<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * Login controller.
 *
 * Handles the login page functionality.
 *
 * @package Controllers
 */
class Login extends EA_Controller
{
    /**
     * Login constructor.
     */
    public function __construct()
    {
        parent::__construct();

        $this->load->library('accounts');
        $this->load->library('ldap_client');
        $this->load->library('email_messages');

        script_vars([
            'dest_url' => session('dest_url', site_url('calendar')),
        ]);
    }

    /**
     * Render the login page.
     */
    public function index(): void
    {
        if (session('user_id')) {
            redirect('calendar');
            return;
        }

        html_vars([
            'page_title' => lang('login'),
            'base_url' => config('base_url'),
            'dest_url' => session('dest_url', site_url('calendar')),
            'company_name' => setting('company_name'),
        ]);

        $this->load->view('pages/login');
    }

    /**
     * Validate the provided credentials and start a new session if the validation was successful.
     */
    public function validate(): void
    {
        try {
            $username = request('username');

            if (empty($username)) {
                throw new InvalidArgumentException('No username value provided.');
            }

            $password = request('password');

            if (empty($password)) {
                throw new InvalidArgumentException('No password value provided.');
            }

            $user_data = $this->accounts->check_login($username, $password);

            if (empty($user_data)) {
                $user_data = $this->ldap_client->check_login($username, $password);
            }

            if (empty($user_data)) {
                throw new InvalidArgumentException(lang('invalid_credentials_provided'));
            }

            // 2FA handshake: if enabled and not a remembered device, do not promote session yet.
            $user = $this->accounts->get_user_by_username($username);
            $settings = $this->db->get_where('user_settings', ['id_users' => $user['id']])->row_array();

            $require_2fa = !empty($settings['two_factor_enabled']) && !empty($settings['two_factor_secret']);

            if ($require_2fa) {
                // Check remembered device via cookie token hash
                $token = (string) $this->input->cookie('ea_2fa_device', true);
                $hash = $token ? hash('sha256', $token) : '';
                $remembered = [];
                if ($hash) {
                    $remembered = $this->db
                        ->from('user_two_factor_devices')
                        ->where(['id_users' => $user['id'], 'device_hash' => $hash])
                        ->where('(expires_datetime IS NULL OR expires_datetime > NOW())')
                        ->get()
                        ->row_array();
                }

                if (!$remembered) {
                    // Mark session as pending and require verification
                    session([
                        'pending_user_id' => $user['id'],
                        'pending_username' => $username,
                    ]);

                    // Preload language for pending user so 2FA page renders correctly
                    if (!empty($user['language'])) {
                        session(['language' => $user['language']]);
                    }

                    json_response([
                        'success' => true,
                        'requires_2fa' => true,
                        'redirect' => site_url('two_factor/verify'),
                    ]);
                    return;
                }
            }

            $this->session->sess_regenerate();

            session($user_data); // Save data in the session.

            json_response([
                'success' => true,
                'requires_2fa' => false,
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }
}
