import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/password_change_request.dart';
import '../bloc/profile_bloc.dart';

/// Change password page.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  Map<String, String?> _fieldErrors = {};

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _changePassword(BuildContext context) {
    setState(() => _fieldErrors = {});

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final request = PasswordChangeRequest(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    context.read<ProfileBloc>().add(ProfilePasswordChangeRequested(request));
  }

  String? _getFieldError(String fieldName) {
    return _fieldErrors[fieldName];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider(
      create: (context) => getIt<ProfileBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.get('changePassword')),
        ),
        body: BlocConsumer<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfilePasswordChanged) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.get('passwordChangedSuccessfully')),
                  backgroundColor: Colors.green,
                ),
              );

              // Logout user to force re-authentication with new password
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            } else if (state is ProfileError) {
              setState(() {
                _fieldErrors = state.fieldErrors?.map((key, value) =>
                  MapEntry(key, value.join(', '))
                ) ?? {};
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.get(state.message)),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is ProfileLoading;

            return Stack(
              children: [
                Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Information card
                        Card(
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.get('passwordRequirements'),
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Current password field
                        TextFormField(
                          controller: _currentPasswordController,
                          decoration: InputDecoration(
                            labelText: '${l10n.get('currentPassword')} *',
                            errorText: _getFieldError('current_password'),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrentPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureCurrentPassword = !_obscureCurrentPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureCurrentPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.get('fieldRequired');
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        // New password field
                        TextFormField(
                          controller: _newPasswordController,
                          decoration: InputDecoration(
                            labelText: '${l10n.get('newPassword')} *',
                            errorText: _getFieldError('new_password'),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureNewPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.get('fieldRequired');
                            }
                            if (value.length < 7) {
                              return l10n.get('passwordTooShort');
                            }
                            if (value == _currentPasswordController.text) {
                              return l10n.get('newPasswordSameAsCurrent');
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        // Confirm password field
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: '${l10n.get('confirmNewPassword')} *',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureConfirmPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.get('fieldRequired');
                            }
                            if (value != _newPasswordController.text) {
                              return l10n.get('passwordsDoNotMatch');
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 24),

                        // Change password button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => _changePassword(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    l10n.get('changePassword'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                if (isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
