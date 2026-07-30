import 'dart:convert';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/app_navigator.dart';
import '../config/network_url.dart';
import '../screens/admin/bills/bill_deep_link_screen.dart';
import '../screens/admin/notifications/notifications_screen.dart';
import '../screens/admin/notifications/password_reset_requests_screen.dart';
import 'api_service.dart';
import 'notification_api_service.dart';

/// Must be a top-level (or static) function - firebase_messaging calls this
/// in a separate background isolate when a push arrives while the app is
/// backgrounded or fully closed. We don't need to do anything here: the OS
/// already renders the notification tray entry from the payload's
/// "notification" block, and tapping it is handled by onMessageOpenedApp /
/// getInitialMessage once the app (re)opens.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Wraps Firebase Cloud Messaging + flutter_local_notifications +
/// app_badge_plus into one place: permission request, token
/// registration/refresh, foreground display, and tap → deep-link
/// navigation for both Android and iOS.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'aj_default_channel',
    'General notifications',
    description: 'Password reset requests and new bill alerts for Admins',
    importance: Importance.high,
  );

  /// Call once, early in main() after Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) {
          _handleData(Map<String, dynamic>.from(jsonDecode(payload)));
        }
      },
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    // App was backgrounded, user tapped the system notification.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleData(m.data));

    // App was fully closed, opened by tapping the system notification.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleData(initialMessage.data));
    }

    // App was open (foreground) - FCM won't show a tray notification by
    // itself in that case, so show one via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (ApiService.token != null) _registerToken(token);
    });
  }

  /// Call right after login (and once at app start if a session was
  /// restored) to link this device's FCM token with the signed-in account.
  Future<void> registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      debugPrint('FCM: token registration failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiService.post(NetworkUrl.fcmToken, body: {
        'token': token,
        'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('FCM: token registration request failed: $e');
    }
  }

  /// Call around logout so this device stops receiving pushes for the
  /// account being signed out of, and clears the app-icon badge.
  Future<void> unregisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService.delete(NetworkUrl.fcmToken, body: {'token': token});
      }
    } catch (e) {
      debugPrint('FCM: token unregistration failed: $e');
    }
    await _setBadgeSafely(0);
  }

  /// Wraps AppBadgePlus.updateBadge() in a try/await so a platform error
  /// (or an unsupported launcher) never crashes the caller.
  Future<void> _setBadgeSafely(int count) async {
    try {
      await AppBadgePlus.updateBadge(count);
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    final badge = int.tryParse('${message.data['badge'] ?? ''}');
    if (badge != null) _setBadgeSafely(badge);

    final notification = message.notification;
    if (notification != null) {
      _local.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  /// Re-syncs the app-icon badge with the server's unread count. Call after
  /// login, on app resume, and after marking notifications read. Silently
  /// no-ops for non-admin users (the endpoint is Admin-only server-side).
  Future<void> refreshBadge() async {
    try {
      final count = await NotificationApiService.unreadCount();
      await _setBadgeSafely(count);
    } catch (_) {
      // not an admin, or offline - nothing to show.
    }
  }

  void _handleData(Map<String, dynamic> data) {
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    switch (data['screen']) {
      case 'password_reset_requests':
        navState.push(MaterialPageRoute(builder: (_) => const PasswordResetRequestsScreen()));
        break;
      case 'bill_detail':
        final billId = int.tryParse('${data['bill_id']}');
        if (billId != null) {
          navState.push(MaterialPageRoute(builder: (_) => BillDeepLinkScreen(billId: billId)));
        } else {
          navState.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        }
        break;
      default:
        navState.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    }

    refreshBadge();
  }
}
