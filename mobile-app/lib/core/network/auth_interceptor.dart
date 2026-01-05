import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../constants/api_constants.dart';

/// Interceptor for handling JWT authentication.
class AuthInterceptor extends Interceptor {
  final AuthLocalDataSource _authLocalDataSource;
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._authLocalDataSource, this._dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for login and refresh endpoints
    final skipPaths = [
      ApiConstants.authLogin,
      ApiConstants.authRefresh,
      ApiConstants.twoFactorVerify,
    ];

    final isLoginRequest = options.path.contains(ApiConstants.authLogin);

    if (skipPaths.any((path) => options.path.contains(path))) {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] Skipping auth for path: ${options.path}');
      }

      // For login requests, add 2FA device token if available
      if (isLoginRequest) {
        final deviceToken = await _authLocalDataSource.getDeviceToken();
        if (deviceToken != null) {
          options.headers['X-2FA-Device-Token'] = deviceToken;
          if (kDebugMode) {
            debugPrint('[AuthInterceptor] Added 2FA device token to login request');
          }
        }
      }

      return handler.next(options);
    }

    // Add authorization header
    final accessToken = await _authLocalDataSource.getAccessToken();

    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] Added token to request: ${options.path}');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[AuthInterceptor] No token available for: ${options.path}');
      }
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Handle 401 errors (token expired)
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      final responseData = err.response?.data;
      final code = responseData is Map ? responseData['code'] : null;

      if (code == 'TOKEN_EXPIRED') {
        try {
          _isRefreshing = true;

          // Try to refresh the token
          final refreshToken = await _authLocalDataSource.getRefreshToken();

          if (refreshToken != null) {
            final response = await _dio.post(
              ApiConstants.authRefresh,
              data: {'refresh_token': refreshToken},
            );

            if (response.statusCode == 200) {
              final newAccessToken = response.data['data']['access_token'];

              // Save new access token
              await _authLocalDataSource.saveAccessToken(newAccessToken);

              // Retry the original request
              final options = err.requestOptions;
              options.headers['Authorization'] = 'Bearer $newAccessToken';

              final retryResponse = await _dio.fetch(options);
              _isRefreshing = false;

              return handler.resolve(retryResponse);
            }
          }
        } catch (e) {
          // Refresh failed, clear tokens and let error propagate
          await _authLocalDataSource.clearTokens();
        } finally {
          _isRefreshing = false;
        }
      }
    }

    return handler.next(err);
  }
}
