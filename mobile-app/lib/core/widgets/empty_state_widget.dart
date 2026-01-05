import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Empty state display widget.
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  /// Factory for no appointments state - requires BuildContext for localization
  static Widget noAppointments(BuildContext context, {VoidCallback? onAction}) {
    final l10n = AppLocalizations.of(context);
    return EmptyStateWidget(
      title: l10n.noAppointments,
      subtitle: l10n.noAppointmentsDescription,
      icon: Icons.event_busy,
      actionLabel: l10n.bookNow,
      onAction: onAction,
    );
  }

  /// Factory for no results state - requires BuildContext for localization
  static Widget noResults(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyStateWidget(
      title: l10n.noResultsFound,
      subtitle: l10n.noResultsDescription,
      icon: Icons.search_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
