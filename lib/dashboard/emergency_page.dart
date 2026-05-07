import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContactPage extends StatefulWidget {
  const EmergencyContactPage({super.key});

  @override
  State<EmergencyContactPage> createState() => _EmergencyContactPageState();
}

class _EmergencyContactPageState extends State<EmergencyContactPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isSending = false;
  bool _isSyncing = true;

  @override
  void initState() {
    super.initState();
    _fetchGuardianFromFirebase();
  }

  // --- Logic remains intact ---
  Future<void> _fetchGuardianFromFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userEmail = prefs.getString('userEmail');
      if (userEmail != null) {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users').where('email', isEqualTo: userEmail).limit(1).get();
        if (querySnapshot.docs.isNotEmpty) {
          var userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          if (userData.containsKey('guardian')) {
            Map<String, dynamic> guardianData = userData['guardian'];
            setState(() {
              _nameController.text = guardianData['name'] ?? "";
              _phoneController.text = guardianData['phone'] ?? "";
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      _showSnackBar("Please fill in both fields", Colors.orange.shade700);
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userEmail = prefs.getString('userEmail');
      if (userEmail == null) return;
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: userEmail).get();
      if (snapshot.docs.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(snapshot.docs.first.id).update({
          'guardian': {
            'name': _nameController.text,
            'phone': _phoneController.text,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        });
        _showSnackBar("Guardian settings saved", Colors.green.shade600);
      }
    } catch (e) {
      _showSnackBar("Save failed. Try again.", Colors.red.shade600);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _sendSOS() async {
    HapticFeedback.heavyImpact();
    if (_phoneController.text.isEmpty) {
      _showSnackBar("No Guardian Number Set", Colors.red.shade600);
      return;
    }
    setState(() => _isSending = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String mapUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      String message = "EMERGENCY! I need help. My live location: $mapUrl";
      final Uri smsLaunchUri = Uri(scheme: 'sms', path: _phoneController.text, queryParameters: {'body': message});
      if (await canLaunchUrl(smsLaunchUri)) await launchUrl(smsLaunchUri);
    } catch (e) {
      _showSnackBar("SOS Failed", Colors.red.shade600);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Emergency Hub", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: true,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline, color: Colors.black54))],
      ),
      body: _isSyncing 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              const Text("Set up your lifeline.", style: TextStyle(color: Colors.black54, fontSize: 16)),
              const SizedBox(height: 24),
              
              // Input Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Guardian Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    _buildInputField(_nameController, "Guardian Name", Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildInputField(_phoneController, "Guardian Phone", Icons.phone_outlined, TextInputType.phone),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _handleSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Save Guardian Info", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 64),
              
              // SOS Trigger Area
              const Center(child: Text("SOS TRIGGER", style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black38))),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _isSending ? null : _sendSOS,
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade600,
                      boxShadow: [
                        BoxShadow(color: Colors.red.shade200, blurRadius: 20, spreadRadius: 6),
                      ],
                    ),
                    child: _isSending 
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("SOS", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                          ],
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(child: Text("Hold for 1 second to trigger help", style: TextStyle(color: Colors.black45, fontSize: 13))),
            ],
          ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon, [TextInputType type = TextInputType.text]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black45)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black45),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.black, width: 2)),
          ),
        ),
      ],
    );
  }
}