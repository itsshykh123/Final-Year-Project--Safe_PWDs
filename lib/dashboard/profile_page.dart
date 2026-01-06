import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safe_pwd/auth/login_page.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;

  const ProfilePage({super.key, required this.userEmail});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isEditingName = false;
  bool isEditingDisability = false;

  final TextEditingController nameController = TextEditingController();
  String disability = 'Blind';
  late String docId;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .get();

    if (query.docs.isNotEmpty) {
      final userDoc = query.docs.first;
      docId = userDoc.id;
      nameController.text = userDoc.get('Name') ?? '';
      disability = userDoc.get('disability') ?? 'Blind';
    }
    setState(() => isLoading = false);
  }

  Future<void> _updateName() async {
    await _firestore.collection('users').doc(docId).update({
      'Name': nameController.text.trim(),
    });
    setState(() => isEditingName = false);
  }

  Future<void> _updateDisability(String newValue) async {
    await _firestore.collection('users').doc(docId).update({
      'disability': newValue,
    });
    setState(() {
      disability = newValue;
      isEditingDisability = false;
    });
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            children: [
              // Modern Profile Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E5A3C), Color(0xFF74C69D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 15),
                    isEditingName
                        ? SizedBox(
                            width: 200,
                            child: TextField(
                              controller: nameController,
                              autofocus: true,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                hintText: "Enter Name",
                                hintStyle: TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                nameController.text,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => isEditingName = true),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 5),
                    Text(
                      widget.userEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Profile Info Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Disability
                      _buildEditableDropdown(
                        title: "Disability",
                        value: disability,
                        isEditing: isEditingDisability,
                        options: const ['Blind', 'Deaf', 'Both'],
                        onEdit: () =>
                            setState(() => isEditingDisability = true),
                        onSave: _updateDisability,
                      ),

                      const SizedBox(height: 20),

                      // Email (read-only)
                      _buildReadOnlyField(
                        title: "Email",
                        value: widget.userEmail,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5A3C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _logout,
                  child: const Text("Logout", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField({required String title, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildEditableDropdown({
    required String title,
    required String value,
    required bool isEditing,
    required List<String> options,
    required VoidCallback onEdit,
    required Function(String) onSave,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        isEditing
            ? DropdownButton<String>(
                value: value,
                underline: const SizedBox(),
                items: options
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onSave(v);
                },
              )
            : Row(
                children: [
                  Text(value, style: TextStyle(color: Colors.grey[700])),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onEdit,
                    child: const Icon(
                      Icons.edit,
                      color: Color(0xFF2E5A3C),
                      size: 18,
                    ),
                  ),
                ],
              ),
      ],
    );
  }
}
