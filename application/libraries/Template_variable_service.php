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
                'key' => 'nome_cliente',
                'display' => '{{nome_cliente}}',
                'example' => 'Maria Silva',
                'source' => 'client',
                'description' => 'Nome completo do cliente'
            ],
            [
                'key' => 'primeiro_nome',
                'display' => '{{primeiro_nome}}',
                'example' => 'Maria',
                'source' => 'client',
                'description' => 'Primeiro nome do cliente'
            ],
            [
                'key' => 'telefone',
                'display' => '{{telefone}}',
                'example' => '+55 11 91234-5678',
                'source' => 'client',
                'description' => 'Telefone do cliente'
            ],
            [
                'key' => 'e-mail',
                'display' => '{{e-mail}}',
                'example' => 'maria@example.com',
                'source' => 'client',
                'description' => 'E-mail do cliente'
            ],
            [
                'key' => 'data_agendamento',
                'display' => '{{data_agendamento}}',
                'example' => '15/10/2025',
                'source' => 'appointment',
                'description' => 'Data do agendamento'
            ],
            [
                'key' => 'hora_agendamento',
                'display' => '{{hora_agendamento}}',
                'example' => '14:30',
                'source' => 'appointment',
                'description' => 'Horário do agendamento'
            ],
            [
                'key' => 'dia_semana',
                'display' => '{{dia_semana}}',
                'example' => 'Segunda-feira',
                'source' => 'appointment',
                'description' => 'Dia da semana do agendamento'
            ],
            [
                'key' => 'nome_servico',
                'display' => '{{nome_servico}}',
                'example' => 'Consulta Clínica',
                'source' => 'service',
                'description' => 'Nome do serviço'
            ],
            [
                'key' => 'local',
                'display' => '{{local}}',
                'example' => 'Av. Paulista, 1000',
                'source' => 'location',
                'description' => 'Local do atendimento'
            ],
            [
                'key' => 'nome_empresa',
                'display' => '{{nome_empresa}}',
                'example' => $this->get_company_name(),
                'source' => 'company',
                'description' => 'Nome da empresa'
            ],
            [
                'key' => 'link',
                'display' => '{{link}}',
                'example' => 'https://exemplo.com/confirmar/abc',
                'source' => 'app',
                'description' => 'Link do agendamento'
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
            // English variables
            'client_name' => 'Maria Silva',
            'first_name' => 'Maria',
            'phone' => '+55 11 91234-5678',
            'email' => 'maria@example.com',
            'appointment_date' => $this->format_date($sample_date, 'en'),
            'appointment_time' => $this->format_time($sample_date, 'en'),
            'dia_semana' => $this->format_weekday($sample_date, 'pt-BR'),
            'service_name' => 'Consulta Clínica',
            'location' => 'Av. Paulista, 1000',
            'company_name' => $this->get_company_name(),
            'link' => 'https://exemplo.com/confirmar/abc123',

            // Portuguese (BR) variables
            'nome_cliente' => 'Maria Silva',
            'primeiro_nome' => 'Maria',
            'telefone' => '+55 11 91234-5678',
            'e-mail' => 'maria@example.com',
            'data_agendamento' => $this->format_date($sample_date, 'pt-BR'),
            'hora_agendamento' => $this->format_time($sample_date, 'pt-BR'),
            'nome_servico' => 'Consulta Clínica',
            'local' => 'Av. Paulista, 1000',
            'nome_empresa' => $this->get_company_name()
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
     * Formata dia da semana conforme locale
     */
    private function format_weekday($date, $locale = 'pt-BR') {
        $timestamp = strtotime($date);
        $day_number = date('w', $timestamp); // 0 (domingo) a 6 (sábado)

        if ($locale === 'pt-BR') {
            $weekdays = [
                0 => 'Domingo',
                1 => 'Segunda-feira',
                2 => 'Terça-feira',
                3 => 'Quarta-feira',
                4 => 'Quinta-feira',
                5 => 'Sexta-feira',
                6 => 'Sábado'
            ];
            return $weekdays[$day_number];
        }

        // Para outros locales, retorna em inglês
        return date('l', $timestamp);
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
            $full_name = trim(($customer['first_name'] ?? '') . ' ' . ($customer['last_name'] ?? ''));
            $first_name = $customer['first_name'] ?? '';
            $email = $customer['email'] ?? '';
            $phone = $customer['phone_number'] ?? '';

            return [
                // English variables
                'client_name' => $full_name,
                'first_name' => $first_name,
                'phone' => $phone,
                'email' => $email,
                'appointment_date' => $this->format_date($appointment['start_datetime'], 'en'),
                'appointment_time' => $this->format_time($appointment['start_datetime'], 'en'),
                'dia_semana' => $this->format_weekday($appointment['start_datetime'], 'pt-BR'),
                'service_name' => $service['name'] ?? '',
                'location' => $provider['address'] ?? '',
                'company_name' => $this->get_company_name(),
                'link' => $this->generate_appointment_link($appointment_id),

                // Portuguese (BR) variables
                'nome_cliente' => $full_name,
                'primeiro_nome' => $first_name,
                'telefone' => $phone,
                'e-mail' => $email,
                'data_agendamento' => $this->format_date($appointment['start_datetime'], 'pt-BR'),
                'hora_agendamento' => $this->format_time($appointment['start_datetime'], 'pt-BR'),
                'nome_servico' => $service['name'] ?? '',
                'local' => $provider['address'] ?? '',
                'nome_empresa' => $this->get_company_name()
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
