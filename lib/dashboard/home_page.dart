import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:safe_pwd/services/notification_service.dart';
import '../core/constants/app_colors.dart';
import 'alerts_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'emergency_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final FlutterTts _tts = FlutterTts();
  String userMode = "deaf"; // This should come from your Settings/Profile

  // Helper to trigger accessibility actions
  void _triggerAccessibilityAlert(String title) async {
    // 1. BLIND: Speak the alert
    if (userMode == "blind" || userMode == "both") {
      await _tts.speak("Emergency Alert: $title");
    }

    // 2. DEAF: Vibrate and show visual cues
    if (userMode == "deaf" || userMode == "both") {
      // Vibration.vibrate(duration: 1000); // Shake for 1 second
      // HapticFeedback.heavyImpact();

      // Show a high-priority banner at the top
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          backgroundColor: Colors.red,
          content: Text(
            "ALERT: $title",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text(
                "DISMISS",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }

  final List<Widget> _pages = [
    const DashboardHomeContent(),
    const AlertsPage(),
    const SettingsPage(),
    const ProfilePage(userEmail: ''),
    const EmergencyPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 220, 33, 33),
        title: const Text('SAFE-PWDs'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications),
          ),
        ],
      ),
      // We wrap the body to listen for alerts globally on the home page
      body: Stack(
        children: [
          _pages[_currentIndex],

          // HIDDEN LISTENER: Listens for the most recent alert
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('alerts')
                .orderBy('issuedAt', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                var alert =
                    snapshot.data!.docs.first.data() as Map<String, dynamic>;

                // Logic to prevent repeating the same alert
                // (In a real app, you'd check if alert['id'] was already played)

                // Use WidgetsBinding to trigger audio/vibration after build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _triggerAccessibilityAlert(
                    alert['title'] ?? "New Hazard Detected",
                  );
                });
              }
              return const SizedBox.shrink(); // This widget is invisible
            },
          ),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),

          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alerts'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.phone), label: 'Emergency'),
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
          ElevatedButton(
            onPressed: () {
              NotificationService.showHighRiskNotification(
                title: "Test Alert",
                body: "This is a test high-risk alert",
              );
            },
            child: const Text("Test Notification"),
          ),
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
