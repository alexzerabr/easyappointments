import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/injection/injection.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/notifications/presentation/bloc/notifications_bloc.dart';
import 'features/settings/presentation/bloc/settings_bloc.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase (may fail if not configured)
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Main] Firebase initialization failed: $e');
    }
  }

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Configure dependency injection
  await configureDependencies();

  try {
    // Initialize push notifications (may fail without Firebase)
    await getIt<PushNotificationService>().initialize();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[Main] Push notification initialization failed: $e');
    }
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const EasyAppointmentsApp());
}

class EasyAppointmentsApp extends StatelessWidget {
  const EasyAppointmentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          // Don't trigger auth check here - let SplashPage handle it after checking server config
          create: (_) => getIt<AuthBloc>(),
        ),
        BlocProvider(
          create: (_) => getIt<NotificationsBloc>(),
        ),
        BlocProvider(
          create: (_) => getIt<SettingsBloc>()..add(const SettingsLoadRequested()),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthUnauthenticated) {
            // Navigate to login when user logs out
            appRouter.go('/login');
          }
        },
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            return MaterialApp.router(
              title: 'Easy!Appointments',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settingsState.themeMode,
              routerConfig: appRouter,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: settingsState.locale,
            );
          },
        ),
      ),
    );
  }
}
