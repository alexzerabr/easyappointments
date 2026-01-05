part of 'notifications_bloc.dart';

/// Base class for notifications events.
abstract class NotificationsEvent extends Equatable {
  const NotificationsEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize notifications (WebSocket + FCM).
class NotificationsInitialized extends NotificationsEvent {
  final String accessToken;
  final int userId;
  final String userRole;

  const NotificationsInitialized({
    required this.accessToken,
    required this.userId,
    required this.userRole,
  });

  @override
  List<Object?> get props => [accessToken, userId, userRole];
}

/// Disconnect notifications.
class NotificationsDisconnected extends NotificationsEvent {
  const NotificationsDisconnected();
}

/// WebSocket event received.
class NotificationsWebSocketEventReceived extends NotificationsEvent {
  final WebSocketEvent event;

  const NotificationsWebSocketEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

/// Push notification received.
class NotificationsPushReceived extends NotificationsEvent {
  final NotificationPayload payload;

  const NotificationsPushReceived(this.payload);

  @override
  List<Object?> get props => [payload];
}

/// WebSocket connection state changed.
class NotificationsConnectionStateChanged extends NotificationsEvent {
  final WebSocketState state;

  const NotificationsConnectionStateChanged(this.state);

  @override
  List<Object?> get props => [state];
}

/// Mark notification as read.
class NotificationsMarkedAsRead extends NotificationsEvent {
  final String notificationId;

  const NotificationsMarkedAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

/// Clear all notifications.
class NotificationsCleared extends NotificationsEvent {
  const NotificationsCleared();
}
