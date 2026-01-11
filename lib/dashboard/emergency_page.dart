import 'package:flutter/material.dart';
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

  Future<void> _fetchGuardianFromFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userEmail = prefs.getString('userEmail');

      if (userEmail != null) {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          var userData = querySnapshot.docs.first.data() as Map<String, dynamic>;

          if (userData.containsKey('guardian')) {
            Map<String, dynamic> guardianData = userData['guardian'];
            setState(() {
              _nameController.text = guardianData['name'] ?? "";
              _phoneController.text = guardianData['phone'] ?? "";
            });
            await prefs.setString('guardianName', _nameController.text);
            await prefs.setString('guardianPhone', _phoneController.text);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching: $e");
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
      _showSnackBar("Missing Guardian Info", Colors.orange);
      return;
    }
    setState(() => _isSyncing = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userEmail = prefs.getString('userEmail');
      if (userEmail == null) return;

      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(snapshot.docs.first.id).update({
          'guardian': {
            'name': _nameController.text,
            'phone': _phoneController.text,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
        });
        await prefs.setString('guardianName', _nameController.text);
        await prefs.setString('guardianPhone', _phoneController.text);
        _showSnackBar("Guardian Saved Securely", Colors.green);
      }
    } catch (e) {
      _showSnackBar("Save Failed", Colors.red);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _sendSOS() async {
    if (_phoneController.text.isEmpty) {
      _showSnackBar("No Guardian Number Set", Colors.red);
      return;
    }
    setState(() => _isSending = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      String mapUrl = "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";
      String message = "EMERGENCY! I need help. My live location: $mapUrl";
      
      final Uri smsLaunchUri = Uri(
        scheme: 'sms',
        path: _phoneController.text,
        queryParameters: <String, String>{'body': message},
      );

      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      }
    } catch (e) {
      _showSnackBar("SOS Failed", Colors.red);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents the physical back button from working
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _isSyncing 
          ? const Center(child: CircularProgressIndicator()) 
          : SafeArea( // Ensures content doesn't hit the notch/status bar
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Icon(Icons.emergency_share_rounded, size: 100, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text(
                      "Emergency Hub",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      "Configure your lifeline",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),
                    
                    // Input Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[200]!.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: "Guardian Name",
                              prefixIcon: Icon(Icons.person_outline),
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(),
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: "Guardian Phone",
                              prefixIcon: Icon(Icons.phone_outlined),
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red[900],
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text("Save Guardian Info", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // SOS TRIGGER
                    GestureDetector(
                      onTap: _isSending ? null : _sendSOS,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Pulsing Background Effect
                          Container(
                            height: 180,
                            width: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withOpacity(0.1),
                            ),
                          ),
                          Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              color: _isSending ? Colors.grey : Colors.red[800],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 25,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: Center(
                              child: _isSending
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.bolt, color: Colors.white, size: 40),
                                      Text(
                                        "SOS",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Hold for 1 second to trigger help",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}