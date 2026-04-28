import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initFCM() async {
    // Request permissions for Android 13+ and iOS
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Subscribe to a topic. All users will receive alerts sent to this topic.
    await FirebaseMessaging.instance.subscribeToTopic("disaster_alerts");

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationService.showHighRiskNotification(
        title: message.data['title'],
        body: message.data['body'],
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NotificationService.showHighRiskNotification(
        title: message.data['title'],
        body: message.data['body'],
      );
    });
  }
}
