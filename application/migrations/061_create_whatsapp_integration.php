<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * EasyAppointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.5.0
 * ---------------------------------------------------------------------------- */

/**
 * Migration: Create WhatsApp Integration
 * 
 * Complete migration that creates the entire WhatsApp integration system:
 * - All WhatsApp tables with complete structure
 * - WhatsApp routine execution logs for detailed tracking
 * - Foreign key constraints
 * - Token rotation and reprocessing fields
 * - Integration with existing appointments table
 */
class Migration_Create_whatsapp_integration extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        // 1. Create whatsapp_integration_settings table
        if (!$this->db->table_exists('whatsapp_integration_settings')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'auto_increment' => true,
                ],
                'host' => [
                    'type' => 'VARCHAR',
                    'constraint' => 255,
                    'null' => true,
                ],
                'port' => [
                    'type' => 'INT',
                    'constraint' => 5,
                    'default' => 21465,
                ],
                'session' => [
                    'type' => 'VARCHAR',
                    'constraint' => 100,
                    'null' => true,
                ],
                'secret_key_enc' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
                'token_enc' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
                'wait_qr' => [
                    'type' => 'TINYINT',
                    'constraint' => 1,
                    'default' => 1,
                ],
                'enabled' => [
                    'type' => 'TINYINT',
                    'constraint' => 1,
                    'default' => 0,
                ],
                'create_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
                'update_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
                // Token rotation fields
                'token_prev_enc' => [
                    'type' => 'TEXT',
                    'null' => TRUE,
                    'comment' => 'Previous encrypted token (for rollback)'
                ],
                'token_prev_rotated_at' => [
                    'type' => 'DATETIME',
                    'null' => TRUE,
                ],
                'token_rotated_at' => [
                    'type' => 'DATETIME',
                    'null' => TRUE,
                ],
            ]);

            $this->dbforge->add_key('id', true);
            $this->dbforge->create_table('whatsapp_integration_settings');

            // Insert default settings
            $this->db->insert('whatsapp_integration_settings', [
                'host' => getenv('WPP_HOST') ?: 'http://localhost',
                'port' => getenv('WPP_PORT') ?: 21465,
                'session' => getenv('WPP_SESSION') ?: 'default',
                'enabled' => 0,
                'wait_qr' => 1,
                'create_datetime' => date('Y-m-d H:i:s'),
                'update_datetime' => date('Y-m-d H:i:s'),
            ]);
        }

        // 2. Create whatsapp_templates table
        if (!$this->db->table_exists('whatsapp_templates')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'auto_increment' => true,
                ],
                'name' => [
                    'type' => 'VARCHAR',
                    'constraint' => 255,
                    'null' => false,
                ],
                'status_key' => [
                    'type' => 'VARCHAR',
                    'constraint' => 50,
                    'null' => false,
                ],
                'enabled' => [
                    'type' => 'TINYINT',
                    'constraint' => 1,
                    'default' => 1,
                ],
                'language' => [
                    'type' => 'VARCHAR',
                    'constraint' => 10,
                    'null' => true,
                ],
                'body' => [
                    'type' => 'TEXT',
                    'null' => false,
                ],
                'create_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
                'update_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
            ]);

            $this->dbforge->add_key('id', true);
            $this->dbforge->add_key('status_key');
            $this->dbforge->create_table('whatsapp_templates');
        }

        // 3. Create whatsapp_message_logs table
        if (!$this->db->table_exists('whatsapp_message_logs')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'auto_increment' => true,
                ],
                'appointment_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'null' => true,
                ],
                'template_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'null' => true,
                ],
                'status_key' => [
                    'type' => 'VARCHAR',
                    'constraint' => 50,
                    'null' => true,
                ],
                'to_phone' => [
                    'type' => 'VARCHAR',
                    'constraint' => 50,
                    'null' => false,
                ],
                'body_hash' => [
                    'type' => 'VARCHAR',
                    'constraint' => 64,
                    'null' => true,
                ],
                'send_type' => [
                    'type' => 'ENUM',
                    'constraint' => ['onCreate', 'onUpdate', 'manual'],
                    'null' => false,
                ],
                'provider' => [
                    'type' => 'VARCHAR',
                    'constraint' => 50,
                    'default' => 'wppconnect',
                ],
                'request_payload' => [
                    'type' => 'JSON',
                    'null' => true,
                ],
                'response_payload' => [
                    'type' => 'JSON',
                    'null' => true,
                ],
                'http_status' => [
                    'type' => 'INT',
                    'constraint' => 3,
                    'null' => true,
                ],
                'result' => [
                    'type' => 'ENUM',
                    'constraint' => ['SUCCESS', 'FAILURE', 'PENDING'],
                    'default' => 'PENDING',
                ],
                'error_code' => [
                    'type' => 'VARCHAR',
                    'constraint' => 50,
                    'null' => true,
                ],
                'error_message' => [
                    'type' => 'TEXT',
                    'null' => true,
                ],
                'create_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
                'update_datetime' => [
                    'type' => 'DATETIME',
                    'null' => true,
                ],
            ]);

            $this->dbforge->add_key('id', true);
            $this->dbforge->add_key('appointment_id');
            $this->dbforge->add_key('template_id');
            $this->dbforge->add_key('status_key');
            $this->dbforge->add_key('result');
            $this->dbforge->add_key('create_datetime');
            
            $this->dbforge->create_table('whatsapp_message_logs');
        }

        // 4. Create whatsapp_token_reveal_logs table
        if (!$this->db->table_exists('whatsapp_token_reveal_logs')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'auto_increment' => TRUE
                ],
                'user_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'null' => TRUE
                ],
                'role_slug' => [
                    'type' => 'VARCHAR',
                    'constraint' => 128,
                    'null' => TRUE
                ],
                'action' => [
                    'type' => 'VARCHAR',
                    'constraint' => 32,
                    'null' => FALSE
                ],
                'status' => [
                    'type' => 'VARCHAR',
                    'constraint' => 32,
                    'null' => FALSE
                ],
                'ip' => [
                    'type' => 'VARCHAR',
                    'constraint' => 45,
                    'null' => TRUE
                ],
                'user_agent' => [
                    'type' => 'TEXT',
                    'null' => TRUE
                ],
                'created_at' => [
                    'type' => 'DATETIME',
                    'null' => TRUE
                ]
            ]);

            $this->dbforge->add_key('id', TRUE);
            $this->dbforge->create_table('whatsapp_token_reveal_logs');
        }

        // 5. Create rotinas_whatsapp table
        if (!$this->db->table_exists('rotinas_whatsapp')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'auto_increment' => TRUE
                ],
                'name' => [
                    'type' => 'VARCHAR',
                    'constraint' => 255,
                    'null' => FALSE
                ],
                'status_agendamento' => [
                    'type' => 'VARCHAR',
                    'constraint' => 128,
                    'null' => FALSE,
                    'comment' => 'Appointment status to match (e.g., Confirmado)'
                ],
                'template_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'null' => FALSE
                ],
                'tempo_antes_horas' => [
                    'type' => 'INT',
                    'constraint' => 5,
                    'default' => 1,
                    'null' => FALSE,
                    'comment' => 'Hours before appointment to send reminder'
                ],
                'ativa' => [
                    'type' => 'TINYINT',
                    'constraint' => 1,
                    'default' => 1,
                    'null' => FALSE
                ],
                'create_datetime' => [
                    'type' => 'DATETIME',
                    'null' => TRUE
                ],
                'update_datetime' => [
                    'type' => 'DATETIME',
                    'null' => TRUE
                ],
            ]);

            $this->dbforge->add_key('id', TRUE);
            $this->dbforge->create_table('rotinas_whatsapp');
        }

        // 6. Create whatsapp_routine_sends table
        if (!$this->db->table_exists('whatsapp_routine_sends')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'auto_increment' => TRUE
                ],
                'routine_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'null' => FALSE
                ],
                'appointment_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'null' => FALSE
                ],
                'log_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'null' => TRUE,
                    'comment' => 'Optional reference to whatsapp_message_logs entry'
                ],
                'sent_at' => [
                    'type' => 'DATETIME',
                    'null' => TRUE
                ],
                // Reprocessing fields
                'calculated_send_time' => [
                    'type' => 'DATETIME',
                    'null' => TRUE,
                    'comment' => 'The exact datetime (UTC) when the message was calculated to be sent.'
                ],
                'appointment_start_time' => [
                    'type' => 'DATETIME',
                    'null' => TRUE,
                    'comment' => 'The start_datetime of the appointment when the routine was processed.'
                ],
                'routine_hours_before' => [
                    'type' => 'INT',
                    'constraint' => 5,
                    'null' => TRUE,
                    'comment' => 'The "hours before" setting of the routine when it was processed.'
                ],
            ]);

            $this->dbforge->add_key('id', TRUE);
            $this->dbforge->add_key('routine_id');
            $this->dbforge->add_key('appointment_id');
            $this->dbforge->create_table('whatsapp_routine_sends');
        }

        // 7. Add template_id to appointments table
        if ($this->db->table_exists('appointments') && !$this->db->field_exists('template_id', 'appointments')) {
            $fields = [
                'template_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'null' => true,
                    'after' => 'status',
                ],
            ];

            $this->dbforge->add_column('appointments', $fields);
        }

        // 8. Create whatsapp_routine_execution_logs table
        if (!$this->db->table_exists('whatsapp_routine_execution_logs')) {
            $this->dbforge->add_field([
                'id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'auto_increment' => TRUE
                ],
                'routine_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'null' => FALSE,
                    'comment' => 'Reference to rotinas_whatsapp.id'
                ],
                'routine_name' => [
                    'type' => 'VARCHAR',
                    'constraint' => 255,
                    'null' => FALSE,
                    'comment' => 'Name of the routine at execution time'
                ],
                'execution_status' => [
                    'type' => 'ENUM',
                    'constraint' => ['SUCCESS', 'FAILURE', 'PARTIAL_SUCCESS'],
                    'null' => FALSE,
                    'comment' => 'Overall execution status'
                ],
                'appointment_status' => [
                    'type' => 'VARCHAR',
                    'constraint' => 50,
                    'null' => FALSE,
                    'comment' => 'Appointment status filter used (booked, confirmed, etc)'
                ],
                'template_id' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'null' => TRUE,
                    'comment' => 'Template used for this execution'
                ],
                'template_name' => [
                    'type' => 'VARCHAR',
                    'constraint' => 255,
                    'null' => TRUE,
                    'comment' => 'Template name at execution time'
                ],
                'message_type' => [
                    'type' => 'VARCHAR',
                    'constraint' => 100,
                    'null' => FALSE,
                    'default' => 'routine',
                    'comment' => 'Type of message sent (routine, reminder, etc)'
                ],
                'total_appointments_found' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'default' => 0,
                    'comment' => 'Total appointments found for processing'
                ],
                'successful_sends' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'default' => 0,
                    'comment' => 'Number of successfully sent messages'
                ],
                'failed_sends' => [
                    'type' => 'INT',
                    'constraint' => 11,
                    'unsigned' => TRUE,
                    'default' => 0,
                    'comment' => 'Number of failed message sends'
                ],
                'clients_notified' => [
                    'type' => 'JSON',
                    'null' => TRUE,
                    'comment' => 'JSON array of clients that were notified with details'
                ],
                'execution_details' => [
                    'type' => 'JSON',
                    'null' => TRUE,
                    'comment' => 'JSON object with detailed execution information'
                ],
                'error_message' => [
                    'type' => 'TEXT',
                    'null' => TRUE,
                    'comment' => 'Error message if execution failed'
                ],
                'execution_time_seconds' => [
                    'type' => 'DECIMAL',
                    'constraint' => '10,3',
                    'null' => TRUE,
                    'comment' => 'Time taken to execute the routine in seconds'
                ],
                'execution_datetime' => [
                    'type' => 'DATETIME',
                    'null' => FALSE,
                    'comment' => 'When the routine execution started'
                ],
                'create_datetime' => [
                    'type' => 'DATETIME',
                    'null' => FALSE,
                    'comment' => 'When this log record was created'
                ]
            ]);

            $this->dbforge->add_key('id', TRUE);
            $this->dbforge->add_key(['routine_id', 'execution_datetime']);
            $this->dbforge->add_key('execution_status');
            $this->dbforge->add_key('execution_datetime');
            $this->dbforge->create_table('whatsapp_routine_execution_logs');
        }

        // 9. Add foreign key constraints
        $this->add_foreign_keys();
    }

    /**
     * Add foreign key constraints
     */
    private function add_foreign_keys(): void
    {
        // Helper function to check if foreign key exists
        $fk_exists = function($table, $constraint_name) {
            $result = $this->db->query(
                "SELECT COUNT(*) as count FROM information_schema.KEY_COLUMN_USAGE 
                 WHERE CONSTRAINT_SCHEMA = DATABASE() 
                 AND TABLE_NAME = '{$this->db->dbprefix($table)}' 
                 AND CONSTRAINT_NAME = '{$constraint_name}'"
            );
            return $result->row()->count > 0;
        };

        // WhatsApp message logs foreign keys
        if ($this->db->table_exists('appointments') && !$fk_exists('whatsapp_message_logs', 'whatsapp_message_logs_appointment_id_fk')) {
            try {
                $this->db->query(
                    'ALTER TABLE `' . $this->db->dbprefix('whatsapp_message_logs') . '` 
                     ADD CONSTRAINT `whatsapp_message_logs_appointment_id_fk` 
                     FOREIGN KEY (`appointment_id`) REFERENCES `' . $this->db->dbprefix('appointments') . '` (`id`) 
                     ON DELETE SET NULL ON UPDATE CASCADE'
                );
            } catch (Exception $e) {
                // Foreign key creation failed, continue
            }
        }

        if ($this->db->table_exists('whatsapp_templates') && !$fk_exists('whatsapp_message_logs', 'whatsapp_message_logs_template_id_fk')) {
            try {
                $this->db->query(
                    'ALTER TABLE `' . $this->db->dbprefix('whatsapp_message_logs') . '` 
                     ADD CONSTRAINT `whatsapp_message_logs_template_id_fk` 
                     FOREIGN KEY (`template_id`) REFERENCES `' . $this->db->dbprefix('whatsapp_templates') . '` (`id`) 
                     ON DELETE SET NULL ON UPDATE CASCADE'
                );
            } catch (Exception $e) {
                // Foreign key creation failed, continue
            }
        }

        // Appointments template_id foreign key
        if ($this->db->table_exists('whatsapp_templates') && $this->db->field_exists('template_id', 'appointments') && !$fk_exists('appointments', 'appointments_template_id_fk')) {
            try {
                $this->db->query(
                    'ALTER TABLE `' . $this->db->dbprefix('appointments') . '` 
                     ADD CONSTRAINT `appointments_template_id_fk` 
                     FOREIGN KEY (`template_id`) REFERENCES `' . $this->db->dbprefix('whatsapp_templates') . '` (`id`) 
                     ON DELETE SET NULL ON UPDATE CASCADE'
                );
            } catch (Exception $e) {
                // Foreign key creation failed, continue
            }
        }

        // WhatsApp routine execution logs foreign keys
        if ($this->db->table_exists('rotinas_whatsapp') && !$fk_exists('whatsapp_routine_execution_logs', 'whatsapp_execution_logs_routine_id_fk')) {
            try {
                $this->db->query(
                    'ALTER TABLE `' . $this->db->dbprefix('whatsapp_routine_execution_logs') . '` 
                     ADD CONSTRAINT `whatsapp_execution_logs_routine_id_fk` 
                     FOREIGN KEY (`routine_id`) REFERENCES `' . $this->db->dbprefix('rotinas_whatsapp') . '` (`id`) 
                     ON DELETE CASCADE ON UPDATE CASCADE'
                );
            } catch (Exception $e) {
                // Foreign key creation failed, continue
            }
        }

        if ($this->db->table_exists('whatsapp_templates') && !$fk_exists('whatsapp_routine_execution_logs', 'whatsapp_execution_logs_template_id_fk')) {
            try {
                $this->db->query(
                    'ALTER TABLE `' . $this->db->dbprefix('whatsapp_routine_execution_logs') . '` 
                     ADD CONSTRAINT `whatsapp_execution_logs_template_id_fk` 
                     FOREIGN KEY (`template_id`) REFERENCES `' . $this->db->dbprefix('whatsapp_templates') . '` (`id`) 
                     ON DELETE SET NULL ON UPDATE CASCADE'
                );
            } catch (Exception $e) {
                // Foreign key creation failed, continue
            }
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        // Drop foreign key constraints first
        $this->drop_foreign_keys();

        // Drop tables in reverse order (respecting foreign key constraints)
        $tables_to_drop = [
            'whatsapp_routine_execution_logs',
            'whatsapp_routine_sends',
            'rotinas_whatsapp', 
            'whatsapp_token_reveal_logs',
            'whatsapp_message_logs',
            'whatsapp_templates',
            'whatsapp_integration_settings'
        ];

        foreach ($tables_to_drop as $table) {
            if ($this->db->table_exists($table)) {
                $this->dbforge->drop_table($table);
            }
        }

        // Remove template_id from appointments table
        if ($this->db->field_exists('template_id', 'appointments')) {
            $this->dbforge->drop_column('appointments', 'template_id');
        }
    }

    /**
     * Drop foreign key constraints
     */
    private function drop_foreign_keys(): void
    {
        $this->db->query('SET FOREIGN_KEY_CHECKS = 0');
        
        // WhatsApp message logs foreign keys
        try {
            $this->db->query(
                'ALTER TABLE `' . $this->db->dbprefix('whatsapp_message_logs') . '` 
                 DROP FOREIGN KEY `whatsapp_message_logs_appointment_id_fk`'
            );
        } catch (Exception $e) {
            // Foreign key might not exist
        }

        try {
            $this->db->query(
                'ALTER TABLE `' . $this->db->dbprefix('whatsapp_message_logs') . '` 
                 DROP FOREIGN KEY `whatsapp_message_logs_template_id_fk`'
            );
        } catch (Exception $e) {
            // Foreign key might not exist
        }

        // Appointments template_id foreign key
        try {
            $this->db->query(
                'ALTER TABLE `' . $this->db->dbprefix('appointments') . '` 
                 DROP FOREIGN KEY `appointments_template_id_fk`'
            );
        } catch (Exception $e) {
            // Foreign key might not exist
        }

        // WhatsApp routine execution logs foreign keys
        try {
            $this->db->query(
                'ALTER TABLE `' . $this->db->dbprefix('whatsapp_routine_execution_logs') . '` 
                 DROP FOREIGN KEY `whatsapp_execution_logs_routine_id_fk`'
            );
        } catch (Exception $e) {
            // Foreign key might not exist
        }

        try {
            $this->db->query(
                'ALTER TABLE `' . $this->db->dbprefix('whatsapp_routine_execution_logs') . '` 
                 DROP FOREIGN KEY `whatsapp_execution_logs_template_id_fk`'
            );
        } catch (Exception $e) {
            // Foreign key might not exist
        }

        $this->db->query('SET FOREIGN_KEY_CHECKS = 1');
    }
}
