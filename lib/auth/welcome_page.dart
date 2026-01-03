import 'package:flutter/material.dart';
import 'package:safe_pwd/auth/login_page.dart';
import 'package:safe_pwd/auth/register_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Use a clean, modern font like Poppins if available, otherwise the default is fine.
        fontFamily: 'Arial',
        brightness: Brightness.dark,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Image with Dark Overlay
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                // Replace this with your actual image asset
                // image: AssetImage('assets/leaves_background.png'),
                image: const NetworkImage(
                  'https://i.pinimg.com/564x/3b/e1/c6/3be1c616049019023241061411743123.jpg',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. Content centered vertically and horizontally
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 60.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Push content down a bit from the top
                const SizedBox(height: 100),
                // Main Title Text
                const Text(
                  "The best app to keep you safe\nwherever you go.",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    height: 1.2, // Adjust line height for better spacing
                  ),
                ),

                // Push the buttons to the bottom
                const Spacer(),

                // "Sign in" Button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      // Translucent dark color for the button
                      color: const Color(0xFF4A5A50).withValues(),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "Sign in",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // "Create an account" Button
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Create an account",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                // Add some bottom padding
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
