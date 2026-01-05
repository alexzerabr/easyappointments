import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_event.dart';
part 'settings_state.dart';

/// Settings BLoC for managing app preferences.
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const String _themeModeKey = 'theme_mode';
  static const String _localeKey = 'locale';
  static const String _pushNotificationsKey = 'push_notifications';
  static const String _emailNotificationsKey = 'email_notifications';
  static const String _appointmentRemindersKey = 'appointment_reminders';

  SettingsBloc() : super(const SettingsState()) {
    on<SettingsLoadRequested>(_onLoadRequested);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<LocaleChanged>(_onLocaleChanged);
    on<PushNotificationsToggled>(_onPushNotificationsToggled);
    on<EmailNotificationsToggled>(_onEmailNotificationsToggled);
    on<AppointmentRemindersToggled>(_onAppointmentRemindersToggled);
  }

  Future<void> _onLoadRequested(
    SettingsLoadRequested event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 0;
    final localeCode = prefs.getString(_localeKey) ?? 'pt';
    final pushNotifications = prefs.getBool(_pushNotificationsKey) ?? true;
    final emailNotifications = prefs.getBool(_emailNotificationsKey) ?? true;
    final appointmentReminders = prefs.getBool(_appointmentRemindersKey) ?? true;

    emit(state.copyWith(
      themeMode: ThemeMode.values[themeModeIndex],
      locale: Locale(localeCode),
      pushNotifications: pushNotifications,
      emailNotifications: emailNotifications,
      appointmentReminders: appointmentReminders,
    ));
  }

  Future<void> _onThemeModeChanged(
    ThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, event.themeMode.index);

    emit(state.copyWith(themeMode: event.themeMode));
  }

  Future<void> _onLocaleChanged(
    LocaleChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, event.locale.languageCode);

    emit(state.copyWith(locale: event.locale));
  }

  Future<void> _onPushNotificationsToggled(
    PushNotificationsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationsKey, event.enabled);

    emit(state.copyWith(pushNotifications: event.enabled));
  }

  Future<void> _onEmailNotificationsToggled(
    EmailNotificationsToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emailNotificationsKey, event.enabled);

    emit(state.copyWith(emailNotifications: event.enabled));
  }

  Future<void> _onAppointmentRemindersToggled(
    AppointmentRemindersToggled event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appointmentRemindersKey, event.enabled);

    emit(state.copyWith(appointmentReminders: event.enabled));
  }
}
