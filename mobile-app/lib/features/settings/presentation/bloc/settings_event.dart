part of 'settings_bloc.dart';

/// Base class for settings events.
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load settings from storage.
class SettingsLoadRequested extends SettingsEvent {
  const SettingsLoadRequested();
}

/// Event to change theme mode.
class ThemeModeChanged extends SettingsEvent {
  final ThemeMode themeMode;

  const ThemeModeChanged(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

/// Event to change locale.
class LocaleChanged extends SettingsEvent {
  final Locale locale;

  const LocaleChanged(this.locale);

  @override
  List<Object?> get props => [locale];
}

/// Event to toggle push notifications.
class PushNotificationsToggled extends SettingsEvent {
  final bool enabled;

  const PushNotificationsToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Event to toggle email notifications.
class EmailNotificationsToggled extends SettingsEvent {
  final bool enabled;

  const EmailNotificationsToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Event to toggle appointment reminders.
class AppointmentRemindersToggled extends SettingsEvent {
  final bool enabled;

  const AppointmentRemindersToggled(this.enabled);

  @override
  List<Object?> get props => [enabled];
}
