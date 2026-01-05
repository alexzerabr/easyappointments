import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/injection/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// Page for creating a new appointment.
class NewAppointmentPage extends StatefulWidget {
  const NewAppointmentPage({super.key});

  @override
  State<NewAppointmentPage> createState() => _NewAppointmentPageState();
}

class _NewAppointmentPageState extends State<NewAppointmentPage> {
  final _formKey = GlobalKey<FormState>();

  // Customer fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _customerNotesController = TextEditingController();

  // Appointment fields
  final _notesController = TextEditingController();

  // Date and Time
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);

  // Recurring appointment fields
  bool _isRecurring = false;
  DateTime? _recurringStartDate;
  DateTime? _recurringEndDate;
  final Set<int> _selectedWeekDays = {}; // 1=Monday, 7=Sunday

  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedProvider;
  Map<String, dynamic>? _selectedCustomer;
  String? _selectedStatus;

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _providers = [];
  List<Map<String, dynamic>> _customers = [];
  List<String> _statusOptions = [];
  Map<String, dynamic> _settings = {};

  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isLoadingCustomers = false;
  bool _isNewCustomer = true;
  String? _errorMessage;

  // Display field settings (visibility)
  bool _displayFirstName = true;
  bool _displayLastName = true;
  bool _displayEmail = true;
  bool _displayPhoneNumber = true;
  bool _displayAddress = true;
  bool _displayCity = true;
  bool _displayZipCode = true;
  bool _displayNotes = true;

  // Required field settings (defaults match backend migration 022)
  bool _requireFirstName = true;
  bool _requireLastName = true;
  bool _requireEmail = true;
  bool _requirePhoneNumber = true;  // Backend default is true!
  bool _requireAddress = false;
  bool _requireCity = false;
  bool _requireZipCode = false;
  bool _requireNotes = false;

  // Custom fields
  final List<TextEditingController> _customFieldControllers = List.generate(5, (_) => TextEditingController());
  final List<bool> _displayCustomFields = [false, false, false, false, false];
  final List<bool> _requireCustomFields = [false, false, false, false, false];
  final List<String> _labelCustomFields = ['', '', '', '', ''];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    try {
      final apiClient = getIt<ApiClient>();

      // Load services
      final servicesResponse = await apiClient.get<List<dynamic>>(
        ApiConstants.services,
      );

      // Load providers
      final providersResponse = await apiClient.get<List<dynamic>>(
        ApiConstants.providers,
      );

      // Load customers
      final customersResponse = await apiClient.get<List<dynamic>>(
        ApiConstants.customers,
      );

      // Load appointment status options from specific endpoint
      List<String>? statusOptions;
      Map<String, dynamic> settingsData = {};

      try {
        final statusResponse = await apiClient.get<Map<String, dynamic>>(
          ApiConstants.appointmentStatusOptions,
        );

        if (kDebugMode) {
          debugPrint('[NewAppointment] Status options response: $statusResponse');
        }

        final value = statusResponse['value'];
        if (value != null) {
          if (value is String && value.isNotEmpty) {
            // Parse JSON string array like '["Booked","Confirmed"]'
            final decoded = jsonDecode(value);
            if (decoded is List && decoded.isNotEmpty) {
              statusOptions = decoded.map((e) => e.toString()).toList();
              if (kDebugMode) {
                debugPrint('[NewAppointment] Loaded status options: $statusOptions');
              }
            }
          } else if (value is List && value.isNotEmpty) {
            statusOptions = value.map((e) => e.toString()).toList();
            if (kDebugMode) {
              debugPrint('[NewAppointment] Loaded status options from List: $statusOptions');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[NewAppointment] Failed to load status options: $e');
        }
      }

      // Load general settings for required field configurations (NO FALLBACK - must load from backend)
      // API has default limit of 20, so we need to request more to get all settings
      final settingsResponse = await apiClient.get<dynamic>('${ApiConstants.settings}?length=100');
      if (kDebugMode) {
        debugPrint('[NewAppointment] Settings response type: ${settingsResponse.runtimeType}');
      }
      if (settingsResponse is List) {
        for (var setting in settingsResponse) {
          if (setting is Map<String, dynamic>) {
            final name = setting['name']?.toString() ?? '';
            final value = setting['value'];
            settingsData[name] = value;
            // Log require/display settings specifically
            if (kDebugMode) {
              if (name.startsWith('require_') || name.startsWith('display_')) {
                debugPrint('[NewAppointment] Setting: $name = $value');
              }
            }
          }
        }
      }
      if (kDebugMode) {
        debugPrint('[NewAppointment] Total settings loaded: ${settingsData.length}');
      }

      // Validate that status options were loaded
      if (statusOptions == null || statusOptions.isEmpty) {
        if (!mounted) return;
        throw Exception(AppLocalizations.of(context).get('failedToLoadStatusOptions'));
      }

      // Validate that field settings were loaded (NO FALLBACK)
      final requiredSettings = [
        'display_first_name', 'display_last_name', 'display_email', 'display_phone_number',
        'display_address', 'display_city', 'display_zip_code', 'display_notes',
        'require_first_name', 'require_last_name', 'require_email', 'require_phone_number',
        'require_address', 'require_city', 'require_zip_code', 'require_notes',
      ];

      final missingSettings = requiredSettings.where((s) => !settingsData.containsKey(s)).toList();
      if (missingSettings.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[NewAppointment] Missing settings: $missingSettings');
        }
        if (!mounted) return;
        throw Exception(AppLocalizations.of(context).get('failedToLoadFieldSettings'));
      }

      setState(() {
        _services = servicesResponse.map((s) => s as Map<String, dynamic>).toList();
        _providers = providersResponse.map((p) => p as Map<String, dynamic>).toList();
        _customers = customersResponse.map((c) => c as Map<String, dynamic>).toList();
        _settings = settingsData;
        _statusOptions = statusOptions!; // Already validated above
        _selectedStatus = statusOptions.first;

        // Helper function to parse boolean settings
        bool parseBool(dynamic value) {
          return value == '1' || value == 1 || value == true || value == 'true';
        }

        // Parse display field settings (visibility) - NO FALLBACK
        _displayFirstName = parseBool(_settings['display_first_name']);
        _displayLastName = parseBool(_settings['display_last_name']);
        _displayEmail = parseBool(_settings['display_email']);
        _displayPhoneNumber = parseBool(_settings['display_phone_number']);
        _displayAddress = parseBool(_settings['display_address']);
        _displayCity = parseBool(_settings['display_city']);
        _displayZipCode = parseBool(_settings['display_zip_code']);
        _displayNotes = parseBool(_settings['display_notes']);

        // Parse required field settings - NO FALLBACK
        _requireFirstName = parseBool(_settings['require_first_name']);
        _requireLastName = parseBool(_settings['require_last_name']);
        _requireEmail = parseBool(_settings['require_email']);
        _requirePhoneNumber = parseBool(_settings['require_phone_number']);
        _requireAddress = parseBool(_settings['require_address']);
        _requireCity = parseBool(_settings['require_city']);
        _requireZipCode = parseBool(_settings['require_zip_code']);
        _requireNotes = parseBool(_settings['require_notes']);

        // Parse custom field settings
        for (int i = 0; i < 5; i++) {
          _displayCustomFields[i] = parseBool(_settings['display_custom_field_${i + 1}']);
          _requireCustomFields[i] = parseBool(_settings['require_custom_field_${i + 1}']);
          _labelCustomFields[i] = _settings['label_custom_field_${i + 1}']?.toString() ?? '';
        }

        if (kDebugMode) {
          debugPrint('[NewAppointment] Display settings loaded - firstName: $_displayFirstName, lastName: $_displayLastName, email: $_displayEmail, phone: $_displayPhoneNumber, address: $_displayAddress, city: $_displayCity, zip: $_displayZipCode, notes: $_displayNotes');
          debugPrint('[NewAppointment] Required settings loaded - firstName: $_requireFirstName, lastName: $_requireLastName, email: $_requireEmail, phone: $_requirePhoneNumber, address: $_requireAddress, city: $_requireCity, zip: $_requireZipCode, notes: $_requireNotes');
        }

        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${AppLocalizations.of(context).failedToLoadData}: ${e.toString()}';
        _isLoadingData = false;
      });
    }
  }

  Future<void> _searchCustomers(String query) async {
    if (query.length < 2) return;

    setState(() {
      _isLoadingCustomers = true;
    });

    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.get<List<dynamic>>(
        ApiConstants.customers,
        queryParameters: {'q': query},
      );

      setState(() {
        _customers = response.map((c) => c as Map<String, dynamic>).toList();
        _isLoadingCustomers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCustomers = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _customerNotesController.dispose();
    _notesController.dispose();
    for (var controller in _customFieldControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateEndTimeFromService() {
    if (_selectedService != null) {
      final duration = _selectedService!['duration'] as int? ?? 30;
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = startMinutes + duration;
      setState(() {
        _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
      _updateEndTimeFromService();
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _selectRecurringStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _recurringStartDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _recurringStartDate = picked;
      });
    }
  }

  Future<void> _selectRecurringEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _recurringEndDate ?? (_recurringStartDate ?? DateTime.now()).add(const Duration(days: 30)),
      firstDate: _recurringStartDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _recurringEndDate = picked;
      });
    }
  }

  void _selectExistingCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomer = customer;
      _firstNameController.text = customer['firstName'] ?? '';
      _lastNameController.text = customer['lastName'] ?? '';
      _emailController.text = customer['email'] ?? '';
      _phoneController.text = customer['phoneNumber'] ?? customer['phone'] ?? '';
      _addressController.text = customer['address'] ?? '';
      _cityController.text = customer['city'] ?? '';
      _zipController.text = customer['zipCode'] ?? customer['zip'] ?? '';
      _customerNotesController.text = customer['notes'] ?? '';
    });
  }

  void _clearCustomerSelection() {
    setState(() {
      _selectedCustomer = null;
      _firstNameController.clear();
      _lastNameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _cityController.clear();
      _zipController.clear();
      _customerNotesController.clear();
    });
  }

  /// Format datetime for backend: YYYY-MM-DD HH:mm:ss
  String _formatDateTimeForBackend(DateTime date, TimeOfDay time) {
    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute, 0);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  /// Calculate duration in minutes
  int _calculateDuration() {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes - startMinutes;
  }

  /// Generate dates for recurring appointments
  List<DateTime> _generateRecurringDates() {
    if (_recurringStartDate == null || _recurringEndDate == null || _selectedWeekDays.isEmpty) {
      return [];
    }

    final dates = <DateTime>[];
    var currentDate = _recurringStartDate!;

    while (!currentDate.isAfter(_recurringEndDate!)) {
      // weekday: 1=Monday, 7=Sunday (same as ISO)
      if (_selectedWeekDays.contains(currentDate.weekday)) {
        dates.add(currentDate);
      }
      currentDate = currentDate.add(const Duration(days: 1));

      // Safety limit: max 365 appointments
      if (dates.length >= 365) break;
    }

    return dates;
  }

  Future<void> _saveAppointment() async {
    final l10n = AppLocalizations.of(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedService == null) {
      _showError(l10n.pleaseSelectService);
      return;
    }

    if (_selectedProvider == null) {
      _showError(l10n.pleaseSelectProvider);
      return;
    }

    // Validate duration (minimum 5 minutes)
    final duration = _calculateDuration();
    if (duration < 5) {
      _showError(l10n.get('minimumDuration'));
      return;
    }

    // Validate recurring appointment fields
    if (_isRecurring) {
      if (_recurringStartDate == null || _recurringEndDate == null) {
        _showError(l10n.get('pleaseSelectDateRange'));
        return;
      }
      if (_selectedWeekDays.isEmpty) {
        _showError(l10n.get('pleaseSelectWeekDays'));
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = getIt<ApiClient>();
      int customerId;

      if (_isNewCustomer || _selectedCustomer == null) {
        // Create new customer - API expects camelCase: phone (not phoneNumber), zip (not zipCode)
        final customerData = <String, dynamic>{
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'zip': _zipController.text.trim(),
          'notes': _customerNotesController.text.trim(),
        };

        // Add custom fields if they have values
        for (int i = 0; i < 5; i++) {
          if (_displayCustomFields[i] && _customFieldControllers[i].text.trim().isNotEmpty) {
            customerData['customField${i + 1}'] = _customFieldControllers[i].text.trim();
          }
        }

        if (kDebugMode) {
          debugPrint('[NewAppointment] Creating customer with data: $customerData');
        }

        final customerResponse = await apiClient.post<Map<String, dynamic>>(
          ApiConstants.customers,
          data: customerData,
        );

        customerId = customerResponse['id'] as int;
        if (kDebugMode) {
          debugPrint('[NewAppointment] Customer created with ID: $customerId');
        }
      } else {
        customerId = _selectedCustomer!['id'] as int;
      }

      if (_isRecurring) {
        // Create multiple appointments for recurring
        if (kDebugMode) {
          debugPrint('[NewAppointment] Recurring mode - generating dates...');
          debugPrint('[NewAppointment] Start date: $_recurringStartDate');
          debugPrint('[NewAppointment] End date: $_recurringEndDate');
          debugPrint('[NewAppointment] Selected weekdays: $_selectedWeekDays');
        }

        final dates = _generateRecurringDates();
        if (kDebugMode) {
          debugPrint('[NewAppointment] Generated ${dates.length} dates');
        }

        if (dates.isEmpty) {
          _showError(l10n.get('noAppointmentsGenerated'));
          setState(() => _isLoading = false);
          return;
        }

        // Hide the main loading indicator
        setState(() => _isLoading = false);

        // Show progress dialog and create appointments
        if (!mounted) return;
        await _createRecurringAppointmentsWithProgress(
          context: context,
          dates: dates,
          customerId: customerId,
          l10n: l10n,
        );
      } else {
        // Create single appointment
        final appointmentData = {
          'serviceId': _selectedService!['id'],
          'providerId': _selectedProvider!['id'],
          'customerId': customerId,
          'start': _formatDateTimeForBackend(_selectedDate, _startTime),
          'end': _formatDateTimeForBackend(_selectedDate, _endTime),
          'status': _selectedStatus ?? 'Booked',
          'notes': _notesController.text.trim(),
        };

        await apiClient.post<Map<String, dynamic>>(
          ApiConstants.appointments,
          data: appointmentData,
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.appointmentCreated),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${l10n.failedToCreateAppointment}: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Creates recurring appointments with a progress dialog and parallel processing
  Future<void> _createRecurringAppointmentsWithProgress({
    required BuildContext context,
    required List<DateTime> dates,
    required int customerId,
    required AppLocalizations l10n,
  }) async {
    final totalCount = dates.length;
    int completedCount = 0;
    int successCount = 0;
    List<String> errors = [];

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start processing when dialog is shown
            if (completedCount == 0 && successCount == 0 && errors.isEmpty) {
              _processAppointmentsInParallel(
                dates: dates,
                customerId: customerId,
                onProgress: (completed, success, errorList) {
                  if (mounted) {
                    setDialogState(() {
                      completedCount = completed;
                      successCount = success;
                      errors = errorList;
                    });
                  }
                },
                onComplete: () {
                  // Close dialog when done
                  if (Navigator.of(dialogContext).canPop()) {
                    Navigator.of(dialogContext).pop();
                  }
                  // Show result and navigate back
                  _showRecurringResult(successCount, errors, totalCount, l10n);
                },
              );
            }

            final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

            return AlertDialog(
              title: Text(l10n.get('creatingAppointments')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress indicator
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  // Progress text
                  Text(
                    '$completedCount ${l10n.get('of')} $totalCount',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.get('processingPleaseWait'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (successCount > 0 || errors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (successCount > 0) ...[
                          Icon(Icons.check_circle, color: AppColors.success, size: 16),
                          const SizedBox(width: 4),
                          Text('$successCount', style: TextStyle(color: AppColors.success)),
                        ],
                        if (errors.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.error, color: AppColors.error, size: 16),
                          const SizedBox(width: 4),
                          Text('${errors.length}', style: TextStyle(color: AppColors.error)),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Process appointments in parallel with a maximum of 4 concurrent requests
  Future<void> _processAppointmentsInParallel({
    required List<DateTime> dates,
    required int customerId,
    required Function(int completed, int success, List<String> errors) onProgress,
    required VoidCallback onComplete,
  }) async {
    final apiClient = getIt<ApiClient>();
    int completedCount = 0;
    int successCount = 0;
    List<String> errors = [];

    const int parallelLimit = 4; // Process 4 appointments at a time

    // Split dates into chunks
    for (int i = 0; i < dates.length; i += parallelLimit) {
      final chunk = dates.skip(i).take(parallelLimit).toList();

      // Process chunk in parallel
      final futures = chunk.map((date) async {
        try {
          final appointmentData = {
            'serviceId': _selectedService!['id'],
            'providerId': _selectedProvider!['id'],
            'customerId': customerId,
            'start': _formatDateTimeForBackend(date, _startTime),
            'end': _formatDateTimeForBackend(date, _endTime),
            'status': _selectedStatus ?? 'Booked',
            'notes': _notesController.text.trim(),
          };

          if (kDebugMode) {
            debugPrint('[NewAppointment] Creating appointment for ${DateFormat('yyyy-MM-dd').format(date)}');
          }
          await apiClient.post<Map<String, dynamic>>(
            ApiConstants.appointments,
            data: appointmentData,
          );
          return {'success': true, 'date': date};
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[NewAppointment] Failed for ${DateFormat('yyyy-MM-dd').format(date)}: $e');
          }
          return {'success': false, 'date': date, 'error': e.toString()};
        }
      }).toList();

      // Wait for all in this chunk to complete
      final results = await Future.wait(futures);

      // Update counts
      for (final result in results) {
        completedCount++;
        if (result['success'] == true) {
          successCount++;
        } else {
          final date = result['date'] as DateTime;
          errors.add(DateFormat('dd/MM').format(date));
        }
      }

      // Report progress
      onProgress(completedCount, successCount, errors);
    }

    // All done
    onComplete();
  }

  /// Show result message after recurring appointments creation
  void _showRecurringResult(int successCount, List<String> errors, int totalCount, AppLocalizations l10n) {
    if (!mounted) return;

    if (errors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount ${l10n.get('appointmentsCreated')}'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successCount ${l10n.get('created')}, ${errors.length} ${l10n.get('failed')}'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    context.pop(true);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showStatusSelector() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              color: theme.scaffoldBackgroundColor,
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          l10n.status,
                          style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          '${_statusOptions.length} ${l10n.get('options')}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Status list with scrolling
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _statusOptions.length,
                      itemBuilder: (context, index) {
                        final status = _statusOptions[index];
                        final isSelected = status == _selectedStatus;

                        return ListTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(
                            status,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected ? AppColors.primary : theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle, color: AppColors.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedStatus = status;
                            });
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return AppColors.statusConfirmed;
      case 'completed':
        return AppColors.statusCompleted;
      case 'cancelled':
        return AppColors.statusCancelled;
      case 'no-show':
        return AppColors.statusNoShow;
      case 'rescheduled':
        return Colors.orange;
      case 'draft':
        return Colors.grey;
      default:
        return AppColors.statusPending;
    }
  }

  List<Widget> _buildCustomFields() {
    final l10n = AppLocalizations.of(context);
    final widgets = <Widget>[];

    for (int i = 0; i < 5; i++) {
      if (_displayCustomFields[i] && _labelCustomFields[i].isNotEmpty) {
        widgets.add(
          TextFormField(
            controller: _customFieldControllers[i],
            enabled: _isNewCustomer,
            decoration: InputDecoration(
              labelText: _requireCustomFields[i]
                  ? '${_labelCustomFields[i]} *'
                  : '${_labelCustomFields[i]} (${l10n.optional})',
              prefixIcon: const Icon(Icons.edit_note_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (_requireCustomFields[i] && (value == null || value.trim().isEmpty)) {
                return '${l10n.get('pleaseEnter')} ${_labelCustomFields[i]}';
              }
              return null;
            },
          ),
        );
        widgets.add(const SizedBox(height: 16));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.newAppointment),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _services.isEmpty
              ? _buildErrorState()
              : _buildForm(),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.failedToLoadData,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? l10n.unknownError,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final l10n = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Service Selection
          _buildSectionTitle(l10n.service, required: true),
          DropdownButtonFormField<int>(
            initialValue: _selectedService?['id'] as int?,
            decoration: InputDecoration(
              hintText: l10n.selectService,
              prefixIcon: const Icon(Icons.spa_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _services.map((service) {
              final name = service['name'] ?? l10n.service;
              final duration = service['duration'] ?? 30;
              return DropdownMenuItem<int>(
                value: service['id'] as int,
                child: Text('$name ($duration min)'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedService = _services.firstWhere((s) => s['id'] == value);
              });
              _updateEndTimeFromService();
            },
            validator: (value) {
              if (value == null) {
                return l10n.pleaseSelectService;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Provider Selection
          _buildSectionTitle(l10n.provider, required: true),
          DropdownButtonFormField<int>(
            initialValue: _selectedProvider?['id'] as int?,
            decoration: InputDecoration(
              hintText: l10n.selectProvider,
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _providers.map((provider) {
              final firstName = provider['firstName'] ?? '';
              final lastName = provider['lastName'] ?? '';
              return DropdownMenuItem<int>(
                value: provider['id'] as int,
                child: Text('$firstName $lastName'.trim()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProvider = _providers.firstWhere((p) => p['id'] == value);
              });
            },
            validator: (value) {
              if (value == null) {
                return l10n.pleaseSelectProvider;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Status Selection (from backend) - using bottom sheet for scrolling
          _buildSectionTitle(l10n.status, required: true),
          InkWell(
            onTap: () => _showStatusSelector(),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.flag_outlined),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _selectedStatus ?? l10n.get('selectStatus'),
                style: TextStyle(
                  color: _selectedStatus != null
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Theme.of(context).hintColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recurring Appointment Toggle
          _buildSectionTitle(l10n.get('recurringAppointment')),
          SwitchListTile(
            title: Text(l10n.get('enableRecurring')),
            subtitle: Text(l10n.get('recurringDescription')),
            value: _isRecurring,
            onChanged: (value) {
              setState(() {
                _isRecurring = value;
                if (value) {
                  _recurringStartDate ??= DateTime.now();
                  _recurringEndDate ??= DateTime.now().add(const Duration(days: 30));
                }
              });
            },
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            contentPadding: EdgeInsets.zero,
          ),

          // Recurring appointment options
          if (_isRecurring) ...[
            const SizedBox(height: 16),

            // Week days selection
            Text(
              l10n.get('selectWeekDays'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildWeekDayChip(1, l10n.get('monday')),
                _buildWeekDayChip(2, l10n.get('tuesday')),
                _buildWeekDayChip(3, l10n.get('wednesday')),
                _buildWeekDayChip(4, l10n.get('thursday')),
                _buildWeekDayChip(5, l10n.get('friday')),
                _buildWeekDayChip(6, l10n.get('saturday')),
                _buildWeekDayChip(7, l10n.get('sunday')),
              ],
            ),
            const SizedBox(height: 16),

            // Date Range for recurring
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectRecurringStartDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.get('startDate'),
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _recurringStartDate != null
                            ? DateFormat('dd/MM/yyyy').format(_recurringStartDate!)
                            : l10n.selectDate,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _selectRecurringEndDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.get('endDate'),
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _recurringEndDate != null
                            ? DateFormat('dd/MM/yyyy').format(_recurringEndDate!)
                            : l10n.selectDate,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Preview count
            if (_selectedWeekDays.isNotEmpty && _recurringStartDate != null && _recurringEndDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${_generateRecurringDates().length} ${l10n.get('appointmentsWillBeCreated')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
          ],
          const SizedBox(height: 24),

          // Date & Time Selection
          _buildSectionTitle(
            _isRecurring ? l10n.get('appointmentTime') : l10n.dateAndTime,
            required: true,
          ),

          // Date (only for single appointments)
          if (!_isRecurring) ...[
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.date,
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Start and End Time
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.get('startTime'),
                      prefixIcon: const Icon(Icons.access_time),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_startTime.format(context)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _selectEndTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.get('endTime'),
                      prefixIcon: const Icon(Icons.access_time),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_endTime.format(context)),
                  ),
                ),
              ),
            ],
          ),

          // Duration display
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${l10n.duration}: ${_calculateDuration()} ${l10n.minutes}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 24),

          // Customer Section
          _buildSectionTitle(l10n.customerInformation, required: true),

          // Customer Type Toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isNewCustomer = true;
                        _clearCustomerSelection();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isNewCustomer ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.newCustomer,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _isNewCustomer ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isNewCustomer = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isNewCustomer ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.existingCustomer,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_isNewCustomer ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Existing Customer Selection
          if (!_isNewCustomer) ...[
            Autocomplete<Map<String, dynamic>>(
              displayStringForOption: (customer) {
                final firstName = customer['firstName'] ?? '';
                final lastName = customer['lastName'] ?? '';
                final email = customer['email'] ?? '';
                return '$firstName $lastName ($email)'.trim();
              },
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _customers;
                }
                final query = textEditingValue.text.toLowerCase();
                return _customers.where((customer) {
                  final firstName = (customer['firstName'] ?? '').toLowerCase();
                  final lastName = (customer['lastName'] ?? '').toLowerCase();
                  final email = (customer['email'] ?? '').toLowerCase();
                  return firstName.contains(query) ||
                      lastName.contains(query) ||
                      email.contains(query);
                });
              },
              onSelected: _selectExistingCustomer,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: l10n.searchCustomer,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _isLoadingCustomers
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length >= 2) {
                      _searchCustomers(value);
                    }
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 200,
                        maxWidth: MediaQuery.of(context).size.width - 32,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final customer = options.elementAt(index);
                          final firstName = customer['firstName'] ?? '';
                          final lastName = customer['lastName'] ?? '';
                          final email = customer['email'] ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text('$firstName $lastName'.trim()),
                            subtitle: Text(email),
                            onTap: () => onSelected(customer),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedCustomer!['firstName']} ${_selectedCustomer!['lastName']} (${_selectedCustomer!['email']})',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _clearCustomerSelection,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Customer Details - respecting display and required settings from backend
          if (_isNewCustomer || _selectedCustomer != null) ...[
            // First Name
            if (_displayFirstName)
              TextFormField(
                controller: _firstNameController,
                enabled: _isNewCustomer,
                decoration: InputDecoration(
                  labelText: _requireFirstName ? '${l10n.firstName} *' : l10n.firstName,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (_requireFirstName && (value == null || value.trim().isEmpty)) {
                    return l10n.pleaseEnterFirstName;
                  }
                  return null;
                },
              ),
            if (_displayFirstName) const SizedBox(height: 16),

            // Last Name
            if (_displayLastName)
              TextFormField(
                controller: _lastNameController,
                enabled: _isNewCustomer,
                decoration: InputDecoration(
                  labelText: _requireLastName ? '${l10n.lastName} *' : l10n.lastName,
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (_requireLastName && (value == null || value.trim().isEmpty)) {
                    return l10n.pleaseEnterLastName;
                  }
                  return null;
                },
              ),
            if (_displayLastName) const SizedBox(height: 16),

            // Email
            if (_displayEmail)
              TextFormField(
                controller: _emailController,
                enabled: _isNewCustomer,
                decoration: InputDecoration(
                  labelText: _requireEmail ? '${l10n.email} *' : l10n.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (_requireEmail && (value == null || value.trim().isEmpty)) {
                    return l10n.pleaseEnterEmail;
                  }
                  if (value != null && value.isNotEmpty && !value.contains('@')) {
                    return l10n.pleaseEnterValidEmail;
                  }
                  return null;
                },
              ),
            if (_displayEmail) const SizedBox(height: 16),

            // Phone
            if (_displayPhoneNumber)
              TextFormField(
                controller: _phoneController,
                enabled: _isNewCustomer,
                decoration: InputDecoration(
                  labelText: _requirePhoneNumber ? '${l10n.phone} *' : l10n.phoneOptional,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (_requirePhoneNumber && (value == null || value.trim().isEmpty)) {
                    return l10n.pleaseEnterPhone;
                  }
                  return null;
                },
              ),
            if (_displayPhoneNumber) const SizedBox(height: 16),

            // Address
            if (_displayAddress)
              TextFormField(
                controller: _addressController,
                enabled: _isNewCustomer,
                decoration: InputDecoration(
                  labelText: _requireAddress ? '${l10n.address} *' : '${l10n.address} (${l10n.optional})',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (_requireAddress && (value == null || value.trim().isEmpty)) {
                    return l10n.pleaseEnterAddress;
                  }
                  return null;
                },
              ),
            if (_displayAddress) const SizedBox(height: 16),

            // City and Zip Code Row
            if (_displayCity || _displayZipCode)
              Row(
                children: [
                  if (_displayCity)
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cityController,
                        enabled: _isNewCustomer,
                        decoration: InputDecoration(
                          labelText: _requireCity ? '${l10n.city} *' : '${l10n.city} (${l10n.optional})',
                          prefixIcon: const Icon(Icons.location_city_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (_requireCity && (value == null || value.trim().isEmpty)) {
                            return l10n.pleaseEnterCity;
                          }
                          return null;
                        },
                      ),
                    ),
                  if (_displayCity && _displayZipCode) const SizedBox(width: 12),
                  if (_displayZipCode)
                    Expanded(
                      flex: _displayCity ? 1 : 2,
                      child: TextFormField(
                        controller: _zipController,
                        enabled: _isNewCustomer,
                        decoration: InputDecoration(
                          labelText: _requireZipCode ? '${l10n.zipCode} *' : l10n.zipCode,
                          prefixIcon: _displayCity ? null : const Icon(Icons.markunread_mailbox_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (_requireZipCode && (value == null || value.trim().isEmpty)) {
                            return l10n.pleaseEnterZipCode;
                          }
                          return null;
                        },
                      ),
                    ),
                ],
              ),
            if (_displayCity || _displayZipCode) const SizedBox(height: 16),

            // Customer Notes
            if (_displayNotes)
              TextFormField(
                controller: _customerNotesController,
                enabled: _isNewCustomer,
                decoration: InputDecoration(
                  labelText: _requireNotes ? '${l10n.customerNotes} *' : '${l10n.customerNotes} (${l10n.optional})',
                  prefixIcon: const Icon(Icons.note_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
                validator: (value) {
                  if (_requireNotes && (value == null || value.trim().isEmpty)) {
                    return l10n.get('pleaseEnterNotes');
                  }
                  return null;
                },
              ),
            if (_displayNotes) const SizedBox(height: 16),

            // Custom Fields
            ..._buildCustomFields(),
          ],
          const SizedBox(height: 24),

          // Appointment Notes
          _buildSectionTitle('${l10n.appointmentNotes} (${l10n.optional})'),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: l10n.addNotes,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),

          // Save Button
          ElevatedButton(
            onPressed: _isLoading ? null : _saveAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _isRecurring
                      ? '${l10n.createAppointment} (${_generateRecurringDates().length})'
                      : l10n.createAppointment,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWeekDayChip(int day, String label) {
    final isSelected = _selectedWeekDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekDays.add(day);
          } else {
            _selectedWeekDays.remove(day);
          }
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (required)
            Text(
              ' *',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
