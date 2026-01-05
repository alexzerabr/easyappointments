import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/password_change_request.dart';
import '../../domain/entities/profile_update_request.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// Profile BLoC for managing user profile operations.
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetProfileUseCase _getProfileUseCase;
  final UpdateProfileUseCase _updateProfileUseCase;
  final ChangePasswordUseCase _changePasswordUseCase;

  ProfileBloc({
    required GetProfileUseCase getProfileUseCase,
    required UpdateProfileUseCase updateProfileUseCase,
    required ChangePasswordUseCase changePasswordUseCase,
  })  : _getProfileUseCase = getProfileUseCase,
        _updateProfileUseCase = updateProfileUseCase,
        _changePasswordUseCase = changePasswordUseCase,
        super(const ProfileInitial()) {
    on<ProfileLoadRequested>(_onProfileLoadRequested);
    on<ProfileUpdateRequested>(_onProfileUpdateRequested);
    on<ProfilePasswordChangeRequested>(_onPasswordChangeRequested);
  }

  Future<void> _onProfileLoadRequested(
    ProfileLoadRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    final result = await _getProfileUseCase();

    result.fold(
      (failure) => emit(ProfileError(message: failure.message)),
      (user) => emit(ProfileLoaded(user: user)),
    );
  }

  Future<void> _onProfileUpdateRequested(
    ProfileUpdateRequested event,
    Emitter<ProfileState> emit,
  ) async {
    print('[ProfileBloc] ProfileUpdateRequested event received'); // DEBUG
    print('[ProfileBloc] Request: ${event.request.firstName} ${event.request.lastName}'); // DEBUG
    emit(const ProfileLoading());

    print('[ProfileBloc] Calling updateProfileUseCase'); // DEBUG
    final result = await _updateProfileUseCase(event.request);

    result.fold(
      (failure) {
        print('[ProfileBloc] Update failed: ${failure.message}'); // DEBUG
        // Handle validation errors with field-specific messages
        if (failure is ValidationFailure) {
          emit(ProfileError(
            message: failure.message,
            fieldErrors: failure.fieldErrors,
          ));
        } else {
          emit(ProfileError(message: failure.message));
        }
      },
      (user) {
        print('[ProfileBloc] Update successful: ${user.firstName} ${user.lastName}'); // DEBUG
        emit(ProfileUpdated(user: user));
      },
    );
  }

  Future<void> _onPasswordChangeRequested(
    ProfilePasswordChangeRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(const ProfileLoading());

    final result = await _changePasswordUseCase(event.request);

    result.fold(
      (failure) {
        // Handle validation errors with field-specific messages
        if (failure is ValidationFailure) {
          emit(ProfileError(
            message: failure.message,
            fieldErrors: failure.fieldErrors,
          ));
        } else {
          emit(ProfileError(message: failure.message));
        }
      },
      (_) => emit(const ProfilePasswordChanged()),
    );
  }
}
