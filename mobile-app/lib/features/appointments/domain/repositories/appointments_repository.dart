import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/appointment.dart';

/// Appointments repository interface.
abstract class AppointmentsRepository {
  /// Get appointments with optional filters.
  Future<Either<Failure, List<Appointment>>> getAppointments({
    DateTime? date,
    DateTime? from,
    DateTime? till,
    int? providerId,
    int? customerId,
    int? serviceId,
    int page = 1,
    int length = 20,
  });

  /// Get a single appointment by ID.
  Future<Either<Failure, Appointment>> getAppointment(int id);

  /// Create a new appointment.
  Future<Either<Failure, Appointment>> createAppointment(Appointment appointment);

  /// Update an existing appointment.
  Future<Either<Failure, Appointment>> updateAppointment(Appointment appointment);

  /// Delete an appointment.
  Future<Either<Failure, void>> deleteAppointment(int id);
}
