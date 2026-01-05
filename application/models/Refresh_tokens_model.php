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
 * Refresh Tokens model.
 *
 * Handles database operations for JWT refresh tokens.
 *
 * @package Models
 */
class Refresh_tokens_model extends EA_Model
{
    /**
     * @var array
     */
    protected array $casts = [
        'id' => 'integer',
        'id_users' => 'integer',
    ];

    /**
     * Create a new refresh token record.
     *
     * @param int $user_id User ID.
     * @param string $token Raw refresh token (will be hashed).
     * @param DateTime $expires_at Token expiration date.
     * @param string|null $device_info Device information (user agent).
     * @param string|null $ip_address Client IP address.
     *
     * @return int Returns the refresh token ID.
     *
     * @throws RuntimeException
     */
    public function create(
        int $user_id,
        string $token,
        DateTime $expires_at,
        ?string $device_info = null,
        ?string $ip_address = null,
    ): int {
        $data = [
            'id_users' => $user_id,
            'token' => hash('sha256', $token),
            'expires_at' => $expires_at->format('Y-m-d H:i:s'),
            'device_info' => $device_info,
            'ip_address' => $ip_address,
            'created_at' => date('Y-m-d H:i:s'),
        ];

        if (!$this->db->insert('refresh_tokens', $data)) {
            throw new RuntimeException('Could not create refresh token.');
        }

        return $this->db->insert_id();
    }

    /**
     * Find a refresh token by its raw value.
     *
     * @param string $token Raw refresh token.
     *
     * @return array|null Returns token record or null if not found.
     */
    public function find_by_token(string $token): ?array
    {
        $hashed = hash('sha256', $token);

        $result = $this->db->get_where('refresh_tokens', ['token' => $hashed])->row_array();

        if ($result) {
            $this->cast($result);
        }

        return $result ?: null;
    }

    /**
     * Find a refresh token by ID.
     *
     * @param int $id Token ID.
     *
     * @return array Returns token record.
     *
     * @throws InvalidArgumentException
     */
    public function find(int $id): array
    {
        $result = $this->db->get_where('refresh_tokens', ['id' => $id])->row_array();

        if (!$result) {
            throw new InvalidArgumentException('Refresh token not found: ' . $id);
        }

        $this->cast($result);

        return $result;
    }

    /**
     * Revoke (delete) a specific refresh token.
     *
     * @param string $token Raw refresh token.
     *
     * @return bool Returns true if deleted.
     */
    public function revoke(string $token): bool
    {
        $hashed = hash('sha256', $token);

        return $this->db->delete('refresh_tokens', ['token' => $hashed]);
    }

    /**
     * Revoke all refresh tokens for a user.
     *
     * @param int $user_id User ID.
     *
     * @return bool Returns true if deleted.
     */
    public function revoke_all_for_user(int $user_id): bool
    {
        return $this->db->delete('refresh_tokens', ['id_users' => $user_id]);
    }

    /**
     * Delete all expired refresh tokens.
     *
     * @return int Returns number of deleted records.
     */
    public function delete_expired(): int
    {
        $this->db->where('expires_at <', date('Y-m-d H:i:s'));
        $this->db->delete('refresh_tokens');

        return $this->db->affected_rows();
    }

    /**
     * Check if a refresh token is valid and not expired.
     *
     * @param string $token Raw refresh token.
     *
     * @return bool Returns true if valid.
     */
    public function is_valid(string $token): bool
    {
        $record = $this->find_by_token($token);

        if (!$record) {
            return false;
        }

        return strtotime($record['expires_at']) > time();
    }

    /**
     * Get all active tokens for a user.
     *
     * @param int $user_id User ID.
     *
     * @return array Returns array of token records (without the hashed token).
     */
    public function get_user_tokens(int $user_id): array
    {
        $tokens = $this->db
            ->select('id, device_info, ip_address, created_at, expires_at')
            ->where('id_users', $user_id)
            ->where('expires_at >', date('Y-m-d H:i:s'))
            ->order_by('created_at', 'DESC')
            ->get('refresh_tokens')
            ->result_array();

        foreach ($tokens as &$token) {
            $this->cast($token);
        }

        return $tokens;
    }

    /**
     * Get the query builder interface.
     *
     * @return CI_DB_query_builder
     */
    public function query(): CI_DB_query_builder
    {
        return $this->db->from('refresh_tokens');
    }
}
