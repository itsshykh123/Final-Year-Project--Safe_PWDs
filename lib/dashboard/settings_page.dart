import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterTts _tts = FlutterTts();
  
  // Settings States
  bool _enableTTS = true;
  bool _enableVibration = true;
  bool _autoSiren = false;
  String _guardianPhone = "Not Set";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load saved preferences from Session
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableTTS = prefs.getBool('enableTTS') ?? true;
      _enableVibration = prefs.getBool('enableVibration') ?? true;
      _autoSiren = prefs.getBool('autoSiren') ?? false;
      _guardianPhone = prefs.getString('guardianPhone') ?? "Add Number +";
    });
  }

  // Save changes to Session
  Future<void> _updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
    _loadSettings(); // Refresh UI
  }

  // Test functionality for demonstration
  void _runDiagnosticTest() async {
    if (_enableTTS) {
      await _tts.speak("Diagnostic test successful. Voice guidance is active.");
    }
    if (_enableVibration) {
      bool? hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 500);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Diagnostic Test Completed"), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader("Alert Preferences"),
          _buildSwitchTile(
            "Voice Guidance (TTS)",
            "Announce hazards for Blind users",
            Icons.record_voice_over,
            _enableTTS,
            (val) => _updateSetting('enableTTS', val),
          ),
          _buildSwitchTile(
            "Haptic Feedback",
            "Vibration alerts for Deaf users",
            Icons.vibration,
            _enableVibration,
            (val) => _updateSetting('enableVibration', val),
          ),
          _buildSwitchTile(
            "Automatic Siren",
            "Trigger loud alarm on high-risk detection",
            Icons.volume_up,
            _autoSiren,
            (val) => _updateSetting('autoSiren', val),
          ),

          const SizedBox(height: 24),
          _buildHeader("Emergency Contacts"),
          _buildClickTile(
            "Primary Guardian",
            _guardianPhone,
            Icons.contact_phone,
            () => _showGuardianDialog(),
          ),

          const SizedBox(height: 24),
          _buildHeader("System Diagnostics"),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const Icon(Icons.security_update_good, color: Colors.green),
              title: const Text("Run Safety System Test"),
              subtitle: const Text("Checks TTS and Haptic engines"),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _runDiagnosticTest,
            ),
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              "Safe PWD v1.0.0 (FYP Build)",
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          )
        ],
      ),
    );
  }

  // UI Helpers
  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2E5A3C)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Switch(
          value: value,
          activeColor: const Color(0xFF2E5A3C),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildClickTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD32F2F)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.edit, size: 18),
        onTap: onTap,
      ),
    );
  }

  void _showGuardianDialog() {
    TextEditingController phoneController = TextEditingController(text: _guardianPhone == "Add Number +" ? "" : _guardianPhone);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Emergency Contact"),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: "Enter Phone Number"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _updateSetting('guardianPhone', phoneController.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}