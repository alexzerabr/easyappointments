import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/websocket_service.dart';

part 'notifications_event.dart';
part 'notifications_state.dart';

/// Bloc for managing notifications from WebSocket and Push Notifications.
class NotificationsBloc extends Bloc<NotificationsEvent, NotificationsState> {
  final WebSocketService _webSocketService;
  final PushNotificationService _pushNotificationService;

  StreamSubscription? _wsStateSubscription;
  StreamSubscription? _wsEventSubscription;
  StreamSubscription? _pushSubscription;

  final _uuid = const Uuid();
  static const int _maxNotifications = 50;

  NotificationsBloc({
    required WebSocketService webSocketService,
    required PushNotificationService pushNotificationService,
  })  : _webSocketService = webSocketService,
        _pushNotificationService = pushNotificationService,
        super(const NotificationsState()) {
    on<NotificationsInitialized>(_onInitialized);
    on<NotificationsDisconnected>(_onDisconnected);
    on<NotificationsWebSocketEventReceived>(_onWebSocketEvent);
    on<NotificationsPushReceived>(_onPushReceived);
    on<NotificationsConnectionStateChanged>(_onConnectionStateChanged);
    on<NotificationsMarkedAsRead>(_onMarkedAsRead);
    on<NotificationsCleared>(_onCleared);
  }

  Future<void> _onInitialized(
    NotificationsInitialized event,
    Emitter<NotificationsState> emit,
  ) async {
    // Listen to WebSocket state changes
    _wsStateSubscription = _webSocketService.stateStream.listen((wsState) {
      add(NotificationsConnectionStateChanged(wsState));
    });

    // Listen to WebSocket events
    _wsEventSubscription = _webSocketService.eventStream.listen((wsEvent) {
      add(NotificationsWebSocketEventReceived(wsEvent));
    });

    // Listen to Push notifications
    _pushSubscription =
        _pushNotificationService.notificationStream.listen((payload) {
      add(NotificationsPushReceived(payload));
    });

    // Connect WebSocket
    await _webSocketService.connect(event.accessToken);

    // Subscribe to relevant rooms based on role
    _subscribeToRooms(event.userId, event.userRole);

    // Subscribe to FCM topics
    await _subscribeToTopics(event.userId, event.userRole);
  }

  void _subscribeToRooms(int userId, String role) {
    // Subscribe based on role
    switch (role.toLowerCase()) {
      case 'admin':
        _webSocketService.subscribe('admin');
        _webSocketService.subscribe('calendar');
        break;
      case 'provider':
        _webSocketService.subscribe('provider_$userId');
        _webSocketService.subscribe('calendar');
        break;
      case 'secretary':
        _webSocketService.subscribe('calendar');
        break;
      case 'customer':
        _webSocketService.subscribe('customer_$userId');
        break;
    }
  }

  Future<void> _subscribeToTopics(int userId, String role) async {
    // Subscribe to FCM topics
    await _pushNotificationService.subscribeToTopic('general');

    switch (role.toLowerCase()) {
      case 'admin':
        await _pushNotificationService.subscribeToTopic('admin');
        break;
      case 'provider':
        await _pushNotificationService.subscribeToTopic('providers');
        await _pushNotificationService.subscribeToTopic('provider_$userId');
        break;
      case 'secretary':
        await _pushNotificationService.subscribeToTopic('staff');
        break;
      case 'customer':
        await _pushNotificationService.subscribeToTopic('customer_$userId');
        break;
    }
  }

  Future<void> _onDisconnected(
    NotificationsDisconnected event,
    Emitter<NotificationsState> emit,
  ) async {
    _webSocketService.disconnect();
    await _pushNotificationService.deleteToken();

    emit(const NotificationsState());
  }

  void _onWebSocketEvent(
    NotificationsWebSocketEventReceived event,
    Emitter<NotificationsState> emit,
  ) {
    final notification = _createNotificationFromWebSocket(event.event);
    _addNotification(notification, emit);
  }

  void _onPushReceived(
    NotificationsPushReceived event,
    Emitter<NotificationsState> emit,
  ) {
    final notification = _createNotificationFromPush(event.payload);
    _addNotification(notification, emit);
  }

  void _onConnectionStateChanged(
    NotificationsConnectionStateChanged event,
    Emitter<NotificationsState> emit,
  ) {
    emit(state.copyWith(connectionState: event.state));
  }

  void _onMarkedAsRead(
    NotificationsMarkedAsRead event,
    Emitter<NotificationsState> emit,
  ) {
    final updatedNotifications = state.notifications.map((n) {
      if (n.id == event.notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

    emit(state.copyWith(
      notifications: updatedNotifications,
      unreadCount: unreadCount,
    ));
  }

  void _onCleared(
    NotificationsCleared event,
    Emitter<NotificationsState> emit,
  ) {
    emit(state.copyWith(
      notifications: [],
      unreadCount: 0,
      clearLatest: true,
    ));
  }

  void _addNotification(
    NotificationItem notification,
    Emitter<NotificationsState> emit,
  ) {
    final notifications = [notification, ...state.notifications];

    // Limit to max notifications
    if (notifications.length > _maxNotifications) {
      notifications.removeRange(_maxNotifications, notifications.length);
    }

    final unreadCount = notifications.where((n) => !n.isRead).length;

    emit(state.copyWith(
      notifications: notifications,
      unreadCount: unreadCount,
      latestNotification: notification,
    ));
  }

  NotificationItem _createNotificationFromWebSocket(WebSocketEvent event) {
    final title = _getTitleForEvent(event.event);
    final body = _getBodyForEvent(event.event, event.data);

    return NotificationItem(
      id: _uuid.v4(),
      type: event.event,
      title: title,
      body: body,
      data: event.data,
      timestamp: event.timestamp,
    );
  }

  NotificationItem _createNotificationFromPush(NotificationPayload payload) {
    return NotificationItem(
      id: _uuid.v4(),
      type: payload.type ?? 'push',
      title: payload.title ?? 'Notification',
      body: payload.body ?? '',
      data: payload.data,
      timestamp: DateTime.now(),
    );
  }

  String _getTitleForEvent(String eventType) {
    switch (eventType) {
      case 'appointment_created':
        return 'New Appointment';
      case 'appointment_updated':
        return 'Appointment Updated';
      case 'appointment_deleted':
        return 'Appointment Cancelled';
      case 'provider_status_changed':
        return 'Provider Status Changed';
      default:
        return 'Notification';
    }
  }

  String _getBodyForEvent(String eventType, Map<String, dynamic> data) {
    switch (eventType) {
      case 'appointment_created':
        final service = data['service_name'] ?? 'Service';
        final customer = data['customer_name'] ?? 'Customer';
        return '$customer booked $service';
      case 'appointment_updated':
        final service = data['service_name'] ?? 'Service';
        return '$service appointment was updated';
      case 'appointment_deleted':
        final service = data['service_name'] ?? 'Service';
        return '$service appointment was cancelled';
      case 'provider_status_changed':
        final provider = data['provider_name'] ?? 'Provider';
        final status = data['status'] ?? 'changed';
        return '$provider is now $status';
      default:
        return data['message']?.toString() ?? 'You have a new notification';
    }
  }

  @override
  Future<void> close() {
    _wsStateSubscription?.cancel();
    _wsEventSubscription?.cancel();
    _pushSubscription?.cancel();
    return super.close();
  }
}
