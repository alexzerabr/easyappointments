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

if (!function_exists('whatsapp_after_appointment_save')) {
    /**
     * Hook called after appointment is saved.
     *
     * @param array $appointment Appointment data.
     * @param array|null $old_appointment Old appointment data (for updates).
     * @param bool $is_new Whether this is a new appointment.
     */
    function whatsapp_after_appointment_save(array $appointment, ?array $old_appointment = null, bool $is_new = true): void
    {
        try {
            $CI = &get_instance();
            
            // Load required libraries
            $CI->load->library('whatsapp_sender');
            $CI->load->model('whatsapp_integration_settings_model');

            // Check if WhatsApp integration is configured
            $settings = $CI->whatsapp_integration_settings_model->get_current();
            if (empty($settings)) {
                log_message('info', 'WhatsApp hook: No integration settings found');
                return;
            }

            // Skip if no customer phone number
            if (empty($appointment['id_users_customer'])) {
                return;
            }

            $CI->load->model('customers_model');
            $customer = $CI->customers_model->find($appointment['id_users_customer']);
            
            if (empty($customer['phone_number'])) {
                log_message('info', 'WhatsApp hook: Skipping appointment ' . $appointment['id'] . ' - no customer phone number');
                return;
            }

            // Determine send action
            if ($is_new) {
                $result = $CI->whatsapp_sender->send_on_create($appointment);
            } else {
                $result = $CI->whatsapp_sender->send_on_update($appointment, $old_appointment ?? []);
            }

            if ($result['success']) {
                log_message('info', 'WhatsApp hook: Message sent successfully for appointment ' . $appointment['id']);
            } else {
                log_message('warning', 'WhatsApp hook: Failed to send message for appointment ' . $appointment['id'] . ': ' . $result['message']);
            }

        } catch (Exception $e) {
            log_message('error', 'WhatsApp hook error: ' . $e->getMessage());
        }
    }
}

if (!function_exists('register_whatsapp_hooks')) {
    /**
     * Register WhatsApp hooks in the application.
     */
    function register_whatsapp_hooks(): void
    {
        $CI = &get_instance();
        
        // Add hooks to appointments model save operations
        add_appointment_save_hook('whatsapp_after_appointment_save');
    }
}

if (!function_exists('add_appointment_save_hook')) {
    /**
     * Add a hook to be called after appointment save.
     *
     * @param string $hook_function Function name to call.
     */
    function add_appointment_save_hook(string $hook_function): void
    {
        if (!function_exists('get_appointment_save_hooks')) {
            // Initialize hooks storage
            $GLOBALS['appointment_save_hooks'] = $GLOBALS['appointment_save_hooks'] ?? [];
        }
        
        $GLOBALS['appointment_save_hooks'][] = $hook_function;
    }
}

if (!function_exists('get_appointment_save_hooks')) {
    /**
     * Get all registered appointment save hooks.
     *
     * @return array
     */
    function get_appointment_save_hooks(): array
    {
        return $GLOBALS['appointment_save_hooks'] ?? [];
    }
}

if (!function_exists('trigger_appointment_save_hooks')) {
    /**
     * Trigger all registered appointment save hooks.
     *
     * @param array $appointment Appointment data.
     * @param array|null $old_appointment Old appointment data.
     * @param bool $is_new Whether this is a new appointment.
     */
    function trigger_appointment_save_hooks(array $appointment, ?array $old_appointment = null, bool $is_new = true): void
    {
        $hooks = get_appointment_save_hooks();

        foreach ($hooks as $hook_function) {
            if (function_exists($hook_function)) {
                try {
                    call_user_func($hook_function, $appointment, $old_appointment, $is_new);
                } catch (Exception $e) {
                    log_message('error', 'Hook execution error (' . $hook_function . '): ' . $e->getMessage());
                }
            }
        }
    }
}

if (!function_exists('mask_phone_number')) {
    /**
     * Mask a phone number for privacy/logging purposes.
     *
     * Shows first 3 and last 4 characters, masks the middle with asterisks.
     * For short numbers (< 8 chars), masks all characters.
     *
     * Examples:
     * - "5511999998888" → "551****8888"
     * - "999998888" → "999****8888"
     * - "12345" → "*****"
     *
     * @param string $phone Phone number to mask
     * @return string Masked phone number
     */
    function mask_phone_number(string $phone): string
    {
        if (empty($phone)) {
            return '';
        }

        $length = strlen($phone);

        // For very short numbers, mask everything
        if ($length < 8) {
            return str_repeat('*', $length);
        }

        // Standard masking: first 3 chars + asterisks + last 4 chars
        $prefix = substr($phone, 0, 3);
        $suffix = substr($phone, -4);
        $masked_middle = str_repeat('*', $length - 7);

        return $prefix . $masked_middle . $suffix;
    }
}

