import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.black.withOpacity(0.2),
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leaf Decoration
            Align(
              alignment: Alignment.topRight,
              child: Image.network(
                "https://cdn-icons-png.flaticon.com/512/2917/2917242.png",
                height: 50,
                color: const Color(0xFF2E5A3C),
              ),
            ),

            const Text(
              "Register",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E5A3C),
              ),
            ),
            const Text(
              "Create your new account",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            _buildTextField("Full Name", Icons.person_outline),
            _buildTextField(
              "user@mail.com",
              Icons.email_outlined,
              isCheck: true,
            ),
            _buildTextField("Password", Icons.lock_outline, isPassword: true),

            const SizedBox(height: 30),

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
                onPressed: () {},
                child: const Text(
                  "Register",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ), // Changed from Login to Register
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              "Or continue with",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _socialBtn(Icons.facebook, Colors.blue),
                const SizedBox(width: 20),
                _socialBtn(Icons.g_mobiledata, Colors.red),
                const SizedBox(width: 20),
                _socialBtn(Icons.apple, Colors.black),
              ],
            ),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already have an account? ",
                  style: TextStyle(color: Colors.grey),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    "Sign up",
                    style: TextStyle(
                      color: Color(0xFF2E5A3C),
                      fontWeight: FontWeight.bold,
                    ),
                  ), // Note: Image says Sign up, logically should be Login
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    IconData icon, {
    bool isPassword = false,
    bool isCheck = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        obscureText: isPassword,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF2E5A3C)),
          suffixIcon: isCheck
              ? const Icon(Icons.check, color: Colors.green)
              : (isPassword
                    ? const Icon(Icons.visibility_off, color: Colors.grey)
                    : null),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _socialBtn(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}
