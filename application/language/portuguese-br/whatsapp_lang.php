<?php defined('BASEPATH') or exit('No direct script access allowed');

// Integração WhatsApp
$lang['whatsapp'] = 'WhatsApp';
$lang['whatsapp_info'] = 'Envie notificações e confirmações de agendamento para clientes via WhatsApp.';
// Routines UI
$lang['routines'] = 'Rotinas';
$lang['create_routine'] = 'Criar Rotina';
$lang['edit_routine'] = 'Editar Rotina';
$lang['delete_routine'] = 'Excluir Rotina';
$lang['routine_name'] = 'Nome';
$lang['routine_appointment_status'] = 'Status do Agendamento';
$lang['routine_template'] = 'Template';
$lang['routine_time_before'] = 'Tempo antes (h)';
$lang['routine_active'] = 'Ativa';
$lang['save_routine'] = 'Salvar Rotina';
$lang['cancel'] = 'Cancelar';
$lang['select_template'] = 'Selecionar Template';
$lang['routine_execute_confirm'] = 'Tem certeza que deseja executar esta rotina agora?';
$lang['routine_executed'] = 'Rotina executada';
$lang['routine_execute_failed'] = 'Falha ao executar rotina';
$lang['routine_name_exists'] = 'Já existe uma rotina com este nome';
$lang['please_fill_required'] = 'Por favor, preencha os campos obrigatórios';
// UI labels for routines
$lang['edit'] = 'Editar';
$lang['force'] = 'Executar';
$lang['delete'] = 'Excluir';
$lang['yes'] = 'Sim';
$lang['no'] = 'Não';
$lang['executing'] = 'Executando...';
$lang['sent'] = 'enviado';

// Configuração
$lang['whatsapp_configuration'] = 'Configuração';
$lang['whatsapp_host'] = 'Host WPPConnect';
$lang['whatsapp_host_hint'] = 'http://localhost';
$lang['whatsapp_port'] = 'Porta';
$lang['whatsapp_port_hint'] = 'padrão: 21465';
$lang['whatsapp_session'] = 'Nome da Sessão';
$lang['whatsapp_session_hint'] = 'nome único da sessão';
$lang['whatsapp_secret_key'] = 'Chave Secreta';
$lang['whatsapp_secret_key_hint'] = 'chave de autenticação';
$lang['whatsapp_token'] = 'Token de Autenticação';
$lang['whatsapp_token_auto_hint'] = 'gerado automaticamente';
$lang['token_auto_generated'] = 'Token será gerado automaticamente';

// Ações
$lang['generate_token'] = 'Gerar Token';
$lang['test_connectivity'] = 'Testar Conectividade';
$lang['health_check'] = 'Verificação de Saúde';
$lang['start_session'] = 'Iniciar Sessão';
$lang['close_session'] = 'Fechar Sessão';
$lang['logout_session'] = 'Desconectar Sessão';
$lang['save_settings'] = 'Salvar Configurações';
$lang['enable_integration'] = 'Habilitar Integração';

// Mensagens
$lang['whatsapp_settings_saved'] = 'Configurações do WhatsApp salvas com sucesso.';
$lang['whatsapp_token_generated'] = 'Token de autenticação gerado com sucesso.';
$lang['whatsapp_session_started'] = 'Sessão do WhatsApp iniciada com sucesso.';
$lang['whatsapp_session_closed'] = 'Sessão do WhatsApp fechada com sucesso.';
$lang['whatsapp_session_logout'] = 'Sessão do WhatsApp desconectada com sucesso.';
$lang['secret_key_required'] = 'Chave secreta é necessária para gerar o token.';
$lang['confirm_reveal_token'] = 'Você tem certeza que deseja revelar o token? Esta ação será registrada.';
$lang['confirm_rotate_token'] = 'Deseja rotacionar o token? Isto irá invalidar o token atual e gerar um novo.';
$lang['invalid_host'] = 'Host/URL inválido ou inacessível';
$lang['token_generation_failed'] = 'Falha na geração do token. Verifique chave secreta e sessão.';
$lang['connectivity_failed'] = 'Falha na conectividade';
$lang['no_token_generated'] = 'Nenhum token gerado ainda';
$lang['enter_secret_key'] = 'Digite sua chave secreta';

// Status da Sessão
$lang['whatsapp_session_management'] = 'Gerenciamento de Sessão';
$lang['session_status'] = 'Status da Sessão';
$lang['connected'] = 'Conectado';
$lang['waiting_qr_scan'] = 'Aguardando Leitura QR';
$lang['pairing'] = 'Pareando';
$lang['session_not_found'] = 'Sessão Não Encontrada';
$lang['connection_error'] = 'Erro de Conexão';
// removed: checking_status (status text is now shown only via badge)
$lang['confirm_logout_session'] = 'Tem certeza que deseja desconectar da sessão do WhatsApp?';

// Código QR
$lang['whatsapp_qr_code'] = 'Código QR do WhatsApp';
$lang['whatsapp_qr_instructions'] = 'Abra o WhatsApp no seu telefone e escaneie este código QR para conectar.';
$lang['generating_qr_code'] = 'Gerando código QR...';
$lang['refresh_qr'] = 'Atualizar Código QR';
$lang['show_qr_code'] = 'Mostrar Código QR';

// Configurações de Mensagem
$lang['message_settings'] = 'Configurações de Mensagem';
$lang['send_confirmation_messages'] = 'Enviar Mensagens de Confirmação';
$lang['send_reschedule_messages'] = 'Enviar Mensagens de Reagendamento';
$lang['send_cancellation_messages'] = 'Enviar Mensagens de Cancelamento';
$lang['send_contract_messages'] = 'Enviar Mensagens de Contrato';

// Estatísticas
$lang['whatsapp_statistics'] = 'Estatísticas';
$lang['active_templates'] = 'Templates Ativos';
$lang['messages_sent'] = 'Mensagens Enviadas';
$lang['messages_failed'] = 'Mensagens Falharam';
$lang['recent_logs'] = 'Logs Recentes';

// Ações Rápidas
$lang['quick_actions'] = 'Ações Rápidas';
$lang['manage_templates'] = 'Gerenciar Templates';
$lang['view_message_logs'] = 'Ver Logs de Mensagem';

// Templates
$lang['whatsapp_templates'] = 'Templates WhatsApp';
$lang['whatsapp_template_created'] = 'Template WhatsApp criado com sucesso.';
$lang['whatsapp_template_updated'] = 'Template WhatsApp atualizado com sucesso.';
$lang['whatsapp_template_deleted'] = 'Template WhatsApp excluído com sucesso.';
$lang['whatsapp_template_toggled'] = 'Template WhatsApp %s com sucesso.';
$lang['whatsapp_template_duplicated'] = 'Template WhatsApp duplicado com sucesso.';
$lang['whatsapp_templates_bulk_updated'] = '%d templates WhatsApp atualizados com sucesso.';
$lang['whatsapp_default_templates_created'] = '%d templates padrão criados com sucesso.';
$lang['whatsapp_templates_imported'] = '%d templates WhatsApp importados com sucesso.';

// Campos de Template
$lang['template_name'] = 'Nome do Template';
$lang['template_status'] = 'Status';
$lang['template_language'] = 'Idioma';
$lang['template_body'] = 'Corpo da Mensagem';
$lang['template_enabled'] = 'Habilitado';
$lang['template_preview'] = 'Visualizar';
$lang['available_variables'] = 'Variáveis Disponíveis';
$lang['available_placeholders'] = 'Variáveis Disponíveis'; // Compatibilidade
$lang['create_template'] = 'Criar Template';
$lang['edit_template'] = 'Editar Template';
$lang['duplicate_template'] = 'Duplicar Template';
$lang['delete_template'] = 'Excluir Template';
$lang['enable_template'] = 'Habilitar Template';
$lang['disable_template'] = 'Desabilitar Template';

// Marcadores
$lang['placeholder_client_name'] = 'Nome completo do cliente';
$lang['placeholder_phone'] = 'Telefone do cliente';
$lang['placeholder_appointment_date'] = 'Data do agendamento';
$lang['placeholder_appointment_time'] = 'Hora do agendamento';
$lang['placeholder_service_name'] = 'Nome do serviço';
$lang['placeholder_location'] = 'Local do agendamento';
$lang['placeholder_link'] = 'Link de gerenciamento do agendamento';

// Logs de Mensagem
$lang['message_logs'] = 'Logs de Mensagem';
$lang['no_message_logs'] = 'Nenhum log de mensagem encontrado.';
$lang['log_date'] = 'Data';
$lang['log_phone'] = 'Telefone';
$lang['log_status'] = 'Status';
$lang['log_result'] = 'Resultado';
$lang['log_send_type'] = 'Tipo de Envio';
$lang['log_template'] = 'Template';
$lang['log_error'] = 'Erro';

// Tipos de Envio
$lang['send_type_onCreate'] = 'Na Criação';
$lang['send_type_onUpdate'] = 'Na Atualização';
$lang['send_type_manual'] = 'Manual';

// Resultados
$lang['result_success'] = 'Sucesso';
$lang['result_failure'] = 'Falha';
$lang['result_pending'] = 'Pendente';

// Formulário de Agendamento
$lang['whatsapp_template'] = 'Template WhatsApp';
$lang['select_template'] = 'Selecionar Template';
$lang['send_whatsapp'] = 'Enviar WhatsApp';
$lang['whatsapp_message_sent'] = 'Mensagem WhatsApp enviada com sucesso.';
$lang['whatsapp_message_failed'] = 'Falha ao enviar mensagem WhatsApp: %s';

// Erros
$lang['whatsapp_not_configured'] = 'Integração WhatsApp não está configurada.';
$lang['whatsapp_not_enabled'] = 'Integração WhatsApp não está habilitada.';
$lang['whatsapp_session_not_connected'] = 'Sessão WhatsApp não está conectada.';
$lang['whatsapp_no_customer_phone'] = 'Telefone do cliente é obrigatório.';
$lang['whatsapp_no_template'] = 'Nenhum template encontrado para este status.';

// Ações de Status
$lang['generating'] = 'Gerando...';
$lang['testing'] = 'Testando...';
$lang['starting'] = 'Iniciando...';
$lang['closing'] = 'Fechando...';
$lang['logging_out'] = 'Desconectando...';
$lang['loading'] = 'Carregando...';

// Ações em Lote
$lang['bulk_actions'] = 'Ações em Lote';
$lang['bulk_enable'] = 'Habilitar Selecionados';
$lang['bulk_disable'] = 'Desabilitar Selecionados';
$lang['bulk_delete'] = 'Excluir Selecionados';
$lang['select_action'] = 'Selecionar Ação';
$lang['apply'] = 'Aplicar';

// Importar/Exportar
$lang['import_templates'] = 'Importar Templates';
$lang['export_templates'] = 'Exportar Templates';
$lang['import_file'] = 'Importar Arquivo';
$lang['overwrite_existing'] = 'Sobrescrever Existentes';
$lang['templates_file'] = 'Arquivo de Templates';
$lang['choose_file'] = 'Escolher Arquivo';

// Validação
$lang['template_name_required'] = 'Nome do template é obrigatório.';
$lang['template_status_required'] = 'Status do template é obrigatório.';
$lang['template_body_required'] = 'Corpo do template é obrigatório.';

// Additional template translations
$lang['whatsapp_templates_description'] = 'Gerencie templates de mensagens WhatsApp para diferentes status de agendamento.';
$lang['whatsapp_templates_management'] = 'Gerenciamento de Templates';
$lang['status_key'] = 'Chave do Status';
$lang['language'] = 'Idioma';
$lang['enabled'] = 'Habilitado';
$lang['created_at'] = 'Criado em';
$lang['actions'] = 'Ações';
$lang['select_status'] = 'Selecionar Status';
$lang['template_body_placeholder'] = 'Digite o corpo da mensagem usando placeholders como {{client_name}}, {{appointment_date}}, etc.';
$lang['template_body_hint'] = 'Use variáveis para personalizar a mensagem. Clique nas variáveis abaixo para inserir automaticamente.';
$lang['variable_hint'] = 'Use variáveis para personalizar a mensagem. Clique nas variáveis abaixo para inserir automaticamente.';
$lang['available_placeholders'] = 'Variáveis Disponíveis'; // Compatibilidade
$lang['unknown_variable'] = 'Variável desconhecida';
$lang['use_available_variables'] = 'Use apenas variáveis disponíveis';
$lang['template_preview'] = 'Pré-visualização do Template';
$lang['insert_variable'] = 'Inserir Variável';
$lang['preview_template'] = 'Visualizar Template';
$lang['save_template'] = 'Salvar Template';
$lang['cancel'] = 'Cancelar';
$lang['close'] = 'Fechar';
$lang['template_preview'] = 'Visualização do Template';
$lang['select_file'] = 'Selecionar Arquivo';
$lang['import_file_hint'] = 'Selecione um arquivo JSON com os templates para importar.';
$lang['import'] = 'Importar';
$lang['no_templates_found'] = 'Nenhum template encontrado';
$lang['create_default_templates'] = 'Criar Templates Padrão';

// Tab navigation translations
$lang['whatsapp_configuration'] = 'Configuração';
$lang['whatsapp_message_logs'] = 'Logs de Mensagens';
$lang['refresh'] = 'Atualizar';
$lang['all_statuses'] = 'Todos os Status';
$lang['success'] = 'Sucesso';
$lang['failure'] = 'Falha';
$lang['date'] = 'Data';
$lang['phone'] = 'Telefone';
$lang['status'] = 'Status';
$lang['result'] = 'Resultado';
$lang['invalid_placeholder'] = 'Marcador inválido: %s';
$lang['invalid_language_code'] = 'Código de idioma inválido: %s';
$lang['invalid_status_key'] = 'Chave de status inválida: %s';

// Comum
$lang['enabled'] = 'Habilitado';
$lang['disabled'] = 'Desabilitado';
$lang['active'] = 'Ativo';
$lang['inactive'] = 'Inativo';
$lang['configure'] = 'Configurar';
$lang['close'] = 'Fechar';
$lang['cancel'] = 'Cancelar';
$lang['delete'] = 'Excluir';
$lang['edit'] = 'Editar';
$lang['create'] = 'Criar';
$lang['update'] = 'Atualizar';
$lang['refresh'] = 'Atualizar';
$lang['preview'] = 'Visualizar';
$lang['date'] = 'Data';
$lang['phone'] = 'Telefone';
$lang['status'] = 'Status';
$lang['result'] = 'Resultado';
$lang['send_type'] = 'Tipo de Envio';
