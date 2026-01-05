import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants/api_constants.dart';

/// Event received from WebSocket.
class WebSocketEvent {
  final String event;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketEvent({
    required this.event,
    required this.data,
    required this.timestamp,
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      event: json['event'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }
}

/// WebSocket connection state.
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// WebSocket service for real-time updates.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final _stateController = StreamController<WebSocketState>.broadcast();
  final _eventController = StreamController<WebSocketEvent>.broadcast();

  WebSocketState _state = WebSocketState.disconnected;
  String? _accessToken;
  final Set<String> _subscribedRooms = {};
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const Duration _reconnectDelay = Duration(seconds: 3);

  /// Stream of connection state changes.
  Stream<WebSocketState> get stateStream => _stateController.stream;

  /// Stream of WebSocket events.
  Stream<WebSocketEvent> get eventStream => _eventController.stream;

  /// Current connection state.
  WebSocketState get state => _state;

  /// Whether currently connected.
  bool get isConnected => _state == WebSocketState.connected;

  /// Connect to WebSocket server.
  Future<void> connect(String accessToken) async {
    if (_state == WebSocketState.connected ||
        _state == WebSocketState.connecting) {
      return;
    }

    _accessToken = accessToken;
    _updateState(WebSocketState.connecting);

    try {
      // Connect without token in URL (security improvement)
      final wsUrl = Uri.parse(ApiConstants.wsBaseUrl);

      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Send authentication message after connection
      _send({'action': 'auth', 'token': accessToken});

      _updateState(WebSocketState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();

      // Resubscribe to rooms
      for (final room in _subscribedRooms) {
        _sendSubscribe(room);
      }

      if (kDebugMode) {
        debugPrint('[WebSocket] Connected');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebSocket] Connection error: $e');
      }
      _updateState(WebSocketState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Disconnect from WebSocket server.
  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _accessToken = null;
    _subscribedRooms.clear();
    _reconnectAttempts = 0;
    _updateState(WebSocketState.disconnected);
    if (kDebugMode) {
      debugPrint('[WebSocket] Disconnected');
    }
  }

  /// Subscribe to a room.
  void subscribe(String room) {
    _subscribedRooms.add(room);
    if (isConnected) {
      _sendSubscribe(room);
    }
  }

  /// Unsubscribe from a room.
  void unsubscribe(String room) {
    _subscribedRooms.remove(room);
    if (isConnected) {
      _send({'action': 'unsubscribe', 'room': room});
    }
  }

  /// Send a ping to keep connection alive.
  void ping() {
    if (isConnected) {
      _send({'action': 'ping'});
    }
  }

  void _sendSubscribe(String room) {
    _send({'action': 'subscribe', 'room': room});
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;

      // Handle different message types
      final type = data['type'] as String?;
      if (type == 'pong') {
        // Heartbeat response, ignore
        return;
      }
      if (type == 'subscribed') {
        if (kDebugMode) {
          debugPrint('[WebSocket] Subscribed to: ${data['room']}');
        }
        return;
      }
      if (type == 'error') {
        if (kDebugMode) {
          debugPrint('[WebSocket] Error: ${data['message']}');
        }
        return;
      }

      // Handle events
      if (data.containsKey('event')) {
        final event = WebSocketEvent.fromJson(data);
        _eventController.add(event);
        if (kDebugMode) {
          debugPrint('[WebSocket] Event: ${event.event}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WebSocket] Parse error: $e');
      }
    }
  }

  void _onError(dynamic error) {
    if (kDebugMode) {
      debugPrint('[WebSocket] Error: $error');
    }
    _updateState(WebSocketState.disconnected);
    _scheduleReconnect();
  }

  void _onDone() {
    if (kDebugMode) {
      debugPrint('[WebSocket] Connection closed');
    }
    _updateState(WebSocketState.disconnected);
    _scheduleReconnect();
  }

  void _updateState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      ping();
    });
  }

  void _scheduleReconnect() {
    if (_accessToken == null || _reconnectAttempts >= _maxReconnectAttempts) {
      return;
    }

    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _reconnectAttempts++;
    _updateState(WebSocketState.reconnecting);

    final delay = _reconnectDelay * _reconnectAttempts;
    if (kDebugMode) {
      debugPrint(
        '[WebSocket] Reconnecting in ${delay.inSeconds}s '
        '(attempt $_reconnectAttempts/$_maxReconnectAttempts)',
      );
    }

    _reconnectTimer = Timer(delay, () {
      if (_accessToken != null) {
        connect(_accessToken!);
      }
    });
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
    _stateController.close();
    _eventController.close();
  }
}
