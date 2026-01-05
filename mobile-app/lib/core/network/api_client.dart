import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../errors/exceptions.dart';

/// API client wrapper for making HTTP requests.
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  /// Perform a GET request.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Perform a POST request.
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Perform a PUT request.
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Perform a DELETE request.
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle Dio errors and convert to app exceptions.
  AppException _handleDioError(DioException error) {
    if (kDebugMode) {
      dev.log(
        'DioException: type=${error.type}, message=${error.message}, '
        'statusCode=${error.response?.statusCode}, '
        'requestPath=${error.requestOptions.path}, '
        'baseUrl=${error.requestOptions.baseUrl}',
        name: 'ApiClient',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException(message: 'Connection timeout');

      case DioExceptionType.connectionError:
        if (kDebugMode) {
          dev.log('Connection error details: ${error.error}', name: 'ApiClient');
        }
        return NetworkException(
          message: 'Connection error: ${error.message ?? 'Cannot connect to server'}',
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);

      case DioExceptionType.cancel:
        return const ServerException(message: 'Request cancelled');

      default:
        if (kDebugMode) {
          dev.log('Unknown error details: ${error.error}', name: 'ApiClient');
        }
        return ServerException(
          message: 'Request failed: ${error.message ?? error.error?.toString() ?? 'Unknown error'}',
          statusCode: error.response?.statusCode,
        );
    }
  }

  /// Handle bad HTTP responses.
  AppException _handleBadResponse(Response? response) {
    if (response == null) {
      return const ServerException(message: 'No response from server');
    }

    final statusCode = response.statusCode;
    final data = response.data;

    String message = 'Server error';
    String? code;

    if (data is Map<String, dynamic>) {
      message = data['message'] ?? message;
      code = data['code'];
    }

    switch (statusCode) {
      case 400:
        return ValidationException(message: message, code: code);

      case 401:
        if (code == 'TOKEN_EXPIRED') {
          return AuthException.tokenExpired();
        }
        return AuthException.invalidCredentials();

      case 403:
        return AuthException.unauthorized();

      case 404:
        return NotFoundException(message: message);

      case 422:
        Map<String, List<String>>? fieldErrors;
        if (data is Map<String, dynamic> && data['errors'] != null) {
          fieldErrors = (data['errors'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(
              key,
              (value as List).cast<String>(),
            ),
          );
        }
        return ValidationException(
          message: message,
          fieldErrors: fieldErrors,
        );

      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message: 'Server error. Please try again later.',
          statusCode: statusCode,
        );

      default:
        return ServerException(
          message: message,
          statusCode: statusCode,
          code: code,
        );
    }
  }
}
