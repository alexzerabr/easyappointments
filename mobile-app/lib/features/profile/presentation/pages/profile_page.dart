import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/injection/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../bloc/profile_bloc.dart';

/// Profile page showing user information (read-only).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late ProfileBloc _profileBloc;

  @override
  void initState() {
    super.initState();
    _profileBloc = getIt<ProfileBloc>()..add(const ProfileLoadRequested());
  }

  @override
  void dispose() {
    _profileBloc.close();
    super.dispose();
  }

  Future<void> _navigateToEdit(BuildContext context) async {
    await context.push('/profile/edit');
    // Reload profile data after returning from edit
    if (mounted) {
      _profileBloc.add(const ProfileLoadRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _profileBloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profile),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l10n.get('editProfile'),
              onPressed: () => _navigateToEdit(context),
            ),
          ],
        ),
        body: BlocConsumer<ProfileBloc, ProfileState>(
          listener: (context, state) {
            if (state is ProfileError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is ProfileLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProfileError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ProfileBloc>().add(const ProfileLoadRequested());
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            }

            // Get user from ProfileLoaded state or AuthBloc
            final user = state is ProfileLoaded
                ? state.user
                : (context.read<AuthBloc>().state is AuthAuthenticated
                    ? (context.read<AuthBloc>().state as AuthAuthenticated).user
                    : null);

            if (user == null) {
              return Center(child: Text(l10n.get('noUserData')));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile header
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Personal information card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.get('personalInformation'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            icon: Icons.person,
                            label: l10n.firstName,
                            value: user.firstName,
                          ),
                          _InfoRow(
                            icon: Icons.person_outline,
                            label: l10n.lastName,
                            value: user.lastName,
                          ),
                          _InfoRow(
                            icon: Icons.email,
                            label: l10n.email,
                            value: user.email,
                          ),
                          if (user.username != null)
                            _InfoRow(
                              icon: Icons.account_circle,
                              label: l10n.username,
                              value: user.username!,
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Contact information card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.get('contactInformation'),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          if (user.phoneNumber != null)
                            _InfoRow(
                              icon: Icons.phone,
                              label: l10n.phone,
                              value: user.phoneNumber!,
                            ),
                          if (user.mobileNumber != null)
                            _InfoRow(
                              icon: Icons.phone_android,
                              label: l10n.get('mobile'),
                              value: user.mobileNumber!,
                            ),
                          if (user.address != null)
                            _InfoRow(
                              icon: Icons.home,
                              label: l10n.address,
                              value: user.address!,
                            ),
                          if (user.city != null)
                            _InfoRow(
                              icon: Icons.location_city,
                              label: l10n.city,
                              value: user.city!,
                            ),
                          if (user.state != null)
                            _InfoRow(
                              icon: Icons.map,
                              label: l10n.get('state'),
                              value: user.state!,
                            ),
                          if (user.zipCode != null)
                            _InfoRow(
                              icon: Icons.mail,
                              label: l10n.zipCode,
                              value: user.zipCode!,
                            ),
                          if (user.phoneNumber == null &&
                              user.mobileNumber == null &&
                              user.address == null &&
                              user.city == null &&
                              user.state == null &&
                              user.zipCode == null)
                            Text(
                              l10n.get('noContactInfo'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Preferences card
                  if (user.timezone != null || user.language != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.get('preferences'),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            if (user.timezone != null)
                              _InfoRow(
                                icon: Icons.schedule,
                                label: l10n.get('timezone'),
                                value: user.timezone!,
                              ),
                            if (user.language != null)
                              _InfoRow(
                                icon: Icons.language,
                                label: l10n.language,
                                value: user.language!,
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Notes card
                  if (user.notes != null && user.notes!.isNotEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.notes,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.notes!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Change password button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/profile/change-password'),
                      icon: const Icon(Icons.lock),
                      label: Text(l10n.get('changePassword')),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
