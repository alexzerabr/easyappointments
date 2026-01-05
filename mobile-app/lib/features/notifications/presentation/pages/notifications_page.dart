import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../bloc/notifications_bloc.dart';

/// Notifications page showing all notifications.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          BlocBuilder<NotificationsBloc, NotificationsState>(
            builder: (context, state) {
              if (state.notifications.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  _showClearDialog(context);
                },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationsBloc, NotificationsState>(
        builder: (context, state) {
          if (state.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('noNotifications'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.get('noNotificationsDescription'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: state.notifications.length,
            itemBuilder: (context, index) {
              final notification = state.notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearAll),
        content: Text(l10n.confirmClearNotifications),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<NotificationsBloc>().add(const NotificationsCleared());
            },
            child: Text(
              l10n.get('clear'),
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        context.read<NotificationsBloc>().add(
              NotificationsMarkedAsRead(notification.id),
            );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getColorForType(notification.type).withValues(alpha: 0.1),
          child: Icon(
            _getIconForType(notification.type),
            color: _getColorForType(notification.type),
          ),
        ),
        title: Text(
          _getLocalizedTitle(context, notification),
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getLocalizedBody(context, notification)),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(context, notification.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
        isThreeLine: true,
        onTap: () {
          context.read<NotificationsBloc>().add(
                NotificationsMarkedAsRead(notification.id),
              );
          _handleNotificationTap(context, notification);
        },
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'appointment_created':
        return AppColors.success;
      case 'appointment_updated':
        return AppColors.info;
      case 'appointment_deleted':
        return AppColors.error;
      case 'provider_status_changed':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'appointment_created':
        return Icons.event_available;
      case 'appointment_updated':
        return Icons.event_note;
      case 'appointment_deleted':
        return Icons.event_busy;
      case 'provider_status_changed':
        return Icons.person;
      default:
        return Icons.notifications;
    }
  }

  String _getLocalizedTitle(BuildContext context, NotificationItem notification) {
    final l10n = AppLocalizations.of(context);
    switch (notification.type) {
      case 'appointment_created':
        return l10n.get('newAppointmentNotification');
      case 'appointment_updated':
        return l10n.get('appointmentUpdatedNotification');
      case 'appointment_deleted':
        return l10n.get('appointmentCancelledNotification');
      case 'provider_status_changed':
        return l10n.get('providerStatusChangedNotification');
      default:
        return l10n.get('notificationDefault');
    }
  }

  String _getLocalizedBody(BuildContext context, NotificationItem notification) {
    final l10n = AppLocalizations.of(context);
    final data = notification.data;

    switch (notification.type) {
      case 'appointment_created':
        final service = data['service_name'] ?? l10n.service;
        final customer = data['customer_name'] ?? l10n.customer;
        return '$customer ${l10n.get('customerBookedService')} $service';
      case 'appointment_updated':
        final service = data['service_name'] ?? l10n.service;
        return '$service ${l10n.get('appointmentWasUpdated')}';
      case 'appointment_deleted':
        final service = data['service_name'] ?? l10n.service;
        return '$service ${l10n.get('appointmentWasCancelled')}';
      case 'provider_status_changed':
        final provider = data['provider_name'] ?? l10n.provider;
        final status = data['status'] ?? '';
        return '$provider ${l10n.get('isNow')} $status';
      default:
        return data['message']?.toString() ?? l10n.get('youHaveNewNotification');
    }
  }

  String _formatTimestamp(BuildContext context, DateTime timestamp) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return l10n.get('justNow');
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}${l10n.get('minutesAgo')}';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}${l10n.get('hoursAgo')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}${l10n.get('daysAgo')}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _handleNotificationTap(BuildContext context, NotificationItem notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case 'appointment_created':
      case 'appointment_updated':
        final appointmentId = notification.data['id'];
        if (appointmentId != null) {
          // Navigate to appointment detail
          // context.push('/appointments/$appointmentId');
        }
        break;
      default:
        // No specific action
        break;
    }
  }
}
