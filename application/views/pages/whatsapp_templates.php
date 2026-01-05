<?php extend('layouts/backend_layout'); ?>

<?php section('content'); ?>

<div class="container-fluid">
    <div class="row">
        <div class="col-12">
            <!-- Templates Management -->
            <div class="card mb-4">
                <div class="card-header">
                    <h5 class="fw-light text-black-50 mb-0">
                        <?= lang('whatsapp_templates_management') ?>
                    </h5>
                </div>
                <div class="card-body">
                    <!-- Template Actions -->
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

                    <!-- Templates Table -->
                    <div class="table-responsive">
                        <table id="templates-table" class="table table-striped">
                            <thead>
                                <tr>
                                    <th><?= lang('template_name') ?></th>
                                    <th><?= lang('status_key') ?></th>
                                    <th><?= lang('language') ?></th>
                                    <th><?= lang('enabled') ?></th>
                                    <th><?= lang('created_at') ?></th>
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
                                <input class="form-check-input" type="checkbox" id="template-enabled" name="enabled" checked>
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
                        <label class="form-label"><?= lang('available_placeholders') ?></label>
                        <div id="placeholders-list" class="border rounded p-2 bg-light">
                            <!-- Placeholders will be loaded via AJAX -->
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


<?php slot('scripts'); ?>
<script>
// Global variables
let templates = [];
let statuses = [];
let placeholders = [];

$(document).ready(function() {
    console.log('WhatsApp Templates: Loading...');
    
    // Load initial data
    loadTemplates();
    loadStatuses();
    loadPlaceholders();
    
    // Event handlers
    $('#create-template-btn').on('click', function() {
        openTemplateModal();
    });
    
    
    
    $('#refresh-templates-btn').on('click', function() {
        loadTemplates();
    });
    
    $('#save-template-btn').on('click', function() {
        saveTemplate();
    });
    
    $('#preview-template-btn').on('click', function() {
        previewTemplate();
    });
    
    $('#confirm-import-btn').on('click', function() {
        importTemplates();
    });
});

// Load templates
function loadTemplates() {
    $.ajax({
        url: 'whatsapp_templates/get_templates',
        type: 'GET',
        data: {
            csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
        },
        success: function(response) {
            console.log('Templates loaded:', response);
            templates = response.data || [];
            renderTemplatesTable();
        },
        error: function(xhr, status, error) {
            console.error('Error loading templates:', xhr, status, error);
            alert('Erro ao carregar templates: ' + error);
        }
    });
}

// Load statuses
function loadStatuses() {
    $.ajax({
        url: 'whatsapp_templates/get_statuses',
        type: 'GET',
        data: {
            csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
        },
        success: function(response) {
            console.log('Statuses loaded:', response);
            statuses = response.data || [];
            renderStatusSelect();
        },
        error: function(xhr, status, error) {
            console.error('Error loading statuses:', xhr, status, error);
        }
    });
}

// Load placeholders
function loadPlaceholders() {
    $.ajax({
        url: 'whatsapp_templates/get_placeholders',
        type: 'GET',
        data: {
            csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
        },
        success: function(response) {
            console.log('Placeholders loaded:', response);
            placeholders = response.data || [];
            renderPlaceholders();
        },
        error: function(xhr, status, error) {
            console.error('Error loading placeholders:', xhr, status, error);
        }
    });
}

// Render templates table
function renderTemplatesTable() {
    const tbody = $('#templates-table tbody');
    tbody.empty();
    
    if (templates.length === 0) {
        tbody.append(`
            <tr>
                <td colspan="6" class="text-center text-muted">
                    <i class="fas fa-inbox me-2"></i>
                    <?= lang('no_templates_found') ?>
                </td>
            </tr>
        `);
        return;
    }
    
    templates.forEach(template => {
        const row = `
            <tr>
                <td>${template.name}</td>
                <td><span class="badge bg-secondary">${template.status_key}</span></td>
                <td>${template.language || 'pt-BR'}</td>
                <td>
                    <div class="form-check form-switch">
                        <input class="form-check-input template-toggle" type="checkbox" 
                               data-id="${template.id}" ${template.enabled ? 'checked' : ''}>
                    </div>
                </td>
                <td>${template.created_at || '-'}</td>
                <td>
                    <div class="btn-group btn-group-sm">
                        <button class="btn btn-outline-primary edit-template" data-id="${template.id}">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-outline-info preview-template" data-id="${template.id}">
                            <i class="fas fa-eye"></i>
                        </button>
                        <button class="btn btn-outline-success duplicate-template" data-id="${template.id}">
                            <i class="fas fa-copy"></i>
                        </button>
                        <button class="btn btn-outline-danger delete-template" data-id="${template.id}">
                            <i class="fas fa-trash"></i>
                        </button>
                    </div>
                </td>
            </tr>
        `;
        tbody.append(row);
    });
    
    // Bind event handlers
    bindTableEvents();
}

// Bind table events
function bindTableEvents() {
    $('.template-toggle').on('change', function() {
        const id = $(this).data('id');
        const enabled = $(this).is(':checked');
        toggleTemplate(id, enabled);
    });
    
    $('.edit-template').on('click', function() {
        const id = $(this).data('id');
        editTemplate(id);
    });
    
    $('.preview-template').on('click', function() {
        const id = $(this).data('id');
        previewTemplateById(id);
    });
    
    $('.duplicate-template').on('click', function() {
        const id = $(this).data('id');
        duplicateTemplate(id);
    });
    
    $('.delete-template').on('click', function() {
        const id = $(this).data('id');
        deleteTemplate(id);
    });
}

// Render status select
function renderStatusSelect() {
    const select = $('#template-status-key');
    select.empty();
    select.append('<option value=""><?= lang('select_status') ?></option>');
    
    statuses.forEach(status => {
        select.append(`<option value="${status.key}">${status.label}</option>`);
    });
}

// Render placeholders
function renderPlaceholders() {
    const container = $('#placeholders-list');
    container.empty();
    
    placeholders.forEach(placeholder => {
        const badge = `<span class="badge bg-light text-dark me-1 mb-1" style="cursor: pointer;" 
                           onclick="insertPlaceholder('${placeholder.key}')">${placeholder.key}</span>`;
        container.append(badge);
    });
}

// Insert placeholder
function insertPlaceholder(placeholder) {
    const textarea = $('#template-body');
    const currentValue = textarea.val();
    const newValue = currentValue + '{{' + placeholder + '}}';
    textarea.val(newValue).focus();
}

// Open template modal
function openTemplateModal(template = null) {
    $('#template-modal-title').text(template ? '<?= lang('edit_template') ?>' : '<?= lang('create_template') ?>');
    $('#template-form')[0].reset();
    
    if (template) {
        $('#template-id').val(template.id);
        $('#template-name').val(template.name);
        $('#template-status-key').val(template.status_key);
        $('#template-language').val(template.language || 'pt-BR');
        $('#template-enabled').prop('checked', template.enabled);
        $('#template-body').val(template.body);
    }
    
    $('#template-modal').modal('show');
}

// Save template
function saveTemplate() {
    const formData = {
        id: $('#template-id').val(),
        name: $('#template-name').val(),
        status_key: $('#template-status-key').val(),
        language: $('#template-language').val(),
        enabled: $('#template-enabled').is(':checked'),
        body: $('#template-body').val(),
        csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
    };
    
    $.ajax({
        url: 'whatsapp_templates/save_template',
        type: 'POST',
        data: formData,
        success: function(response) {
            console.log('Template saved:', response);
            if (response.success) {
                alert('Template salvo com sucesso!');
                $('#template-modal').modal('hide');
                loadTemplates();
            } else {
                alert('Erro ao salvar template: ' + (response.message || 'Erro desconhecido'));
            }
        },
        error: function(xhr, status, error) {
            console.error('Error saving template:', xhr, status, error);
            alert('Erro ao salvar template: ' + error);
        }
    });
}

// Edit template
function editTemplate(id) {
    const template = templates.find(t => t.id == id);
    if (template) {
        openTemplateModal(template);
    }
}

// Toggle template
function toggleTemplate(id, enabled) {
    $.ajax({
        url: 'whatsapp_templates/toggle_template/' + id,
        type: 'PUT',
        data: {
            enabled: enabled,
            csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
        },
        success: function(response) {
            console.log('Template toggled:', response);
            if (!response.success) {
                alert('Erro ao alterar status do template: ' + (response.message || 'Erro desconhecido'));
                loadTemplates(); // Reload to reset state
            }
        },
        error: function(xhr, status, error) {
            console.error('Error toggling template:', xhr, status, error);
            alert('Erro ao alterar status do template: ' + error);
            loadTemplates(); // Reload to reset state
        }
    });
}

// Preview template
function previewTemplate() {
    const body = $('#template-body').val();
    if (!body.trim()) {
        alert('Digite o conteúdo do template para visualizar');
        return;
    }
    
    $.ajax({
        url: 'whatsapp_templates/get_preview',
        type: 'POST',
        data: {
            body: body,
            csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
        },
        success: function(response) {
            console.log('Preview generated:', response);
            if (response.success) {
                $('#preview-content').html(response.data.preview);
                $('#preview-modal').modal('show');
            } else {
                alert('Erro ao gerar preview: ' + (response.message || 'Erro desconhecido'));
            }
        },
        error: function(xhr, status, error) {
            console.error('Error generating preview:', xhr, status, error);
            alert('Erro ao gerar preview: ' + error);
        }
    });
}

// Preview template by ID
function previewTemplateById(id) {
    const template = templates.find(t => t.id == id);
    if (template) {
        $('#preview-content').html(template.body);
        $('#preview-modal').modal('show');
    }
}

// Duplicate template
function duplicateTemplate(id) {
    if (confirm('Deseja duplicar este template?')) {
        $.ajax({
            url: 'whatsapp_templates/duplicate_template/' + id,
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Template duplicated:', response);
                if (response.success) {
                    alert('Template duplicado com sucesso!');
                    loadTemplates();
                } else {
                    alert('Erro ao duplicar template: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Error duplicating template:', xhr, status, error);
                alert('Erro ao duplicar template: ' + error);
            }
        });
    }
}

// Delete template
function deleteTemplate(id) {
    if (confirm('Tem certeza que deseja excluir este template?')) {
        $.ajax({
            url: 'whatsapp_templates/delete_template/' + id,
            type: 'DELETE',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Template deleted:', response);
                if (response.success) {
                    alert('Template excluído com sucesso!');
                    loadTemplates();
                } else {
                    alert('Erro ao excluir template: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Error deleting template:', xhr, status, error);
                alert('Erro ao excluir template: ' + error);
            }
        });
    }
}


</script>

<?php end_section('content'); ?>
