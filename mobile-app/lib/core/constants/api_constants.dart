import '../injection/injection.dart';
import '../services/server_config_service.dart';

/// API configuration constants.
class ApiConstants {
  ApiConstants._();

  /// Base URL for the API (from ServerConfigService).
  static String get baseUrl {
    try {
      return getIt<ServerConfigService>().baseUrl;
    } catch (e) {
      // Fallback during initialization
      return 'http://localhost/api/v1';
    }
  }

  /// WebSocket URL for real-time updates.
  static String get wsBaseUrl {
    try {
      return getIt<ServerConfigService>().wsUrl;
    } catch (e) {
      // Fallback during initialization
      return 'ws://localhost/ws';
    }
  }

  /// Check if server is configured.
  static bool get isServerConfigured {
    try {
      return getIt<ServerConfigService>().isConfigured;
    } catch (e) {
      return false;
    }
  }

  /// Connection timeout in milliseconds.
  static const int connectTimeout = 30000;

  /// Receive timeout in milliseconds.
  static const int receiveTimeout = 30000;

  /// API version.
  static const String apiVersion = 'v1';

  // Auth endpoints
  static const String authLogin = '/auth/login';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authMe = '/auth/me';

  // Appointments endpoints
  static const String appointments = '/appointments';
  static String appointment(int id) => '/appointments/$id';

  // Providers endpoints
  static const String providers = '/providers';
  static String provider(int id) => '/providers/$id';

  // Services endpoints
  static const String services = '/services';
  static String service(int id) => '/services/$id';

  // Customers endpoints
  static const String customers = '/customers';
  static String customer(int id) => '/customers/$id';

  // Admins endpoints
  static const String admins = '/admins';
  static String admin(int id) => '/admins/$id';

  // Secretaries endpoints
  static const String secretaries = '/secretaries';
  static String secretary(int id) => '/secretaries/$id';

  // Profile endpoints (role-based updates)
  static String updateAdmin(int id) => '/admins/$id';
  static String updateProvider(int id) => '/providers/$id';
  static String updateSecretary(int id) => '/secretaries/$id';
  static String updateCustomer(int id) => '/customers/$id';

  // Password change endpoint
  static const String changePassword = '/auth/change-password';

  // Availabilities endpoint
  static const String availabilities = '/availabilities';

  // Settings endpoint
  static const String settings = '/settings';
  static const String appointmentStatusOptions = '/settings/appointment_status_options';

  // Two-factor authentication endpoints
  static const String twoFactorVerify = '/2fa/verify';
}
