import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:safe_pwd/admin/dashboard.dart';
import 'package:safe_pwd/auth/login_page.dart';
import 'package:safe_pwd/dashboard/home_page.dart';
import 'package:safe_pwd/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'routes/app_routes.dart';

// This MUST be a top-level function (outside any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.init();

  // Read from data instead of notification
  NotificationService.showHighRiskNotification(
    title: message.data['title'],
    body: message.data['body'],
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.init();
  await FCMService.initFCM();

  final prefs = await SharedPreferences.getInstance();
  final String? userEmail = prefs.getString('userEmail');

  // Logic to check for initial message
  RemoteMessage? initialMessage = await FirebaseMessaging.instance
      .getInitialMessage();

  // Explicitly convert to a bool so it is never null
  bool startWithAlert = initialMessage != null;

  String initialRoute = (userEmail != null && userEmail.isNotEmpty)
      ? AppRoutes.home
      : AppRoutes.login;

  runApp(
    MyApp(
      initialRoute: initialRoute,
      startWithAlert: startWithAlert, // Pass the explicit bool
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  final bool startWithAlert; // New field

  const MyApp({
    super.key,
    required this.initialRoute,
    this.startWithAlert = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Safe PWD',
      initialRoute: initialRoute,
      // Use onGenerateRoute to pass arguments to the HomePage
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.home) {
          return MaterialPageRoute(
            builder: (context) => HomePage(startWithAlert: startWithAlert),
          );
        }
        // Define other routes normally
        if (settings.name == AppRoutes.login) {
          return MaterialPageRoute(builder: (context) => const LoginPage());
        }
        if (settings.name == AppRoutes.adminDashboard) {
          return MaterialPageRoute(
            builder: (context) => const AdminDashboard(),
          );
        }
        return null;
      },
    );
  }
}
