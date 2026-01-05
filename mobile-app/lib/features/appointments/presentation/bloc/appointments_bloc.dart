import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/appointment.dart';
import '../../domain/usecases/create_appointment_usecase.dart';
import '../../domain/usecases/get_appointments_usecase.dart';

part 'appointments_event.dart';
part 'appointments_state.dart';

/// Appointments BLoC.
class AppointmentsBloc extends Bloc<AppointmentsEvent, AppointmentsState> {
  final GetAppointmentsUseCase _getAppointmentsUseCase;
  final CreateAppointmentUseCase _createAppointmentUseCase;

  AppointmentsBloc({
    required GetAppointmentsUseCase getAppointmentsUseCase,
    required CreateAppointmentUseCase createAppointmentUseCase,
  })  : _getAppointmentsUseCase = getAppointmentsUseCase,
        _createAppointmentUseCase = createAppointmentUseCase,
        super(const AppointmentsInitial()) {
    on<AppointmentsLoadRequested>(_onLoadRequested);
    on<AppointmentsRefreshRequested>(_onRefreshRequested);
    on<AppointmentsCreateRequested>(_onCreateRequested);
  }

  Future<void> _onLoadRequested(
    AppointmentsLoadRequested event,
    Emitter<AppointmentsState> emit,
  ) async {
    emit(const AppointmentsLoading());

    final result = await _getAppointmentsUseCase(GetAppointmentsParams(
      date: event.date,
      from: event.from,
      till: event.till,
      providerId: event.providerId,
    ));

    result.fold(
      (failure) => emit(AppointmentsError(message: failure.message)),
      (appointments) => emit(AppointmentsLoaded(appointments: appointments)),
    );
  }

  Future<void> _onRefreshRequested(
    AppointmentsRefreshRequested event,
    Emitter<AppointmentsState> emit,
  ) async {
    final currentState = state;
    if (currentState is AppointmentsLoaded) {
      // Keep showing current data while refreshing
      emit(AppointmentsLoaded(
        appointments: currentState.appointments,
        isRefreshing: true,
      ));
    }

    final result = await _getAppointmentsUseCase(GetAppointmentsParams(
      date: event.date,
      from: event.from,
      till: event.till,
      providerId: event.providerId,
    ));

    result.fold(
      (failure) {
        if (currentState is AppointmentsLoaded) {
          emit(AppointmentsLoaded(
            appointments: currentState.appointments,
            errorMessage: failure.message,
          ));
        } else {
          emit(AppointmentsError(message: failure.message));
        }
      },
      (appointments) => emit(AppointmentsLoaded(appointments: appointments)),
    );
  }

  Future<void> _onCreateRequested(
    AppointmentsCreateRequested event,
    Emitter<AppointmentsState> emit,
  ) async {
    final currentState = state;

    emit(const AppointmentsLoading());

    final result = await _createAppointmentUseCase(event.appointment);

    result.fold(
      (failure) {
        if (currentState is AppointmentsLoaded) {
          emit(AppointmentsLoaded(
            appointments: currentState.appointments,
            errorMessage: failure.message,
          ));
        } else {
          emit(AppointmentsError(message: failure.message));
        }
      },
      (appointment) {
        if (currentState is AppointmentsLoaded) {
          emit(AppointmentsLoaded(
            appointments: [...currentState.appointments, appointment],
            successMessage: 'Appointment created successfully',
          ));
        } else {
          emit(AppointmentsLoaded(
            appointments: [appointment],
            successMessage: 'Appointment created successfully',
          ));
        }
      },
    );
  }
}
