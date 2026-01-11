import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import 'package:safe_pwd/dashboard/home_page.dart';
import 'register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool rememberMe = false;

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final emailInput = emailController.text.trim();
      final passwordInput = passwordController.text.trim();

      final querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: emailInput)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No user found with this email")),
          );
        }
        return;
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data(); // Get the full map
      final storedPassword = userData['password'];

      if (storedPassword == passwordInput) {
        // --- SESSION STORAGE START ---
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userName', userData['Name'] ?? 'User');
        await prefs.setString('userEmail', userData['email'] ?? '');
        await prefs.setString('userMode', userData['disability'] ?? 'both');
        // --- SESSION STORAGE END ---
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Incorrect password")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // TOP IMAGE SECTION
            Stack(
              children: [
                ClipPath(
                  clipper: WaveClipper(),
                  child: Container(
                    height: 350,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(
                          "https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?q=80&w=1000&auto=format&fit=crop",
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      color: const Color(0xFF2E5A3C).withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),

            // FORM SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E5A3C),
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Login to your account",
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 30),

                    _buildTextField(
                      "Email",
                      Icons.email_outlined,
                      false,
                      emailController,
                    ),
                    _buildTextField(
                      "Password",
                      Icons.lock_outline,
                      true,
                      passwordController,
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: rememberMe,
                              activeColor: const Color(0xFF2E5A3C),
                              onChanged: (v) {
                                setState(() => rememberMe = v!);
                              },
                            ),
                            const Text(
                              "Remember Me",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          "Forgot Password?",
                          style: TextStyle(
                            color: Color(0xFF2E5A3C),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E5A3C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: _login,
                        child: const Text(
                          "Login",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          ),
                          child: const Text(
                            "Sign up",
                            style: TextStyle(
                              color: Color(0xFF2E5A3C),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    IconData icon,
    bool isPassword,
    TextEditingController controller,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "$hint is required";
          }
          if (!isPassword && !value.contains("@")) {
            return "Enter a valid email";
          }
          if (isPassword && value.length < 6) {
            return "Password must be at least 6 characters";
          }
          return null;
        },
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF2E5A3C)),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

// WAVY HEADER
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 80);

    final firstControlPoint = Offset(size.width / 4, size.height);
    final firstEndPoint = Offset(size.width / 2.25, size.height - 50);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(
      size.width - (size.width / 3.25),
      size.height - 100,
    );
    final secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
