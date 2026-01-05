part of 'settings_bloc.dart';

/// Settings state.
class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final Locale locale;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool appointmentReminders;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('pt'),
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.appointmentReminders = true,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? appointmentReminders,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      appointmentReminders: appointmentReminders ?? this.appointmentReminders,
    );
  }

  /// Get theme mode display name.
  String get themeModeDisplayName {
    switch (themeMode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  /// Get locale display name.
  String get localeDisplayName {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'pt':
        return 'Português';
      case 'es':
        return 'Español';
      case 'de':
        return 'Deutsch';
      default:
        return locale.languageCode;
    }
  }

  @override
  List<Object?> get props => [
        themeMode,
        locale,
        pushNotifications,
        emailNotifications,
        appointmentReminders,
      ];
}
