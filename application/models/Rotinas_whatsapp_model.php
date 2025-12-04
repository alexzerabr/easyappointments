<?php defined('BASEPATH') or exit('No direct script access allowed');

class Rotinas_whatsapp_model extends EA_Model
{
    /**
     * Get all active routines
     *
     * @return array
     */
    public function get_active(): array
    {
        $rows = $this->db->get_where('ea_rotinas_whatsapp', ['ativa' => 1])->result_array();
        foreach ($rows as &$r) $this->cast($r);
        return $rows;
    }

    /**
     * Find appointments due for a routine within a small window
     *
     * @param array $routine
     * @param int $window_minutes Window for future sends (default 5 minutes)
     * @return array
     */
    public function find_due_appointments(array $routine, int $window_minutes = 5): array
    {
        $hours_before = (int)($routine['tempo_antes_horas'] ?? 1);
        $minutes_before = $hours_before * 60; // Convert hours to minutes for calculation

        // Get past window from environment variable (default 10 minutes)
        $past_window_minutes = (int)(getenv('WHATSAPP_ROUTINE_WINDOW_MINUTES') ?: 10);
        // We'll perform a timezone-aware check per appointment based on the customer's timezone.
        // Approach:
        //  - Interpret the appointment's start_datetime in the customer's timezone (if available),
        //    convert that moment to UTC, subtract minutes_before, and compare to current UTC.
        //  - This avoids using server timezone as the base for send time.

        // Broad SQL window to limit DB rows (look ahead a few days)
        $sql_from = date('Y-m-d H:i:s', strtotime('-1 day'));
        $sql_to = date('Y-m-d H:i:s', strtotime('+' . ($minutes_before + $window_minutes + 1440) . ' minutes'));

        $this->db
            ->select('ea_appointments.*')
            ->from('ea_appointments')
            ->join('ea_whatsapp_routine_sends s', 's.appointment_id = ea_appointments.id AND s.routine_id = ' . (int)$routine['id'], 'left')
            ->where('ea_appointments.is_unavailability', false)
            ->where('ea_appointments.status', $routine['status_agendamento'])
            ->where('ea_appointments.start_datetime >=', $sql_from)
            ->where('ea_appointments.start_datetime <=', $sql_to)
            ->group_start()
                ->where('s.appointment_id IS NULL', null, false)
                ->or_where('s.sent_at IS NULL', null, false)
                ->or_where('(s.appointment_start_time != ea_appointments.start_datetime OR s.routine_hours_before != ' . (int)$hours_before . ')', null, false)
            ->group_end();

        $query = $this->db->get();
        $candidates = $query->result_array();

        $CI = &get_instance();
        $CI->load->model('customers_model');

        $due = [];

        foreach ($candidates as $row) {
            $this->cast($row);

            // get customer timezone; fallback to app default then UTC
            $customer_tz = null;
            try {
                $customer = $CI->customers_model->find($row['id_users_customer']);
                $customer_tz = $customer['timezone'] ?? null;
            } catch (Exception $e) {
                $customer_tz = null;
            }
            $app_tz = setting('default_timezone') ?: date_default_timezone_get();
            $cust_tz = $customer_tz ?: $app_tz ?: 'UTC';

            try {
                // Set the customer timezone as the current timezone for calculations
                date_default_timezone_set($cust_tz);

                // Current time in customer timezone
                $now_local = new DateTime('now');

                // Window: allow sending from past_window_minutes in the past to window_minutes in the future
                // Past window is configured via WHATSAPP_ROUTINE_WINDOW_MINUTES env var
                // This prevents missing sends due to worker timing and delays
                $window_start_local = clone $now_local;
                $window_start_local->modify('-' . $past_window_minutes . ' minutes');

                $window_end_local = clone $now_local;
                $window_end_local->modify('+' . $window_minutes . ' minutes');

                // FIXED: Interpret appointment datetime in customer timezone directly
                // The database stores datetimes in the MySQL timezone (BRT -03:00)
                // We set the PHP timezone to customer timezone before parsing
                try {
                    // Parse datetime assuming it's already in customer timezone (matches MySQL tz)
                    $start_local = new DateTime($row['start_datetime']);
                } catch (Exception $dt_ex) {
                    log_message('warning', "Could not parse appointment {$row['id']} datetime: {$dt_ex->getMessage()}");
                    continue; // Skip this appointment
                }

                // Calculate send time in customer timezone by subtracting hours_before
                $send_time_local = clone $start_local;
                $send_time_local->modify('-' . $hours_before . ' hours');

                // If send_time_local is within [window_start_local, window_end_local], it's due
                // FIXED: Changed from ">= now" to ">= window_start" to allow sending recently missed messages
                if ($send_time_local >= $window_start_local && $send_time_local <= $window_end_local) {
                    // attach computed debug fields to the row for logging/inspection
                    $row['_send_time_local'] = $send_time_local->format('Y-m-d H:i:s');
                    $row['_start_local'] = $start_local->format('Y-m-d H:i:s');
                    $row['_customer_timezone'] = $cust_tz;
                    $due[] = $row;
                }

                // Debug logging
                log_message('debug', sprintf(
                    'Appointment %d: start_local=%s, send_local=%s, window_start=%s, now_local=%s, window_end_local=%s, is_due=%s',
                    $row['id'],
                    $start_local->format('Y-m-d H:i:s'),
                    $send_time_local->format('Y-m-d H:i:s'),
                    $window_start_local->format('Y-m-d H:i:s'),
                    $now_local->format('Y-m-d H:i:s'),
                    $window_end_local->format('Y-m-d H:i:s'),
                    ($send_time_local >= $window_start_local && $send_time_local <= $window_end_local) ? 'YES' : 'NO'
                ));
            } catch (Exception $e) {
                // skip malformed dates or timezone issues
                continue;
            } finally {
                // Reset timezone to UTC for other operations
                date_default_timezone_set('UTC');
            }
        }

        return $due;
    }

    /**
     * Find upcoming appointments by status (for force execution).
     * Returns appointments with start_datetime >= now and not already sent for this routine.
     *
     * @param array $routine
     * @return array
     */
    public function find_upcoming_by_status(array $routine): array
    {
        $now = date('Y-m-d H:i:s');

        $this->db
            ->select('ea_appointments.*')
            ->from('ea_appointments')
            ->join('ea_whatsapp_routine_sends s', 's.appointment_id = ea_appointments.id AND s.routine_id = ' . (int)$routine['id'], 'left')
            ->where('s.appointment_id IS NULL', null, false)
            ->where('ea_appointments.is_unavailability', false)
            ->where('ea_appointments.status', $routine['status_agendamento'])
            ->where('ea_appointments.start_datetime >=', $now)
            ->order_by('ea_appointments.start_datetime ASC');

        $query = $this->db->get();
        $rows = $query->result_array();
        foreach ($rows as &$r) $this->cast($r);
        return $rows;
    }

    /**
     * Mark appointment as sent for routine
     */
    public function mark_sent(int $routine_id, int $appointment_id, ?int $log_id = null, ?string $calculated_send_time = null, ?string $appointment_start_time = null, ?int $routine_hours_before = null): bool
    {
        if (empty($log_id)) {
            log_message('warning', 'Attempt to mark_sent without log_id for routine ' . $routine_id . ', appointment ' . $appointment_id);
            return false;
        }

        $this->db->where('routine_id', $routine_id)
                 ->where('appointment_id', $appointment_id)
                 ->delete('ea_whatsapp_routine_sends');

        return (bool)$this->db->insert('ea_whatsapp_routine_sends', [
            'routine_id' => $routine_id,
            'appointment_id' => $appointment_id,
            'log_id' => $log_id,
            'sent_at' => date('Y-m-d H:i:s'),
            'calculated_send_time' => $calculated_send_time,
            'appointment_start_time' => $appointment_start_time,
            'routine_hours_before' => $routine_hours_before
        ]);
    }
}


