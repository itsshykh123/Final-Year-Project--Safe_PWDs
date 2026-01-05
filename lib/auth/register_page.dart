import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // 1. Controllers to get text from fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  // 2. The Register Function
  void _registerUser() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;

      // Check if user already exists
      final existingUser = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (existingUser.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email already registered")),
        );
      } else {
        // Create new user document
        await firestore.collection('users').add({
          'Name': name,
          'email': email,
          'password': password, // Storing plain text as requested
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account Created Successfully!")),
        );
        Navigator.pop(context); // Go back to login
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.black,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
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

            // 3. Pass controllers to text fields
            _buildTextField("Full Name", Icons.person_outline, _nameController),
            _buildTextField(
              "user@mail.com",
              Icons.email_outlined,
              _emailController,
            ),
            _buildTextField(
              "Password",
              Icons.lock_outline,
              _passwordController,
              isPassword: true,
            ),

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
                onPressed: _isLoading
                    ? null
                    : _registerUser, // Disable while loading
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Register",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
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
<<<<<<< Updated upstream
                    "Log in", // Corrected label
=======
                    "Sign in",
>>>>>>> Stashed changes
                    style: TextStyle(
                      color: Color(0xFF2E5A3C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 4. Added controller parameter to the helper widget
  Widget _buildTextField(
    String hint,
    IconData icon,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller, // Link the controller
        obscureText: isPassword,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF2E5A3C)),
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
