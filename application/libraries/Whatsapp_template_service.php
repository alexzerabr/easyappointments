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
 * WhatsApp Template Service library.
 *
 * Handles template management and rendering for WhatsApp messages.
 *
 * @package Libraries
 */
class Whatsapp_template_service
{
    /**
     * @var EA_Controller|CI_Controller
     */
    protected EA_Controller|CI_Controller $CI;

    /**
     * WhatsApp Template Service constructor.
     */
    public function __construct()
    {
        $this->CI = &get_instance();
        $this->CI->load->model('whatsapp_templates_model');
        $this->CI->load->library('timezones');
    }

    /**
     * Get templates by status key.
     *
     * @param string $status_key Status key.
     * @param bool $enabled_only Whether to return only enabled templates.
     * @param string|null $language Language filter.
     *
     * @return array Returns array of templates.
     */
    public function get_by_status(string $status_key, bool $enabled_only = true, ?string $language = null): array
    {
        return $this->CI->whatsapp_templates_model->get_by_status($status_key, $enabled_only, $language);
    }

    /**
     * Resolve template for appointment.
     *
     * @param string $status_key Status key.
     * @param int|null $selected_template_id Explicitly selected template ID.
     * @param string|null $language Language preference.
     *
     * @return array|null Returns resolved template or null if not found.
     */
    public function resolve_template(string $status_key, ?int $selected_template_id = null, ?string $language = null): ?array
    {
        // If template is explicitly selected, use it
        if ($selected_template_id) {
            try {
                $template = $this->CI->whatsapp_templates_model->find($selected_template_id);
                if ($template['enabled']) {
                    return $template;
                }
            } catch (Exception $e) {
                // Template not found or disabled, fall back to default
                log_message('warning', 'Selected WhatsApp template not found or disabled: ' . $selected_template_id);
            }
        }

        // Fall back to default template for status
        return $this->CI->whatsapp_templates_model->get_default_for_status($status_key, $language);
    }

    /**
     * Render template with appointment data.
     *
     * @param array $template Template data.
     * @param array $appointment Appointment data.
     * @param array $customer Customer data.
     * @param array $service Service data.
     * @param array $provider Provider data.
     * @param string|null $language Language for formatting.
     *
     * @return string Returns rendered message.
     */
    public function render_template(
        array $template,
        array $appointment,
        array $customer,
        array $service,
        array $provider,
        ?string $language = null
    ): string {
        return $this->CI->whatsapp_templates_model->render_template(
            $template,
            $appointment,
            $customer,
            $service,
            $provider,
            $language
        );
    }

    /**
     * Get all available status keys.
     *
     * @return array Returns array of status options.
     */
    public function get_available_statuses(): array
    {
        try {
            $this->CI->load->model('settings_model');
            $status_setting = $this->CI->settings_model->get(['name' => 'appointment_status_options']);
            
            if (!empty($status_setting[0]['value'])) {
                $status_options = json_decode($status_setting[0]['value'], true);
                if (is_array($status_options)) {
                    $statuses = [];
                    foreach ($status_options as $status) {
                        $statuses[] = [
                            'key' => $status,
                            'label' => $status,
                        ];
                    }
                    return $statuses;
                }
            }
        } catch (Exception $e) {
            log_message('error', 'Failed to load appointment status options: ' . $e->getMessage());
        }

        // Fallback to default statuses if setting not found
        return [
            ['key' => 'Booked', 'label' => 'Booked'],
            ['key' => 'Confirmado', 'label' => 'Confirmado'],
            ['key' => 'Remarcado', 'label' => 'Remarcado'],
            ['key' => 'Cancelled', 'label' => 'Cancelled'],
            ['key' => 'Draft', 'label' => 'Draft'],
        ];
    }

    /**
     * Validate template data.
     *
     * @param array $template Template data.
     *
     * @return array Returns validation errors, empty if valid.
     */
    public function validate_template(array $template): array
    {
        $errors = [];

        // Required fields
        if (empty($template['name'])) {
            $errors[] = 'Template name is required';
        }

        if (empty($template['status_key'])) {
            $errors[] = 'Status key is required';
        }

        if (empty($template['body'])) {
            $errors[] = 'Template body is required';
        }

        // Validate status key
        if (!empty($template['status_key'])) {
            $available_statuses = $this->get_available_statuses();
            $valid_keys = array_column($available_statuses, 'key');
            
            if (!in_array($template['status_key'], $valid_keys)) {
                $errors[] = 'Invalid status key: ' . $template['status_key'];
            }
        }

        // Validate placeholders
        if (!empty($template['body'])) {
            $placeholder_errors = $this->CI->whatsapp_templates_model->validate_placeholders($template['body']);
            $errors = array_merge($errors, $placeholder_errors);
        }

        // Validate language code
        if (!empty($template['language'])) {
            $valid_languages = ['en', 'pt-BR', 'es', 'fr', 'de', 'it'];
            if (!in_array($template['language'], $valid_languages)) {
                $errors[] = 'Invalid language code: ' . $template['language'];
            }
        }

        return $errors;
    }

    /**
     * Get template preview with sample data.
     *
     * @param array $template Template data.
     * @param string|null $language Language for formatting.
     *
     * @return string Returns preview text.
     */
    public function get_template_preview(array $template, ?string $language = null): string
    {
        $language = $language ?: config('language');

        // Sample data
        $sample_appointment = [
            'start_datetime' => date('Y-m-d H:i:s', strtotime('+1 day 10:00')),
            'location' => 'Main Office',
            'hash' => 'sample123',
        ];

        $sample_customer = [
            'first_name' => 'John',
            'last_name' => 'Doe',
            'phone_number' => '+5511999999999',
            'email' => 'john.doe@example.com',
        ];

        $sample_service = [
            'name' => 'Consultation',
            'location' => 'Room 101',
        ];

        $sample_provider = [
            'first_name' => 'Dr. Jane',
            'last_name' => 'Smith',
        ];

        return $this->render_template(
            $template,
            $sample_appointment,
            $sample_customer,
            $sample_service,
            $sample_provider,
            $language
        );
    }

    /**
     * Get available placeholders.
     *
     * @return array Returns array of placeholder information.
     */
    public function get_available_placeholders(): array
    {
        return [
            [
                'placeholder' => '{{nome_cliente}}',
                'description' => 'Nome completo do cliente',
                'example' => 'João Silva',
            ],
            [
                'placeholder' => '{{primeiro_nome}}',
                'description' => 'Apenas o primeiro nome do cliente',
                'example' => 'João',
            ],
            [
                'placeholder' => '{{telefone}}',
                'description' => 'Número de telefone do cliente',
                'example' => '+5511999999999',
            ],
            [
                'placeholder' => '{{e-mail}}',
                'description' => 'Endereço de e-mail do cliente',
                'example' => 'joao.silva@exemplo.com.br',
            ],
            [
                'placeholder' => '{{data_agendamento}}',
                'description' => 'Data do agendamento',
                'example' => '15/01/2024',
            ],
            [
                'placeholder' => '{{hora_agendamento}}',
                'description' => 'Horário do agendamento',
                'example' => '10:00',
            ],
            [
                'placeholder' => '{{dia_semana}}',
                'description' => 'Dia da semana do agendamento',
                'example' => 'Segunda-feira',
            ],
            [
                'placeholder' => '{{nome_servico}}',
                'description' => 'Nome do serviço',
                'example' => 'Consulta',
            ],
            [
                'placeholder' => '{{local}}',
                'description' => 'Local do agendamento',
                'example' => 'Escritório Principal',
            ],
            [
                'placeholder' => '{{nome_empresa}}',
                'description' => 'Nome da empresa',
                'example' => 'Minha Empresa',
            ],
            [
                'placeholder' => '{{link}}',
                'description' => 'Link de gerenciamento do agendamento',
                'example' => 'https://exemplo.com.br/appointments/book/abc123',
            ],
        ];
    }

    /**
     * Create default templates for a new status.
     *
     * @param string $status_key Status key.
     * @param string $status_label Status label.
     *
     * @return array Returns created template IDs.
     */
    // Removed: automatic creation of default templates. Users will create templates manually.

    /**
     * Get templates grouped by status.
     *
     * @param bool $enabled_only Whether to return only enabled templates.
     *
     * @return array Returns templates grouped by status key.
     */
    public function get_templates_grouped_by_status(bool $enabled_only = true): array
    {
        $where = [];
        if ($enabled_only) {
            $where['enabled'] = 1;
        }

        $templates = $this->CI->whatsapp_templates_model->get($where, null, null, 'status_key ASC, name ASC');
        $grouped = [];

        foreach ($templates as $template) {
            $grouped[$template['status_key']][] = $template;
        }

        return $grouped;
    }

    /**
     * Check if templates exist for a status.
     *
     * @param string $status_key Status key.
     *
     * @return bool Returns true if templates exist.
     */
    public function has_templates_for_status(string $status_key): bool
    {
        $templates = $this->get_by_status($status_key, true);
        return !empty($templates);
    }

    /**
     * Disable templates for orphaned statuses.
     *
     * @param array $valid_status_keys Array of valid status keys.
     *
     * @return int Returns number of templates disabled.
     */
    public function disable_orphaned_templates(array $valid_status_keys): int
    {
        $all_templates = $this->CI->whatsapp_templates_model->get(['enabled' => 1]);
        $disabled_count = 0;

        foreach ($all_templates as $template) {
            if (!in_array($template['status_key'], $valid_status_keys)) {
                $template['enabled'] = 0;
                $this->CI->whatsapp_templates_model->save($template);
                $disabled_count++;
                
                log_message('info', 'Disabled orphaned WhatsApp template: ' . $template['name'] . ' (status: ' . $template['status_key'] . ')');
            }
        }

        return $disabled_count;
    }

    /**
     * Get template statistics.
     *
     * @return array Returns template statistics.
     */
    public function get_template_statistics(): array
    {
        $all_templates = $this->CI->whatsapp_templates_model->get();
        $enabled_templates = $this->CI->whatsapp_templates_model->get(['enabled' => 1]);
        
        $stats = [
            'total' => count($all_templates),
            'enabled' => count($enabled_templates),
            'disabled' => count($all_templates) - count($enabled_templates),
            'by_status' => [],
            'by_language' => [],
        ];

        // Group by status
        foreach ($enabled_templates as $template) {
            $status = $template['status_key'];
            if (!isset($stats['by_status'][$status])) {
                $stats['by_status'][$status] = 0;
            }
            $stats['by_status'][$status]++;
        }

        // Group by language
        foreach ($enabled_templates as $template) {
            $language = $template['language'] ?: 'default';
            if (!isset($stats['by_language'][$language])) {
                $stats['by_language'][$language] = 0;
            }
            $stats['by_language'][$language]++;
        }

        return $stats;
    }
}
