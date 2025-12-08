import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('User granted permission');
        }
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        if (kDebugMode) {
          print('User granted provisional permission');
        }
      } else {
        if (kDebugMode) {
          print('User declined or has not accepted permission');
        }
      }
    } catch (e) {
      // 이미 요청 중인 경우 무시
      if (kDebugMode) {
        print('Permission request warning: $e');
      }
    }

    // Get Token
    try {
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('\n\n🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥');
        print('FCM Token: $token');
        print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥\n\n');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
    }

    // Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('\n📩 Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
          print('Title: ${message.notification?.title}');
          print('Body: ${message.notification?.body}');
        }
        print('--------------------------------------------------\n');
      }
    });
  }
}
