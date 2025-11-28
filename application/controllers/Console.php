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
                    response("No due appointments found for routine '{$routine['name']}' ({$routine['tempo_antes_horas']}h before)\n");
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

    /**
     * Audit server logs for exposed WhatsApp secret keys and sensitive data.
     *
     * Usage: php index.php console audit_whatsapp_logs [--fix]
     *
     * Scans application logs for:
     * - WPPConnect secret keys in URLs
     * - Bearer tokens in logs
     * - Unencrypted credentials
     *
     * @param string|null $fix Optional '--fix' flag to sanitize logs
     */
    public function audit_whatsapp_logs(?string $fix = null): void
    {
        response("=== WhatsApp Integration Security Audit ===" . PHP_EOL . PHP_EOL);

        $this->load->model('whatsapp_integration_settings_model');

        // Get log directory from CodeIgniter config
        $log_path = APPPATH . 'logs/';
        $issues_found = 0;
        $files_scanned = 0;

        if (!is_dir($log_path)) {
            response("ERROR: Log directory not found: {$log_path}" . PHP_EOL);
            return;
        }

        response("Scanning logs in: {$log_path}" . PHP_EOL . PHP_EOL);

        // Get current secret key from settings (to detect in logs)
        try {
            $settings = $this->whatsapp_integration_settings_model->get_settings();
            $current_secret = $settings['secret_key'] ?? null;

            if ($current_secret) {
                response("[INFO] Current secret key loaded for detection" . PHP_EOL);
            }
        } catch (Throwable $e) {
            response("[WARN] Could not load current secret key: " . $e->getMessage() . PHP_EOL);
            $current_secret = null;
        }

        // Patterns to search for (sensitive data indicators)
        $patterns = [
            'secret_key' => '/\/api\/[^\/]+\/([a-zA-Z0-9_-]{10,})\/generate-token/i',
            'bearer_token' => '/Authorization:\s*Bearer\s+([a-zA-Z0-9_-]{20,})/i',
            'wpp_token' => '/"token"\s*:\s*"([a-zA-Z0-9_-]{20,})"/i',
            'raw_secret' => '/"secret_key"\s*:\s*"([^"]{8,})"/i',
        ];

        // Scan log files
        $log_files = glob($log_path . 'log-*.php');

        if (empty($log_files)) {
            response("No log files found to scan." . PHP_EOL);
            return;
        }

        foreach ($log_files as $log_file) {
            $files_scanned++;
            $filename = basename($log_file);
            $file_issues = [];

            $content = file_get_contents($log_file);

            foreach ($patterns as $type => $pattern) {
                if (preg_match_all($pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
                    foreach ($matches[1] as $match) {
                        $value = $match[0];
                        $position = $match[1];

                        // Calculate line number
                        $line_num = substr_count(substr($content, 0, $position), "\n") + 1;

                        // Check if it's the current secret key
                        $is_current = ($current_secret && $type === 'secret_key' && $value === $current_secret);

                        $file_issues[] = [
                            'type' => $type,
                            'line' => $line_num,
                            'value' => $this->mask_sensitive_value($value),
                            'is_current' => $is_current,
                        ];

                        $issues_found++;
                    }
                }
            }

            if (!empty($file_issues)) {
                response("📄 {$filename}:" . PHP_EOL);

                foreach ($file_issues as $issue) {
                    $warning = $issue['is_current'] ? ' ⚠️ CURRENT SECRET!' : '';
                    response("  Line {$issue['line']}: {$issue['type']} = {$issue['value']}{$warning}" . PHP_EOL);
                }

                response(PHP_EOL);

                // If --fix flag is provided, sanitize this file
                if ($fix === '--fix') {
                    $this->sanitize_log_file($log_file, $patterns);
                }
            }
        }

        // Summary
        response("=== Audit Summary ===" . PHP_EOL);
        response("Files scanned: {$files_scanned}" . PHP_EOL);
        response("Issues found: {$issues_found}" . PHP_EOL . PHP_EOL);

        if ($issues_found > 0) {
            response("⚠️  SECURITY RISK: Sensitive data found in logs!" . PHP_EOL . PHP_EOL);
            response("Recommendations:" . PHP_EOL);
            response("1. Rotate WhatsApp secret key immediately if CURRENT SECRET found" . PHP_EOL);
            response("2. Run with --fix flag to sanitize logs: php index.php console audit_whatsapp_logs --fix" . PHP_EOL);
            response("3. Review server access logs (nginx/apache) for similar exposures" . PHP_EOL);
            response("4. Consider log rotation and retention policies" . PHP_EOL . PHP_EOL);

            if ($current_secret && $issues_found > 0) {
                response("To rotate the token, run:" . PHP_EOL);
                response("  php index.php console rotate_whatsapp_token" . PHP_EOL);
            }
        } else {
            response("✅ No sensitive data exposure detected in application logs." . PHP_EOL);
        }
    }

    /**
     * Mask sensitive value for display (show first 4 and last 4 chars).
     */
    private function mask_sensitive_value(string $value): string
    {
        $len = strlen($value);
        if ($len <= 8) {
            return str_repeat('*', $len);
        }

        return substr($value, 0, 4) . str_repeat('*', $len - 8) . substr($value, -4);
    }

    /**
     * Sanitize a log file by replacing sensitive patterns with [REDACTED].
     */
    private function sanitize_log_file(string $file_path, array $patterns): void
    {
        $content = file_get_contents($file_path);
        $original_size = strlen($content);
        $replacements = 0;

        foreach ($patterns as $type => $pattern) {
            $content = preg_replace_callback($pattern, function($matches) use (&$replacements, $type) {
                $replacements++;
                // Replace the captured group (secret/token) with [REDACTED-{type}]
                return str_replace($matches[1], '[REDACTED-' . strtoupper($type) . ']', $matches[0]);
            }, $content);
        }

        if ($replacements > 0) {
            // Backup original file
            $backup_path = $file_path . '.backup-' . date('YmdHis');
            copy($file_path, $backup_path);

            // Write sanitized content
            file_put_contents($file_path, $content);

            response("  ✅ Sanitized " . basename($file_path) . " ({$replacements} replacements)" . PHP_EOL);
            response("     Backup: " . basename($backup_path) . PHP_EOL);
        }
    }
}
