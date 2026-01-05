<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Simple crypto utility (AES-256-GCM) for encrypting sensitive data at rest.
 *
 * Envelope format: "v1:" . base64_encode(iv | tag | ciphertext)
 * - iv: 12-16 bytes (openssl_cipher_iv_length)
 * - tag: 16 bytes
 * - ciphertext: variable
 * ---------------------------------------------------------------------------- */

class Crypto
{
    public function __construct()
    {
        // No state
    }

    /**
     * Encrypt plaintext with AES-256-GCM using key from environment.
     *
     * @param string $plaintext
     * @return string Envelope string (v1:...)
     */
    public function encrypt(string $plaintext): string
    {
        $key = $this->getKey();
        $ivLen = openssl_cipher_iv_length('aes-256-gcm');
        $iv = random_bytes($ivLen);
        $tag = '';
        $cipher = openssl_encrypt($plaintext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
        if ($cipher === false) {
            throw new RuntimeException('Encryption failed');
        }
        return 'v1:' . base64_encode($iv . $tag . $cipher);
    }

    /**
     * Decrypt envelope string. If input is not an envelope, return it as-is (compat mode).
     *
     * @param string $envelope
     * @return string
     */
    public function decrypt(string $envelope): string
    {
        if (!is_string($envelope) || strpos($envelope, 'v1:') !== 0) {
            // Backwards compatibility: treat value as plaintext
            return (string) $envelope;
        }

        $key = $this->getKey();
        $raw = base64_decode(substr($envelope, 3), true);
        if ($raw === false) {
            throw new RuntimeException('Invalid envelope');
        }
        $ivLen = openssl_cipher_iv_length('aes-256-gcm');
        $iv = substr($raw, 0, $ivLen);
        $tag = substr($raw, $ivLen, 16);
        $ciphertext = substr($raw, $ivLen + 16);
        $plain = openssl_decrypt($ciphertext, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag);
        if ($plain === false) {
            throw new RuntimeException('Decryption failed');
        }
        return $plain;
    }

    /**
     * Retrieve 32-byte key from env WA_TOKEN_ENC_KEY or config item 'wa_token_enc_key'.
     * Accepts base64 or raw string. Throws in production if missing/short.
     */
    private function getKey(): string
    {
        $CI =& get_instance();
        $raw = getenv('WA_TOKEN_ENC_KEY') ?: ($CI->config->item('wa_token_enc_key') ?? '');

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

        if (defined('ENVIRONMENT') && ENVIRONMENT === 'production') {
            throw new RuntimeException('Encryption key missing. Configure WA_TOKEN_ENC_KEY (32+ bytes, prefer base64).');
        }

        // Development fallback: derive stable key from CI encryption_key (not for production)
        $ek = (string) $CI->config->item('encryption_key');
        if ($ek === '') {
            $ek = __FILE__ . APPPATH;
        }
        log_message('warning', 'WA_TOKEN_ENC_KEY not configured. Using development-derived key from encryption_key.');
        return substr(hash('sha256', $ek, true), 0, 32);
    }
}




