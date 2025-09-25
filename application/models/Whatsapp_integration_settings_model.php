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
 * WhatsApp Integration Settings model.
 *
 * Handles all the database operations of the WhatsApp integration settings resource.
 *
 * @package Models
 */
class Whatsapp_integration_settings_model extends EA_Model
{
    /**
     * @var array
     */
    protected array $casts = [
        'id' => 'integer',
        'port' => 'integer',
        'enabled' => 'boolean',
    ];

    /**
     * @var array
     */
    protected array $api_resource = [
        'id' => 'id',
        'host' => 'host',
        'port' => 'port',
        'session' => 'session',
        'enabled' => 'enabled',
    ];

    /**
     * Save (insert or update) WhatsApp integration settings.
     *
     * @param array $settings Associative array with the settings data.
     *
     * @return int Returns the settings ID.
     *
     * @throws InvalidArgumentException
     */
    public function save(array $settings): int
    {
        $this->validate($settings);

        if (empty($settings['id'])) {
            return $this->insert($settings);
        } else {
            return $this->update($settings);
        }
    }

    /**
     * Validate the WhatsApp integration settings data.
     *
     * @param array $settings Associative array with the settings data.
     *
     * @throws InvalidArgumentException
     */
    public function validate(array $settings): void
    {
        // If a settings ID is provided then check whether the record really exists in the database.
        if (!empty($settings['id'])) {
            $count = $this->db->get_where('whatsapp_integration_settings', ['id' => $settings['id']])->num_rows();

            if (!$count) {
                throw new InvalidArgumentException(
                    'The provided WhatsApp integration settings ID does not exist in the database: ' . $settings['id'],
                );
            }
        }

        // Make sure all required fields are provided.
        if (empty($settings['host'])) {
            throw new InvalidArgumentException('Not all required fields are provided: host');
        }

        if (empty($settings['port'])) {
            throw new InvalidArgumentException('Not all required fields are provided: port');
        }

        if (empty($settings['session'])) {
            throw new InvalidArgumentException('Not all required fields are provided: session');
        }
    }

    /**
     * Insert a new WhatsApp integration settings record to the database.
     *
     * @param array $settings Associative array with the settings data.
     *
     * @return int Returns the settings ID.
     *
     * @throws RuntimeException
     */
    protected function insert(array $settings): int
    {
        $settings['create_datetime'] = date('Y-m-d H:i:s');
        $settings['update_datetime'] = date('Y-m-d H:i:s');

        if (!$this->db->insert('whatsapp_integration_settings', $settings)) {
            throw new RuntimeException('Could not insert WhatsApp integration settings to the database.');
        }

        return $this->db->insert_id();
    }

    /**
     * Update an existing WhatsApp integration settings record in the database.
     *
     * @param array $settings Associative array with the settings data.
     *
     * @return int Returns the settings ID.
     *
     * @throws RuntimeException
     */
    protected function update(array $settings): int
    {
        $settings['update_datetime'] = date('Y-m-d H:i:s');

        if (!$this->db->update('whatsapp_integration_settings', $settings, ['id' => $settings['id']])) {
            throw new RuntimeException('Could not update WhatsApp integration settings in the database.');
        }

        return $settings['id'];
    }

    /**
     * Find a specific WhatsApp integration settings record from the database.
     *
     * @param int $settings_id The settings ID.
     *
     * @return array Returns an associative array with the settings data.
     *
     * @throws InvalidArgumentException
     */
    public function find(int $settings_id): array
    {
        if (!$settings_id) {
            throw new InvalidArgumentException('The settings ID argument is required.');
        }

        $settings = $this->db->get_where('whatsapp_integration_settings', ['id' => $settings_id])->row_array();

        if (!$settings) {
            throw new InvalidArgumentException('The provided settings ID was not found in the database: ' . $settings_id);
        }

        $this->cast($settings);

        return $settings;
    }

    /**
     * Get a specific field value from the database.
     *
     * @param string $field Name of the value to be returned.
     * @param int $settings_id Settings ID.
     *
     * @return string Returns the selected record value from the database.
     *
     * @throws InvalidArgumentException
     */
    public function value(string $field, int $settings_id): string
    {
        if (empty($field)) {
            throw new InvalidArgumentException('The field argument is required.');
        }

        if (empty($settings_id)) {
            throw new InvalidArgumentException('The settings ID argument is required.');
        }

        if ($this->db->get_where('whatsapp_integration_settings', ['id' => $settings_id])->num_rows() == 0) {
            throw new InvalidArgumentException('The provided settings ID was not found in the database: ' . $settings_id);
        }

        $row = $this->db->get_where('whatsapp_integration_settings', ['id' => $settings_id])->row_array();

        if (!isset($row[$field])) {
            throw new InvalidArgumentException('The requested field was not found in the database: ' . $field);
        }

        $this->cast($row);

        return $row[$field];
    }

    /**
     * Get all, or specific WhatsApp integration settings records from the database.
     *
     * @param array|string $where Where conditions
     * @param int|null $limit Record limit.
     * @param int|null $offset Record offset.
     * @param string|null $order_by Order by.
     *
     * @return array Returns an array of settings records.
     */
    public function get($where = null, ?int $limit = null, ?int $offset = null, ?string $order_by = null): array
    {
        if ($where !== null) {
            $this->db->where($where);
        }

        if ($order_by !== null) {
            $this->db->order_by($this->quote_order_by($order_by));
        }

        $settings = $this->db->get('whatsapp_integration_settings', $limit, $offset)->result_array();

        foreach ($settings as &$record) {
            $this->cast($record);
        }

        return $settings;
    }

    /**
     * Get the current WhatsApp integration settings (there should be only one record).
     *
     * @return array Returns the current settings or an empty array if none found.
     */
    public function get_current(): array
    {
        $settings = $this->get();

        if (!empty($settings)) {
            $this->decrypt_sensitive_data($settings[0]);
            return $settings[0];
        }

        return [];
    }

    /**
     * Delete an existing WhatsApp integration settings record from the database.
     *
     * @param int $settings_id The settings ID to be deleted.
     *
     * @throws RuntimeException
     */
    public function delete(int $settings_id): void
    {
        if (!$settings_id) {
            throw new InvalidArgumentException('The settings ID argument is required.');
        }

        $count = $this->db->get_where('whatsapp_integration_settings', ['id' => $settings_id])->num_rows();

        if (!$count) {
            throw new InvalidArgumentException('The provided settings ID was not found in the database: ' . $settings_id);
        }

        $this->db->delete('whatsapp_integration_settings', ['id' => $settings_id]);
    }

    /**
     * Encrypt sensitive data before saving.
     *
     * @param array $settings Settings data.
     */
    public function encrypt_sensitive_data(array &$settings): void
    {
        // Use AES-256-GCM for encrypting sensitive fields. Key must be provided via env var WA_TOKEN_ENC_KEY.
        // This replaces the previous base64 "encoding" which is not secure.
        $key = $this->get_encryption_key();

        // If key is not available and we're not in production, fallback to base64 encoding (development mode) but warn.
        if (empty($key)) {
            if (isset($settings['secret_key']) && is_string($settings['secret_key']) && trim($settings['secret_key']) !== '') {
                $settings['secret_key_enc'] = base64_encode($settings['secret_key']);
                unset($settings['secret_key']);
            } else {
                unset($settings['secret_key']);
            }

            if (isset($settings['token']) && is_string($settings['token']) && trim($settings['token']) !== '') {
                $settings['token_enc'] = base64_encode($settings['token']);
                unset($settings['token']);
            } else {
                unset($settings['token']);
            }

            // In production, this path is unreachable due to exception in get_encryption_key
            return;
        }

        if (isset($settings['secret_key']) && is_string($settings['secret_key']) && trim($settings['secret_key']) !== '') {
            $iv = random_bytes(openssl_cipher_iv_length('aes-256-gcm'));
            $tag = '';
            $cipher = openssl_encrypt($settings['secret_key'], 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
            if ($cipher === false) {
                throw new RuntimeException('Failed to encrypt secret_key');
            }
            $settings['secret_key_enc'] = base64_encode($iv . $tag . $cipher);
            unset($settings['secret_key']);
        } else {
            unset($settings['secret_key']);
        }

        if (isset($settings['token']) && is_string($settings['token']) && trim($settings['token']) !== '') {
            $iv = random_bytes(openssl_cipher_iv_length('aes-256-gcm'));
            $tag = '';
            $cipher = openssl_encrypt($settings['token'], 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
            if ($cipher === false) {
                throw new RuntimeException('Failed to encrypt token');
            }
            $settings['token_enc'] = base64_encode($iv . $tag . $cipher);
            unset($settings['token']);
        } else {
            unset($settings['token']);
        }
    }

    /**
     * Decrypt sensitive data after loading.
     *
     * @param array $settings Settings data.
     */
    public function decrypt_sensitive_data(array &$settings): void
    {
        // Initialize fields to avoid null values
        $settings['secret_key'] = '';
        $settings['token'] = '';

        $key = $this->get_encryption_key();

        // If no key available, fallback to base64 decoding (dev mode). In production this won't happen.
        if (empty($key)) {
            if (isset($settings['secret_key_enc']) && is_string($settings['secret_key_enc']) && trim($settings['secret_key_enc']) !== '') {
                $decrypted = base64_decode($settings['secret_key_enc']);
                if ($decrypted !== false) {
                    $settings['secret_key'] = $decrypted;
                }
            }

            if (isset($settings['token_enc']) && is_string($settings['token_enc']) && trim($settings['token_enc']) !== '') {
                $decrypted = base64_decode($settings['token_enc']);
                if ($decrypted !== false) {
                    $settings['token'] = $decrypted;
                }
            }

            return;
        }

        if (isset($settings['secret_key_enc']) && is_string($settings['secret_key_enc']) && trim($settings['secret_key_enc']) !== '') {
            $raw = base64_decode($settings['secret_key_enc']);
            $ivlen = openssl_cipher_iv_length('aes-256-gcm');
            $iv = substr($raw, 0, $ivlen);
            $tag = substr($raw, $ivlen, 16);
            $ciphertext = substr($raw, $ivlen + 16);
            $decrypted = openssl_decrypt($ciphertext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
            if ($decrypted !== false) {
                $settings['secret_key'] = $decrypted;
            }
        }

        if (isset($settings['token_enc']) && is_string($settings['token_enc']) && trim($settings['token_enc']) !== '') {
            $raw = base64_decode($settings['token_enc']);
            $ivlen = openssl_cipher_iv_length('aes-256-gcm');
            $iv = substr($raw, 0, $ivlen);
            $tag = substr($raw, $ivlen, 16);
            $ciphertext = substr($raw, $ivlen + 16);
            $decrypted = openssl_decrypt($ciphertext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
            if ($decrypted !== false) {
                $settings['token'] = $decrypted;
            }
        }
    }

    /**
     * Retrieve encryption key from environment/config
     *
     * @return string
     */
    private function get_encryption_key(): string
    {
        $raw = getenv('WA_TOKEN_ENC_KEY') ?: ($this->config->item('wa_token_enc_key') ?? '');

        // Try to accept base64-encoded key material as well as raw strings
        $candidate = '';
        if (!empty($raw)) {
            $decoded = base64_decode($raw, true);
            if (is_string($decoded) && strlen($decoded) >= 32) {
                $candidate = substr($decoded, 0, 32);
            } elseif (strlen($raw) >= 32) {
                $candidate = substr($raw, 0, 32);
            }
        }

        if (!empty($candidate)) {
            return $candidate;
        }

        // Enforce key presence/length in production
        if (defined('ENVIRONMENT') && ENVIRONMENT === 'production') {
            log_message('error', 'WA_TOKEN_ENC_KEY is missing or invalid in production. Set a 32-byte key (prefer base64).');
            throw new RuntimeException('CRITICAL: WA_TOKEN_ENC_KEY must be configured in production. Generate with: openssl rand -base64 32');
        }

        // Development fallback (non-production): log warning and return empty string to signal fallback path
        log_message('warning', 'WA_TOKEN_ENC_KEY is not configured or too short (min 32 bytes). Using development fallback encoding. NEVER use this in production!');
        return '';
    }

    /**
     * Get masked token for display purposes.
     *
     * @param array $settings Settings data.
     * @return string Returns masked token.
     */
    public function get_masked_token(array $settings): string
    {
        // Check if we have encrypted token data
        if (empty($settings['token_enc']) || !is_string($settings['token_enc'])) {
            return '';
        }

        // Create a copy to avoid modifying original
        $temp_settings = $settings;
        $this->decrypt_sensitive_data($temp_settings);
        
        $token = $temp_settings['token'] ?? '';
        
        // Ensure token is a string and not empty
        if (!is_string($token) || trim($token) === '') {
            return '';
        }
        
        $token_length = strlen($token);
        if ($token_length <= 8) {
            return str_repeat('*', $token_length);
        }

        return substr($token, 0, 4) . str_repeat('*', $token_length - 8) . substr($token, -4);
    }

    /**
     * Update only the token field.
     *
     * @param string $token The new token.
     *
     * @return bool Returns true if successful.
     */
    public function update_token(string $token): bool
    {
        $settings = $this->get_current();
        if (empty($settings)) {
            return false;
        }

        // Preserve previous encrypted token for brief rollback window
        $prev_enc = $settings['token_enc'] ?? null;
        $prev_rotated_at = $settings['token_rotated_at'] ?? null;

        // Prepare settings with new token and encrypt
        $settings_update = $settings;
        $settings_update['token'] = $token;
        $this->encrypt_sensitive_data($settings_update);

        // Update using transaction: set prev fields and new token + rotated timestamp
        $this->db->trans_start();

        $this->db->where('id', $settings['id']);
        $this->db->update('whatsapp_integration_settings', [
            'token_prev_enc' => $prev_enc,
            'token_prev_rotated_at' => $prev_rotated_at,
            'token_enc' => $settings_update['token_enc'],
            'token_rotated_at' => date('Y-m-d H:i:s'),
            'update_datetime' => date('Y-m-d H:i:s')
        ]);

        $this->db->trans_complete();
        return $this->db->trans_status() === TRUE;
    }
}
