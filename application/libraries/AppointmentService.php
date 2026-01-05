<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * Appointment Service.
 * 
 * Handles business logic for appointments to reduce Model complexity.
 */
class AppointmentService
{
    protected $CI;

    public function __construct()
    {
        $this->CI =& get_instance();
    }

    /**
     * Calculate the end datetime based on start time and service duration.
     * 
     * @param array $appointment Appointment data containing 'start_datetime' and 'id_services'.
     * @return string Calculated end datetime (Y-m-d H:i:s).
     */
    public function calculate_end_datetime(array $appointment): string
    {
        $start_timestamp = strtotime($appointment['start_datetime']);
        
        $service = $this->CI->db->get_where('services', ['id' => $appointment['id_services']])->row_array();
        $duration = $service ? (int)$service['duration'] : 30; // Default 30 min if not found

        return date('Y-m-d H:i:s', $start_timestamp + ($duration * 60));
    }
}
