part of 'profile_bloc.dart';

/// Base class for profile states.
abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

/// Initial profile state.
class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

/// Loading state during profile operations.
class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

/// State when profile is loaded.
class ProfileLoaded extends ProfileState {
  final User user;

  const ProfileLoaded({required this.user});

  @override
  List<Object?> get props => [user];
}

/// State when profile is successfully updated.
class ProfileUpdated extends ProfileState {
  final User user;

  const ProfileUpdated({required this.user});

  @override
  List<Object?> get props => [user];
}

/// State when password is successfully changed.
class ProfilePasswordChanged extends ProfileState {
  const ProfilePasswordChanged();
}

/// State when profile operation fails.
class ProfileError extends ProfileState {
  final String message;
  final Map<String, List<String>>? fieldErrors;

  const ProfileError({
    required this.message,
    this.fieldErrors,
  });

  @override
  List<Object?> get props => [message, fieldErrors];
}
