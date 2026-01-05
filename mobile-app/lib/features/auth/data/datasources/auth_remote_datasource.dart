import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

/// Remote data source for authentication.
abstract class AuthRemoteDataSource {
  Future<(AuthTokensModel, UserModel)> login({
    required String username,
    required String password,
    String? deviceName,
    String? deviceToken,
  });

  Future<void> logout({String? refreshToken, bool logoutAll = false});

  Future<String> refreshToken(String refreshToken);

  Future<UserModel> getCurrentUser();

  /// Verify 2FA code and complete login.
  /// Returns (tokens, user, deviceToken) where deviceToken is optional.
  Future<(AuthTokensModel, UserModel, String?)> verify2FA({
    required String tempToken,
    required String code,
    bool rememberDevice = false,
    String? deviceName,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSourceImpl(this._apiClient);

  @override
  Future<(AuthTokensModel, UserModel)> login({
    required String username,
    required String password,
    String? deviceName,
    String? deviceToken,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.authLogin,
        data: {
          'username': username,
          'password': password,
          if (deviceName != null) 'device_name': deviceName,
        },
        options: deviceToken != null
            ? Options(headers: {'X-2FA-Device-Token': deviceToken})
            : null,
      );

      if (response['success'] != true) {
        final code = response['code'] as String?;
        final message = response['message'] as String? ?? 'Login failed';

        // Check for authentication-related error codes
        if (code == 'INVALID_CREDENTIALS') {
          throw AuthException.invalidCredentials();
        } else if (code == 'TOKEN_EXPIRED') {
          throw AuthException.tokenExpired();
        } else if (code == 'UNAUTHORIZED') {
          throw AuthException.unauthorized();
        }

        throw ServerException(
          message: message,
          code: code,
        );
      }

      // Check if 2FA is required
      if (response['requires_2fa'] == true) {
        final tempToken = response['temp_token'] as String? ?? '';
        throw TwoFactorRequiredException(tempToken: tempToken);
      }

      final data = response['data'] as Map<String, dynamic>;
      final tokens = AuthTokensModel.fromJson(data['tokens']);
      final user = UserModel.fromJson(data['user']);

      return (tokens, user);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Login failed: ${e.toString()}');
    }
  }

  @override
  Future<void> logout({String? refreshToken, bool logoutAll = false}) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.authLogout,
        data: {
          if (refreshToken != null) 'refresh_token': refreshToken,
          'all': logoutAll,
        },
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Logout failed: ${e.toString()}');
    }
  }

  @override
  Future<String> refreshToken(String refreshToken) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.authRefresh,
        data: {'refresh_token': refreshToken},
      );

      if (response['success'] != true) {
        throw AuthException(
          message: response['message'] ?? 'Token refresh failed',
          code: response['code'],
        );
      }

      return response['data']['access_token'] as String;
    } on AppException {
      rethrow;
    } catch (e) {
      throw AuthException.tokenExpired();
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.authMe,
      );

      if (response['success'] != true) {
        throw ServerException(
          message: response['message'] ?? 'Failed to get user',
          code: response['code'],
        );
      }

      return UserModel.fromJson(response['data']);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(message: 'Failed to get user: ${e.toString()}');
    }
  }

  @override
  Future<(AuthTokensModel, UserModel, String?)> verify2FA({
    required String tempToken,
    required String code,
    bool rememberDevice = false,
    String? deviceName,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.twoFactorVerify,
        data: {
          'temp_token': tempToken,
          'code': code,
          'remember_device': rememberDevice,
          if (deviceName != null) 'device_name': deviceName,
        },
      );

      if (response['success'] != true) {
        final code = response['code'] as String?;
        final message = response['message'] as String? ?? '2FA verification failed';

        if (code == 'INVALID_CODE') {
          throw const AuthException(
            message: 'Invalid verification code',
            code: 'INVALID_CODE',
          );
        } else if (code == 'RATE_LIMITED') {
          throw const AuthException(
            message: 'Too many attempts. Please try again later.',
            code: 'RATE_LIMITED',
          );
        } else if (code == 'INVALID_2FA_SESSION') {
          throw AuthException.tokenExpired();
        }

        throw ServerException(
          message: message,
          code: code,
        );
      }

      final data = response['data'] as Map<String, dynamic>;
      final tokens = AuthTokensModel.fromJson(data['tokens']);
      final user = UserModel.fromJson(data['user']);
      final newDeviceToken = data['device_token'] as String?;

      return (tokens, user, newDeviceToken);
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(message: '2FA verification failed: ${e.toString()}');
    }
  }
}
