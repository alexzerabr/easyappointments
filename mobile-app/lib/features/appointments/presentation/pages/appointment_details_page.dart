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

/// Page for viewing and managing appointment details.
class AppointmentDetailsPage extends StatefulWidget {
  final int appointmentId;

  const AppointmentDetailsPage({super.key, required this.appointmentId});

  @override
  State<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends State<AppointmentDetailsPage> {
  Map<String, dynamic>? _appointment;
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _service;
  Map<String, dynamic>? _provider;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAppointmentDetails();
  }

  Future<void> _loadAppointmentDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = getIt<ApiClient>();

      // Load appointment
      final appointmentResponse = await apiClient.get<Map<String, dynamic>>(
        ApiConstants.appointment(widget.appointmentId),
      );

      _appointment = appointmentResponse;

      // Load related data
      if (_appointment != null) {
        final customerId = _appointment!['customerId'] as int?;
        final serviceId = _appointment!['serviceId'] as int?;
        final providerId = _appointment!['providerId'] as int?;

        // Load customer, service, provider in parallel
        final futures = <Future>[];

        if (customerId != null) {
          futures.add(apiClient.get<Map<String, dynamic>>(
            ApiConstants.customer(customerId),
          ).then((value) => _customer = value).catchError((e) {
            if (kDebugMode) {
              debugPrint('Failed to load customer: $e');
            }
            return <String, dynamic>{};
          }));
        }

        if (serviceId != null) {
          futures.add(apiClient.get<Map<String, dynamic>>(
            ApiConstants.service(serviceId),
          ).then((value) => _service = value).catchError((e) {
            if (kDebugMode) {
              debugPrint('Failed to load service: $e');
            }
            return <String, dynamic>{};
          }));
        }

        if (providerId != null) {
          futures.add(apiClient.get<Map<String, dynamic>>(
            ApiConstants.provider(providerId),
          ).then((value) => _provider = value).catchError((e) {
            if (kDebugMode) {
              debugPrint('Failed to load provider: $e');
            }
            return <String, dynamic>{};
          }));
        }

        await Future.wait(futures);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAppointment() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.get('deleteAppointment')),
        content: Text(l10n.get('confirmDeleteAppointment')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final apiClient = getIt<ApiClient>();
      await apiClient.delete(ApiConstants.appointment(widget.appointmentId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.get('appointmentDeleted')),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.get('failedToDelete')}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _editAppointment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditAppointmentPage(
          appointment: _appointment!,
          customer: _customer,
          service: _service,
          provider: _provider,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadAppointmentDetails();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appointmentDetails),
        actions: [
          if (!_isLoading && _appointment != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editAppointment,
              tooltip: l10n.edit,
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _deleteAppointment,
              tooltip: l10n.delete,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadData,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAppointmentDetails,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.tryAgain),
              ),
            ],
          ),
        ),
      );
    }

    if (_appointment == null) {
      return Center(child: Text(l10n.get('appointmentNotFound')));
    }

    return RefreshIndicator(
      onRefresh: _loadAppointmentDetails,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Date & Time Card
            _buildDateTimeCard(),
            const SizedBox(height: 16),

            // Service Card
            _buildServiceCard(),
            const SizedBox(height: 16),

            // Provider Card
            _buildProviderCard(),
            const SizedBox(height: 16),

            // Customer Card
            _buildCustomerCard(),
            const SizedBox(height: 16),

            // Notes Card
            if (_appointment!['notes'] != null &&
                (_appointment!['notes'] as String).isNotEmpty)
              _buildNotesCard(),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _editAppointment,
                    icon: const Icon(Icons.edit),
                    label: Text(l10n.edit),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDeleting ? null : _deleteAppointment,
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete),
                    label: Text(l10n.delete),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final l10n = AppLocalizations.of(context);
    final status = _appointment!['status'] as String? ?? 'Booked';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeCard() {
    final l10n = AppLocalizations.of(context);

    DateTime? startDateTime;
    DateTime? endDateTime;

    final startStr = _appointment!['start'] as String?;
    final endStr = _appointment!['end'] as String?;

    if (startStr != null) {
      startDateTime = DateTime.tryParse(startStr.replaceAll(' ', 'T'));
    }
    if (endStr != null) {
      endDateTime = DateTime.tryParse(endStr.replaceAll(' ', 'T'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  l10n.dateAndTime,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.date,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        startDateTime != null
                            ? DateFormat('EEEE, dd MMMM yyyy').format(startDateTime)
                            : '-',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.get('startTime'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        startDateTime != null
                            ? DateFormat('HH:mm').format(startDateTime)
                            : '-',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.get('endTime'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        endDateTime != null
                            ? DateFormat('HH:mm').format(endDateTime)
                            : '-',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.duration,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        startDateTime != null && endDateTime != null
                            ? _formatDuration(endDateTime.difference(startDateTime))
                            : '-',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    final l10n = AppLocalizations.of(context);
    final serviceName = _service?['name'] ?? '-';
    final servicePrice = _service?['price'];
    final serviceCurrency = _service?['currency'] ?? 'BRL';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.spa_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  l10n.service,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              serviceName,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (servicePrice != null) ...[
              const SizedBox(height: 8),
              Text(
                '$serviceCurrency ${servicePrice.toString()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard() {
    final l10n = AppLocalizations.of(context);
    final firstName = _provider?['firstName'] ?? '';
    final lastName = _provider?['lastName'] ?? '';
    final providerName = '$firstName $lastName'.trim();
    final providerEmail = _provider?['email'] ?? '';
    final providerPhone = _provider?['phoneNumber'] ?? _provider?['phone'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  l10n.provider,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              providerName.isNotEmpty ? providerName : '-',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (providerEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    providerEmail,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (providerPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    providerPhone,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    final l10n = AppLocalizations.of(context);
    final firstName = _customer?['firstName'] ?? '';
    final lastName = _customer?['lastName'] ?? '';
    final customerName = '$firstName $lastName'.trim();
    final customerEmail = _customer?['email'] ?? '';
    final customerPhone = _customer?['phoneNumber'] ?? _customer?['phone'] ?? '';
    final customerAddress = _customer?['address'] ?? '';
    final customerCity = _customer?['city'] ?? '';
    final customerZip = _customer?['zipCode'] ?? _customer?['zip'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  l10n.customer,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              customerName.isNotEmpty ? customerName : '-',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            if (customerEmail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerEmail,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (customerPhone.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    customerPhone,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (customerAddress.isNotEmpty || customerCity.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [customerAddress, customerCity, customerZip]
                          .where((s) => s.isNotEmpty)
                          .join(', '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    final l10n = AppLocalizations.of(context);
    final notes = _appointment!['notes'] as String? ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  l10n.notes,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              notes,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
    }
    return '${minutes}min';
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
      default:
        return AppColors.statusPending;
    }
  }
}

/// Page for editing an existing appointment.
class EditAppointmentPage extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? service;
  final Map<String, dynamic>? provider;

  const EditAppointmentPage({
    super.key,
    required this.appointment,
    this.customer,
    this.service,
    this.provider,
  });

  @override
  State<EditAppointmentPage> createState() => _EditAppointmentPageState();
}

class _EditAppointmentPageState extends State<EditAppointmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);

  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _selectedProvider;
  String? _selectedStatus;

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _providers = [];
  List<String> _statusOptions = [];

  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeFromAppointment();
    _loadData();
  }

  void _initializeFromAppointment() {
    final startStr = widget.appointment['start'] as String?;
    final endStr = widget.appointment['end'] as String?;

    if (startStr != null) {
      final startDateTime = DateTime.tryParse(startStr.replaceAll(' ', 'T'));
      if (startDateTime != null) {
        _selectedDate = startDateTime;
        _startTime = TimeOfDay(hour: startDateTime.hour, minute: startDateTime.minute);
      }
    }

    if (endStr != null) {
      final endDateTime = DateTime.tryParse(endStr.replaceAll(' ', 'T'));
      if (endDateTime != null) {
        _endTime = TimeOfDay(hour: endDateTime.hour, minute: endDateTime.minute);
      }
    }

    _selectedStatus = widget.appointment['status'] as String? ?? 'Booked';
    _notesController.text = widget.appointment['notes'] as String? ?? '';
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
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

      // Load appointment status options from specific endpoint
      List<String>? statusOptions;

      try {
        final statusResponse = await apiClient.get<Map<String, dynamic>>(
          ApiConstants.appointmentStatusOptions,
        );

        if (kDebugMode) {
          debugPrint('[EditAppointment] Status options response: $statusResponse');
        }

        final value = statusResponse['value'];
        if (value != null) {
          if (value is String && value.isNotEmpty) {
            // Parse JSON string array like '["Booked","Confirmed"]'
            final decoded = jsonDecode(value);
            if (decoded is List && decoded.isNotEmpty) {
              statusOptions = decoded.map((e) => e.toString()).toList();
              if (kDebugMode) {
                debugPrint('[EditAppointment] Loaded status options: $statusOptions');
              }
            }
          } else if (value is List && value.isNotEmpty) {
            statusOptions = value.map((e) => e.toString()).toList();
            if (kDebugMode) {
              debugPrint('[EditAppointment] Loaded status options from List: $statusOptions');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[EditAppointment] Failed to load status options: $e');
        }
      }

      // Validate that status options were loaded
      if (statusOptions == null || statusOptions.isEmpty) {
        if (!mounted) return;
        throw Exception(AppLocalizations.of(context).get('failedToLoadStatusOptions'));
      }

      setState(() {
        _services = servicesResponse.map((s) => s as Map<String, dynamic>).toList();
        _providers = providersResponse.map((p) => p as Map<String, dynamic>).toList();
        _statusOptions = statusOptions!; // Already validated above

        // Set selected service and provider
        final serviceId = widget.appointment['serviceId'] as int?;
        final providerId = widget.appointment['providerId'] as int?;

        if (serviceId != null) {
          _selectedService = _services.firstWhere(
            (s) => s['id'] == serviceId,
            orElse: () => <String, dynamic>{},
          );
          if (_selectedService!.isEmpty) _selectedService = null;
        }

        if (providerId != null) {
          _selectedProvider = _providers.firstWhere(
            (p) => p['id'] == providerId,
            orElse: () => <String, dynamic>{},
          );
          if (_selectedProvider!.isEmpty) _selectedProvider = null;
        }

        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingData = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  String _formatDateTimeForBackend(DateTime date, TimeOfDay time) {
    final dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute, 0);
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  void _showStatusSelector() {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${_statusOptions.length} ${l10n.get('options')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
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
                            color: isSelected ? AppColors.primary : Theme.of(context).textTheme.bodyLarge?.color,
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

  Future<void> _saveAppointment() async {
    final l10n = AppLocalizations.of(context);

    if (!_formKey.currentState!.validate()) return;

    if (_selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectService), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pleaseSelectProvider), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = getIt<ApiClient>();

      final appointmentData = {
        'serviceId': _selectedService!['id'],
        'providerId': _selectedProvider!['id'],
        'customerId': widget.appointment['customerId'],
        'start': _formatDateTimeForBackend(_selectedDate, _startTime),
        'end': _formatDateTimeForBackend(_selectedDate, _endTime),
        'status': _selectedStatus ?? 'Booked',
        'notes': _notesController.text.trim(),
      };

      await apiClient.put<Map<String, dynamic>>(
        ApiConstants.appointment(widget.appointment['id'] as int),
        data: appointmentData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.appointmentUpdated),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editAppointment),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
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
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),

                  // Customer Info (read-only)
                  if (widget.customer != null) ...[
                    _buildSectionTitle(l10n.customer),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                '${(widget.customer!['firstName'] as String? ?? '').isNotEmpty ? widget.customer!['firstName'][0] : ''}',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.customer!['firstName'] ?? ''} ${widget.customer!['lastName'] ?? ''}'.trim(),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    widget.customer!['email'] ?? '',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Service Selection
                  _buildSectionTitle(l10n.service, required: true),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedService?['id'] as int?,
                    decoration: InputDecoration(
                      hintText: l10n.selectService,
                      prefixIcon: const Icon(Icons.spa_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    menuMaxHeight: 300,
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    menuMaxHeight: 300,
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
                  ),
                  const SizedBox(height: 24),

                  // Status Selection - using bottom sheet for scrolling
                  _buildSectionTitle(l10n.status, required: true),
                  InkWell(
                    onTap: () => _showStatusSelector(),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.flag_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

                  // Date Selection
                  _buildSectionTitle(l10n.dateAndTime, required: true),
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.date,
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time Selection
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectStartTime,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: l10n.get('startTime'),
                              prefixIcon: const Icon(Icons.access_time),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(_endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Notes
                  _buildSectionTitle('${l10n.notes} (${l10n.optional})'),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText: l10n.addNotes,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            l10n.save,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
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
