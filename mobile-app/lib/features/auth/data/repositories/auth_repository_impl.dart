import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  AuthRepositoryImpl(this._remoteDataSource, this._localDataSource);

  @override
  Future<Either<Failure, (AuthTokens, User)>> login({
    required String username,
    required String password,
    String? deviceName,
  }) async {
    try {
      // Get saved device token for 2FA bypass
      final deviceToken = await _localDataSource.getDeviceToken();

      final (tokens, user) = await _remoteDataSource.login(
        username: username,
        password: password,
        deviceName: deviceName,
        deviceToken: deviceToken,
      );

      // Save tokens and user locally
      await _localDataSource.saveAccessToken(tokens.accessToken);
      await _localDataSource.saveRefreshToken(tokens.refreshToken);
      await _localDataSource.saveUser(user);

      return Right((tokens, user));
    } on TwoFactorRequiredException catch (e) {
      return Left(TwoFactorRequiredFailure(tempToken: e.tempToken));
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
  Future<Either<Failure, void>> logout({bool logoutAll = false}) async {
    try {
      final refreshToken = await _localDataSource.getRefreshToken();

      await _remoteDataSource.logout(
        refreshToken: refreshToken,
        logoutAll: logoutAll,
      );

      await _localDataSource.clearAll();

      return const Right(null);
    } on NetworkException {
      // Still clear local data even if network fails
      await _localDataSource.clearAll();
      return const Right(null);
    } catch (e) {
      // Still clear local data on any error
      await _localDataSource.clearAll();
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    try {
      final refreshToken = await _localDataSource.getRefreshToken();

      if (refreshToken == null) {
        return Left(AuthFailure.tokenExpired());
      }

      final newAccessToken = await _remoteDataSource.refreshToken(refreshToken);
      await _localDataSource.saveAccessToken(newAccessToken);

      return Right(newAccessToken);
    } on AuthException catch (e) {
      await _localDataSource.clearAll();
      return Left(AuthFailure(message: e.message, code: e.code));
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      // Try to get from remote first
      final user = await _remoteDataSource.getCurrentUser();
      await _localDataSource.saveUser(user);
      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on NetworkException {
      // Try to get from local cache
      try {
        final cachedUser = await _localDataSource.getUser();
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
  Future<bool> isAuthenticated() async {
    return await _localDataSource.hasValidSession();
  }

  @override
  Future<String?> getAccessToken() async {
    return await _localDataSource.getAccessToken();
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _localDataSource.getRefreshToken();
  }

  @override
  Future<String?> getDeviceToken() async {
    return await _localDataSource.getDeviceToken();
  }

  @override
  Future<Either<Failure, (AuthTokens, User)>> verify2FA({
    required String tempToken,
    required String code,
    bool rememberDevice = false,
    String? deviceName,
  }) async {
    try {
      final (tokens, user, deviceToken) = await _remoteDataSource.verify2FA(
        tempToken: tempToken,
        code: code,
        rememberDevice: rememberDevice,
        deviceName: deviceName,
      );

      // Save tokens and user locally
      await _localDataSource.saveAccessToken(tokens.accessToken);
      await _localDataSource.saveRefreshToken(tokens.refreshToken);
      await _localDataSource.saveUser(user);

      // Save device token if provided
      if (deviceToken != null) {
        await _localDataSource.saveDeviceToken(deviceToken);
      }

      return Right((tokens, user));
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
