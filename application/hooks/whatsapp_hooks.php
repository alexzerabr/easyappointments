<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * WhatsApp Hooks
 * 
 * Hooks para registrar o subscriber de WhatsApp no sistema
 */
class Whatsapp_hooks
{
    private $CI;

    public function __construct()
    {
        $this->CI = &get_instance();
    }

    /**
     * Registrar hooks após carregamento do sistema
     */
    public function register()
    {
        // Não registrar durante o processo de instalação
        if (function_exists('is_app_installed') && !is_app_installed()) {
            return;
        }

        // Garantir que o banco está pronto antes de carregar componentes da integração
        // (evita erros quando as tabelas ainda não existem em uma instalação nova)
        try {
            if (!$this->CI->db->table_exists('settings')) {
                return;
            }

            // Se as tabelas principais da integração não existem ainda, aguardar migrações
            if (!$this->CI->db->table_exists('whatsapp_integration_settings')) {
                return;
            }
        } catch (Throwable $e) {
            // Em qualquer erro de conexão/consulta, não registrar os hooks
            return;
        }

        // Registrar subscriber de WhatsApp somente quando instalado e com tabelas existentes
        $this->CI->load->library('whatsapp_appointment_subscriber');
        $this->CI->whatsapp_appointment_subscriber->register();
    }
}
