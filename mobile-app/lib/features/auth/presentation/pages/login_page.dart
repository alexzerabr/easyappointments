import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/server_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/auth_bloc.dart';

/// Login page for user authentication.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(AuthLoginRequested(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.calendar);
        } else if (state is Auth2FARequired) {
          context.push(
            AppRoutes.twoFactorVerify,
            extra: {
              'tempToken': state.tempToken,
              'username': state.username,
            },
          );
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final l10n = AppLocalizations.of(context);

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                // Language selector in top-right corner
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LanguageSelector(),
                ),
                // Main content
                LoadingOverlay(
                  isLoading: isLoading,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 60),

                          // Logo
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Center(
                            child: Text(
                              'EA',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        l10n.welcome,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.signInToContinue,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Username field
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.get('pleaseEnterUsername');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _onLogin(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.get('pleaseEnterPassword');
                          }
                          if (value.length < 6) {
                            return l10n.get('passwordMinLength');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Login button
                      ElevatedButton(
                        onPressed: isLoading ? null : _onLogin,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            l10n.login,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Help text
                      Text(
                        l10n.get('contactAdminHelp'),
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Server info and change button
                      _buildServerInfo(context),
                    ],
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServerInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final serverConfig = getIt<ServerConfigService>();
    final serverUrl = serverConfig.serverUrl;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dns_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                serverUrl.isNotEmpty ? serverUrl : l10n.get('noServerConfigured'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            context.push(AppRoutes.serverSetup);
          },
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(l10n.changeServer),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Language selector widget.
class _LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        return PopupMenuButton<Locale>(
          initialValue: state.locale,
          onSelected: (locale) {
            context.read<SettingsBloc>().add(LocaleChanged(locale));
          },
          itemBuilder: (context) => [
            _buildLanguageItem(const Locale('pt'), 'Portugues', state.locale),
            _buildLanguageItem(const Locale('en'), 'English', state.locale),
            _buildLanguageItem(const Locale('es'), 'Espanol', state.locale),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 20, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _getLanguageCode(state.locale),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<Locale> _buildLanguageItem(
    Locale locale,
    String label,
    Locale currentLocale,
  ) {
    final isSelected = locale.languageCode == currentLocale.languageCode;
    return PopupMenuItem<Locale>(
      value: locale,
      child: Row(
        children: [
          if (isSelected)
            const Icon(Icons.check, size: 18, color: AppColors.primary)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppColors.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageCode(Locale locale) {
    switch (locale.languageCode) {
      case 'pt':
        return 'PT';
      case 'en':
        return 'EN';
      case 'es':
        return 'ES';
      default:
        return 'PT';
    }
  }
}
