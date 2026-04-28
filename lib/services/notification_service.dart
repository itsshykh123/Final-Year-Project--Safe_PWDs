import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Android notification channel ID
  static const String _channelId = "high_risk_alerts";
  static const String _channelName = "High Risk Alerts";

  static Future<void> init() async {
    // Android settings
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (payload) {
        // Optional: handle notification tap
      },
    );

    // Create Android notification channel
    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notifications for high-risk alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 1000, 500, 1000]),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  static Future<void> showHighRiskNotification({
    RemoteMessage? message,
    String? title,
    String? body,
  }) async {
    // 1. Determine the content (Prioritize manual strings, then FCM, then defaults)
    String displayTitle =
        title ?? message?.notification?.title ?? "⚠️ EMERGENCY";
    String displayBody =
        body ?? message?.notification?.body ?? "High Risk Alert Detected";

    // 2. Vibrate
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 1000, 500, 1000]);
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_risk_alerts',
          'High Risk Alerts',
          channelDescription: 'Used for emergency risk alerts',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          icon: '@mipmap/ic_launcher',
        );

    // 3. Show it
    await _notificationsPlugin.show(
      // Use message hash or a timestamp for manual alerts
      message?.hashCode ?? DateTime.now().millisecondsSinceEpoch % 100000,
      displayTitle,
      displayBody,
      const NotificationDetails(android: androidDetails),
    );
  }

  // For FCM messages
  static Future<void> showFCMNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      // Add 'message:' before the variable
      await showHighRiskNotification(message: message);
    }
  }
}
