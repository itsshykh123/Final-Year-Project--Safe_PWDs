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
  String _guardianPhone = "Add Number +";

  @override
  void initState() {
    super.initState();
    _initTTS();
    _loadSettings();
  }

  @override
  void dispose() {
    _tts.stop(); // Essential to prevent memory leaks
    super.dispose();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enableTTS = prefs.getBool('enableTTS') ?? true;
      _enableVibration = prefs.getBool('enableVibration') ?? true;
      _autoSiren = prefs.getBool('autoSiren') ?? false;
      _guardianPhone = prefs.getString('guardianPhone') ?? "Add Number +";
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Setting Saved"),
          duration: Duration(milliseconds: 500),
        ),
      );
      _loadSettings();
    }
  }

  void _runDiagnosticTest() async {
    // 1. TTS Test
    if (_enableTTS) {
      await _tts.speak("Diagnostic test successful. Voice guidance is active.");
    }

    // 2. Vibration Test
    if (_enableVibration) {
      bool? hasVib = await Vibration.hasVibrator();
      if (hasVib == true) {
        Vibration.vibrate(duration: 500);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test complete. Check device feedback.")),
      );
    }
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
            "Voice Guidance",
            "Announce hazards",
            Icons.record_voice_over,
            _enableTTS,
            (val) => _updateSetting('enableTTS', val),
          ),
          _buildSwitchTile(
            "Haptic Feedback",
            "Vibration for alerts",
            Icons.vibration,
            _enableVibration,
            (val) => _updateSetting('enableVibration', val),
          ),
          _buildSwitchTile(
            "Automatic Siren",
            "Trigger alarm on risk",
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
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.security_update_good,
                color: Colors.green,
              ),
              title: const Text("Run Safety System Test"),
              onTap: _runDiagnosticTest,
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    ),
  );

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    ),
  );

  Widget _buildClickTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: onTap,
    ),
  );

  void _showGuardianDialog() {
    TextEditingController controller = TextEditingController(
      text: _guardianPhone == "Add Number +" ? "" : _guardianPhone,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Contact"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: "e.g., +923001234567"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length > 5) {
                // Simple validation
                _updateSetting('guardianPhone', controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
