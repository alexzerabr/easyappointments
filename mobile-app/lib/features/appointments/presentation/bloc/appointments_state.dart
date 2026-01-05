part of 'appointments_bloc.dart';

/// Base class for appointments states.
abstract class AppointmentsState extends Equatable {
  const AppointmentsState();

  @override
  List<Object?> get props => [];
}

/// Initial appointments state.
class AppointmentsInitial extends AppointmentsState {
  const AppointmentsInitial();
}

/// Loading state.
class AppointmentsLoading extends AppointmentsState {
  const AppointmentsLoading();
}

/// Loaded state with appointments.
class AppointmentsLoaded extends AppointmentsState {
  final List<Appointment> appointments;
  final bool isRefreshing;
  final String? errorMessage;
  final String? successMessage;

  const AppointmentsLoaded({
    required this.appointments,
    this.isRefreshing = false,
    this.errorMessage,
    this.successMessage,
  });

  @override
  List<Object?> get props => [
        appointments,
        isRefreshing,
        errorMessage,
        successMessage,
      ];
}

/// Error state.
class AppointmentsError extends AppointmentsState {
  final String message;

  const AppointmentsError({required this.message});

  @override
  List<Object?> get props => [message];
}
