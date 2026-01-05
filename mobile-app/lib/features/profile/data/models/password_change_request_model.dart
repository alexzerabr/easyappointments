import '../../domain/entities/password_change_request.dart';

/// Password change request model for JSON serialization.
class PasswordChangeRequestModel extends PasswordChangeRequest {
  const PasswordChangeRequestModel({
    required super.currentPassword,
    required super.newPassword,
  });

  factory PasswordChangeRequestModel.fromEntity(PasswordChangeRequest request) {
    return PasswordChangeRequestModel(
      currentPassword: request.currentPassword,
      newPassword: request.newPassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_password': currentPassword,
      'new_password': newPassword,
    };
  }
}
