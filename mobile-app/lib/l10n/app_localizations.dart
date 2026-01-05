import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Application localizations.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('pt'), // Portuguese
    Locale('es'), // Spanish
  ];

  // Localized strings
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // General
      'appName': 'Easy!Appointments',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'confirm': 'Confirm',
      'close': 'Close',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'back': 'Back',
      'next': 'Next',
      'done': 'Done',
      'edit': 'Edit',
      'create': 'Create',
      'update': 'Update',
      'search': 'Search',
      'filter': 'Filter',
      'refresh': 'Refresh',
      'tryAgain': 'Try Again',
      'goToHome': 'Go to Home',
      'changeServer': 'Change Server',
      'noServerConfigured': 'No server configured',
      'clearAll': 'Clear All',
      'confirmClearNotifications': 'Are you sure you want to clear all notifications?',
      'website': 'Website',
      'version': 'Version',

      // Auth
      'login': 'Sign In',
      'logout': 'Sign Out',
      'username': 'Username',
      'password': 'Password',
      'welcome': 'Welcome',
      'signInToContinue': 'Sign in to continue',
      'invalidCredentials': 'Invalid credentials',
      'forgotPassword': 'Forgot Password?',
      'rememberMe': 'Remember me',
      'pleaseEnterUsername': 'Please enter your username',
      'pleaseEnterPassword': 'Please enter your password',
      'passwordMinLength': 'Password must be at least 6 characters',
      'contactAdminHelp': 'Contact your administrator if you need help accessing your account.',

      // Profile
      'editProfile': 'Edit Profile',
      'profileUpdatedSuccessfully': 'Profile updated successfully!',
      'personalInformation': 'Personal Information',
      'contactInformation': 'Contact Information',
      'mobile': 'Mobile',
      'state': 'State',
      'timezone': 'Timezone',
      'noContactInfo': 'No contact information available',
      'noUserData': 'No user data available',
      'account': 'Account',
      'manageYourProfile': 'Manage your profile',
      'changePassword': 'Change Password',
      'passwordChangedSuccessfully': 'Password changed successfully!',
      'currentPassword': 'Current Password',
      'newPassword': 'New Password',
      'confirmNewPassword': 'Confirm New Password',
      'passwordRequirements': 'Password must be at least 7 characters long',
      'passwordTooShort': 'Password must be at least 7 characters',
      'passwordsDoNotMatch': 'Passwords do not match',
      'newPasswordSameAsCurrent': 'New password must be different from current password',
      'invalidEmail': 'Invalid email address',

      // Navigation
      'calendar': 'Calendar',
      'appointments': 'Appointments',
      'settings': 'Settings',
      'notifications': 'Notifications',
      'profile': 'Profile',

      // Appointments
      'newAppointment': 'New Appointment',
      'editAppointment': 'Edit Appointment',
      'appointmentDetails': 'Appointment Details',
      'noAppointments': 'No appointments',
      'noAppointmentsDescription': 'You don\'t have any appointments scheduled.',
      'bookNow': 'Book Now',
      'noResultsFound': 'No results found',
      'noResultsDescription': 'Try adjusting your search or filters.',
      'upcomingAppointments': 'Upcoming Appointments',
      'pastAppointments': 'Past Appointments',
      'appointmentCreated': 'Appointment created successfully!',
      'appointmentUpdated': 'Appointment updated successfully!',
      'appointmentCancelled': 'Appointment cancelled!',
      'createAppointment': 'Create Appointment',
      'failedToCreateAppointment': 'Failed to create appointment',
      'failedToLoadData': 'Failed to load data',

      // Date & Time
      'today': 'Today',
      'tomorrow': 'Tomorrow',
      'yesterday': 'Yesterday',
      'selectDate': 'Select Date',
      'selectTime': 'Select Time',
      'dateAndTime': 'Date & Time',
      'date': 'Date',
      'time': 'Time',
      'duration': 'Duration',
      'minutes': 'minutes',
      'hours': 'hours',
      'startTime': 'Start Time',
      'endTime': 'End Time',
      'startDate': 'Start Date',
      'endDate': 'End Date',
      'appointmentTime': 'Appointment Time',

      // Recurring Appointments
      'recurringAppointment': 'Recurring Appointment',
      'noRecurrence': 'No recurrence',
      'specificDays': 'Specific days',
      'weekly': 'Weekly',
      'everyXDays': 'Every X days',
      'selectWeekDays': 'Select week days',
      'intervalDays': 'Interval (days)',
      'days': 'days',
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
      'minimumDuration': 'Duration must be at least 5 minutes',
      'pleaseSelectDateRange': 'Please select start and end dates',
      'pleaseSelectWeekDays': 'Please select at least one day',
      'invalidInterval': 'Interval must be between 1 and 365 days',
      'enableRecurring': 'Enable recurring appointment',
      'recurringDescription': 'Create appointments on selected days within the period',
      'pleaseEnter': 'Please enter',
      'pleaseEnterNotes': 'Please enter notes',
      'appointmentsWillBeCreated': 'appointments will be created',
      'appointmentsCreated': 'appointments created',
      'creatingAppointments': 'Creating appointments',
      'creatingAppointmentProgress': 'Creating appointment',
      'of': 'of',
      'processingPleaseWait': 'Processing, please wait...',
      'created': 'created',
      'failed': 'failed',
      'noAppointmentsGenerated': 'No appointments generated for the selected period',

      // Service & Provider
      'service': 'Service',
      'services': 'Services',
      'selectService': 'Select Service',
      'provider': 'Provider',
      'providers': 'Providers',
      'selectProvider': 'Select Provider',

      // Customer
      'customer': 'Customer',
      'customers': 'Customers',
      'customerInformation': 'Customer Information',
      'fullName': 'Full Name',
      'firstName': 'First Name',
      'lastName': 'Last Name',
      'email': 'Email',
      'phone': 'Phone',
      'phoneOptional': 'Phone (optional)',
      'address': 'Address',
      'city': 'City',
      'zipCode': 'ZIP Code',
      'newCustomer': 'New Customer',
      'existingCustomer': 'Existing Customer',
      'searchCustomer': 'Search Customer',
      'customerNotes': 'Customer Notes',
      'optional': 'optional',

      // Notes
      'notes': 'Notes',
      'notesOptional': 'Notes (Optional)',
      'addNotes': 'Add any additional notes...',
      'appointmentNotes': 'Appointment Notes',

      // Status
      'status': 'Status',
      'selectStatus': 'Select status',
      'options': 'options',
      'pending': 'Pending',
      'booked': 'Booked',
      'confirmed': 'Confirmed',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'noShow': 'No Show',
      'unavailability': 'Unavailability',

      // Validation
      'fieldRequired': 'This field is required',
      'pleaseEnterName': 'Please enter customer name',
      'pleaseEnterFirstName': 'Please enter first name',
      'pleaseEnterLastName': 'Please enter last name',
      'pleaseEnterEmail': 'Please enter email',
      'pleaseEnterValidEmail': 'Please enter a valid email',
      'pleaseEnterPhone': 'Please enter phone number',
      'pleaseEnterAddress': 'Please enter address',
      'pleaseEnterCity': 'Please enter city',
      'pleaseEnterZipCode': 'Please enter ZIP code',
      'pleaseSelectService': 'Please select a service',
      'pleaseSelectProvider': 'Please select a provider',
      'pleaseSelectDate': 'Please select a date',
      'pleaseSelectTime': 'Please select a time',

      // Calendar
      'selectDayToView': 'Select a day to view appointments',
      'tapToCreate': 'Tap + to create a new appointment',
      'noAppointmentsForDay': 'No appointments for this day',
      'with': 'with',

      // Settings
      'language': 'Language',
      'theme': 'Theme',
      'themeLight': 'Light',
      'themeDark': 'Dark',
      'themeSystem': 'System Default',
      'connection': 'Connection',
      'server': 'Server',
      'preferences': 'Preferences',
      'about': 'About',
      'privacyPolicy': 'Privacy Policy',
      'termsOfService': 'Terms of Service',
      'aboutApp': 'About Easy!Appointments',
      'pushNotifications': 'Push Notifications',
      'emailNotifications': 'Email Notifications',
      'appointmentReminders': 'Appointment Reminders',
      'receiveReminders': 'Receive appointment reminders',
      'receiveEmailUpdates': 'Receive email updates',
      'getReminders': 'Get reminders before appointments',
      'languageSetTo': 'Language set to',
      'selectLanguage': 'Select Language',
      'selectTheme': 'Select Theme',
      'systemDefault': 'System Default',
      'light': 'Light',
      'dark': 'Dark',
      'themeSetTo': 'Theme set to',
      'pushNotificationsEnabled': 'Push notifications enabled',
      'pushNotificationsDisabled': 'Push notifications disabled',
      'emailNotificationsEnabled': 'Email notifications enabled',
      'emailNotificationsDisabled': 'Email notifications disabled',
      'remindersEnabled': 'Reminders enabled',
      'remindersDisabled': 'Reminders disabled',
      'aboutDescription': 'Easy!Appointments is a highly customizable web application that allows customers to book appointments with you via a sophisticated web interface.',
      'openSourceLicense': 'Open Source - GPL-3.0 License',
      'scheduleWithEase': 'Schedule with ease',
      'checkingConfiguration': 'Checking configuration...',
      'connectingToServer': 'Connecting to server...',
      'newAppointmentNotification': 'New Appointment',
      'appointmentUpdatedNotification': 'Appointment Updated',
      'appointmentCancelledNotification': 'Appointment Cancelled',
      'providerStatusChangedNotification': 'Provider Status Changed',
      'notificationDefault': 'Notification',
      'youHaveNewNotification': 'You have a new notification',
      'customerBookedService': 'booked',
      'appointmentWasUpdated': 'appointment was updated',
      'appointmentWasCancelled': 'appointment was cancelled',
      'isNow': 'is now',

      // Logout
      'signOut': 'Sign Out',
      'confirmSignOut': 'Are you sure you want to sign out?',

      // Errors
      'networkError': 'No internet connection',
      'checkConnectionAndRetry': 'Please check your connection and try again.',
      'serverError': 'Server error',
      'somethingWentWrong': 'Something went wrong. Please try again later.',
      'notFound': 'Not found',
      'userNotFound': 'User not found',
      'invalidPassword': 'Current password is incorrect',
      'newPasswordTooWeak': 'New password is too weak',
      'missingFields': 'Missing required fields',
      'tokenExpired': 'Token expired',
      'invalidToken': 'Invalid token',
      'pageNotFound': 'Page not found',
      'noNotifications': 'No notifications',
      'noNotificationsDescription': 'You\'ll see notifications here when they arrive',
      'clear': 'Clear',
      'justNow': 'Just now',
      'minutesAgo': 'm ago',
      'hoursAgo': 'h ago',
      'daysAgo': 'd ago',
      'unknownError': 'Unknown error',
      'connectionError': 'Connection error',
      'sessionExpired': 'Session expired',
      'failedToLoadStatusOptions': 'Failed to load status options from server',
      'failedToLoadFieldSettings': 'Failed to load field settings from server',

      // Server Setup
      'serverSetup': 'Server Setup',
      'enterServerUrl': 'Enter server URL',
      'testConnection': 'Test Connection',
      'connectionSuccessful': 'Connection successful',
      'connectionFailed': 'Connection failed',
      'welcomeToEasyAppointments': 'Welcome to Easy!Appointments',
      'serverConfiguration': 'Server Configuration',
      'pleaseEnterServerUrl': 'Please enter your server URL to get started.',
      'updateServerSettings': 'Update your server connection settings.',
      'serverUrl': 'Server URL',
      'serverUrlHint': 'https://appointments.example.com',
      'pleaseEnterServerUrlError': 'Please enter the server URL',
      'pleaseEnterValidUrl': 'Please enter a valid URL',
      'serverUrlHelp': 'Enter the URL of your Easy!Appointments server.\\nExample: https://appointments.company.com',
      'connectionSuccessfulMessage': 'Connection successful! Server is reachable.',
      'testing': 'Testing...',
      'connecting': 'Connecting...',
      'saveAndContinue': 'Save & Continue',
      'failedToSaveConfig': 'Failed to save configuration',

      // Appointment Details
      'deleteAppointment': 'Delete Appointment',
      'confirmDeleteAppointment': 'Are you sure you want to delete this appointment? This action cannot be undone.',
      'appointmentDeleted': 'Appointment deleted successfully',
      'failedToDelete': 'Failed to delete',
      'appointmentNotFound': 'Appointment not found',

      // Two-Factor Authentication
      'twoFactorVerification': 'Two-Factor Authentication',
      'enterVerificationCode': 'Enter Verification Code',
      'enterCodeFromAuthenticator': 'Enter the 6-digit code from your authenticator app',
      'rememberThisDevice': 'Remember this device',
      'rememberDeviceFor30Days': 'Skip 2FA verification on this device for 30 days',
      'verify': 'Verify',
      'useRecoveryCode': 'Use Recovery Code',
      'useAuthenticatorCode': 'Use Authenticator Code',
      'enterRecoveryCode': 'Enter Recovery Code',
      'enterRecoveryCodeDescription': 'Enter one of your recovery codes',
      'recoveryCode': 'Recovery Code',
      'invalidCode': 'Invalid verification code',
      'tooManyAttempts': 'Too many attempts. Please try again later.',
    },
    'pt': {
      // General
      'appName': 'Easy!Appointments',
      'loading': 'Carregando...',
      'error': 'Erro',
      'retry': 'Tentar novamente',
      'cancel': 'Cancelar',
      'save': 'Salvar',
      'delete': 'Excluir',
      'confirm': 'Confirmar',
      'close': 'Fechar',
      'ok': 'OK',
      'yes': 'Sim',
      'no': 'Nao',
      'back': 'Voltar',
      'next': 'Proximo',
      'done': 'Concluido',
      'edit': 'Editar',
      'create': 'Criar',
      'update': 'Atualizar',
      'search': 'Buscar',
      'filter': 'Filtrar',
      'refresh': 'Atualizar',
      'tryAgain': 'Tentar novamente',
      'goToHome': 'Ir para Inicio',
      'changeServer': 'Alterar Servidor',
      'noServerConfigured': 'Nenhum servidor configurado',
      'clearAll': 'Limpar Tudo',
      'confirmClearNotifications': 'Tem certeza que deseja limpar todas as notificacoes?',
      'website': 'Site',
      'version': 'Versao',

      // Auth
      'login': 'Entrar',
      'logout': 'Sair',
      'username': 'Usuario',
      'password': 'Senha',
      'welcome': 'Bem-vindo',
      'signInToContinue': 'Entre para continuar',
      'invalidCredentials': 'Credenciais invalidas',
      'forgotPassword': 'Esqueceu a senha?',
      'rememberMe': 'Lembrar-me',
      'pleaseEnterUsername': 'Por favor, informe seu usuario',
      'pleaseEnterPassword': 'Por favor, informe sua senha',
      'passwordMinLength': 'A senha deve ter pelo menos 6 caracteres',
      'contactAdminHelp': 'Entre em contato com o administrador se precisar de ajuda para acessar sua conta.',

      // Profile
      'editProfile': 'Editar Perfil',
      'profileUpdatedSuccessfully': 'Perfil atualizado com sucesso!',
      'personalInformation': 'Informacoes Pessoais',
      'contactInformation': 'Informacoes de Contato',
      'mobile': 'Celular',
      'state': 'Estado',
      'timezone': 'Fuso Horario',
      'noContactInfo': 'Nenhuma informacao de contato disponivel',
      'noUserData': 'Nenhum dado de usuario disponivel',
      'account': 'Conta',
      'manageYourProfile': 'Gerencie seu perfil',
      'changePassword': 'Alterar Senha',
      'passwordChangedSuccessfully': 'Senha alterada com sucesso!',
      'currentPassword': 'Senha Atual',
      'newPassword': 'Nova Senha',
      'confirmNewPassword': 'Confirmar Nova Senha',
      'passwordRequirements': 'A senha deve ter pelo menos 7 caracteres',
      'passwordTooShort': 'A senha deve ter pelo menos 7 caracteres',
      'passwordsDoNotMatch': 'As senhas nao coincidem',
      'newPasswordSameAsCurrent': 'A nova senha deve ser diferente da senha atual',
      'invalidEmail': 'Endereco de e-mail invalido',

      // Navigation
      'calendar': 'Calendario',
      'appointments': 'Agendamentos',
      'settings': 'Configuracoes',
      'notifications': 'Notificacoes',
      'profile': 'Perfil',

      // Appointments
      'newAppointment': 'Novo Agendamento',
      'editAppointment': 'Editar Agendamento',
      'appointmentDetails': 'Detalhes do Agendamento',
      'noAppointments': 'Nenhum agendamento',
      'noAppointmentsDescription': 'Voce nao tem nenhum agendamento marcado.',
      'bookNow': 'Agendar Agora',
      'noResultsFound': 'Nenhum resultado encontrado',
      'noResultsDescription': 'Tente ajustar sua busca ou filtros.',
      'upcomingAppointments': 'Proximos Agendamentos',
      'pastAppointments': 'Agendamentos Anteriores',
      'appointmentCreated': 'Agendamento criado com sucesso!',
      'appointmentUpdated': 'Agendamento atualizado com sucesso!',
      'appointmentCancelled': 'Agendamento cancelado!',
      'createAppointment': 'Criar Agendamento',
      'failedToCreateAppointment': 'Falha ao criar agendamento',
      'failedToLoadData': 'Falha ao carregar dados',

      // Date & Time
      'today': 'Hoje',
      'tomorrow': 'Amanha',
      'yesterday': 'Ontem',
      'selectDate': 'Selecione a Data',
      'selectTime': 'Selecione o Horario',
      'dateAndTime': 'Data e Horario',
      'date': 'Data',
      'time': 'Horario',
      'duration': 'Duracao',
      'minutes': 'minutos',
      'hours': 'horas',
      'startTime': 'Horario Inicio',
      'endTime': 'Horario Fim',
      'startDate': 'Data Inicio',
      'endDate': 'Data Fim',
      'appointmentTime': 'Horario do Agendamento',

      // Recurring Appointments
      'recurringAppointment': 'Agendamento Recorrente',
      'noRecurrence': 'Sem recorrencia',
      'specificDays': 'Dias especificos',
      'weekly': 'Semanal',
      'everyXDays': 'A cada X dias',
      'selectWeekDays': 'Selecione os dias da semana',
      'intervalDays': 'Intervalo (dias)',
      'days': 'dias',
      'monday': 'Seg',
      'tuesday': 'Ter',
      'wednesday': 'Qua',
      'thursday': 'Qui',
      'friday': 'Sex',
      'saturday': 'Sab',
      'sunday': 'Dom',
      'minimumDuration': 'Duracao minima de 5 minutos',
      'pleaseSelectDateRange': 'Selecione as datas de inicio e fim',
      'pleaseSelectWeekDays': 'Selecione pelo menos um dia',
      'invalidInterval': 'Intervalo deve ser entre 1 e 365 dias',
      'enableRecurring': 'Ativar agendamento recorrente',
      'recurringDescription': 'Criar agendamentos nos dias selecionados dentro do periodo',
      'pleaseEnter': 'Por favor, informe',
      'pleaseEnterNotes': 'Por favor, informe as observacoes',
      'appointmentsWillBeCreated': 'agendamentos serao criados',
      'appointmentsCreated': 'agendamentos criados',
      'creatingAppointments': 'Criando agendamentos',
      'creatingAppointmentProgress': 'Criando agendamento',
      'of': 'de',
      'processingPleaseWait': 'Processando, aguarde...',
      'created': 'criados',
      'failed': 'falharam',
      'noAppointmentsGenerated': 'Nenhum agendamento gerado para o periodo selecionado',

      // Service & Provider
      'service': 'Servico',
      'services': 'Servicos',
      'selectService': 'Selecione o Servico',
      'provider': 'Profissional',
      'providers': 'Profissionais',
      'selectProvider': 'Selecione o Profissional',

      // Customer
      'customer': 'Cliente',
      'customers': 'Clientes',
      'customerInformation': 'Informacoes do Cliente',
      'fullName': 'Nome Completo',
      'firstName': 'Primeiro Nome',
      'lastName': 'Sobrenome',
      'email': 'E-mail',
      'phone': 'Telefone',
      'phoneOptional': 'Telefone (opcional)',
      'address': 'Endereco',
      'city': 'Cidade',
      'zipCode': 'CEP',
      'newCustomer': 'Novo Cliente',
      'existingCustomer': 'Cliente Existente',
      'searchCustomer': 'Buscar Cliente',
      'customerNotes': 'Observacoes do Cliente',
      'optional': 'opcional',

      // Notes
      'notes': 'Observacoes',
      'notesOptional': 'Observacoes (Opcional)',
      'addNotes': 'Adicione observacoes adicionais...',
      'appointmentNotes': 'Observacoes do Agendamento',

      // Status
      'status': 'Status',
      'selectStatus': 'Selecione o status',
      'options': 'opcoes',
      'pending': 'Pendente',
      'booked': 'Agendado',
      'confirmed': 'Confirmado',
      'completed': 'Concluido',
      'cancelled': 'Cancelado',
      'noShow': 'Nao Compareceu',
      'unavailability': 'Indisponibilidade',

      // Validation
      'fieldRequired': 'Este campo e obrigatorio',
      'pleaseEnterName': 'Por favor, informe o nome do cliente',
      'pleaseEnterFirstName': 'Por favor, informe o primeiro nome',
      'pleaseEnterLastName': 'Por favor, informe o sobrenome',
      'pleaseEnterEmail': 'Por favor, informe o e-mail',
      'pleaseEnterValidEmail': 'Por favor, informe um e-mail valido',
      'pleaseEnterPhone': 'Por favor, informe o telefone',
      'pleaseEnterAddress': 'Por favor, informe o endereco',
      'pleaseEnterCity': 'Por favor, informe a cidade',
      'pleaseEnterZipCode': 'Por favor, informe o CEP',
      'pleaseSelectService': 'Por favor, selecione um servico',
      'pleaseSelectProvider': 'Por favor, selecione um profissional',
      'pleaseSelectDate': 'Por favor, selecione uma data',
      'pleaseSelectTime': 'Por favor, selecione um horario',

      // Calendar
      'selectDayToView': 'Selecione um dia para ver os agendamentos',
      'tapToCreate': 'Toque em + para criar um novo agendamento',
      'noAppointmentsForDay': 'Sem agendamentos para este dia',
      'with': 'com',

      // Settings
      'language': 'Idioma',
      'theme': 'Tema',
      'themeLight': 'Claro',
      'themeDark': 'Escuro',
      'themeSystem': 'Padrao do Sistema',
      'connection': 'Conexao',
      'server': 'Servidor',
      'preferences': 'Preferencias',
      'about': 'Sobre',
      'privacyPolicy': 'Politica de Privacidade',
      'termsOfService': 'Termos de Servico',
      'aboutApp': 'Sobre Easy!Appointments',
      'pushNotifications': 'Notificacoes Push',
      'emailNotifications': 'Notificacoes por E-mail',
      'appointmentReminders': 'Lembretes de Agendamento',
      'receiveReminders': 'Receber lembretes de agendamentos',
      'receiveEmailUpdates': 'Receber atualizacoes por e-mail',
      'getReminders': 'Receber lembretes antes dos agendamentos',
      'languageSetTo': 'Idioma definido para',
      'selectLanguage': 'Selecionar Idioma',
      'selectTheme': 'Selecionar Tema',
      'systemDefault': 'Padrao do Sistema',
      'light': 'Claro',
      'dark': 'Escuro',
      'themeSetTo': 'Tema definido para',
      'pushNotificationsEnabled': 'Notificacoes push ativadas',
      'pushNotificationsDisabled': 'Notificacoes push desativadas',
      'emailNotificationsEnabled': 'Notificacoes por e-mail ativadas',
      'emailNotificationsDisabled': 'Notificacoes por e-mail desativadas',
      'remindersEnabled': 'Lembretes ativados',
      'remindersDisabled': 'Lembretes desativados',
      'aboutDescription': 'Easy!Appointments e um aplicativo web altamente personalizavel que permite que clientes agendem compromissos com voce atraves de uma interface web sofisticada.',
      'openSourceLicense': 'Codigo Aberto - Licenca GPL-3.0',
      'scheduleWithEase': 'Agende com facilidade',
      'checkingConfiguration': 'Verificando configuracao...',
      'connectingToServer': 'Conectando ao servidor...',
      'newAppointmentNotification': 'Novo Agendamento',
      'appointmentUpdatedNotification': 'Agendamento Atualizado',
      'appointmentCancelledNotification': 'Agendamento Cancelado',
      'providerStatusChangedNotification': 'Status do Prestador Alterado',
      'notificationDefault': 'Notificacao',
      'youHaveNewNotification': 'Voce tem uma nova notificacao',
      'customerBookedService': 'reservou',
      'appointmentWasUpdated': 'agendamento foi atualizado',
      'appointmentWasCancelled': 'agendamento foi cancelado',
      'isNow': 'agora esta',

      // Logout
      'signOut': 'Sair',
      'confirmSignOut': 'Tem certeza que deseja sair?',

      // Errors
      'networkError': 'Sem conexao com a internet',
      'checkConnectionAndRetry': 'Por favor, verifique sua conexao e tente novamente.',
      'serverError': 'Erro no servidor',
      'somethingWentWrong': 'Algo deu errado. Por favor, tente novamente mais tarde.',
      'notFound': 'Nao encontrado',
      'userNotFound': 'Usuario nao encontrado',
      'invalidPassword': 'A senha atual esta incorreta',
      'newPasswordTooWeak': 'A nova senha e muito fraca',
      'missingFields': 'Campos obrigatorios faltando',
      'tokenExpired': 'Token expirado',
      'invalidToken': 'Token invalido',
      'pageNotFound': 'Pagina nao encontrada',
      'noNotifications': 'Sem notificacoes',
      'noNotificationsDescription': 'Voce vera as notificacoes aqui quando chegarem',
      'clear': 'Limpar',
      'justNow': 'Agora',
      'minutesAgo': 'm atras',
      'hoursAgo': 'h atras',
      'daysAgo': 'd atras',
      'unknownError': 'Erro desconhecido',
      'connectionError': 'Erro de conexao',
      'sessionExpired': 'Sessao expirada',
      'failedToLoadStatusOptions': 'Falha ao carregar opcoes de status do servidor',
      'failedToLoadFieldSettings': 'Falha ao carregar configuracoes de campos do servidor',

      // Server Setup
      'serverSetup': 'Configuracao do Servidor',
      'enterServerUrl': 'Informe a URL do servidor',
      'testConnection': 'Testar Conexao',
      'connectionSuccessful': 'Conexao bem-sucedida',
      'connectionFailed': 'Falha na conexao',
      'welcomeToEasyAppointments': 'Bem-vindo ao Easy!Appointments',
      'serverConfiguration': 'Configuracao do Servidor',
      'pleaseEnterServerUrl': 'Informe a URL do seu servidor para comecar.',
      'updateServerSettings': 'Atualize as configuracoes de conexao do servidor.',
      'serverUrl': 'URL do Servidor',
      'serverUrlHint': 'https://agendamentos.exemplo.com',
      'pleaseEnterServerUrlError': 'Por favor, informe a URL do servidor',
      'pleaseEnterValidUrl': 'Por favor, informe uma URL valida',
      'serverUrlHelp': 'Informe a URL do seu servidor Easy!Appointments.\\nExemplo: https://agendamentos.empresa.com',
      'connectionSuccessfulMessage': 'Conexao bem-sucedida! Servidor acessivel.',
      'testing': 'Testando...',
      'connecting': 'Conectando...',
      'saveAndContinue': 'Salvar e Continuar',
      'failedToSaveConfig': 'Falha ao salvar configuracao',

      // Appointment Details
      'deleteAppointment': 'Excluir Agendamento',
      'confirmDeleteAppointment': 'Tem certeza que deseja excluir este agendamento? Esta acao nao pode ser desfeita.',
      'appointmentDeleted': 'Agendamento excluido com sucesso',
      'failedToDelete': 'Falha ao excluir',
      'appointmentNotFound': 'Agendamento nao encontrado',

      // Two-Factor Authentication
      'twoFactorVerification': 'Autenticacao em Dois Fatores',
      'enterVerificationCode': 'Digite o Codigo de Verificacao',
      'enterCodeFromAuthenticator': 'Digite o codigo de 6 digitos do seu aplicativo autenticador',
      'rememberThisDevice': 'Lembrar este dispositivo',
      'rememberDeviceFor30Days': 'Pular verificacao 2FA neste dispositivo por 30 dias',
      'verify': 'Verificar',
      'useRecoveryCode': 'Usar Codigo de Recuperacao',
      'useAuthenticatorCode': 'Usar Codigo do Autenticador',
      'enterRecoveryCode': 'Digite o Codigo de Recuperacao',
      'enterRecoveryCodeDescription': 'Digite um dos seus codigos de recuperacao',
      'recoveryCode': 'Codigo de Recuperacao',
      'invalidCode': 'Codigo de verificacao invalido',
      'tooManyAttempts': 'Muitas tentativas. Por favor, tente novamente mais tarde.',
    },
    'es': {
      // General
      'appName': 'Easy!Appointments',
      'loading': 'Cargando...',
      'error': 'Error',
      'retry': 'Reintentar',
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'confirm': 'Confirmar',
      'close': 'Cerrar',
      'ok': 'OK',
      'yes': 'Si',
      'no': 'No',
      'back': 'Volver',
      'next': 'Siguiente',
      'done': 'Hecho',
      'edit': 'Editar',
      'create': 'Crear',
      'update': 'Actualizar',
      'search': 'Buscar',
      'filter': 'Filtrar',
      'refresh': 'Actualizar',
      'tryAgain': 'Intentar de nuevo',
      'goToHome': 'Ir al Inicio',
      'changeServer': 'Cambiar Servidor',
      'noServerConfigured': 'Ningun servidor configurado',
      'clearAll': 'Limpiar Todo',
      'confirmClearNotifications': 'Esta seguro que desea limpiar todas las notificaciones?',
      'website': 'Sitio Web',
      'version': 'Version',

      // Auth
      'login': 'Iniciar Sesion',
      'logout': 'Cerrar Sesion',
      'username': 'Usuario',
      'password': 'Contrasena',
      'welcome': 'Bienvenido',
      'signInToContinue': 'Inicia sesion para continuar',
      'invalidCredentials': 'Credenciales invalidas',
      'forgotPassword': 'Olvidaste la contrasena?',
      'rememberMe': 'Recuerdame',
      'pleaseEnterUsername': 'Por favor, ingrese su usuario',
      'pleaseEnterPassword': 'Por favor, ingrese su contrasena',
      'passwordMinLength': 'La contrasena debe tener al menos 6 caracteres',
      'contactAdminHelp': 'Contacte a su administrador si necesita ayuda para acceder a su cuenta.',

      // Profile
      'editProfile': 'Editar Perfil',
      'profileUpdatedSuccessfully': 'Perfil actualizado con exito!',
      'personalInformation': 'Informacion Personal',
      'contactInformation': 'Informacion de Contacto',
      'mobile': 'Celular',
      'state': 'Estado',
      'timezone': 'Zona Horaria',
      'noContactInfo': 'No hay informacion de contacto disponible',
      'noUserData': 'No hay datos de usuario disponibles',
      'account': 'Cuenta',
      'manageYourProfile': 'Administra tu perfil',
      'changePassword': 'Cambiar Contrasena',
      'passwordChangedSuccessfully': 'Contrasena cambiada con exito!',
      'currentPassword': 'Contrasena Actual',
      'newPassword': 'Nueva Contrasena',
      'confirmNewPassword': 'Confirmar Nueva Contrasena',
      'passwordRequirements': 'La contrasena debe tener al menos 7 caracteres',
      'passwordTooShort': 'La contrasena debe tener al menos 7 caracteres',
      'passwordsDoNotMatch': 'Las contrasenas no coinciden',
      'newPasswordSameAsCurrent': 'La nueva contrasena debe ser diferente de la actual',
      'invalidEmail': 'Direccion de correo invalida',

      // Navigation
      'calendar': 'Calendario',
      'appointments': 'Citas',
      'settings': 'Configuracion',
      'notifications': 'Notificaciones',
      'profile': 'Perfil',

      // Appointments
      'newAppointment': 'Nueva Cita',
      'editAppointment': 'Editar Cita',
      'appointmentDetails': 'Detalles de la Cita',
      'noAppointments': 'Sin citas',
      'noAppointmentsDescription': 'No tienes ninguna cita programada.',
      'bookNow': 'Reservar Ahora',
      'noResultsFound': 'No se encontraron resultados',
      'noResultsDescription': 'Intenta ajustar tu busqueda o filtros.',
      'upcomingAppointments': 'Proximas Citas',
      'pastAppointments': 'Citas Anteriores',
      'appointmentCreated': 'Cita creada con exito!',
      'appointmentUpdated': 'Cita actualizada con exito!',
      'appointmentCancelled': 'Cita cancelada!',
      'createAppointment': 'Crear Cita',
      'failedToCreateAppointment': 'Error al crear cita',
      'failedToLoadData': 'Error al cargar datos',

      // Date & Time
      'today': 'Hoy',
      'tomorrow': 'Manana',
      'yesterday': 'Ayer',
      'selectDate': 'Seleccionar Fecha',
      'selectTime': 'Seleccionar Hora',
      'dateAndTime': 'Fecha y Hora',
      'date': 'Fecha',
      'time': 'Hora',
      'duration': 'Duracion',
      'minutes': 'minutos',
      'hours': 'horas',
      'startTime': 'Hora Inicio',
      'endTime': 'Hora Fin',
      'startDate': 'Fecha Inicio',
      'endDate': 'Fecha Fin',
      'appointmentTime': 'Hora de la Cita',

      // Recurring Appointments
      'recurringAppointment': 'Cita Recurrente',
      'noRecurrence': 'Sin recurrencia',
      'specificDays': 'Dias especificos',
      'weekly': 'Semanal',
      'everyXDays': 'Cada X dias',
      'selectWeekDays': 'Seleccione los dias de la semana',
      'intervalDays': 'Intervalo (dias)',
      'days': 'dias',
      'monday': 'Lun',
      'tuesday': 'Mar',
      'wednesday': 'Mie',
      'thursday': 'Jue',
      'friday': 'Vie',
      'saturday': 'Sab',
      'sunday': 'Dom',
      'minimumDuration': 'La duracion minima es de 5 minutos',
      'pleaseSelectDateRange': 'Seleccione las fechas de inicio y fin',
      'pleaseSelectWeekDays': 'Seleccione al menos un dia',
      'invalidInterval': 'El intervalo debe ser entre 1 y 365 dias',
      'enableRecurring': 'Activar cita recurrente',
      'recurringDescription': 'Crear citas en los dias seleccionados dentro del periodo',
      'pleaseEnter': 'Por favor, ingrese',
      'pleaseEnterNotes': 'Por favor, ingrese las notas',
      'appointmentsWillBeCreated': 'citas seran creadas',
      'appointmentsCreated': 'citas creadas',
      'creatingAppointments': 'Creando citas',
      'creatingAppointmentProgress': 'Creando cita',
      'of': 'de',
      'processingPleaseWait': 'Procesando, espere...',
      'created': 'creadas',
      'failed': 'fallaron',
      'noAppointmentsGenerated': 'No se generaron citas para el periodo seleccionado',

      // Service & Provider
      'service': 'Servicio',
      'services': 'Servicios',
      'selectService': 'Seleccionar Servicio',
      'provider': 'Proveedor',
      'providers': 'Proveedores',
      'selectProvider': 'Seleccionar Proveedor',

      // Customer
      'customer': 'Cliente',
      'customers': 'Clientes',
      'customerInformation': 'Informacion del Cliente',
      'fullName': 'Nombre Completo',
      'firstName': 'Nombre',
      'lastName': 'Apellido',
      'email': 'Correo',
      'phone': 'Telefono',
      'phoneOptional': 'Telefono (opcional)',
      'address': 'Direccion',
      'city': 'Ciudad',
      'zipCode': 'Codigo Postal',
      'newCustomer': 'Nuevo Cliente',
      'existingCustomer': 'Cliente Existente',
      'searchCustomer': 'Buscar Cliente',
      'customerNotes': 'Notas del Cliente',
      'optional': 'opcional',

      // Notes
      'notes': 'Notas',
      'notesOptional': 'Notas (Opcional)',
      'addNotes': 'Agregar notas adicionales...',
      'appointmentNotes': 'Notas de la Cita',

      // Status
      'status': 'Estado',
      'selectStatus': 'Seleccionar estado',
      'options': 'opciones',
      'pending': 'Pendiente',
      'booked': 'Reservado',
      'confirmed': 'Confirmado',
      'completed': 'Completado',
      'cancelled': 'Cancelado',
      'noShow': 'No Asistio',
      'unavailability': 'No Disponible',

      // Validation
      'fieldRequired': 'Este campo es obligatorio',
      'pleaseEnterName': 'Por favor, ingrese el nombre del cliente',
      'pleaseEnterFirstName': 'Por favor, ingrese el nombre',
      'pleaseEnterLastName': 'Por favor, ingrese el apellido',
      'pleaseEnterEmail': 'Por favor, ingrese el correo',
      'pleaseEnterValidEmail': 'Por favor, ingrese un correo valido',
      'pleaseEnterPhone': 'Por favor, ingrese el telefono',
      'pleaseEnterAddress': 'Por favor, ingrese la direccion',
      'pleaseEnterCity': 'Por favor, ingrese la ciudad',
      'pleaseEnterZipCode': 'Por favor, ingrese el codigo postal',
      'pleaseSelectService': 'Por favor, seleccione un servicio',
      'pleaseSelectProvider': 'Por favor, seleccione un proveedor',
      'pleaseSelectDate': 'Por favor, seleccione una fecha',
      'pleaseSelectTime': 'Por favor, seleccione una hora',

      // Calendar
      'selectDayToView': 'Seleccione un dia para ver las citas',
      'tapToCreate': 'Toque + para crear una nueva cita',
      'noAppointmentsForDay': 'Sin citas para este dia',
      'with': 'con',

      // Settings
      'language': 'Idioma',
      'theme': 'Tema',
      'themeLight': 'Claro',
      'themeDark': 'Oscuro',
      'themeSystem': 'Predeterminado del Sistema',
      'connection': 'Conexion',
      'server': 'Servidor',
      'preferences': 'Preferencias',
      'about': 'Acerca de',
      'privacyPolicy': 'Politica de Privacidad',
      'termsOfService': 'Terminos de Servicio',
      'aboutApp': 'Acerca de Easy!Appointments',
      'pushNotifications': 'Notificaciones Push',
      'emailNotifications': 'Notificaciones por Correo',
      'appointmentReminders': 'Recordatorios de Citas',
      'receiveReminders': 'Recibir recordatorios de citas',
      'receiveEmailUpdates': 'Recibir actualizaciones por correo',
      'getReminders': 'Recibir recordatorios antes de las citas',
      'languageSetTo': 'Idioma establecido en',
      'selectLanguage': 'Seleccionar Idioma',
      'selectTheme': 'Seleccionar Tema',
      'systemDefault': 'Predeterminado del Sistema',
      'light': 'Claro',
      'dark': 'Oscuro',
      'themeSetTo': 'Tema establecido en',
      'pushNotificationsEnabled': 'Notificaciones push activadas',
      'pushNotificationsDisabled': 'Notificaciones push desactivadas',
      'emailNotificationsEnabled': 'Notificaciones por correo activadas',
      'emailNotificationsDisabled': 'Notificaciones por correo desactivadas',
      'remindersEnabled': 'Recordatorios activados',
      'remindersDisabled': 'Recordatorios desactivados',
      'aboutDescription': 'Easy!Appointments es una aplicacion web altamente personalizable que permite a los clientes reservar citas contigo a traves de una interfaz web sofisticada.',
      'openSourceLicense': 'Codigo Abierto - Licencia GPL-3.0',
      'scheduleWithEase': 'Agenda con facilidad',
      'checkingConfiguration': 'Verificando configuracion...',
      'connectingToServer': 'Conectando al servidor...',
      'newAppointmentNotification': 'Nueva Cita',
      'appointmentUpdatedNotification': 'Cita Actualizada',
      'appointmentCancelledNotification': 'Cita Cancelada',
      'providerStatusChangedNotification': 'Estado del Proveedor Cambiado',
      'notificationDefault': 'Notificacion',
      'youHaveNewNotification': 'Tienes una nueva notificacion',
      'customerBookedService': 'reservo',
      'appointmentWasUpdated': 'cita fue actualizada',
      'appointmentWasCancelled': 'cita fue cancelada',
      'isNow': 'ahora esta',

      // Logout
      'signOut': 'Cerrar Sesion',
      'confirmSignOut': 'Estas seguro de que deseas cerrar sesion?',

      // Errors
      'networkError': 'Sin conexion a internet',
      'checkConnectionAndRetry': 'Por favor, verifique su conexion e intente nuevamente.',
      'serverError': 'Error del servidor',
      'somethingWentWrong': 'Algo salio mal. Por favor, intente nuevamente mas tarde.',
      'notFound': 'No encontrado',
      'userNotFound': 'Usuario no encontrado',
      'invalidPassword': 'La contrasena actual es incorrecta',
      'newPasswordTooWeak': 'La nueva contrasena es muy debil',
      'missingFields': 'Faltan campos obligatorios',
      'tokenExpired': 'Token expirado',
      'invalidToken': 'Token invalido',
      'pageNotFound': 'Pagina no encontrada',
      'noNotifications': 'Sin notificaciones',
      'noNotificationsDescription': 'Veras las notificaciones aqui cuando lleguen',
      'clear': 'Limpiar',
      'justNow': 'Ahora',
      'minutesAgo': 'm atras',
      'hoursAgo': 'h atras',
      'daysAgo': 'd atras',
      'unknownError': 'Error desconocido',
      'connectionError': 'Error de conexion',
      'sessionExpired': 'Sesion expirada',
      'failedToLoadStatusOptions': 'Error al cargar opciones de estado del servidor',
      'failedToLoadFieldSettings': 'Error al cargar configuracion de campos del servidor',

      // Server Setup
      'serverSetup': 'Configuracion del Servidor',
      'enterServerUrl': 'Ingrese la URL del servidor',
      'testConnection': 'Probar Conexion',
      'connectionSuccessful': 'Conexion exitosa',
      'connectionFailed': 'Conexion fallida',
      'welcomeToEasyAppointments': 'Bienvenido a Easy!Appointments',
      'serverConfiguration': 'Configuracion del Servidor',
      'pleaseEnterServerUrl': 'Ingrese la URL de su servidor para comenzar.',
      'updateServerSettings': 'Actualice la configuracion de conexion del servidor.',
      'serverUrl': 'URL del Servidor',
      'serverUrlHint': 'https://citas.ejemplo.com',
      'pleaseEnterServerUrlError': 'Por favor, ingrese la URL del servidor',
      'pleaseEnterValidUrl': 'Por favor, ingrese una URL valida',
      'serverUrlHelp': 'Ingrese la URL de su servidor Easy!Appointments.\\nEjemplo: https://citas.empresa.com',
      'connectionSuccessfulMessage': 'Conexion exitosa! Servidor accesible.',
      'testing': 'Probando...',
      'connecting': 'Conectando...',
      'saveAndContinue': 'Guardar y Continuar',
      'failedToSaveConfig': 'Error al guardar configuracion',

      // Appointment Details
      'deleteAppointment': 'Eliminar Cita',
      'confirmDeleteAppointment': 'Esta seguro de que desea eliminar esta cita? Esta accion no se puede deshacer.',
      'appointmentDeleted': 'Cita eliminada con exito',
      'failedToDelete': 'Error al eliminar',
      'appointmentNotFound': 'Cita no encontrada',

      // Two-Factor Authentication
      'twoFactorVerification': 'Autenticacion de Dos Factores',
      'enterVerificationCode': 'Ingrese el Codigo de Verificacion',
      'enterCodeFromAuthenticator': 'Ingrese el codigo de 6 digitos de su aplicacion autenticadora',
      'rememberThisDevice': 'Recordar este dispositivo',
      'rememberDeviceFor30Days': 'Omitir verificacion 2FA en este dispositivo por 30 dias',
      'verify': 'Verificar',
      'useRecoveryCode': 'Usar Codigo de Recuperacion',
      'useAuthenticatorCode': 'Usar Codigo del Autenticador',
      'enterRecoveryCode': 'Ingrese el Codigo de Recuperacion',
      'enterRecoveryCodeDescription': 'Ingrese uno de sus codigos de recuperacion',
      'recoveryCode': 'Codigo de Recuperacion',
      'invalidCode': 'Codigo de verificacion invalido',
      'tooManyAttempts': 'Demasiados intentos. Por favor, intente nuevamente mas tarde.',
    },
  };

  /// Get a translated string by key.
  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Common getters
  String get appName => get('appName');
  String get loading => get('loading');
  String get error => get('error');
  String get retry => get('retry');
  String get cancel => get('cancel');
  String get save => get('save');
  String get delete => get('delete');
  String get confirm => get('confirm');
  String get close => get('close');
  String get ok => get('ok');
  String get yes => get('yes');
  String get no => get('no');
  String get back => get('back');
  String get next => get('next');
  String get done => get('done');
  String get edit => get('edit');
  String get create => get('create');
  String get update => get('update');
  String get search => get('search');
  String get filter => get('filter');
  String get refresh => get('refresh');
  String get tryAgain => get('tryAgain');
  String get goToHome => get('goToHome');
  String get changeServer => get('changeServer');
  String get clearAll => get('clearAll');
  String get confirmClearNotifications => get('confirmClearNotifications');
  String get website => get('website');
  String get version => get('version');

  // Auth getters
  String get login => get('login');
  String get logout => get('logout');
  String get username => get('username');
  String get password => get('password');
  String get welcome => get('welcome');
  String get signInToContinue => get('signInToContinue');
  String get invalidCredentials => get('invalidCredentials');
  String get forgotPassword => get('forgotPassword');
  String get rememberMe => get('rememberMe');

  // Navigation getters
  String get calendar => get('calendar');
  String get appointments => get('appointments');
  String get settings => get('settings');
  String get notifications => get('notifications');
  String get profile => get('profile');

  // Appointments getters
  String get newAppointment => get('newAppointment');
  String get editAppointment => get('editAppointment');
  String get appointmentDetails => get('appointmentDetails');
  String get noAppointments => get('noAppointments');
  String get noAppointmentsDescription => get('noAppointmentsDescription');
  String get bookNow => get('bookNow');
  String get noResultsFound => get('noResultsFound');
  String get noResultsDescription => get('noResultsDescription');
  String get upcomingAppointments => get('upcomingAppointments');
  String get pastAppointments => get('pastAppointments');
  String get appointmentCreated => get('appointmentCreated');
  String get appointmentUpdated => get('appointmentUpdated');
  String get appointmentCancelled => get('appointmentCancelled');
  String get createAppointment => get('createAppointment');
  String get failedToCreateAppointment => get('failedToCreateAppointment');
  String get failedToLoadData => get('failedToLoadData');

  // Date & Time getters
  String get today => get('today');
  String get tomorrow => get('tomorrow');
  String get yesterday => get('yesterday');
  String get selectDate => get('selectDate');
  String get selectTime => get('selectTime');
  String get dateAndTime => get('dateAndTime');
  String get date => get('date');
  String get time => get('time');
  String get duration => get('duration');
  String get minutes => get('minutes');
  String get hours => get('hours');

  // Service & Provider getters
  String get service => get('service');
  String get services => get('services');
  String get selectService => get('selectService');
  String get provider => get('provider');
  String get providers => get('providers');
  String get selectProvider => get('selectProvider');

  // Customer getters
  String get customer => get('customer');
  String get customers => get('customers');
  String get customerInformation => get('customerInformation');
  String get fullName => get('fullName');
  String get firstName => get('firstName');
  String get lastName => get('lastName');
  String get email => get('email');
  String get phone => get('phone');
  String get phoneOptional => get('phoneOptional');
  String get address => get('address');
  String get city => get('city');
  String get zipCode => get('zipCode');
  String get newCustomer => get('newCustomer');
  String get existingCustomer => get('existingCustomer');
  String get searchCustomer => get('searchCustomer');
  String get customerNotes => get('customerNotes');
  String get optional => get('optional');

  // Notes getters
  String get notes => get('notes');
  String get notesOptional => get('notesOptional');
  String get addNotes => get('addNotes');
  String get appointmentNotes => get('appointmentNotes');

  // Status getters
  String get status => get('status');
  String get pending => get('pending');
  String get booked => get('booked');
  String get confirmed => get('confirmed');
  String get completed => get('completed');
  String get cancelled => get('cancelled');
  String get noShow => get('noShow');
  String get unavailability => get('unavailability');

  // Validation getters
  String get fieldRequired => get('fieldRequired');
  String get pleaseEnterName => get('pleaseEnterName');
  String get pleaseEnterFirstName => get('pleaseEnterFirstName');
  String get pleaseEnterLastName => get('pleaseEnterLastName');
  String get pleaseEnterEmail => get('pleaseEnterEmail');
  String get pleaseEnterValidEmail => get('pleaseEnterValidEmail');
  String get pleaseEnterPhone => get('pleaseEnterPhone');
  String get pleaseEnterAddress => get('pleaseEnterAddress');
  String get pleaseEnterCity => get('pleaseEnterCity');
  String get pleaseEnterZipCode => get('pleaseEnterZipCode');
  String get pleaseSelectService => get('pleaseSelectService');
  String get pleaseSelectProvider => get('pleaseSelectProvider');
  String get pleaseSelectDate => get('pleaseSelectDate');
  String get pleaseSelectTime => get('pleaseSelectTime');

  // Calendar getters
  String get selectDayToView => get('selectDayToView');
  String get tapToCreate => get('tapToCreate');
  String get noAppointmentsForDay => get('noAppointmentsForDay');

  // Settings getters
  String get language => get('language');
  String get theme => get('theme');
  String get themeLight => get('themeLight');
  String get themeDark => get('themeDark');
  String get themeSystem => get('themeSystem');
  String get connection => get('connection');
  String get server => get('server');
  String get preferences => get('preferences');
  String get about => get('about');
  String get privacyPolicy => get('privacyPolicy');
  String get termsOfService => get('termsOfService');
  String get aboutApp => get('aboutApp');
  String get pushNotifications => get('pushNotifications');
  String get emailNotifications => get('emailNotifications');
  String get appointmentReminders => get('appointmentReminders');
  String get receiveReminders => get('receiveReminders');
  String get receiveEmailUpdates => get('receiveEmailUpdates');
  String get getReminders => get('getReminders');
  String get languageSetTo => get('languageSetTo');

  // Logout getters
  String get signOut => get('signOut');
  String get confirmSignOut => get('confirmSignOut');

  // Error getters
  String get networkError => get('networkError');
  String get serverError => get('serverError');
  String get unknownError => get('unknownError');
  String get connectionError => get('connectionError');
  String get sessionExpired => get('sessionExpired');
  String get userNotFound => get('userNotFound');
  String get invalidPassword => get('invalidPassword');
  String get newPasswordTooWeak => get('newPasswordTooWeak');
  String get missingFields => get('missingFields');
  String get tokenExpired => get('tokenExpired');
  String get invalidToken => get('invalidToken');

  // Server Setup getters
  String get serverSetup => get('serverSetup');
  String get enterServerUrl => get('enterServerUrl');
  String get testConnection => get('testConnection');
  String get connectionSuccessful => get('connectionSuccessful');
  String get connectionFailed => get('connectionFailed');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'pt', 'es'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => true;
}
