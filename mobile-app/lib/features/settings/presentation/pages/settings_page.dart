import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/server_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/settings_bloc.dart';

/// Settings page.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final user = authState is AuthAuthenticated ? authState.user : null;

          return BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, settingsState) {
              return ListView(
                children: [
                  // User profile header
                  if (user != null)
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              user.initials,
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Divider(),

                  // Account section
                  _SettingsSection(
                    title: l10n.get('account'),
                    children: [
                      _SettingsTile(
                        icon: Icons.person,
                        title: l10n.profile,
                        subtitle: l10n.get('manageYourProfile'),
                        onTap: () {
                          context.push(AppRoutes.profile);
                        },
                      ),
                    ],
                  ),

                  // Connection section
                  _SettingsSection(
                    title: l10n.connection,
                    children: [
                      _SettingsTile(
                        icon: Icons.dns,
                        title: l10n.server,
                        subtitle: getIt<ServerConfigService>().serverUrl,
                        onTap: () {
                          context.push(AppRoutes.serverSetup);
                        },
                      ),
                    ],
                  ),

                  // Settings sections
                  _SettingsSection(
                    title: l10n.preferences,
                    children: [
                      _SettingsTile(
                        icon: Icons.language,
                        title: l10n.language,
                        subtitle: settingsState.localeDisplayName,
                        onTap: () => _showLanguagePicker(context, settingsState),
                      ),
                      _SettingsTile(
                        icon: Icons.dark_mode_outlined,
                        title: l10n.theme,
                        subtitle: _getLocalizedThemeName(l10n, settingsState.themeMode),
                        onTap: () => _showThemePicker(context, settingsState),
                      ),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: l10n.notifications,
                        onTap: () => _showNotificationsSettings(context, settingsState),
                      ),
                    ],
                  ),

                  _SettingsSection(
                    title: l10n.about,
                    children: [
                      _SettingsTile(
                        icon: Icons.info_outline,
                        title: l10n.aboutApp,
                        onTap: () => _showAboutDialog(context),
                      ),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: l10n.privacyPolicy,
                        onTap: () => _openPrivacyPolicy(),
                      ),
                      _SettingsTile(
                        icon: Icons.description_outlined,
                        title: l10n.termsOfService,
                        onTap: () => _openTermsOfService(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Logout button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },
                      icon: const Icon(Icons.logout, color: AppColors.error),
                      label: Text(
                        l10n.signOut,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Version info
                  Center(
                    child: Text(
                      '${l10n.version} 1.0.0',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOut),
        content: Text(l10n.confirmSignOut),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            child: Text(
              l10n.signOut,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, SettingsState settingsState) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<SettingsBloc>();
    final currentLocale = settingsState.locale.languageCode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.get('selectLanguage'),
              style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _LanguageOption(
              language: 'English',
              code: 'en',
              isSelected: currentLocale == 'en',
              onTap: () {
                bloc.add(const LocaleChanged(Locale('en')));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${l10n.languageSetTo} English')),
                );
              },
            ),
            _LanguageOption(
              language: 'Português',
              code: 'pt',
              isSelected: currentLocale == 'pt',
              onTap: () {
                bloc.add(const LocaleChanged(Locale('pt')));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${l10n.languageSetTo} Português')),
                );
              },
            ),
            _LanguageOption(
              language: 'Español',
              code: 'es',
              isSelected: currentLocale == 'es',
              onTap: () {
                bloc.add(const LocaleChanged(Locale('es')));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${l10n.languageSetTo} Español')),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, SettingsState settingsState) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<SettingsBloc>();
    final currentTheme = settingsState.themeMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.get('selectTheme'),
              style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _ThemeOption(
              title: l10n.get('systemDefault'),
              icon: Icons.settings_brightness,
              isSelected: currentTheme == ThemeMode.system,
              onTap: () {
                bloc.add(const ThemeModeChanged(ThemeMode.system));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${l10n.get('themeSetTo')} ${l10n.get('systemDefault')}')),
                );
              },
            ),
            _ThemeOption(
              title: l10n.get('light'),
              icon: Icons.light_mode,
              isSelected: currentTheme == ThemeMode.light,
              onTap: () {
                bloc.add(const ThemeModeChanged(ThemeMode.light));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${l10n.get('themeSetTo')} ${l10n.get('light')}')),
                );
              },
            ),
            _ThemeOption(
              title: l10n.get('dark'),
              icon: Icons.dark_mode,
              isSelected: currentTheme == ThemeMode.dark,
              onTap: () {
                bloc.add(const ThemeModeChanged(ThemeMode.dark));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${l10n.get('themeSetTo')} ${l10n.get('dark')}')),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSettings(BuildContext context, SettingsState settingsState) {
    final l10n = AppLocalizations.of(context);
    final bloc = context.read<SettingsBloc>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => BlocBuilder<SettingsBloc, SettingsState>(
        bloc: bloc,
        builder: (builderContext, state) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notifications,
                style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.pushNotifications),
                subtitle: Text(l10n.receiveReminders),
                value: state.pushNotifications,
                onChanged: (value) {
                  bloc.add(PushNotificationsToggled(value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value
                          ? l10n.get('pushNotificationsEnabled')
                          : l10n.get('pushNotificationsDisabled')),
                    ),
                  );
                },
                activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
              ),
              SwitchListTile(
                title: Text(l10n.emailNotifications),
                subtitle: Text(l10n.receiveEmailUpdates),
                value: state.emailNotifications,
                onChanged: (value) {
                  bloc.add(EmailNotificationsToggled(value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value
                          ? l10n.get('emailNotificationsEnabled')
                          : l10n.get('emailNotificationsDisabled')),
                    ),
                  );
                },
                activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
              ),
              SwitchListTile(
                title: Text(l10n.appointmentReminders),
                subtitle: Text(l10n.getReminders),
                value: state.appointmentReminders,
                onChanged: (value) {
                  bloc.add(AppointmentRemindersToggled(value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(value
                          ? l10n.get('remindersEnabled')
                          : l10n.get('remindersDisabled')),
                    ),
                  );
                },
                activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'EA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Easy!Appointments'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${l10n.version} 1.0.0'),
            const SizedBox(height: 16),
            Text(l10n.get('aboutDescription')),
            const SizedBox(height: 16),
            Text(
              '© 2024 Easy!Appointments\n${l10n.get('openSourceLicense')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final url = Uri.parse('https://easyappointments.org');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(l10n.website),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final serverUrl = getIt<ServerConfigService>().serverUrl;
    final url = Uri.parse('$serverUrl/privacy');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUrl = Uri.parse('https://easyappointments.org/privacy');
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback to main website
      final fallbackUrl = Uri.parse('https://easyappointments.org');
      await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTermsOfService() async {
    final serverUrl = getIt<ServerConfigService>().serverUrl;
    final url = Uri.parse('$serverUrl/terms');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUrl = Uri.parse('https://easyappointments.org/terms');
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback to main website
      final fallbackUrl = Uri.parse('https://easyappointments.org');
      await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  String _getLocalizedThemeName(AppLocalizations l10n, ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.system:
        return l10n.get('systemDefault');
      case ThemeMode.light:
        return l10n.get('light');
      case ThemeMode.dark:
        return l10n.get('dark');
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String language;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.language,
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(language),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: onTap,
    );
  }
}
