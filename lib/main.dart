import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

void main() {
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
