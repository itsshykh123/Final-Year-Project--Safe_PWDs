import 'package:flutter/material.dart';
import 'package:safe_pwd/admin/dashboard.dart';
import '../auth/login_page.dart';
import '../auth/register_page.dart';
import '../auth/welcome_page.dart';
import '../dashboard/home_page.dart';

class AppRoutes {
  static const authChoice = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const adminDashboard = '/admin/dashboard';

  static Map<String, WidgetBuilder> routes = {
    authChoice: (_) => const WelcomeScreen(),
    login: (_) => const LoginPage(),
    register: (_) => const RegisterPage(),
    home: (_) => const HomePage(),
    adminDashboard: (_) => const AdminDashboard(),
  };
}
