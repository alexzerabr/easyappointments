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
 * WhatsApp Integration controller.
 *
 * Handles the WhatsApp integration settings and operations.
 *
 * @package Controllers
 */
class Whatsapp_integration extends EA_Controller
{
    /**
     * WhatsApp Integration constructor.
     */
    public function __construct()
    {
        parent::__construct();

        $this->load->model('whatsapp_integration_settings_model');
        $this->load->model('whatsapp_templates_model');
        $this->load->model('whatsapp_message_logs_model');
        $this->load->model('whatsapp_routine_execution_logs_model');
        $this->load->model('roles_model');

        $this->load->library('wppconnect_service');
        $this->load->library('whatsapp_template_service');
        $this->load->library('whatsapp_sender');

        // Load WhatsApp language file
        $this->lang->load('whatsapp');
    }

    /**
     * Sanitize sensitive data for logging.
     *
     * @param array $data Data to sanitize
     * @return array Sanitized data
     */
    private function sanitize_for_logs(array $data): array
    {
        $sensitive_keys = ['token', 'secret_key', 'password', 'key', 'authorization', 'secret'];
        $sanitized = $data;
        
        array_walk_recursive($sanitized, function(&$value, $key) use ($sensitive_keys) {
            $key_lower = strtolower($key);
            foreach ($sensitive_keys as $sensitive) {
                if (strpos($key_lower, $sensitive) !== false) {
                    $value = '[REDACTED]';
                    break;
                }
            }
        });
        
        return $sanitized;
    }

    /**
     * Render the WhatsApp integration page.
     */
    public function index(): void
    {
        session(['dest_url' => site_url('whatsapp_integration')]);

        $user_id = session('user_id');

        if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
            if ($user_id) {
                abort(403, 'Forbidden');
            }

            redirect('login');

            return;
        }

        $role_slug = session('role_slug');

        // Get current settings
        $settings = $this->whatsapp_integration_settings_model->get_current();
        
        // Prepare settings for display (do not decrypt or expose tokens)
        if (!empty($settings)) {
            // Ensure sensitive fields are blanked and encrypted columns removed
            $settings['secret_key'] = '';
            $settings['token'] = '';
            unset($settings['secret_key_enc'], $settings['token_enc'], $settings['token_masked']);
        }

        // Get template statistics
        $template_stats = $this->whatsapp_template_service->get_template_statistics();

        // Get message statistics
        $message_stats = $this->whatsapp_message_logs_model->get_stats();

        // Get recent message logs
        $recent_logs = $this->whatsapp_message_logs_model->get_paginated(1, 10, []);

        // Get WPPConnect service status
        $service_status = [
            'configured' => $this->wppconnect_service->is_configured(),
            'enabled' => $this->wppconnect_service->is_enabled(),
        ];

        // Determine initial session status (for first paint, without extra UI requests)
        $initial_status = 'DISCONNECTED';
        try {
            if (!empty($settings) && !empty($settings['token'])) {
                $resp = $this->wppconnect_service->get_status();
                if (is_array($resp) && !empty($resp['status'])) {
                    $initial_status = strtoupper($resp['status']);
                }
            } else {
                $initial_status = 'NOT_CONFIGURED';
            }
        } catch (Throwable $e) {
            // Keep default DISCONNECTED on any error to avoid surfacing exceptions in view
            $initial_status = 'DISCONNECTED';
        }

        // Prepare settings for script_vars (serialize format)
        $whatsapp_settings_serialized = [];
        if (!empty($settings)) {
            // Add basic configuration fields
            $config_fields = ['host', 'port', 'session'];
            foreach ($config_fields as $field) {
                if (isset($settings[$field])) {
                    $whatsapp_settings_serialized[] = [
                        'name' => $field,
                        'value' => $settings[$field],
                    ];
                }
            }
            
            // Do NOT include token or masked token in script_vars for the frontend
        }

        script_vars([
            'user_id' => $user_id,
            'role_slug' => $role_slug,
            'whatsapp_settings' => $whatsapp_settings_serialized,
            'template_stats' => $template_stats,
            'message_stats' => $message_stats,
            'service_status' => $service_status,
            'initial_session_status' => $initial_status,
            'appointment_status_options' => json_decode(setting('appointment_status_options') ?: '[]', true) ?: [],
            'i18n' => [
                'confirm_reveal_token' => lang('confirm_reveal_token') ?? 'Você tem certeza que deseja revelar o token? Esta ação será registrada.',
                'confirm_rotate_token' => lang('confirm_rotate_token') ?? 'Deseja rotacionar o token? Isto irá invalidar o token atual e gerar um novo.',
                'connectivity_failed' => lang('connection_error') ?? 'Erro de Conexão',
                'secret_key_required' => lang('secret_key_required') ?? 'Chave secreta é necessária para gerar o token',
                'token_generation_failed' => lang('no_token_generated') ?? 'Nenhum token gerado ainda',
                'invalid_host' => lang('invalid_host') ?? 'Host/URL inválido ou inacessível',
                'field_required' => lang('template_name_required') ?? 'Campo obrigatório',
            ],
        ]);

        html_vars([
            'page_title' => lang('whatsapp_integration'),
            'active_menu' => PRIV_SYSTEM_SETTINGS,
            'user_display_name' => $this->accounts->get_user_display_name($user_id),
            'privileges' => $this->roles_model->get_permissions_by_slug($role_slug),
            'whatsapp_settings' => $settings,
            'template_stats' => $template_stats,
            'message_stats' => $message_stats,
            'recent_logs' => $recent_logs,
            'service_status' => $service_status,
        ]);

        $this->load->view('pages/whatsapp_integration');
    }

    /**
     * Get all routines (for AJAX)
     */
    public function get_routines(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            // Return routines with template name joined for better UI display
            $this->load->model('rotinas_whatsapp_model');

            $tb_r = $this->db->dbprefix('rotinas_whatsapp');
            $tb_t = $this->db->dbprefix('whatsapp_templates');

            $rows = $this->db
                ->select("{$tb_r}.*, {$tb_t}.name as template_name")
                ->from($tb_r)
                ->join($tb_t, "{$tb_t}.id = {$tb_r}.template_id", 'left')
                ->where("{$tb_r}.ativa", 1)
                ->order_by("{$tb_r}.id DESC")
                ->get()
                ->result_array();

            foreach ($rows as &$r) $this->rotinas_whatsapp_model->cast($r);

            json_response(['success' => true, 'data' => $rows]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Save routine (create/update)
     */
    public function save_routine(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $payload = request('routine', []);
            // basic validation
            if (empty($payload['name']) || empty($payload['status_agendamento']) || empty($payload['template_id'])) {
                json_response(['success' => false, 'message' => 'Missing required fields'], 400);
                return;
            }

            $data = [
                'name' => $payload['name'],
                'status_agendamento' => $payload['status_agendamento'],
                'template_id' => (int)$payload['template_id'],
                'tempo_antes_horas' => (int)($payload['tempo_antes_horas'] ?? 1),
                'ativa' => !empty($payload['ativa']) ? 1 : 0,
                'update_datetime' => date('Y-m-d H:i:s'),
            ];

            if (!empty($payload['id'])) {
                $data['id'] = (int)$payload['id'];
            } else {
                $data['create_datetime'] = date('Y-m-d H:i:s');
            }

            // insert/update using db directly for simplicity (use table without hardcoded prefix)
            if (!empty($data['id'])) {
                // prevent duplicate name
                $exists = $this->db->where('name', $data['name'])->where('id !=', $data['id'])->get($this->db->dbprefix('rotinas_whatsapp'))->num_rows();
                if ($exists) {
                    json_response(['success' => false, 'message' => 'Routine name already exists'], 400);
                    return;
                }

                $this->db->where('id', $data['id']);
                $this->db->update('rotinas_whatsapp', $data);
                $id = $data['id'];
            } else {
                // prevent duplicate name
                $exists = $this->db->where('name', $data['name'])->get($this->db->dbprefix('rotinas_whatsapp'))->num_rows();
                if ($exists) {
                    json_response(['success' => false, 'message' => 'Routine name already exists'], 400);
                    return;
                }

                $this->db->insert('rotinas_whatsapp', $data);
                $id = $this->db->insert_id();
            }

            json_response(['success' => true, 'message' => 'Routine saved', 'data' => ['id' => $id]]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Delete routine
     */
    public function delete_routine(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $id = (int)request('id');
            if (!$id) {
                json_response(['success' => false, 'message' => 'Invalid id'], 400);
                return;
            }

            $this->db->where('id', $id)->delete('rotinas_whatsapp');
            json_response(['success' => true, 'message' => 'Routine deleted']);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Force-run a routine (AJAX) - triggers sends for due appointments now
     */
    public function force_routine(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $id = (int) request('id');
            if (!$id) {
                json_response(['success' => false, 'message' => 'Invalid id'], 400);
                return;
            }

            $this->load->model('rotinas_whatsapp_model');
            $this->load->library('whatsapp_sender');
            $this->load->library('whatsapp_routine_logger');

            $routine = $this->db->get_where('rotinas_whatsapp', ['id' => $id])->row_array();
            if (!$routine) {
                json_response(['success' => false, 'message' => 'Routine not found'], 404);
                return;
            }

            // For force, fetch upcoming appointments by status (start >= now) that haven't been sent for this routine
            log_message('info', 'Force routine called for id=' . $id . ' name=' . ($routine['name'] ?? '[no-name]'));

            $appointments = $this->rotinas_whatsapp_model->find_upcoming_by_status($routine);
            if (empty($appointments)) {
                log_message('info', 'No upcoming appointments found for routine id=' . $id);
                json_response(['success' => true, 'message' => 'No upcoming appointments to send']);
                return;
            }

            // Start execution logging for forced routine
            $execution_log_id = $this->whatsapp_routine_logger->start_force_execution_log($routine, $appointments);

            $results = [];
            $sent_count = 0;
            $appt_ids = [];
            
            try {
                foreach ($appointments as $appt) {
                    $appt_ids[] = $appt['id'];
                    
                    try {
                        $res = $this->whatsapp_sender->send((int)$appt['id'], (int)$routine['template_id'], 'routine', true);
                        $results[] = $res;
                        
                        if (!empty($res['success'])) {
                            $ok = $this->rotinas_whatsapp_model->mark_sent($routine['id'], $appt['id'], $res['log_id'] ?? null);
                            if ($ok) $sent_count++;
                            
                            // Log successful send
                            $this->whatsapp_routine_logger->log_successful_send($appt, $res);
                        } else {
                            // Log failed send
                            $this->whatsapp_routine_logger->log_failed_send($appt, $res);
                        }
                    } catch (Throwable $e) {
                        // Log exception as failed send
                        $error_result = [
                            'success' => false,
                            'message' => 'Exception during send: ' . $e->getMessage(),
                            '_http_status' => null
                        ];
                        $this->whatsapp_routine_logger->log_failed_send($appt, $error_result);
                        $results[] = $error_result;
                        
                        log_message('error', 'Exception sending forced routine message for appointment ' . $appt['id'] . ': ' . $e->getMessage());
                    }
                }
                
                // Finish execution log with success
                $this->whatsapp_routine_logger->finish_execution_log();
                
            } catch (Throwable $e) {
                // Finish execution log with error
                $this->whatsapp_routine_logger->finish_execution_log('Force routine execution failed: ' . $e->getMessage());
                throw $e; // Re-throw to be caught by outer try-catch
            }

            log_message('info', 'Force routine executed id=' . $id . ' appointments=' . implode(',', $appt_ids) . ' sent=' . $sent_count);

            json_response(['success' => true, 'message' => 'Routine executed', 'appointments' => $appt_ids, 'sent' => $sent_count, 'data' => $results]);
        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Save WhatsApp integration settings.
     */
    public function save(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                throw new RuntimeException('You do not have the required permissions for this task.');
            }

            $whatsapp_settings = request('whatsapp_settings', []);

            // Get current settings to update or create new
            $current = $this->whatsapp_integration_settings_model->get_current();
            
            if (!empty($current)) {
                $settings_data = $current;
            } else {
                $settings_data = [
                    'host' => 'http://localhost',
                    'port' => 21465,
                    'session' => 'default',
                    'enabled' => 0,
                    'wait_qr' => 1,
                ];
            }

            // Update with new values
            foreach ($whatsapp_settings as $setting) {
                if (isset($setting['name']) && isset($setting['value'])) {
                    $settings_data[$setting['name']] = $setting['value'];
                }
            }

            // Auto-enable integration if required fields are filled
            // If host contains scheme or explicit port, port field isn't strictly required
            $hostVal = (string)($settings_data['host'] ?? '');
            $hasScheme = strpos($hostVal, '://') !== false;
            $hasPortInHost = (bool) preg_match('/:\\d+$/', $hostVal);
            $portProvided = !empty($settings_data['port']);

            $requiredOk = !empty($settings_data['host']) && !empty($settings_data['session']) && !empty($settings_data['secret_key']);
            $portOk = ($hasScheme || $hasPortInHost) ? true : $portProvided;
            $all_filled = $requiredOk && $portOk;
            $settings_data['enabled'] = $all_filled ? 1 : 0;

            // Ensure we have the ID for update
            if (!empty($current)) {
                $settings_data['id'] = $current['id'];
            }

            // If all required fields are filled, automatically generate token
            $token_generated = false;
            $token_message = '';
            $token_already_generated = false;
            
            if ($all_filled) {
                try {
                    // Update service config in-memory so subsequent connectivity/token calls target the newly provided host/port/session
                    $this->wppconnect_service->update_config([
                        'host' => $settings_data['host'] ?? $this->wppconnect_service->get_config()['host'],
                        'port' => $settings_data['port'] ?? $this->wppconnect_service->get_config()['port'],
                        'session' => $settings_data['session'] ?? $this->wppconnect_service->get_config()['session'],
                        'secret_key' => $settings_data['secret_key'] ?? $this->wppconnect_service->get_config()['secret_key'],
                    ]);

                    // Pre-save connectivity check: fail fast and do not persist invalid config
                    $connectivity = $this->wppconnect_service->test_connectivity();
                    if (empty($connectivity['success']) || $connectivity['success'] === false) {
                        // 1) Se a própria verificação incluiu geração de token bem-sucedida, prosseguir
                        $gen = $connectivity['details']['token_generation'] ?? [];
                        $statusVal = strtolower((string)($gen['status'] ?? ''));
                        $httpStatus = (int)($gen['_http_status'] ?? 0);
                        $hasToken = !empty($gen['token']);
                        $gen_ok = ($statusVal === 'success' || $httpStatus === 201 || ($hasToken && $httpStatus >= 200 && $httpStatus < 300));

                        if (!$gen_ok) {
                            // 2) Fallback: se falhou por 401 (token inválido) e temos secret_key, tentar gerar novo token agora
                            $msg = strtolower((string)($connectivity['message'] ?? ''));
                            $err = strtolower((string)(($connectivity['details']['error'] ?? '') . ''));
                            $needsNewToken = (strpos($msg, 'authentication failed') !== false) || (strpos($err, '401') !== false);
                            if ($needsNewToken && !empty($settings_data['secret_key'])) {
                                try {
                                    $regen = $this->wppconnect_service->generate_token($settings_data['secret_key']);
                                    $statusVal2 = strtolower((string)($regen['status'] ?? ''));
                                    $httpStatus2 = (int)($regen['_http_status'] ?? 0);
                                    $hasToken2 = !empty($regen['token']);
                                    $regen_ok = ($statusVal2 === 'success' || $httpStatus2 === 201 || ($hasToken2 && $httpStatus2 >= 200 && $httpStatus2 < 300));
                                    if ($regen_ok) {
                                        $settings_data['token'] = $regen['token'];
                                        $token_generated = true;
                                        $token_already_generated = true;
                                        $token_message = 'Token gerado automaticamente com sucesso';
                                        $this->wppconnect_service->update_config(['token' => $regen['token']]);
                                    } else {
                                        json_response([
                                            'success' => false,
                                            'message' => 'Connectivity check failed: ' . ($connectivity['message'] ?? 'Unknown error'),
                                            'details' => $connectivity['details'] ?? []
                                        ], 400);
                                        return;
                                    }
                                } catch (Throwable $e) {
                                    json_response([
                                        'success' => false,
                                        'message' => 'Connectivity check failed: ' . $e->getMessage(),
                                        'details' => $connectivity['details'] ?? []
                                    ], 400);
                                    return;
                                }
                            } else {
                                // 3) Sem fallback possível -> abortar com detalhes
                                json_response([
                                    'success' => false,
                                    'message' => 'Connectivity check failed: ' . ($connectivity['message'] ?? 'Unknown error'),
                                    'details' => $connectivity['details'] ?? []
                                ], 400);
                                return;
                            }
                        }
                    }

                    // Generate token automatically (skip if já gerado no fallback anterior)
                    if (!$token_already_generated) {
                        $token_response = $this->wppconnect_service->generate_token($settings_data['secret_key']);
                        
                        $statusVal = strtolower((string)($token_response['status'] ?? ''));
                        $httpStatus = (int)($token_response['_http_status'] ?? 0);
                        $hasToken = !empty($token_response['token']);

                        if ($statusVal === 'success' || $httpStatus === 201 || ($hasToken && $httpStatus >= 200 && $httpStatus < 300)) {
                            $settings_data['token'] = $token_response['token'];
                            $token_generated = true;
                            $token_message = 'Token gerado automaticamente com sucesso';
                            
                            log_message('info', 'Auto-generated WPPConnect token for session: ' . $settings_data['session']);
                        } else {
                            $token_message = 'Configurações salvas, mas falha na geração automática do token: ' . ($token_response['message'] ?? 'Erro desconhecido');
                            $safe_token_response = $this->sanitize_for_logs($token_response);
                            log_message('warning', 'Auto token generation failed: ' . json_encode($safe_token_response));
                        }
                    }
                } catch (Exception $e) {
                    $token_message = 'Configurações salvas, mas erro na geração automática do token: ' . $e->getMessage();
                    log_message('error', 'Auto token generation error: ' . $e->getMessage());
                }
            }

            // Encrypt sensitive data before saving
            $this->whatsapp_integration_settings_model->encrypt_sensitive_data($settings_data);

            $settings_id = $this->whatsapp_integration_settings_model->save($settings_data);

            // Return response with token generation info and the saved non-sensitive settings so the UI
            // can update immediately without requiring a full page refresh. Do NOT expose token or masked token.
            $saved_settings = [
                'host' => $settings_data['host'] ?? null,
                'port' => $settings_data['port'] ?? null,
                'session' => $settings_data['session'] ?? null,
                'enabled' => isset($settings_data['enabled']) ? (int)$settings_data['enabled'] : 0,
            ];

            json_response([
                'success' => true,
                'message' => $token_generated ? $token_message : 'Configurações salvas com sucesso',
                'token_generated' => $token_generated,
                'token_message' => $token_message,
                'settings_id' => $settings_id,
                'saved_settings' => $saved_settings,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Update WPPConnect token manually.
     */
    public function update_token(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $token = request('token');
            if (empty($token)) {
                json_response([
                    'success' => false,
                    'message' => 'Token is required',
                ], 400);
                return;
            }

            // Get current settings
            $current = $this->whatsapp_integration_settings_model->get();
            
            if (!empty($current)) {
                // Update only the token
                $update_data = $current;
                $update_data['token'] = $token;
                
                $this->whatsapp_integration_settings_model->encrypt_sensitive_data($update_data);
                $this->whatsapp_integration_settings_model->save($update_data);

                // Update service config
                $this->wppconnect_service->update_config(['token' => $token]);

                json_response([
                    'success' => true,
                    'message' => 'Token updated successfully',
                    'data' => [
                        'token_masked' => $this->whatsapp_integration_settings_model->get_masked_token($update_data),
                    ],
                ]);
            } else {
                json_response([
                    'success' => false,
                    'message' => 'No settings found to update',
                ], 404);
            }

        } catch (Throwable $e) {
            json_response([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Generate WPPConnect authentication token.
     */
    public function generate_token(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $secret_key = request('secret_key');

            if (empty($secret_key)) {
                json_response([
                    'success' => false,
                    'message' => 'Secret key is required',
                ], 400);
                return;
            }

            // Log current configuration for debugging
            $current_config = $this->wppconnect_service->get_config();
            log_message('info', 'Current WPPConnect config: ' . json_encode([
                'host' => $current_config['host'],
                'port' => $current_config['port'],
                'session' => $current_config['session'],
                'has_token' => $current_config['has_token'],
            ]));

            $response = $this->wppconnect_service->generate_token($secret_key);
            
            // Log the response for debugging
            $safe_response = $this->sanitize_for_logs($response);
            log_message('info', 'WPPConnect generate_token response: ' . json_encode($safe_response));

            if (!empty($response['status']) && ($response['status'] === 'success' || $response['status'] === 'Success')) {
                // Save token to settings
                $current = $this->whatsapp_integration_settings_model->get_current();
                if (!empty($current)) {
                    // Prepare update data with only the fields we want to update
                    $update_data = $current; // Start with current data
                    $update_data['token'] = $response['token'];
                    $update_data['secret_key'] = $secret_key;
                    
                    $this->whatsapp_integration_settings_model->encrypt_sensitive_data($update_data);
                    
                    // Update only the encrypted fields in the database
                    $this->db->where('id', $current['id']);
                    $this->db->update('whatsapp_integration_settings', [
                        'token_enc' => $update_data['token_enc'] ?? null,
                        'secret_key_enc' => $update_data['secret_key_enc'] ?? null,
                        'update_datetime' => date('Y-m-d H:i:s'),
                    ]);

                    // Update service config
                    $this->wppconnect_service->update_config(['token' => $response['token']]);
                }

                // Do not expose token or masked token to the client. Return only status/session.
                json_response([
                    'success' => true,
                    'message' => lang('whatsapp_token_generated'),
                    'data' => [
                        'session' => $response['session'] ?? '',
                        'status' => $response['status'],
                    ],
                ]);
            } else {
                json_response([
                    'success' => false,
                    'message' => $response['message'] ?? 'Failed to generate token',
                    'data' => $response,
                    'debug' => [
                        'response_status' => $response['status'] ?? 'no_status',
                        'full_response' => $response,
                    ],
                ], 400);
            }

        } catch (Throwable $e) {
            log_message('error', 'WPPConnect generate_token error: ' . $e->getMessage());
            json_response([
                'success' => false,
                'message' => $e->getMessage(),
                'debug' => [
                    'file' => $e->getFile(),
                    'line' => $e->getLine(),
                ],
            ], 500);
        }
    }

    /**
     * Start WPPConnect session.
     */
    public function start_session(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            // Always wait for QR code since we have a dedicated "Show QR" button
            $response = $this->wppconnect_service->start_session(true);

            json_response([
                'success' => true,
                'message' => lang('whatsapp_session_started'),
                'data' => $response,
            ]);

        } catch (Throwable $e) {
            json_response([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get WPPConnect session status.
     */
    public function get_status(): void
    {
        try {
            // Require permission to view system settings for status check
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            // If not configured or token missing yet, respond gracefully without hitting service
            $settings = $this->whatsapp_integration_settings_model->get_current();
            if (empty($settings) || empty($settings['token'])) {
                json_response([
                    'success' => true,
                    'message' => 'WhatsApp integration not configured yet',
                    'data' => [
                        'status' => 'NOT_CONFIGURED',
                    ],
                ]);
                return;
            }

            $response = $this->wppconnect_service->get_status();

            // Ensure we have a valid response structure
            if (is_array($response) && isset($response['status'])) {
                json_response([
                    'success' => true,
                    'message' => lang('whatsapp_status_retrieved'),
                    'data' => $response,
                ]);
            } else {
                // If no valid status, return disconnected
                json_response([
                    'success' => true,
                    'message' => lang('whatsapp_status_retrieved'),
                    'data' => [
                        'status' => 'DISCONNECTED',
                        'message' => 'No active session found'
                    ],
                ]);
            }

        } catch (Throwable $e) {
            json_response([
                'success' => true,
                'message' => 'WhatsApp status unavailable',
                'data' => ['status' => 'DISCONNECTED'],
            ]);
        }
    }

    /**
     * Close WPPConnect session.
     */
    public function close_session(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $response = $this->wppconnect_service->close_session();

            json_response([
                'success' => true,
                'message' => lang('whatsapp_session_closed'),
                'data' => $response,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Logout from WPPConnect session.
     */
    public function logout_session(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $response = $this->wppconnect_service->logout_session();

            json_response([
                'success' => true,
                'message' => lang('whatsapp_session_logout'),
                'data' => $response,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Perform comprehensive health check.
     */
    public function health_check(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $health = $this->wppconnect_service->health_check();

            json_response([
                'success' => true,
                'data' => $health
            ]);

        } catch (Throwable $e) {
            json_response([
                'success' => false,
                'message' => 'Health check failed: ' . $e->getMessage(),
                'data' => [
                    'status' => 'error',
                    'checks' => [],
                    'error' => $e->getMessage(),
                    'timestamp' => date('Y-m-d H:i:s')
                ]
            ], 500);
        }
    }

    /**
     * Test connectivity to WPPConnect server.
     */
    public function test_connectivity(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            // Simple reachability only (no token generation, no status-session calls)
            $result = $this->wppconnect_service->ping_host();

            json_response([
                'success' => $result['success'],
                'message' => $result['message'],
                'details' => $result['details'] ?? [],
            ]);

        } catch (Throwable $e) {
            json_response([
                'success' => false,
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get message logs with pagination and filters.
     */
    public function get_message_logs(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $filters = [
                'date_from' => request('date_from'),
                'date_to' => request('date_to'),
                'result' => request('result'),
                'status_key' => request('status_key'),
                'appointment_id' => request('appointment_id'),
                'phone' => request('phone'),
                'send_type' => request('send_type'),
            ];

            // Remove empty filters
            $filters = array_filter($filters, function($value) {
                return $value !== null && $value !== '';
            });

            $limit = min((int)request('limit', 50), 100);
            $pageParam = (int)request('page', 0);
            $offsetParam = request('offset', null);
            $page = $pageParam > 0 ? $pageParam : 1;
            if ($pageParam === 0 && $offsetParam !== null) {
                $offset = (int)$offsetParam;
                $page = max(1, (int)floor($offset / $limit) + 1);
            }

            $result = $this->whatsapp_message_logs_model->get_paginated($page, $limit, $filters);

            json_response([
                'success' => true,
                'data' => $result,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Send manual WhatsApp message.
     */
    public function send_message(): void
    {
        try {
            if (cannot('edit', PRIV_APPOINTMENTS)) {
                abort(403, 'Forbidden');
            }

            $appointment_id = (int)request('appointment_id');
            $template_id = request('template_id') ? (int)request('template_id') : null;
            $custom_message = request('custom_message');

            if (!$appointment_id) {
                json_response([
                    'success' => false,
                    'message' => 'Appointment ID is required',
                ], 400);
                return;
            }

            if ($custom_message) {
                $result = $this->whatsapp_sender->send_custom_message($appointment_id, $custom_message);
            } else {
                $result = $this->whatsapp_sender->send_manual($appointment_id, $template_id);
            }

            if ($result['success']) {
                json_response([
                    'success' => true,
                    'message' => $result['message'],
                    'log_id' => $result['log_id'],
                ]);
            } else {
                json_response([
                    'success' => false,
                    'message' => $result['message'],
                    'details' => $result['details'],
                ], 400);
            }

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Check if message can be sent for appointment.
     */
    public function can_send_message(): void
    {
        try {
            if (cannot('view', PRIV_APPOINTMENTS)) {
                abort(403, 'Forbidden');
            }

            $appointment_id = (int)request('appointment_id');
            $send_type = request('send_type', 'manual');

            if (!$appointment_id) {
                json_response([
                    'success' => false,
                    'message' => 'Appointment ID is required',
                ], 400);
                return;
            }

            $result = $this->whatsapp_sender->can_send($appointment_id, $send_type);

            json_response($result);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get sending statistics.
     */
    public function get_statistics(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            // Optional date filters (not applied to template counts)
            $filters = [
                'date_from' => request('date_from'),
                'date_to' => request('date_to'),
            ];

            // Prepare template statistics (enabled count)
            $template_stats = $this->whatsapp_template_service->get_template_statistics();

            // Prepare message statistics using the logs model (returns counts by result)
            $this->load->model('whatsapp_message_logs_model');
            $message_stats = $this->whatsapp_message_logs_model->get_stats();

            // Return unified shape expected by the frontend
            json_response([
                'success' => true,
                'data' => [
                    'templates' => $template_stats['enabled'] ?? 0,
                    'messages' => $message_stats,
                ],
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Send test message manually.
     */
    public function send_test_message(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $phone = request('phone');
            $message = request('message');
            $template_id = null; // no longer supported on test UI

            // Require phone and message only (template removed from UI)
            if (empty($phone) || empty($message)) {
                json_response([
                    'success' => false,
                    'message' => 'Informe o telefone e a mensagem'
                ]);
                return;
            }

            // Usar serviço unificado
            $this->load->library('wppconnect_service');
            $this->load->model('whatsapp_message_logs_model');

            // Verificar se está conectado
            if (!$this->wppconnect_service->is_connected()) {
                json_response([
                    'success' => false,
                    'message' => 'Sessão WhatsApp não está conectada. Inicie a sessão primeiro.'
                ]);
                return;
            }

            // Template selection removed: always use provided message

            // Gerar hash para idempotência
            $hash = $this->whatsapp_message_logs_model->generate_hash(
                null, // appointment_id = null para teste
                $template_id ?: null,
                'test',
                $message
            );

            // Criar log inicial
            $log_data = [
                'body_hash' => $hash,
                'appointment_id' => null, // null para teste
                'template_id' => $template_id ?: null,
                'status_key' => 'test',
                'to_phone' => $this->mask_phone($phone),
                'send_type' => 'manual', // usar 'manual' em vez de 'test'
                'provider' => 'wppconnect',
                'result' => 'PENDING',
                'request_payload' => json_encode(['phone' => $phone, 'message' => $message])
            ];

            $this->whatsapp_message_logs_model->save($log_data);

            // Enviar mensagem
            $response = $this->wppconnect_service->send_message(
                $phone,
                $message,
                $hash,
                null,
                null,
                'test'
            );

            json_response([
                'success' => true,
                'message' => 'Mensagem de teste enviada com sucesso',
                'response' => $response
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }


    /**
     * Get message statistics.
     */
    public function get_message_stats(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $this->load->model('whatsapp_message_logs_model');

            $stats = $this->whatsapp_message_logs_model->get_stats();

            json_response([
                'success' => true,
                'data' => $stats
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    // Duplicate get_statistics removed: keep sending statistics implementation above

    /**
     * Get current token (for editing purposes).
     */
    public function get_token(): void
    {
        // Endpoint intentionally disabled for security. Use reveal_token (audited and rate-limited).
        json_response(['success' => false, 'message' => 'Token retrieval is only allowed via reveal_token endpoint'], 405);
    }

    /**
     * Reveal token (guarded, audited and rate-limited)
     */
    public function reveal_token(): void
    {
        try {
            if ($this->input->method() !== 'post') {
                json_response(['success' => false, 'message' => 'Method not allowed'], 405);
                return;
            }

            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $user_id = session('user_id');
            $role_slug = session('role_slug');
            $ip = $this->input->ip_address();

            // Rate limit: prefer Redis-based counter; fallback to DB counter
            $limitExceeded = false;
            try {
                if (extension_loaded('redis')) {
                    $redisHost = getenv('REDIS_HOST') ?: '127.0.0.1';
                    $redisPort = (int)(getenv('REDIS_PORT') ?: 6379);
                    $redis = new Redis();
                    $redis->connect($redisHost, $redisPort);

                    $key = "wa:reveal:{$user_id}";
                    $count = $redis->incr($key);
                    if ($count === 1) {
                        $redis->expire($key, 3600); // 1 hour window
                    }

                    if ($count > 3) {
                        $limitExceeded = true;
                    }
                } else {
                    // Redis extension not available: fallback to DB count
                    $one_hour_ago = date('Y-m-d H:i:s', strtotime('-1 hour'));
            $count = $this->db->where('user_id', $user_id)
                                      ->where('action', 'reveal')
                                      ->where('created_at >=', $one_hour_ago)
                                      ->count_all_results('whatsapp_token_reveal_logs');
                    if ($count >= 3) {
                        $limitExceeded = true;
                    }
                }
            } catch (Throwable $e) {
                // On any error with rate-limiter, fail-open but log the issue
                log_message('error', 'Rate limiter error: ' . $e->getMessage());
                $limitExceeded = false;
            }

            if ($limitExceeded) {
                // Log attempt
                $this->log_token_action($user_id, $role_slug, 'reveal', 'rate_limited');
                json_response(['success' => false, 'message' => 'Rate limit exceeded'], 429);
                return;
            }

            $settings = $this->whatsapp_integration_settings_model->get_current();
            if (empty($settings) || empty($settings['token'])) {
                $this->log_token_action($user_id, $role_slug, 'reveal', 'not_found');
                json_response(['success' => false, 'message' => 'Token not configured'], 404);
                return;
            }

            // Audit success (do NOT log token value)
            $this->log_token_action($user_id, $role_slug, 'reveal', 'success');

            json_response(['success' => true, 'data' => ['token' => $settings['token']]]);

        } catch (Throwable $e) {
            log_message('error', 'WA token reveal error: ' . $e->getMessage());
            json_exception($e);
        }
    }

    /**
     * Rotate token (generate new and revoke old)
     *
     * NOTE: web/API rotation is disabled. Rotation must be performed from the console (CLI).
     */
    public function rotate_token(): void
    {
        try {
            // Disallow rotation via web/API
            if (!is_cli()) {
                json_response(['success' => false, 'message' => 'Token rotation is only allowed via console (CLI)'], 405);
                return;
            }

            // CLI rotation flow
            $settings = $this->whatsapp_integration_settings_model->get_current();
            if (empty($settings)) {
                response('No WhatsApp integration settings found.' . PHP_EOL);
                return;
            }

            $new = $this->wppconnect_service->generate_token($settings['secret_key'] ?? '');
            if (empty($new['token'])) {
                response('Failed to rotate token: no token returned by WPPConnect' . PHP_EOL);
                return;
            }

            $ok = $this->whatsapp_integration_settings_model->update_token($new['token']);
            if ($ok) {
                $this->wppconnect_service->update_config(['token' => $new['token']]);
                $this->log_token_action(session('user_id') ?? null, session('role_slug') ?? 'cli', 'rotate', 'success');
                response('Token rotated successfully.' . PHP_EOL);
            } else {
                $this->log_token_action(session('user_id') ?? null, session('role_slug') ?? 'cli', 'rotate', 'failed');
                response('Failed to update token in database.' . PHP_EOL);
            }

        } catch (Throwable $e) {
            log_message('error', 'WA token rotate error: ' . $e->getMessage());
            if (is_cli()) {
                response('Exception during rotation: ' . $e->getMessage() . PHP_EOL);
            } else {
                json_exception($e);
            }
        }
    }

    /**
     * Log token copy action (audit)
     */
    public function log_token_copy(): void
    {
        try {
            if ($this->input->method() !== 'post') {
                json_response(['success' => false, 'message' => 'Method not allowed'], 405);
                return;
            }

            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $user_id = session('user_id');
            $role_slug = session('role_slug');
            $this->log_token_action($user_id, $role_slug, 'copy', 'success');
            json_response(['success' => true]);

        } catch (Throwable $e) {
            log_message('error', 'WA log_token_copy error: ' . $e->getMessage());
            json_exception($e);
        }
    }

    /**
     * Insert audit record for token actions
     */
    private function log_token_action($user_id, $role_slug, string $action, string $status): void
    {
        try {
            $this->db->insert('whatsapp_token_reveal_logs', [
                'user_id' => $user_id,
                'role_slug' => $role_slug,
                'action' => $action,
                'status' => $status,
                'ip' => $this->input->ip_address(),
                'user_agent' => $this->input->user_agent(),
                'created_at' => date('Y-m-d H:i:s')
            ]);
        } catch (Exception $e) {
            log_message('error', 'Failed to insert token reveal audit: ' . $e->getMessage());
        }
    }

    /**
     * Get message logs with filters.
     */
    public function get_logs(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $this->load->model('whatsapp_message_logs_model');

            // Parâmetros de filtro
            $status = request('status', '');
            $page = (int) request('page', 1);
            $limit = (int) request('limit', 20);
            $search = request('search', '');

            // Construir filtros
            $filters = [];
            if (!empty($status)) {
                $filters['result'] = $status;
            }
            if (!empty($search)) {
                $filters['search'] = $search;
            }

            // Buscar logs paginados
            $logs = $this->whatsapp_message_logs_model->get_paginated($page, $limit, $filters);

            // Buscar estatísticas para os filtros
            $stats = $this->whatsapp_message_logs_model->get_stats();

            json_response([
                'success' => true,
                'data' => $logs,
                'stats' => $stats,
                'pagination' => [
                    'page' => $page,
                    'limit' => $limit,
                    'total' => $logs['total'] ?? 0,
                    'pages' => ceil(($logs['total'] ?? 0) / $limit)
                ]
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Clear message logs.
     */
    public function clear_logs(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $this->load->model('whatsapp_message_logs_model');

            // Parâmetros de filtro para limpeza
            $status = request('status', '');
            $older_than_days = (int) request('older_than_days', 0);

            $deleted_count = 0;

            if (!empty($status)) {
                // Limpar por status específico
                $deleted_count = $this->whatsapp_message_logs_model->delete_by_status($status);
            } elseif ($older_than_days > 0) {
                // Limpar logs mais antigos que X dias
                $deleted_count = $this->whatsapp_message_logs_model->delete_older_than($older_than_days);
            } else {
                // Limpar todos os logs
                $deleted_count = $this->whatsapp_message_logs_model->delete_all();
            }

            json_response([
                'success' => true,
                'message' => "Logs removidos com sucesso. {$deleted_count} registros deletados.",
                'deleted_count' => $deleted_count
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Mask phone number for display.
     */
    private function mask_phone(string $phone): string
    {
        if (strlen($phone) < 8) {
            return $phone;
        }
        
        $prefix = substr($phone, 0, 3);
        $suffix = substr($phone, -4);
        $masked = str_repeat('*', strlen($phone) - 7);
        
        return $prefix . $masked . $suffix;
    }

    /**
     * Mask token for display.
     *
     * @param string $token Token to mask.
     *
     * @return string Masked token.
     */
    private function mask_token(string $token): string
    {
        if (strlen($token) <= 8) {
            return str_repeat('*', strlen($token));
        }

        return substr($token, 0, 4) . str_repeat('*', strlen($token) - 8) . substr($token, -4);
    }

    /**
     * Get routine execution logs (AJAX).
     */
    public function get_execution_logs(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $page = (int)request('page', 1);
            $limit = (int)request('limit', 20);
            $routine_id = request('routine_id') ? (int)request('routine_id') : null;
            $status = request('status');
            $date_from = request('date_from');
            $date_to = request('date_to');

            // Build filters
            $filters = [];
            if ($routine_id) {
                $filters['routine_id'] = $routine_id;
            }
            if ($status) {
                $filters['execution_status'] = $status;
            }
            if ($date_from) {
                $filters['date_from'] = $date_from . ' 00:00:00';
            }
            if ($date_to) {
                $filters['date_to'] = $date_to . ' 23:59:59';
            }

            $offset = ($page - 1) * $limit;
            $logs = $this->whatsapp_routine_execution_logs_model->get_execution_logs($filters, $limit, $offset);

            // Get total count for pagination
            $total_logs = $this->whatsapp_routine_execution_logs_model->get_execution_logs($filters);
            $total_count = count($total_logs);

            json_response([
                'success' => true,
                'data' => $logs,
                'total' => $total_count,
                'page' => $page,
                'limit' => $limit,
                'total_pages' => ceil($total_count / $limit)
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get execution log details (AJAX).
     */
    public function get_execution_log_details(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $log_id = (int)request('id');
            if (!$log_id) {
                json_response(['success' => false, 'message' => 'Log ID is required'], 400);
                return;
            }

            $logs = $this->whatsapp_routine_execution_logs_model->get_execution_logs(['id' => $log_id]);
            if (empty($logs)) {
                json_response(['success' => false, 'message' => 'Log not found'], 404);
                return;
            }

            json_response([
                'success' => true,
                'data' => $logs[0]
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get routine execution statistics (AJAX).
     */
    public function get_execution_stats(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $routine_id = request('routine_id') ? (int)request('routine_id') : null;
            $date_from = request('date_from');
            $date_to = request('date_to');

            if ($routine_id) {
                $stats = $this->whatsapp_routine_execution_logs_model->get_routine_stats($routine_id, $date_from, $date_to);
            } else {
                $stats = $this->whatsapp_routine_execution_logs_model->get_overall_stats($date_from, $date_to);
            }

            json_response([
                'success' => true,
                'data' => $stats
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Clean up old execution logs (AJAX).
     */
    public function cleanup_execution_logs(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $days_to_keep = (int)request('days_to_keep', 90);
            if ($days_to_keep < 1) {
                json_response(['success' => false, 'message' => 'Days to keep must be at least 1'], 400);
                return;
            }

            $deleted_count = $this->whatsapp_routine_execution_logs_model->cleanup_old_logs($days_to_keep);

            json_response([
                'success' => true,
                'message' => "Removed {$deleted_count} old execution logs",
                'deleted_count' => $deleted_count
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

}
