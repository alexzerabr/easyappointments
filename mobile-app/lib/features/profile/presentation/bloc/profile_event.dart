part of 'profile_bloc.dart';

/// Base class for profile events.
abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load the current profile.
class ProfileLoadRequested extends ProfileEvent {
  const ProfileLoadRequested();
}

/// Event to update the profile.
class ProfileUpdateRequested extends ProfileEvent {
  final ProfileUpdateRequest request;

  const ProfileUpdateRequested(this.request);

  @override
  List<Object?> get props => [request];
}

/// Event to change password.
class ProfilePasswordChangeRequested extends ProfileEvent {
  final PasswordChangeRequest request;

  const ProfilePasswordChangeRequested(this.request);

  @override
  List<Object?> get props => [request];
}
