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

        // SECURITY: Validar encryption key em produção
        $this->validate_encryption_key();

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

    /**
     * Validate that encryption key is properly configured in production.
     *
     * @throws RuntimeException If encryption key is missing or invalid in production
     */
    private function validate_encryption_key(): void
    {
        // Only enforce in production (ENVIRONMENT constant is set by index.php)
        if (ENVIRONMENT !== 'production') {
            return;
        }

        $encryption_key = getenv('WA_TOKEN_ENC_KEY');

        // Check if key exists
        if (empty($encryption_key)) {
            log_message('error', 'CRITICAL: WA_TOKEN_ENC_KEY not configured in production environment');
            throw new RuntimeException(
                'WhatsApp integration requires WA_TOKEN_ENC_KEY environment variable in production. ' .
                'Generate with: openssl rand -hex 32'
            );
        }

        // Validate key format (should be hex string, minimum 32 bytes = 64 hex chars)
        $key_length = strlen($encryption_key);
        if ($key_length < 64) {
            log_message('error', "CRITICAL: WA_TOKEN_ENC_KEY too short ({$key_length} chars, need 64+)");
            throw new RuntimeException(
                "WA_TOKEN_ENC_KEY must be at least 64 characters (32 bytes). " .
                "Current length: {$key_length}. Generate with: openssl rand -hex 32"
            );
        }

        // Validate it's a valid hex string
        if (!ctype_xdigit($encryption_key)) {
            log_message('error', 'CRITICAL: WA_TOKEN_ENC_KEY contains invalid characters (not hexadecimal)');
            throw new RuntimeException(
                'WA_TOKEN_ENC_KEY must be a hexadecimal string. ' .
                'Generate with: openssl rand -hex 32'
            );
        }

        // Log success (only once per deployment)
        log_message('info', 'WhatsApp encryption key validated successfully');
    }
}
