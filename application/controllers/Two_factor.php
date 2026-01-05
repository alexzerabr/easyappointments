<?php defined('BASEPATH') or exit('No direct script access allowed');

/* Two-factor authentication controller. */

class Two_factor extends EA_Controller
{
    /** Rate limit configuration and table name. */
    private string $rateLimitTable = 'ea_two_factor_rate_limit';
    private int $rateLimitMaxAttempts = 5; // attempts
    private int $rateLimitWindowSeconds = 300; // 5 minutes

    public function __construct()
    {
        parent::__construct();

        $this->load->model('users_model');
        $this->load->library('totp');
        $this->load->library('timezones');
        $this->load->library('accounts');
        $this->load->library('crypto');
    }

    /** Initialize 2FA setup and return provisioning data. */
    public function setup_init(): void
    {
        try {
            $user_id = (int) session('user_id');
            if (!$user_id) {
                abort(403, 'Forbidden');
            }

            // Generate random base32 secret
            $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
            $base32 = '';
            for ($i = 0; $i < 32; $i++) {
                $base32 .= $alphabet[random_int(0, 31)];
            }

            $company = setting('company_name') ?: 'Minha Agenda';
            $username = $this->accounts->get_user_by_username(session('username'))['email'] ?? session('username');

            // Store encrypted secret at rest
            $this->users_model->set_setting($user_id, 'two_factor_secret', $this->crypto->encrypt($base32));

            $issuer = rawurlencode($company);
            $label = rawurlencode($username ?: ('user-' . $user_id));
            $otpauth = 'otpauth://totp/' . $issuer . ':' . $label . '?secret=' . $base32 . '&issuer=' . $issuer . '&period=30&algorithm=SHA1&digits=6';

            // Attempt to build local QR as data URL (if library available)
            $qr_data_url = null;
            try {
                if (class_exists('chillerlan\\QRCode\\QRCode')) {
                    $options = new \chillerlan\QRCode\QROptions([
                        'eccLevel' => \chillerlan\QRCode\QRCode::ECC_L,
                        'scale' => 5,
                        'imageTransparent' => false,
                    ]);
                    $qrcode = new \chillerlan\QRCode\QRCode($options);
                    $png = $qrcode->render($otpauth);
                    // Some outputs already return data URI; detect and wrap if needed
                    if (str_starts_with($png, 'data:image')) {
                        $qr_data_url = $png;
                    } else {
                        $qr_data_url = 'data:image/png;base64,' . base64_encode($png);
                    }
                }
            } catch (\Throwable $e) {
                // Fallback: no QR generated; client may render with local JS or show manual code
            }

            header('Cache-Control: no-store');
            header('X-Frame-Options: DENY');
            json_response([
                'success' => true,
                'secret' => $base32,
                'otpauth' => $otpauth,
                'qr_data_url' => $qr_data_url,
            ]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Enable 2FA after code verification, generate recovery codes.
     */
    public function setup_enable(): void
    {
        try {
            $user_id = (int) session('user_id');
            if (!$user_id) {
                abort(403, 'Forbidden');
            }

            $code = request('code');
            if (empty($code)) {
                throw new InvalidArgumentException(lang('invalid_totp_code'));
            }

            $settings = $this->db->get_where('user_settings', ['id_users' => $user_id])->row_array();
            $secretRaw = (string) ($settings['two_factor_secret'] ?? '');
            $secret = $this->crypto->decrypt($secretRaw);
            if (!$secret) {
                throw new RuntimeException('Missing secret');
            }

            if (!$this->totp->verify($secret, $code)) {
                throw new InvalidArgumentException(lang('invalid_totp_code'));
            }

            // Mark enabled
            $this->users_model->set_setting($user_id, 'two_factor_enabled', '1');

            // Generate recovery codes (store encrypted JSON)
            $codes = [];
            for ($i = 0; $i < 8; $i++) {
                $codes[] = bin2hex(random_bytes(4)) . '-' . bin2hex(random_bytes(4));
            }
            $this->users_model->set_setting($user_id, 'two_factor_recovery_codes', $this->crypto->encrypt(json_encode($codes)));

            header('Cache-Control: no-store');
            header('X-Frame-Options: DENY');
            json_response(['success' => true, 'recovery_codes' => $codes]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Disable 2FA for current user.
     */
    public function setup_disable(): void
    {
        try {
            $user_id = (int) session('user_id');
            if (!$user_id) {
                abort(403, 'Forbidden');
            }

            $this->users_model->set_setting($user_id, 'two_factor_enabled', '0');
            $this->users_model->set_setting($user_id, 'two_factor_secret', '');
            $this->users_model->set_setting($user_id, 'two_factor_recovery_codes', '');

            header('Cache-Control: no-store');
            header('X-Frame-Options: DENY');
            json_response(['success' => true]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Regenerate recovery codes.
     */
    public function regenerate_recovery_codes(): void
    {
        try {
            $user_id = (int) session('user_id');
            if (!$user_id) {
                abort(403, 'Forbidden');
            }
            $codes = [];
            for ($i = 0; $i < 8; $i++) {
                $codes[] = bin2hex(random_bytes(4)) . '-' . bin2hex(random_bytes(4));
            }
            $this->users_model->set_setting($user_id, 'two_factor_recovery_codes', $this->crypto->encrypt(json_encode($codes)));
            header('Cache-Control: no-store');
            header('X-Frame-Options: DENY');
            json_response(['success' => true, 'recovery_codes' => $codes]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * List remembered devices.
     */
    public function devices(): void
    {
        try {
            $user_id = (int) session('user_id');
            if (!$user_id) {
                abort(403, 'Forbidden');
            }
            $devices = $this->db
                ->from('user_two_factor_devices')
                ->where(['id_users' => $user_id])
                ->order_by('last_used_datetime', 'DESC')
                ->get()
                ->result_array();
            json_response(['success' => true, 'devices' => $devices]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Revoke a remembered device by device_hash.
     */
    public function revoke_device(): void
    {
        try {
            $user_id = (int) session('user_id');
            if (!$user_id) {
                abort(403, 'Forbidden');
            }
            $hash = (string) request('device_hash');
            if (!$hash) {
                throw new InvalidArgumentException('Missing device_hash');
            }
            $this->db->delete('user_two_factor_devices', [
                'id_users' => $user_id,
                'device_hash' => $hash,
            ]);
            json_response(['success' => true]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Render the verification page when login requires second factor.
     */
    public function verify(): void
    {
        if (!session('pending_user_id')) {
            redirect('login');
            return;
        }

        html_vars([
            'page_title' => lang('two_factor_verification'),
        ]);

        $this->load->view('pages/two_factor_verify');
    }

    /**
     * POST: Validate a TOTP code, complete login session.
     */
    public function validate(): void
    {
        try {
            // Rate limit check (5 attempts per 5 minutes per IP)
            $ip = (string) $this->input->ip_address();

            if ($this->is_rate_limited($ip)) {
                header('HTTP/1.1 429 Too Many Requests');
                json_response(['success' => false, 'message' => 'Too many attempts. Try again later.']);
                return;
            }
            $pending_user_id = (int) session('pending_user_id');
            $username = (string) session('pending_username');

            if (!$pending_user_id || !$username) {
                json_response(['success' => false, 'message' => 'No pending authentication.'], 400);
                return;
            }

            $code = request('code');
            $remember = (bool) request('remember');

            if (empty($code)) {
                throw new InvalidArgumentException(lang('invalid_totp_code'));
            }

            $settings = $this->db->get_where('user_settings', ['id_users' => $pending_user_id])->row_array();

            if (empty($settings) || (string)$settings['two_factor_enabled'] === '0' || empty($settings['two_factor_secret'])) {
                json_response(['success' => false, 'message' => '2FA not enabled.'], 400);
                return;
            }

            $secret = $this->crypto->decrypt((string) $settings['two_factor_secret']);

            // Try TOTP verification first
            $is_valid = $this->totp->verify($secret, $code);
            $method = 'totp';

            // If TOTP fails, try recovery codes
            if (!$is_valid && !empty($settings['two_factor_recovery_codes'])) {
                $is_valid = $this->validate_and_consume_recovery_code($pending_user_id, $code, $settings['two_factor_recovery_codes']);
                if ($is_valid) {
                    $method = 'recovery_code';
                }
            }

            if (!$is_valid) {
                // Log failed attempt
                $this->log_2fa_attempt($pending_user_id, $username, false, 'totp');

                // Increment rate limit counter on failure
                $this->increment_rate_limit($ip);

                json_response(['success' => false, 'message' => lang('invalid_totp_code')], 400);
                return;
            }

            // Log successful attempt
            $this->log_2fa_attempt($pending_user_id, $username, true, $method);

            // Reset rate limit on success
            $this->reset_rate_limit($ip);

            // Promote session to fully authenticated
            $user = $this->users_model->find($pending_user_id);
            $role = $this->db->get_where('roles', ['id' => $user['id_roles']])->row_array();

            $default_timezone = $this->timezones->get_default_timezone();

            $this->session->sess_regenerate();

            session([
                'user_id' => $user['id'],
                'user_email' => $user['email'],
                'username' => $username,
                'timezone' => !empty($user['timezone']) ? $user['timezone'] : $default_timezone,
                'language' => !empty($user['language']) ? $user['language'] : Config::LANGUAGE,
                'role_slug' => $role['slug'] ?? null,
            ]);

            // Clear pending markers
            $this->session->unset_userdata('pending_user_id');
            $this->session->unset_userdata('pending_username');

            // Remember device (optional): generate token & set cookie (HttpOnly, SameSite=Lax)
            if ($remember) {
                $this->remember_device($user['id']);
            }

            header('Cache-Control: no-store');
            header('X-Frame-Options: DENY');
            json_response(['success' => true]);
        } catch (Throwable $e) {
            // On failure, increment rate limit counter
            $ip = (string) $this->input->ip_address();
            $this->increment_rate_limit($ip);
            json_exception($e);
        }
    }

    /**
     * Check whether the current device is remembered for the pending user.
     */
    public function is_device_remembered(): void
    {
        try {
            $pending_user_id = (int) session('pending_user_id');
            if (!$pending_user_id) {
                json_response(['remembered' => false]);
                return;
            }
            $token = (string) $this->input->cookie('ea_2fa_device', true);
            $hash = $token ? hash('sha256', $token) : '';
            $row = $this->db
                ->from('user_two_factor_devices')
                ->where(['id_users' => $pending_user_id, 'device_hash' => $hash])
                ->where('(expires_datetime IS NULL OR expires_datetime > NOW())')
                ->get()
                ->row_array();

            header('Cache-Control: no-store');
            header('X-Frame-Options: DENY');
            json_response(['remembered' => !empty($row)]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * POST: Remember this device for the logged-in or pending user.
     */
    public function remember(): void
    {
        try {
            $user_id = (int) session('user_id') ?: (int) session('pending_user_id');
            if (!$user_id) {
                throw new RuntimeException('Not authorized');
            }

            $label = substr((string) request('label'), 0, 256);
            $token = bin2hex(random_bytes(32));
            $hash = hash('sha256', $token);

            $expires = new DateTime('+30 days');

            $this->db->insert('user_two_factor_devices', [
                'id_users' => $user_id,
                'device_hash' => $hash,
                'device_label' => $label ?: $this->input->user_agent(),
                'create_datetime' => date('Y-m-d H:i:s'),
                'update_datetime' => date('Y-m-d H:i:s'),
                'last_used_datetime' => date('Y-m-d H:i:s'),
                'expires_datetime' => $expires->format('Y-m-d H:i:s'),
            ]);

            // Set cookie
            $secure = (bool) config('cookie_secure');
            $params = session_get_cookie_params();
            $cookie = 'ea_2fa_device=' . $token
                . '; Max-Age=' . (30 * 24 * 60 * 60)
                . '; Path=' . ($params['path'] ?: '/')
                . '; SameSite=Lax; HttpOnly' . ($secure ? '; Secure' : '');
            header('Set-Cookie: ' . $cookie, false);

            header('Cache-Control: no-store');
            header('X-Frame-Options: DENY');
            json_response(['success' => true]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Utility: Remember device after successful verification.
     */
    private function remember_device(int $user_id): void
    {
        $token = bin2hex(random_bytes(32));
        $hash = hash('sha256', $token);
        $exists = $this->db->get_where('user_two_factor_devices', [
            'id_users' => $user_id,
            'device_hash' => $hash,
        ])->row_array();

        $expires = new DateTime('+30 days');

        if ($exists) {
            $this->db->update('user_two_factor_devices', [
                'update_datetime' => date('Y-m-d H:i:s'),
                'last_used_datetime' => date('Y-m-d H:i:s'),
                'expires_datetime' => $expires->format('Y-m-d H:i:s'),
            ], ['id' => $exists['id']]);
            // Set cookie refresh
            $secure = (bool) config('cookie_secure');
            $params = session_get_cookie_params();
            $cookie = 'ea_2fa_device=' . $token
                . '; Max-Age=' . (30 * 24 * 60 * 60)
                . '; Path=' . ($params['path'] ?: '/')
                . '; SameSite=Lax; HttpOnly' . ($secure ? '; Secure' : '');
            header('Set-Cookie: ' . $cookie, false);
            return;
        }

        $this->db->insert('user_two_factor_devices', [
            'id_users' => $user_id,
            'device_hash' => $hash,
            'device_label' => $this->input->user_agent(),
            'create_datetime' => date('Y-m-d H:i:s'),
            'update_datetime' => date('Y-m-d H:i:s'),
            'last_used_datetime' => date('Y-m-d H:i:s'),
            'expires_datetime' => $expires->format('Y-m-d H:i:s'),
        ]);

        // Set cookie
        $secure = (bool) config('cookie_secure');
        $params = session_get_cookie_params();
        $cookie = 'ea_2fa_device=' . $token
            . '; Max-Age=' . (30 * 24 * 60 * 60)
            . '; Path=' . ($params['path'] ?: '/')
            . '; SameSite=Lax; HttpOnly' . ($secure ? '; Secure' : '');
        header('Set-Cookie: ' . $cookie, false);
    }

    /**
     * Validate and consume a recovery code.
     *
     * @param int $user_id
     * @param string $code
     * @param string $encrypted_codes_json
     * @return bool
     */
    private function validate_and_consume_recovery_code(int $user_id, string $code, string $encrypted_codes_json): bool
    {
        try {
            $codes_json = $this->crypto->decrypt($encrypted_codes_json);
            $codes = json_decode($codes_json, true);

            if (!is_array($codes)) {
                return false;
            }

            // Normalize input code (remove spaces, convert to uppercase)
            $normalized_code = strtoupper(str_replace([' ', '-'], '', trim($code)));

            foreach ($codes as $index => $recovery_code) {
                $normalized_recovery = strtoupper(str_replace([' ', '-'], '', $recovery_code));

                if (hash_equals($normalized_recovery, $normalized_code)) {
                    // Remove used code
                    unset($codes[$index]);
                    $codes = array_values($codes); // Re-index array

                    // Update database with remaining codes
                    $new_encrypted = $this->crypto->encrypt(json_encode($codes));
                    $this->users_model->set_setting($user_id, 'two_factor_recovery_codes', $new_encrypted);

                    // Log recovery code usage
                    log_message('info', "2FA recovery code used for user_id={$user_id}, IP=" . $this->input->ip_address());

                    return true;
                }
            }

            return false;
        } catch (Throwable $e) {
            log_message('error', '2FA recovery code validation failed: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Log 2FA authentication attempt.
     */
    private function log_2fa_attempt(int $user_id, string $username, bool $success, string $method = 'totp'): void
    {
        $ip = (string) $this->input->ip_address();
        $user_agent = (string) $this->input->user_agent();
        $status = $success ? 'SUCCESS' : 'FAILED';

        log_message('info', "2FA {$status}: user_id={$user_id}, username={$username}, method={$method}, IP={$ip}, UA={$user_agent}");
    }

    /**
     * Check if an IP address is rate limited.
     *
     * @param string $ip
     * @return bool
     */
    private function is_rate_limited(string $ip): bool
    {
        // Fallback to session-based rate limiting if table doesn't exist
        if (!$this->db->table_exists($this->rateLimitTable)) {
            return $this->is_rate_limited_session($ip);
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
     * @param string $ip
     */
    private function increment_rate_limit(string $ip): void
    {
        // Fallback to session-based rate limiting if table doesn't exist
        if (!$this->db->table_exists($this->rateLimitTable)) {
            $this->increment_rate_limit_session($ip);
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
     * @param string $ip
     */
    private function reset_rate_limit(string $ip): void
    {
        // Fallback to session-based rate limiting if table doesn't exist
        if (!$this->db->table_exists($this->rateLimitTable)) {
            $this->reset_rate_limit_session($ip);
            return;
        }

        $this->db->delete($this->rateLimitTable, ['ip_address' => $ip]);
    }

    /**
     * Cleanup old rate limit records (older than 1 hour).
     */
    private function cleanup_old_rate_limits(): void
    {
        if (!$this->db->table_exists($this->rateLimitTable)) {
            return;
        }

        $cutoff = date('Y-m-d H:i:s', strtotime('-1 hour'));
        $this->db->where('reset_at <', $cutoff)->delete($this->rateLimitTable);
    }

    /**
     * Session-based rate limiting fallback (when DB table doesn't exist).
     *
     * @param string $ip
     * @return bool
     */
    private function is_rate_limited_session(string $ip): bool
    {
        $rlKey = 'two_factor_rl_' . md5($ip);
        $bucket = (array) session($rlKey) ?: [];
        $now = time();
        $resetAt = (int) ($bucket['reset_at'] ?? 0);
        $count = (int) ($bucket['count'] ?? 0);

        if ($now > $resetAt) {
            return false;
        }

        return $count >= $this->rateLimitMaxAttempts;
    }

    /**
     * Increment session-based rate limit.
     *
     * @param string $ip
     */
    private function increment_rate_limit_session(string $ip): void
    {
        $rlKey = 'two_factor_rl_' . md5($ip);
        $bucket = (array) session($rlKey) ?: [];
        $now = time();
        $resetAt = (int) ($bucket['reset_at'] ?? 0);
        $count = (int) ($bucket['count'] ?? 0);

        if ($now > $resetAt) {
            $count = 0;
            $resetAt = $now + $this->rateLimitWindowSeconds;
        }

        session([$rlKey => ['count' => $count + 1, 'reset_at' => $resetAt]]);
    }

    /**
     * Reset session-based rate limit.
     *
     * @param string $ip
     */
    private function reset_rate_limit_session(string $ip): void
    {
        $rlKey = 'two_factor_rl_' . md5($ip);
        session([$rlKey => ['count' => 0, 'reset_at' => time() + $this->rateLimitWindowSeconds]]);
    }
}


