import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/server_config_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/settings_bloc.dart';

/// Page for configuring the server URL.
/// Shown on first launch or when server needs to be reconfigured.
class ServerSetupPage extends StatefulWidget {
  /// Whether this is the initial setup (first launch).
  final bool isInitialSetup;

  const ServerSetupPage({
    super.key,
    this.isInitialSetup = true,
  });

  @override
  State<ServerSetupPage> createState() => _ServerSetupPageState();
}

class _ServerSetupPageState extends State<ServerSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _serverConfigService = getIt<ServerConfigService>();

  bool _isLoading = false;
  bool _isTesting = false;
  String? _errorMessage;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing URL if available
    final currentUrl = _serverConfigService.serverUrl;
    if (currentUrl.isNotEmpty) {
      _serverUrlController.text = currentUrl;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _testSuccess = false;
    });

    final result = await _serverConfigService.testConnection(
      _serverUrlController.text,
    );

    setState(() {
      _isTesting = false;
      if (result.isSuccess) {
        _testSuccess = true;
        _errorMessage = null;
      } else {
        _testSuccess = false;
        _errorMessage = result.errorMessage;
      }
    });
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Test connection first
      final result = await _serverConfigService.testConnection(
        _serverUrlController.text,
      );

      if (!result.isSuccess) {
        setState(() {
          _isLoading = false;
          _errorMessage = result.errorMessage;
        });
        return;
      }

      // Save configuration
      await _serverConfigService.saveConfig(
        serverUrl: _serverUrlController.text,
      );

      if (mounted) {
        // Restart the app to reinitialize with new server
        context.go(AppRoutes.splash);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '${_getLocalizedErrorMessage()}: ${e.toString()}';
      });
    }
  }

  String _getLocalizedErrorMessage() {
    // Get l10n from context - this is a fallback since we can't access l10n in catch block
    return 'Failed to save configuration';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Language selector in top-right corner
              Positioned(
                top: 8,
                right: 8,
                child: _LanguageSelector(),
              ),
              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'EA',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        // Title
                        Text(
                          widget.isInitialSetup
                              ? l10n.get('welcomeToEasyAppointments')
                              : l10n.get('serverConfiguration'),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          widget.isInitialSetup
                              ? l10n.get('pleaseEnterServerUrl')
                              : l10n.get('updateServerSettings'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Server URL field
                        TextFormField(
                          controller: _serverUrlController,
                          decoration: InputDecoration(
                            labelText: l10n.get('serverUrl'),
                            hintText: l10n.get('serverUrlHint'),
                            prefixIcon: const Icon(Icons.dns),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: _testSuccess
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                          ),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.get('pleaseEnterServerUrlError');
                            }
                            if (!ServerConfigService.isValidUrl(value)) {
                              return l10n.get('pleaseEnterValidUrl');
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _testConnection(),
                        ),
                        const SizedBox(height: 8),

                        // Help text
                        Text(
                          l10n.get('serverUrlHelp').replaceAll('\\n', '\n'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.red[700], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Success message
                        if (_testSuccess)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.green[700], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.get('connectionSuccessfulMessage'),
                                    style: TextStyle(color: Colors.green[700], fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Test Connection button
                        OutlinedButton.icon(
                          onPressed: _isTesting || _isLoading ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_find),
                          label: Text(_isTesting ? l10n.get('testing') : l10n.testConnection),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Save button
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _saveAndContinue,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward),
                          label: Text(_isLoading ? l10n.get('connecting') : l10n.get('saveAndContinue')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        // Skip button for non-initial setup
                        if (!widget.isInitialSetup) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(l10n.cancel),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
      ),
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
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 20, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _getLanguageCode(state.locale),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.primary),
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
