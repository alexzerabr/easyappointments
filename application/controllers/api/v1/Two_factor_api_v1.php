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
 * Two Factor API v1 controller.
 *
 * Handles 2FA verification endpoints for the API.
 *
 * @package Controllers
 */
class Two_factor_api_v1 extends EA_Controller
{
    /** Rate limit configuration. */
    private string $rateLimitTable = 'ea_two_factor_rate_limit';
    private int $rateLimitMaxAttempts = 5;
    private int $rateLimitWindowSeconds = 300; // 5 minutes

    /**
     * Two_factor_api_v1 constructor.
     */
    public function __construct()
    {
        parent::__construct();

        $this->load->library('jwt_auth');
        $this->load->library('totp');
        $this->load->library('crypto');
        $this->load->model('users_model');
        $this->load->model('roles_model');
    }

    /**
     * Verify 2FA code and complete login.
     *
     * POST /api/v1/2fa/verify
     *
     * Validates TOTP code or recovery code and returns JWT tokens.
     */
    public function verify(): void
    {
        try {
            $temp_token = request('temp_token');
            $code = request('code');
            $remember_device = filter_var(request('remember_device', false), FILTER_VALIDATE_BOOLEAN);
            $device_name = request('device_name');

            // Validate temp token
            if (empty($temp_token)) {
                json_response([
                    'success' => false,
                    'message' => 'Missing temporary token',
                    'code' => 'MISSING_TEMP_TOKEN',
                ], 400);
                return;
            }

            $pending = $this->jwt_auth->validate_2fa_pending_token($temp_token);

            if (!$pending) {
                json_response([
                    'success' => false,
                    'message' => 'Invalid or expired session. Please login again.',
                    'code' => 'INVALID_2FA_SESSION',
                ], 401);
                return;
            }

            // Validate code
            if (empty($code)) {
                json_response([
                    'success' => false,
                    'message' => 'Verification code is required',
                    'code' => 'MISSING_CODE',
                ], 400);
                return;
            }

            $user_id = (int) $pending->data->user_id;
            $ip = (string) $this->input->ip_address();

            // Rate limiting check
            if ($this->is_rate_limited($ip)) {
                json_response([
                    'success' => false,
                    'message' => 'Too many attempts. Please try again later.',
                    'code' => 'RATE_LIMITED',
                ], 429);
                return;
            }

            // Get user settings
            $settings = $this->db->get_where('user_settings', ['id_users' => $user_id])->row_array();

            if (empty($settings) || empty($settings['two_factor_secret'])) {
                json_response([
                    'success' => false,
                    'message' => '2FA is not configured for this account',
                    'code' => '2FA_NOT_CONFIGURED',
                ], 400);
                return;
            }

            // Decrypt and verify TOTP code
            $secret = $this->crypto->decrypt((string) $settings['two_factor_secret']);
            $is_valid = $this->totp->verify($secret, $code);
            $method = 'totp';

            // If TOTP fails, try recovery codes
            if (!$is_valid && !empty($settings['two_factor_recovery_codes'])) {
                $is_valid = $this->validate_and_consume_recovery_code(
                    $user_id,
                    $code,
                    $settings['two_factor_recovery_codes']
                );
                if ($is_valid) {
                    $method = 'recovery_code';
                }
            }

            if (!$is_valid) {
                // Increment rate limit on failure
                $this->increment_rate_limit($ip);

                // Log failed attempt
                $this->log_2fa_attempt($user_id, $pending->data->username ?? '', false, 'totp');

                json_response([
                    'success' => false,
                    'message' => 'Invalid verification code',
                    'code' => 'INVALID_CODE',
                ], 400);
                return;
            }

            // Success - reset rate limit
            $this->reset_rate_limit($ip);

            // Log successful attempt
            $this->log_2fa_attempt($user_id, $pending->data->username ?? '', true, $method);

            // Get user data for token generation
            $user = $this->users_model->find($user_id);
            $role = $this->roles_model->find($user['id_roles']);

            $user_data = [
                'user_id' => $user_id,
                'user_email' => $user['email'],
                'username' => $pending->data->username ?? '',
                'role_slug' => $role['slug'],
                'timezone' => $user['timezone'] ?? null,
                'language' => $user['language'] ?? null,
            ];

            // Get device info
            $device_info = $device_name ?: ($this->input->user_agent() ?: 'Mobile App');

            // Generate JWT tokens
            $tokens = $this->jwt_auth->create_tokens($user_data, $device_info, $ip);

            // Remember device if requested
            $device_token = null;
            if ($remember_device) {
                $device_token = $this->remember_device($user_id, $device_info);
            }

            // Build response
            $response_data = [
                'tokens' => $tokens,
                'user' => [
                    'id' => (int) $user['id'],
                    'firstName' => $user['first_name'],
                    'lastName' => $user['last_name'],
                    'email' => $user['email'],
                    'role' => $role['slug'],
                    'timezone' => $user['timezone'],
                    'language' => $user['language'],
                ],
            ];

            if ($device_token) {
                $response_data['device_token'] = $device_token;
            }

            header('Cache-Control: no-store');
            json_response([
                'success' => true,
                'data' => $response_data,
            ], 200);

        } catch (Throwable $e) {
            // Increment rate limit on error
            $ip = (string) $this->input->ip_address();
            $this->increment_rate_limit($ip);

            json_exception($e);
        }
    }

    /**
     * Remember device and return token.
     *
     * @param int $user_id User ID.
     * @param string|null $device_label Device label/name.
     *
     * @return string Device token.
     */
    private function remember_device(int $user_id, ?string $device_label): string
    {
        $token = bin2hex(random_bytes(32));
        $hash = hash('sha256', $token);
        $expires = new DateTime('+30 days');

        $this->db->insert('user_two_factor_devices', [
            'id_users' => $user_id,
            'device_hash' => $hash,
            'device_label' => $device_label ?: 'Mobile App',
            'create_datetime' => date('Y-m-d H:i:s'),
            'update_datetime' => date('Y-m-d H:i:s'),
            'last_used_datetime' => date('Y-m-d H:i:s'),
            'expires_datetime' => $expires->format('Y-m-d H:i:s'),
        ]);

        return $token;
    }

    /**
     * Validate and consume a recovery code.
     *
     * @param int $user_id User ID.
     * @param string $code Input code.
     * @param string $encrypted_codes_json Encrypted recovery codes JSON.
     *
     * @return bool True if valid and consumed.
     */
    private function validate_and_consume_recovery_code(int $user_id, string $code, string $encrypted_codes_json): bool
    {
        try {
            $codes_json = $this->crypto->decrypt($encrypted_codes_json);
            $codes = json_decode($codes_json, true);

            if (!is_array($codes)) {
                return false;
            }

            // Normalize input code (remove spaces, dashes, convert to uppercase)
            $normalized_code = strtoupper(str_replace([' ', '-'], '', trim($code)));

            foreach ($codes as $index => $recovery_code) {
                $normalized_recovery = strtoupper(str_replace([' ', '-'], '', $recovery_code));

                if (hash_equals($normalized_recovery, $normalized_code)) {
                    // Remove used code
                    unset($codes[$index]);
                    $codes = array_values($codes);

                    // Update database with remaining codes
                    $new_encrypted = $this->crypto->encrypt(json_encode($codes));
                    $this->users_model->set_setting($user_id, 'two_factor_recovery_codes', $new_encrypted);

                    // Log recovery code usage
                    log_message('info', "2FA API: Recovery code used for user_id={$user_id}, IP=" . $this->input->ip_address());

                    return true;
                }
            }

            return false;
        } catch (Throwable $e) {
            log_message('error', '2FA API: Recovery code validation failed: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Log 2FA authentication attempt.
     *
     * @param int $user_id User ID.
     * @param string $username Username.
     * @param bool $success Whether attempt was successful.
     * @param string $method Authentication method (totp/recovery_code).
     */
    private function log_2fa_attempt(int $user_id, string $username, bool $success, string $method = 'totp'): void
    {
        $ip = (string) $this->input->ip_address();
        $user_agent = (string) $this->input->user_agent();
        $status = $success ? 'SUCCESS' : 'FAILED';

        log_message('info', "2FA API {$status}: user_id={$user_id}, username={$username}, method={$method}, IP={$ip}, UA={$user_agent}");
    }

    /**
     * Check if an IP address is rate limited.
     *
     * @param string $ip IP address.
     *
     * @return bool True if rate limited.
     */
    private function is_rate_limited(string $ip): bool
    {
        if (!$this->db->table_exists($this->rateLimitTable)) {
            return false;
        }

        $this->cleanup_old_rate_limits();

        $record = $this->db
            ->from($this->rateLimitTable)
            ->where('ip_address', $ip)
            ->where('reset_at >', date('Y-m-d H:i:s'))
            ->get()
            ->row_array();

        if (empty($record)) {
            return false;
        }

        return (int) $record['attempts'] >= $this->rateLimitMaxAttempts;
    }

    /**
     * Increment rate limit attempts for an IP.
     *
     * @param string $ip IP address.
     */
    private function increment_rate_limit(string $ip): void
    {
        if (!$this->db->table_exists($this->rateLimitTable)) {
            return;
        }

        $now = date('Y-m-d H:i:s');
        $reset_at = date('Y-m-d H:i:s', strtotime('+' . $this->rateLimitWindowSeconds . ' seconds'));

        $record = $this->db
            ->from($this->rateLimitTable)
            ->where('ip_address', $ip)
            ->where('reset_at >', $now)
            ->get()
            ->row_array();

        if (empty($record)) {
            $this->db->insert($this->rateLimitTable, [
                'ip_address' => $ip,
                'attempts' => 1,
                'reset_at' => $reset_at,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        } else {
            $this->db->update(
                $this->rateLimitTable,
                [
                    'attempts' => (int) $record['attempts'] + 1,
                    'updated_at' => $now,
                ],
                ['id' => $record['id']]
            );
        }
    }

    /**
     * Reset rate limit for an IP (on successful authentication).
     *
     * @param string $ip IP address.
     */
    private function reset_rate_limit(string $ip): void
    {
        if (!$this->db->table_exists($this->rateLimitTable)) {
            return;
        }

        $this->db->delete($this->rateLimitTable, ['ip_address' => $ip]);
    }

    /**
     * Cleanup old rate limit records.
     */
    private function cleanup_old_rate_limits(): void
    {
        if (!$this->db->table_exists($this->rateLimitTable)) {
            return;
        }

        $cutoff = date('Y-m-d H:i:s', strtotime('-1 hour'));
        $this->db->where('reset_at <', $cutoff)->delete($this->rateLimitTable);
    }
}
