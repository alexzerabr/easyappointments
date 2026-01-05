import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/appointment.dart';
import '../repositories/appointments_repository.dart';

/// Get appointments use case.
class GetAppointmentsUseCase {
  final AppointmentsRepository _repository;

  GetAppointmentsUseCase(this._repository);

  Future<Either<Failure, List<Appointment>>> call(GetAppointmentsParams params) {
    return _repository.getAppointments(
      date: params.date,
      from: params.from,
      till: params.till,
      providerId: params.providerId,
      customerId: params.customerId,
      serviceId: params.serviceId,
      page: params.page,
      length: params.length,
    );
  }
}

/// Parameters for get appointments use case.
class GetAppointmentsParams extends Equatable {
  final DateTime? date;
  final DateTime? from;
  final DateTime? till;
  final int? providerId;
  final int? customerId;
  final int? serviceId;
  final int page;
  final int length;

  const GetAppointmentsParams({
    this.date,
    this.from,
    this.till,
    this.providerId,
    this.customerId,
    this.serviceId,
    this.page = 1,
    this.length = 20,
  });

  @override
  List<Object?> get props => [
        date,
        from,
        till,
        providerId,
        customerId,
        serviceId,
        page,
        length,
      ];
}
