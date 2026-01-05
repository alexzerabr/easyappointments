import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification payload.
class NotificationPayload {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String? type;

  NotificationPayload({
    this.title,
    this.body,
    required this.data,
    this.type,
  });

  factory NotificationPayload.fromRemoteMessage(RemoteMessage message) {
    return NotificationPayload(
      title: message.notification?.title,
      body: message.notification?.body,
      data: message.data,
      type: message.data['type'] as String?,
    );
  }
}

/// Background message handler (must be top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint('[FCM] Background message: ${message.messageId}');
  }
}

/// Push notification service using Firebase Cloud Messaging.
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final _tokenController = StreamController<String?>.broadcast();
  final _notificationController =
      StreamController<NotificationPayload>.broadcast();

  StreamSubscription? _foregroundSubscription;
  StreamSubscription? _openedAppSubscription;
  String? _fcmToken;

  /// Stream of FCM token changes.
  Stream<String?> get tokenStream => _tokenController.stream;

  /// Stream of notification payloads.
  Stream<NotificationPayload> get notificationStream =>
      _notificationController.stream;

  /// Current FCM token.
  String? get fcmToken => _fcmToken;

  /// Initialize push notifications.
  Future<void> initialize() async {
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _tokenController.add(token);
      if (kDebugMode) {
        debugPrint('[FCM] Token refreshed');
      }
    });

    // Handle foreground messages
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification opened app
    _openedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

    // Check if app was opened from notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpened(initialMessage);
    }

    if (kDebugMode) {
      debugPrint('[FCM] Initialized');
    }
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    }

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        debugPrint('[FCM] User granted permission');
      }
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      if (kDebugMode) {
        debugPrint('[FCM] User granted provisional permission');
      }
    } else {
      if (kDebugMode) {
        debugPrint('[FCM] User declined permission');
      }
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      _tokenController.add(_fcmToken);
      if (kDebugMode) {
        debugPrint('[FCM] Token: $_fcmToken');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error getting token: $e');
      }
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] Foreground message: ${message.messageId}');
    }

    final payload = NotificationPayload.fromRemoteMessage(message);
    _notificationController.add(payload);

    // Show local notification
    _showLocalNotification(message);
  }

  void _handleNotificationOpened(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('[FCM] Notification opened: ${message.messageId}');
    }

    final payload = NotificationPayload.fromRemoteMessage(message);
    _notificationController.add(payload);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('[LocalNotification] Tapped: ${response.payload}');
    }

    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final payload = NotificationPayload(
          data: data,
          type: data['type'] as String?,
        );
        _notificationController.add(payload);
      } catch (e) {
        debugPrint('[LocalNotification] Error parsing payload: $e');
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Subscribe to a topic.
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        debugPrint('[FCM] Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error subscribing to topic: $e');
      }
    }
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        debugPrint('[FCM] Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error unsubscribing from topic: $e');
      }
    }
  }

  /// Delete FCM token (for logout).
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      _tokenController.add(null);
      if (kDebugMode) {
        debugPrint('[FCM] Token deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] Error deleting token: $e');
      }
    }
  }

  /// Dispose resources.
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();
    _tokenController.close();
    _notificationController.close();
  }
}
