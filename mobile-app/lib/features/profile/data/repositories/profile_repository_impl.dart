import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/password_change_request.dart';
import '../../domain/entities/profile_update_request.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/password_change_request_model.dart';
import '../models/profile_update_request_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _authLocalDataSource;

  ProfileRepositoryImpl(
    this._remoteDataSource,
    this._authLocalDataSource,
  );

  @override
  Future<Either<Failure, User>> getProfile() async {
    try {
      final user = await _remoteDataSource.getProfile();
      // Update local cache
      await _authLocalDataSource.saveUser(user);
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on NetworkException {
      // Try to get from local cache
      try {
        final cachedUser = await _authLocalDataSource.getUser();
        if (cachedUser != null) {
          return Right(cachedUser);
        }
        return const Left(NetworkFailure());
      } catch (e) {
        return const Left(NetworkFailure());
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> updateProfile(
    ProfileUpdateRequest request,
  ) async {
    try {
      // Get current user to determine role and ID
      final cachedUser = await _authLocalDataSource.getUser();
      if (cachedUser == null) {
        return Left(AuthFailure.unauthorized());
      }

      final requestModel = ProfileUpdateRequestModel.fromEntity(request);
      final updatedUser = await _remoteDataSource.updateProfile(
        requestModel,
        cachedUser.role,
        cachedUser.id,
      );

      // Update local cache with new user data
      await _authLocalDataSource.saveUser(updatedUser);

      return Right(updatedUser);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(
        message: e.message,
        fieldErrors: e.fieldErrors,
      ));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword(
    PasswordChangeRequest request,
  ) async {
    try {
      final requestModel = PasswordChangeRequestModel.fromEntity(request);
      await _remoteDataSource.changePassword(requestModel);
      return const Right(null);
    } on ValidationException catch (e) {
      return Left(ValidationFailure(
        message: e.message,
        fieldErrors: e.fieldErrors,
      ));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on NetworkException {
      return const Left(NetworkFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
