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
 * Recurring appointments model.
 *
 * @package Models
 */
class Recurring_appointments_model extends EA_Model
{
    /**
     * @var array
     */
    protected array $casts = [
        'id' => 'integer',
        'interval_days' => 'integer',
        'duration' => 'integer',
        'id_users_provider' => 'integer',
        'id_users_customer' => 'integer',
        'id_services' => 'integer',
    ];

    /**
     * @var array
     */
    protected array $api_resource = [
        'id' => 'id',
        'recurrenceType' => 'recurrence_type',
        'intervalDays' => 'interval_days',
        'weekDays' => 'week_days',
        'startDate' => 'start_date',
        'endDate' => 'end_date',
        'appointmentTime' => 'appointment_time',
        'duration' => 'duration',
        'location' => 'location',
        'notes' => 'notes',
        'color' => 'color',
        'status' => 'status',
        'serviceId' => 'id_services',
        'providerId' => 'id_users_provider',
        'customerId' => 'id_users_customer',
    ];

    /**
     * Save (insert or update) a recurring appointment.
     *
     * @param array $recurring_appointment Associative array with the recurring appointment data.
     *
     * @return int Returns the recurring appointment ID.
     *
     * @throws InvalidArgumentException
     */
    public function save(array $recurring_appointment): int
    {
        $this->validate($recurring_appointment);

        if (empty($recurring_appointment['id'])) {
            return $this->insert($recurring_appointment);
        } else {
            return $this->update($recurring_appointment);
        }
    }

    /**
     * Validate the recurring appointment data.
     *
     * @param array $recurring_appointment Associative array with the recurring appointment data.
     *
     * @throws InvalidArgumentException
     */
    public function validate(array $recurring_appointment): void
    {
        // If an ID is provided then check whether the record exists
        if (!empty($recurring_appointment['id'])) {
            $count = $this->db->get_where('recurring_appointments', ['id' => $recurring_appointment['id']])->num_rows();

            if (!$count) {
                throw new InvalidArgumentException(
                    'The provided recurring appointment ID does not exist in the database: ' . $recurring_appointment['id'],
                );
            }
        }

        // Make sure all required fields are provided
        if (
            empty($recurring_appointment['recurrence_type']) ||
            empty($recurring_appointment['start_date']) ||
            empty($recurring_appointment['end_date']) ||
            empty($recurring_appointment['id_users_provider']) ||
            empty($recurring_appointment['id_users_customer']) ||
            empty($recurring_appointment['id_services']) ||
            empty($recurring_appointment['appointment_time']) ||
            empty($recurring_appointment['duration'])
        ) {
            throw new InvalidArgumentException('Not all required fields are provided: ' . print_r($recurring_appointment, true));
        }

        // Validate recurrence_type
        $valid_types = ['weekly', 'interval', 'specific_days', 'custom'];
        if (!in_array($recurring_appointment['recurrence_type'], $valid_types)) {
            throw new InvalidArgumentException('Invalid recurrence_type: ' . $recurring_appointment['recurrence_type']);
        }

        // Validate start_date and end_date
        if (strtotime($recurring_appointment['start_date']) > strtotime($recurring_appointment['end_date'])) {
            throw new InvalidArgumentException('Start date must be before or equal to end date.');
        }

        // Type-specific validation
        if ($recurring_appointment['recurrence_type'] === 'interval' && empty($recurring_appointment['interval_days'])) {
            throw new InvalidArgumentException('interval_days is required for interval recurrence type.');
        }

        if ($recurring_appointment['recurrence_type'] === 'specific_days') {
            // Check if week_days is empty or contains only commas
            $week_days = trim($recurring_appointment['week_days'] ?? '');
            $clean_days = str_replace(',', '', $week_days);

            if (empty($clean_days)) {
                throw new InvalidArgumentException('week_days is required for specific_days recurrence type. Please select at least one day of the week.');
            }
        }
    }

    /**
     * Insert a new recurring appointment into the database.
     *
     * @param array $recurring_appointment Associative array with the recurring appointment data.
     *
     * @return int Returns the recurring appointment ID.
     *
     * @throws RuntimeException
     */
    protected function insert(array $recurring_appointment): int
    {
        $recurring_appointment['create_datetime'] = date('Y-m-d H:i:s');
        $recurring_appointment['update_datetime'] = date('Y-m-d H:i:s');

        if (!$this->db->insert('recurring_appointments', $recurring_appointment)) {
            throw new RuntimeException('Could not insert recurring appointment.');
        }

        return $this->db->insert_id();
    }

    /**
     * Update an existing recurring appointment.
     *
     * @param array $recurring_appointment Associative array with the recurring appointment data.
     *
     * @return int Returns the recurring appointment ID.
     *
     * @throws RuntimeException
     */
    protected function update(array $recurring_appointment): int
    {
        $recurring_appointment['update_datetime'] = date('Y-m-d H:i:s');

        if (!$this->db->update('recurring_appointments', $recurring_appointment, ['id' => $recurring_appointment['id']])) {
            throw new RuntimeException('Could not update recurring appointment record.');
        }

        return $recurring_appointment['id'];
    }

    /**
     * Get a specific recurring appointment from the database.
     *
     * @param int $recurring_appointment_id The ID of the record to be returned.
     *
     * @return array Returns an array with the recurring appointment data.
     *
     * @throws InvalidArgumentException
     */
    public function find(int $recurring_appointment_id): array
    {
        $recurring_appointment = $this->db->get_where('recurring_appointments', ['id' => $recurring_appointment_id])->row_array();

        if (!$recurring_appointment) {
            throw new InvalidArgumentException('The provided recurring appointment ID was not found in the database: ' . $recurring_appointment_id);
        }

        $this->cast($recurring_appointment);

        return $recurring_appointment;
    }

    /**
     * Get a specific field value from the database.
     *
     * @param int $recurring_appointment_id Recurring appointment ID.
     * @param string $field Name of the value to be returned.
     *
     * @return mixed Returns the selected recurring appointment value from the database.
     *
     * @throws InvalidArgumentException
     */
    public function value(int $recurring_appointment_id, string $field): mixed
    {
        if (empty($field)) {
            throw new InvalidArgumentException('The field argument is cannot be empty.');
        }

        if (empty($recurring_appointment_id)) {
            throw new InvalidArgumentException('The recurring appointment id argument cannot be empty.');
        }

        // Check whether the recurring appointment exists
        $query = $this->db->get_where('recurring_appointments', ['id' => $recurring_appointment_id]);

        if (!$query->num_rows()) {
            throw new InvalidArgumentException('The provided recurring appointment ID was not found in the database: ' . $recurring_appointment_id);
        }

        // Return the selected value
        return $query->row()->$field ?? null;
    }

    /**
     * Get all, or specific recurring appointments.
     *
     * @param array|string|null $where Where conditions.
     * @param int|null $limit Record limit.
     * @param int|null $offset Record offset.
     * @param string|null $order_by Order by.
     *
     * @return array Returns an array of recurring appointments.
     */
    public function get(
        array|string|null $where = null,
        int|null $limit = null,
        int|null $offset = null,
        ?string $order_by = null,
    ): array {
        if ($where !== null) {
            $this->db->where($where);
        }

        if ($order_by) {
            $this->db->order_by($this->quote_order_by($order_by));
        }

        $recurring_appointments = $this->db->get('recurring_appointments', $limit, $offset)->result_array();

        foreach ($recurring_appointments as &$recurring_appointment) {
            $this->cast($recurring_appointment);
        }

        return $recurring_appointments;
    }

    /**
     * Remove an existing recurring appointment from the database.
     *
     * @param int $recurring_appointment_id Recurring appointment ID.
     *
     * @throws RuntimeException
     */
    public function delete(int $recurring_appointment_id): void
    {
        $this->db->delete('recurring_appointments', ['id' => $recurring_appointment_id]);
    }

    /**
     * Generate dates for recurring appointments based on recurrence pattern.
     *
     * @param array $recurring_data Recurring appointment data.
     *
     * @return array Array of dates (Y-m-d format).
     */
    public function generate_dates(array $recurring_data): array
    {
        $dates = [];
        $start = new DateTime($recurring_data['start_date']);
        $end = new DateTime($recurring_data['end_date']);
        $recurrence_type = $recurring_data['recurrence_type'];

        // Maximum 365 appointments to prevent DoS
        $max_appointments = 365;

        switch ($recurrence_type) {
            case 'weekly':
                // Same day of the week
                $day_of_week = $start->format('w'); // 0 (Sunday) to 6 (Saturday)
                $current = clone $start;

                while ($current <= $end && count($dates) < $max_appointments) {
                    $dates[] = $current->format('Y-m-d');
                    $current->modify('+1 week');
                }
                break;

            case 'interval':
                // Every X days
                $interval_days = (int) $recurring_data['interval_days'];

                // Validate interval_days to prevent infinite loops
                if ($interval_days < 1 || $interval_days > 365) {
                    break;
                }

                $current = clone $start;

                while ($current <= $end && count($dates) < $max_appointments) {
                    $dates[] = $current->format('Y-m-d');
                    $current->modify("+{$interval_days} days");
                }
                break;

            case 'specific_days':
                // Specific weekdays (e.g., "1,3,5" for Mon, Wed, Fri)
                $week_days = explode(',', $recurring_data['week_days']);

                // Sanitize and validate week_days - only allow integers 1-7
                $week_days = array_filter(array_map('intval', $week_days), function($day) {
                    return $day >= 1 && $day <= 7;
                });

                if (empty($week_days)) {
                    break;
                }

                $current = clone $start;

                while ($current <= $end && count($dates) < $max_appointments) {
                    $current_day = $current->format('N'); // 1 (Monday) to 7 (Sunday)

                    if (in_array($current_day, $week_days)) {
                        $dates[] = $current->format('Y-m-d');
                    }

                    $current->modify('+1 day');
                }
                break;

            case 'custom':
                // Custom logic can be implemented here
                break;
        }

        return $dates;
    }

    /**
     * Generate appointments for a recurring series.
     *
     * @param int $recurring_id Recurring appointment ID.
     *
     * @return array Array of generated appointment IDs.
     *
     * @throws InvalidArgumentException
     */
    public function generate_appointments(int $recurring_id): array
    {
        $recurring = $this->find($recurring_id);
        $dates = $this->generate_dates($recurring);
        $appointment_ids = [];

        $this->load->model('appointments_model');

        foreach ($dates as $date) {
            $start_datetime = $date . ' ' . $recurring['appointment_time'];
            
            // Calculate end datetime
            $end_timestamp = strtotime($start_datetime) + ($recurring['duration'] * 60);
            $end_datetime = date('Y-m-d H:i:s', $end_timestamp);

            $appointment = [
                'start_datetime' => $start_datetime,
                'end_datetime' => $end_datetime,
                'id_users_provider' => $recurring['id_users_provider'],
                'id_users_customer' => $recurring['id_users_customer'],
                'id_services' => $recurring['id_services'],
                'location' => $recurring['location'] ?? '',
                'notes' => $recurring['notes'] ?? '',
                'color' => $recurring['color'] ?? '',
                'status' => $recurring['status'] ?? 'pending',
                'id_recurring_appointment' => $recurring_id,
                'is_unavailability' => false,
            ];

            try {
                $appointment_id = $this->appointments_model->save($appointment);
                $appointment_ids[] = $appointment_id;
            } catch (Exception $e) {
                // Log error but continue with other appointments
                log_message('error', 'Failed to create appointment for recurring series: ' . $e->getMessage());
            }
        }

        return $appointment_ids;
    }

    /**
     * Validate conflicts for recurring appointments.
     *
     * @param array $recurring_data Recurring appointment data.
     *
     * @return array Array of conflicts with dates and conflicting appointments.
     */
    public function validate_conflicts(array $recurring_data): array
    {
        $conflicts = [];
        $generated_dates = $this->generate_dates($recurring_data);

        foreach ($generated_dates as $date) {
            $start = $date . ' ' . $recurring_data['appointment_time'];
            $end_time = date('H:i:s', strtotime($start) + ($recurring_data['duration'] * 60));
            $end = $date . ' ' . $end_time;

            // Check if provider is available
            $this->db->where('id_users_provider', $recurring_data['id_users_provider']);
            $this->db->where('start_datetime <', $end);
            $this->db->where('end_datetime >', $start);
            $this->db->where('is_unavailability', false);
            
            $existing = $this->db->get('appointments')->result_array();

            if (!empty($existing)) {
                $conflicts[] = [
                    'date' => $date,
                    'time' => $recurring_data['appointment_time'],
                    'conflicting_appointments' => $existing,
                ];
            }
        }

        return $conflicts;
    }

    /**
     * Get all appointments in a recurring series.
     *
     * @param int $recurring_id Recurring appointment ID.
     *
     * @return array Array of appointments.
     */
    public function get_appointments_in_series(int $recurring_id): array
    {
        $this->load->model('appointments_model');
        
        return $this->appointments_model->get(['id_recurring_appointment' => $recurring_id]);
    }
}


