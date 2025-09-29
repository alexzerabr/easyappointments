<?php
defined('BASEPATH') OR exit('No direct script access allowed');

/**
 * Template Variable Service
 * 
 * Gerencia as variáveis disponíveis para templates WhatsApp
 */
class Template_variable_service {
    
    private $CI;
    
    public function __construct() {
        $this->CI = &get_instance();
        $this->CI->load->model('settings_model');
    }
    
    /**
     * Obtém o catálogo completo de variáveis disponíveis
     */
    public function get_catalog() {
        return [
            [
                'key' => 'client_name',
                'display' => '{{client_name}}',
                'example' => 'Maria Silva',
                'source' => 'client',
                'description' => 'Nome do cliente'
            ],
            [
                'key' => 'phone',
                'display' => '{{phone}}',
                'example' => '+55 11 91234-5678',
                'source' => 'client',
                'description' => 'Telefone do cliente'
            ],
            [
                'key' => 'appointment_date',
                'display' => '{{appointment_date}}',
                'example' => '15/10/2025',
                'source' => 'appointment',
                'description' => 'Data do agendamento'
            ],
            [
                'key' => 'appointment_time',
                'display' => '{{appointment_time}}',
                'example' => '14:30',
                'source' => 'appointment',
                'description' => 'Horário do agendamento'
            ],
            [
                'key' => 'service_name',
                'display' => '{{service_name}}',
                'example' => 'Consulta Clínica',
                'source' => 'service',
                'description' => 'Nome do serviço'
            ],
            [
                'key' => 'location',
                'display' => '{{location}}',
                'example' => 'Av. Paulista, 1000',
                'source' => 'location',
                'description' => 'Localização do atendimento'
            ],
            [
                'key' => 'link',
                'display' => '{{link}}',
                'example' => 'https://exemplo.com/confirmar/abc',
                'source' => 'app',
                'description' => 'Link do agendamento'
            ],
            [
                'key' => 'company_name',
                'display' => '{{company_name}}',
                'example' => $this->get_company_name(),
                'source' => 'company',
                'description' => 'Nome da empresa'
            ]
        ];
    }
    
    /**
     * Obtém o nome da empresa das configurações
     */
    private function get_company_name() {
        try {
            $this->CI->load->helper('setting');
            $company_name = setting('company_name');
            return $company_name ?: 'Sua Empresa';
        } catch (Exception $e) {
            return 'Sua Empresa';
        }
    }
    
    /**
     * Extrai todas as variáveis de um texto de template
     */
    public function extract_variables($text) {
        $pattern = '/\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}/';
        preg_match_all($pattern, $text, $matches);
        return array_unique($matches[1] ?? []);
    }
    
    /**
     * Valida se todas as variáveis do texto estão no catálogo
     */
    public function validate_variables($text) {
        $extracted = $this->extract_variables($text);
        $catalog = $this->get_catalog();
        $valid_keys = array_column($catalog, 'key');
        
        $invalid = array_diff($extracted, $valid_keys);
        
        return [
            'valid' => empty($invalid),
            'invalid_variables' => $invalid,
            'valid_variables' => array_intersect($extracted, $valid_keys)
        ];
    }
    
    /**
     * Renderiza um template com contexto seguro
     */
    public function render_template($text, $context = []) {
        $pattern = '/\{\{\s*([a-zA-Z0-9_.-]+)\s*\}\}/';
        
        return preg_replace_callback($pattern, function($matches) use ($context) {
            $key = $matches[1];
            $value = $this->get_nested_value($context, $key);
            
            // Se valor não existe ou está vazio, retorna —
            if ($value === null || $value === '' || $value === 'undefined') {
                return '—';
            }
            
            return (string) $value;
        }, $text);
    }
    
    /**
     * Obtém valor aninhado de um array usando notação de ponto
     */
    private function get_nested_value($array, $key) {
        $keys = explode('.', $key);
        $value = $array;
        
        foreach ($keys as $k) {
            if (!is_array($value) || !array_key_exists($k, $value)) {
                return null;
            }
            $value = $value[$k];
        }
        
        return $value;
    }
    
    /**
     * Cria contexto de exemplo para preview
     */
    public function create_preview_context($locale = 'pt-BR') {
        $sample_date = date('Y-m-d H:i:s', strtotime('+1 day'));
        
        return [
            'client_name' => 'Maria Silva',
            'phone' => '+55 11 91234-5678',
            'appointment_date' => $this->format_date($sample_date, $locale),
            'appointment_time' => $this->format_time($sample_date, $locale),
            'service_name' => 'Consulta Clínica',
            'location' => 'Av. Paulista, 1000',
            'link' => 'https://exemplo.com/confirmar/abc123',
            'company_name' => $this->get_company_name()
        ];
    }
    
    /**
     * Formata data conforme locale
     */
    private function format_date($date, $locale = 'pt-BR') {
        if ($locale === 'pt-BR') {
            return date('d/m/Y', strtotime($date));
        }
        return date('Y-m-d', strtotime($date));
    }
    
    /**
     * Formata hora conforme locale
     */
    private function format_time($date, $locale = 'pt-BR') {
        return date('H:i', strtotime($date));
    }
    
    /**
     * Cria contexto real para envio de mensagem
     */
    public function create_real_context($appointment_id) {
        try {
            $this->CI->load->model('appointments_model');
            $this->CI->load->model('customers_model');
            $this->CI->load->model('services_model');
            $this->CI->load->model('providers_model');
            
            $appointment = $this->CI->appointments_model->find($appointment_id);
            if (!$appointment) {
                return [];
            }
            
            $customer = $this->CI->customers_model->find($appointment['id_users_customer']);
            $service = $this->CI->services_model->find($appointment['id_services']);
            $provider = $this->CI->providers_model->find($appointment['id_users_provider']);
            
            $locale = $this->get_current_locale();
            
            return [
                'client_name' => trim(($customer['first_name'] ?? '') . ' ' . ($customer['last_name'] ?? '')),
                'phone' => $customer['phone_number'] ?? '',
                'appointment_date' => $this->format_date($appointment['start_datetime'], $locale),
                'appointment_time' => $this->format_time($appointment['start_datetime'], $locale),
                'service_name' => $service['name'] ?? '',
                'location' => $provider['address'] ?? '',
                'link' => $this->generate_appointment_link($appointment_id),
                'company_name' => $this->get_company_name()
            ];
        } catch (Exception $e) {
            log_message('error', 'Template Variable Service - Error creating real context: ' . $e->getMessage());
            return [];
        }
    }
    
    /**
     * Gera link do agendamento
     */
    private function generate_appointment_link($appointment_id) {
        $base_url = base_url();
        return $base_url . 'index.php/appointments/view/' . $appointment_id;
    }
    
    /**
     * Obtém locale atual
     */
    private function get_current_locale() {
        try {
            $locale = $this->CI->settings_model->get_setting('default_language');
            return $locale ?: 'pt-BR';
        } catch (Exception $e) {
            return 'pt-BR';
        }
    }
}
