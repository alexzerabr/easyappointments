import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/server_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';

/// Splash page shown while checking authentication status.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _isCheckingServer = true;
  bool _serverConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkServerConfiguration();
  }

  Future<void> _checkServerConfiguration() async {
    // Small delay for splash screen visibility
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final serverConfig = getIt<ServerConfigService>();
    final isConfigured = serverConfig.isConfigured;

    setState(() {
      _isCheckingServer = false;
      _serverConfigured = isConfigured;
    });

    if (!isConfigured) {
      // Redirect to server setup
      if (mounted) {
        context.go('${AppRoutes.serverSetup}?initial=true');
      }
    } else {
      // Reconfigure Dio with saved URL and check auth
      reconfigureDio();

      // Trigger auth check
      if (mounted) {
        context.read<AuthBloc>().add(const AuthCheckRequested());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Only handle auth states if server is configured
        if (!_serverConfigured) return;

        if (state is AuthAuthenticated) {
          context.go(AppRoutes.calendar);
        } else if (state is AuthUnauthenticated) {
          context.go(AppRoutes.login);
        } else if (state is AuthError) {
          // On auth error, go to login
          context.go(AppRoutes.login);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'EA',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // App name
                const Text(
                  'Easy!Appointments',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  AppLocalizations.of(context).get('scheduleWithEase'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 48),

                // Loading indicator
                if (_isCheckingServer) ...[
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context).get('checkingConfiguration'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ] else if (_serverConfigured) ...[
                  // Show loading while checking auth
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is AuthLoading || state is AuthInitial) {
                        return Column(
                          children: [
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context).get('connectingToServer'),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
