import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/loading_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/auth_bloc.dart';

/// Two-factor authentication verification page.
class TwoFactorVerifyPage extends StatefulWidget {
  final String tempToken;
  final String? username;

  const TwoFactorVerifyPage({
    super.key,
    required this.tempToken,
    this.username,
  });

  @override
  State<TwoFactorVerifyPage> createState() => _TwoFactorVerifyPageState();
}

class _TwoFactorVerifyPageState extends State<TwoFactorVerifyPage> {
  final _codeController = TextEditingController();
  bool _rememberDevice = false;
  bool _isRecoveryMode = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onVerify() {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    // For TOTP, expect 6 digits. For recovery, expect any non-empty code.
    if (!_isRecoveryMode && code.length != 6) return;

    context.read<AuthBloc>().add(Auth2FAVerifyRequested(
          tempToken: widget.tempToken,
          code: code,
          rememberDevice: _rememberDevice,
        ));
  }

  void _toggleRecoveryMode() {
    setState(() {
      _isRecoveryMode = !_isRecoveryMode;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(AppRoutes.calendar);
        } else if (state is Auth2FAError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is Auth2FALoading;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(AppRoutes.login),
            ),
            title: Text(l10n.get('twoFactorVerification')),
          ),
          body: LoadingOverlay(
            isLoading: isLoading,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),

                  // Icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecoveryMode ? Icons.vpn_key : Icons.security,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    _isRecoveryMode
                        ? l10n.get('enterRecoveryCode')
                        : l10n.get('enterVerificationCode'),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    _isRecoveryMode
                        ? l10n.get('enterRecoveryCodeDescription')
                        : l10n.get('enterCodeFromAuthenticator'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  if (widget.username != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.username!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Code input
                  if (_isRecoveryMode)
                    _buildRecoveryCodeInput(context)
                  else
                    _buildTotpCodeInput(context),

                  const SizedBox(height: 24),

                  // Remember device checkbox
                  CheckboxListTile(
                    value: _rememberDevice,
                    onChanged: (value) {
                      setState(() {
                        _rememberDevice = value ?? false;
                      });
                    },
                    title: Text(l10n.get('rememberThisDevice')),
                    subtitle: Text(
                      l10n.get('rememberDeviceFor30Days'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: 24),

                  // Verify button
                  ElevatedButton(
                    onPressed: isLoading ? null : _onVerify,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        l10n.get('verify'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Toggle recovery mode
                  TextButton(
                    onPressed: _toggleRecoveryMode,
                    child: Text(
                      _isRecoveryMode
                          ? l10n.get('useAuthenticatorCode')
                          : l10n.get('useRecoveryCode'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTotpCodeInput(BuildContext context) {
    return PinCodeTextField(
      appContext: context,
      length: 6,
      controller: _codeController,
      keyboardType: TextInputType.number,
      animationType: AnimationType.fade,
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(8),
        fieldHeight: 56,
        fieldWidth: 48,
        activeFillColor: Colors.white,
        inactiveFillColor: Colors.grey.shade100,
        selectedFillColor: Colors.white,
        activeColor: AppColors.primary,
        inactiveColor: Colors.grey.shade300,
        selectedColor: AppColors.primary,
      ),
      enableActiveFill: true,
      onCompleted: (_) => _onVerify(),
      onChanged: (_) {},
    );
  }

  Widget _buildRecoveryCodeInput(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TextFormField(
      controller: _codeController,
      decoration: InputDecoration(
        labelText: l10n.get('recoveryCode'),
        prefixIcon: const Icon(Icons.vpn_key_outlined),
        hintText: 'XXXX-XXXX-XXXX',
      ),
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.characters,
      onFieldSubmitted: (_) => _onVerify(),
    );
  }
}
