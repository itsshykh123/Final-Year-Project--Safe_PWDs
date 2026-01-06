import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:safe_pwd/services/fcm_service.dart';
import 'services/notification_service.dart';
import 'routes/app_routes.dart';

// FCM Background Handler
@pragma('vm:entry-point') // required for background execution
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  NotificationService.showFCMNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await NotificationService.init();
  await FCMService.initFCM(); // <-- Added this

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    NotificationService.showFCMNotification(message);
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe-PWD',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.authChoice,
      routes: AppRoutes.routes,
    );
  }
}
