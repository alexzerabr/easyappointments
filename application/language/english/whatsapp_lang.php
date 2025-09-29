<?php defined('BASEPATH') or exit('No direct script access allowed');

// WhatsApp Integration
$lang['whatsapp'] = 'WhatsApp';
$lang['whatsapp_info'] = 'Send appointment notifications and confirmations to customers via WhatsApp.';
// Routines UI
$lang['routines'] = 'Routines';
$lang['create_routine'] = 'Create Routine';
$lang['edit_routine'] = 'Edit Routine';
$lang['delete_routine'] = 'Delete Routine';
$lang['routine_name'] = 'Name';
$lang['routine_appointment_status'] = 'Appointment Status';
$lang['routine_template'] = 'Template';
$lang['routine_time_before'] = 'Time Before';
$lang['routine_active'] = 'Active';
$lang['save_routine'] = 'Save Routine';
$lang['cancel'] = 'Cancel';
$lang['select_template'] = 'Select Template';
$lang['routine_execute_confirm'] = 'Are you sure you want to execute this routine now?';
$lang['routine_executed'] = 'Routine executed';
$lang['routine_execute_failed'] = 'Failed to execute routine';
$lang['routine_name_exists'] = 'Routine name already exists';
$lang['please_fill_required'] = 'Please fill required fields';
// UI labels for routines
$lang['edit'] = 'Edit';
$lang['force'] = 'Force';
$lang['delete'] = 'Delete';
$lang['yes'] = 'Yes';
$lang['no'] = 'No';
$lang['executing'] = 'Executing...';
$lang['sent'] = 'sent';

// Configuration
$lang['whatsapp_configuration'] = 'Configuration';
$lang['whatsapp_host'] = 'URL';
$lang['whatsapp_host_hint'] = 'e.g. http://localhost:21465 | 127.0.0.1:21465 | https://your-domain';
// Port removed from UI
$lang['whatsapp_session'] = 'Session';
$lang['whatsapp_session_hint'] = 'nome único da sessão';
$lang['whatsapp_secret_key'] = 'Key';
$lang['whatsapp_secret_key_hint'] = 'chave de autenticação';
$lang['whatsapp_token'] = 'Authentication Token';
$lang['whatsapp_token_auto_hint'] = 'gerado automaticamente';
$lang['token_auto_generated'] = 'Token will be generated automatically';

// Actions
$lang['generate_token'] = 'Generate Token';
$lang['test_connectivity'] = 'Test Connectivity';
$lang['health_check'] = 'Health Check';
$lang['start_session'] = 'Start Session';
$lang['close_session'] = 'Close Session';
$lang['logout_session'] = 'Logout Session';
$lang['save_settings'] = 'Save Settings';
$lang['enable_integration'] = 'Enable Integration';

// Messages
$lang['whatsapp_settings_saved'] = 'WhatsApp settings saved successfully.';
$lang['whatsapp_token_generated'] = 'Authentication token generated successfully.';
$lang['whatsapp_session_started'] = 'WhatsApp session started successfully.';
$lang['whatsapp_session_closed'] = 'WhatsApp session closed successfully.';
$lang['whatsapp_session_logout'] = 'WhatsApp session logged out successfully.';
$lang['secret_key_required'] = 'Secret key is required to generate token.';
$lang['confirm_reveal_token'] = 'Are you sure you want to reveal the token? This action will be audited.';
$lang['confirm_rotate_token'] = 'Do you want to rotate the token? This will invalidate the current token and generate a new one.';
$lang['invalid_host'] = 'Invalid or unreachable host/URL';
$lang['token_generation_failed'] = 'Token generation failed. Please check secret key and session.';
$lang['connectivity_failed'] = 'Connectivity check failed';
$lang['no_token_generated'] = 'No token generated yet';
$lang['enter_secret_key'] = 'Enter your secret key';

// Session Status
$lang['whatsapp_session_management'] = 'Session Management';
$lang['session_status'] = 'Session Status';
$lang['connected'] = 'Connected';
$lang['waiting_qr_scan'] = 'Waiting for QR Scan';
$lang['pairing'] = 'Pairing';
$lang['session_not_found'] = 'Session Not Found';
$lang['connection_error'] = 'Connection Error';
// removed: unknown (status is shown only via badge)
// removed: checking_status (status text is now shown only via badge)
$lang['confirm_logout_session'] = 'Are you sure you want to logout from the WhatsApp session?';

// QR Code
$lang['whatsapp_qr_code'] = 'WhatsApp QR Code';
$lang['whatsapp_qr_instructions'] = 'Open WhatsApp on your phone and scan this QR code to connect.';
$lang['generating_qr_code'] = 'Generating QR code...';
$lang['refresh_qr'] = 'Refresh QR Code';
$lang['show_qr_code'] = 'Show QR Code';

// Message Settings
$lang['message_settings'] = 'Message Settings';
$lang['send_confirmation_messages'] = 'Send Confirmation Messages';
$lang['send_reschedule_messages'] = 'Send Reschedule Messages';
$lang['send_cancellation_messages'] = 'Send Cancellation Messages';
$lang['send_contract_messages'] = 'Send Contract Messages';

// Statistics
$lang['whatsapp_statistics'] = 'Statistics';
$lang['active_templates'] = 'Active Templates';
$lang['messages_sent'] = 'Messages Sent';
$lang['messages_failed'] = 'Messages Failed';
$lang['recent_logs'] = 'Recent Logs';

// Quick Actions
$lang['quick_actions'] = 'Quick Actions';
$lang['manage_templates'] = 'Manage Templates';
$lang['view_message_logs'] = 'View Message Logs';

// Templates
$lang['whatsapp_templates'] = 'WhatsApp Templates';
$lang['whatsapp_template_created'] = 'WhatsApp template created successfully.';
$lang['whatsapp_template_updated'] = 'WhatsApp template updated successfully.';
$lang['whatsapp_template_deleted'] = 'WhatsApp template deleted successfully.';
$lang['whatsapp_template_toggled'] = 'WhatsApp template %s successfully.';
$lang['whatsapp_template_duplicated'] = 'WhatsApp template duplicated successfully.';
$lang['whatsapp_templates_bulk_updated'] = '%d WhatsApp templates updated successfully.';
$lang['whatsapp_default_templates_created'] = '%d default templates created successfully.';
$lang['whatsapp_templates_imported'] = '%d WhatsApp templates imported successfully.';

// Template Fields
$lang['template_name'] = 'Template Name';
$lang['template_status'] = 'Status';
$lang['template_language'] = 'Language';
$lang['template_body'] = 'Message Body';
$lang['template_enabled'] = 'Enabled';
$lang['template_preview'] = 'Preview';
$lang['available_variables'] = 'Available Variables';
$lang['available_placeholders'] = 'Available Variables'; // Compatibility
$lang['create_template'] = 'Create Template';
$lang['edit_template'] = 'Edit Template';
$lang['duplicate_template'] = 'Duplicate Template';
$lang['delete_template'] = 'Delete Template';
$lang['enable_template'] = 'Enable Template';
$lang['disable_template'] = 'Disable Template';

// Placeholders
$lang['placeholder_client_name'] = 'Customer full name';
$lang['placeholder_phone'] = 'Customer phone number';
$lang['placeholder_appointment_date'] = 'Appointment date';
$lang['placeholder_appointment_time'] = 'Appointment time';
$lang['placeholder_service_name'] = 'Service name';
$lang['placeholder_location'] = 'Appointment location';
$lang['placeholder_link'] = 'Appointment management link';

// Message Logs
$lang['message_logs'] = 'Message Logs';
$lang['no_message_logs'] = 'No message logs found.';
$lang['log_date'] = 'Date';
$lang['log_phone'] = 'Phone';
$lang['log_status'] = 'Status';
$lang['log_result'] = 'Result';
$lang['log_send_type'] = 'Send Type';
$lang['log_template'] = 'Template';
$lang['log_error'] = 'Error';

// Send Types
$lang['send_type_onCreate'] = 'On Create';
$lang['send_type_onUpdate'] = 'On Update';
$lang['send_type_manual'] = 'Manual';

// Results
$lang['result_success'] = 'Success';
$lang['result_failure'] = 'Failure';
$lang['result_pending'] = 'Pending';

// Appointment Form
$lang['whatsapp_template'] = 'WhatsApp Template';
$lang['select_template'] = 'Select Template';
$lang['send_whatsapp'] = 'Send WhatsApp';
$lang['whatsapp_message_sent'] = 'WhatsApp message sent successfully.';
$lang['whatsapp_message_failed'] = 'Failed to send WhatsApp message: %s';

// Errors
$lang['whatsapp_not_configured'] = 'WhatsApp integration is not configured.';
$lang['whatsapp_not_enabled'] = 'WhatsApp integration is not enabled.';
$lang['whatsapp_session_not_connected'] = 'WhatsApp session is not connected.';
$lang['whatsapp_no_customer_phone'] = 'Customer phone number is required.';
$lang['whatsapp_no_template'] = 'No template found for this status.';

// Status Actions
$lang['generating'] = 'Generating...';
$lang['testing'] = 'Testing...';
$lang['starting'] = 'Starting...';
$lang['closing'] = 'Closing...';
$lang['logging_out'] = 'Logging out...';
$lang['loading'] = 'Loading...';

// Bulk Actions
$lang['bulk_actions'] = 'Bulk Actions';
$lang['bulk_enable'] = 'Enable Selected';
$lang['bulk_disable'] = 'Disable Selected';
$lang['bulk_delete'] = 'Delete Selected';
$lang['select_action'] = 'Select Action';
$lang['apply'] = 'Apply';

// Import/Export
$lang['import_templates'] = 'Import Templates';
$lang['export_templates'] = 'Export Templates';
$lang['import_file'] = 'Import File';
$lang['overwrite_existing'] = 'Overwrite Existing';
$lang['templates_file'] = 'Templates File';
$lang['choose_file'] = 'Choose File';

// Validation
$lang['template_name_required'] = 'Template name is required.';
$lang['template_status_required'] = 'Template status is required.';
$lang['template_body_required'] = 'Template body is required.';

// Additional template translations
$lang['whatsapp_templates_description'] = 'Manage WhatsApp message templates for different appointment statuses.';
$lang['whatsapp_templates_management'] = 'Templates Management';
$lang['status_key'] = 'Status Key';
$lang['language'] = 'Language';
$lang['enabled'] = 'Enabled';
$lang['created_at'] = 'Created At';
$lang['actions'] = 'Actions';
$lang['select_status'] = 'Select Status';
$lang['template_body_placeholder'] = 'Enter the message body using placeholders like {{client_name}}, {{appointment_date}}, etc.';
$lang['template_body_hint'] = 'Use variables to customize the message. Click on the variables below to insert automatically.';
$lang['variable_hint'] = 'Use variables to customize the message. Click on the variables below to insert automatically.';
$lang['unknown_variable'] = 'Unknown variable';
$lang['use_available_variables'] = 'Use only available variables';
$lang['template_preview'] = 'Template Preview';
$lang['insert_variable'] = 'Insert Variable';
$lang['available_variables'] = 'Available Variables';
$lang['available_placeholders'] = 'Available Variables'; // Compatibility
$lang['preview_template'] = 'Preview Template';
$lang['save_template'] = 'Save Template';
$lang['cancel'] = 'Cancel';
$lang['close'] = 'Close';
$lang['template_preview'] = 'Template Preview';
$lang['select_file'] = 'Select File';
$lang['import_file_hint'] = 'Select a JSON file with templates to import.';
$lang['import'] = 'Import';
$lang['no_templates_found'] = 'No templates found';
$lang['create_default_templates'] = 'Create Default Templates';

// Tab navigation translations
$lang['whatsapp_configuration'] = 'Configuration';
$lang['whatsapp_message_logs'] = 'Message Logs';
$lang['refresh'] = 'Refresh';
$lang['all_statuses'] = 'All Statuses';
$lang['success'] = 'Success';
$lang['failure'] = 'Failure';
$lang['date'] = 'Date';
$lang['phone'] = 'Phone';
$lang['status'] = 'Status';
$lang['result'] = 'Result';
$lang['invalid_placeholder'] = 'Invalid placeholder: %s';
$lang['invalid_language_code'] = 'Invalid language code: %s';
$lang['invalid_status_key'] = 'Invalid status key: %s';

// Common
$lang['enabled'] = 'Enabled';
$lang['disabled'] = 'Disabled';
$lang['active'] = 'Active';
$lang['inactive'] = 'Inactive';
$lang['configure'] = 'Configure';
$lang['close'] = 'Close';
$lang['cancel'] = 'Cancel';
$lang['delete'] = 'Delete';
$lang['edit'] = 'Edit';
$lang['create'] = 'Create';
$lang['update'] = 'Update';
$lang['refresh'] = 'Refresh';
$lang['preview'] = 'Preview';
$lang['date'] = 'Date';
$lang['phone'] = 'Phone';
$lang['status'] = 'Status';
$lang['result'] = 'Result';
$lang['send_type'] = 'Send Type';
