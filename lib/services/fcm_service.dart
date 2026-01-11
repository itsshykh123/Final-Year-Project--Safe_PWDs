import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initFCM() async {
    // Request permissions (iOS)
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Get FCM token
    // String? token = await _messaging.getToken();

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationService.showFCMNotification(message);
    });

    // App opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Optional: navigate to specific screen
    });
  }
}
