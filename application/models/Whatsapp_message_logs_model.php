<?php defined('BASEPATH') or exit('No direct script access allowed');

/**
 * WhatsApp Message Logs Model
 * 
 * Gerencia logs de mensagens enviadas via WhatsApp
 * com sistema de idempotência e controle de status
 */
class Whatsapp_message_logs_model extends EA_Model
{
    /**
     * @var array
     */
    protected array $casts = [
        'id' => 'integer',
        'appointment_id' => 'integer',
        'template_id' => 'integer',
        'http_status' => 'integer',
    ];

    /**
     * @var array
     */
    protected array $api_resource = [
        'id' => 'id',
        'appointmentId' => 'appointment_id',
        'templateId' => 'template_id',
        'statusKey' => 'status_key',
        'toPhone' => 'to_phone',
        'bodyHash' => 'body_hash',
        'sendType' => 'send_type',
        'provider' => 'provider',
        'requestPayload' => 'request_payload',
        'responsePayload' => 'response_payload',
        'httpStatus' => 'http_status',
        'result' => 'result',
        'errorCode' => 'error_code',
        'errorMessage' => 'error_message',
        'createDatetime' => 'create_datetime',
    ];

    /**
     * Validar dados do log
     */
    protected function validate(array $log): void
    {
        $required_fields = ['status_key', 'to_phone', 'body_hash', 'send_type', 'provider'];
        
        foreach ($required_fields as $field) {
            if (!isset($log[$field]) || empty($log[$field])) {
                throw new InvalidArgumentException("Campo obrigatório '{$field}' não fornecido");
            }
        }
        
        // appointment_id e template_id são opcionais (podem ser null)
        if (!isset($log['appointment_id'])) {
            $log['appointment_id'] = null;
        }
        if (!isset($log['template_id'])) {
            $log['template_id'] = null;
        }
    }

    /**
     * Salvar log de mensagem
     */
    public function save(array $log): int
    {
        $this->validate($log);

        if (empty($log['id'])) {
            return $this->insert($log);
        } else {
            return $this->update($log);
        }
    }

    /**
     * Inserir novo log
     */
    protected function insert(array $log): int
    {
        $log['create_datetime'] = date('Y-m-d H:i:s');

        if (!$this->db->insert('whatsapp_message_logs', $log)) {
            throw new RuntimeException('Could not insert message log.');
        }

        return $this->db->insert_id();
    }

    /**
     * Atualizar log existente
     */
    protected function update(array $log): int
    {
        if (!$this->db->update('whatsapp_message_logs', $log, ['id' => $log['id']])) {
            throw new RuntimeException('Could not update message log.');
        }

        return $log['id'];
    }

    /**
     * Verificar se hash já existe (idempotência)
     */
    public function exists_by_hash(string $hash): bool
    {
        $query = $this->db->get_where('whatsapp_message_logs', ['body_hash' => $hash], 1);
        return $query->num_rows() > 0;
    }

    /**
     * Buscar log por hash
     */
    public function get_by_hash(string $hash): ?array
    {
        $query = $this->db->get_where('whatsapp_message_logs', ['body_hash' => $hash], 1);
        return $query->num_rows() > 0 ? $query->row_array() : null;
    }

    /**
     * Atualizar status do log
     */
    public function update_status(string $hash, string $status, array $data = []): bool
    {
        $update_data = array_merge($data, [
            'result' => $status,
        ]);

        return $this->db->update('whatsapp_message_logs', $update_data, ['body_hash' => $hash]);
    }

    /**
     * Gerar hash único para idempotência
     */
    public function generate_hash(?int $appointment_id, ?int $template_id, string $send_type, string $message): string
    {
        return hash('sha256', ($appointment_id ?? 0) . '|' . ($template_id ?? 0) . '|' . $send_type . '|' . $message);
    }

    /**
     * Create initial log entry and return its id.
     *
     * @param int|null $appointment_id
     * @param int|null $template_id
     * @param string $status_key
     * @param string $to_phone
     * @param string $body_hash
     * @param string $send_type
     * @param array $payload
     * @return int
     */
    public function create_log_entry(?int $appointment_id, ?int $template_id, string $status_key, string $to_phone, string $body_hash, string $send_type, array $payload = []): int
    {
        $data = [
            'appointment_id' => $appointment_id,
            'template_id' => $template_id,
            'status_key' => $status_key,
            'to_phone' => $to_phone,
            'body_hash' => $body_hash,
            'send_type' => $send_type,
            'provider' => 'wppconnect',
            'request_payload' => is_string($payload) ? $payload : json_encode($payload),
            'result' => 'PENDING',
            'create_datetime' => date('Y-m-d H:i:s')
        ];

        if (!$this->db->insert('whatsapp_message_logs', $data)) {
            throw new RuntimeException('Could not insert message log.');
        }

        return (int)$this->db->insert_id();
    }

    /**
     * Update a log entry with result/http status/response details.
     *
     * @param int $log_id
     * @param string $result
     * @param int|null $http_status
     * @param mixed|null $response
     * @param string|null $error_code
     * @param string|null $error_message
     * @return bool
     */
    public function update_log_result(int $log_id, string $result, ?int $http_status = null, $response = null, ?string $error_code = null, ?string $error_message = null): bool
    {
        $update = [
            'result' => $result,
            'update_datetime' => date('Y-m-d H:i:s'),
        ];

        if ($http_status !== null) {
            $update['http_status'] = $http_status;
        }

        if ($response !== null) {
            $update['response_payload'] = is_string($response) ? $response : json_encode($response);
        }

        if ($error_code !== null) {
            $update['error_code'] = $error_code;
        }

        if ($error_message !== null) {
            $update['error_message'] = $error_message;
        }

        return (bool)$this->db->update('whatsapp_message_logs', $update, ['id' => $log_id]);
    }

    /**
     * Check whether a send is a duplicate within a time window.
     *
     * @param int|null $appointment_id
     * @param string $status_key
     * @param int|null $template_id
     * @param string $send_type
     * @param string $body_hash
     * @param int $window_seconds
     * @param bool $time_changed Whether the appointment time has changed (allows re-send)
     * @return bool
     */
    public function is_duplicate_send(?int $appointment_id, string $status_key, ?int $template_id, string $send_type, string $body_hash, int $window_seconds = 300, bool $time_changed = false): bool
    {
        // Routine sends should not be blocked by general duplicate prevention that
        // applies to onCreate/manual sends. The routine is a reminder and must
        // execute regardless of existing booking-time messages.
        if ($send_type === 'routine') {
            return false;
        }

        // If appointment time changed, allow re-send even if content is similar
        if ($time_changed) {
            return false;
        }

        // First, quick check by body_hash (only if time hasn't changed)
        if ($this->exists_by_hash($body_hash)) {
            // If any existing record with same body_hash found, consider duplicate
            return true;
        }

        // Otherwise, check for recent sends for same appointment/template/send_type within window
        $time_limit = date('Y-m-d H:i:s', time() - $window_seconds);

        $this->db->from('whatsapp_message_logs');
        $this->db->where('create_datetime >=', $time_limit);

        if ($appointment_id !== null) {
            $this->db->where('appointment_id', $appointment_id);
        }

        if ($template_id !== null) {
            $this->db->where('template_id', $template_id);
        }

        if (!empty($send_type)) {
            $this->db->where('send_type', $send_type);
        }

        // Match status_key if present
        if (!empty($status_key)) {
            $this->db->where('status_key', $status_key);
        }

        $this->db->limit(1);
        $query = $this->db->get();

        return $query->num_rows() > 0;
    }

    /**
     * Buscar logs por agendamento
     */
    public function get_by_appointment(int $appointment_id): array
    {
        $query = $this->db->order_by('create_datetime', 'DESC')
                          ->get_where('whatsapp_message_logs', ['appointment_id' => $appointment_id]);
        return $query->result_array();
    }

    /**
     * Buscar logs por status
     */
    public function get_by_status(string $status, int $limit = 100): array
    {
        $query = $this->db->order_by('create_datetime', 'DESC')
                          ->limit($limit)
                          ->get_where('whatsapp_message_logs', ['result' => $status]);
        return $query->result_array();
    }

    /**
     * Buscar logs com paginação
     */
    public function get_paginated(int $page = 1, int $limit = 50, array $filters = []): array
    {
        // Aplicar filtros
        if (!empty($filters['date_from'])) {
            $this->db->where('create_datetime >=', $filters['date_from']);
        }
        if (!empty($filters['date_to'])) {
            $this->db->where('create_datetime <=', $filters['date_to']);
        }
        if (!empty($filters['result'])) {
            $this->db->where('result', $filters['result']);
        }
        if (!empty($filters['status_key'])) {
            $this->db->where('status_key', $filters['status_key']);
        }
        if (!empty($filters['appointment_id'])) {
            $this->db->where('appointment_id', $filters['appointment_id']);
        }
        if (!empty($filters['phone'])) {
            $this->db->like('to_phone', $filters['phone']);
        }
        if (!empty($filters['send_type'])) {
            $this->db->where('send_type', $filters['send_type']);
        }

        // Contar total de registros
        $total_query = clone $this->db;
        $total = $total_query->count_all_results('whatsapp_message_logs', false);

        // Aplicar paginação
        $offset = ($page - 1) * $limit;
        $this->db->order_by('create_datetime', 'DESC');
        $this->db->limit($limit, $offset);
        
        $logs = $this->db->get('whatsapp_message_logs')->result_array();

        return [
            'data' => $logs,
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset
        ];
    }

    /**
     * Buscar todos os logs (sem paginação)
     */
    public function get_all(array $filters = []): array
    {
        // Aplicar filtros
        if (!empty($filters['status'])) {
            $this->db->where('result', $filters['status']);
        }
        if (!empty($filters['send_type'])) {
            $this->db->where('send_type', $filters['send_type']);
        }
        if (!empty($filters['date_from'])) {
            $this->db->where('create_datetime >=', $filters['date_from']);
        }
        if (!empty($filters['date_to'])) {
            $this->db->where('create_datetime <=', $filters['date_to']);
        }

        $this->db->order_by('create_datetime', 'DESC');
        return $this->db->get('whatsapp_message_logs')->result_array();
    }

    /**
     * Estatísticas de envio
     */
    public function get_stats(): array
    {
        $query = $this->db->select('result, COUNT(*) as count')
                          ->group_by('result')
                          ->get('whatsapp_message_logs');
        
        $stats = [];
        foreach ($query->result_array() as $row) {
            $stats[$row['result']] = (int) $row['count'];
        }
        
        return $stats;
    }

    /**
     * Deletar logs por status
     */
    public function delete_by_status(string $status): int
    {
        $this->db->where('result', $status);
        $this->db->delete('whatsapp_message_logs');
        return $this->db->affected_rows();
    }

    /**
     * Deletar logs mais antigos que X dias
     */
    public function delete_older_than(int $days): int
    {
        $date_limit = date('Y-m-d H:i:s', strtotime("-{$days} days"));
        $this->db->where('create_datetime <', $date_limit);
        $this->db->delete('whatsapp_message_logs');
        return $this->db->affected_rows();
    }

    /**
     * Deletar todos os logs
     */
    public function delete_all(): int
    {
        $this->db->empty_table('whatsapp_message_logs');
        return $this->db->affected_rows();
    }

    /**
     * Deletar log específico por ID
     */
    public function delete_by_id(int $id): bool
    {
        $this->db->where('id', $id);
        $this->db->delete('whatsapp_message_logs');
        return $this->db->affected_rows() > 0;
    }
}