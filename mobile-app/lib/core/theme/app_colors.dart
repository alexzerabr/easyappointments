import 'package:flutter/material.dart';

/// Application color palette based on Easy!Appointments branding.
class AppColors {
  AppColors._();

  // Primary colors (Easy!Appointments teal/green)
  static const Color primary = Color(0xFF429A82);
  static const Color primaryLight = Color(0xFF80E3AD);
  static const Color primaryDark = Color(0xFF1A865F);

  // Secondary colors
  static const Color secondary = Color(0xFF35A768);
  static const Color secondaryLight = Color(0xFF6FD89E);
  static const Color secondaryDark = Color(0xFF1B7840);

  // Accent colors
  static const Color accent = Color(0xFFFF6B6B);

  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Neutral colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);

  // Background colors
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Status colors for appointments
  static const Color statusPending = Color(0xFFFFA726);
  static const Color statusConfirmed = Color(0xFF66BB6A);
  static const Color statusCompleted = Color(0xFF42A5F5);
  static const Color statusCancelled = Color(0xFFEF5350);
  static const Color statusNoShow = Color(0xFF78909C);

  // Calendar colors (matching Easy!Appointments theme)
  static const Color calendarToday = Color(0xFFE8F5E9);
  static const Color calendarSelected = Color(0xFF429A82);
  static const Color calendarEvent = Color(0xFF80E3AD);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
