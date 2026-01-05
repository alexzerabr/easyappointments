<?php
use Tests\TestCase;

require_once __DIR__ . '/../../application/models/Whatsapp_integration_settings_model.php';

class WhatsappTokenTest extends TestCase
{
    public function testEncryptDecryptRoundtrip()
    {
        // Ensure env key present for test
        $key = bin2hex(random_bytes(16)); // 32 chars
        putenv('WA_TOKEN_ENC_KEY=' . $key);

        $model = new Whatsapp_integration_settings_model();

        $settings = [
            'token' => 'super-secret-token-1234567890',
            'secret_key' => 'my-secret-key'
        ];

        $model->encrypt_sensitive_data($settings);

        $this->assertArrayHasKey('token_enc', $settings);
        $this->assertArrayHasKey('secret_key_enc', $settings);

        // Now decrypt
        $copy = [
            'token_enc' => $settings['token_enc'],
            'secret_key_enc' => $settings['secret_key_enc']
        ];

        $model->decrypt_sensitive_data($copy);

        $this->assertEquals('super-secret-token-1234567890', $copy['token']);
        $this->assertEquals('my-secret-key', $copy['secret_key']);
    }
}


