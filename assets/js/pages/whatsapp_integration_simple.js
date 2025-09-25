/* ----------------------------------------------------------------------------
 * Easy!Appointments - WhatsApp Integration (Simplified)
 * ---------------------------------------------------------------------------- */

$(document).ready(function() {
    console.log('WhatsApp Integration: Simple version loading...');

    // Storage keys
    const STORAGE_KEYS = {
    	HOST: 'whatsapp_host',
    	PORT: 'whatsapp_port',
    	SESSION: 'whatsapp_session',
    	// Do NOT persist secret key or any token in localStorage for security
    	SECRET_KEY: 'whatsapp_secret_key'
    };

    // Initialize settings from localStorage
    function initializeSettings() {
        console.log('Initializing settings from localStorage...');
        
        // Restore form values from localStorage
        const host = localStorage.getItem(STORAGE_KEYS.HOST);
        const port = localStorage.getItem(STORAGE_KEYS.PORT);
        const session = localStorage.getItem(STORAGE_KEYS.SESSION);
        const secretKey = null; // Do not load secret from localStorage
        const tokenMasked = null;

        if (host) $('#whatsapp-host').val(host);
        if (port) $('#whatsapp-port').val(port);
        if (session) $('#whatsapp-session').val(session);
        // Never prefill secret key from storage for security
        // Ensure token input is blank on load
        $('#whatsapp-token').val('');

        // Remove any legacy token values from localStorage
        try {
            localStorage.removeItem('whatsapp_token');
            localStorage.removeItem('whatsapp_token_masked');
            // Purge any previously stored secret key
            localStorage.removeItem('whatsapp_secret_key');
        } catch (e) {
            // ignore
        }

        console.log('Settings restored from localStorage');
        // Hide spinner by default; status is checked only via Test Connectivity
        try { $('#session-status').find('.spinner-border').hide(); } catch (e) {}
        
        // Load statistics only
        loadStatistics();
    }

    // Update session status in UI
    function updateSessionStatus(statusData) {
        const $statusElement = $('#session-status');
        const $statusText = $('#session-status-text');
        const $statusBadge = $statusElement.find('.badge');

        // We'll display only the badge label to the user. The additional text is hidden to avoid duplicate info.
        $statusText.hide();

        if (statusData && statusData.status) {
            const status = statusData.status.toUpperCase();
            let label = '';

            switch(status) {
                case 'CONNECTED':
                    label = 'Conectado';
                    $statusBadge.removeClass().addClass('badge bg-success');
                    break;
                case 'QRCODE':
                    label = 'Aguardando QR Code';
                    $statusBadge.removeClass().addClass('badge bg-warning');
                    break;
                case 'PAIRING':
                    label = 'Pareando';
                    $statusBadge.removeClass().addClass('badge bg-info');
                    break;
                case 'INITIALIZING':
                    label = 'Inicializando';
                    $statusBadge.removeClass().addClass('badge bg-info');
                    break;
                case 'DISCONNECTED':
                case 'CLOSED':
                    label = 'Desconectado';
                    $statusBadge.removeClass().addClass('badge bg-danger');
                    break;
                case 'ERROR':
                    label = 'Erro';
                    $statusBadge.removeClass().addClass('badge bg-danger');
                    break;
                default:
                    label = 'Desconhecido';
                    $statusBadge.removeClass().addClass('badge bg-secondary');
            }

            $statusBadge.text(label);
            $statusElement.find('.spinner-border').hide();

            // Update button states based on status
            updateButtonStates(status);
        } else {
            $statusBadge.text('Desconhecido');
            $statusBadge.removeClass().addClass('badge bg-secondary');
            $statusElement.find('.spinner-border').hide();
        }
    }

    // Update button states based on session status
    function updateButtonStates(status) {
        const $startBtn = $('#start-session-btn');
        const $closeBtn = $('#close-session-btn');
        const $logoutBtn = $('#logout-session-btn');
        
        // Reset all buttons - remove all button color classes
        $startBtn.prop('disabled', false).removeClass('btn-success btn-danger btn-warning');
        $closeBtn.prop('disabled', false).removeClass('btn-success btn-danger btn-warning');
        $logoutBtn.prop('disabled', false).removeClass('btn-success btn-danger btn-warning');
        
        switch(status) {
            case 'CONNECTED':
                $startBtn.prop('disabled', true).addClass('btn-success');
                $closeBtn.prop('disabled', false).addClass('btn-warning');
                $logoutBtn.prop('disabled', false).addClass('btn-danger');
                break;
            case 'QRCODE':
            case 'PAIRING':
                $startBtn.prop('disabled', true);
                $closeBtn.prop('disabled', false).addClass('btn-warning');
                $logoutBtn.prop('disabled', false).addClass('btn-danger');
                break;
            case 'DISCONNECTED':
            case 'CLOSED':
            case 'ERROR':
                $startBtn.prop('disabled', false).addClass('btn-success');
                $closeBtn.prop('disabled', true).addClass('btn-warning');
                $logoutBtn.prop('disabled', true).addClass('btn-danger');
                break;
        }
    }

    // Save settings to localStorage
    function saveSettingsToStorage(settings) {
        console.log('Saving settings to localStorage (without secret key)...');
        
        settings.forEach(setting => {
            switch(setting.name) {
                case 'host':
                    localStorage.setItem(STORAGE_KEYS.HOST, setting.value);
                    break;
                case 'port':
                    localStorage.setItem(STORAGE_KEYS.PORT, setting.value);
                    break;
                case 'session':
                    localStorage.setItem(STORAGE_KEYS.SESSION, setting.value);
                    break;
            }
        });
        
        console.log('Settings saved to localStorage');
    }

    // Token MUST NOT be persisted client-side. No-op helper kept for compatibility.
    function saveTokenToStorage(/* token, tokenMasked */) {
        // Intentionally empty
    }

    // Internationalization strings provided by server
    const I18N = (typeof vars === 'function' && vars('i18n')) || {};

    // Initialize settings on page load
    initializeSettings();

	// Use initial status from server (script_vars) to set buttons immediately
	try {
		const initStatus = (typeof vars === 'function' && vars('initial_session_status')) || null;
		if (initStatus) {
			updateButtonStates(String(initStatus).toUpperCase());
		}
	} catch (e) {}

	// Single background status check after page load to confirm
	try { fetchStatusAndUpdateButtons(); } catch (e) {}

    // Background watcher (silent) to keep buttons in correct state
    let statusWatcherInterval = null;
    function fetchStatusAndUpdateButtons() {
		$.ajax({
            url: 'whatsapp_integration/get_status',
            type: 'GET',
			data: { csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '') },
			global: false,
            success: function(resp) {
                const st = (resp && (resp.data?.status || resp.status)) ? (resp.data?.status || resp.status) : '';
                if (st) updateButtonStates(st.toUpperCase());
            }
        });
    }
    function startStatusWatcher() {
        if (statusWatcherInterval) return;
        fetchStatusAndUpdateButtons();
        statusWatcherInterval = setInterval(fetchStatusAndUpdateButtons, 5000);
    }
    function stopStatusWatcher() {
        if (statusWatcherInterval) {
            clearInterval(statusWatcherInterval);
            statusWatcherInterval = null;
        }
    }

    // Show settings error inline in the Settings card
    function showSettingsError(message, details) {
        const $cardBody = $('#whatsapp-settings-form').closest('.card-body');
        clearSettingsError();
        clearFieldHighlights();

        let html = '<div id="settings-error" class="alert alert-danger" role="alert">';
        html += '<strong>Erro:</strong> ' + (message || 'Erro ao salvar configurações') + '<br/>';
        if (details) {
            try {
                if (typeof details === 'object') {
                    html += '<pre class="small mb-0">' + JSON.stringify(details, null, 2) + '</pre>';
                } else {
                    html += '<div class="small mb-0">' + details + '</div>';
                }
            } catch (e) {
                html += '<div class="small mb-0">' + String(details) + '</div>';
            }
        }
        html += '</div>';

        $cardBody.prepend(html);
        // Scroll to error for visibility
        const el = document.getElementById('settings-error');
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });

        // Highlight fields based on details
        highlightSettingsFields(details);
    }

    function clearSettingsError() {
        $('#settings-error').remove();
    }

    // Highlight specific form fields with validation/connectivity errors
    function highlightSettingsFields(details) {
        clearFieldHighlights();
        if (!details) return;

        // If details is an object, inspect known keys
        try {
            // If base_url present, mark host/port
            if (details.base_url) {
                // Attempt to parse host and port
                try {
                    const url = new URL(details.base_url.includes('://') ? details.base_url : 'http://' + details.base_url);
                    const host = url.hostname || '';
                    const port = url.port || '';
                    if (host) setFieldError('#whatsapp-host', (I18N.invalid_host || 'Host/URL inválido ou inacessível') + ': ' + host);
                    if (port) setFieldError('#whatsapp-port', (I18N.invalid_host || 'Host/URL inválido ou inacessível') + ': ' + port);
                } catch (e) {
                    // Fallback: mark host field generically
                    setFieldError('#whatsapp-host', I18N.invalid_host || 'Host/URL inválido ou inacessível');
                }
            }

            if (details.step) {
                switch (details.step) {
                    case 'missing_secret_key':
                        setFieldError('#whatsapp-secret-key', I18N.secret_key_required || 'Chave secreta obrigatória para gerar token');
                        break;
                    case 'token_generation_failed':
                    case 'token_generated':
                    case 'token_generation':
                        // likely secret_key or session issue
                        setFieldError('#whatsapp-secret-key', I18N.token_generation_failed || 'Falha na geração do token. Verifique chave secreta e sessão.');
                        setFieldError('#whatsapp-session', I18N.invalid_host || 'Verifique o nome da sessão');
                        break;
                    case 'status_check_failed':
                        setFieldError('#whatsapp-host', I18N.connectivity_failed || 'Falha ao verificar status da sessão. Host/porta/sessão podem estar incorretos');
                        break;
                }
            }

            // If details contain error strings, search for keywords
            if (typeof details === 'string') {
                const txt = details.toLowerCase();
                if (txt.includes('connection refused') || txt.includes('could not resolve') || txt.includes('timed out')) {
                    setFieldError('#whatsapp-host', I18N.invalid_host || 'Host inacessível (connection refused / timeout)');
                }
            } else if (typeof details === 'object') {
                const flat = JSON.stringify(details).toLowerCase();
                if (flat.includes('connection refused') || flat.includes('timeout') || flat.includes('could not resolve')) {
                    setFieldError('#whatsapp-host', I18N.invalid_host || 'Host inacessível (connection refused / timeout)');
                }
            }
        } catch (e) {
            console.error('Error highlighting settings fields:', e);
        }
    }

    function clearFieldHighlights() {
        ['#whatsapp-host','#whatsapp-port','#whatsapp-session','#whatsapp-secret-key'].forEach(function(sel){
            const $el = $(sel);
            $el.removeClass('is-invalid');
            $el.next('.invalid-feedback').remove();
        });
    }

    function setFieldError(selector, msg) {
        const $el = $(selector);
        if ($el.length === 0) return;
        $el.addClass('is-invalid');
        // avoid duplicate messages
        if ($el.next('.invalid-feedback').length === 0) {
            $el.after('<div class="invalid-feedback">' + msg + '</div>');
        }
    }

    // Save Settings
    $('#save-settings').on('click', function() {
        console.log('Save settings clicked');
        
        const $btn = $(this);
        $btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>Salvando...');
        
        const settings = [];
        
        // Collect form data
        $('[data-field]').each(function() {
            const $field = $(this);
            const name = $field.data('field');
            let value;
            
            if ($field.is(':checkbox')) {
                value = $field.prop('checked') ? 1 : 0;
            } else {
                value = $field.val();
            }
            
            settings.push({
                name: name,
                value: value
            });
        });
        
        // Redact secret key from logs
        try {
            const redacted = settings.map(function(s){
                return s && s.name === 'secret_key' ? { name: s.name, value: '[REDACTED]' } : s;
            });
            console.log('Settings to save:', redacted);
        } catch (e) { console.log('Settings to save: [REDACTED]'); }
        
        // Save to localStorage first
        saveSettingsToStorage(settings);
        
        // Send via AJAX
        $.ajax({
            url: 'whatsapp_integration/save',
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : ''),
                whatsapp_settings: settings
            },
            success: function(response) {
                console.log('Save success:', response);
                
                let message = response.message || 'Configurações salvas com sucesso!';
                
                if (response.token_generated) {
                    message += '\n\n✓ Token gerado automaticamente!';
                } else if (response.token_message) {
                    message += '\n\n⚠ ' + response.token_message;
                }
                
                // Do NOT update token input from server responses. Token must not be sent to client.
                $('#whatsapp-token').val('');
                
                // Clear any previous settings errors and highlights
                clearSettingsError();
                clearFieldHighlights();

                // If server returned saved settings, update inputs to reflect canonical values
                if (response.saved_settings) {
                    const ss = response.saved_settings;
                    if (ss.host !== undefined) $('#whatsapp-host').val(ss.host);
                    if (ss.port !== undefined) $('#whatsapp-port').val(ss.port);
                    if (ss.session !== undefined) $('#whatsapp-session').val(ss.session);
                }

                // Single status check after successful save
                try { loadStatistics(); } catch (e) { console.warn('loadStatistics failed', e); }

                // Show a user-friendly message
                if (typeof toastr !== 'undefined') {
                    toastr.success(message);
                } else {
                    alert(message);
                }
            },
            error: function(xhr, status, error) {
                console.error('Save error:', xhr, status, error);
                let errorMsg = 'Erro ao salvar: ' + error;

                if (xhr.responseJSON && xhr.responseJSON.message) {
                    errorMsg = xhr.responseJSON.message;
                }

                // If server returned details (e.g., connectivity failure), show inline in the settings card
                const details = xhr.responseJSON && xhr.responseJSON.details ? xhr.responseJSON.details : null;
                showSettingsError(errorMsg, details);
            },
            complete: function() {
                $btn.prop('disabled', false).html('<i class="fas fa-save me-2"></i>Salvar Configurações');
            }
        });
    });

    // Test Connectivity
    $('#test-connectivity-btn').on('click', function() {
        console.log('Test connectivity clicked');
        
        const $btn = $(this);
        $btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>Testando...');
        
		$.ajax({
            url: 'whatsapp_integration/test_connectivity',
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
			},
			global: false,
            success: function(response) {
                console.log('Test connectivity success:', response);
                // If status info present, update badge once
                try {
                    const status = response?.details?.session_status || response?.details?.status_check?.status || null;
                    if (status) {
                        updateSessionStatus({ status: status });
                    }
                } catch (e) {}
                if (response.success) {
					if (typeof toastr !== 'undefined') toastr.success('Conectividade testada com sucesso!');
					else alert('Conectividade testada com sucesso!');
                } else {
					if (typeof toastr !== 'undefined') toastr.error('Erro na conectividade: ' + (response.message || 'Erro desconhecido'));
					else alert('Erro na conectividade: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Test connectivity error:', xhr, status, error);
				if (typeof toastr !== 'undefined') toastr.error('Erro ao testar conectividade: ' + error);
				else alert('Erro ao testar conectividade: ' + error);
            },
            complete: function() {
                $btn.prop('disabled', false).html('<i class="fas fa-network-wired me-2"></i>Testar Conectividade');
            }
        });
    });

    // Secret key visibility toggle
    $('#toggle-secret-key').on('click', function() {
        const $secretInput = $('#whatsapp-secret-key');
        const $eyeIcon = $(this).find('i');
        
        if ($secretInput.attr('type') === 'password') {
            $secretInput.attr('type', 'text');
            $eyeIcon.removeClass('fa-eye').addClass('fa-eye-slash');
            $(this).attr('title', 'Ocultar chave secreta');
        } else {
            $secretInput.attr('type', 'password');
            $eyeIcon.removeClass('fa-eye-slash').addClass('fa-eye');
            $(this).attr('title', 'Mostrar chave secreta');
        }
    });

    // Token reveal/copy are intentionally disabled on the frontend for security reasons.
    // All token access must go through server-protected audit endpoints and should not be invoked from client-side UI.

    // Token rotation UI removed: rotation is still available via admin API but not exposed in the frontend.

    // Session control buttons
    $('#start-session-btn').on('click', function() {
        console.log('Start session clicked');
        
        const $btn = $(this);
        $btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>Iniciando...');
        
		$.ajax({
            url: 'whatsapp_integration/start_session',
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
			},
			global: false,
            success: function(response) {
                console.log('Start session success:', response);
                if (response.success) {
					if (typeof toastr !== 'undefined') toastr.success('Sessão iniciada com sucesso!');
					else alert('Sessão iniciada com sucesso!');
                    startStatusWatcher();
                } else {
					if (typeof toastr !== 'undefined') toastr.error('Erro ao iniciar sessão: ' + (response.message || 'Erro desconhecido'));
					else alert('Erro ao iniciar sessão: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Start session error:', xhr, status, error);
				if (typeof toastr !== 'undefined') toastr.error('Erro ao iniciar sessão: ' + error);
				else alert('Erro ao iniciar sessão: ' + error);
            },
            complete: function() {
                $btn.prop('disabled', false).html('<i class="fas fa-play me-2"></i>Iniciar Sessão');
            }
        });
    });

    $('#close-session-btn').on('click', function() {
        console.log('Close session clicked');
        
        const $btn = $(this);
        $btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>Fechando...');
        
	$.ajax({
            url: 'whatsapp_integration/close_session',
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
			},
			global: false,
            success: function(response) {
                console.log('Close session success:', response);
                if (response.success) {
					if (typeof toastr !== 'undefined') toastr.success('Sessão fechada com sucesso!');
					else alert('Sessão fechada com sucesso!');
                    // Single status refresh after close
                    updateSessionStatus({ status: 'DISCONNECTED' });
                    startStatusWatcher();
                } else {
					if (typeof toastr !== 'undefined') toastr.error('Erro ao fechar sessão: ' + (response.message || 'Erro desconhecido'));
					else alert('Erro ao fechar sessão: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Close session error:', xhr, status, error);
				if (typeof toastr !== 'undefined') toastr.error('Erro ao fechar sessão: ' + error);
				else alert('Erro ao fechar sessão: ' + error);
            },
            complete: function() {
                $btn.prop('disabled', false).html('<i class="fas fa-pause me-2"></i>Fechar Sessão');
            }
        });
    });

    $('#logout-session-btn').on('click', function() {
        console.log('Logout session clicked');
        
        const $btn = $(this);
        $btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>Desconectando...');
        
	$.ajax({
            url: 'whatsapp_integration/logout_session',
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
			},
			global: false,
            success: function(response) {
                console.log('Logout session success:', response);
                if (response.success) {
					if (typeof toastr !== 'undefined') toastr.success('Sessão desconectada com sucesso!');
					else alert('Sessão desconectada com sucesso!');
                    // Single status refresh after logout
                    updateSessionStatus({ status: 'DISCONNECTED' });
                    startStatusWatcher();
                } else {
					if (typeof toastr !== 'undefined') toastr.error('Erro ao desconectar sessão: ' + (response.message || 'Erro desconhecido'));
					else alert('Erro ao desconectar sessão: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Logout session error:', xhr, status, error);
				if (typeof toastr !== 'undefined') toastr.error('Erro ao desconectar sessão: ' + error);
				else alert('Erro ao desconectar sessão: ' + error);
            },
            complete: function() {
                $btn.prop('disabled', false).html('<i class="fas fa-sign-out-alt me-2"></i>Desconectar Sessão');
            }
        });
    });

    // Manual refresh removed; Test Connectivity covers on-demand status

    // Show QR Code
    $('#show-qr-btn').on('click', function() {
        console.log('Show QR clicked');
        
        const $btn = $(this);
        $btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>Carregando...');
        
	$.ajax({
            url: 'whatsapp_integration/start_session',
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
			},
			global: false,
            success: function(response) {
                console.log('Start session success:', response);
                if (response.success && response.data && response.data.qrcode) {
                    showQrModal(response.data.qrcode);
                } else {
					if (typeof toastr !== 'undefined') toastr.error('QR Code não disponível: ' + (response.message || 'Erro desconhecido'));
					else alert('QR Code não disponível: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Show QR error:', xhr, status, error);
				if (typeof toastr !== 'undefined') toastr.error('Erro ao obter QR Code: ' + error);
				else alert('Erro ao obter QR Code: ' + error);
            },
            complete: function() {
                $btn.prop('disabled', false).html('<i class="fas fa-qrcode me-2"></i>Mostrar QR Code');
            }
        });
    });

    // QR Code Modal
    function showQrModal(qrcode) {
        const modalHtml = `
            <div class="modal fade" id="qrModal" tabindex="-1">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">QR Code WhatsApp</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body text-center">
                            <p>Escaneie o QR Code com seu WhatsApp:</p>
                            <img src="${qrcode}" class="img-fluid" alt="QR Code">
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Fechar</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        // Remove existing modal if any
        $('#qrModal').remove();
        
        // Add new modal
        $('body').append(modalHtml);
        
        // Show modal
        $('#qrModal').modal('show');
    }

    // Tab functionality
    function initializeTabs() {
        console.log('Initializing tab functionality...');
        
        // Templates tab functionality
        $('#templates-tab').on('click', function() {
            loadTemplates();
        });
        
        // Logs tab functionality
        $('#logs-tab').on('click', function() {
            loadLogs();
        });
        
        // Routines tab functionality
        $('#routines-tab').on('click', function() {
            loadRoutines();
        });
        
        // If routines tab is active on load, populate it
        if ($('#routines-tab').hasClass('active')) {
            loadRoutines();
        }
        
        // Persist active tab across page refreshes using localStorage
        try {
            const TAB_STORAGE_KEY = 'whatsapp_active_tab';

            // Store shown tab id when user switches tabs (works for <a> and <button> elements)
            $('[data-bs-toggle="tab"]').on('shown.bs.tab', function(e) {
                try {
                    const id = $(e.target).attr('id');
                    if (id) localStorage.setItem(TAB_STORAGE_KEY, id);

                    // When a tab becomes visible, trigger its loader so content is populated
                    switch (id) {
                        case 'templates-tab':
                            loadTemplates();
                            break;
                        case 'routines-tab':
                            loadRoutines();
                            break;
                        case 'logs-tab':
                            loadLogs();
                            break;
                        case 'test-tab':
                            try { initializeTestTab(); } catch (e) {}
                            break;
                        case 'config-tab':
                            // only refresh statistics automatically; status is event-driven
                            try { loadStatistics(); } catch (e) {}
                            break;
                    }
                } catch (err) {
                    // ignore
                }
            });

            // On load, restore previously active tab if present
            const savedTab = localStorage.getItem(TAB_STORAGE_KEY);
            if (savedTab) {
                const el = document.getElementById(savedTab);
                if (el) {
                    try {
                        const tab = new bootstrap.Tab(el);
                        tab.show();
                    } catch (err) {
                        // fallback: trigger click
                        $(el).trigger('click');
                    }
                }
            }
        } catch (e) {
            console.warn('Could not persist tab state', e);
        }
        
        // Template actions
        $('#create-template-btn').on('click', function() {
            openTemplateModal();
        });
        
        
        $('#refresh-templates-btn').on('click', function() {
            loadTemplates();
        });
        
        // Log actions
        $('#refresh-logs-btn').on('click', function() {
            loadLogs();
        });
        
        $('#log-filter-status').on('change', function() {
            loadLogs();
        });
        
        $('#clear-logs-btn').on('click', function() {
            clearLogs();
        });
    }
    
    // Global templates array
    let templates = [];
    
    // Load templates
    function loadTemplates() {
        console.log('Loading templates...');
        
        $.ajax({
            url: typeof App !== 'undefined' && App.Utils && App.Utils.Url ? App.Utils.Url.siteUrl('whatsapp_templates/get_templates') : 'whatsapp_templates/get_templates',
            type: 'GET',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Templates loaded:', response);
                templates = response.data || [];
                renderTemplatesTable(templates);
            },
            error: function(xhr, status, error) {
                console.error('Error loading templates:', xhr, status, error);
                $('#templates-table tbody').html('<tr><td colspan="5" class="text-center text-muted">Erro ao carregar templates</td></tr>');
            }
        });
    }
    
    // Render templates table
    function renderTemplatesTable(templates) {
        const tbody = $('#templates-table tbody');
        tbody.empty();
        
        if (templates.length === 0) {
            tbody.append('<tr><td colspan="5" class="text-center text-muted">Nenhum template encontrado</td></tr>');
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
                    <td>
                        <div class="btn-group btn-group-sm">
                            <button class="btn btn-outline-primary edit-template" data-id="${template.id}">
                                <i class="fas fa-edit"></i>
                            </button>
                            <button class="btn btn-outline-info preview-template" data-id="${template.id}">
                                <i class="fas fa-eye"></i>
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
        
        // Bind template actions
        bindTemplateActions();
    }
    
    // Bind template actions
    function bindTemplateActions() {
        $('.template-toggle').on('change', function() {
            const id = $(this).data('id');
            const enabled = $(this).is(':checked');
            toggleTemplate(id, enabled);
        });
        
        $('.edit-template').on('click', function() {
            const id = $(this).data('id');
            const template = templates.find(t => t.id == id);
            if (template) {
                openTemplateModal(template);
            }
        });
        
        $('.preview-template').on('click', function() {
            const id = $(this).data('id');
            // Implement preview functionality
            alert('Preview functionality - Template ID: ' + id);
        });
        
        $('.delete-template').on('click', function() {
            const id = $(this).data('id');
            if (confirm('Tem certeza que deseja excluir este template?')) {
                deleteTemplate(id);
            }
        });
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
    
    // Delete template
    function deleteTemplate(id) {
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
    
    
    // Load logs
    function loadLogs() {
        console.log('Loading logs...');
        
        const filterStatus = $('#log-filter-status').val();
        
        $.ajax({
            url: 'whatsapp_integration/get_logs',
            type: 'GET',
            data: {
                status: filterStatus,
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Logs loaded:', response);
                if (response.success && response.data) {
                    renderLogsTable(response.data.data || []);
                    // Update statistics after loading logs
                    loadStatistics();
                } else {
                    $('#logs-table tbody').html('<tr><td colspan="5" class="text-center text-muted">Erro ao carregar logs</td></tr>');
                }
            },
            error: function(xhr, status, error) {
                console.error('Error loading logs:', xhr, status, error);
                $('#logs-table tbody').html('<tr><td colspan="5" class="text-center text-muted">Erro ao carregar logs</td></tr>');
            }
        });
    }
    
    // Render logs table
    function renderLogsTable(logs) {
        const tbody = $('#logs-table tbody');
        tbody.empty();

        // Normalize input: accept array or object with various shapes
        if (!Array.isArray(logs)) {
            // Common shape: { data: { data: [...] } } or { data: [...] }
            if (logs && Array.isArray(logs.data)) {
                logs = logs.data;
            } else if (logs && logs.data && Array.isArray(logs.data.data)) {
                logs = logs.data.data;
            } else if (logs && logs.data && typeof logs.data === 'object') {
                // data may be an object with numeric keys: convert to array
                const vals = Object.values(logs.data);
                if (Array.isArray(vals) && vals.length > 0 && typeof vals[0] === 'object') {
                    logs = vals;
                }
            } else if (logs && typeof logs === 'object') {
                // Try to find the first array property inside the object
                const arrayProp = Object.keys(logs).find(k => Array.isArray(logs[k]));
                if (arrayProp) {
                    logs = logs[arrayProp];
                }
            }

            // After attempts, if still not array -> bail out
            if (!Array.isArray(logs)) {
                tbody.append('<tr><td colspan="5" class="text-center text-muted">Nenhum log encontrado</td></tr>');
                return;
            }
        }

        if (logs.length === 0) {
            tbody.append('<tr><td colspan="5" class="text-center text-muted">Nenhum log encontrado</td></tr>');
            return;
        }
        
        logs.forEach(log => {
            const statusClass = log.result === 'SUCCESS' ? 'text-success' : 
                               log.result === 'PENDING' ? 'text-warning' : 'text-danger';
            const statusIcon = log.result === 'SUCCESS' ? 'fa-check-circle' : 
                              log.result === 'PENDING' ? 'fa-clock' : 'fa-times-circle';
            
            const row = `
                <tr>
                    <td>${log.create_datetime || '-'}</td>
                    <td>${log.to_phone || '-'}</td>
                    <td>${log.status_key || '-'}</td>
                    <td><i class="fas ${statusIcon} ${statusClass}"></i> ${log.result || '-'}</td>
                    <td>
                        <button class="btn btn-outline-info btn-sm view-log-details" data-id="${log.id}">
                            <i class="fas fa-eye"></i>
                        </button>
                    </td>
                </tr>
            `;
            tbody.append(row);
        });
        
        // Bind log actions
        $('.view-log-details').on('click', function() {
            const id = $(this).data('id');
            viewLogDetails(id);
        });
    }
    
    // View log details
    function viewLogDetails(id) {
        // Implement log details view
        alert('Log details functionality - Log ID: ' + id);
    }
    
    // Clear logs
    function clearLogs() {
        if (!confirm('Tem certeza que deseja limpar todos os logs? Esta ação não pode ser desfeita.')) {
            return;
        }
        
        $.ajax({
            url: 'whatsapp_integration/clear_logs',
            type: 'POST',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                if (response.success) {
                    alert('Logs limpos com sucesso! ' + response.deleted_count + ' registros removidos.');
                    loadLogs();
                    loadStatistics(); // Refresh statistics after clearing logs
                } else {
                    alert('Erro ao limpar logs: ' + (response.message || 'Erro desconhecido'));
                }
            },
            error: function(xhr, status, error) {
                console.error('Error clearing logs:', xhr, status, error);
                alert('Erro ao limpar logs. Verifique o console para mais detalhes.');
            }
        });
    }
    
    // Load statistics
    function loadStatistics() {
        console.log('Loading statistics...');
        
        $.ajax({
            url: 'whatsapp_integration/get_statistics',
            type: 'GET',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Statistics loaded:', response);
                if (response.success && response.data) {
                    updateStatisticsDisplay(response.data);
                }
            },
            error: function(xhr, status, error) {
                console.error('Error loading statistics:', xhr, status, error);
            }
        });
    }
    
    // Update statistics display
    function updateStatisticsDisplay(stats) {
        // Update template count
        if (stats.templates !== undefined) {
            $('#stat-templates').text(stats.templates);
        }
        
        // Update message counts
        if (stats.messages) {
            $('#stat-sent').text(stats.messages.SUCCESS || 0);
            $('#stat-failed').text(stats.messages.FAILURE || 0);
        }
        
        // Recent logs removed from dashboard; no update required
    }

    // Template modal functions
    function openTemplateModal(template = null) {
        $('#template-modal-title').text(template ? 'Editar Template' : 'Criar Template');
        $('#template-form')[0].reset();

        if (template) {
            $('#template-id').val(template.id);
            $('#template-name').val(template.name);
            // Do not set status here synchronously; we'll pass it to loadStatuses so it remains selected
            $('#template-language').val(template.language || 'pt-BR');
            $('#template-enabled').prop('checked', template.enabled);
            $('#template-body').val(template.body);
        }

        // Load statuses (pass selected status so select keeps value) and placeholders
        loadStatuses(template ? template.status_key : null);
        loadPlaceholders();

        $('#template-modal').modal('show');
    }
    
    // Load statuses for template modal
    function loadStatuses(selectedStatus = null) {
        return $.ajax({
            url: 'whatsapp_templates/get_statuses',
            type: 'GET',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Statuses loaded:', response);
                renderStatusSelect(response.data || [], selectedStatus);
            },
            error: function(xhr, status, error) {
                console.error('Error loading statuses:', xhr, status, error);
            }
        });
    }
    
    // Render status select
    function renderStatusSelect(statuses, selectedStatus = null) {
        const select = $('#template-status-key');
        select.empty();
        select.append('<option value="">Selecionar Status</option>');

        statuses.forEach(status => {
            const option = $(`<option value="${status.key}">${status.label}</option>`);
            select.append(option);
        });

        // If a selected status value was provided, set it after options are populated
        if (selectedStatus) {
            try {
                select.val(selectedStatus);
            } catch (e) {
                console.warn('Could not set selected status', e);
            }
        }
    }
    
    // Load variables
    function loadVariables() {
        $.ajax({
            url: 'whatsapp_templates/get_variables',
            type: 'GET',
            data: {
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Variables loaded:', response);
                renderVariables(response.data || []);
            },
            error: function(xhr, status, error) {
                console.error('Error loading variables:', xhr, status, error);
            }
        });
    }
    
    // Load placeholders (legacy compatibility)
    function loadPlaceholders() {
        loadVariables();
    }
    
    // Render variables
    function renderVariables(variables) {
        const container = $('#placeholders-list');
        container.empty();
        
        variables.forEach(variable => {
            const badge = `<span class="badge bg-light text-dark me-1 mb-1" style="cursor: pointer;" 
                               onclick="insertVariable('${variable.key}')" 
                               title="${variable.description || variable.key} - Exemplo: ${variable.example || 'N/A'}">${variable.display || variable.key}</span>`;
            container.append(badge);
        });
    }
    
    // Render placeholders (legacy compatibility)
    function renderPlaceholders(placeholders) {
        renderVariables(placeholders);
    }
    
    // Insert variable
    function insertVariable(variable) {
        const textarea = $('#template-body');
        const currentValue = textarea.val();
        const cursorPos = textarea.prop('selectionStart');
        const newValue = currentValue.substring(0, cursorPos) + 
                        '{{' + variable + '}}' + 
                        currentValue.substring(cursorPos);
        textarea.val(newValue);
        textarea.focus();
    }
    
    // Insert placeholder (legacy compatibility)
    function insertPlaceholder(placeholder) {
        insertVariable(placeholder);
    }
    
    // Save template
    function saveTemplate() {
        const formData = {
            id: $('#template-id').val(),
            name: $('#template-name').val(),
            status_key: $('#template-status-key').val(),
            language: $('#template-language').val(),
            // send enabled as integer to match server expectations
            enabled: $('#template-enabled').is(':checked') ? 1 : 0,
            body: $('#template-body').val(),
            csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
        };
        
        // Validate required fields
        if (!formData.name || !formData.status_key || !formData.body) {
            alert('Por favor, preencha todos os campos obrigatórios.');
            return;
        }
        
        $.ajax({
            url: 'whatsapp_templates/save_template',
            type: 'POST',
            data: formData,
            success: function(response) {
                console.log('Template saved:', response);
                if (response.success) {
                    // Show success message
                    if (typeof toastr !== 'undefined') {
                        toastr.success(response.message || 'Template salvo com sucesso!');
                    } else {
                        alert(response.message || 'Template salvo com sucesso!');
                    }

                    $('#template-modal').modal('hide');

                    // Reload templates list
                    loadTemplates();

                    // Add new template to global templates array if it's a new template
                    if (response.data && !formData.id) {
                        templates.unshift(response.data);
                    }
                } else {
                    // server returned success=false (should be rare); surface message and errors
                    let msg = response.message || 'Erro ao salvar template';
                    if (response.errors) {
                        if (Array.isArray(response.errors)) {
                            msg += ': ' + response.errors.join(', ');
                        } else if (typeof response.errors === 'object') {
                            const parts = [];
                            for (const k in response.errors) {
                                parts.push(k + ': ' + response.errors[k]);
                            }
                            msg += ': ' + parts.join('; ');
                        }
                    }
                    alert(msg);
                }
            },
            error: function(xhr, status, error) {
                console.error('Error saving template:', xhr, status, error);
                // If validation errors returned (400), show them
                let errorMessage = xhr.responseJSON?.message || error;
                if (xhr.responseJSON?.errors) {
                    const errs = xhr.responseJSON.errors;
                    if (Array.isArray(errs)) {
                        errorMessage += ': ' + errs.join(', ');
                    } else if (typeof errs === 'object') {
                        const parts = [];
                        for (const k in errs) {
                            parts.push(k + ': ' + (errs[k].join ? errs[k].join(', ') : errs[k]));
                        }
                        errorMessage += ': ' + parts.join('; ');
                    }
                }
                alert('Erro ao salvar template: ' + errorMessage);
            }
        });
    }
    
    // Preview template
    function previewTemplate() {
        const body = $('#template-body').val();
        const language = $('#template-language').val() || 'pt-BR';
        
        if (!body.trim()) {
            alert('Digite o conteúdo do template para visualizar');
            return;
        }
        
        $.ajax({
            url: 'whatsapp_templates/get_preview',
            type: 'POST',
            data: {
                body: body,
                locale: language,
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                console.log('Preview generated:', response);
                if (response.success) {
                    $('#preview-content').html(response.data.preview.replace(/\n/g, '<br>'));
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

    // Test message functionality
    let testTabInitialized = false;
    let testSending = false;
    function initializeTestTab() {
        if (testTabInitialized) return; // evitar múltiplos binds ao alternar abas
        testTabInitialized = true;

        // Test form submission (bind único)
        $('#test-message-form').off('submit').on('submit', function(e) {
            e.preventDefault();
            if (testSending) return; // evitar envios concorrentes
            sendTestMessage();
        });

        // Clear form button
        $('#clear-test-form').off('click').on('click', function() {
            const form = document.getElementById('test-message-form');
            if (form) form.reset();
            $('#test-result').addClass('d-none');
        });
    }
    
    // Removed: loadTemplatesForTest

    // Routines management
    function loadRoutines() {
        $.ajax({
            url: 'whatsapp_integration/get_routines',
            type: 'GET',
            data: { csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '') },
            success: function(resp) {
                renderRoutinesTable(resp.data || []);
            },
            error: function() {
                console.error('Failed to load routines');
            }
        });
    }

    function renderRoutinesTable(routines) {
        const tbody = $('#routines-table tbody');
        tbody.empty();
        if (!routines || routines.length === 0) {
            tbody.append('<tr><td colspan="6" class="text-center text-muted">No routines defined</td></tr>');
            return;
        }

        routines.forEach(function(r) {
            const templateLabel = r.template_name ? r.template_name + ' (' + (r.template_id||'') + ')' : (r.template_id || '');
            const row = `
                <tr>
                    <td>${escapeHtml(r.name)}</td>
                    <td>${escapeHtml(r.status_agendamento)}</td>
                    <td>${escapeHtml(templateLabel)}</td>
                    <td>${r.tempo_antes_horas} h</td>
                    <td>${r.ativa ? (I18N.yes || 'Yes') : (I18N.no || 'No')}</td>
                    <td>
                        <div class="btn-group btn-group-sm">
                            <button class="btn btn-outline-primary edit-routine" data-id="${r.id}" data-template-id="${r.template_id || ''}">${I18N.edit || 'Edit'}</button>
                            <button class="btn btn-outline-secondary force-routine" data-id="${r.id}">${I18N.force || 'Force'}</button>
                            <button class="btn btn-outline-danger delete-routine" data-id="${r.id}">${I18N.delete || 'Delete'}</button>
                        </div>
                    </td>
                </tr>
            `;
            tbody.append(row);
        });

        $('.edit-routine').on('click', function() {
            const id = $(this).data('id');
            openRoutineModal(id);
        });

        $('.delete-routine').on('click', function() {
            const id = $(this).data('id');
            if (!confirm('Delete routine?')) return;
            $.post('whatsapp_integration/delete_routine', { id: id, csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '') }, function(resp){
                if (resp.success) loadRoutines(); else alert(resp.message || 'Failed to delete');
            });
        });

        $('.force-routine').on('click', function() {
            const $btn = $(this);
            const id = $btn.data('id');
            const confirmMsg = (I18N.routine_execute_confirm || 'Execute this routine now?');
            if (!confirm(confirmMsg)) return;

            // show loading state on button
            const originalHtml = $btn.html();
            $btn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>' + (I18N.executing || 'Executing...'));

            $.ajax({
                url: 'whatsapp_integration/force_routine',
                type: 'POST',
                data: { id: id, csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '') },
                success: function(resp) {
                    console.log('force routine resp', resp);
                    const msg = resp.message || (resp.sent !== undefined ? (resp.sent + ' ' + (I18N.sent || 'sent')) : (I18N.routine_executed || 'Executed'));
                    if (resp.success) {
                        if (typeof toastr !== 'undefined') toastr.success(msg); else alert(msg);
                    } else {
                        if (typeof toastr !== 'undefined') toastr.error(resp.message || (I18N.routine_execute_failed || 'Failed')); else alert(resp.message || (I18N.routine_execute_failed || 'Failed'));
                    }
                    loadRoutines();
                },
                error: function(xhr) {
                    console.error('force routine error', xhr);
                    const msg = xhr.responseJSON?.message || ('HTTP ' + xhr.status);
                    if (typeof toastr !== 'undefined') toastr.error(msg); else alert(msg);
                },
                complete: function() {
                    $btn.prop('disabled', false).html(originalHtml);
                }
            });
        });
    }

    function escapeHtml(unsafe) {
        return String(unsafe || '').replace(/[&<>"']/g, function (m) {
            return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#039;'})[m];
        });
    }

    function openRoutineModal(id = null) {
        // populate template dropdown first (pass desired template id when editing)
        const editBtn = id ? $('#routines-table tbody').find(`button.edit-routine[data-id="${id}"]`) : null;
        const desiredTemplateId = editBtn ? editBtn.data('template-id') : null;

        loadTemplatesForRoutineModal(desiredTemplateId).then(function(){
            if (id) {
                // populate fields from table row
                const row = $('#routines-table tbody').find(`button.edit-routine[data-id="${id}"]`).closest('tr');
                const editBtn = $('#routines-table tbody').find(`button.edit-routine[data-id="${id}"]`);
                const name = row.find('td').eq(0).text();
                const status = row.find('td').eq(1).text();
                const templateId = editBtn.data('template-id') || '';
                const timeBefore = row.find('td').eq(3).text().replace(' h','') || '1';
                const active = row.find('td').eq(4).text() === (I18N.yes || 'Yes');

                $('#routine-id').val(id);
                $('#routine-name').val(name);
                $('#routine-status').val(status);
                // set template id after options are loaded (loadTemplatesForRoutineModal will populate the select)
                $('#routine-timebefore').val(timeBefore);
                $('#routine-active').prop('checked', active);
                $('#routine-modal-title').text((typeof vars === 'function' ? vars('routines') : '') ? (vars('routines') + ' - Edit') : 'Edit Routine');

                // store desired template id on the select element so loadTemplatesForRoutineModal can set it
                $('#routine-template').data('selected-template-id', templateId);
            } else {
                $('#routine-id').val('');
                $('#routine-name').val('');
                $('#routine-status').val('');
                $('#routine-template').val('');
                $('#routine-timebefore').val('1');
                $('#routine-active').prop('checked', true);
                $('#routine-modal-title').text((typeof vars === 'function' ? vars('create_routine') : 'Create Routine'));
            }

            var modal = new bootstrap.Modal(document.getElementById('routine-modal'));
            modal.show();
        });
    }

    function loadTemplatesForRoutineModal(desiredTemplateId = null) {
        return $.ajax({
            url: typeof App !== 'undefined' && App.Utils && App.Utils.Url ? App.Utils.Url.siteUrl('whatsapp_templates/get_templates') : 'whatsapp_templates/get_templates',
            type: 'GET',
            data: { csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : ''), enabled_only: true },
            success: function(response) {
                const select = $('#routine-template');
                select.empty();
                select.append('<option value="">' + (typeof vars === 'function' && vars('select_template') ? vars('select_template') : 'Select Template') + '</option>');
                if (response.success && response.data) {
                    response.data.forEach(function(t){
                        select.append('<option value="'+t.id+'">'+t.name+' ('+t.status_key+')</option>');
                    });

                    // If a desired template id was provided, select it now
                    try {
                        if (desiredTemplateId) {
                            select.val(desiredTemplateId.toString());
                        }
                    } catch (e) {
                        // ignore
                    }
                }

                // populate status select from server-provided script_vars if available
                try {
                    const statuses = (typeof vars === 'function' && vars('appointment_status_options')) || [];
                    const $status = $('#routine-status');
                    if ($status && $status.length && statuses && statuses.length) {
                        // clear existing (keep first placeholder)
                        $status.find('option:not(:first)').remove();
                        statuses.forEach(function(s){
                            $status.append('<option value="'+s+'">'+s+'</option>');
                        });
                    }
                } catch (e) {
                    console.warn('Failed to populate statuses', e);
                }
            }
        });
    }

    function saveRoutine(payload) {
        // client-side validation
        const $name = $('#routine-name');
        const $status = $('#routine-status');
        const $template = $('#routine-template');
        $name.removeClass('is-invalid'); $status.removeClass('is-invalid'); $template.removeClass('is-invalid');
        let bad = false;
        if (!$name.val().trim()) { $name.addClass('is-invalid'); bad = true; }
        if (!$status.val().trim()) { $status.addClass('is-invalid'); bad = true; }
        if (!$template.val().trim()) { $template.addClass('is-invalid'); bad = true; }
        if (bad) {
            if (typeof toastr !== 'undefined') toastr.error('Please fill required fields'); else alert('Please fill required fields');
            return;
        }

        $.post('whatsapp_integration/save_routine', { routine: payload, csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '') }, function(resp){
            if (resp.success) {
                if (typeof toastr !== 'undefined') toastr.success(resp.message || 'Saved'); else alert(resp.message || 'Saved');
                var modalEl = document.getElementById('routine-modal');
                var modal = bootstrap.Modal.getInstance(modalEl);
                if (modal) modal.hide();
                loadRoutines();
            } else {
                // show inline error if duplicate name
                if (resp.message && resp.message.toLowerCase().includes('name')) {
                    $('#routine-name').addClass('is-invalid');
                }
                if (typeof toastr !== 'undefined') toastr.error(resp.message || 'Failed'); else alert(resp.message || 'Failed');
            }
        }).fail(function(xhr){
            const msg = xhr.responseJSON?.message || 'Failed to save';
            if (typeof toastr !== 'undefined') toastr.error(msg); else alert(msg);
        });
    }

    // bind create button
    $('#create-routine-btn').on('click', function(){ openRoutineModal(null); });

    // save modal button
    $('#save-routine-btn').on('click', function(){
        const payload = {
            id: $('#routine-id').val() || null,
            name: $('#routine-name').val(),
            status_agendamento: $('#routine-status').val(),
            template_id: $('#routine-template').val(),
            tempo_antes_horas: $('#routine-timebefore').val(),
            ativa: $('#routine-active').is(':checked') ? 1 : 0
        };
        saveRoutine(payload);
    });
    
    // Send test message
    function sendTestMessage() {
        const phone = $('#test-phone').val().trim();
        const message = $('#test-message').val().trim();
        
        if (!phone || !message) {
            alert('Por favor, preencha o telefone e a mensagem');
            return;
        }
        
        // Validate phone format
        if (!phone.match(/^\+?[1-9]\d{1,14}$/)) {
            alert('Formato de telefone inválido. Use o formato: +5535988143613');
            return;
        }
        
        // Show loading state
        const submitBtn = $('#send-test-message');
        const originalText = submitBtn.html();
        submitBtn.prop('disabled', true).html('<i class="fas fa-spinner fa-spin me-2"></i>Enviando...');
        testSending = true;
        
        $.ajax({
            url: 'whatsapp_integration/send_test_message',
            type: 'POST',
            data: {
                phone: phone,
                message: message,
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                const ok = response && response.success;
                if (typeof toastr !== 'undefined') {
                    ok ? toastr.success('Mensagem enviada com sucesso...') : toastr.error(response?.message || 'Falha em enviar mensagem...');
                } else {
                    alert(ok ? 'Mensagem enviada com sucesso...' : (response?.message || 'Falha em enviar mensagem...'));
                }
                // Limpar campos após envio bem-sucedido
                if (ok) {
                    $('#test-phone').val('');
                    $('#test-message').val('');
                }
                // Esconder bloco de debug/resultado
                $('#test-result').addClass('d-none');
            },
            error: function(xhr) {
                const msg = xhr.responseJSON?.message || 'Falha em enviar mensagem...';
                if (typeof toastr !== 'undefined') toastr.error(msg); else alert(msg);
                $('#test-result').addClass('d-none');
            },
            complete: function() {
                // Restore button state
                submitBtn.prop('disabled', false).html(originalText);
                testSending = false;
            }
        });
    }
    
    // Show test result
    function showTestResult() {
        // Mantido por compatibilidade, agora oculto/sem debug
        $('#test-result').addClass('d-none');
    }

    console.log('WhatsApp Integration: Event handlers registered');
    
    // Initialize tabs
    initializeTabs();
    
    // Initialize test tab
    initializeTestTab();
    
    // Initialize execution logs tab
    initializeExecutionLogsTab();
    
    // Template modal event handlers
    $('#save-template-btn').on('click', function() {
        saveTemplate();
    });
    
    $('#preview-template-btn').on('click', function() {
        previewTemplate();
    });
    // ============= EXECUTION LOGS FUNCTIONS =============

    // Initialize execution logs tab
    function initializeExecutionLogsTab() {
        console.log('Initializing execution logs tab...');
        
        // Load initial data when tab is shown
        $('#execution-logs-tab').on('shown.bs.tab', function() {
            console.log('Execution logs tab shown, loading data...');
            loadExecutionStats();
            loadExecutionLogs();
            loadRoutinesForFilter();
        });
        
        // Event handlers for execution logs
        $('#filter-execution-logs-btn').on('click', function() {
            loadExecutionLogs();
        });
        
        $('#clear-execution-filters-btn').on('click', function() {
            clearExecutionFilters();
        });
        
        $('#refresh-execution-logs-btn').on('click', function() {
            loadExecutionStats();
            loadExecutionLogs();
        });
        
        $('#cleanup-execution-logs-btn').on('click', function() {
            showCleanupModal();
        });
        
        $('#confirm-cleanup-btn').on('click', function() {
            performCleanup();
        });
        
        // View details button handler (delegated)
        $(document).on('click', '.view-execution-details-btn', function() {
            const logId = $(this).data('log-id');
            showExecutionLogDetails(logId);
        });
    }
    
    // Load execution statistics
    function loadExecutionStats() {
        const routineId = $('#execution-log-routine-filter').val() || '';
        const dateFrom = $('#execution-log-date-from').val() || '';
        const dateTo = $('#execution-log-date-to').val() || '';
        
        console.log('Loading execution stats with filters:', { routineId, dateFrom, dateTo });
        
        $.ajax({
            url: 'whatsapp_integration/get_execution_stats',
            type: 'GET',
            data: {
                routine_id: routineId || '',
                date_from: dateFrom || '',
                date_to: dateTo || ''
            },
            success: function(response) {
                console.log('Stats response:', response);
                if (response && response.success) {
                    const stats = response.data;
                    $('#total-executions').text(stats.total_executions || 0);
                    $('#successful-executions').text(stats.successful_executions || 0);
                    $('#partial-executions').text(stats.partial_executions || 0);
                    $('#failed-executions').text(stats.failed_executions || 0);
                }
            },
            error: function(xhr) {
                console.error('Failed to load execution stats:', xhr);
            }
        });
    }
    
    // Load execution logs
    let currentPage = 1;
    function loadExecutionLogs(page = 1) {
        currentPage = page;
        
        const routineId = $('#execution-log-routine-filter').val() || '';
        const status = $('#execution-log-status-filter').val() || '';
        const dateFrom = $('#execution-log-date-from').val() || '';
        const dateTo = $('#execution-log-date-to').val() || '';
        
        $.ajax({
            url: 'whatsapp_integration/get_execution_logs',
            type: 'GET',
            data: {
                page: page,
                limit: 20,
                routine_id: routineId || '',
                status: status || '',
                date_from: dateFrom || '',
                date_to: dateTo || ''
            },
            success: function(response) {
                if (response && response.success) {
                    renderExecutionLogsTable(response.data);
                    renderExecutionLogsPagination(response);
                    loadExecutionStats(); // Update stats with filtered data
                }
            },
            error: function(xhr) {
                console.error('Failed to load execution logs:', xhr);
                const msg = xhr.responseJSON?.message || 'Falha ao carregar logs de execução';
                if (typeof toastr !== 'undefined') {
                    toastr.error(msg);
                } else {
                    alert(msg);
                }
            }
        });
    }
    
    // Render execution logs table
    function renderExecutionLogsTable(logs) {
        const $tbody = $('#execution-logs-table tbody');
        $tbody.empty();
        
        if (!logs || logs.length === 0) {
            $tbody.append('<tr><td colspan="10" class="text-center text-muted">Nenhum log de execução encontrado</td></tr>');
            return;
        }
        
        logs.forEach(function(log) {
            const statusClass = getStatusClass(log.execution_status);
            const statusText = getStatusText(log.execution_status);
            const executionTime = log.execution_time_seconds ? parseFloat(log.execution_time_seconds).toFixed(3) + 's' : '-';
            const templateName = log.template_name || log.current_template_name || '-';
            
            const row = `
                <tr>
                    <td>${formatDateTime(log.execution_datetime)}</td>
                    <td>${escapeHtml(log.routine_name)}</td>
                    <td><span class="badge ${statusClass}">${statusText}</span></td>
                    <td>${escapeHtml(log.appointment_status)}</td>
                    <td>${escapeHtml(templateName)}</td>
                    <td>${log.total_appointments_found}</td>
                    <td>${log.successful_sends}</td>
                    <td>${log.failed_sends}</td>
                    <td>${executionTime}</td>
                    <td>
                        <button type="button" class="btn btn-sm btn-outline-primary view-execution-details-btn" data-log-id="${log.id}">
                            <i class="fas fa-eye"></i> Ver
                        </button>
                    </td>
                </tr>
            `;
            $tbody.append(row);
        });
    }
    
    // Render pagination
    function renderExecutionLogsPagination(response) {
        const $pagination = $('#execution-logs-pagination');
        $pagination.empty();
        
        if (response.total_pages <= 1) return;
        
        // Previous button
        if (response.page > 1) {
            $pagination.append(`
                <li class="page-item">
                    <a class="page-link" href="#" onclick="loadExecutionLogs(${response.page - 1}); return false;">
                        <i class="fas fa-chevron-left"></i>
                    </a>
                </li>
            `);
        }
        
        // Page numbers
        const startPage = Math.max(1, response.page - 2);
        const endPage = Math.min(response.total_pages, response.page + 2);
        
        for (let i = startPage; i <= endPage; i++) {
            const activeClass = i === response.page ? 'active' : '';
            $pagination.append(`
                <li class="page-item ${activeClass}">
                    <a class="page-link" href="#" onclick="loadExecutionLogs(${i}); return false;">${i}</a>
                </li>
            `);
        }
        
        // Next button
        if (response.page < response.total_pages) {
            $pagination.append(`
                <li class="page-item">
                    <a class="page-link" href="#" onclick="loadExecutionLogs(${response.page + 1}); return false;">
                        <i class="fas fa-chevron-right"></i>
                    </a>
                </li>
            `);
        }
    }
    
    // Show execution log details modal
    function showExecutionLogDetails(logId) {
        $.ajax({
            url: 'whatsapp_integration/get_execution_log_details',
            type: 'GET',
            data: { id: logId },
            success: function(response) {
                if (response && response.success) {
                    const log = response.data;
                    populateExecutionLogModal(log);
                    $('#execution-log-details-modal').modal('show');
                }
            },
            error: function(xhr) {
                console.error('Failed to load execution log details:', xhr);
                const msg = xhr.responseJSON?.message || 'Falha ao carregar detalhes do log';
                if (typeof toastr !== 'undefined') {
                    toastr.error(msg);
                } else {
                    alert(msg);
                }
            }
        });
    }
    
    // Populate execution log details modal
    function populateExecutionLogModal(log) {
        $('#detail-routine-name').text(log.routine_name || '-');
        $('#detail-execution-status').html(`<span class="badge ${getStatusClass(log.execution_status)}">${getStatusText(log.execution_status)}</span>`);
        $('#detail-execution-datetime').text(formatDateTime(log.execution_datetime));
        $('#detail-execution-time').text(log.execution_time_seconds ? parseFloat(log.execution_time_seconds).toFixed(3) + 's' : '-');
        $('#detail-total-appointments').text(log.total_appointments_found || 0);
        $('#detail-successful-sends').text(log.successful_sends || 0);
        $('#detail-failed-sends').text(log.failed_sends || 0);
        $('#detail-template-name').text(log.template_name || log.current_template_name || '-');
        
        // Clients notified
        const $clientsDiv = $('#detail-clients-notified');
        $clientsDiv.empty();
        if (log.clients_notified && log.clients_notified.length > 0) {
            log.clients_notified.forEach(function(client) {
                const statusIcon = client.status === 'SUCCESS' ? 
                    '<i class="fas fa-check-circle text-success"></i>' : 
                    '<i class="fas fa-times-circle text-danger"></i>';
                const errorInfo = client.error ? ` (${client.error})` : '';
                $clientsDiv.append(`
                    <div class="mb-2">
                        ${statusIcon} <strong>${escapeHtml(client.customer_name)}</strong><br>
                        <small class="text-muted">Agendamento: ${client.appointment_id} | ${formatDateTime(client.appointment_datetime)} | ${formatDateTime(client.timestamp)}${errorInfo}</small>
                    </div>
                `);
            });
        } else {
            $clientsDiv.append('<div class="text-muted">Nenhum cliente notificado</div>');
        }
        
        // Execution details
        const $detailsDiv = $('#detail-execution-details');
        $detailsDiv.empty();
        if (log.execution_details) {
            $detailsDiv.append('<pre class="small">' + JSON.stringify(log.execution_details, null, 2) + '</pre>');
        } else {
            $detailsDiv.append('<div class="text-muted">Nenhum detalhe adicional</div>');
        }
        
        // Error message
        if (log.error_message) {
            $('#detail-error-message').text(log.error_message);
            $('#detail-error-section').removeClass('d-none');
        } else {
            $('#detail-error-section').addClass('d-none');
        }
    }
    
    // Load routines for filter dropdown
    function loadRoutinesForFilter() {
        $.ajax({
            url: 'whatsapp_integration/get_routines',
            type: 'GET',
            success: function(response) {
                if (response && response.success) {
                    const $select = $('#execution-log-routine-filter');
                    $select.find('option:not(:first)').remove(); // Keep first option
                    
                    response.data.forEach(function(routine) {
                        $select.append(`<option value="${routine.id}">${escapeHtml(routine.name)}</option>`);
                    });
                }
            },
            error: function(xhr) {
                console.error('Failed to load routines for filter:', xhr);
            }
        });
    }
    
    // Clear execution filters
    function clearExecutionFilters() {
        $('#execution-log-routine-filter').val('');
        $('#execution-log-status-filter').val('');
        $('#execution-log-date-from').val('');
        $('#execution-log-date-to').val('');
        loadExecutionLogs(1);
    }
    
    // Show cleanup modal
    function showCleanupModal() {
        $('#cleanup-confirmation-modal').modal('show');
    }
    
    // Perform cleanup
    function performCleanup() {
        const daysToKeep = parseInt($('#cleanup-days').val()) || 90;
        
        $.ajax({
            url: 'whatsapp_integration/cleanup_execution_logs',
            type: 'POST',
            data: {
                days_to_keep: daysToKeep,
                csrf_token: (typeof vars !== 'undefined' ? vars('csrf_token') : '')
            },
            success: function(response) {
                if (response && response.success) {
                    $('#cleanup-confirmation-modal').modal('hide');
                    if (typeof toastr !== 'undefined') {
                        toastr.success(response.message || 'Logs antigos removidos com sucesso');
                    } else {
                        alert(response.message || 'Logs antigos removidos com sucesso');
                    }
                    loadExecutionStats();
                    loadExecutionLogs();
                } else {
                    if (typeof toastr !== 'undefined') {
                        toastr.error(response.message || 'Falha ao remover logs antigos');
                    } else {
                        alert(response.message || 'Falha ao remover logs antigos');
                    }
                }
            },
            error: function(xhr) {
                console.error('Failed to cleanup logs:', xhr);
                const msg = xhr.responseJSON?.message || 'Falha ao remover logs antigos';
                if (typeof toastr !== 'undefined') {
                    toastr.error(msg);
                } else {
                    alert(msg);
                }
            }
        });
    }
    
    // Helper functions for execution logs
    function getStatusClass(status) {
        switch (status) {
            case 'SUCCESS':
                return 'bg-success';
            case 'PARTIAL_SUCCESS':
                return 'bg-warning';
            case 'FAILURE':
                return 'bg-danger';
            default:
                return 'bg-secondary';
        }
    }
    
    function getStatusText(status) {
        switch (status) {
            case 'SUCCESS':
                return 'Sucesso';
            case 'PARTIAL_SUCCESS':
                return 'Parcial';
            case 'FAILURE':
                return 'Falha';
            default:
                return status;
        }
    }
    
    function formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return '-';
        const date = new Date(dateTimeStr);
        return date.toLocaleString('pt-BR');
    }
    
    function escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

});

(function () {
    const $testForm = $('#wa-test-form');
    if ($testForm.length) {
        $testForm.on('submit', function (e) {
            e.preventDefault();
            const phone = $.trim($('#wa-test-phone').val() || '');
            const templateId = $('#wa-test-template').val();
            const message = $.trim($('#wa-test-message').val() || '');

            if (!phone) {
                App.Layouts.Backend.displayNotification('error', 'Informe o telefone.');
                return;
            }
            if (!templateId && !message) {
                App.Layouts.Backend.displayNotification('error', 'Informe uma mensagem ou selecione um template.');
                return;
            }

            const payload = {
                csrf_token: vars('csrf_token'),
                phone: phone,
                template_id: templateId || '',
                message: message || ''
            };

            $.post(App.Utils.Url.siteUrl('whatsapp_integration/send_test_message'), payload)
                .done(function (res) {
                    if (res && res.success) {
                        App.Layouts.Backend.displayNotification('success', res.message || 'Mensagem de teste enviada');
                    } else {
                        App.Layouts.Backend.displayNotification('error', (res && res.message) || 'Falha ao enviar mensagem de teste');
                    }
                })
                .fail(function (xhr) {
                    App.Layouts.Backend.displayNotification('error', 'Falha ao enviar mensagem de teste');
                });
        });
    }
})();


