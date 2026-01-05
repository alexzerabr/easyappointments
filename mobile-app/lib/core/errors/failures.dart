import 'package:equatable/equatable.dart';

/// Base class for all failures in the application.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  List<Object?> get props => [message, code];
}

/// Server-side failure (API errors).
class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure({
    required super.message,
    super.code,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, code, statusCode];
}

/// Network connectivity failure.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection',
    super.code = 'NETWORK_ERROR',
  });
}

/// Cache-related failure.
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache error occurred',
    super.code = 'CACHE_ERROR',
  });
}

/// Authentication failure.
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.code,
  });

  factory AuthFailure.invalidCredentials() => const AuthFailure(
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS',
      );

  factory AuthFailure.tokenExpired() => const AuthFailure(
        message: 'Session expired. Please login again.',
        code: 'TOKEN_EXPIRED',
      );

  factory AuthFailure.unauthorized() => const AuthFailure(
        message: 'You are not authorized to perform this action',
        code: 'UNAUTHORIZED',
      );
}

/// Validation failure.
class ValidationFailure extends Failure {
  final Map<String, List<String>>? fieldErrors;

  const ValidationFailure({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [message, code, fieldErrors];
}

/// Not found failure.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Resource not found',
    super.code = 'NOT_FOUND',
  });
}

/// Unknown failure.
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code = 'UNKNOWN_ERROR',
  });
}

/// Two-factor authentication required failure.
///
/// Returned when login succeeds but 2FA verification is needed.
class TwoFactorRequiredFailure extends Failure {
  final String tempToken;

  const TwoFactorRequiredFailure({
    required this.tempToken,
    super.message = 'Two-factor authentication required',
    super.code = '2FA_REQUIRED',
  });

  @override
  List<Object?> get props => [message, code, tempToken];
}
