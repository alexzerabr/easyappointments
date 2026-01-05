import 'package:equatable/equatable.dart';

/// Password change request parameters.
class PasswordChangeRequest extends Equatable {
  final String currentPassword;
  final String newPassword;

  const PasswordChangeRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}
