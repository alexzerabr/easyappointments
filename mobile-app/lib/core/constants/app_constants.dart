/// Application-wide constants.
class AppConstants {
  AppConstants._();

  /// Application name.
  static const String appName = 'Easy!Appointments';

  /// Application version.
  static const String appVersion = '1.0.0';

  /// Minimum password length.
  static const int minPasswordLength = 6;

  /// Default page size for pagination.
  static const int defaultPageSize = 20;

  /// Token refresh threshold in seconds (refresh when less than 5 minutes left).
  static const int tokenRefreshThreshold = 300;

  /// WebSocket reconnect delay in seconds.
  static const int wsReconnectDelay = 3;

  /// Maximum WebSocket reconnect attempts.
  static const int wsMaxReconnectAttempts = 10;

  /// Cache duration in hours.
  static const int cacheDurationHours = 24;

  /// Date format for display.
  static const String dateFormat = 'dd/MM/yyyy';

  /// Time format for display.
  static const String timeFormat = 'HH:mm';

  /// DateTime format for display.
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';

  /// Supported locales.
  static const List<String> supportedLocales = ['pt', 'en', 'es'];

  /// Default locale.
  static const String defaultLocale = 'pt';
}
