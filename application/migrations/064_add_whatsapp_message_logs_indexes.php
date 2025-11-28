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
 * Add performance indexes to whatsapp_message_logs table.
 *
 * This migration adds optimized indexes to improve query performance for:
 * - Duplicate message detection by hash
 * - Time-window based duplicate checking
 * - Appointment-based log retrieval with ordering
 */
class Migration_Add_whatsapp_message_logs_indexes extends EA_Migration
{
    /**
     * Upgrade.
     */
    public function up()
    {
        if (!$this->db->table_exists('whatsapp_message_logs')) {
            return;
        }

        // Drop existing simple indexes that will be replaced by composite indexes
        // Note: appointment_id, template_id, status_key already have individual indexes from migration 061

        // 1. Add index on body_hash for fast duplicate detection
        // Used by: Whatsapp_message_logs_model::exists_by_hash()
        // Query: SELECT * FROM whatsapp_message_logs WHERE body_hash = ?
        $table_name = $this->db->dbprefix('whatsapp_message_logs');
        if (!$this->db->query("SHOW INDEX FROM {$table_name} WHERE Key_name = 'idx_body_hash'")->num_rows()) {
            $this->db->query("ALTER TABLE {$table_name} ADD INDEX idx_body_hash (body_hash)");
        }

        // 2. Add composite index for time-window duplicate checking
        // Used by: Whatsapp_message_logs_model::is_duplicate_send()
        // Query: WHERE create_datetime >= ? AND appointment_id = ? AND template_id = ? AND send_type = ? AND status_key = ?
        // Order matters: Most selective columns first (create_datetime filters by time window, then specific identifiers)
        if (!$this->db->query("SHOW INDEX FROM {$table_name} WHERE Key_name = 'idx_duplicate_check'")->num_rows()) {
            $this->db->query("
                ALTER TABLE {$table_name}
                ADD INDEX idx_duplicate_check (create_datetime, appointment_id, template_id, send_type, status_key)
            ");
        }

        // 3. Add composite index for appointment log retrieval with ordering
        // Used by: Whatsapp_message_logs_model::get_by_appointment()
        // Query: SELECT * FROM whatsapp_message_logs WHERE appointment_id = ? ORDER BY create_datetime DESC
        // Note: MySQL can use this index for both filtering and sorting
        if (!$this->db->query("SHOW INDEX FROM {$table_name} WHERE Key_name = 'idx_appointment_datetime'")->num_rows()) {
            $this->db->query("
                ALTER TABLE {$table_name}
                ADD INDEX idx_appointment_datetime (appointment_id, create_datetime)
            ");
        }

        // 4. Add index for filtering by result status (for statistics and monitoring)
        // Used by: get_statistics(), get_logs() with result filtering
        if (!$this->db->query("SHOW INDEX FROM {$table_name} WHERE Key_name = 'idx_result_datetime'")->num_rows()) {
            $this->db->query("
                ALTER TABLE {$table_name}
                ADD INDEX idx_result_datetime (result, create_datetime)
            ");
        }

        // 5. Add covering index for routine sends table
        // Optimize: Rotinas_whatsapp_model::has_been_sent()
        if ($this->db->table_exists('whatsapp_routine_sends')) {
            $routine_sends_table = $this->db->dbprefix('whatsapp_routine_sends');
            if (!$this->db->query("SHOW INDEX FROM {$routine_sends_table} WHERE Key_name = 'idx_routine_appointment'")->num_rows()) {
                $this->db->query("
                    ALTER TABLE {$routine_sends_table}
                    ADD INDEX idx_routine_appointment (routine_id, appointment_id, sent_at)
                ");
            }
        }
    }

    /**
     * Downgrade.
     */
    public function down()
    {
        if (!$this->db->table_exists('whatsapp_message_logs')) {
            return;
        }

        $table_name = $this->db->dbprefix('whatsapp_message_logs');

        // Drop all indexes added in up()
        $indexes_to_drop = [
            'idx_body_hash',
            'idx_duplicate_check',
            'idx_appointment_datetime',
            'idx_result_datetime',
        ];

        foreach ($indexes_to_drop as $index_name) {
            if ($this->db->query("SHOW INDEX FROM {$table_name} WHERE Key_name = '{$index_name}'")->num_rows()) {
                $this->db->query("ALTER TABLE {$table_name} DROP INDEX {$index_name}");
            }
        }

        // Drop routine_sends index
        if ($this->db->table_exists('whatsapp_routine_sends')) {
            $routine_sends_table = $this->db->dbprefix('whatsapp_routine_sends');
            if ($this->db->query("SHOW INDEX FROM {$routine_sends_table} WHERE Key_name = 'idx_routine_appointment'")->num_rows()) {
                $this->db->query("ALTER TABLE {$routine_sends_table} DROP INDEX idx_routine_appointment");
            }
        }
    }
}
