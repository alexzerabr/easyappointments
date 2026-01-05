import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/verify_2fa_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Authentication BLoC.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final Verify2FAUseCase _verify2FAUseCase;

  AuthBloc({
    required LoginUseCase loginUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required Verify2FAUseCase verify2FAUseCase,
  })  : _loginUseCase = loginUseCase,
        _logoutUseCase = logoutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _verify2FAUseCase = verify2FAUseCase,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthUserUpdated>(_onUserUpdated);
    on<Auth2FAVerifyRequested>(_on2FAVerifyRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _getCurrentUserUseCase();

    result.fold(
      (failure) => emit(const AuthUnauthenticated()),
      (user) => emit(AuthAuthenticated(user: user)),
    );
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _loginUseCase(LoginParams(
      username: event.username,
      password: event.password,
      deviceName: event.deviceName,
    ));

    result.fold(
      (failure) {
        if (failure is TwoFactorRequiredFailure) {
          emit(Auth2FARequired(
            tempToken: failure.tempToken,
            username: event.username,
          ));
        } else {
          emit(AuthError(message: failure.message));
        }
      },
      (data) => emit(AuthAuthenticated(user: data.$2)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    await _logoutUseCase(logoutAll: event.logoutAll);

    emit(const AuthUnauthenticated());
  }

  void _onUserUpdated(
    AuthUserUpdated event,
    Emitter<AuthState> emit,
  ) {
    // Update the current authenticated state with new user data
    emit(AuthAuthenticated(user: event.user));
  }

  Future<void> _on2FAVerifyRequested(
    Auth2FAVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(Auth2FALoading(tempToken: event.tempToken));

    final result = await _verify2FAUseCase(Verify2FAParams(
      tempToken: event.tempToken,
      code: event.code,
      rememberDevice: event.rememberDevice,
      deviceName: event.deviceName,
    ));

    result.fold(
      (failure) => emit(Auth2FAError(
        message: failure.message,
        tempToken: event.tempToken,
      )),
      (data) => emit(AuthAuthenticated(user: data.$2)),
    );
  }
}
