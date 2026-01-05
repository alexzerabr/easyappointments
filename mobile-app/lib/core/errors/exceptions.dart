/// Base class for all exceptions in the application.
abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Server exception for API errors.
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    super.code,
    this.statusCode,
  });

  @override
  String toString() => 'ServerException: $message (status: $statusCode, code: $code)';
}

/// Network exception for connectivity issues.
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection',
    super.code = 'NETWORK_ERROR',
  });
}

/// Cache exception for local storage issues.
class CacheException extends AppException {
  const CacheException({
    super.message = 'Cache error occurred',
    super.code = 'CACHE_ERROR',
  });
}

/// Authentication exception.
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
  });

  factory AuthException.invalidCredentials() => const AuthException(
        message: 'Invalid credentials',
        code: 'INVALID_CREDENTIALS',
      );

  factory AuthException.tokenExpired() => const AuthException(
        message: 'Token expired',
        code: 'TOKEN_EXPIRED',
      );

  factory AuthException.unauthorized() => const AuthException(
        message: 'Unauthorized',
        code: 'UNAUTHORIZED',
      );
}

/// Validation exception.
class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code = 'VALIDATION_ERROR',
    this.fieldErrors,
  });
}

/// Not found exception.
class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'Resource not found',
    super.code = 'NOT_FOUND',
  });
}

/// Two-factor authentication required exception.
///
/// Thrown when login succeeds but 2FA verification is needed.
class TwoFactorRequiredException extends AppException {
  final String tempToken;

  const TwoFactorRequiredException({
    required this.tempToken,
    super.message = 'Two-factor authentication required',
    super.code = '2FA_REQUIRED',
  });
}
