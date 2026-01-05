import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/websocket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/notifications_bloc.dart';

/// Notification badge showing unread count.
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final bool showZero;

  const NotificationBadge({
    super.key,
    required this.child,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      builder: (context, state) {
        final count = state.unreadCount;

        if (count == 0 && !showZero) {
          return child;
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Connection status indicator.
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsBloc, NotificationsState>(
      buildWhen: (previous, current) =>
          previous.connectionState != current.connectionState,
      builder: (context, state) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getColorForState(state.connectionState),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Color _getColorForState(WebSocketState state) {
    switch (state) {
      case WebSocketState.connected:
        return AppColors.success;
      case WebSocketState.connecting:
      case WebSocketState.reconnecting:
        return AppColors.warning;
      case WebSocketState.disconnected:
        return AppColors.textSecondary;
    }
  }
}

/// Notification icon button with badge.
class NotificationIconButton extends StatelessWidget {
  final VoidCallback onPressed;

  const NotificationIconButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationBadge(
      child: IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: onPressed,
      ),
    );
  }
}
