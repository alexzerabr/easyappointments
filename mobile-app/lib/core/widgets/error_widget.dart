import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';

/// Error display widget.
class AppErrorWidget extends StatelessWidget {
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.details,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  /// Factory for network error - requires BuildContext for localization
  static Widget network(BuildContext context, {VoidCallback? onRetry}) {
    final l10n = AppLocalizations.of(context);
    return AppErrorWidget(
      message: l10n.networkError,
      details: l10n.get('checkConnectionAndRetry'),
      icon: Icons.wifi_off,
      onRetry: onRetry,
    );
  }

  /// Factory for server error - requires BuildContext for localization
  static Widget server(BuildContext context, {VoidCallback? onRetry}) {
    final l10n = AppLocalizations.of(context);
    return AppErrorWidget(
      message: l10n.serverError,
      details: l10n.get('somethingWentWrong'),
      icon: Icons.cloud_off,
      onRetry: onRetry,
    );
  }

  /// Factory for not found error
  static Widget notFound(BuildContext context, {String? resource}) {
    final l10n = AppLocalizations.of(context);
    return AppErrorWidget(
      message: resource != null ? '$resource ${l10n.get('notFound')}' : l10n.get('notFound'),
      icon: Icons.search_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              Text(
                details!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.tryAgain),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
