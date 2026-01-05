import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/bloc/appointments_bloc.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';

/// Calendar page showing appointments in a calendar view.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late AppointmentsBloc _appointmentsBloc;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _appointmentsBloc = getIt<AppointmentsBloc>();
    _loadAppointmentsForMonth(_focusedDay);
  }

  void _loadAppointmentsForMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    _appointmentsBloc.add(AppointmentsLoadRequested(
      from: firstDay,
      till: lastDay,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _appointmentsBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.calendar),
          actions: [
            NotificationIconButton(
              onPressed: () => context.push(AppRoutes.notifications),
            ),
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime.now();
                  _selectedDay = DateTime.now();
                });
                _loadAppointmentsForMonth(DateTime.now());
              },
            ),
            IconButton(
              icon: const Icon(Icons.view_agenda_outlined),
              onPressed: () {
                setState(() {
                  _calendarFormat = _calendarFormat == CalendarFormat.month
                      ? CalendarFormat.week
                      : CalendarFormat.month;
                });
              },
            ),
          ],
        ),
        body: BlocBuilder<AppointmentsBloc, AppointmentsState>(
          builder: (context, state) {
            final appointments = state is AppointmentsLoaded
                ? state.appointments
                : <Appointment>[];

            return Column(
              children: [
                TableCalendar<Appointment>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) => _getAppointmentsForDay(day, appointments),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                    _loadAppointmentsForMonth(focusedDay);
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.calendarToday,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.calendarSelected,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                    markerSize: 6.0,
                    markerMargin: const EdgeInsets.symmetric(horizontal: 0.5),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _selectedDay != null
                      ? _DayAppointments(
                          selectedDay: _selectedDay!,
                          appointments: _getAppointmentsForDay(_selectedDay!, appointments),
                          isLoading: state is AppointmentsLoading,
                          onRefresh: () => _loadAppointmentsForMonth(_focusedDay),
                        )
                      : Center(
                          child: Text(l10n.selectDayToView),
                        ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await context.push<bool>(AppRoutes.newAppointment);
            if (result == true && mounted) {
              _loadAppointmentsForMonth(_focusedDay);
            }
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  List<Appointment> _getAppointmentsForDay(DateTime day, List<Appointment> appointments) {
    return appointments.where((appointment) {
      return isSameDay(appointment.startDateTime, day);
    }).toList();
  }
}

class _DayAppointments extends StatelessWidget {
  final DateTime selectedDay;
  final List<Appointment> appointments;
  final bool isLoading;
  final VoidCallback? onRefresh;

  const _DayAppointments({
    required this.selectedDay,
    required this.appointments,
    this.isLoading = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isLoading) {
      return const LoadingWidget();
    }

    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noAppointments,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, y').format(selectedDay),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.tapToCreate,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _AppointmentTile(
          appointment: appointment,
          onRefresh: onRefresh,
        );
      },
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onRefresh;

  const _AppointmentTile({required this.appointment, this.onRefresh});

  Future<void> _navigateToDetails(BuildContext context) async {
    final result = await context.push<bool>('/appointments/${appointment.id}');
    if (result == true && context.mounted) {
      onRefresh?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appointment.customerName ?? 'Customer',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (appointment.providerName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'with ${appointment.providerName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(appointment.startDateTime),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${appointment.durationMinutes} min',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
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
}
