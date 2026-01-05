import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage server configuration.
/// Allows dynamic server URL configuration instead of hardcoded values.
class ServerConfigService {
  final SharedPreferences _prefs;

  static const String _serverUrlKey = 'server_url';
  static const String _wsUrlKey = 'ws_url';
  static const String _isConfiguredKey = 'is_server_configured';

  ServerConfigService(this._prefs);

  /// Check if server is configured.
  bool get isConfigured => _prefs.getBool(_isConfiguredKey) ?? false;

  /// Get the base URL for API calls.
  String get baseUrl {
    final serverUrl = _prefs.getString(_serverUrlKey);
    if (serverUrl == null || serverUrl.isEmpty) {
      return 'http://localhost/api/v1'; // Fallback
    }
    // Remove trailing slash and ensure /api/v1 suffix
    final cleanUrl = serverUrl.replaceAll(RegExp(r'/+$'), '');
    if (cleanUrl.endsWith('/api/v1')) {
      return cleanUrl;
    }
    return '$cleanUrl/api/v1';
  }

  /// Get the base URL without /api/v1 suffix.
  String get serverUrl {
    return _prefs.getString(_serverUrlKey) ?? '';
  }

  /// Get WebSocket URL.
  String get wsUrl {
    final wsUrl = _prefs.getString(_wsUrlKey);
    if (wsUrl != null && wsUrl.isNotEmpty) {
      return wsUrl;
    }
    // Generate WebSocket URL from server URL
    final server = serverUrl;
    if (server.isEmpty) return 'ws://localhost/ws';

    final wsProtocol = server.startsWith('https://') ? 'wss://' : 'ws://';
    final host = server
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceAll(RegExp(r'/+$'), '');
    return '$wsProtocol$host/ws';
  }

  /// Save server configuration.
  Future<void> saveConfig({
    required String serverUrl,
    String? wsUrl,
  }) async {
    // Clean and normalize URL
    String cleanUrl = serverUrl.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      // Default to http for local development
      cleanUrl = 'http://$cleanUrl';
    }
    cleanUrl = cleanUrl.replaceAll(RegExp(r'/+$'), '');

    await _prefs.setString(_serverUrlKey, cleanUrl);
    if (wsUrl != null && wsUrl.isNotEmpty) {
      await _prefs.setString(_wsUrlKey, wsUrl);
    }
    await _prefs.setBool(_isConfiguredKey, true);
  }

  /// Clear server configuration.
  Future<void> clearConfig() async {
    await _prefs.remove(_serverUrlKey);
    await _prefs.remove(_wsUrlKey);
    await _prefs.setBool(_isConfiguredKey, false);
  }

  /// Validate server URL format.
  static bool isValidUrl(String url) {
    if (url.isEmpty) return false;

    String testUrl = url.trim();
    if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
      // Default to http for local development
      testUrl = 'http://$testUrl';
    }

    try {
      final uri = Uri.parse(testUrl);
      return uri.hasScheme && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Test connection to server.
  Future<ServerTestResult> testConnection(String url) async {
    try {
      String testUrl = url.trim();
      if (!testUrl.startsWith('http://') && !testUrl.startsWith('https://')) {
        // Default to http for local development
        testUrl = 'http://$testUrl';
      }
      testUrl = testUrl.replaceAll(RegExp(r'/+$'), '');

      final uri = Uri.parse('$testUrl/api/v1/settings');

      // Use a simple HTTP client for testing
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(uri);
      final response = await request.close();

      client.close();

      if (response.statusCode >= 200 && response.statusCode < 500) {
        return ServerTestResult.success();
      } else {
        return ServerTestResult.error('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        return ServerTestResult.error('Cannot connect to server. Check the URL and try again.');
      }
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        return ServerTestResult.error('SSL certificate error. Try using http:// instead of https://');
      }
      return ServerTestResult.error('Connection failed: ${e.toString()}');
    }
  }
}

/// Result of server connection test.
class ServerTestResult {
  final bool isSuccess;
  final String? errorMessage;

  ServerTestResult._({required this.isSuccess, this.errorMessage});

  factory ServerTestResult.success() => ServerTestResult._(isSuccess: true);

  factory ServerTestResult.error(String message) =>
      ServerTestResult._(isSuccess: false, errorMessage: message);
}
