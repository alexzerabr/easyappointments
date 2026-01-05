import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/password_change_request_model.dart';
import '../models/profile_update_request_model.dart';

/// Remote data source for profile management.
abstract class ProfileRemoteDataSource {
  Future<UserModel> getProfile();
  Future<UserModel> updateProfile(
    ProfileUpdateRequestModel request,
    String role,
    int userId,
  );
  Future<void> changePassword(PasswordChangeRequestModel request);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final ApiClient _apiClient;

  ProfileRemoteDataSourceImpl(this._apiClient);

  @override
  Future<UserModel> getProfile() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.authMe,
      );

      if (response['success'] != true) {
        throw ServerException(
          message: response['message'] ?? 'Failed to get profile',
          code: response['code'],
        );
      }

      return UserModel.fromJson(response['data']);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to get profile: ${e.toString()}',
      );
    }
  }

  @override
  Future<UserModel> updateProfile(
    ProfileUpdateRequestModel request,
    String role,
    int userId,
  ) async {
    try {


      // Determine endpoint based on user role
      final String endpoint;
      switch (role.toLowerCase()) {
        case 'admin':
          endpoint = ApiConstants.updateAdmin(userId);
          break;
        case 'provider':
          endpoint = ApiConstants.updateProvider(userId);
          break;
        case 'secretary':
          endpoint = ApiConstants.updateSecretary(userId);
          break;
        case 'customer':
          endpoint = ApiConstants.updateCustomer(userId);
          break;
        default:
          throw ServerException(
            message: 'Invalid user role: $role',
            code: 'INVALID_ROLE',
          );
      }



      final response = await _apiClient.put<Map<String, dynamic>>(
        endpoint,
        data: request.toJson(),
      );



      // Check if response indicates failure OR if it's not a direct user object (missing id) AND not a success envelope
      if ((response['success'] == false) || (response['id'] == null && response['success'] != true)) {
        final code = response['code'] as String?;
        final message = response['message'] as String? ?? 'Failed to update profile';

        // Handle validation errors with field-specific messages
        if (code == 'VALIDATION_ERROR' && response['errors'] != null) {
          throw ValidationException(
            message: message,
            fieldErrors: Map<String, List<String>>.from(
              (response['errors'] as Map<String, dynamic>).map(
                (key, value) => MapEntry(
                  key,
                  (value as List).map((e) => e.toString()).toList(),
                ),
              ),
            ),
          );
        }

        throw ServerException(
          message: message,
          code: code,
        );
      }

      // If response has 'id', it's the user object. If it has 'data', use that.
      final userData = Map<String, dynamic>.from(
        response['id'] != null ? response : (response['data'] as Map<String, dynamic>),
      );
      
      // Ensure role is present (backend update response doesn't include it)
      if (userData['role'] == null) {
        userData['role'] = role;
      }
      
      return UserModel.fromJson(userData);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to update profile: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> changePassword(PasswordChangeRequestModel request) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.changePassword,
        data: request.toJson(),
      );

      if (response['success'] != true) {
        final code = response['code'] as String?;
        final message = response['message'] as String? ?? 'Failed to change password';

        // Handle specific password change errors
        // Handle specific password change errors
        if (code == 'INVALID_PASSWORD') {
          throw ServerException(
            message: 'invalidPassword',
            code: code,
          );
        } else if (code == 'WEAK_PASSWORD') {
          throw ServerException(
            message: 'newPasswordTooWeak',
            code: code,
          );
        } else if (code == 'USER_NOT_FOUND') {
          throw ServerException(
            message: 'userNotFound',
            code: code,
          );
        } else if (code == 'MISSING_FIELDS') {
          throw ServerException(
            message: 'missingFields',
            code: code,
          );
        } else if (code == 'TOKEN_EXPIRED') {
          throw ServerException(
            message: 'tokenExpired',
            code: code,
          );
        } else if (code == 'INVALID_TOKEN' || code == 'MISSING_TOKEN') {
          throw ServerException(
            message: 'invalidToken',
            code: code,
          );
        } else if (code == 'VALIDATION_ERROR' && response['errors'] != null) {
          throw ValidationException(
            message: message,
            fieldErrors: Map<String, List<String>>.from(
              (response['errors'] as Map<String, dynamic>).map(
                (key, value) => MapEntry(
                  key,
                  (value as List).map((e) => e.toString()).toList(),
                ),
              ),
            ),
          );
        }

        throw ServerException(
          message: message,
          code: code,
        );
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Failed to change password: ${e.toString()}',
      );
    }
  }
}
