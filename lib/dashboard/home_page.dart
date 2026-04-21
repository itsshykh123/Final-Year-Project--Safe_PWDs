import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_pwd/services/notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:async/async.dart' show StreamGroup;

// Page Imports
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
  String userEmail = "";
  String _userMode = "both";
  String? _lastAlertId;

  final FlutterTts _tts = FlutterTts();

  // Navigation Logic
  List<Widget> get _pages => [
    const DashboardHomeContent(),
    const AlertsPage(),
    const SettingsPage(),
    ProfilePage(userEmail: userEmail),
    const EmergencyContactPage(),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userMode = prefs.getString('userMode') ?? "both";
      userName = prefs.getString('userName') ?? "User";
      userEmail = prefs.getString('userEmail') ?? "";
    });
  }

  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return DateTime(2000);
    try {
      List<String> parts = dateStr.split('-');
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (e) {
      return DateTime(2000);
    }
  }

  // ✅ Visual Helper for Deaf/Full-Screen
  Widget _getAlertVisual(String title, {double size = 150}) {
    final t = title.toLowerCase();
    String imagePath = 'assets/images/warning.png'; // Default fallback

    if (t.contains('fire')) {
      imagePath = 'assets/images/fire.png';
    } else if (t.contains('flood') || t.contains('rain')) {
      imagePath = 'assets/images/flood.png';
    } else if (t.contains('storm') || t.contains('cyclone')) {
      imagePath = 'assets/images/storm.png';
    } else if (t.contains('earthquake')) {
      imagePath = 'assets/images/earthquake.png';
    } else if (t.contains('medical')) {
      imagePath = 'assets/images/medical.png';
    }

    return Image.asset(
      imagePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Error builder ensures app doesn't crash if image is missing
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.warning, color: Colors.white, size: size),
    );
  }

  // ✅ FULL SCREEN ALERT TRIGGER
  void _triggerAccessibilityAlert(String title) async {
    // 1. Notification
    NotificationService.showHighRiskNotification(
      title: "⚠️ EMERGENCY",
      body: title,
    );

    // 2. TTS
    if (_userMode == "blind" || _userMode == "both") {
      await _tts.speak(
        "Emergency Alert: $title. Look at the screen for details.",
      );
    }

    // 3. Vibration
    if (_userMode == "deaf" || _userMode == "both") {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 1000, 500, 1000]);
      }
    }

    // 4. Full Screen Image Overlay
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, anim1, anim2) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            backgroundColor: const Color(0xFFB71C1C),
            body: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _getAlertVisual(title, size: 220), // Show large picture
                    const SizedBox(height: 40),
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 70),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          Vibration.cancel();
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          "DISMISS / I AM SAFE",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchCombinedAlerts() async {
    final advisories = await FirebaseFirestore.instance
        .collection('advisories')
        .get();
    final alerts = await FirebaseFirestore.instance
        .collection('alerts')
        .where('isActive', isEqualTo: true)
        .get();
    return [...advisories.docs, ...alerts.docs];
  }

  @override
  Widget build(BuildContext context) {
    IconData modeIcon = _userMode == 'blind'
        ? Icons.record_voice_over
        : _userMode == 'deaf'
        ? Icons.vibration
        : Icons.all_inclusive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 220, 33, 33),
        elevation: 4,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Text(
                userName.isNotEmpty ? userName[0] : "U",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(modeIcon, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          _pages[_currentIndex],
          StreamBuilder<QuerySnapshot>(
            stream: StreamGroup.merge([
              FirebaseFirestore.instance.collection('advisories').snapshots(),
              FirebaseFirestore.instance
                  .collection('alerts')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
            ]),
            builder: (context, snapshot) {
              return FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _fetchCombinedAlerts(),
                builder: (context, futureSnapshot) {
                  if (!futureSnapshot.hasData || futureSnapshot.data!.isEmpty)
                    return const SizedBox.shrink();
                  final allDocs = futureSnapshot.data!;
                  allDocs.sort((a, b) {
                    var dA = a.data() as Map<String, dynamic>;
                    var dB = b.data() as Map<String, dynamic>;
                    DateTime tA = dA['createdAt'] is Timestamp
                        ? (dA['createdAt'] as Timestamp).toDate()
                        : _parseDate(dA['date']);
                    DateTime tB = dB['createdAt'] is Timestamp
                        ? (dB['createdAt'] as Timestamp).toDate()
                        : _parseDate(dB['date']);
                    return tB.compareTo(tA);
                  });
                  if (_lastAlertId != allDocs.first.id) {
                    _lastAlertId = allDocs.first.id;
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _triggerAccessibilityAlert(allDocs.first['title']),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
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

// ✅ RE-INTEGRATED DASHBOARD CONTENT (Weather, Location, Hardware Siren)
class DashboardHomeContent extends StatefulWidget {
  const DashboardHomeContent({super.key});
  @override
  State<DashboardHomeContent> createState() => _DashboardHomeContentState();
}

class _DashboardHomeContentState extends State<DashboardHomeContent> {
  String _temp = "Loading...";
  String _weatherStatus = "Fetching...";
  String _city = "Locating...";
  String _area = "Detecting...";
  IconData _weatherIcon = Icons.cloud_queue;

  @override
  void initState() {
    super.initState();
    _fetchLiveStatus();
  }

  Future<void> _fetchLiveStatus() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      List<Placemark> marks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      Placemark p = marks[0];

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current_weather=true',
      );
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['current_weather'];
        setState(() {
          _temp = "${data['temperature']}°C";
          _city = p.locality ?? "Unknown";
          _area = p.subLocality ?? p.name ?? "";
          _weatherStatus = data['weathercode'] == 0 ? "Clear Sky" : "Overcast";
          _weatherIcon = data['weathercode'] == 0
              ? Icons.wb_sunny
              : Icons.cloud;
        });
      }
    } catch (e) {
      setState(() {
        _temp = "N/A";
        _city = "Error";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatusBanner(),
          const SizedBox(height: 16),
          Row(
            children: [
              _card('Weather', _temp, _weatherStatus, _weatherIcon),
              const SizedBox(width: 12),
              _card('Location', _city, _area, Icons.location_on),
            ],
          ),
          const SizedBox(height: 16),
          _simpleCard(
            Icons.warning,
            'Nearby Hazards',
            'No active hazards in your area',
          ),
          const SizedBox(height: 16),
          _tipCard(),
          const SizedBox(height: 24),
          _sirenBtn(),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF2D6A4F),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
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
            Text('No Active Threats', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ],
    ),
  );
  Widget _card(String t, String v, String s, IconData i) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
        ],
      ),
      child: Column(
        children: [
          Icon(i, color: Colors.red),
          const SizedBox(height: 8),
          Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            v,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Text(
            s,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    ),
  );
  Widget _simpleCard(IconData i, String t, String s) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(i, color: Colors.green),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(s, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ],
    ),
  );
  Widget _tipCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.withOpacity(0.3)),
    ),
    child: const Text(
      'Preparedness Tip\n\nEnsure your emergency kit is easily accessible.',
      style: TextStyle(fontSize: 13),
    ),
  );
  Widget _sirenBtn() => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      foregroundColor: Colors.red,
      side: const BorderSide(color: Colors.red),
    ),
    onPressed: () {},
    icon: const Icon(Icons.volume_up),
    label: const Text('Activate Hardware Siren'),
  );
}
