<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * WhatsApp Routine Logger
 * 
 * Helper library for logging routine executions with detailed information
 * about each routine run, including success/failure status, templates used,
 * and clients notified.
 */
class Whatsapp_routine_logger
{
    private $CI;
    private $start_time;
    private $execution_log_id;

    public function __construct()
    {
        $this->CI = &get_instance();
        $this->CI->load->model('whatsapp_routine_execution_logs_model');
        $this->CI->load->model('whatsapp_templates_model');
        $this->CI->load->model('customers_model');
    }

    /**
     * Start logging a routine execution
     *
     * @param array $routine Routine data
     * @param array $appointments Appointments to process
     * @return int Log ID
     */
    public function start_execution_log(array $routine, array $appointments): int
    {
        $this->start_time = microtime(true);
        
        // Get template information
        $template_name = null;
        if (!empty($routine['template_id'])) {
            try {
                $template = $this->CI->whatsapp_templates_model->find($routine['template_id']);
                $template_name = $template['name'] ?? null;
            } catch (Exception $e) {
                log_message('error', 'Failed to load template for routine log: ' . $e->getMessage());
            }
        }

        $log_data = [
            'routine_id' => $routine['id'],
            'routine_name' => $routine['name'],
            'execution_status' => 'PENDING', // Will be updated later
            'appointment_status' => $routine['status_agendamento'],
            'template_id' => $routine['template_id'] ?? null,
            'template_name' => $template_name,
            'message_type' => 'routine',
            'total_appointments_found' => count($appointments),
            'successful_sends' => 0,
            'failed_sends' => 0,
            'clients_notified' => [],
            'execution_details' => [
                'routine_config' => [
                    'tempo_antes_horas' => $routine['tempo_antes_horas'] ?? 1,
                    'ativa' => $routine['ativa'] ?? 1,
                ],
                'execution_context' => 'automated', // or 'manual' for force execution
                'appointments_preview' => array_map(function($appt) {
                    return [
                        'id' => $appt['id'],
                        'start_datetime' => $appt['start_datetime'],
                        'customer_timezone' => $appt['_customer_timezone'] ?? null,
                        'send_time_local' => $appt['_send_time_local'] ?? null
                    ];
                }, array_slice($appointments, 0, 10)) // Log first 10 for preview
            ],
            'execution_datetime' => date('Y-m-d H:i:s')
        ];

        $this->execution_log_id = $this->CI->whatsapp_routine_execution_logs_model->create_execution_log($log_data);
        
        return $this->execution_log_id;
    }

    /**
     * Start logging a forced routine execution
     *
     * @param array $routine Routine data
     * @param array $appointments Appointments to process
     * @return int Log ID
     */
    public function start_force_execution_log(array $routine, array $appointments): int
    {
        $this->start_time = microtime(true);
        
        // Get template information
        $template_name = null;
        if (!empty($routine['template_id'])) {
            try {
                $template = $this->CI->whatsapp_templates_model->find($routine['template_id']);
                $template_name = $template['name'] ?? null;
            } catch (Exception $e) {
                log_message('error', 'Failed to load template for routine log: ' . $e->getMessage());
            }
        }

        $log_data = [
            'routine_id' => $routine['id'],
            'routine_name' => $routine['name'],
            'execution_status' => 'PENDING', // Will be updated later
            'appointment_status' => $routine['status_agendamento'],
            'template_id' => $routine['template_id'] ?? null,
            'template_name' => $template_name,
            'message_type' => 'routine',
            'total_appointments_found' => count($appointments),
            'successful_sends' => 0,
            'failed_sends' => 0,
            'clients_notified' => [],
            'execution_details' => [
                'routine_config' => [
                    'tempo_antes_horas' => $routine['tempo_antes_horas'] ?? 1,
                    'ativa' => $routine['ativa'] ?? 1,
                ],
                'execution_context' => 'manual', // Force execution is manual
                'appointments_preview' => array_map(function($appt) {
                    return [
                        'id' => $appt['id'],
                        'start_datetime' => $appt['start_datetime']
                    ];
                }, array_slice($appointments, 0, 10)) // Log first 10 for preview
            ],
            'execution_datetime' => date('Y-m-d H:i:s')
        ];

        $this->execution_log_id = $this->CI->whatsapp_routine_execution_logs_model->create_execution_log($log_data);
        
        return $this->execution_log_id;
    }

    /**
     * Log a successful message send
     *
     * @param array $appointment Appointment data
     * @param array $send_result Send result from whatsapp_sender
     */
    public function log_successful_send(array $appointment, array $send_result): void
    {
        if (!$this->execution_log_id) {
            return;
        }

        // Get customer name for logging - reload appointment to ensure fresh data
        $customer_name = 'Unknown';
        $customer_id = null;
        try {
            // Reload appointment from database to get fresh id_users_customer
            $this->CI->load->model('appointments_model');
            $fresh_appointment = $this->CI->appointments_model->find((int)$appointment['id']);
            $customer_id = $fresh_appointment['id_users_customer'] ?? $appointment['id_users_customer'] ?? null;

            if (!empty($customer_id)) {
                $customer = $this->CI->customers_model->find((int)$customer_id);
                $customer_name = trim(($customer['first_name'] ?? '') . ' ' . ($customer['last_name'] ?? ''));
                if (empty($customer_name)) {
                    $customer_name = $customer['email'] ?? 'Customer ID: ' . $customer_id;
                }
            }
        } catch (Exception $e) {
            log_message('error', 'Failed to load customer for routine log (appt=' . ($appointment['id'] ?? 'unknown') . ', customer=' . ($customer_id ?? 'unknown') . '): ' . $e->getMessage());
        }

        // Update the execution log with success information
        $this->update_send_result(true, $appointment, $customer_name, $send_result);
    }

    /**
     * Log a failed message send
     *
     * @param array $appointment Appointment data
     * @param array $send_result Send result from whatsapp_sender
     */
    public function log_failed_send(array $appointment, array $send_result): void
    {
        if (!$this->execution_log_id) {
            return;
        }

        // Get customer name for logging - reload appointment to ensure fresh data
        $customer_name = 'Unknown';
        $customer_id = null;
        try {
            // Reload appointment from database to get fresh id_users_customer
            $this->CI->load->model('appointments_model');
            $fresh_appointment = $this->CI->appointments_model->find((int)$appointment['id']);
            $customer_id = $fresh_appointment['id_users_customer'] ?? $appointment['id_users_customer'] ?? null;

            if (!empty($customer_id)) {
                $customer = $this->CI->customers_model->find((int)$customer_id);
                $customer_name = trim(($customer['first_name'] ?? '') . ' ' . ($customer['last_name'] ?? ''));
                if (empty($customer_name)) {
                    $customer_name = $customer['email'] ?? 'Customer ID: ' . $customer_id;
                }
            }
        } catch (Exception $e) {
            log_message('error', 'Failed to load customer for routine log (appt=' . ($appointment['id'] ?? 'unknown') . ', customer=' . ($customer_id ?? 'unknown') . '): ' . $e->getMessage());
        }

        // Update the execution log with failure information
        $this->update_send_result(false, $appointment, $customer_name, $send_result);
    }

    /**
     * Finish the execution log with final status
     *
     * @param string|null $error_message Optional error message if execution failed
     */
    public function finish_execution_log(?string $error_message = null): void
    {
        if (!$this->execution_log_id) {
            return;
        }

        $execution_time = microtime(true) - $this->start_time;
        
        // Get current log data to determine final status
        $current_log = $this->CI->whatsapp_routine_execution_logs_model->get_execution_logs(['id' => $this->execution_log_id]);
        
        if (empty($current_log)) {
            return;
        }
        
        $log = $current_log[0];
        $successful = $log['successful_sends'] ?? 0;
        $failed = $log['failed_sends'] ?? 0;
        
        // Determine final execution status
        $execution_status = 'SUCCESS';
        if ($error_message) {
            $execution_status = 'FAILURE';
        } elseif ($failed > 0 && $successful > 0) {
            $execution_status = 'PARTIAL_SUCCESS';
        } elseif ($failed > 0 && $successful === 0) {
            $execution_status = 'FAILURE';
        }

        $update_data = [
            'execution_status' => $execution_status,
            'execution_time_seconds' => round($execution_time, 3),
            'error_message' => $error_message
        ];

        $this->CI->whatsapp_routine_execution_logs_model->update_execution_log($this->execution_log_id, $update_data);
        
        // Log completion message
        log_message('info', sprintf(
            'Routine execution completed: ID=%d, Status=%s, Success=%d, Failed=%d, Time=%.3fs',
            $this->execution_log_id,
            $execution_status,
            $successful,
            $failed,
            $execution_time
        ));
        
        // Reset for next execution
        $this->execution_log_id = null;
        $this->start_time = null;
    }

    /**
     * Update send result in the execution log
     *
     * @param bool $success Whether the send was successful
     * @param array $appointment Appointment data
     * @param string $customer_name Customer name
     * @param array $send_result Send result data
     */
    private function update_send_result(bool $success, array $appointment, string $customer_name, array $send_result): void
    {
        // Get current log data
        $current_logs = $this->CI->whatsapp_routine_execution_logs_model->get_execution_logs(['id' => $this->execution_log_id]);
        
        if (empty($current_logs)) {
            return;
        }
        
        $current_log = $current_logs[0];
        $clients_notified = $current_log['clients_notified'] ?? [];
        $execution_details = $current_log['execution_details'] ?? [];
        
        // Add client to notified list (regardless of success/failure)
        $client_info = [
            'customer_name' => $customer_name,
            'appointment_id' => $appointment['id'],
            'appointment_datetime' => $appointment['start_datetime'],
            'status' => $success ? 'SUCCESS' : 'FAILURE',
            'timestamp' => date('Y-m-d H:i:s')
        ];
        
        if (!$success && !empty($send_result['message'])) {
            $client_info['error'] = $send_result['message'];
        }
        
        $clients_notified[] = $client_info;
        
        // Update execution details with send information
        if (!isset($execution_details['send_results'])) {
            $execution_details['send_results'] = [];
        }
        
        $execution_details['send_results'][] = [
            'appointment_id' => $appointment['id'],
            'success' => $success,
            'timestamp' => date('Y-m-d H:i:s'),
            'log_id' => $send_result['log_id'] ?? null,
            'http_status' => $send_result['_http_status'] ?? null,
            'response_summary' => $success ? 'Message sent successfully' : ($send_result['message'] ?? 'Send failed')
        ];

        // Update counters
        $update_data = [
            'successful_sends' => $current_log['successful_sends'] + ($success ? 1 : 0),
            'failed_sends' => $current_log['failed_sends'] + ($success ? 0 : 1),
            'clients_notified' => $clients_notified,
            'execution_details' => $execution_details
        ];

        $this->CI->whatsapp_routine_execution_logs_model->update_execution_log($this->execution_log_id, $update_data);
    }

    /**
     * Get the current execution log ID
     *
     * @return int|null
     */
    public function get_execution_log_id(): ?int
    {
        return $this->execution_log_id;
    }
}

