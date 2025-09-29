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
 * WhatsApp Sender library.
 *
 * Handles sending WhatsApp messages for appointments.
 *
 * @package Libraries
 */
class Whatsapp_sender
{
    /**
     * @var EA_Controller|CI_Controller
     */
    protected EA_Controller|CI_Controller $CI;

    /**
     * WhatsApp Sender constructor.
     */
    public function __construct()
    {
        $this->CI = &get_instance();
        
        $this->CI->load->model('appointments_model');
        $this->CI->load->model('customers_model');
        $this->CI->load->model('services_model');
        $this->CI->load->model('providers_model');
        $this->CI->load->model('whatsapp_integration_settings_model');
        $this->CI->load->model('whatsapp_templates_model');
        $this->CI->load->model('whatsapp_message_logs_model');
        
        $this->CI->load->library('wppconnect_service');
        $this->CI->load->library('whatsapp_template_service');
    }

    /**
     * Send WhatsApp message for an appointment.
     *
     * @param int $appointment_id Appointment ID.
     * @param int|null $template_id Template ID (optional, will resolve by status if not provided).
     * @param string $send_type Send type (onCreate, onUpdate, manual).
     * @param bool $force_send Force send even if duplicate.
     *
     * @return array Returns send result.
     */
    public function send(int $appointment_id, ?int $template_id = null, string $send_type = 'manual', bool $force_send = false, bool $time_changed = false): array
    {
        $result = [
            'success' => false,
            'message' => '',
            'log_id' => null,
            'details' => [],
        ];

        try {
            // Check if integration is enabled
            if (!$this->is_integration_enabled()) {
                $result['message'] = 'WhatsApp integration is disabled';
                return $result;
            }

            // Load appointment data
            $appointment = $this->CI->appointments_model->find($appointment_id);
            $customer = $this->CI->customers_model->find($appointment['id_users_customer']);
            $service = $this->CI->services_model->find($appointment['id_services']);
            $provider = $this->CI->providers_model->find($appointment['id_users_provider']);

            $result['details']['appointment'] = $appointment;
            $result['details']['customer'] = $this->mask_customer_data($customer);

            // Validate customer phone
            if (empty($customer['phone_number'])) {
                $result['message'] = 'Customer phone number is required';
                return $result;
            }

            // For automatic sends, check if template exists and is enabled
            if ($send_type !== 'manual') {
                $template_check = $this->CI->whatsapp_template_service->resolve_template(
                    $appointment['status'],
                    $template_id,
                    $customer['language'] ?? config('language')
                );
                
                if (!$template_check) {
                    $result['message'] = 'No enabled template found for status: ' . $appointment['status'];
                    return $result;
                }
            }

            // Resolve template
            $template = $this->CI->whatsapp_template_service->resolve_template(
                $appointment['status'],
                $template_id,
                $customer['language'] ?? config('language')
            );

            if (!$template) {
                $result['message'] = 'No template found for status: ' . $appointment['status'];
                return $result;
            }

            $result['details']['template'] = $template;

            // Render message
            $message_body = $this->CI->whatsapp_template_service->render_template(
                $template,
                $appointment,
                $customer,
                $service,
                $provider,
                $customer['language'] ?? config('language')
            );

            $body_hash = hash('sha256', $message_body);

            // Check for duplicates
            if (!$force_send && $this->CI->whatsapp_message_logs_model->is_duplicate_send(
                $appointment_id,
                $appointment['status'],
                $template['id'],
                $send_type,
                $body_hash,
                300, // window_seconds
                $time_changed
            )) {
                $result['message'] = 'Message already sent recently (duplicate prevention)';
                return $result;
            }

            // Create log entry
            $log_id = $this->CI->whatsapp_message_logs_model->create_log_entry(
                $appointment_id,
                $template['id'],
                $appointment['status'],
                $customer['phone_number'],
                $body_hash,
                $send_type,
                [
                    'phone' => $customer['phone_number'],
                    'message' => $message_body,
                ]
            );

            $result['log_id'] = $log_id;

            // Send message
            try {
                $send_response = $this->CI->wppconnect_service->send_message(
                    $customer['phone_number'],
                    $message_body
                );

                $result['details']['send_response'] = $send_response;

                // Update log with success
                $this->CI->whatsapp_message_logs_model->update_log_result(
                    $log_id,
                    'SUCCESS',
                    $send_response['_http_status'] ?? 200,
                    $send_response
                );

                $result['success'] = true;
                $result['message'] = 'Message sent successfully';

                log_message('info', 'WhatsApp message sent successfully for appointment ' . $appointment_id);

            } catch (Exception $e) {
                // Update log with failure
                $this->CI->whatsapp_message_logs_model->update_log_result(
                    $log_id,
                    'FAILURE',
                    $e->getCode(),
                    null,
                    'SEND_ERROR',
                    $e->getMessage()
                );

                $result['message'] = 'Failed to send message: ' . $e->getMessage();
                $result['details']['error'] = $e->getMessage();

                log_message('error', 'WhatsApp message send failed for appointment ' . $appointment_id . ': ' . $e->getMessage());
            }

        } catch (Exception $e) {
            $result['message'] = 'Error processing send request: ' . $e->getMessage();
            $result['details']['error'] = $e->getMessage();

            log_message('error', 'WhatsApp sender error for appointment ' . $appointment_id . ': ' . $e->getMessage());
        }

        return $result;
    }

    /**
     * Send WhatsApp message on appointment create.
     *
     * @param array $appointment Appointment data.
     *
     * @return array Returns send result.
     */
    public function send_on_create(array $appointment): array
    {
        return $this->send($appointment['id'], $appointment['template_id'] ?? null, 'onCreate');
    }

    /**
     * Send WhatsApp message on appointment update.
     *
     * @param array $appointment Appointment data.
     * @param array $old_appointment Old appointment data for comparison.
     *
     * @return array Returns send result.
     */
    public function send_on_update(array $appointment, array $old_appointment = []): array
    {
        // Send if status changed OR appointment time changed
        $status_changed = empty($old_appointment) || (($appointment['status'] ?? null) !== ($old_appointment['status'] ?? null));
        $time_changed = empty($old_appointment) || (($appointment['start_datetime'] ?? null) !== ($old_appointment['start_datetime'] ?? null));

        if (!$status_changed && !$time_changed) {
            return [
                'success' => false,
                'message' => 'No relevant changes (status/time), no message sent',
                'log_id' => null,
            ];
        }

        return $this->send($appointment['id'], $appointment['template_id'] ?? null, 'onUpdate', false, $time_changed);
    }

    /**
     * Send manual WhatsApp message.
     *
     * @param int $appointment_id Appointment ID.
     * @param int|null $template_id Template ID.
     * @param bool $force_send Force send even if duplicate.
     *
     * @return array Returns send result.
     */
    public function send_manual(int $appointment_id, ?int $template_id = null, bool $force_send = true): array
    {
        return $this->send($appointment_id, $template_id, 'manual', $force_send);
    }

    /**
     * Send WhatsApp message with custom text.
     *
     * @param int $appointment_id Appointment ID.
     * @param string $message_body Custom message body.
     *
     * @return array Returns send result.
     */
    public function send_custom_message(int $appointment_id, string $message_body): array
    {
        $result = [
            'success' => false,
            'message' => '',
            'log_id' => null,
            'details' => [],
        ];

        try {
            // Check if integration is enabled
            if (!$this->is_integration_enabled()) {
                $result['message'] = 'WhatsApp integration is disabled';
                return $result;
            }

            // Load appointment data
            $appointment = $this->CI->appointments_model->find($appointment_id);
            $customer = $this->CI->customers_model->find($appointment['id_users_customer']);

            // Validate customer phone
            if (empty($customer['phone_number'])) {
                $result['message'] = 'Customer phone number is required';
                return $result;
            }

            $body_hash = hash('sha256', $message_body);

            // Create log entry
            $log_id = $this->CI->whatsapp_message_logs_model->create_log_entry(
                $appointment_id,
                null,
                'Custom',
                $customer['phone_number'],
                $body_hash,
                'manual',
                [
                    'phone' => $customer['phone_number'],
                    'message' => $message_body,
                ]
            );

            $result['log_id'] = $log_id;

            // Send message
            try {
                $send_response = $this->CI->wppconnect_service->send_message(
                    $customer['phone_number'],
                    $message_body
                );

                // Update log with success
                $this->CI->whatsapp_message_logs_model->update_log_result(
                    $log_id,
                    'SUCCESS',
                    $send_response['_http_status'] ?? 200,
                    $send_response
                );

                $result['success'] = true;
                $result['message'] = 'Custom message sent successfully';

            } catch (Exception $e) {
                // Update log with failure
                $this->CI->whatsapp_message_logs_model->update_log_result(
                    $log_id,
                    'FAILURE',
                    $e->getCode(),
                    null,
                    'SEND_ERROR',
                    $e->getMessage()
                );

                $result['message'] = 'Failed to send custom message: ' . $e->getMessage();
            }

        } catch (Exception $e) {
            $result['message'] = 'Error sending custom message: ' . $e->getMessage();
        }

        return $result;
    }

    /**
     * Check if WhatsApp integration is enabled.
     *
     * @return bool
     */
    private function is_integration_enabled(): bool
    {
        try {
            $settings = $this->CI->whatsapp_integration_settings_model->get_current();
            return !empty($settings['enabled']);
        } catch (Exception $e) {
            return false;
        }
    }


    /**
     * Mask sensitive customer data for logging.
     *
     * @param array $customer Customer data.
     *
     * @return array Masked customer data.
     */
    private function mask_customer_data(array $customer): array
    {
        $masked = $customer;
        
        if (!empty($masked['phone_number'])) {
            $phone = $masked['phone_number'];
            if (strlen($phone) > 7) {
                $masked['phone_number_masked'] = substr($phone, 0, 3) . str_repeat('*', strlen($phone) - 7) . substr($phone, -4);
            } else {
                $masked['phone_number_masked'] = str_repeat('*', strlen($phone));
            }
        }

        // Remove sensitive fields
        unset($masked['notes']);
        
        return $masked;
    }

    /**
     * Get send status for appointment.
     *
     * @param int $appointment_id Appointment ID.
     * @param string|null $status_key Status key filter.
     *
     * @return array Returns send status information.
     */
    public function get_send_status(int $appointment_id, ?string $status_key = null): array
    {
        $where = ['appointment_id' => $appointment_id];
        
        if ($status_key) {
            $where['status_key'] = $status_key;
        }

        // Get logs for the appointment (model provides get_by_appointment)
        $logs = $this->CI->whatsapp_message_logs_model->get_by_appointment($appointment_id);
        // If a status_key filter was provided, apply it on the results
        if ($status_key) {
            $logs = array_values(array_filter($logs, function($l) use ($status_key) {
                return (($l['status_key'] ?? '') === $status_key);
            }));
        }
        
        $status = [
            'last_sent' => null,
            'total_sent' => 0,
            'success_count' => 0,
            'failure_count' => 0,
            'recent_logs' => array_slice($logs, 0, 5), // Last 5 logs
        ];

        foreach ($logs as $log) {
            if ($log['result'] === 'SUCCESS') {
                $status['success_count']++;
                if (!$status['last_sent']) {
                    $status['last_sent'] = $log['create_datetime'];
                }
            } elseif ($log['result'] === 'FAILURE') {
                $status['failure_count']++;
            }
            $status['total_sent']++;
        }

        return $status;
    }

    /**
     * Check if WhatsApp can be sent for appointment.
     *
     * @param int $appointment_id Appointment ID.
     * @param string $send_type Send type.
     *
     * @return array Returns availability check result.
     */
    public function can_send(int $appointment_id, string $send_type = 'manual'): array
    {
        $result = [
            'can_send' => false,
            'message' => '',
            'details' => [],
        ];

        try {
            // Check if integration is enabled
            if (!$this->is_integration_enabled()) {
                $result['message'] = 'WhatsApp integration is disabled';
                return $result;
            }

            // Check WPPConnect service status
            if (!$this->CI->wppconnect_service->is_enabled()) {
                $result['message'] = 'WPPConnect service is not enabled';
                return $result;
            }

            // Check session status
            try {
                $status_response = $this->CI->wppconnect_service->get_status();
                $session_status = $status_response['status'] ?? 'UNKNOWN';
                
                if ($session_status !== 'CONNECTED') {
                    $result['message'] = 'WhatsApp session is not connected. Status: ' . $session_status;
                    $result['details']['session_status'] = $session_status;
                    return $result;
                }
            } catch (Exception $e) {
                $result['message'] = 'Cannot check session status: ' . $e->getMessage();
                return $result;
            }

            // Load appointment and customer
            $appointment = $this->CI->appointments_model->find($appointment_id);
            $customer = $this->CI->customers_model->find($appointment['id_users_customer']);

            // Check if customer has phone
            if (empty($customer['phone_number'])) {
                $result['message'] = 'Customer phone number is required';
                return $result;
            }

            // For automatic sends, check if template exists for the status
            if ($send_type !== 'manual') {
                $template_check = $this->CI->whatsapp_template_service->resolve_template(
                    $appointment['status'],
                    null,
                    $customer['language'] ?? config('language')
                );

                if (!$template_check) {
                    $result['message'] = 'No enabled template found for status: ' . $appointment['status'];
                    return $result;
                }
            }

            // Check if template exists
            $template = $this->CI->whatsapp_template_service->resolve_template(
                $appointment['status'],
                null,
                $customer['language'] ?? config('language')
            );

            if (!$template) {
                $result['message'] = 'No template found for status: ' . $appointment['status'];
                return $result;
            }

            $result['can_send'] = true;
            $result['message'] = 'Ready to send';
            $result['details'] = [
                'session_status' => 'CONNECTED',
                'template' => $template,
                'customer_phone' => $this->mask_customer_data($customer)['phone_number_masked'] ?? '',
            ];

        } catch (Exception $e) {
            $result['message'] = 'Error checking send availability: ' . $e->getMessage();
        }

        return $result;
    }

    /**
     * Get sending statistics.
     *
     * @param array $filters Optional filters.
     *
     * @return array Returns sending statistics.
     */
    public function get_statistics(array $filters = []): array
    {
        $stats = [
            'total_sent' => 0,
            'success_count' => 0,
            'failure_count' => 0,
            'pending_count' => 0,
            'by_status' => [],
            'by_send_type' => [],
            'recent_activity' => [],
        ];

        try {
            // Get all logs with filters
            $logs = $this->CI->whatsapp_message_logs_model->get_paginated(1, 1000, $filters);
            
            foreach ($logs['data'] as $log) {
                $stats['total_sent']++;
                
                switch ($log['result']) {
                    case 'SUCCESS':
                        $stats['success_count']++;
                        break;
                    case 'FAILURE':
                        $stats['failure_count']++;
                        break;
                    case 'PENDING':
                        $stats['pending_count']++;
                        break;
                }

                // Group by status
                $status = $log['status_key'] ?? 'Unknown';
                if (!isset($stats['by_status'][$status])) {
                    $stats['by_status'][$status] = ['total' => 0, 'success' => 0, 'failure' => 0];
                }
                $stats['by_status'][$status]['total']++;
                if ($log['result'] === 'SUCCESS') {
                    $stats['by_status'][$status]['success']++;
                } elseif ($log['result'] === 'FAILURE') {
                    $stats['by_status'][$status]['failure']++;
                }

                // Group by send type
                $send_type = $log['send_type'];
                if (!isset($stats['by_send_type'][$send_type])) {
                    $stats['by_send_type'][$send_type] = 0;
                }
                $stats['by_send_type'][$send_type]++;
            }

            // Get recent activity (last 10 logs) using paginated helper
            $recent_paginated = $this->CI->whatsapp_message_logs_model->get_paginated(1, 10, []);
            $stats['recent_activity'] = $recent_paginated['data'] ?? [];

        } catch (Exception $e) {
            log_message('error', 'Error getting WhatsApp statistics: ' . $e->getMessage());
        }

        return $stats;
    }
}
