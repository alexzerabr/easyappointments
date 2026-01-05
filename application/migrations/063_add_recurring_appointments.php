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
 * Add recurring appointments functionality.
 *
 * This migration creates the recurring_appointments table and adds
 * the id_recurring_appointment column to the appointments table.
 */
class Migration_Add_recurring_appointments extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        // Create recurring_appointments table
        if (!$this->db->table_exists('recurring_appointments')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'auto_increment' => true,
                ],
                'recurrence_type' => [
                    'type' => 'ENUM',
                    'constraint' => ['specific_days'],
                    'null' => false,
                    'comment' => 'Type of recurrence pattern (only specific_days is used)',
                ],
                'week_days' => [
                    'type' => 'VARCHAR',
                    'constraint' => '50',
                    'null' => false,
                    'comment' => 'Comma-separated list of weekdays (1=Monday, 7=Sunday)',
                ],
                'start_date' => [
                    'type' => 'DATE',
                    'null' => false,
                    'comment' => 'Treatment start date',
                ],
                'end_date' => [
                    'type' => 'DATE',
                    'null' => false,
                    'comment' => 'Treatment end date',
                ],
                'id_users_provider' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                ],
                'id_users_customer' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                ],
                'id_services' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                ],
                'appointment_time' => [
                    'type' => 'TIME',
                    'null' => false,
                    'comment' => 'Time of day for all appointments (from main form)',
                ],
                'duration' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                    'comment' => 'Duration in minutes',
                ],
                'location' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
                'notes' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
                'color' => [
                    'type' => 'VARCHAR',
                    'constraint' => '50',
                    'null' => true,
                ],
                'status' => [
                    'type' => 'VARCHAR',
                    'constraint' => '50',
                    'default' => 'Booked',
                ],
                'create_datetime' => [
                    'type' => 'DATETIME',
                    'null' => false,
                ],
                'update_datetime' => [
                    'type' => 'DATETIME',
                    'null' => false,
                ],
            ]);

            $this->dbforge->add_key('id', true);
            $this->dbforge->add_key('id_users_provider');
            $this->dbforge->add_key('id_users_customer');
            $this->dbforge->add_key('id_services');

            $this->dbforge->create_table('recurring_appointments', true, ['engine' => 'InnoDB']);

            // Add foreign keys
            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('recurring_appointments') .
                    '`
              ADD CONSTRAINT `' .
                    $this->db->dbprefix('recurring_appointments') .
                    '_ibfk_1` FOREIGN KEY (`id_users_provider`) REFERENCES `' .
                    $this->db->dbprefix('users') .
                    '` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
              ADD CONSTRAINT `' .
                    $this->db->dbprefix('recurring_appointments') .
                    '_ibfk_2` FOREIGN KEY (`id_users_customer`) REFERENCES `' .
                    $this->db->dbprefix('users') .
                    '` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
              ADD CONSTRAINT `' .
                    $this->db->dbprefix('recurring_appointments') .
                    '_ibfk_3` FOREIGN KEY (`id_services`) REFERENCES `' .
                    $this->db->dbprefix('services') .
                    '` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
            ',
            );
        }

        // Add id_recurring_appointment column to appointments table
        if (!$this->db->field_exists('id_recurring_appointment', 'appointments')) {
            $fields = [
                'id_recurring_appointment' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'null' => true,
                    'after' => 'id_caldav_calendar',
                    'comment' => 'Reference to recurring_appointments table',
                ],
            ];

            $this->dbforge->add_column('appointments', $fields);

            // Add foreign key
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('appointments') .
                    '`
                ADD CONSTRAINT `appointments_recurring_appointment`
                FOREIGN KEY (`id_recurring_appointment`) REFERENCES `' .
                    $this->db->dbprefix('recurring_appointments') .
                    '` (`id`)
                ON DELETE SET NULL ON UPDATE CASCADE'
            );
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        // Remove foreign key and column from appointments table
        if ($this->db->field_exists('id_recurring_appointment', 'appointments')) {
            // Drop foreign key first
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('appointments') .
                    '`
                DROP FOREIGN KEY `appointments_recurring_appointment`'
            );

            $this->dbforge->drop_column('appointments', 'id_recurring_appointment');
        }

        // Drop recurring_appointments table (foreign keys will be dropped automatically)
        if ($this->db->table_exists('recurring_appointments')) {
            $this->dbforge->drop_table('recurring_appointments');
        }
    }
}
