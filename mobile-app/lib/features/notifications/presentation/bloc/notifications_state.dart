part of 'notifications_bloc.dart';

/// In-app notification item.
class NotificationItem extends Equatable {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    this.isRead = false,
  });

  NotificationItem copyWith({
    String? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  List<Object?> get props => [id, type, title, body, data, timestamp, isRead];
}

/// Base class for notifications states.
class NotificationsState extends Equatable {
  final WebSocketState connectionState;
  final List<NotificationItem> notifications;
  final int unreadCount;
  final NotificationItem? latestNotification;

  const NotificationsState({
    this.connectionState = WebSocketState.disconnected,
    this.notifications = const [],
    this.unreadCount = 0,
    this.latestNotification,
  });

  NotificationsState copyWith({
    WebSocketState? connectionState,
    List<NotificationItem>? notifications,
    int? unreadCount,
    NotificationItem? latestNotification,
    bool clearLatest = false,
  }) {
    return NotificationsState(
      connectionState: connectionState ?? this.connectionState,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      latestNotification:
          clearLatest ? null : (latestNotification ?? this.latestNotification),
    );
  }

  bool get isConnected => connectionState == WebSocketState.connected;

  @override
  List<Object?> get props =>
      [connectionState, notifications, unreadCount, latestNotification];
}
