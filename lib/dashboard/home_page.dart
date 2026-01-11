import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_pwd/services/notification_service.dart';
import '../core/constants/app_colors.dart';
import 'alerts_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'emergency_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  String userName = "Loading...";
  String _userMode = "both"; // Default
  String? _lastAlertId; // Prevents duplicate triggers

  final FlutterTts _tts = FlutterTts();

  final List<Widget> _pages = [
    const DashboardHomeContent(),
    const AlertsPage(),
    const SettingsPage(),
    const ProfilePage(userEmail: ''),
    const EmergencyPage(),
  ];

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    try {
      // Splits "31-10-2025" into [31, 10, 2025]
      List<String> parts = dateStr.split('-');
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (e) {
      return DateTime(2000); // Fallback for bad data
    }
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userMode = prefs.getString('userMode') ?? "both";
      userName = prefs.getString('userName') ?? "User";
    });
  }

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  // Accessibility Alert Trigger
  void _triggerAccessibilityAlert(String title) async {
    // Persistent Visual Banner
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.redAccent,
        leading: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.white,
          size: 40,
        ),
        content: Text(
          "EMERGENCY: $title",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text(
              "DISMISS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    // 1. BLIND MODE: Voice Feedback
    if (_userMode == "blind" || _userMode == "both") {
      await _tts.setLanguage("en-US");
      await _tts.speak("Emergency Alert: $title");
    }

    // 2. DEAF MODE: Haptic & Visual Feedback
    if (_userMode == "deaf" || _userMode == "both") {
      // Vibrate for 1.5 seconds in a specific pattern
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
      }
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine which icon to show in the header based on the session userMode
    IconData modeIcon;
    Color modeColor = Colors.white;

    if (_userMode == 'blind') {
      modeIcon = Icons.record_voice_over;
    } else if (_userMode == 'deaf') {
      modeIcon = Icons.vibration;
    } else if (_userMode == 'both') {
      modeIcon = Icons.all_inclusive;
    } else {
      modeIcon = Icons.accessibility_new;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // 1. REMOVE BACK BUTTON
        automaticallyImplyLeading: false,

        // 2. MODERN HEADER STYLING
        backgroundColor: const Color.fromARGB(255, 220, 33, 33),
        elevation: 4,
        title: Row(
          children: [
            // User Avatar Circle
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            // Name and Welcome text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, $userName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Safety Dashboard',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // 3. MODE ICON DISPLAY IN APPBAR
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Tooltip(
              message: "Active Mode: ${_userMode.toUpperCase()}",
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(modeIcon, color: modeColor, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ensure pages are loaded using the getter to pass latest session data
          _pages[_currentIndex],

          // BACKGROUND FIRESTORE LISTENER
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('advisories')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                List<QueryDocumentSnapshot> sortedDocs = snapshot.data!.docs
                    .toList();

                // Sort locally to ensure "31-10-2025" logic works correctly
                sortedDocs.sort((a, b) {
                  Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
                  Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;
                  return _parseDate(
                    dataB['date'],
                  ).compareTo(_parseDate(dataA['date']));
                });

                var latestDoc = sortedDocs.first;
                var alert = latestDoc.data() as Map<String, dynamic>;
                String currentId = latestDoc.id;

                if (_lastAlertId != currentId) {
                  _lastAlertId = currentId;

                  // Trigger System-wide Alert
                  NotificationService.showHighRiskNotification(
                    title: "EMERGENCY ALERT",
                    body: alert['title'] ?? "New Hazard Detected",
                  );

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _triggerAccessibilityAlert(
                      alert['title'] ?? "Hazard Detected",
                    );
                  });
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_rounded),
            label: 'Alerts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_suggest),
            label: 'Settings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(
            icon: Icon(Icons.emergency_share),
            label: 'SOS',
          ),
        ],
      ),
    );
  }
}

class DashboardHomeContent extends StatelessWidget {
  const DashboardHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALL CLEAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'No Active Threats',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              _infoCard('Weather', '24°C', 'Partly Cloudy', Icons.cloud),
              const SizedBox(width: 12),
              _infoCard(
                'Location',
                'San Francisco',
                'CA 94102',
                Icons.location_on,
              ),
            ],
          ),
          // ElevatedButton(
          //   onPressed: () {
          //     NotificationService.showHighRiskNotification(
          //       title: "Test Alert",
          //       body: "This is a test high-risk alert",
          //     );
          //   },
          //   child: const Text("Test Notification"),
          // ),
          const SizedBox(height: 16),

          _simpleCard(
            Icons.warning,
            'Nearby Hazards',
            'No active hazards in your area',
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Preparedness Tip of the Day\n\nKeep an emergency kit with water, non-perishable food, flashlight, and radio.',
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            onPressed: () {},
            icon: const Icon(Icons.volume_up),
            label: const Text('Activate Hardware Siren'),
          ),
        ],
      ),
    );
  }

  static Widget _infoCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _simpleCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
