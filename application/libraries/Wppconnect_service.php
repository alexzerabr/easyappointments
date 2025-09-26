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
 * WPPConnect Service library.
 *
 * Handles all WPPConnect API communications for WhatsApp integration.
 *
 * @package Libraries
 */
class Wppconnect_service
{
    /**
     * @var EA_Controller|CI_Controller
     */
    protected EA_Controller|CI_Controller $CI;

    /**
     * @var array
     */
    private array $config;

    /**
     * WPPConnect Service constructor.
     */
    public function __construct()
    {
        $this->CI = &get_instance();
        $this->CI->load->model('whatsapp_integration_settings_model');
        
        $this->load_config();
    }

    /**
     * Load configuration from database.
     */
    private function load_config(): void
    {
        $settings = $this->CI->whatsapp_integration_settings_model->get_current();
        
        if (empty($settings)) {
            $this->config = [
                'host' => getenv('WPP_HOST') ?: 'http://localhost',
                'port' => getenv('WPP_PORT') ?: 21465,
                'session' => getenv('WPP_SESSION') ?: 'default',
                'secret_key' => '',
                'token' => '',
                'enabled' => false,
                'wait_qr' => true,
            ];
            return;
        }

        // Only decrypt if we have encrypted data
        $has_encrypted_data = (!empty($settings['secret_key_enc']) && is_string($settings['secret_key_enc'])) ||
                             (!empty($settings['token_enc']) && is_string($settings['token_enc']));
        
        if ($has_encrypted_data) {
            $this->CI->whatsapp_integration_settings_model->decrypt_sensitive_data($settings);
        }

        $this->config = [
            'host' => $settings['host'] ?? 'http://localhost',
            'port' => $settings['port'] ?? 21465,
            'session' => $settings['session'] ?? 'default',
            'secret_key' => $settings['secret_key'] ?? '',
            'token' => $settings['token'] ?? '',
            'enabled' => $settings['enabled'] ?? false,
            'wait_qr' => $settings['wait_qr'] ?? true,
        ];
    }

    /**
     * Check if the WPPConnect session is connected.
     */
    public function is_connected(): bool
    {
        try {
            $status = $this->get_status();
            return isset($status['status']) && strtoupper((string)$status['status']) === 'CONNECTED';
        } catch (Throwable $e) {
            log_message('error', 'WPPConnect is_connected check failed: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Perform comprehensive health check.
     *
     * @return array Health check results
     */
    public function health_check(): array
    {
        $start_time = microtime(true);
        $health = [
            'status' => 'healthy',
            'checks' => [],
            'response_time_ms' => 0,
            'timestamp' => date('Y-m-d H:i:s'),
        ];

        // 1. Configuration check
        $config_check = $this->check_configuration();
        $health['checks']['configuration'] = $config_check;

        // 2. Connectivity check
        $connectivity_check = $this->check_connectivity();
        $health['checks']['connectivity'] = $connectivity_check;

        // 3. Authentication check
        $auth_check = $this->check_authentication();
        $health['checks']['authentication'] = $auth_check;

        // 4. Session status check
        $session_check = $this->check_session_status();
        $health['checks']['session'] = $session_check;

        // Calculate overall status
        $failed_checks = array_filter($health['checks'], function($check) {
            return $check['status'] !== 'pass';
        });

        if (!empty($failed_checks)) {
            $health['status'] = 'unhealthy';
        }

        $health['response_time_ms'] = round((microtime(true) - $start_time) * 1000, 2);

        return $health;
    }

    /**
     * Check configuration completeness.
     */
    private function check_configuration(): array
    {
        $required_fields = ['host', 'port', 'session'];
        $missing = [];

        foreach ($required_fields as $field) {
            if (empty($this->config[$field])) {
                $missing[] = $field;
            }
        }

        return [
            'status' => empty($missing) ? 'pass' : 'fail',
            'message' => empty($missing) ? 'Configuration complete' : 'Missing: ' . implode(', ', $missing),
            'details' => [
                'required_fields' => $required_fields,
                'missing_fields' => $missing,
            ]
        ];
    }

    /**
     * Check basic connectivity to WPPConnect server.
     */
    private function check_connectivity(): array
    {
        try {
            $base_url = $this->get_base_url();
            
            // Simple connectivity test - try to reach the base URL
            $ch = curl_init();
            curl_setopt_array($ch, [
                CURLOPT_URL => $base_url,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT => (int)(getenv('WPPCONNECT_TIMEOUT') ?: 30),
                CURLOPT_CONNECTTIMEOUT => (int)(getenv('WPPCONNECT_CONNECT_TIMEOUT') ?: 10),
                CURLOPT_NOBODY => true, // HEAD request
                CURLOPT_SSL_VERIFYPEER => false, // For local development
                CURLOPT_FOLLOWLOCATION => false,
            ]);

            $result = curl_exec($ch);
            $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $error = curl_error($ch);
            curl_close($ch);

            if ($error) {
                return [
                    'status' => 'fail',
                    'message' => 'Connection error: ' . $error,
                    'details' => ['url' => $base_url, 'error' => $error]
                ];
            }

            return [
                'status' => 'pass',
                'message' => 'Server reachable',
                'details' => ['url' => $base_url, 'http_code' => $http_code]
            ];

        } catch (Throwable $e) {
            return [
                'status' => 'fail',
                'message' => 'Connectivity check failed: ' . $e->getMessage(),
                'details' => ['error' => $e->getMessage()]
            ];
        }
    }

    /**
     * Check authentication status.
     */
    private function check_authentication(): array
    {
        if (empty($this->config['token'])) {
            return [
                'status' => 'warn',
                'message' => 'No authentication token configured',
                'details' => ['has_token' => false]
            ];
        }

        return [
            'status' => 'pass',
            'message' => 'Authentication token present',
            'details' => ['has_token' => true, 'token_length' => strlen($this->config['token'])]
        ];
    }

    /**
     * Check session status.
     */
    private function check_session_status(): array
    {
        try {
            $status = $this->get_status();
            $session_status = $status['status'] ?? 'unknown';

            $is_healthy = in_array(strtoupper($session_status), ['CONNECTED', 'PAIRING']);

            return [
                'status' => $is_healthy ? 'pass' : 'warn',
                'message' => 'Session status: ' . $session_status,
                'details' => [
                    'session' => $this->config['session'],
                    'status' => $session_status,
                    'raw_response' => $status
                ]
            ];

        } catch (Throwable $e) {
            return [
                'status' => 'fail',
                'message' => 'Session status check failed: ' . $e->getMessage(),
                'details' => ['error' => $e->getMessage()]
            ];
        }
    }

    /**
     * Get base URL for WPPConnect API.
     * 
     * Logic for port handling:
     * - HTTPS URLs: Never add port (default 443)
     * - HTTP URLs with domain: Only add port if explicitly provided in host
     * - IP addresses: Always consider port from config
     *
     * @return string
     */
    private function get_base_url(): string
    {
        $host = rtrim((string)($this->config['host'] ?? ''), '/');
        $port = $this->config['port'] ?? '';

        if (empty($host)) {
            return '';
        }

        // Check if host already contains scheme and/or port
        $hasScheme = strpos($host, '://') !== false;
        $hasPortInHost = (bool) preg_match('/:\d+$/', $host);

        // If host already contains port, return as-is
        if ($hasPortInHost) {
            return $host;
        }

        // If no scheme, return host with port (backward compatibility)
        if (!$hasScheme) {
            if (!empty($port)) {
                return $host . ':' . $port;
            }
            return $host;
        }

        // Parse URL components for scheme-based logic
        $parsedUrl = parse_url($host);
        if (!$parsedUrl || !isset($parsedUrl['scheme'], $parsedUrl['host'])) {
            // Fallback: return original host
            return $host;
        }

        $scheme = strtolower($parsedUrl['scheme']);
        $hostname = $parsedUrl['host'];

        // HTTPS: Never add port (uses default 443)
        if ($scheme === 'https') {
            return $host;
        }

        // HTTP: Differentiate between domains and IPs
        if ($scheme === 'http') {
            // Check if hostname is an IP address
            if ($this->is_ip_address($hostname)) {
                // IP address: Always add port if configured
                if (!empty($port)) {
                    return $host . ':' . $port;
                }
            } else {
                // Domain name: Only add port if it was NOT already in original host
                // Since we already checked $hasPortInHost above, we know it's not there
                // For HTTP domains, only add port if explicitly configured AND not default
                if (!empty($port) && $port != '80') {
                    return $host . ':' . $port;
                }
            }
        }

        return $host;
    }

    /**
     * Check if a hostname is an IP address (IPv4 or IPv6).
     *
     * @param string $hostname
     * @return bool
     */
    private function is_ip_address(string $hostname): bool
    {
        // Check for IPv4 or IPv6
        return filter_var($hostname, FILTER_VALIDATE_IP) !== false;
    }

    /**
     * Generate authentication token.
     *
     * @param string|null $secret_key Secret key (if not provided, uses config).
     *
     * @return array Returns API response.
     *
     * @throws RuntimeException
     */
    public function generate_token(?string $secret_key = null): array
    {
        $secret_key = $secret_key ?: ($this->config['secret_key'] ?? '');
        
        if (empty($secret_key) || $secret_key === null) {
            throw new RuntimeException('Secret key is required to generate token');
        }

        if (empty($this->config['session']) || $this->config['session'] === null) {
            throw new RuntimeException('Session name is required to generate token');
        }

        $sessionSeg = rawurlencode((string)$this->config['session']);
        $url = $this->get_base_url() . '/api/' . $sessionSeg . '/' . rawurlencode($secret_key) . '/generate-token';
        
        // Log the URL being called (without secret key)
        $safe_url = $this->get_base_url() . '/api/' . $sessionSeg . '/[SECRET]/generate-token';
        log_message('info', 'WPPConnect token generation URL: ' . $safe_url);

        $response = $this->make_request('POST', $url, null, false);

        // Log success (without exposing sensitive data)
        log_message('info', 'WPPConnect token generation attempted for session: ' . $this->config['session']);

        return $response;
    }

    /**
     * Start WhatsApp session.
     *
     * @param bool $wait_qr Whether to wait for QR code.
     *
     * @return array Returns API response.
     *
     * @throws RuntimeException
     */
    public function start_session(bool $wait_qr = true): array
    {
        $this->ensure_authenticated();

        $sessionSeg = rawurlencode((string)$this->config['session']);
        $url = $this->get_base_url() . '/api/' . $sessionSeg . '/start-session';
        
        $data = [
            'waitQrCode' => $wait_qr,
        ];

        $response = $this->make_request('POST', $url, $data);

        log_message('info', 'WPPConnect session start attempted for session: ' . $this->config['session']);

        return $response;
    }

    /**
     * Get session status.
     *
     * @return array Returns API response.
     *
     * @throws RuntimeException
     */
    public function get_status(): array
    {
        $this->ensure_authenticated();

        $sessionSeg = rawurlencode((string)$this->config['session']);
        $url = $this->get_base_url() . '/api/' . $sessionSeg . '/status-session';

        $response = $this->make_request('GET', $url);

        return $response;
    }

    /**
     * Send WhatsApp message.
     *
     * @param string $phone Phone number in E164 format.
     * @param string $message Message text.
     *
     * @return array Returns API response.
     *
     * @throws RuntimeException
     */
    public function send_message(string $phone, string $message): array
    {
        $this->ensure_authenticated();

        $sessionSeg = rawurlencode((string)$this->config['session']);
        $url = $this->get_base_url() . '/api/' . $sessionSeg . '/send-message';

        $data = [
            'phone' => $this->normalize_phone($phone),
            'message' => $message,
        ];

        $response = $this->make_request('POST', $url, $data);

        log_message('info', 'WPPConnect message sent to: ' . $this->mask_phone($phone));

        return $response;
    }

    /**
     * Close WhatsApp session.
     *
     * @return array Returns API response.
     *
     * @throws RuntimeException
     */
    public function close_session(): array
    {
        $this->ensure_authenticated();

        $sessionSeg = rawurlencode((string)$this->config['session']);
        $url = $this->get_base_url() . '/api/' . $sessionSeg . '/close-session';

        $response = $this->make_request('POST', $url);

        log_message('info', 'WPPConnect session closed for session: ' . $this->config['session']);

        return $response;
    }

    /**
     * Logout from WhatsApp session.
     *
     * @return array Returns API response.
     *
     * @throws RuntimeException
     */
    public function logout_session(): array
    {
        $this->ensure_authenticated();

        $sessionSeg = rawurlencode((string)$this->config['session']);
        $url = $this->get_base_url() . '/api/' . $sessionSeg . '/logout-session';

        $response = $this->make_request('POST', $url);

        log_message('info', 'WPPConnect logout for session: ' . $this->config['session']);

        return $response;
    }

    /**
     * Test connectivity to WPPConnect server.
     *
     * @return array Returns connectivity test results.
     */
    public function test_connectivity(): array
    {
        $result = [
            'success' => false,
            'message' => '',
            'details' => [],
        ];

        try {
            // Test 1: Basic connectivity
            $base_url = $this->get_base_url();
            $result['details']['base_url'] = $base_url;

            // Test 2: Token generation or status check
            if (empty($this->config['token'])) {
                if (empty($this->config['secret_key'])) {
                    $result['message'] = 'Secret key is required to generate token';
                    $result['details']['step'] = 'missing_secret_key';
                    return $result;
                }

                // Try to generate token
                $token_response = $this->generate_token();
                $result['details']['token_generation'] = $token_response;

                $statusVal = strtolower((string)($token_response['status'] ?? ''));
                $httpStatus = (int)($token_response['_http_status'] ?? 0);
                $hasToken = !empty($token_response['token']);

                if ($statusVal === 'success' || $httpStatus === 201 || ($hasToken && $httpStatus >= 200 && $httpStatus < 300)) {
                    $result['success'] = true;
                    $result['message'] = 'Token generated successfully. Please save settings and try starting a session.';
                    $result['details']['step'] = 'token_generated';
                } else {
                    $result['message'] = 'Failed to generate token: ' . ($token_response['message'] ?? 'Unknown error');
                    $result['details']['step'] = 'token_generation_failed';
                }
            } else {
                // Try to check status
                $status_response = $this->get_status();
                $result['details']['status_check'] = $status_response;

                if (!empty($status_response)) {
                    $result['success'] = true;
                    $result['message'] = 'Connection successful. Session status: ' . ($status_response['status'] ?? 'Unknown');
                    $result['details']['step'] = 'status_checked';
                    $result['details']['session_status'] = $status_response['status'] ?? 'Unknown';
                } else {
                    $result['message'] = 'Failed to get session status';
                    $result['details']['step'] = 'status_check_failed';
                }
            }
        } catch (Exception $e) {
            $result['message'] = $this->get_user_friendly_error($e);
            $result['details']['error'] = $e->getMessage();
            $result['details']['step'] = 'exception';
        }

        return $result;
    }

    /**
     * Simple reachability check (no auth, no JSON expectation).
     * Used by the UI "Testar Conectividade" to avoid side-effects.
     */
    public function ping_host(): array
    {
        $baseUrl = $this->get_base_url();

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $baseUrl,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => (int)(getenv('WPPCONNECT_TIMEOUT') ?: 30),
            CURLOPT_CONNECTTIMEOUT => (int)(getenv('WPPCONNECT_CONNECT_TIMEOUT') ?: 10),
            // Do not follow redirects to reduce SSRF risk
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_NOBODY => false,
            // Enforce TLS verification on reachability check as well
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
        ]);
        $body = curl_exec($ch);
        $http = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $err  = curl_error($ch);
        curl_close($ch);

        if ($err) {
            return [ 'success' => false, 'message' => 'Connection error: ' . $err, 'details' => ['base_url' => $baseUrl] ];
        }
        // Treat common non-2xx responses as "reachable" (server answered): 401/403/404/405
        if (($http >= 200 && $http < 400) || in_array($http, [401, 403, 404, 405], true)) {
            $msg = ($http >= 200 && $http < 400) ? 'Reachable' : ('Reachable (HTTP ' . $http . ')');
            return [ 'success' => true, 'message' => $msg, 'details' => ['base_url' => $baseUrl, 'http' => $http] ];
        }
        return [ 'success' => false, 'message' => 'HTTP ' . $http, 'details' => ['base_url' => $baseUrl, 'http' => $http] ];
    }

    /**
     * Make HTTP request to WPPConnect API with retry logic.
     *
     * @param string $method HTTP method.
     * @param string $url Request URL.
     * @param array|null $data Request data.
     * @param bool $use_auth Whether to use authentication header.
     * @param int $max_retries Maximum number of retries.
     *
     * @return array Returns parsed response.
     *
     * @throws RuntimeException
     */
    private function make_request(string $method, string $url, ?array $data = null, bool $use_auth = true, int $max_retries = 3): array
    {
        $attempt = 1;
        $last_exception = null;

        while ($attempt <= $max_retries) {
            try {
                $start_time = microtime(true);
                
                $ch = curl_init();

                $headers = [
                    'Content-Type: application/json',
                    'Accept: application/json',
                ];

                if ($use_auth && !empty($this->config['token']) && $this->config['token'] !== null) {
                    $headers[] = 'Authorization: Bearer ' . $this->config['token'];
                }

                curl_setopt_array($ch, [
                    CURLOPT_URL => $url,
                    CURLOPT_RETURNTRANSFER => true,
                    CURLOPT_TIMEOUT => (int)(getenv('WPPCONNECT_TIMEOUT') ?: 30),
                    CURLOPT_CONNECTTIMEOUT => (int)(getenv('WPPCONNECT_CONNECT_TIMEOUT') ?: 10),
                    CURLOPT_HTTPHEADER => $headers,
                    CURLOPT_SSL_VERIFYPEER => true,
                    CURLOPT_SSL_VERIFYHOST => 2,
                    CURLOPT_FOLLOWLOCATION => false,
                    CURLOPT_MAXREDIRS => 0,
                ]);

                if ($method === 'POST') {
                    curl_setopt($ch, CURLOPT_POST, true);
                    if ($data) {
                        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
                    }
                }

                $response = curl_exec($ch);
                $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
                $error = curl_error($ch);

                curl_close($ch);

                $response_time = round((microtime(true) - $start_time) * 1000, 2);

                if ($error) {
                    throw new RuntimeException('cURL error: ' . $error);
                }

                $decoded_response = json_decode($response, true);

                if (json_last_error() !== JSON_ERROR_NONE) {
                    throw new RuntimeException('Invalid JSON response: ' . json_last_error_msg());
                }

                if ($http_code >= 400) {
                    $error_message = $decoded_response['message'] ?? 'HTTP ' . $http_code . ' error';
                    
                    // Check if this is a retryable error
                    if ($this->is_retryable_error($http_code, $error_message) && $attempt < $max_retries) {
                        log_message('warning', "WPPConnect request failed (attempt {$attempt}/{$max_retries}): HTTP {$http_code} - {$error_message}. Retrying...");
                        $last_exception = new RuntimeException($error_message, $http_code);
                        $this->wait_before_retry($attempt);
                        $attempt++;
                        continue;
                    }
                    
                    throw new RuntimeException($error_message, $http_code);
                }

                // Add HTTP status and metadata to response
                if (is_array($decoded_response)) {
                    $decoded_response['_http_status'] = $http_code;
                    $decoded_response['_response_time_ms'] = $response_time;
                    $decoded_response['_attempt'] = $attempt;
                }

                if ($attempt > 1) {
                    log_message('info', "WPPConnect request succeeded after {$attempt} attempts");
                }

                return $decoded_response ?: [];

            } catch (RuntimeException $e) {
                $last_exception = $e;
                
                // Check if this is a connection error that should be retried
                if ($this->is_connection_error($e) && $attempt < $max_retries) {
                    log_message('warning', "WPPConnect connection error (attempt {$attempt}/{$max_retries}): " . $e->getMessage() . ". Retrying...");
                    $this->wait_before_retry($attempt);
                    $attempt++;
                    continue;
                }
                
                // Re-throw if not retryable or max retries reached
                throw $e;
            }
        }

        // If we get here, all retries failed
        log_message('error', "WPPConnect request failed after {$max_retries} attempts. Last error: " . ($last_exception ? $last_exception->getMessage() : 'Unknown error'));
        throw $last_exception ?? new RuntimeException('Request failed after maximum retries');
    }

    /**
     * Check if error is retryable based on HTTP code and message.
     */
    private function is_retryable_error(int $http_code, string $error_message): bool
    {
        // Retry on temporary server errors
        $retryable_codes = [500, 502, 503, 504, 408, 429];
        
        if (in_array($http_code, $retryable_codes)) {
            return true;
        }
        
        // Retry on specific error messages
        $retryable_messages = [
            'timeout',
            'connection refused',
            'connection reset',
            'network unreachable',
            'service unavailable'
        ];
        
        foreach ($retryable_messages as $pattern) {
            if (stripos($error_message, $pattern) !== false) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * Check if exception indicates a connection error.
     */
    private function is_connection_error(RuntimeException $e): bool
    {
        $message = strtolower($e->getMessage());
        
        $connection_patterns = [
            'curl error',
            'connection refused',
            'connection timeout',
            'connection reset',
            'network unreachable',
            'host unreachable',
            'timeout',
            'ssl connection error'
        ];
        
        foreach ($connection_patterns as $pattern) {
            if (strpos($message, $pattern) !== false) {
                return true;
            }
        }
        
        return false;
    }

    /**
     * Wait before retry with exponential backoff.
     */
    private function wait_before_retry(int $attempt): void
    {
        // Exponential backoff: 1s, 2s, 4s, 8s, etc.
        $delay = min(pow(2, $attempt - 1), 8); // Cap at 8 seconds
        
        // Add some jitter to avoid thundering herd
        $jitter = mt_rand(0, 500) / 1000; // 0-500ms
        $total_delay = $delay + $jitter;
        
        log_message('debug', "WPPConnect retry delay: {$total_delay}s (attempt {$attempt})");
        
        // Use usleep for sub-second precision
        usleep((int)($total_delay * 1000000));
    }

    /**
     * Ensure authentication token is available.
     *
     * @throws RuntimeException
     */
    private function ensure_authenticated(): void
    {
        if (empty($this->config['token']) || $this->config['token'] === null) {
            throw new RuntimeException('Authentication token is required. Please generate a token first.');
        }
    }

    /**
     * Normalize phone number to E164 format.
     *
     * @param string $phone Phone number.
     *
     * @return string Normalized phone number.
     */
    private function normalize_phone(string $phone): string
    {
        // Remove all non-digit characters
        $phone = preg_replace('/[^0-9]/', '', $phone);

        // Add country code if not present (assuming Brazil +55 as default)
        if (strlen($phone) === 11 && substr($phone, 0, 1) !== '5') {
            $phone = '55' . $phone;
        } elseif (strlen($phone) === 10 && substr($phone, 0, 1) !== '5') {
            $phone = '55' . $phone;
        }

        return $phone;
    }

    /**
     * Mask phone number for logging.
     *
     * @param string $phone Phone number.
     *
     * @return string Masked phone number.
     */
    private function mask_phone(string $phone): string
    {
        $phone = $this->normalize_phone($phone);
        
        if (strlen($phone) > 7) {
            return substr($phone, 0, 3) . str_repeat('*', strlen($phone) - 7) . substr($phone, -4);
        }

        return str_repeat('*', strlen($phone));
    }

    /**
     * Get user-friendly error message.
     *
     * @param Exception $e Exception.
     *
     * @return string User-friendly error message.
     */
    private function get_user_friendly_error(Exception $e): string
    {
        $code = $e->getCode();
        $message = $e->getMessage();

        switch ($code) {
            case 401:
                return 'Authentication failed. Please generate a new token.';
            case 404:
                return 'WPPConnect server not found. Please check host and port settings.';
            case 500:
                return 'WPPConnect server error. Please try again later.';
            case 0:
                if (strpos($message, 'Connection refused') !== false) {
                    return 'Cannot connect to WPPConnect server. Please check if the server is running.';
                }
                if (strpos($message, 'timeout') !== false) {
                    return 'Connection timeout. Please check your network connection.';
                }
                break;
        }

        return $message;
    }

    /**
     * Check if the service is properly configured.
     *
     * @return bool
     */
    public function is_configured(): bool
    {
        $host = (string)($this->config['host'] ?? '');
        $session = (string)($this->config['session'] ?? '');
        $port = $this->config['port'] ?? '';

        // Determine if an explicit port is required
        $hasScheme = strpos($host, '://') !== false;
        $hasPortInHost = (bool) preg_match('/:\d+$/', $host);
        $portOk = $hasScheme || $hasPortInHost || (!empty($port));

        return !empty($host) && $portOk && !empty($session);
    }

    /**
     * Check if the service is enabled.
     *
     * @return bool
     */
    public function is_enabled(): bool
    {
        return $this->config['enabled'] ?? false;
    }

    /**
     * Get current configuration (without sensitive data).
     *
     * @return array
     */
    public function get_config(): array
    {
        return [
            'host' => $this->config['host'],
            'port' => $this->config['port'],
            'session' => $this->config['session'],
            'enabled' => $this->config['enabled'],
            'wait_qr' => $this->config['wait_qr'],
            'has_token' => !empty($this->config['token']),
        ];
    }

    /**
     * Update service configuration.
     *
     * @param array $config New configuration.
     */
    public function update_config(array $config): void
    {
        $this->config = array_merge($this->config, $config);
    }
}
