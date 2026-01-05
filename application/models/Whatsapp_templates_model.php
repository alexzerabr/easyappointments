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
 * WhatsApp Templates model.
 *
 * Handles all the database operations of the WhatsApp templates resource.
 *
 * @package Models
 */
class Whatsapp_templates_model extends EA_Model
{
    /**
     * @var array
     */
    protected array $casts = [
        'id' => 'integer',
        'enabled' => 'boolean',
    ];

    /**
     * @var array
     */
    protected array $api_resource = [
        'id' => 'id',
        'name' => 'name',
        'statusKey' => 'status_key',
        'enabled' => 'enabled',
        'language' => 'language',
        'body' => 'body',
    ];

    /**
     * Save (insert or update) a WhatsApp template.
     *
     * @param array $template Associative array with the template data.
     *
     * @return int Returns the template ID.
     *
     * @throws InvalidArgumentException
     */
    public function save(array $template): int
    {
        $this->validate($template);

        if (empty($template['id'])) {
            return $this->insert($template);
        } else {
            return $this->update($template);
        }
    }

    /**
     * Validate the WhatsApp template data.
     *
     * @param array $template Associative array with the template data.
     *
     * @throws InvalidArgumentException
     */
    public function validate(array $template): void
    {
        // If a template ID is provided then check whether the record really exists in the database.
        if (!empty($template['id'])) {
            $count = $this->db->get_where('ea_whatsapp_templates', ['id' => $template['id']])->num_rows();

            if (!$count) {
                throw new InvalidArgumentException(
                    'The provided WhatsApp template ID does not exist in the database: ' . $template['id'],
                );
            }
        }

        // Make sure all required fields are provided.
        if (empty($template['name'])) {
            throw new InvalidArgumentException('Not all required fields are provided: name');
        }

        if (empty($template['status_key'])) {
            throw new InvalidArgumentException('Not all required fields are provided: status_key');
        }

        if (empty($template['body'])) {
            throw new InvalidArgumentException('Not all required fields are provided: body');
        }
    }

    /**
     * Insert a new WhatsApp template record to the database.
     *
     * @param array $template Associative array with the template data.
     *
     * @return int Returns the template ID.
     *
     * @throws RuntimeException
     */
    protected function insert(array $template): int
    {
        $template['create_datetime'] = date('Y-m-d H:i:s');
        $template['update_datetime'] = date('Y-m-d H:i:s');

        if (!$this->db->insert('ea_whatsapp_templates', $template)) {
            throw new RuntimeException('Could not insert WhatsApp template to the database.');
        }

        return $this->db->insert_id();
    }

    /**
     * Update an existing WhatsApp template record in the database.
     *
     * @param array $template Associative array with the template data.
     *
     * @return int Returns the template ID.
     *
     * @throws RuntimeException
     */
    protected function update(array $template): int
    {
        $template['update_datetime'] = date('Y-m-d H:i:s');

        if (!$this->db->update('ea_whatsapp_templates', $template, ['id' => $template['id']])) {
            throw new RuntimeException('Could not update WhatsApp template in the database.');
        }

        return $template['id'];
    }

    /**
     * Find a specific WhatsApp template record from the database.
     *
     * @param int $template_id The template ID.
     *
     * @return array Returns an associative array with the template data.
     *
     * @throws InvalidArgumentException
     */
    public function find(int $template_id): array
    {
        if (!$template_id) {
            throw new InvalidArgumentException('The template ID argument is required.');
        }

        $template = $this->db->get_where('ea_whatsapp_templates', ['id' => $template_id])->row_array();

        if (!$template) {
            throw new InvalidArgumentException('The provided template ID was not found in the database: ' . $template_id);
        }

        $this->cast($template);

        return $template;
    }

    /**
     * Get a specific field value from the database.
     *
     * @param string $field Name of the value to be returned.
     * @param int $template_id Template ID.
     *
     * @return string Returns the selected record value from the database.
     *
     * @throws InvalidArgumentException
     */
    public function value(string $field, int $template_id): string
    {
        if (empty($field)) {
            throw new InvalidArgumentException('The field argument is required.');
        }

        if (empty($template_id)) {
            throw new InvalidArgumentException('The template ID argument is required.');
        }

        if ($this->db->get_where('ea_whatsapp_templates', ['id' => $template_id])->num_rows() == 0) {
            throw new InvalidArgumentException('The provided template ID was not found in the database: ' . $template_id);
        }

        $row = $this->db->get_where('ea_whatsapp_templates', ['id' => $template_id])->row_array();

        if (!isset($row[$field])) {
            throw new InvalidArgumentException('The requested field was not found in the database: ' . $field);
        }

        $this->cast($row);

        return $row[$field];
    }

    /**
     * Get all, or specific WhatsApp template records from the database.
     *
     * @param array|string $where Where conditions
     * @param int|null $limit Record limit.
     * @param int|null $offset Record offset.
     * @param string|null $order_by Order by.
     *
     * @return array Returns an array of template records.
     */
    public function get($where = null, ?int $limit = null, ?int $offset = null, ?string $order_by = null): array
    {
        if ($where !== null) {
            $this->db->where($where);
        }

        if ($order_by !== null) {
            $this->db->order_by($this->quote_order_by($order_by));
        }

        $templates = $this->db->get('ea_whatsapp_templates', $limit, $offset)->result_array();

        foreach ($templates as &$template) {
            $this->cast($template);
        }

        return $templates;
    }

    /**
     * Delete an existing WhatsApp template record from the database.
     *
     * @param int $template_id The template ID to be deleted.
     *
     * @throws RuntimeException
     */
    public function delete(int $template_id): void
    {
        if (!$template_id) {
            throw new InvalidArgumentException('The template ID argument is required.');
        }

        $count = $this->db->get_where('ea_whatsapp_templates', ['id' => $template_id])->num_rows();

        if (!$count) {
            throw new InvalidArgumentException('The provided template ID was not found in the database: ' . $template_id);
        }

        $this->db->delete('ea_whatsapp_templates', ['id' => $template_id]);
    }

    /**
     * Get templates by status key.
     *
     * @param string $status_key The status key.
     * @param bool $enabled_only Whether to return only enabled templates.
     * @param string|null $language Language filter.
     *
     * @return array Returns array of templates for the given status.
     */
    public function get_by_status(string $status_key, bool $enabled_only = true, ?string $language = null): array
    {
        $where = ['status_key' => $status_key];
        
        if ($enabled_only) {
            $where['enabled'] = 1;
        }

        if ($language) {
            $where['language'] = $language;
        }

        return $this->get($where, null, null, 'name ASC');
    }

    /**
     * Get the default template for a status.
     *
     * @param string $status_key The status key.
     * @param string|null $language Language preference.
     *
     * @return array|null Returns the default template or null if not found.
     */
    public function get_default_for_status(string $status_key, ?string $language = null): ?array
    {
        $templates = $this->get_by_status($status_key, true, $language);
        
        if (empty($templates) && $language) {
            // Fallback to English if no template found for the specified language
            $templates = $this->get_by_status($status_key, true, 'en');
        }

        return !empty($templates) ? $templates[0] : null;
    }

    /**
     * Get all available status keys from templates.
     *
     * @return array Returns array of unique status keys.
     */
    public function get_status_keys(): array
    {
        $this->db->select('DISTINCT status_key');
        $this->db->where('enabled', 1);
        $result = $this->db->get('ea_whatsapp_templates')->result_array();

        return array_column($result, 'status_key');
    }

    /**
     * Get valid placeholders for both English and Portuguese.
     *
     * @return array Returns array of valid placeholders in both languages.
     */
    protected function get_valid_placeholders(): array
    {
        return [
            // English placeholders
            '{{client_name}}',
            '{{first_name}}',
            '{{phone}}',
            '{{email}}',
            '{{appointment_date}}',
            '{{appointment_time}}',
            '{{service_name}}',
            '{{location}}',
            '{{link}}',
            '{{company_name}}',

            // Portuguese (BR) placeholders
            '{{nome_cliente}}',
            '{{primeiro_nome}}',
            '{{telefone}}',
            '{{e-mail}}',
            '{{data_agendamento}}',
            '{{hora_agendamento}}',
            '{{dia_semana}}',
            '{{nome_servico}}',
            '{{local}}',
            '{{link}}', // same in both languages
            '{{nome_empresa}}',
        ];
    }

    /**
     * Validate template placeholders.
     *
     * @param string $body Template body.
     *
     * @return array Returns array of validation errors, empty if valid.
     */
    public function validate_placeholders(string $body): array
    {
        $errors = [];
        $valid_placeholders = $this->get_valid_placeholders();

        // Find all placeholders in the body
        preg_match_all('/\{\{[^}]+\}\}/', $body, $matches);
        $found_placeholders = $matches[0];

        foreach ($found_placeholders as $placeholder) {
            if (!in_array($placeholder, $valid_placeholders)) {
                $errors[] = "Invalid placeholder: $placeholder";
            }
        }

        return $errors;
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
     * @return string Returns the rendered template body.
     */
    public function render_template(
        array $template,
        array $appointment,
        array $customer,
        array $service,
        array $provider,
        ?string $language = null
    ): string {
        $body = $template['body'];
        $language = $language ?: config('language');

        // Format date and time based on language/locale
        $appointment_date = date('Y-m-d', strtotime($appointment['start_datetime']));
        $appointment_time = date('H:i', strtotime($appointment['start_datetime']));

        // Format weekday based on language/locale
        $timestamp = strtotime($appointment['start_datetime']);
        $day_number = date('w', $timestamp);
        $weekdays_pt = [
            0 => 'Domingo',
            1 => 'Segunda-feira',
            2 => 'Terça-feira',
            3 => 'Quarta-feira',
            4 => 'Quinta-feira',
            5 => 'Sexta-feira',
            6 => 'Sábado'
        ];
        $dia_semana = $weekdays_pt[$day_number];

        if ($language === 'pt-BR' || $language === 'portuguese-br') {
            $appointment_date = date('d/m/Y', strtotime($appointment['start_datetime']));
        }

        $CI = &get_instance();
        $CI->load->model('settings_model');
        $company_name = $CI->settings_model->get_setting('company_name', '');

        // Extract first name from customer
        $full_name = $customer['first_name'] . ' ' . $customer['last_name'];
        $first_name = $customer['first_name'];
        $email = $customer['email'] ?? '';
        $phone = $customer['phone_number'] ?? '';

        // English placeholders
        $placeholders_en = [
            '{{client_name}}' => $full_name,
            '{{first_name}}' => $first_name,
            '{{phone}}' => $phone,
            '{{email}}' => $email,
            '{{appointment_date}}' => $appointment_date,
            '{{appointment_time}}' => $appointment_time,
            '{{service_name}}' => $service['name'] ?? '',
            '{{location}}' => $appointment['location'] ?? $service['location'] ?? '',
            '{{link}}' => site_url('appointments/book/' . $appointment['hash']),
            '{{company_name}}' => $company_name,
        ];

        // Portuguese (BR) placeholders - same values, different keys
        $placeholders_pt = [
            '{{nome_cliente}}' => $full_name,
            '{{primeiro_nome}}' => $first_name,
            '{{telefone}}' => $phone,
            '{{e-mail}}' => $email,
            '{{data_agendamento}}' => $appointment_date,
            '{{hora_agendamento}}' => $appointment_time,
            '{{dia_semana}}' => $dia_semana,
            '{{nome_servico}}' => $service['name'] ?? '',
            '{{local}}' => $appointment['location'] ?? $service['location'] ?? '',
            '{{link}}' => site_url('appointments/book/' . $appointment['hash']),
            '{{nome_empresa}}' => $company_name,
        ];

        // Merge both placeholder sets (supports bilingual templates)
        $placeholders = array_merge($placeholders_en, $placeholders_pt);

        // Replace all placeholders
        foreach ($placeholders as $placeholder => $value) {
            $body = str_replace($placeholder, $value, $body);
        }

        return $body;
    }
}

