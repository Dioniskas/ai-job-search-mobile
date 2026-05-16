import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'api_service.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs
}

class FcmService {
  FcmService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static GoRouter? _router;

  static const _androidChannel = AndroidNotificationChannel(
    'ai_job_search_channel',
    'Уведомления',
    description: 'Уведомления приложения AI Job Search',
    importance: Importance.high,
  );

  static void setRouter(GoRouter router) => _router = router;

  static Future<void> init(String authToken) async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }

    // Init local notifications (for foreground display)
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _navigate(details.payload);
      },
    );

    // Get token and send to server
    final token = await _messaging.getToken();
    if (token != null) {
      await ApiService.saveFcmToken(authToken, token);
    }

    // Refresh token
    _messaging.onTokenRefresh.listen((newToken) {
      ApiService.saveFcmToken(authToken, newToken);
    });

    // Foreground: show local notification
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // App opened from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _navigate(_routeFromData(message.data));
    });

    // App opened from terminated state via notification tap
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _navigate(_routeFromData(initial.data));
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _routeFromData(message.data),
    );
  }

  static String? _routeFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'NEW_APPLICATION':
        return '/employer/applications';
      case 'APPLICATION_STATUS':
        return '/seeker/applications';
      case 'NEW_MESSAGE':
        final appId = data['applicationId'] as String?;
        return appId != null ? '/chat/$appId' : null;
      default:
        return null;
    }
  }

  static void _navigate(String? route) {
    if (route == null || _router == null) return;
    Future.delayed(Duration.zero, () => _router!.go(route));
  }

  static Future<void> deleteToken(String authToken) async {
    await _messaging.deleteToken();
    await ApiService.deleteFcmToken(authToken);
  }
}
