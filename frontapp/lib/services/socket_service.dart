import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'api_service.dart';

class SocketService {
  StompClient? _client;
  final _connectionStatusController = StreamController<bool>.broadcast();

  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  bool get isConnected => _client?.connected ?? false;
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  // Base URL Logic matching ApiService
  String get _socketUrl {
    // Reuse the logic from ApiService, but change http -> ws
    String httpUrl = ApiService.baseUrl;
    String wsUrl = httpUrl
        .replaceFirst('http', 'ws')
        .replaceFirst('/api', '/ws-stomp');
    return wsUrl;
  }

  String? _jwtToken;

  void connect(String jwtToken, {Function()? onConnect}) {
    // If already connected with the SAME token, skip.
    if (_client != null && _client!.connected) {
      if (_jwtToken == jwtToken) {
        if (kDebugMode) print('Already connected with same token');
        if (onConnect != null) onConnect();
        _connectionStatusController.add(true);
        return;
      } else {
        if (kDebugMode) print('Token changed. Reconnecting...');
        _client?.deactivate();
        // Fall through to re-connect
      }
    }

    _jwtToken = jwtToken; // Update token for new connection

    _client = StompClient(
      config: StompConfig(
        url: '$_socketUrl?token=$jwtToken',
        beforeConnect: () async {
          if (kDebugMode)
            print(
              'Attempting to connect to WebSocket URL: $_socketUrl?token=$jwtToken',
            );
        },
        onConnect: (StompFrame frame) {
          if (kDebugMode) print('STOMP Connected');
          _connectionStatusController.add(true);
          if (onConnect != null) onConnect();
        },
        onWebSocketError: (dynamic error) {
          if (kDebugMode) print('WebSocket Error: $error');
          _connectionStatusController.add(false);
        },
        onDisconnect: (frame) {
          if (kDebugMode) print('❌ [Socket] STOMP Disconnected');
          _connectionStatusController.add(false);
          // Do NOT clear _jwtToken here, as we might want to preserve it for reconnection or pending messages.
        },
        stompConnectHeaders: {'Authorization': 'Bearer $jwtToken'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $jwtToken'},
        // Heartbeat: 10000ms = 10s
        heartbeatOutgoing: const Duration(milliseconds: 10000),
        heartbeatIncoming: const Duration(milliseconds: 10000),
      ),
    );

    _client?.activate();
  }

  // Returns unsubscribe function
  dynamic subscribe(String destination, Function(dynamic) callback) {
    if (_client == null || !_client!.connected) {
      if (kDebugMode) print('Cannot subscribe, client not connected');
      return null;
    }

    return _client?.subscribe(
      destination: destination,
      callback: (StompFrame frame) {
        if (frame.body != null) {
          try {
            final data = json.decode(frame.body!);
            callback(data);
          } catch (e) {
            print('Error decoding JSON: $e');
          }
        }
      },
    );
  }

  void sendMessage(String destination, Map<String, dynamic> body) {
    if (_client == null || !_client!.connected) {
      if (kDebugMode)
        print('❌ [Socket] Cannot send message, client not connected');
      return;
    }

    final encodedBody = json.encode(body);
    if (kDebugMode) {
      print('✅ [Socket] Sending frame to: $destination');
      print('   Body: $encodedBody');
      print('   Has Auth Token: ${_jwtToken != null}');
    }

    _client?.send(
      destination: destination,
      body: encodedBody,
      headers:
          _jwtToken != null ? {'Authorization': 'Bearer $_jwtToken'} : null,
    );
  }

  void disconnect() {
    _client?.deactivate();
    _connectionStatusController.add(false);
    if (kDebugMode) print('STOMP Disconnected');
  }
}
