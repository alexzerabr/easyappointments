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
 * WhatsApp Templates controller.
 *
 * Handles the WhatsApp templates management.
 *
 * @package Controllers
 */
class Whatsapp_templates extends EA_Controller
{
    /**
     * WhatsApp Templates constructor.
     */
    public function __construct()
    {
        parent::__construct();

        $this->load->model('whatsapp_templates_model');
        $this->load->model('roles_model');

        $this->load->library('whatsapp_template_service');

        // Load WhatsApp language file
        $this->lang->load('whatsapp');
    }

    /**
     * Render the WhatsApp templates page.
     */
    public function index(): void
    {
        session(['dest_url' => site_url('whatsapp_templates')]);

        $user_id = session('user_id');

        if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
            if ($user_id) {
                abort(403, 'Forbidden');
            }

            redirect('login');

            return;
        }

        $role_slug = session('role_slug');

        // Get available statuses
        $available_statuses = $this->whatsapp_template_service->get_available_statuses();

        // Get templates grouped by status
        $templates_by_status = $this->whatsapp_template_service->get_templates_grouped_by_status();

        // Get available placeholders
        $available_placeholders = $this->whatsapp_template_service->get_available_placeholders();

        // Get template statistics
        $template_stats = $this->whatsapp_template_service->get_template_statistics();

        html_vars([
            'page_title' => lang('whatsapp_templates'),
            'active_menu' => PRIV_SYSTEM_SETTINGS,
            'user_display_name' => $this->accounts->get_user_display_name($user_id),
            'privileges' => $this->roles_model->get_permissions_by_slug($role_slug),
            'available_statuses' => $available_statuses,
            'templates_by_status' => $templates_by_status,
            'available_placeholders' => $available_placeholders,
            'template_stats' => $template_stats,
        ]);

        $this->load->view('pages/whatsapp_templates');
    }

    /**
     * Get all templates.
     */
    public function get_templates(): void
    {
        try {
            // Temporarily remove permission check for template listing
            // if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
            //     abort(403, 'Forbidden');
            // }

            $status_key = request('status_key');
            $enabled_only = request('enabled_only', false);
            $language = request('language');

            if ($status_key) {
                $templates = $this->whatsapp_template_service->get_by_status($status_key, $enabled_only, $language);
            } else {
                $where = [];
                if ($enabled_only) {
                    $where['enabled'] = 1;
                }
                if ($language) {
                    $where['language'] = $language;
                }
                $templates = $this->whatsapp_templates_model->get($where, null, null, 'status_key ASC, name ASC');
            }

            json_response([
                'success' => true,
                'data' => $templates,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get a specific template.
     */
    public function get_template(int $template_id): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $template = $this->whatsapp_templates_model->find($template_id);

            json_response([
                'success' => true,
                'data' => $template,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Save (create or update) a template.
     */
    public function save_template(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $template = request();

            // Validate template data
            $validation_errors = $this->whatsapp_template_service->validate_template($template);
            
            if (!empty($validation_errors)) {
                json_response([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validation_errors,
                ], 400);
                return;
            }

            // Validate template variables
            if (!empty($template['body'])) {
                $this->load->library('template_variable_service');
                $variable_validation = $this->template_variable_service->validate_variables($template['body']);
                
                if (!$variable_validation['valid']) {
                    $invalid_vars = implode(', ', array_map(function($var) {
                        return '{{' . $var . '}}';
                    }, $variable_validation['invalid_variables']));
                    
                    json_response([
                        'success' => false,
                        'message' => 'Variável desconhecida: ' . $invalid_vars . '. Use apenas variáveis disponíveis.',
                        'errors' => ['variables' => $variable_validation['invalid_variables']]
                    ], 400);
                    return;
                }
            }

            $template_id = $this->whatsapp_templates_model->save($template);

            $saved_template = $this->whatsapp_templates_model->find($template_id);

            json_response([
                'success' => true,
                'message' => empty($template['id']) ? lang('whatsapp_template_created') : lang('whatsapp_template_updated'),
                'data' => $saved_template,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Delete a template.
     */
    public function delete_template(int $template_id): void
    {
        try {
            if (cannot('delete', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $this->whatsapp_templates_model->delete($template_id);

            json_response([
                'success' => true,
                'message' => lang('whatsapp_template_deleted'),
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }


    /**
     * Get available statuses.
     */
    public function get_statuses(): void
    {
        try {
            // Temporarily remove permission check for status listing
            // This endpoint only returns public appointment status options
            // if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
            //     abort(403, 'Forbidden');
            // }

            // Get appointment status options from system settings
            $this->load->model('settings_model');
            $status_setting = $this->settings_model->get(['name' => 'appointment_status_options']);
            
            $statuses = [];
            if (!empty($status_setting[0]['value'])) {
                $status_options = json_decode($status_setting[0]['value'], true);
                if (is_array($status_options)) {
                    foreach ($status_options as $status) {
                        $statuses[] = [
                            'key' => $status,
                            'label' => $status
                        ];
                    }
                }
            }

            // Fallback to default statuses if none found
            if (empty($statuses)) {
                $statuses = [
                    ['key' => 'Booked', 'label' => 'Booked'],
                    ['key' => 'Confirmed', 'label' => 'Confirmed'],
                    ['key' => 'Rescheduled', 'label' => 'Rescheduled'],
                    ['key' => 'Cancelled', 'label' => 'Cancelled'],
                    ['key' => 'Draft', 'label' => 'Draft']
                ];
            }

            json_response([
                'success' => true,
                'data' => $statuses,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get available variables (new method).
     */
    public function get_variables(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $this->load->library('template_variable_service');
            $variables = $this->template_variable_service->get_catalog();

            json_response([
                'success' => true,
                'data' => $variables,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Get available placeholders (legacy method for compatibility).
     */
    public function get_placeholders(): void
    {
        // Redirect to new method for compatibility
        $this->get_variables();
    }

    /**
     * Get template preview.
     */
    public function get_preview(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $body = $this->input->post('body');
            $locale = $this->input->post('locale') ?: 'pt-BR';

            if (empty($body)) {
                json_response([
                    'success' => false,
                    'message' => 'Template body is required'
                ]);
                return;
            }

            $this->load->library('template_variable_service');
            $context = $this->template_variable_service->create_preview_context($locale);
            $preview = $this->template_variable_service->render_template($body, $context);

            json_response([
                'success' => true,
                'data' => [
                    'preview' => $preview,
                    'context' => $context
                ]
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Validate template variables.
     */
    public function validate_variables(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $body = $this->input->post('body');

            if (empty($body)) {
                json_response([
                    'success' => false,
                    'message' => 'Template body is required'
                ]);
                return;
            }

            $this->load->library('template_variable_service');
            $validation = $this->template_variable_service->validate_variables($body);

            json_response([
                'success' => true,
                'data' => $validation
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Create default templates for a status.
     */
    // create_default_templates endpoint removed: templates are now user-managed only

    /**
     * Toggle template enabled status.
     */
    public function toggle_template(int $template_id): void
    {
        try {
            // Temporarily remove permission check for template toggle
            // if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
            //     abort(403, 'Forbidden');
            // }

            $template = $this->whatsapp_templates_model->find($template_id);
            $template['enabled'] = !$template['enabled'];
            
            $this->whatsapp_templates_model->save($template);

            $status = $template['enabled'] ? 'enabled' : 'disabled';

            json_response([
                'success' => true,
                'message' => sprintf(lang('whatsapp_template_toggled'), $status),
                'data' => [
                    'enabled' => $template['enabled'],
                ],
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Duplicate a template.
     */
    public function duplicate_template(int $template_id): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $template = $this->whatsapp_templates_model->find($template_id);
            
            // Remove ID to create a new record
            unset($template['id']);
            
            // Modify name to indicate it's a copy
            $template['name'] = $template['name'] . ' (Copy)';
            
            // Set as disabled by default
            $template['enabled'] = 0;

            $new_template_id = $this->whatsapp_templates_model->save($template);
            $new_template = $this->whatsapp_templates_model->find($new_template_id);

            json_response([
                'success' => true,
                'message' => lang('whatsapp_template_duplicated'),
                'data' => $new_template,
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Bulk update templates.
     */
    public function bulk_update(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $action = request('action');
            $template_ids = request('template_ids', []);

            if (empty($action) || empty($template_ids)) {
                json_response([
                    'success' => false,
                    'message' => 'Action and template IDs are required',
                ], 400);
                return;
            }

            $updated_count = 0;

            foreach ($template_ids as $template_id) {
                try {
                    $template = $this->whatsapp_templates_model->find($template_id);
                    
                    switch ($action) {
                        case 'enable':
                            $template['enabled'] = 1;
                            break;
                        case 'disable':
                            $template['enabled'] = 0;
                            break;
                        case 'delete':
                            $this->whatsapp_templates_model->delete($template_id);
                            $updated_count++;
                            continue 2; // Skip the save operation
                        default:
                            continue 2; // Skip unknown actions
                    }
                    
                    $this->whatsapp_templates_model->save($template);
                    $updated_count++;
                    
                } catch (Exception $e) {
                    // Log error but continue with other templates
                    log_message('error', 'Failed to update template ' . $template_id . ': ' . $e->getMessage());
                }
            }

            json_response([
                'success' => true,
                'message' => sprintf(lang('whatsapp_templates_bulk_updated'), $updated_count),
                'data' => [
                    'updated_count' => $updated_count,
                ],
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Export templates.
     */
    public function export_templates(): void
    {
        try {
            if (cannot('view', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $status_key = request('status_key');
            $language = request('language');
            $enabled_only = request('enabled_only', true);

            $where = [];
            if ($status_key) {
                $where['status_key'] = $status_key;
            }
            if ($language) {
                $where['language'] = $language;
            }
            if ($enabled_only) {
                $where['enabled'] = 1;
            }

            $templates = $this->whatsapp_templates_model->get($where, null, null, 'status_key ASC, name ASC');

            // Remove sensitive data for export
            foreach ($templates as &$template) {
                unset($template['id'], $template['create_datetime'], $template['update_datetime']);
            }

            $filename = 'whatsapp_templates_' . date('Y-m-d_H-i-s') . '.json';

            header('Content-Type: application/json');
            header('Content-Disposition: attachment; filename="' . $filename . '"');
            
            echo json_encode($templates, JSON_PRETTY_PRINT);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }

    /**
     * Import templates.
     */
    public function import_templates(): void
    {
        try {
            if (cannot('edit', PRIV_SYSTEM_SETTINGS)) {
                abort(403, 'Forbidden');
            }

            $templates_data = request('templates');
            $overwrite_existing = request('overwrite_existing', false);

            if (empty($templates_data)) {
                json_response([
                    'success' => false,
                    'message' => 'Templates data is required',
                ], 400);
                return;
            }

            if (is_string($templates_data)) {
                $templates_data = json_decode($templates_data, true);
                if (json_last_error() !== JSON_ERROR_NONE) {
                    json_response([
                        'success' => false,
                        'message' => 'Invalid JSON format',
                    ], 400);
                    return;
                }
            }

            $imported_count = 0;
            $skipped_count = 0;
            $errors = [];

            foreach ($templates_data as $template) {
                try {
                    // Validate template
                    $validation_errors = $this->whatsapp_template_service->validate_template($template);
                    if (!empty($validation_errors)) {
                        $errors[] = 'Template "' . ($template['name'] ?? 'Unknown') . '": ' . implode(', ', $validation_errors);
                        continue;
                    }

                    // Check if template with same name and status exists
                    $existing = $this->whatsapp_templates_model->get([
                        'name' => $template['name'],
                        'status_key' => $template['status_key'],
                        'language' => $template['language'] ?? null,
                    ]);

                    if (!empty($existing) && !$overwrite_existing) {
                        $skipped_count++;
                        continue;
                    }

                    if (!empty($existing) && $overwrite_existing) {
                        $template['id'] = $existing[0]['id'];
                    }

                    $this->whatsapp_templates_model->save($template);
                    $imported_count++;

                } catch (Exception $e) {
                    $errors[] = 'Template "' . ($template['name'] ?? 'Unknown') . '": ' . $e->getMessage();
                }
            }

            json_response([
                'success' => true,
                'message' => sprintf(lang('whatsapp_templates_imported'), $imported_count),
                'data' => [
                    'imported_count' => $imported_count,
                    'skipped_count' => $skipped_count,
                    'errors' => $errors,
                ],
            ]);

        } catch (Throwable $e) {
            json_exception($e);
        }
    }
}
