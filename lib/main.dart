import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
