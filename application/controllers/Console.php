<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.3.2
 * ---------------------------------------------------------------------------- */

use Jsvrcek\ICS\Exception\CalendarEventException;

require_once __DIR__ . '/Google.php';
require_once __DIR__ . '/Caldav.php';

/**
 * Console controller.
 *
 * Handles all the Console related operations.
 */
class Console extends EA_Controller
{
    /**
     * Console constructor.
     */
    public function __construct()
    {
        if (!is_cli()) {
            exit('No direct script access allowed');
        }

        parent::__construct();

        $this->load->dbutil();

        $this->load->library('instance');

        $this->load->model('admins_model');
        $this->load->model('customers_model');
        $this->load->model('providers_model');
        $this->load->model('services_model');
        $this->load->model('settings_model');
    }

    /**
     * Perform a console installation.
     *
     * Use this method to install Easy!Appointments directly from the terminal.
     *
     * Usage:
     *
     * php index.php console install
     *
     * @throws Exception
     */
    public function install(): void
    {
        $this->instance->migrate('fresh');

        $password = $this->instance->seed();

        response(
            PHP_EOL . '⇾ Installation completed, login with "administrator" / "' . $password . '".' . PHP_EOL . PHP_EOL,
        );
    }

    /**
     * Migrate the database to the latest state.
     *
     * Use this method to upgrade an Easy!Appointments instance to the latest database state.
     *
     * Notice:
     *
     * Do not use this method to install the app as it will not seed the database with the initial entries (admin,
     * provider, service, settings etc.).
     *
     * Usage:
     *
     * php index.php console migrate
     *
     * php index.php console migrate fresh
     *
     * @param string $type
     */
    public function migrate(string $type = ''): void
    {
        $this->instance->migrate($type);
    }

    /**
     * Seed the database with test data.
     *
     * Use this method to add test data to your database
     *
     * Usage:
     *
     * php index.php console seed
     * @throws Exception
     */
    public function seed(): void
    {
        $this->instance->seed();
    }

    /**
     * Create a database backup file.
     *
     * Use this method to back up your Easy!Appointments data.
     *
     * Usage:
     *
     * php index.php console backup
     *
     * php index.php console backup /path/to/backup/folder
     *
     * @throws Exception
     */
    public function backup(): void
    {
        $this->instance->backup($GLOBALS['argv'][3] ?? null);
    }

    /**
     * Trigger the synchronization of all provider calendars with Google Calendar.
     *
     * Use this method in a cronjob to automatically sync events between Easy!Appointments and Google Calendar.
     *
     * Notice:
     *
     * Google syncing must first be enabled for each individual provider from inside the backend calendar page.
     *
     * Usage:
     *
     * php index.php console sync
     *
     * @throws CalendarEventException
     * @throws Exception
     * @throws Throwable
     */
    public function sync(): void
    {
        $providers = $this->providers_model->get();

        foreach ($providers as $provider) {
            if (filter_var($provider['settings']['google_sync'], FILTER_VALIDATE_BOOLEAN)) {
                Google::sync((string) $provider['id']);
            }

            if (filter_var($provider['settings']['caldav_sync'], FILTER_VALIDATE_BOOLEAN)) {
                Caldav::sync((string) $provider['id']);
            }
        }
    }

    /**
     * Show help information about the console capabilities.
     *
     * Use this method to see the available commands.
     *
     * Usage:
     *
     * php index.php console help
     */
    public function help(): void
    {
        $help = [
            '',
            'Easy!Appointments ' . config('version'),
            '',
            'Usage:',
            '',
            '⇾ php index.php console [command] [arguments]',
            '',
            'Commands:',
            '',
            '⇾ php index.php console migrate',
            '⇾ php index.php console migrate fresh',
            '⇾ php index.php console migrate up',
            '⇾ php index.php console migrate down',
            '⇾ php index.php console seed',
            '⇾ php index.php console install',
            '⇾ php index.php console backup',
            '⇾ php index.php console sync',
            '',
            '',
        ];

        response(implode(PHP_EOL, $help));
    }

    /**
     * Rotate WPPConnect token from the console (CLI only).
     *
     * Usage:
     *   php index.php console rotate_whatsapp_token
     */
    public function rotate_whatsapp_token(): void
    {
        // Already guarded by constructor is_cli()
        $this->load->model('whatsapp_integration_settings_model');
        $this->load->library('wppconnect_service');

        $settings = $this->whatsapp_integration_settings_model->get_current();
        if (empty($settings)) {
            response('No WhatsApp integration settings found.' . PHP_EOL);
            return;
        }

        $new = $this->wppconnect_service->generate_token($settings['secret_key'] ?? '');
        if (empty($new['token'])) {
            response('Failed to rotate token: WPPConnect did not return a token.' . PHP_EOL);
            return;
        }

        $ok = $this->whatsapp_integration_settings_model->update_token($new['token']);
        if ($ok) {
            $this->wppconnect_service->update_config(['token' => $new['token']]);
            // Audit: rotation performed via CLI (no DB audit insertion to avoid migration prefix issues here)
            response('Token rotated successfully.' . PHP_EOL);
        } else {
            response('Failed to update token in database.' . PHP_EOL);
        }
    }

    /**
     * Run WhatsApp reminder routines (CLI only).
     *
     * Usage: php index.php console run_whatsapp_routines
     */
    public function run_whatsapp_routines(): void
    {
        // Guarded by constructor is_cli()
        $this->load->model('rotinas_whatsapp_model');
        $this->load->library('whatsapp_sender');
        $this->load->library('whatsapp_routine_logger');

        $routines = $this->rotinas_whatsapp_model->get_active();
        $window = 5; // minutes window - check every 5 minutes for due appointments

        foreach ($routines as $routine) {
            $execution_log_id = null;
            
            try {
                $appointments = $this->rotinas_whatsapp_model->find_due_appointments($routine, $window);
                
                // Skip routine if no appointments found
                if (empty($appointments)) {
                    continue;
                }
                
                // Start execution logging
                $execution_log_id = $this->whatsapp_routine_logger->start_execution_log($routine, $appointments);
                
                // Ensure message sends from routines are recorded in message logs.
                $this->load->model('whatsapp_message_logs_model');

                foreach ($appointments as $appt) {
                    response('Sending routine ' . $routine['name'] . ' for appointment ' . $appt['id'] . PHP_EOL);
                    
                    try {
                        // Attempt send using Whatsapp_sender; pass template_id from routine
                        $res = $this->whatsapp_sender->send((int)$appt['id'], (int)$routine['template_id'], 'routine', true);

                        // If whatsapp_sender didn't create a message log (log_id missing), create a fallback log entry here
                        $logId = $res['log_id'] ?? null;
                        if (empty($logId)) {
                            try {
                                // load appointment/customer to populate log
                                $this->load->model('appointments_model');
                                $this->load->model('customers_model');
                                $appointmentRow = $this->appointments_model->find((int)$appt['id']);
                                $customerRow = $this->customers_model->find($appointmentRow['id_users_customer'] ?? 0);

                                $toPhone = $customerRow['phone_number'] ?? '';
                                $bodyHash = hash('sha256', json_encode($res['details'] ?? $res));

                                $logId = $this->whatsapp_message_logs_model->create_log_entry(
                                    (int)$appt['id'],
                                    (int)$routine['template_id'] ?: null,
                                    $appointmentRow['status'] ?? '',
                                    $toPhone,
                                    $bodyHash,
                                    'routine',
                                    ['response' => $res]
                                );

                                // Update result based on send response
                                if (!empty($res['success'])) {
                                    $this->whatsapp_message_logs_model->update_log_result($logId, 'SUCCESS', $res['_http_status'] ?? ($res['details']['send_response']['_http_status'] ?? 200), $res['details']['send_response'] ?? $res);
                                } else {
                                    $this->whatsapp_message_logs_model->update_log_result($logId, 'FAILURE', $res['_http_status'] ?? null, $res['details']['send_response'] ?? null, null, $res['message'] ?? null);
                                }
                            } catch (Throwable $e) {
                                log_message('error', 'Failed to create fallback whatsapp message log for appointment ' . $appt['id'] . ': ' . $e->getMessage());
                            }
                        }

                        if (!empty($res['success'])) {
                            // Calculate send time for reprocessing tracking
                            $calculated_send_time = null;
                            $appointment_start_time = $appt['start_datetime'] ?? null;
                            $routine_hours_before = (int)($routine['tempo_antes_horas'] ?? 1);
                            
                            if ($appointment_start_time) {
                                $send_time = new DateTime($appointment_start_time);
                                $send_time->modify('-' . $routine_hours_before . ' hours');
                                $calculated_send_time = $send_time->format('Y-m-d H:i:s');
                            }
                            
                            $okMark = $this->rotinas_whatsapp_model->mark_sent(
                                $routine['id'], 
                                $appt['id'], 
                                $logId ?? null, 
                                $calculated_send_time, 
                                $appointment_start_time, 
                                $routine_hours_before
                            );
                            
                            // Log successful send
                            $this->whatsapp_routine_logger->log_successful_send($appt, $res);
                            
                            if ($okMark) {
                                response('Sent OK for appointment ' . $appt['id'] . PHP_EOL);
                            } else {
                                response('Sent but failed to record routine send for appointment ' . $appt['id'] . PHP_EOL);
                            }
                        } else {
                            // Log failed send
                            $this->whatsapp_routine_logger->log_failed_send($appt, $res);
                            response('Failed to send for appointment ' . $appt['id'] . ': ' . ($res['message'] ?? 'unknown') . PHP_EOL);
                        }
                    } catch (Throwable $e) {
                        // Log exception as failed send
                        $error_result = [
                            'success' => false,
                            'message' => 'Exception during send: ' . $e->getMessage(),
                            '_http_status' => null
                        ];
                        $this->whatsapp_routine_logger->log_failed_send($appt, $error_result);
                        
                        log_message('error', 'Exception sending routine message for appointment ' . $appt['id'] . ': ' . $e->getMessage());
                        response('Exception sending for appointment ' . $appt['id'] . ': ' . $e->getMessage() . PHP_EOL);
                    }
                }
                
                // Finish execution log with success
                $this->whatsapp_routine_logger->finish_execution_log();
                
            } catch (Throwable $e) {
                // Finish execution log with error
                if ($execution_log_id) {
                    $this->whatsapp_routine_logger->finish_execution_log('Routine execution failed: ' . $e->getMessage());
                }
                
                log_message('error', 'Exception in routine execution for routine ' . $routine['id'] . ': ' . $e->getMessage());
                response('Exception in routine ' . $routine['name'] . ': ' . $e->getMessage() . PHP_EOL);
            }
        }
    }
}
