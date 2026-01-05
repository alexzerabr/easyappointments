part of 'appointments_bloc.dart';

/// Base class for appointments events.
abstract class AppointmentsEvent extends Equatable {
  const AppointmentsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load appointments.
class AppointmentsLoadRequested extends AppointmentsEvent {
  final DateTime? date;
  final DateTime? from;
  final DateTime? till;
  final int? providerId;

  const AppointmentsLoadRequested({
    this.date,
    this.from,
    this.till,
    this.providerId,
  });

  @override
  List<Object?> get props => [date, from, till, providerId];
}

/// Event to refresh appointments.
class AppointmentsRefreshRequested extends AppointmentsEvent {
  final DateTime? date;
  final DateTime? from;
  final DateTime? till;
  final int? providerId;

  const AppointmentsRefreshRequested({
    this.date,
    this.from,
    this.till,
    this.providerId,
  });

  @override
  List<Object?> get props => [date, from, till, providerId];
}

/// Event to create an appointment.
class AppointmentsCreateRequested extends AppointmentsEvent {
  final Appointment appointment;

  const AppointmentsCreateRequested({required this.appointment});

  @override
  List<Object?> get props => [appointment];
}
