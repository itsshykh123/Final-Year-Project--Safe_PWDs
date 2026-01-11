import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  // We keep the parameter as a backup, but we prioritize the Session
  final String userEmail;

  const ProfilePage({super.key, required this.userEmail});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Session Variables
  String? sessionEmail;
  String? sessionName;

  bool isEditingName = false;
  bool isEditingDisability = false;

  final TextEditingController nameController = TextEditingController();
  String disability = 'blind'; 
  late String docId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSessionAndData();
  }

  /// 1. Get Email from Session, then load Firestore Data
  Future<void> _initializeSessionAndData() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      // Prioritize the email stored in SharedPreferences
      sessionEmail = prefs.getString('userEmail') ?? widget.userEmail;
      sessionName = prefs.getString('userName') ?? "User";
    });

    if (sessionEmail != null && sessionEmail!.isNotEmpty) {
      await _loadUserDataFromFirestore(sessionEmail!);
    } else {
      setState(() => isLoading = false);
    }
  }

  /// 2. Fetch latest data from Firestore
  Future<void> _loadUserDataFromFirestore(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        docId = userDoc.id;
        
        setState(() {
          nameController.text = userDoc.data().containsKey('Name') ? userDoc.get('Name') : 'User';
          disability = userDoc.data().containsKey('disability') ? userDoc.get('disability') : 'blind';
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// 3. Update Name in both Firestore and Session
  Future<void> _updateName() async {
    String newName = nameController.text.trim();
    if (newName.isEmpty) return;

    await _firestore.collection('users').doc(docId).update({
      'Name': newName,
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', newName);
    
    setState(() {
      isEditingName = false;
      sessionName = newName;
    });
    
    _showSuccessSnackBar("Name updated successfully");
  }

  /// 4. Update Disability in both Firestore and Session
  Future<void> _updateDisability(String newValue) async {
    await _firestore.collection('users').doc(docId).update({
      'disability': newValue,
    });
    
    final prefs = await SharedPreferences.getInstance();
    // This key 'userMode' MUST match what your HomePage uses for TTS/Vibration
    await prefs.setString('userMode', newValue); 
    
    setState(() {
      disability = newValue;
      isEditingDisability = false;
    });

    _showSuccessSnackBar("Accessibility mode set to ${newValue.toUpperCase()}");
  }

  /// 5. Clear Session and Logout
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Wipe session data
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFF2E5A3C)),
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
              // Header Section
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
                      child: const Icon(Icons.person, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 15),
                    
                    // Editable Name Display
                    isEditingName
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                child: TextField(
                                  controller: nameController,
                                  autofocus: true,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.white),
                                onPressed: _updateName,
                              )
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                nameController.text,
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                onPressed: () => setState(() => isEditingName = true),
                              ),
                            ],
                          ),
                    Text(sessionEmail ?? "No email", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Information Details Card
              
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildEditableDropdown(
                        title: "Accessibility Mode",
                        value: disability,
                        isEditing: isEditingDisability,
                        options: const ['blind', 'deaf', 'both'],
                        onEdit: () => setState(() => isEditingDisability = true),
                        onSave: _updateDisability,
                      ),
                      const Divider(height: 30),
                      _buildReadOnlyField(title: "Account Email", value: sessionEmail ?? "N/A"),
                      const Divider(height: 30),
                      _buildReadOnlyField(title: "App Version", value: "1.0.0 (FYP-Build)"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5A3C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text("Logout", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(value, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        isEditing
            ? DropdownButton<String>(
                value: options.contains(value) ? value : options.first,
                items: options.map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase()))).toList(),
                onChanged: (v) { if (v != null) onSave(v); },
              )
            : Row(
                children: [
                  Text(value.toUpperCase(), style: const TextStyle(color: Color(0xFF2E5A3C), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings_accessibility, color: Color(0xFF2E5A3C), size: 22),
                    onPressed: onEdit,
                  ),
                ],
              ),
      ],
    );
  }
}