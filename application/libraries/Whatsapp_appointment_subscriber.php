<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * WhatsApp Appointment Subscriber
 * 
 * Subscriber que escuta eventos de agendamento e envia mensagens WhatsApp
 * com sistema de idempotência e logs
 */
class Whatsapp_appointment_subscriber
{
    private $CI;

    public function __construct()
    {
        $this->CI = &get_instance();
        $this->CI->load->model('whatsapp_integration_settings_model');
        $this->CI->load->model('whatsapp_templates_model');
        $this->CI->load->model('whatsapp_message_logs_model');
        $this->CI->load->model('appointments_model');
        $this->CI->load->model('customers_model');
        $this->CI->load->model('services_model');
        $this->CI->load->model('providers_model');
        $this->CI->load->library('wppconnect_service');
    }

    /**
     * Registrar listeners
     */
    public function register(): void
    {
        $this->CI->load->library('domain_events');
        Domain_events::listen('Appointment_saved', [$this, 'onAppointmentSaved']);
    }

    /**
     * Handler para evento AppointmentSaved
     */
    public function onAppointmentSaved(Appointment_saved $event): void
    {
        try {
            // Verificar se integração está habilitada
            $settings = $this->CI->whatsapp_integration_settings_model->get_current();
            if (!$settings) {
                log_message('info', 'WhatsApp integration not configured, skipping message send');
                return;
            }

            // Obter dados completos do agendamento
            $appointment = $this->CI->appointments_model->get_row($event->appointment_id);
            if (!$appointment) {
                log_message('error', 'Appointment not found: ' . $event->appointment_id);
                return;
            }

            // Obter dados do cliente
            $customer = $this->CI->customers_model->get_row($appointment['id_users_customer']);
            if (!$customer || empty($customer['phone_number'])) {
                log_message('info', 'Customer phone not found for appointment: ' . $event->appointment_id);
                return;
            }

            // Resolver template
            $template = $this->resolve_template($appointment, $event->action_type);
            if (!$template) {
                $this->log_no_template($event->appointment_id, $appointment['status']);
                return;
            }

            // Obter dados completos para renderização
            $service = $this->CI->services_model->get_row($appointment['id_services']);
            $provider = $this->CI->providers_model->get_row($appointment['id_users_provider']);

            // Renderizar mensagem usando o mesmo método do Whatsapp_sender
            $message = $this->CI->whatsapp_templates_model->render_template(
                $template,
                $appointment,
                $customer,
                $service,
                $provider,
                $appointment['language'] ?? 'pt-BR'
            );

            // Verificar se houve mudança de horário
            $time_changed = false;
            if ($event->old_appointment && $event->new_appointment) {
                $time_changed = ($event->old_appointment['start_datetime'] ?? null) !== ($event->new_appointment['start_datetime'] ?? null);
            }

            // Verificar idempotência (permitir reenvio se horário mudou)
            $hash = $this->CI->whatsapp_message_logs_model->generate_hash(
                $event->appointment_id,
                $template['id'],
                $event->action_type,
                $message
            );

            if (!$time_changed && $this->CI->whatsapp_message_logs_model->exists_by_hash($hash)) {
                log_message('info', 'Message already sent (idempotency): ' . $hash);
                return;
            }

            // Criar log inicial
            $this->create_message_log($hash, $event, $appointment, $template, $customer['phone_number'], $message);

            // Enviar mensagem
            $this->send_message($hash, $customer['phone_number'], $message, $event, $appointment, $template);

        } catch (Exception $e) {
            log_message('error', 'WhatsApp subscriber error: ' . $e->getMessage());
        }
    }

    /**
     * Resolver template para o agendamento
     */
    private function resolve_template(array $appointment, string $action_type): ?array
    {
        // Primeiro, tentar usar template_id se especificado
        if (!empty($appointment['template_id'])) {
            $template = $this->CI->whatsapp_templates_model->get_row($appointment['template_id']);
            if ($template && $template['enabled']) {
                return $template;
            }
        }

        // Senão, buscar por status
        $templates = $this->CI->whatsapp_templates_model->get_by_status(
            $appointment['status'],
            true, // enabled only
            $appointment['language'] ?? 'pt-BR'
        );

        return !empty($templates) ? $templates[0] : null;
    }

    /**
     * Construir contexto para renderização do template
     * @deprecated Método removido - agora usa Whatsapp_templates_model->render_template() diretamente
     */

    /**
     * Obter nome da empresa
     */
    private function get_company_name(): string
    {
        $this->CI->load->model('settings_model');
        $settings = $this->CI->settings_model->get_setting('company_name');
        return $settings ?: 'EasyAppointments';
    }

    /**
     * Gerar link do agendamento
     */
    private function generate_appointment_link(string $hash): string
    {
        if (empty($hash)) {
            return '';
        }
        
        $base_url = rtrim($this->CI->config->item('base_url'), '/');
        return $base_url . '/index.php/appointments/index/' . $hash;
    }

    /**
     * Criar log de mensagem
     */
    private function create_message_log(string $hash, Appointment_saved $event, array $appointment, array $template, string $phone, string $message): void
    {
        $log_data = [
            'body_hash' => $hash,
            'appointment_id' => $event->appointment_id,
            'template_id' => $template['id'],
            'status_key' => $appointment['status'],
            'to_phone' => $this->mask_phone($phone),
            'send_type' => $event->action_type,
            'provider' => 'wppconnect',
            'result' => 'PENDING',
            'request_payload' => json_encode(['phone' => $phone, 'message' => $message])
        ];

        $this->CI->whatsapp_message_logs_model->save($log_data);
    }

    /**
     * Enviar mensagem via WPPConnect
     */
    private function send_message(string $hash, string $phone, string $message, Appointment_saved $event, array $appointment, array $template): void
    {
        try {
            $response = $this->CI->wppconnect_service->send_message(
                $phone,
                $message
            );

            // Atualizar log com sucesso
            $this->CI->whatsapp_message_logs_model->update_status(
                $hash,
                'SUCCESS',
                [
                    'update_datetime' => date('Y-m-d H:i:s'),
                    'http_status' => $response['_http_status'] ?? 200,
                    'response_payload' => is_string($response) ? $response : json_encode($response)
                ]
            );

            log_message('info', 'WhatsApp message sent successfully for appointment: ' . $event->appointment_id);

        } catch (Exception $e) {
            // Atualizar log com falha
            $this->CI->whatsapp_message_logs_model->update_status(
                $hash,
                'FAILURE',
                [
                    'update_datetime' => date('Y-m-d H:i:s'),
                    'error_message' => $e->getMessage(),
                    'error_code' => 'SEND_ERROR'
                ]
            );

            log_message('error', 'WhatsApp send failed for appointment ' . $event->appointment_id . ': ' . $e->getMessage());
        }
    }

    /**
     * Log quando não há template
     */
    private function log_no_template(int $appointment_id, string $status): void
    {
        $log_data = [
            'body_hash' => 'no_template_' . $appointment_id . '_' . time(),
            'appointment_id' => $appointment_id,
            'template_id' => 0,
            'status_key' => $status,
            'to_phone' => '',
            'send_type' => 'no_template',
            'provider' => 'wppconnect',
            'result' => 'NO_TEMPLATE',
            'error_message' => 'No template found for status: ' . $status
        ];

        $this->CI->whatsapp_message_logs_model->save($log_data);
        log_message('info', 'No WhatsApp template found for appointment ' . $appointment_id . ' with status: ' . $status);
    }

    /**
     * Mascarar telefone para logs
     */
    private function mask_phone(string $phone): string
    {
        if (strlen($phone) < 8) {
            return $phone;
        }
        
        $prefix = substr($phone, 0, 3);
        $suffix = substr($phone, -4);
        $masked = str_repeat('*', strlen($phone) - 7);
        
        return $prefix . $masked . $suffix;
    }
}
