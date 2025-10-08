<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * WhatsApp Routine Execution Logs Model
 * 
 * Manages logs for routine executions with detailed information about
 * each routine run, including success/failure status, templates used,
 * and clients notified.
 */
class Whatsapp_routine_execution_logs_model extends EA_Model
{
    /**
     * @var array
     */
    protected array $casts = [
        'id' => 'integer',
        'routine_id' => 'integer',
        'template_id' => 'integer',
        'total_appointments_found' => 'integer',
        'successful_sends' => 'integer',
        'failed_sends' => 'integer',
        'execution_time_seconds' => 'float',
    ];

    /**
     * @var array
     */
    protected array $api_resource = [
        'id' => 'id',
        'routineId' => 'routine_id',
        'routineName' => 'routine_name',
        'executionStatus' => 'execution_status',
        'appointmentStatus' => 'appointment_status',
        'templateId' => 'template_id',
        'templateName' => 'template_name',
        'messageType' => 'message_type',
        'totalAppointmentsFound' => 'total_appointments_found',
        'successfulSends' => 'successful_sends',
        'failedSends' => 'failed_sends',
        'clientsNotified' => 'clients_notified',
        'executionDetails' => 'execution_details',
        'errorMessage' => 'error_message',
        'executionTimeSeconds' => 'execution_time_seconds',
        'executionDatetime' => 'execution_datetime',
        'createDatetime' => 'create_datetime',
    ];

    /**
     * Create a new routine execution log entry
     *
     * @param array $data Log data
     * @return int Log ID
     */
    public function create_execution_log(array $data): int
    {
        $log_data = [
            'routine_id' => $data['routine_id'],
            'routine_name' => $data['routine_name'],
            'execution_status' => $data['execution_status'],
            'appointment_status' => $data['appointment_status'],
            'template_id' => $data['template_id'] ?? null,
            'template_name' => $data['template_name'] ?? null,
            'message_type' => $data['message_type'] ?? 'routine',
            'total_appointments_found' => $data['total_appointments_found'] ?? 0,
            'successful_sends' => $data['successful_sends'] ?? 0,
            'failed_sends' => $data['failed_sends'] ?? 0,
            'clients_notified' => is_array($data['clients_notified'] ?? null) 
                ? json_encode($data['clients_notified']) 
                : $data['clients_notified'],
            'execution_details' => is_array($data['execution_details'] ?? null) 
                ? json_encode($data['execution_details']) 
                : $data['execution_details'],
            'error_message' => $data['error_message'] ?? null,
            'execution_time_seconds' => $data['execution_time_seconds'] ?? null,
            'execution_datetime' => $data['execution_datetime'] ?? date('Y-m-d H:i:s'),
            'create_datetime' => date('Y-m-d H:i:s')
        ];

        if (!$this->db->insert('whatsapp_routine_execution_logs', $log_data)) {
            throw new RuntimeException('Could not insert routine execution log.');
        }

        return (int)$this->db->insert_id();
    }

    /**
     * Update an existing routine execution log
     *
     * @param int $log_id Log ID
     * @param array $data Data to update
     * @return bool Success status
     */
    public function update_execution_log(int $log_id, array $data): bool
    {
        $update_data = [];
        
        // Only update allowed fields
        $allowed_fields = [
            'execution_status', 'successful_sends', 'failed_sends', 
            'clients_notified', 'execution_details', 'error_message', 
            'execution_time_seconds'
        ];
        
        foreach ($allowed_fields as $field) {
            if (array_key_exists($field, $data)) {
                if (in_array($field, ['clients_notified', 'execution_details']) && is_array($data[$field])) {
                    $update_data[$field] = json_encode($data[$field]);
                } else {
                    $update_data[$field] = $data[$field];
                }
            }
        }

        if (empty($update_data)) {
            return true; // Nothing to update
        }

        return $this->db->update('whatsapp_routine_execution_logs', $update_data, ['id' => $log_id]);
    }

    /**
     * Get routine execution logs with optional filters
     *
     * @param array $filters Optional filters
     * @param int $limit Optional limit
     * @param int $offset Optional offset
     * @return array
     */
    public function get_execution_logs(array $filters = [], int $limit = 0, int $offset = 0): array
    {
        $this->db->select('rel.*, rt.name as current_routine_name, wt.name as current_template_name')
                 ->from('whatsapp_routine_execution_logs rel')
                 ->join('rotinas_whatsapp rt', 'rt.id = rel.routine_id', 'left')
                 ->join('whatsapp_templates wt', 'wt.id = rel.template_id', 'left');

        // Apply filters
        if (!empty($filters['routine_id'])) {
            $this->db->where('rel.routine_id', $filters['routine_id']);
        }
        
        if (!empty($filters['execution_status'])) {
            $this->db->where('rel.execution_status', $filters['execution_status']);
        }
        
        if (!empty($filters['appointment_status'])) {
            $this->db->where('rel.appointment_status', $filters['appointment_status']);
        }
        
        if (!empty($filters['date_from'])) {
            $this->db->where('rel.execution_datetime >=', $filters['date_from']);
        }
        
        if (!empty($filters['date_to'])) {
            $this->db->where('rel.execution_datetime <=', $filters['date_to']);
        }

        $this->db->order_by('rel.execution_datetime', 'DESC');

        if ($limit > 0) {
            $this->db->limit($limit, $offset);
        }

        $query = $this->db->get();
        $results = $query->result_array();

        // Decode JSON fields
        foreach ($results as &$result) {
            if (!empty($result['clients_notified'])) {
                $result['clients_notified'] = json_decode($result['clients_notified'], true);
            }
            if (!empty($result['execution_details'])) {
                $result['execution_details'] = json_decode($result['execution_details'], true);
            }
            $this->cast($result);
        }

        return $results;
    }

    /**
     * Get execution statistics for a routine
     *
     * @param int $routine_id Routine ID
     * @param string $date_from Optional start date
     * @param string $date_to Optional end date
     * @return array
     */
    public function get_routine_stats(int $routine_id, ?string $date_from = null, ?string $date_to = null): array
    {
        $this->db->select('
            COUNT(*) as total_executions,
            SUM(CASE WHEN execution_status = "SUCCESS" THEN 1 ELSE 0 END) as successful_executions,
            SUM(CASE WHEN execution_status = "FAILURE" THEN 1 ELSE 0 END) as failed_executions,
            SUM(CASE WHEN execution_status = "PARTIAL_SUCCESS" THEN 1 ELSE 0 END) as partial_executions,
            SUM(total_appointments_found) as total_appointments_processed,
            SUM(successful_sends) as total_successful_sends,
            SUM(failed_sends) as total_failed_sends,
            AVG(execution_time_seconds) as avg_execution_time
        ')->from('whatsapp_routine_execution_logs')
         ->where('routine_id', $routine_id);

        if ($date_from) {
            $this->db->where('execution_datetime >=', $date_from);
        }
        
        if ($date_to) {
            $this->db->where('execution_datetime <=', $date_to);
        }

        $query = $this->db->get();
        $result = $query->row_array();

        // Cast numeric values
        if ($result) {
            $result['total_executions'] = (int)$result['total_executions'];
            $result['successful_executions'] = (int)$result['successful_executions'];
            $result['failed_executions'] = (int)$result['failed_executions'];
            $result['partial_executions'] = (int)$result['partial_executions'];
            $result['total_appointments_processed'] = (int)$result['total_appointments_processed'];
            $result['total_successful_sends'] = (int)$result['total_successful_sends'];
            $result['total_failed_sends'] = (int)$result['total_failed_sends'];
            $result['avg_execution_time'] = $result['avg_execution_time'] ? (float)$result['avg_execution_time'] : null;
        }

        return $result ?: [];
    }

    /**
     * Get overall execution statistics
     *
     * @param string $date_from Optional start date
     * @param string $date_to Optional end date
     * @return array
     */
    public function get_overall_stats(?string $date_from = null, ?string $date_to = null): array
    {
        $this->db->select('
            COUNT(*) as total_executions,
            SUM(CASE WHEN execution_status = "SUCCESS" THEN 1 ELSE 0 END) as successful_executions,
            SUM(CASE WHEN execution_status = "FAILURE" THEN 1 ELSE 0 END) as failed_executions,
            SUM(CASE WHEN execution_status = "PARTIAL_SUCCESS" THEN 1 ELSE 0 END) as partial_executions,
            SUM(total_appointments_found) as total_appointments_processed,
            SUM(successful_sends) as total_successful_sends,
            SUM(failed_sends) as total_failed_sends,
            AVG(execution_time_seconds) as avg_execution_time,
            COUNT(DISTINCT routine_id) as active_routines
        ')->from('whatsapp_routine_execution_logs');

        if ($date_from) {
            $this->db->where('execution_datetime >=', $date_from);
        }
        
        if ($date_to) {
            $this->db->where('execution_datetime <=', $date_to);
        }

        $query = $this->db->get();
        $result = $query->row_array();

        // Cast numeric values
        if ($result) {
            foreach (['total_executions', 'successful_executions', 'failed_executions', 
                     'partial_executions', 'total_appointments_processed', 
                     'total_successful_sends', 'total_failed_sends', 'active_routines'] as $field) {
                $result[$field] = (int)$result[$field];
            }
            $result['avg_execution_time'] = $result['avg_execution_time'] ? (float)$result['avg_execution_time'] : null;
        }

        return $result ?: [];
    }

    /**
     * Clean up old execution logs
     *
     * @param int $days_to_keep Number of days to keep
     * @return int Number of deleted records
     */
    public function cleanup_old_logs(int $days_to_keep = 90): int
    {
        $date_limit = date('Y-m-d H:i:s', strtotime("-{$days_to_keep} days"));
        
        $this->db->where('create_datetime <', $date_limit);
        $this->db->delete('whatsapp_routine_execution_logs');
        
        return $this->db->affected_rows();
    }
}
