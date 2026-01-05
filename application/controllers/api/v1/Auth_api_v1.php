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

use Firebase\JWT\ExpiredException;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

/**
 * Auth API v1 controller.
 *
 * Handles JWT authentication endpoints for the API.
 *
 * @package Controllers
 */
class Auth_api_v1 extends EA_Controller
{
    /**
     * Auth_api_v1 constructor.
     */
    public function __construct()
    {
        parent::__construct();

        $this->load->library('jwt_auth');
        $this->load->library('accounts');
        $this->load->library('crypto');
        $this->load->model('users_model');
        $this->load->model('roles_model');
    }

    /**
     * User login.
     *
     * POST /api/v1/auth/login
     *
     * Authenticates user credentials and returns JWT tokens.
     * If 2FA is enabled and device is not remembered, returns requires_2fa flag.
     */
    public function login(): void
    {
        try {
            $username = request('username');
            $password = request('password');

            if (empty($username) || empty($password)) {
                json_response(
                    [
                        'success' => false,
                        'message' => 'Username and password are required',
                        'code' => 'MISSING_CREDENTIALS',
                    ],
                    400,
                );
                return;
            }

            // Authenticate using existing Accounts library
            $user_data = $this->accounts->check_login($username, $password);

            if (!$user_data) {
                json_response(
                    [
                        'success' => false,
                        'message' => 'Invalid credentials',
                        'code' => 'INVALID_CREDENTIALS',
                    ],
                    401,
                );
                return;
            }

            // Check if 2FA is enabled for this user
            $user_id = (int) $user_data['user_id'];
            $settings = $this->db->get_where('user_settings', ['id_users' => $user_id])->row_array();

            $two_factor_enabled = !empty($settings['two_factor_enabled'])
                && (string) $settings['two_factor_enabled'] === '1'
                && !empty($settings['two_factor_secret']);

            if ($two_factor_enabled) {
                // Check if device is remembered via header token
                $device_token = $this->get_2fa_device_token();
                $is_remembered = $this->check_remembered_device($user_id, $device_token);

                if (!$is_remembered) {
                    // Generate temporary token for 2FA verification
                    $temp_token = $this->jwt_auth->create_2fa_pending_token($user_data);

                    json_response(
                        [
                            'success' => true,
                            'requires_2fa' => true,
                            'temp_token' => $temp_token,
                            'code' => '2FA_REQUIRED',
                        ],
                        200,
                    );
                    return;
                }
            }

            // Get device info for token tracking
            $device_info = $this->get_device_info();
            $ip_address = $this->input->ip_address();

            // Generate tokens
            $tokens = $this->jwt_auth->create_tokens($user_data, $device_info, $ip_address);

            // Get full user info for response
            $user = $this->users_model->find($user_data['user_id']);

            json_response(
                [
                    'success' => true,
                    'requires_2fa' => false,
                    'data' => [
                        'tokens' => $tokens,
                        'user' => [
                            'id' => (int) $user['id'],
                            'firstName' => $user['first_name'],
                            'lastName' => $user['last_name'],
                            'email' => $user['email'],
                            'role' => $user_data['role_slug'],
                            'timezone' => $user_data['timezone'],
                            'language' => $user_data['language'],
                        ],
                    ],
                ],
                200,
            );
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Refresh access token.
     *
     * POST /api/v1/auth/refresh
     *
     * Generates a new access token using a valid refresh token.
     */
    public function refresh(): void
    {
        try {
            $refresh_token = request('refresh_token');

            if (empty($refresh_token)) {
                json_response(
                    [
                        'success' => false,
                        'message' => 'Refresh token is required',
                        'code' => 'MISSING_REFRESH_TOKEN',
                    ],
                    400,
                );
                return;
            }

            $result = $this->jwt_auth->refresh_access_token($refresh_token);

            if (!$result) {
                json_response(
                    [
                        'success' => false,
                        'message' => 'Invalid or expired refresh token',
                        'code' => 'REFRESH_TOKEN_INVALID',
                    ],
                    401,
                );
                return;
            }

            json_response(
                [
                    'success' => true,
                    'data' => $result,
                ],
                200,
            );
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Logout and revoke tokens.
     *
     * POST /api/v1/auth/logout
     *
     * Revokes the provided refresh token or all user tokens.
     */
    public function logout(): void
    {
        try {
            $refresh_token = request('refresh_token');
            $logout_all = filter_var(request('all', false), FILTER_VALIDATE_BOOLEAN);

            // Get current user from JWT if available
            $user_id = $this->get_authenticated_user_id();

            if ($logout_all && $user_id) {
                $this->jwt_auth->revoke_all_user_tokens($user_id);
            } elseif (!empty($refresh_token)) {
                $this->jwt_auth->revoke_token($refresh_token);
            }

            json_response(
                [
                    'success' => true,
                    'message' => 'Successfully logged out',
                ],
                200,
            );
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get current authenticated user info.
     *
     * GET /api/v1/auth/me
     *
     * Returns information about the currently authenticated user.
     */
    public function me(): void
    {
        try {
            $token = $this->get_bearer_token();

            if (!$token) {
                json_response(
                    [
                        'success' => false,
                        'message' => 'No authentication token provided',
                        'code' => 'MISSING_TOKEN',
                    ],
                    401,
                );
                return;
            }

            $decoded = $this->jwt_auth->validate_access_token($token);

            $user = $this->users_model->find($decoded->data->user_id);
            $role = $this->roles_model->find($user['id_roles']);

            // Get username from user_settings
            $user_settings = $this->db->get_where('user_settings', ['id_users' => $user['id']])->row_array();

            json_response(
                [
                    'success' => true,
                    'data' => [
                        'id' => (int) $user['id'],
                        'firstName' => $user['first_name'],
                        'lastName' => $user['last_name'],
                        'email' => $user['email'],
                        'username' => $user_settings['username'] ?? '',
                        'role' => $role['slug'],
                        'timezone' => $user['timezone'],
                        'language' => $user['language'],
                        'phone' => $user['phone_number'],
                        'mobile' => $user['mobile_number'],
                        'address' => $user['address'],
                        'city' => $user['city'],
                        'state' => $user['state'],
                        'zip' => $user['zip_code'],
                        'notes' => $user['notes'],
                    ],
                ],
                200,
            );
        } catch (ExpiredException $e) {
            json_response(
                [
                    'success' => false,
                    'message' => 'Token expired',
                    'code' => 'TOKEN_EXPIRED',
                ],
                401,
            );
        } catch (Throwable $e) {
            json_response(
                [
                    'success' => false,
                    'message' => 'Invalid token',
                    'code' => 'INVALID_TOKEN',
                ],
                401,
            );
        }
    }

    /**
     * Get bearer token from request headers.
     *
     * @return string|null
     */
    protected function get_bearer_token(): ?string
    {
        $headers = $this->get_authorization_header();

        if (!empty($headers) && preg_match('/Bearer\s(\S+)/', $headers, $matches)) {
            return $matches[1];
        }

        return null;
    }

    /**
     * Get authorization header from various server configurations.
     *
     * @return string|null
     */
    protected function get_authorization_header(): ?string
    {
        if (isset($_SERVER['Authorization'])) {
            return trim($_SERVER['Authorization']);
        }

        if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            return trim($_SERVER['HTTP_AUTHORIZATION']);
        }

        if (function_exists('apache_request_headers')) {
            $headers = apache_request_headers();
            $headers = array_combine(array_map('ucwords', array_keys($headers)), array_values($headers));

            if (isset($headers['Authorization'])) {
                return trim($headers['Authorization']);
            }
        }

        return null;
    }

    /**
     * Get device info from request.
     *
     * @return string|null
     */
    protected function get_device_info(): ?string
    {
        $device_name = request('device_name');

        if (!empty($device_name)) {
            return $device_name;
        }

        return $this->input->user_agent() ?: null;
    }

    /**
     * Get authenticated user ID from JWT token.
     *
     * @return int|null
     */
    protected function get_authenticated_user_id(): ?int
    {
        try {
            $token = $this->get_bearer_token();

            if ($token) {
                $decoded = $this->jwt_auth->validate_access_token($token);
                return (int) $decoded->data->user_id;
            }
        } catch (Throwable $e) {
            // Token invalid or expired - ignore
        }

        return null;
    }

    /**
     * Change the current user's password.
     */
    public function change_password()
    {
        try {
            $token = $this->get_bearer_token();

            if (!$token) {
                json_response([
                    'success' => false,
                    'message' => 'No authentication token provided',
                    'code' => 'MISSING_TOKEN'
                ], 401);
                return;
            }

            try {
                $decoded = $this->jwt_auth->validate_access_token($token);
                $user_id = (int) $decoded->data->user_id;
            } catch (ExpiredException $e) {
                json_response([
                    'success' => false,
                    'message' => 'Token expired',
                    'code' => 'TOKEN_EXPIRED'
                ], 401);
                return;
            } catch (Throwable $e) {
                json_response([
                    'success' => false,
                    'message' => 'Invalid token',
                    'code' => 'INVALID_TOKEN'
                ], 401);
                return;
            }

            $current_password = request('current_password');
            $new_password = request('new_password');

            if (empty($current_password) || empty($new_password)) {
                json_response([
                    'success' => false,
                    'message' => 'Missing required fields',
                    'code' => 'MISSING_FIELDS'
                ], 400);
                return;
            }

            // Verify current password
            $user_settings = $this->db->get_where('user_settings', ['id_users' => $user_id])->row_array();
            
            if (!$user_settings) {
                json_response([
                    'success' => false,
                    'message' => 'User settings not found',
                    'code' => 'USER_NOT_FOUND'
                ], 404);
                return;
            }

            $current_hash = hash_password($user_settings['salt'], $current_password);

            if ($current_hash !== $user_settings['password']) {
                json_response([
                    'success' => false,
                    'message' => 'Current password is incorrect',
                    'code' => 'INVALID_PASSWORD'
                ], 400);
                return;
            }

            // Update with new password
            $new_hash = hash_password($user_settings['salt'], $new_password);
            $this->users_model->set_setting($user_id, 'password', $new_hash);

            json_response(['success' => true, 'message' => 'Password changed successfully']);

        } catch (Exception $e) {
            json_response([
                'success' => false,
                'message' => $e->getMessage(),
                'code' => 'SERVER_ERROR'
            ], 500);
        }
    }

    /**
     * Get 2FA device token from request header.
     *
     * @return string|null
     */
    protected function get_2fa_device_token(): ?string
    {
        // Check custom header first
        $token = $this->input->get_request_header('X-2FA-Device-Token', true);

        if (!empty($token)) {
            return $token;
        }

        // Also check cookie as fallback (for web compatibility)
        $cookie_token = $this->input->cookie('ea_2fa_device', true);

        return !empty($cookie_token) ? $cookie_token : null;
    }

    /**
     * Check if a device is remembered for the user.
     *
     * @param int $user_id User ID.
     * @param string|null $device_token Device token from header or cookie.
     *
     * @return bool Returns true if device is remembered and valid.
     */
    protected function check_remembered_device(int $user_id, ?string $device_token): bool
    {
        if (empty($device_token)) {
            return false;
        }

        $hash = hash('sha256', $device_token);

        $row = $this->db
            ->from('user_two_factor_devices')
            ->where(['id_users' => $user_id, 'device_hash' => $hash])
            ->where('(expires_datetime IS NULL OR expires_datetime > NOW())')
            ->get()
            ->row_array();

        if ($row) {
            // Update last_used_datetime
            $this->db->update('user_two_factor_devices', [
                'last_used_datetime' => date('Y-m-d H:i:s'),
            ], ['id' => $row['id']]);

            return true;
        }

        return false;
    }
}
