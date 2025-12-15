import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Added
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final StreamController<void> _messageStreamController =
      StreamController<void>.broadcast();
  Stream<void> get onMessageReceived => _messageStreamController.stream;

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Android Channel
  // Android Channel
  final AndroidNotificationChannel _androidChannel =
      const AndroidNotificationChannel(
        'feelscore_notification_channel_v1', // id
        'High Importance Notifications', // title
        description:
            'This channel is used for important notifications.', // description
        importance: Importance.high,
      );

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Initialize Local Notifications Plugin
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Web Initialization (if needed in future, minimal requirement is just settings)
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // 2. Create Android Notification Channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // 3. Request Permission (FCM)
    try {
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Permission request warning: $e');
      }
    }

    // 4. Get FCM Token
    try {
      String? token;
      if (kIsWeb) {
        // TODO: [Important] Replace this with your VAPID Key from Firebase Console -> Project Settings -> Cloud Messaging -> Web Push Certificates
        // If this is empty, Web Notifications will properly NOT work.
        const String vapidKey =
            "BKiEWLDn4aseX9PiCXdq2U_OIcXhKoAg1qHDXJW_DlVorVuYWAnhM4vPBJcjdBvU2HqqVFJ3orWTJYhKRWay5GE";
        if (vapidKey.contains("YOUR_VAPID_KEY")) {
          print(
            '⚠️ [FCMService] VAPID Key is missing! Web notifications will check fail.',
          );
        }
        token = await _firebaseMessaging.getToken(vapidKey: vapidKey);
      } else {
        token = await _firebaseMessaging.getToken();
      }

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

    // 5. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      Map<String, dynamic> data = message.data;

      if (kDebugMode) {
        print('\n📩 Got a message whilst in the foreground!');
        print('Message ID: ${message.messageId}');
        print('Sent Time: ${message.sentTime}');
        print(
          'Notification: ${message.notification?.title} / ${message.notification?.body}',
        );
        print('Data Payload: ${message.data}');
      }

      // Notify listeners (e.g. InboxPage) to refresh regardless of notification suppression
      _messageStreamController.add(null);

      // 🔥 Check if user is currently in this chat room
      String? msgThreadId = data['threadId']?.toString();
      if (msgThreadId != null && msgThreadId == currentActiveThreadId) {
        // Double check lifecycle: If app is paused/inactive, we SHOULD show notification
        // because the user isn't actually looking at the chat.
        final lifecycle = WidgetsBinding.instance.lifecycleState;
        if (lifecycle == AppLifecycleState.paused ||
            lifecycle == AppLifecycleState.inactive) {
          if (kDebugMode) {
            print(
              'User active in thread $msgThreadId but app state is $lifecycle. Force SHOWING notification.',
            );
          }
          // Proceed to show notification (fall through)
        } else {
          if (kDebugMode) {
            print(
              'User is currently in thread $msgThreadId (State: $lifecycle). Suppressing notification.',
            );
          }
          return; // Suppress notification
        }
      }

      // 🔥 Check if message is from self
      // Note: Verify 'senderId' key matches your backend payload.
      String? senderId = data['senderId']?.toString();
      if (senderId != null && senderId == currentUserId) {
        if (kDebugMode) {
          print('Suppressing notification from self ($senderId)');
        }
        return;
      }

      // If `onMessage` is triggered with a notification object, display a local notification.
      if (notification != null && !kIsWeb) {
        _showLocalNotification(
          notification.title ?? '',
          notification.body ?? '',
        );
      } else if (kIsWeb && notification != null) {
        if (kDebugMode) {
          print(
            'Web Notification: ${notification.title} - ${notification.body}',
          );
        }
        // Show In-App SnackBar for Web
        _showWebSnackBar(notification.title ?? '알림', notification.body ?? '');

        // Also attempt local notification (optional)
        try {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(),
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error showing Web notification: $e');
          }
        }
      }
    });
  }

  // Active Thread Management
  String? currentUserId;
  String? currentActiveThreadId;
  GlobalKey<NavigatorState>? _navigatorKey;
  OverlayEntry? _overlayEntry;
  final ValueNotifier<List<_NotificationItem>> _notificationsNotifier =
      ValueNotifier([]);

  void setCurrentUserId(String? userId) {
    currentUserId = userId;
    if (kDebugMode) {
      print('FCMService: Current User ID set to $userId');
    }
  }

  void setCurrentThreadId(String? threadId) {
    currentActiveThreadId = threadId;
    if (kDebugMode) {
      print('FCMService: Current Active Thread ID set to $threadId');
    }
  }

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
    if (kDebugMode) {
      print('FCMService: Navigator Key set');
    }
  }

  void _showWebSnackBar(String title, String body) {
    // Legacy SnackBar support if needed, but we use Overlay now per user request
    _showOverlayNotification(title, body);
  }

  void _showOverlayNotification(String title, String body) {
    if (kDebugMode) {
      print('FCMService: _showOverlayNotification called');
      print('FCMService: NavigatorKey is $_navigatorKey');
      print(
        'FCMService: NavigatorKey.currentState is ${_navigatorKey?.currentState}',
      );
    }

    // [Step 1] Always show System Notification (Status Bar) for reliability
    _showLocalNotification(title, body);

    if (_navigatorKey?.currentState == null) {
      if (kDebugMode) {
        print('FCMService: Navigator State is NULL. Aborting overlay.');
      }
      return;
    }

    final item = _NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
    );

    // Add to list
    final List<_NotificationItem> currentList = List.from(
      _notificationsNotifier.value,
    );
    currentList.add(item);
    _notificationsNotifier.value = currentList;

    // Ensure Overlay is active
    if (_overlayEntry == null) {
      try {
        _overlayEntry = OverlayEntry(
          builder:
              (context) =>
                  _CreateNotificationStack(notifier: _notificationsNotifier),
        );
        _navigatorKey!.currentState!.overlay!.insert(_overlayEntry!);
        if (kDebugMode) print('FCMService: Overlay inserted successfully');
      } catch (e) {
        if (kDebugMode) print('FCMService: Error inserting overlay: $e');
        // Fallback or cleanup
        _overlayEntry = null;
        return;
      }
    }

    // Auto-remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      final List<_NotificationItem> updatedList = List.from(
        _notificationsNotifier.value,
      );
      updatedList.removeWhere((element) => element.id == item.id);
      _notificationsNotifier.value = updatedList;

      // If list is empty, we could remove overlay, but keeping it is fine
    });
  }

  Future<void> _showLocalNotification(String title, String body) async {
    try {
      final AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          );

      final NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: const DarwinNotificationDetails(),
      );

      // Use a safe 32-bit integer for the ID to prevent collision/overflow
      final int notificationId =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 % 2147483647;

      await _localNotifications.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error showing local notification: $e');
      }
    }
  }
}

class _NotificationItem {
  final String id;
  final String title;
  final String body;

  _NotificationItem({
    required this.id,
    required this.title,
    required this.body,
  });
}

class _CreateNotificationStack extends StatelessWidget {
  final ValueNotifier<List<_NotificationItem>> notifier;

  const _CreateNotificationStack({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 50, // Moved to TOP (safe area approx)
      left: 16,
      right: 16, // Full width with padding
      child: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<List<_NotificationItem>>(
          valueListenable: notifier,
          builder: (context, notifications, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Stretch full width
              children:
                  notifications.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(
                        bottom: 10,
                      ), // Margin bottom for stack
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.notifications,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.body,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ),
    );
  }
} // End of file logic from previous replace calls
