import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/user_model.dart';

/// Local data source for authentication.
abstract class AuthLocalDataSource {
  Future<void> saveAccessToken(String token);
  Future<String?> getAccessToken();
  Future<void> saveRefreshToken(String token);
  Future<String?> getRefreshToken();
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> clearTokens();
  Future<void> clearAll();
  Future<bool> hasValidSession();

  // 2FA device token methods
  Future<void> saveDeviceToken(String token);
  Future<String?> getDeviceToken();
  Future<void> clearDeviceToken();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _deviceTokenKey = '2fa_device_token';

  AuthLocalDataSourceImpl(this._secureStorage, this._prefs);

  @override
  Future<void> saveAccessToken(String token) async {
    try {
      await _secureStorage.write(key: _accessTokenKey, value: token);
    } catch (e) {
      throw const CacheException(message: 'Failed to save access token');
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: _accessTokenKey);
    } catch (e) {
      throw const CacheException(message: 'Failed to read access token');
    }
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      throw const CacheException(message: 'Failed to save refresh token');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      throw const CacheException(message: 'Failed to read refresh token');
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await _prefs.setString(_userKey, userJson);
    } catch (e) {
      throw const CacheException(message: 'Failed to save user');
    }
  }

  @override
  Future<UserModel?> getUser() async {
    try {
      final userJson = _prefs.getString(_userKey);
      if (userJson == null) return null;
      return UserModel.fromJson(jsonDecode(userJson));
    } catch (e) {
      throw const CacheException(message: 'Failed to read user');
    }
  }

  @override
  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    } catch (e) {
      throw const CacheException(message: 'Failed to clear tokens');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      await clearTokens();
      await _prefs.remove(_userKey);
      await _prefs.remove(_tokenExpiryKey);
    } catch (e) {
      throw const CacheException(message: 'Failed to clear auth data');
    }
  }

  @override
  Future<bool> hasValidSession() async {
    try {
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();
      return accessToken != null && refreshToken != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> saveDeviceToken(String token) async {
    try {
      await _secureStorage.write(key: _deviceTokenKey, value: token);
    } catch (e) {
      // Don't throw - device token is optional
    }
  }

  @override
  Future<String?> getDeviceToken() async {
    try {
      return await _secureStorage.read(key: _deviceTokenKey);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> clearDeviceToken() async {
    try {
      await _secureStorage.delete(key: _deviceTokenKey);
    } catch (e) {
      // Don't throw - device token is optional
    }
  }
}
