import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/two_factor_verify_page.dart';
import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/appointments/presentation/pages/appointment_details_page.dart';
import '../../features/appointments/presentation/pages/new_appointment_page.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/change_password_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/server_setup_page.dart';
import '../widgets/main_scaffold.dart';

/// Application routes.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String serverSetup = '/server-setup';
  static const String login = '/login';
  static const String twoFactorVerify = '/2fa/verify';
  static const String home = '/home';
  static const String calendar = '/calendar';
  static const String appointments = '/appointments';
  static const String appointmentDetails = '/appointments/:id';
  static const String newAppointment = '/appointments/new';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String profile = '/profile';
}

/// Global navigator key.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Application router configuration.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: true,
  routes: [
    // Splash screen
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashPage(),
    ),

    // Server setup screen
    GoRoute(
      path: AppRoutes.serverSetup,
      builder: (context, state) {
        final isInitial = state.uri.queryParameters['initial'] == 'true';
        return ServerSetupPage(isInitialSetup: isInitial);
      },
    ),

    // Login screen
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginPage(),
    ),

    // Two-factor authentication verification
    GoRoute(
      path: AppRoutes.twoFactorVerify,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return TwoFactorVerifyPage(
          tempToken: extra?['tempToken'] ?? '',
          username: extra?['username'],
        );
      },
    ),

    // Main app shell with bottom navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        // Calendar (Home)
        GoRoute(
          path: AppRoutes.calendar,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CalendarPage(),
          ),
        ),

        // Appointments list
        GoRoute(
          path: AppRoutes.appointments,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AppointmentsPage(),
          ),
          routes: [
            // New appointment - MUST be before :id to avoid "new" being parsed as id
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const NewAppointmentPage(),
            ),
            // Appointment details
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final idStr = state.pathParameters['id'];
                final id = int.tryParse(idStr ?? '') ?? 0;
                return AppointmentDetailsPage(appointmentId: id);
              },
            ),
          ],
        ),

        // Settings
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsPage(),
          ),
        ),
      ],
    ),

    // Notifications (full screen)
    GoRoute(
      path: AppRoutes.notifications,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NotificationsPage(),
    ),

    // Profile routes (full screen)
    GoRoute(
      path: AppRoutes.profile,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfilePage(),
      routes: [
        // Edit profile
        GoRoute(
          path: 'edit',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const EditProfilePage(),
        ),
        // Change password
        GoRoute(
          path: 'change-password',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (context, state) => const ChangePasswordPage(),
        ),
      ],
    ),
  ],

  // Error handling
  errorBuilder: (context, state) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              l10n.get('pageNotFound'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.calendar),
              child: Text(l10n.goToHome),
            ),
          ],
        ),
      ),
    );
  },

  // Redirect logic
  redirect: (context, state) {
    // Add authentication redirect logic here
    // final isLoggedIn = context.read<AuthBloc>().state is AuthAuthenticated;
    // final isLoggingIn = state.matchedLocation == AppRoutes.login;
    // final isSplash = state.matchedLocation == AppRoutes.splash;

    // if (!isLoggedIn && !isLoggingIn && !isSplash) {
    //   return AppRoutes.login;
    // }

    return null;
  },
);

