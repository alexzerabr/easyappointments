import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_tokens.dart';
import '../entities/user.dart';

/// Authentication repository interface.
abstract class AuthRepository {
  /// Login with username and password.
  Future<Either<Failure, (AuthTokens, User)>> login({
    required String username,
    required String password,
    String? deviceName,
  });

  /// Logout the current user.
  Future<Either<Failure, void>> logout({bool logoutAll = false});

  /// Refresh the access token.
  Future<Either<Failure, String>> refreshToken();

  /// Get the current authenticated user.
  Future<Either<Failure, User>> getCurrentUser();

  /// Check if user is authenticated.
  Future<bool> isAuthenticated();

  /// Get stored access token.
  Future<String?> getAccessToken();

  /// Get stored refresh token.
  Future<String?> getRefreshToken();

  /// Get stored 2FA device token.
  Future<String?> getDeviceToken();

  /// Verify 2FA code and complete login.
  Future<Either<Failure, (AuthTokens, User)>> verify2FA({
    required String tempToken,
    required String code,
    bool rememberDevice = false,
    String? deviceName,
  });
}
