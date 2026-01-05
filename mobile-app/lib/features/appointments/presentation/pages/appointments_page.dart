import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/error_widget.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/appointment.dart';
import '../bloc/appointments_bloc.dart';

/// Appointments list page.
class AppointmentsPage extends StatelessWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AppointmentsBloc>()
        ..add(AppointmentsLoadRequested(
          from: DateTime.now().subtract(const Duration(days: 7)),
          till: DateTime.now().add(const Duration(days: 30)),
        )),
      child: const _AppointmentsView(),
    );
  }
}

class _AppointmentsView extends StatelessWidget {
  const _AppointmentsView();

  Future<void> _navigateToNewAppointment(BuildContext context) async {
    final result = await context.push<bool>(AppRoutes.newAppointment);
    if (result == true && context.mounted) {
      // Refresh appointments list after creation
      context.read<AppointmentsBloc>().add(
        AppointmentsRefreshRequested(
          from: DateTime.now().subtract(const Duration(days: 7)),
          till: DateTime.now().add(const Duration(days: 30)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appointments),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter dialog
            },
          ),
        ],
      ),
      body: BlocConsumer<AppointmentsBloc, AppointmentsState>(
        listener: (context, state) {
          if (state is AppointmentsLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            if (state.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.successMessage!),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          }
        },
        builder: (context, state) {
          if (state is AppointmentsLoading) {
            return const LoadingWidget();
          }

          if (state is AppointmentsError) {
            return AppErrorWidget(
              message: state.message,
              onRetry: () {
                context.read<AppointmentsBloc>().add(
                      AppointmentsLoadRequested(
                        from: DateTime.now().subtract(const Duration(days: 7)),
                        till: DateTime.now().add(const Duration(days: 30)),
                      ),
                    );
              },
            );
          }

          if (state is AppointmentsLoaded) {
            if (state.appointments.isEmpty) {
              return EmptyStateWidget.noAppointments(
                context,
                onAction: () => _navigateToNewAppointment(context),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<AppointmentsBloc>().add(
                      AppointmentsRefreshRequested(
                        from: DateTime.now().subtract(const Duration(days: 7)),
                        till: DateTime.now().add(const Duration(days: 30)),
                      ),
                    );
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.appointments.length,
                itemBuilder: (context, index) {
                  final appointment = state.appointments[index];
                  return _AppointmentCard(
                    appointment: appointment,
                    onRefresh: () {
                      context.read<AppointmentsBloc>().add(
                        AppointmentsRefreshRequested(
                          from: DateTime.now().subtract(const Duration(days: 7)),
                          till: DateTime.now().add(const Duration(days: 30)),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onRefresh;

  const _AppointmentCard({required this.appointment, this.onRefresh});

  Future<void> _navigateToDetails(BuildContext context) async {
    final result = await context.push<bool>('/appointments/${appointment.id}');
    if (result == true && context.mounted) {
      // Refresh appointments list after edit or delete
      onRefresh?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getStatusColor(appointment.status),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.serviceName ?? 'Service',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appointment.customerName ?? 'Customer',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatDate(context, appointment.startDateTime),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(appointment.startDateTime),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    appointment.formattedDuration,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    appointment.providerName ?? 'Provider',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
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

  String _formatDate(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final appointmentDate = DateTime(date.year, date.month, date.day);

    if (appointmentDate == today) {
      return l10n.today;
    } else if (appointmentDate == tomorrow) {
      return l10n.tomorrow;
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
