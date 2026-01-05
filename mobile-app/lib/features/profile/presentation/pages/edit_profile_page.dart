import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/profile_update_request.dart';
import '../bloc/profile_bloc.dart';

/// Edit profile page with editable form.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _zipCodeController;
  late TextEditingController _notesController;

  Map<String, String?> _fieldErrors = {};
  User? _currentUser;

  @override
  void initState() {
    super.initState();

    // Get current user from AuthBloc
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _currentUser = authState.user;
    }

    // Initialize controllers with current user data
    _firstNameController = TextEditingController(text: _currentUser?.firstName ?? '');
    _lastNameController = TextEditingController(text: _currentUser?.lastName ?? '');
    _emailController = TextEditingController(text: _currentUser?.email ?? '');
    _usernameController = TextEditingController(text: _currentUser?.username ?? '');
    _phoneNumberController = TextEditingController(text: _currentUser?.phoneNumber ?? '');
    _mobileNumberController = TextEditingController(text: _currentUser?.mobileNumber ?? '');
    _addressController = TextEditingController(text: _currentUser?.address ?? '');
    _cityController = TextEditingController(text: _currentUser?.city ?? '');
    _stateController = TextEditingController(text: _currentUser?.state ?? '');
    _zipCodeController = TextEditingController(text: _currentUser?.zipCode ?? '');
    _notesController = TextEditingController(text: _currentUser?.notes ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneNumberController.dispose();
    _mobileNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveProfile(BuildContext context) {
    setState(() => _fieldErrors = {});


    if (!_formKey.currentState!.validate()) {
      return;
    }

    final request = ProfileUpdateRequest(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
      timezone: _currentUser?.timezone,
      language: _currentUser?.language,
      phoneNumber: _phoneNumberController.text.trim().isEmpty
          ? null
          : _phoneNumberController.text.trim(),
      mobileNumber: _mobileNumberController.text.trim().isEmpty
          ? null
          : _mobileNumberController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      state: _stateController.text.trim().isEmpty
          ? null
          : _stateController.text.trim(),
      zipCode: _zipCodeController.text.trim().isEmpty
          ? null
          : _zipCodeController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    context.read<ProfileBloc>().add(ProfileUpdateRequested(request));
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
          title: Text(l10n.get('editProfile')),
        ),
        body: BlocConsumer<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfileUpdated) {
              // Update AuthBloc with new user data
              context.read<AuthBloc>().add(AuthUserUpdated(state.user));

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.get('profileUpdatedSuccessfully')),
                  backgroundColor: Colors.green,
                ),
              );

              // Navigate back to profile page
              context.pop();
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
                        // Personal Information Section
                        Text(
                          l10n.get('personalInformation'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(
                            labelText: '${l10n.firstName} *',
                            errorText: _getFieldError('firstName'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.get('fieldRequired');
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(
                            labelText: '${l10n.lastName} *',
                            errorText: _getFieldError('lastName'),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.get('fieldRequired');
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: '${l10n.email} *',
                            errorText: _getFieldError('email'),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.get('fieldRequired');
                            }
                            if (!value.contains('@')) {
                              return l10n.get('invalidEmail');
                            }
                            return null;
                          },
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: l10n.username,
                            errorText: _getFieldError('username'),
                            border: const OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 24),

                        // Contact Information Section
                        Text(
                          l10n.get('contactInformation'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _phoneNumberController,
                          decoration: InputDecoration(
                            labelText: l10n.phone,
                            errorText: _getFieldError('phone_number'),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _mobileNumberController,
                          decoration: InputDecoration(
                            labelText: l10n.get('mobile'),
                            errorText: _getFieldError('mobile_number'),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: l10n.address,
                            errorText: _getFieldError('address'),
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            labelText: l10n.city,
                            errorText: _getFieldError('city'),
                            border: const OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _stateController,
                          decoration: InputDecoration(
                            labelText: l10n.get('state'),
                            errorText: _getFieldError('state'),
                            border: const OutlineInputBorder(),
                          ),
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _zipCodeController,
                          decoration: InputDecoration(
                            labelText: l10n.zipCode,
                            errorText: _getFieldError('zip_code'),
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.text,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 24),

                        // Notes Section
                        Text(
                          l10n.notes,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: l10n.notes,
                            errorText: _getFieldError('notes'),
                            border: const OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          enabled: !isLoading,
                        ),
                        const SizedBox(height: 24),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () => _saveProfile(context),
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
                                    l10n.save,
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
