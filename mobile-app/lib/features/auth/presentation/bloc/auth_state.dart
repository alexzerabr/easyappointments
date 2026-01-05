part of 'auth_bloc.dart';

/// Base class for authentication states.
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial authentication state.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state during authentication operations.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// State when user is authenticated.
class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// State when user is not authenticated.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// State when authentication fails.
class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// State when 2FA verification is required.
class Auth2FARequired extends AuthState {
  final String tempToken;
  final String? username;

  const Auth2FARequired({
    required this.tempToken,
    this.username,
  });

  @override
  List<Object?> get props => [tempToken, username];
}

/// State when 2FA verification fails.
class Auth2FAError extends AuthState {
  final String message;
  final String tempToken;

  const Auth2FAError({
    required this.message,
    required this.tempToken,
  });

  @override
  List<Object?> get props => [message, tempToken];
}

/// State when 2FA verification is in progress.
class Auth2FALoading extends AuthState {
  final String tempToken;

  const Auth2FALoading({required this.tempToken});

  @override
  List<Object?> get props => [tempToken];
}
