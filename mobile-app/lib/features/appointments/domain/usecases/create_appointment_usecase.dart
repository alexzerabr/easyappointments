import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/appointment.dart';
import '../repositories/appointments_repository.dart';

/// Create appointment use case.
class CreateAppointmentUseCase {
  final AppointmentsRepository _repository;

  CreateAppointmentUseCase(this._repository);

  Future<Either<Failure, Appointment>> call(Appointment appointment) {
    return _repository.createAppointment(appointment);
  }
}
