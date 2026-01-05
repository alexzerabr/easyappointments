part of 'auth_bloc.dart';

/// Base class for authentication events.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Event to check authentication status.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Event to request login.
class AuthLoginRequested extends AuthEvent {
  final String username;
  final String password;
  final String? deviceName;

  const AuthLoginRequested({
    required this.username,
    required this.password,
    this.deviceName,
  });

  @override
  List<Object?> get props => [username, password, deviceName];
}

/// Event to request logout.
class AuthLogoutRequested extends AuthEvent {
  final bool logoutAll;

  const AuthLogoutRequested({this.logoutAll = false});

  @override
  List<Object?> get props => [logoutAll];
}

/// Event to update the current user (e.g., after profile edit).
class AuthUserUpdated extends AuthEvent {
  final User user;

  const AuthUserUpdated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Event to request 2FA verification.
class Auth2FAVerifyRequested extends AuthEvent {
  final String tempToken;
  final String code;
  final bool rememberDevice;
  final String? deviceName;

  const Auth2FAVerifyRequested({
    required this.tempToken,
    required this.code,
    this.rememberDevice = false,
    this.deviceName,
  });

  @override
  List<Object?> get props => [tempToken, code, rememberDevice, deviceName];
}
