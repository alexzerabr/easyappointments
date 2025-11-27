<?php extend('layouts/backend_layout'); ?>

<?php section('content'); ?>

<div id="whatsapp-integration-page" class="container backend-page">
    <div class="row">
        <div class="col-sm-3 offset-sm-1">
            <?php component('settings_nav'); ?>
        </div>
        <div id="whatsapp-integration" class="col-sm-8">
            <h4 class="text-secondary border-bottom py-3 mb-3 fw-light">
                <?= lang('Whatsapp') ?>
            </h4>

            <p class="form-text text-muted mb-4">
            </p>

            <!-- Navigation Tabs -->
            <ul class="nav nav-tabs mb-4" id="whatsapp-tabs" role="tablist">
                <li class="nav-item" role="presentation">
                    <button class="nav-link active" id="config-tab" data-bs-toggle="tab" data-bs-target="#config-pane" type="button" role="tab" aria-controls="config-pane" aria-selected="true">
                        <i class="fas fa-cog me-2"></i>
                        <?= lang('whatsapp_configuration') ?>
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="templates-tab" data-bs-toggle="tab" data-bs-target="#templates-pane" type="button" role="tab" aria-controls="templates-pane" aria-selected="false">
                        <i class="fas fa-file-alt me-2"></i>
                        <?= lang('whatsapp_templates') ?>
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="routines-tab" data-bs-toggle="tab" data-bs-target="#routines-pane" type="button" role="tab" aria-controls="routines-pane" aria-selected="false">
                        <i class="fas fa-clock me-2"></i>
                        <?= lang('routines') ?>
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="logs-tab" data-bs-toggle="tab" data-bs-target="#logs-pane" type="button" role="tab" aria-controls="logs-pane" aria-selected="false">
                        <i class="fas fa-list me-2"></i>
                        <?= lang('whatsapp_message_logs') ?>
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="execution-logs-tab" data-bs-toggle="tab" data-bs-target="#execution-logs-pane" type="button" role="tab" aria-controls="execution-logs-pane" aria-selected="false">
                        <i class="fas fa-history me-2"></i>
                        <?= lang('execution_logs') ?>
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="test-tab" data-bs-toggle="tab" data-bs-target="#test-pane" type="button" role="tab" aria-controls="test-pane" aria-selected="false">
                        <i class="fas fa-paper-plane me-2"></i>
                        <?= lang('test_send') ?>
                    </button>
                </li>
            </ul>

            <!-- Tab Content -->
            <div class="tab-content" id="whatsapp-tab-content">
                <!-- Configuration Tab -->
                <div class="tab-pane fade show active" id="config-pane" role="tabpanel" aria-labelledby="config-tab">

            

            <!-- Configuration Section -->
            <div class="card mb-4">
                <div class="card-header">
                    <h5 class="fw-light text-secondary mb-0">
                        <?= lang('whatsapp_configuration') ?>
                    </h5>
                </div>
                <div class="card-body">
                    <form id="whatsapp-settings-form">
                        <div class="row">
                            <div class="col-md-12 mb-4">
                                <div class="form-check form-switch">
                                    <input class="form-check-input" type="checkbox" id="whatsapp-enabled" data-field="enabled" 
                                           <?= !empty($whatsapp_settings['enabled']) ? 'checked' : '' ?>>
                                    <label class="form-check-label" for="whatsapp-enabled">
                                        <strong><?= lang('whatsapp_integration_enabled') ?: 'Habilitar Integração WhatsApp' ?></strong>
                                    </label>
                                </div>
                                <div class="form-text">
                                    <?= lang('whatsapp_integration_enabled_hint') ?>
                                </div>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-12 mb-3">
                                <label for="whatsapp-host" class="form-label">
                                    <?= lang('whatsapp_host') ?> *
                                </label>
                                <input type="text" id="whatsapp-host" data-field="host" class="form-control"
                                       value="<?= $whatsapp_settings['host'] ?? 'http://localhost:21465' ?>"
                                       placeholder="<?= lang('whatsapp_host_placeholder') ?>" required>
                                <div class="form-text"><?= lang('whatsapp_host_hint') ?></div>
                            </div>
                        </div>

                        <div class="row">
                            <div class="col-md-6 mb-3">
                                <label for="whatsapp-session" class="form-label">
                                    <?= lang('whatsapp_session') ?> *
                                </label>
                                <input type="text" id="whatsapp-session" data-field="session" class="form-control" 
                                       value="<?= $whatsapp_settings['session'] ?? 'default' ?>" 
                                       placeholder="default" required>
                                <div class="form-text"><?= lang('whatsapp_session_hint') ?></div>
                            </div>
                            <div class="col-md-6 mb-3">
                                <label for="whatsapp-secret-key" class="form-label">
                                    <?= lang('whatsapp_secret_key') ?> *
                                </label>
                                <div class="input-group">
                                    <input type="password" id="whatsapp-secret-key" data-field="secret_key" class="form-control" 
                                           placeholder="<?= lang('enter_secret_key') ?>">
                                    <button class="btn btn-outline-secondary" type="button" id="toggle-secret-key">
                                        <i class="fas fa-eye"></i>
                                    </button>
                                </div>
                                <div class="form-text"><?= lang('whatsapp_secret_key_hint') ?></div>
                            </div>
                        </div>

                        <div class="d-flex justify-content-between">
                            <div>
                                <button type="button" id="test-connectivity-btn" class="btn btn-outline-info me-2">
                                    <i class="fas fa-network-wired me-2"></i>
                                    <?= lang('test_connectivity') ?>
                                </button>
                                <button type="button" id="show-qr-btn" class="btn btn-outline-success">
                                    <i class="fas fa-qrcode me-2"></i>
                                    <?= lang('show_qr_code') ?>
                                </button>
                            </div>
                            <button type="button" id="save-settings" class="btn btn-primary">
                                <i class="fas fa-save me-2"></i>
                                <?= lang('save_settings') ?>
                            </button>
                        </div>
                    </form>
                </div>
            </div>

            <!-- Session Management -->
            <div class="card mb-4">
                <div class="card-header">
                    <h5 class="fw-light text-secondary mb-0">
                        <?= lang('whatsapp_session_management') ?>
                    </h5>
                </div>
                <div class="card-body">
                    

                    <div class="btn-group me-2" role="group">
                        <button type="button" id="start-session-btn" class="btn btn-success">
                            <i class="fas fa-play me-2"></i>
                            <?= lang('start_session') ?>
                        </button>
                        <button type="button" id="close-session-btn" class="btn btn-warning">
                            <i class="fas fa-pause me-2"></i>
                            <?= lang('close_session') ?>
                        </button>
                        <button type="button" id="logout-session-btn" class="btn btn-danger">
                            <i class="fas fa-sign-out-alt me-2"></i>
                            <?= lang('logout_session') ?>
                        </button>
                    </div>
                </div>
            </div>

            <!-- Statistics -->
            <div class="card mb-4">
                <div class="card-header">
                    <h5 class="fw-light text-secondary mb-0">
                        <?= lang('whatsapp_statistics') ?>
                    </h5>
                </div>
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-4 text-center">
                            <div class="h4 text-primary mb-1" id="stat-templates"><?= $template_stats['enabled'] ?? 0 ?></div>
                            <div class="text-muted"><?= lang('active_templates') ?></div>
                        </div>
                        <div class="col-md-4 text-center">
                            <div class="h4 text-success mb-1" id="stat-sent"><?= $message_stats['SUCCESS'] ?? 0 ?></div>
                            <div class="text-muted"><?= lang('messages_sent') ?></div>
                        </div>
                        <div class="col-md-4 text-center">
                            <div class="h4 text-danger mb-1" id="stat-failed"><?= $message_stats['FAILURE'] ?? 0 ?></div>
                            <div class="text-muted"><?= lang('messages_failed') ?></div>
                        </div>
                    </div>
                </div>
            </div>

                </div>

                <!-- Test Tab -->
                <div class="tab-pane fade" id="test-pane" role="tabpanel" aria-labelledby="test-tab">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="fw-light text-secondary mb-0">
                                <i class="fas fa-paper-plane me-2"></i>
                                <?= lang('test_send_message') ?>
                            </h5>
                        </div>
                        <div class="card-body">
                            <div class="alert alert-info">
                                <i class="fas fa-info-circle me-2"></i>
                                <?= lang('test_whatsapp_integration') ?>
                            </div>

                            <form id="test-message-form">
                                <div class="row">
                                    <div class="col-md-12">
                                        <div class="mb-3">
                                            <label for="test-phone" class="form-label"><?= lang('phone_number') ?> *</label>
                                            <input type="text" id="test-phone" name="phone" class="form-control"
                                                   placeholder="<?= lang('phone_placeholder') ?>" required>
                                            <div class="form-text"><?= lang('phone_format_hint') ?></div>
                                        </div>
                                    </div>
                                </div>

                                <div class="mb-3">
                                    <label for="test-message" class="form-label"><?= lang('message') ?> *</label>
                                    <textarea id="test-message" name="message" class="form-control" rows="4"
                                              placeholder="<?= lang('test_message_placeholder') ?>" required></textarea>
                                    <div class="form-text"><?= lang('message_max_chars') ?></div>
                                </div>

                                <div class="d-flex justify-content-between">
                                    <div>
                                        <button type="button" id="clear-test-form" class="btn btn-outline-secondary">
                                            <i class="fas fa-eraser me-2"></i>
                                            <?= lang('clear') ?>
                                        </button>
                                    </div>
                                    <div>
                                        <button type="submit" id="send-test-message" class="btn btn-primary">
                                            <i class="fas fa-paper-plane me-2"></i>
                                            <?= lang('send_test') ?>
                                        </button>
                                    </div>
                                </div>
                            </form>

                            <!-- Test Result -->
                            <div id="test-result" class="mt-4 d-none">
                                <div class="card">
                                    <div class="card-header">
                                        <h6 class="mb-0"><?= lang('test_result') ?></h6>
                                    </div>
                                    <div class="card-body">
                                        <div id="test-result-content"></div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Templates Tab -->
                <div class="tab-pane fade" id="templates-pane" role="tabpanel" aria-labelledby="templates-tab">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="fw-light text-secondary mb-0">
                                <?= lang('whatsapp_templates') ?>
                            </h5>
                        </div>
                        <div class="card-body">
                            <div class="d-flex justify-content-between mb-3">
                                <div>
                                    <button type="button" id="create-template-btn" class="btn btn-primary me-2">
                                        <i class="fas fa-plus me-2"></i>
                                        <?= lang('create_template') ?>
                                    </button>
                                </div>
                                <div>
                                    <button type="button" id="refresh-templates-btn" class="btn btn-outline-secondary">
                                        <i class="fas fa-sync-alt"></i>
                                    </button>
                                </div>
                            </div>

                            <div class="table-responsive">
                                <table id="templates-table" class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th><?= lang('template_name') ?></th>
                                            <th><?= lang('status_key') ?></th>
                                            <th><?= lang('language') ?></th>
                                            <th><?= lang('enabled') ?></th>
                                            <th><?= lang('actions') ?></th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <!-- Templates will be loaded via AJAX -->
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Routines Tab -->
                <div class="tab-pane fade" id="routines-pane" role="tabpanel" aria-labelledby="routines-tab">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="fw-light text-secondary mb-0"><?= lang('routines') ?></h5>
                        </div>
                        <div class="card-body">
                            <div class="mb-3 d-flex justify-content-between">
                                <div>
                                    <button id="create-routine-btn" class="btn btn-primary"><i class="fas fa-plus me-2"></i><?= lang('create_routine') ?></button>
                                </div>
                            </div>

                            <div class="table-responsive">
                                <table id="routines-table" class="table">
                                    <thead>
                                        <tr>
                                            <th><?= lang('routine_name') ?></th>
                                            <th><?= lang('routine_appointment_status') ?></th>
                                            <th><?= lang('routine_template') ?></th>
                                            <th><?= lang('routine_time_before') ?></th>
                                            <th><?= lang('routine_active') ?></th>
                                            <th><?= lang('actions') ?></th>
                                        </tr>
                                    </thead>
                                    <tbody></tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Routine Modal -->
                <div class="modal fade" id="routine-modal" tabindex="-1" aria-hidden="true">
                    <div class="modal-dialog modal-dialog-centered">
                        <div class="modal-content">
                            <div class="modal-header">
                                <h5 class="modal-title" id="routine-modal-title"><?= lang('create_routine') ?></h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                            </div>
                            <div class="modal-body">
                                <form id="routine-form">
                                    <input type="hidden" id="routine-id">
                                    <div class="mb-3">
                                        <label class="form-label"><?= lang('routine_name') ?></label>
                                        <input id="routine-name" class="form-control" required>
                                    </div>
                                    <div class="mb-3">
                                        <label class="form-label"><?= lang('routine_appointment_status') ?></label>
                                        <select id="routine-status" class="form-select" required>
                                            <option value=""><?= lang('select_status') ?></option>
                                            <?php foreach (json_decode(setting('appointment_status_options') ?: '[]', true) as $opt): ?>
                                                <option value="<?= e($opt) ?>"><?= e($opt) ?></option>
                                            <?php endforeach; ?>
                                        </select>
                                    </div>
                                    <div class="mb-3">
                                        <label class="form-label"><?= lang('routine_template') ?></label>
                                        <select id="routine-template" class="form-select">
                                            <option value=""><?= lang('select_template') ?></option>
                                        </select>
                                    </div>
                                    <div class="mb-3">
                                        <label class="form-label"><?= lang('routine_time_before') ?></label>
                                        <input id="routine-timebefore" type="number" class="form-control" value="1" min="1">
                                    </div>
                                    <div class="form-check mb-3">
                                        <input class="form-check-input" type="checkbox" id="routine-active" checked>
                                        <label class="form-check-label" for="routine-active"><?= lang('routine_active') ?></label>
                                    </div>
                                </form>
                            </div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal"><?= lang('cancel') ?></button>
                                <button type="button" id="save-routine-btn" class="btn btn-primary"><?= lang('save_routine') ?></button>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Logs Tab -->
                <div class="tab-pane fade" id="logs-pane" role="tabpanel" aria-labelledby="logs-tab">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="fw-light text-secondary mb-0">
                                <?= lang('whatsapp_message_logs') ?>
                            </h5>
                        </div>
                        <div class="card-body">
                            <div class="d-flex justify-content-between mb-3">
                                <div>
                                    <button type="button" id="refresh-logs-btn" class="btn btn-outline-secondary">
                                        <i class="fas fa-sync-alt me-2"></i>
                                        <?= lang('refresh') ?>
                                    </button>
                                    <button type="button" id="clear-logs-btn" class="btn btn-outline-danger ms-2">
                                        <i class="fas fa-trash me-2"></i>
                                        <?= lang('clear_logs') ?>
                                    </button>
                                </div>
                                <div>
                                    <select id="log-filter-status" class="form-select form-select-sm d-inline-block w-auto">
                                        <option value=""><?= lang('all_statuses') ?></option>
                                        <option value="SUCCESS"><?= lang('success') ?></option>
                                        <option value="PENDING"><?= lang('pending') ?></option>
                                        <option value="FAILURE"><?= lang('failure') ?></option>
                                    </select>
                                </div>
                            </div>

                            <div class="table-responsive">
                                <table id="logs-table" class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th><?= lang('date') ?></th>
                                            <th><?= lang('phone') ?></th>
                                            <th><?= lang('status') ?></th>
                                            <th><?= lang('result') ?></th>
                                            <th><?= lang('actions') ?></th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <!-- Logs will be loaded via AJAX -->
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Execution Logs Tab -->
                <div class="tab-pane fade" id="execution-logs-pane" role="tabpanel" aria-labelledby="execution-logs-tab">
                    <div class="card">
                        <div class="card-header">
                            <h5 class="fw-light text-secondary mb-0">
                                <i class="fas fa-history me-2"></i>
                                <?= lang('routine_execution_logs') ?>
                            </h5>
                        </div>
                        <div class="card-body">
                            <!-- Statistics Cards -->
                            <div class="row mb-4">
                                <div class="col-md-3">
                                    <div class="card bg-primary text-white">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between">
                                                <div>
                                                    <h4 class="mb-0" id="total-executions">-</h4>
                                                    <span class="small"><?= lang('total_executions') ?></span>
                                                </div>
                                                <i class="fas fa-play-circle fa-2x"></i>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="card bg-success text-white">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between">
                                                <div>
                                                    <h4 class="mb-0" id="successful-executions">-</h4>
                                                    <span class="small"><?= lang('successes') ?></span>
                                                </div>
                                                <i class="fas fa-check-circle fa-2x"></i>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="card bg-warning text-white">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between">
                                                <div>
                                                    <h4 class="mb-0" id="partial-executions">-</h4>
                                                    <span class="small"><?= lang('partials') ?></span>
                                                </div>
                                                <i class="fas fa-exclamation-triangle fa-2x"></i>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div class="col-md-3">
                                    <div class="card bg-danger text-white">
                                        <div class="card-body">
                                            <div class="d-flex justify-content-between">
                                                <div>
                                                    <h4 class="mb-0" id="failed-executions">-</h4>
                                                    <span class="small"><?= lang('failures') ?></span>
                                                </div>
                                                <i class="fas fa-times-circle fa-2x"></i>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <!-- Filters -->
                            <div class="row mb-3">
                                <div class="col-md-3">
                                    <label for="execution-log-routine-filter" class="form-label"><?= lang('routine') ?></label>
                                    <select id="execution-log-routine-filter" class="form-select">
                                        <option value=""><?= lang('all_routines') ?></option>
                                    </select>
                                </div>
                                <div class="col-md-2">
                                    <label for="execution-log-status-filter" class="form-label"><?= lang('status') ?></label>
                                    <select id="execution-log-status-filter" class="form-select">
                                        <option value=""><?= lang('all') ?></option>
                                        <option value="SUCCESS"><?= lang('success') ?></option>
                                        <option value="PARTIAL_SUCCESS"><?= lang('partial') ?></option>
                                        <option value="FAILURE"><?= lang('failure') ?></option>
                                    </select>
                                </div>
                                <div class="col-md-2">
                                    <label for="execution-log-date-from" class="form-label"><?= lang('date_from') ?></label>
                                    <input type="date" id="execution-log-date-from" class="form-control">
                                </div>
                                <div class="col-md-2">
                                    <label for="execution-log-date-to" class="form-label"><?= lang('date_to') ?></label>
                                    <input type="date" id="execution-log-date-to" class="form-control">
                                </div>
                                <div class="col-md-3">
                                    <label class="form-label">&nbsp;</label>
                                    <div class="d-flex gap-2">
                                        <button type="button" id="filter-execution-logs-btn" class="btn btn-primary">
                                            <i class="fas fa-filter me-2"></i><?= lang('filter') ?>
                                        </button>
                                        <button type="button" id="clear-execution-filters-btn" class="btn btn-outline-secondary">
                                            <i class="fas fa-times me-2"></i><?= lang('clear') ?>
                                        </button>
                                    </div>
                                </div>
                            </div>

                            <!-- Actions -->
                            <div class="d-flex justify-content-between mb-3">
                                <div>
                                    <button type="button" id="refresh-execution-logs-btn" class="btn btn-outline-secondary">
                                        <i class="fas fa-sync-alt me-2"></i><?= lang('refresh') ?>
                                    </button>
                                </div>
                                <div>
                                    <button type="button" id="cleanup-execution-logs-btn" class="btn btn-outline-warning">
                                        <i class="fas fa-broom me-2"></i><?= lang('clear_old_logs') ?>
                                    </button>
                                </div>
                            </div>

                            <!-- Execution Logs Table -->
                            <div class="table-responsive">
                                <table id="execution-logs-table" class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th><?= lang('datetime') ?></th>
                                            <th><?= lang('routine') ?></th>
                                            <th><?= lang('status') ?></th>
                                            <th><?= lang('appointment_status') ?></th>
                                            <th><?= lang('template') ?></th>
                                            <th><?= lang('found') ?></th>
                                            <th><?= lang('successes') ?></th>
                                            <th><?= lang('failures') ?></th>
                                            <th><?= lang('time_seconds') ?></th>
                                            <th><?= lang('actions') ?></th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <!-- Execution logs will be loaded via AJAX -->
                                    </tbody>
                                </table>
                            </div>

                            <!-- Pagination -->
                            <nav aria-label="Execution logs pagination" class="mt-3">
                                <ul id="execution-logs-pagination" class="pagination justify-content-center">
                                    <!-- Pagination will be generated via JavaScript -->
                                </ul>
                            </nav>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- QR Code Modal -->
<div class="modal fade" id="qr-code-modal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title"><?= lang('whatsapp_qr_code') ?></h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body text-center">
                <p class="text-muted mb-3"><?= lang('whatsapp_qr_instructions') ?></p>
                <div id="qr-code-container">
                    <img id="qr-code-image" src="" alt="QR Code" class="img-fluid">
                </div>
                <div id="qr-loading" class="d-none">
                    <div class="spinner-border text-primary" role="status">
                        <span class="visually-hidden"><?= lang('loading') ?></span>
                    </div>
                    <p class="mt-2 text-muted"><?= lang('generating_qr_code') ?></p>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                    <?= lang('close') ?>
                </button>
                <button type="button" id="refresh-qr-btn" class="btn btn-primary">
                    <i class="fas fa-sync-alt me-2"></i>
                    <?= lang('refresh_qr') ?>
                </button>
            </div>
        </div>
    </div>
</div>

<!-- Message Logs Modal -->
<div class="modal fade" id="message-logs-modal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-xl">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title"><?= lang('message_logs') ?></h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div id="message-logs-container">
                    <!-- Logs will be loaded here -->
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Template Modal -->
<div class="modal fade" id="template-modal" tabindex="-1">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="template-modal-title"><?= lang('create_template') ?></h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <form id="template-form">
                    <input type="hidden" id="template-id" name="id">
                    
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label for="template-name" class="form-label"><?= lang('template_name') ?> *</label>
                            <input type="text" id="template-name" name="name" class="form-control" required>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label for="template-status-key" class="form-label"><?= lang('status_key') ?> *</label>
                            <select id="template-status-key" name="status_key" class="form-select" required>
                                <option value=""><?= lang('select_status') ?></option>
                            </select>
                        </div>
                    </div>
                    
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label for="template-language" class="form-label"><?= lang('language') ?></label>
                            <select id="template-language" name="language" class="form-select">
                                <option value="pt-BR">Português (Brasil)</option>
                                <option value="en">English</option>
                            </select>
                        </div>
                        <div class="col-md-6 mb-3">
                            <div class="form-check form-switch mt-4">
                                <input class="form-check-input" type="checkbox" id="template-enabled" name="enabled">
                                <label class="form-check-label" for="template-enabled">
                                    <?= lang('enabled') ?>
                                </label>
                            </div>
                        </div>
                    </div>
                    
                    <div class="mb-3">
                        <label for="template-body" class="form-label"><?= lang('template_body') ?> *</label>
                        <textarea id="template-body" name="body" class="form-control" rows="6" required 
                                  placeholder="<?= lang('template_body_placeholder') ?>"></textarea>
                        <div class="form-text"><?= lang('template_body_hint') ?></div>
                    </div>
                    
                    <div class="mb-3">
                        <label class="form-label"><?= lang('available_variables') ?></label>
                        <div id="placeholders-list" class="border rounded p-2 bg-light">
                            <!-- Variables will be loaded via AJAX -->
                        </div>
                    </div>
                    
                    <div class="mb-3">
                        <button type="button" id="preview-template-btn" class="btn btn-outline-info">
                            <i class="fas fa-eye me-2"></i>
                            <?= lang('preview_template') ?>
                        </button>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                    <?= lang('cancel') ?>
                </button>
                <button type="button" id="save-template-btn" class="btn btn-primary">
                    <i class="fas fa-save me-2"></i>
                    <?= lang('save_template') ?>
                </button>
            </div>
        </div>
    </div>
</div>

<!-- Preview Modal -->
<div class="modal fade" id="preview-modal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title"><?= lang('template_preview') ?></h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div id="preview-content" class="border rounded p-3 bg-light">
                    <!-- Preview content will be loaded here -->
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                    <?= lang('close') ?>
                </button>
            </div>
        </div>
    </div>
</div>

<!-- Execution Log Details Modal -->
<div class="modal fade" id="execution-log-details-modal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">
                    <i class="fas fa-info-circle me-2"></i>
                    <?= lang('execution_details') ?>
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div class="row">
                    <div class="col-md-6">
                        <h6 class="text-muted"><?= lang('general_information') ?></h6>
                        <table class="table table-sm">
                            <tr>
                                <td><strong><?= lang('routine') ?>:</strong></td>
                                <td id="detail-routine-name">-</td>
                            </tr>
                            <tr>
                                <td><strong><?= lang('status') ?>:</strong></td>
                                <td id="detail-execution-status">-</td>
                            </tr>
                            <tr>
                                <td><strong><?= lang('datetime') ?>:</strong></td>
                                <td id="detail-execution-datetime">-</td>
                            </tr>
                            <tr>
                                <td><strong><?= lang('execution_time') ?>:</strong></td>
                                <td id="detail-execution-time">-</td>
                            </tr>
                        </table>
                    </div>
                    <div class="col-md-6">
                        <h6 class="text-muted"><?= lang('results') ?></h6>
                        <table class="table table-sm">
                            <tr>
                                <td><strong><?= lang('appointments_found') ?>:</strong></td>
                                <td id="detail-total-appointments">-</td>
                            </tr>
                            <tr>
                                <td><strong><?= lang('successful_sends') ?>:</strong></td>
                                <td id="detail-successful-sends">-</td>
                            </tr>
                            <tr>
                                <td><strong><?= lang('failed_sends') ?>:</strong></td>
                                <td id="detail-failed-sends">-</td>
                            </tr>
                            <tr>
                                <td><strong><?= lang('template') ?>:</strong></td>
                                <td id="detail-template-name">-</td>
                            </tr>
                        </table>
                    </div>
                </div>

                <div class="mt-3">
                    <h6 class="text-muted"><?= lang('notified_clients') ?></h6>
                    <div id="detail-clients-notified" class="border rounded p-3 bg-light" style="max-height: 200px; overflow-y: auto;">
                        <!-- Clients list will be loaded here -->
                    </div>
                </div>

                <div class="mt-3">
                    <h6 class="text-muted"><?= lang('execution_details') ?></h6>
                    <div id="detail-execution-details" class="border rounded p-3 bg-light" style="max-height: 200px; overflow-y: auto;">
                        <!-- Execution details will be loaded here -->
                    </div>
                </div>

                <div id="detail-error-section" class="mt-3 d-none">
                    <h6 class="text-muted text-danger"><?= lang('error_message') ?></h6>
                    <div id="detail-error-message" class="alert alert-danger">
                        <!-- Error message will be loaded here -->
                    </div>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                    <i class="fas fa-times me-2"></i><?= lang('close') ?>
                </button>
            </div>
        </div>
    </div>
</div>

<!-- Cleanup Confirmation Modal -->
<div class="modal fade" id="cleanup-confirmation-modal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">
                    <i class="fas fa-exclamation-triangle me-2 text-warning"></i>
                    <?= lang('confirm_cleanup') ?>
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <p><?= lang('confirm_cleanup_message') ?></p>
                <div class="mb-3">
                    <label for="cleanup-days" class="form-label"><?= lang('keep_logs_days') ?>:</label>
                    <input type="number" id="cleanup-days" class="form-control" value="90" min="1" max="365">
                    <div class="form-text"><?= lang('cleanup_warning') ?></div>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">
                    <i class="fas fa-times me-2"></i><?= lang('cancel') ?>
                </button>
                <button type="button" id="confirm-cleanup-btn" class="btn btn-warning">
                    <i class="fas fa-broom me-2"></i><?= lang('confirm_cleanup') ?>
                </button>
            </div>
        </div>
    </div>
</div>

<?php section('scripts'); ?>

<script src="<?= asset_url('assets/js/pages/whatsapp_integration_simple.js') ?>"></script>

<?php end_section('scripts'); ?>

<?php end_section('content'); ?>
