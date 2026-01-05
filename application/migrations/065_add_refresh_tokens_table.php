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

require_once APPPATH . 'core/EA_Migration.php';

/**
 * Add refresh_tokens table for JWT authentication.
 *
 * This migration creates the refresh_tokens table to store
 * JWT refresh tokens for API authentication.
 */
class Migration_Add_refresh_tokens_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if (!$this->db->table_exists('refresh_tokens')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'auto_increment' => true,
                ],
                'id_users' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                ],
                'token' => [
                    'type' => 'VARCHAR',
                    'constraint' => '255',
                    'null' => false,
                    'comment' => 'SHA256 hash of refresh token',
                ],
                'expires_at' => [
                    'type' => 'DATETIME',
                    'null' => false,
                ],
                'device_info' => [
                    'type' => 'TEXT',
                    'null' => true,
                    'comment' => 'User agent or device name',
                ],
                'ip_address' => [
                    'type' => 'VARCHAR',
                    'constraint' => '45',
                    'null' => true,
                    'comment' => 'IPv4 or IPv6 address',
                ],
                'created_at' => [
                    'type' => 'DATETIME',
                    'null' => false,
                ],
            ]);

            $this->dbforge->add_key('id', true);
            $this->dbforge->add_key('token');
            $this->dbforge->add_key('id_users');
            $this->dbforge->add_key('expires_at');

            $this->dbforge->create_table('refresh_tokens', true, ['engine' => 'InnoDB']);

            // Add unique constraint on token
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('refresh_tokens') .
                    '` ADD UNIQUE KEY `token_unique` (`token`)'
            );

            // Add foreign key to users table
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('refresh_tokens') .
                    '`
                ADD CONSTRAINT `refresh_tokens_user_fk`
                FOREIGN KEY (`id_users`) REFERENCES `' .
                    $this->db->dbprefix('users') .
                    '` (`id`)
                ON DELETE CASCADE ON UPDATE CASCADE'
            );
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        if ($this->db->table_exists('refresh_tokens')) {
            $this->dbforge->drop_table('refresh_tokens');
        }
    }
}
