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

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;

/**
 * JWT Authentication library.
 *
 * Handles JWT token generation and validation for API authentication.
 *
 * @package Libraries
 */
class Jwt_auth
{
    /**
     * @var EA_Controller|CI_Controller
     */
    protected EA_Controller|CI_Controller $CI;

    /**
     * JWT secret key.
     *
     * @var string
     */
    protected string $secret_key;

    /**
     * JWT algorithm.
     *
     * @var string
     */
    protected string $algorithm = 'HS256';

    /**
     * Access token expiry in seconds (15 minutes).
     *
     * @var int
     */
    protected int $access_token_expiry = 900;

    /**
     * Refresh token expiry in seconds (7 days).
     *
     * @var int
     */
    protected int $refresh_token_expiry = 604800;

    /**
     * Token issuer.
     *
     * @var string
     */
    protected string $issuer;

    /**
     * Jwt_auth constructor.
     */
    public function __construct()
    {
        $this->CI = &get_instance();

        $this->CI->load->model('refresh_tokens_model');
        $this->CI->load->model('users_model');
        $this->CI->load->model('roles_model');

        $this->secret_key = $this->get_jwt_secret();
        $this->issuer = config('base_url') ?: 'easyappointments';
    }

    /**
     * Get or generate JWT secret key.
     *
     * Priority:
     * 1. JWT_SECRET environment variable
     * 2. Derived from api_token setting
     * 3. Default fallback (not recommended for production)
     *
     * @return string
     */
    protected function get_jwt_secret(): string
    {
        // Try environment variable first
        $env_secret = getenv('JWT_SECRET');

        if (!empty($env_secret)) {
            return $env_secret;
        }

        // Fall back to derived secret from api_token
        $api_token = setting('api_token');

        if (!empty($api_token)) {
            return hash('sha256', $api_token . '_jwt_auth_secret_v1');
        }

        // Last resort: use a constant (not recommended for production)
        return hash('sha256', 'easyappointments_jwt_default_secret_change_me');
    }

    /**
     * Generate an access token (JWT).
     *
     * @param array $user_data User data from Accounts::check_login().
     *
     * @return string Returns the JWT access token.
     */
    public function generate_access_token(array $user_data): string
    {
        $issued_at = time();
        $expiration = $issued_at + $this->access_token_expiry;

        $payload = [
            'iss' => $this->issuer,
            'iat' => $issued_at,
            'exp' => $expiration,
            'sub' => (string) $user_data['user_id'],
            'data' => [
                'user_id' => (int) $user_data['user_id'],
                'email' => $user_data['user_email'] ?? '',
                'username' => $user_data['username'] ?? '',
                'role' => $user_data['role_slug'] ?? '',
                'timezone' => $user_data['timezone'] ?? null,
            ],
        ];

        return JWT::encode($payload, $this->secret_key, $this->algorithm);
    }

    /**
     * Generate a refresh token (random string).
     *
     * @return string Returns a secure random token.
     */
    public function generate_refresh_token(): string
    {
        return bin2hex(random_bytes(32));
    }

    /**
     * Validate and decode an access token.
     *
     * @param string $token JWT access token.
     *
     * @return object Returns the decoded token payload.
     *
     * @throws InvalidArgumentException If token is invalid.
     * @throws ExpiredException If token has expired.
     */
    public function validate_access_token(string $token): object
    {
        try {
            return JWT::decode($token, new Key($this->secret_key, $this->algorithm));
        } catch (ExpiredException $e) {
            throw new ExpiredException('Access token has expired');
        } catch (Exception $e) {
            throw new InvalidArgumentException('Invalid access token: ' . $e->getMessage());
        }
    }

    /**
     * Create tokens for a user (login flow).
     *
     * @param array $user_data User data from Accounts::check_login().
     * @param string|null $device_info Device information (user agent).
     * @param string|null $ip_address Client IP address.
     *
     * @return array Returns array with tokens and metadata.
     */
    public function create_tokens(
        array $user_data,
        ?string $device_info = null,
        ?string $ip_address = null,
    ): array {
        $access_token = $this->generate_access_token($user_data);
        $refresh_token = $this->generate_refresh_token();

        $expires_at = new DateTime();
        $expires_at->modify('+' . $this->refresh_token_expiry . ' seconds');

        $this->CI->refresh_tokens_model->create(
            (int) $user_data['user_id'],
            $refresh_token,
            $expires_at,
            $device_info,
            $ip_address,
        );

        return [
            'access_token' => $access_token,
            'refresh_token' => $refresh_token,
            'token_type' => 'Bearer',
            'expires_in' => $this->access_token_expiry,
            'refresh_expires_in' => $this->refresh_token_expiry,
        ];
    }

    /**
     * Refresh an access token using a refresh token.
     *
     * @param string $refresh_token Refresh token.
     *
     * @return array|null Returns new access token data or null if invalid.
     */
    public function refresh_access_token(string $refresh_token): ?array
    {
        $token_record = $this->CI->refresh_tokens_model->find_by_token($refresh_token);

        if (!$token_record) {
            return null;
        }

        // Check if expired
        if (strtotime($token_record['expires_at']) < time()) {
            $this->CI->refresh_tokens_model->revoke($refresh_token);
            return null;
        }

        // Get user data
        try {
            $user = $this->CI->users_model->find($token_record['id_users']);
            $role = $this->CI->roles_model->find($user['id_roles']);

            // Get username from user_settings
            $user_settings = $this->CI->db
                ->get_where('user_settings', ['id_users' => $user['id']])
                ->row_array();
        } catch (Exception $e) {
            return null;
        }

        $user_data = [
            'user_id' => $user['id'],
            'user_email' => $user['email'],
            'username' => $user_settings['username'] ?? '',
            'role_slug' => $role['slug'],
            'timezone' => $user['timezone'] ?? null,
        ];

        $access_token = $this->generate_access_token($user_data);

        return [
            'access_token' => $access_token,
            'token_type' => 'Bearer',
            'expires_in' => $this->access_token_expiry,
        ];
    }

    /**
     * Revoke a refresh token (logout).
     *
     * @param string $refresh_token Refresh token.
     *
     * @return bool Returns true if revoked.
     */
    public function revoke_token(string $refresh_token): bool
    {
        return $this->CI->refresh_tokens_model->revoke($refresh_token);
    }

    /**
     * Revoke all tokens for a user.
     *
     * @param int $user_id User ID.
     *
     * @return bool Returns true if revoked.
     */
    public function revoke_all_user_tokens(int $user_id): bool
    {
        return $this->CI->refresh_tokens_model->revoke_all_for_user($user_id);
    }

    /**
     * Get token expiry configuration.
     *
     * @return array Returns expiry times in seconds.
     */
    public function get_expiry_config(): array
    {
        return [
            'access_token_expiry' => $this->access_token_expiry,
            'refresh_token_expiry' => $this->refresh_token_expiry,
        ];
    }

    /**
     * Clean up expired refresh tokens.
     *
     * @return int Returns number of deleted tokens.
     */
    public function cleanup_expired_tokens(): int
    {
        return $this->CI->refresh_tokens_model->delete_expired();
    }

    /**
     * 2FA pending token expiry in seconds (5 minutes).
     *
     * @var int
     */
    protected int $two_factor_pending_expiry = 300;

    /**
     * Generate a temporary token for 2FA verification.
     *
     * This token is issued after successful password authentication
     * but before 2FA verification is complete.
     *
     * @param array $user_data User data from Accounts::check_login().
     *
     * @return string Returns the JWT pending token.
     */
    public function create_2fa_pending_token(array $user_data): string
    {
        $issued_at = time();
        $expiration = $issued_at + $this->two_factor_pending_expiry;

        $payload = [
            'iss' => $this->issuer,
            'iat' => $issued_at,
            'exp' => $expiration,
            'type' => '2fa_pending',
            'sub' => (string) $user_data['user_id'],
            'data' => [
                'user_id' => (int) $user_data['user_id'],
                'email' => $user_data['user_email'] ?? '',
                'username' => $user_data['username'] ?? '',
                'role' => $user_data['role_slug'] ?? '',
                'timezone' => $user_data['timezone'] ?? null,
                'language' => $user_data['language'] ?? null,
            ],
        ];

        return JWT::encode($payload, $this->secret_key, $this->algorithm);
    }

    /**
     * Validate and decode a 2FA pending token.
     *
     * @param string $token JWT pending token.
     *
     * @return object|null Returns the decoded token payload or null if invalid.
     */
    public function validate_2fa_pending_token(string $token): ?object
    {
        try {
            $decoded = JWT::decode($token, new Key($this->secret_key, $this->algorithm));

            // Verify this is a 2FA pending token
            if (!isset($decoded->type) || $decoded->type !== '2fa_pending') {
                return null;
            }

            return $decoded;
        } catch (ExpiredException $e) {
            return null;
        } catch (Exception $e) {
            return null;
        }
    }
}
