<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.6.0
 * ---------------------------------------------------------------------------- */

class Migration_Add_two_factor_columns_to_user_settings_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if (!$this->db->field_exists('two_factor_enabled', 'user_settings')) {
            $fields = [
                'two_factor_enabled' => [
                    'type' => 'TINYINT',
                    'constraint' => '4',
                    'default' => 0,
                    'after' => 'notifications',
                ],
            ];

            $this->dbforge->add_column('user_settings', $fields);
        }

        if (!$this->db->field_exists('two_factor_secret', 'user_settings')) {
            $fields = [
                'two_factor_secret' => [
                    'type' => 'VARCHAR',
                    'constraint' => '512',
                    'null' => true,
                    'after' => 'two_factor_enabled',
                ],
            ];

            $this->dbforge->add_column('user_settings', $fields);
        }

        if (!$this->db->field_exists('two_factor_recovery_codes', 'user_settings')) {
            $fields = [
                'two_factor_recovery_codes' => [
                    'type' => 'TEXT',
                    'null' => true,
                    'after' => 'two_factor_secret',
                ],
            ];

            $this->dbforge->add_column('user_settings', $fields);
        }

        if (!$this->db->table_exists('user_two_factor_devices')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'auto_increment' => true,
                ],
                'create_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
                'update_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
                'id_users' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                ],
                'device_hash' => [
                    'type' => 'VARCHAR',
                    'constraint' => '512',
                    'null' => true,
                ],
                'device_label' => [
                    'type' => 'VARCHAR',
                    'constraint' => '256',
                    'null' => true,
                ],
                'last_used_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
                'expires_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
            ]);

            $this->dbforge->add_key('id', true);
            $this->dbforge->add_key('id_users');
            $this->dbforge->add_key('device_hash');

            $this->dbforge->create_table('user_two_factor_devices', true, ['engine' => 'InnoDB']);
        }

        if (!$this->db->table_exists('ea_two_factor_rate_limit')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'auto_increment' => true,
                ],
                'ip_address' => [
                    'type' => 'VARCHAR',
                    'constraint' => '45',
                    'null' => false,
                ],
                'attempts' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'default' => 0,
                ],
                'reset_at' => [
                    'type' => 'DATETIME',
                    'null' => false,
                ],
                'created_at' => [
                    'type' => 'DATETIME',
                    'null' => false,
                ],
                'updated_at' => [
                    'type' => 'DATETIME',
                    'null' => false,
                ],
            ]);

            $this->dbforge->add_key('id', true);
            $this->dbforge->add_key('ip_address');
            $this->dbforge->add_key('reset_at');

            $this->dbforge->create_table('ea_two_factor_rate_limit', true, ['engine' => 'InnoDB']);
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        if ($this->db->field_exists('two_factor_enabled', 'user_settings')) {
            $this->dbforge->drop_column('user_settings', 'two_factor_enabled');
        }

        if ($this->db->field_exists('two_factor_secret', 'user_settings')) {
            $this->dbforge->drop_column('user_settings', 'two_factor_secret');
        }

        if ($this->db->field_exists('two_factor_recovery_codes', 'user_settings')) {
            $this->dbforge->drop_column('user_settings', 'two_factor_recovery_codes');
        }

        if ($this->db->table_exists('user_two_factor_devices')) {
            $this->dbforge->drop_table('user_two_factor_devices');
        }

        if ($this->db->table_exists('ea_two_factor_rate_limit')) {
            $this->dbforge->drop_table('ea_two_factor_rate_limit');
        }
    }
}



