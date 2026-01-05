import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../datasources/appointments_remote_datasource.dart';
import '../models/appointment_model.dart';

class AppointmentsRepositoryImpl implements AppointmentsRepository {
  final AppointmentsRemoteDataSource _remoteDataSource;

  AppointmentsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<Appointment>>> getAppointments({
    DateTime? date,
    DateTime? from,
    DateTime? till,
    int? providerId,
    int? customerId,
    int? serviceId,
    int page = 1,
    int length = 20,
  }) async {
    try {
      final appointments = await _remoteDataSource.getAppointments(
        date: date,
        from: from,
        till: till,
        providerId: providerId,
        customerId: customerId,
        serviceId: serviceId,
        page: page,
        length: length,
      );
      return Right(appointments);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e, stackTrace) {
      // Log for debugging
      if (kDebugMode) {
        debugPrint('AppointmentsRepository error: $e');
        debugPrint('StackTrace: $stackTrace');
      }
      return Left(UnknownFailure(message: 'Error loading appointments: ${e.runtimeType}'));
    }
  }

  @override
  Future<Either<Failure, Appointment>> getAppointment(int id) async {
    try {
      final appointment = await _remoteDataSource.getAppointment(id);
      return Right(appointment);
    } on NotFoundException {
      return const Left(NotFoundFailure(message: 'Appointment not found'));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Appointment>> createAppointment(
    Appointment appointment,
  ) async {
    try {
      final model = AppointmentModel(
        id: 0,
        startDateTime: appointment.startDateTime,
        endDateTime: appointment.endDateTime,
        location: appointment.location,
        color: appointment.color,
        notes: appointment.notes,
        serviceId: appointment.serviceId,
        providerId: appointment.providerId,
        customerId: appointment.customerId,
      );

      final created = await _remoteDataSource.createAppointment(model);
      return Right(created);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(
        message: e.message,
        fieldErrors: e.fieldErrors,
      ));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Appointment>> updateAppointment(
    Appointment appointment,
  ) async {
    try {
      final model = AppointmentModel(
        id: appointment.id,
        startDateTime: appointment.startDateTime,
        endDateTime: appointment.endDateTime,
        location: appointment.location,
        color: appointment.color,
        status: appointment.status,
        notes: appointment.notes,
        serviceId: appointment.serviceId,
        providerId: appointment.providerId,
        customerId: appointment.customerId,
      );

      final updated = await _remoteDataSource.updateAppointment(model);
      return Right(updated);
    } on NotFoundException {
      return const Left(NotFoundFailure(message: 'Appointment not found'));
    } on ValidationException catch (e) {
      return Left(ValidationFailure(
        message: e.message,
        fieldErrors: e.fieldErrors,
      ));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAppointment(int id) async {
    try {
      await _remoteDataSource.deleteAppointment(id);
      return const Right(null);
    } on NotFoundException {
      return const Left(NotFoundFailure(message: 'Appointment not found'));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
