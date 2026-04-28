import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
import 'package:rxdart/rxdart.dart';
import 'package:intl/intl.dart';

// Page Imports
import '../core/constants/app_colors.dart';
import 'alerts_page.dart';
import 'settings_page.dart';
import 'profile_page.dart';
import 'emergency_page.dart';

class HomePage extends StatefulWidget {
  final bool startWithAlert; // Passed from main.dart if initialMessage != null
  const HomePage({super.key, this.startWithAlert = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  String userName = "Loading...";
  String userEmail = "";
  String _userMode = "both";
  // String? _lastAlertId;

  final FlutterTts _tts = FlutterTts();
  StreamSubscription? _alertSubscription;

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
    _initialSetup();

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _triggerAccessibilityAlert(
        message.data['body'] ?? "Emergency Alert",
        "fcm_open",
      );
    });

    // If we were woken up by a notification, trigger immediate feedback
    if (widget.startWithAlert) {
      _triggerAccessibilityAlert("Emergency Alert Received", "system_init");
    }
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initialSetup() async {
    await _loadUserPreferences();
    _startAlertListener();
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userMode = prefs.getString('userMode') ?? "both";
      userName = prefs.getString('userName') ?? "User";
      userEmail = prefs.getString('userEmail') ?? "";
    });
  }

  void _startAlertListener() {
    final now = DateTime.now();

    // Format for the 'advisories' table (e.g., "26-04-2026")
    final String todayStr = DateFormat('dd-MM-yyyy').format(now);

    // Start of today for 'alerts' (Timestamp comparison)
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);

    // 1. Stream for 'alerts' collection (Filters by Timestamp)
    Stream<List<Map<String, dynamic>>> alertsStream = FirebaseFirestore.instance
        .collection('alerts')
        .where('isActive', isEqualTo: true)
        .where('severity', whereIn: ['Critical', 'High'])
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'source_table': 'alerts',
              'displayDate': (data['createdAt'] as Timestamp).toDate(),
            };
          }).toList(),
        );

    // 2. Stream for 'advisories' collection (Filters by Date String)
    Stream<List<Map<String, dynamic>>> advisoriesStream = FirebaseFirestore
        .instance
        .collection('advisories')
        .where('date', isEqualTo: todayStr)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'source_table': 'advisories',
              // Parse string date back to DateTime for sorting
              'displayDate': DateFormat('dd-MM-yyyy').parse(data['date']),
            };
          }).toList(),
        );

    // 3. Combine both streams into one
    _alertSubscription =
        Rx.combineLatest2(
          alertsStream,
          advisoriesStream,
          (a, b) => [...a, ...b],
        ).listen((combinedList) async {
          if (combinedList.isEmpty) return;

          final prefs = await SharedPreferences.getInstance();
          final String? userEmail = prefs.getString(
            'userEmail',
          ); // Get email from prefs since no Auth
          if (userEmail == null) return;

          for (var alert in combinedList) {
            final String alertId = alert['id'];

            // Check if this specific user has already acknowledged this alert
            bool localSeen =
                prefs.getBool("${userEmail}_seen_$alertId") ?? false;
            List seenByList = alert['seenBy'] ?? [];
            bool cloudSeen = seenByList.contains(userEmail);

            if (!localSeen && !cloudSeen) {
              // THIS IS THE TRIGGER
              _triggerAccessibilityAlert(alert['title'], alertId);

              // Auto-mark as seen so it doesn't pop up again every time the stream updates
              await _markAsSeenInDB(alertId, alert['source_table']);
            }
          }
        });
  }

  Future<void> _markAsSeenInDB(String alertId, String collectionName) async {
    if (userEmail.isEmpty) return;

    try {
      // 1. Update the specific collection (alerts or advisories)
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(alertId)
          .update({
            'seenBy': FieldValue.arrayUnion([userEmail]),
          });

      // 2. Update Local Prefs (SharedPref key stays unique to the alertId)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("${userEmail}_seen_$alertId", true);

      debugPrint(
        "Item $alertId in $collectionName marked as seen for $userEmail",
      );
    } catch (e) {
      // If a table (like advisories) doesn't have the 'seenBy' field yet,
      // Firestore might throw an error. You can use set with merge:true to be safe.
      debugPrint("Auto-save to DB failed for $collectionName: $e");

      // Alternative: Use set with merge if you want to create the field if it's missing
      /*
    await FirebaseFirestore.instance.collection(collectionName).doc(alertId).set(
      {'seenBy': FieldValue.arrayUnion([userEmail])}, 
      SetOptions(merge: true)
    );
    */
    }
  }

  // ✅ VISUAL HELPER
  Widget _getAlertVisual(String title, {double size = 150}) {
    final t = title.toLowerCase();
    String imagePath = 'assets/images/warning.png';
    if (t.contains('fire'))
      imagePath = 'assets/images/fire.png';
    else if (t.contains('flood') || t.contains('rain'))
      imagePath = 'assets/images/flood.png';
    else if (t.contains('storm') || t.contains('cyclone'))
      imagePath = 'assets/images/storm.png';
    else if (t.contains('earthquake'))
      imagePath = 'assets/images/earthquake.png';
    else if (t.contains('medical'))
      imagePath = 'assets/images/medical.png';

    return Image.asset(
      imagePath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.warning, color: Colors.white, size: size),
    );
  }

  // ✅ ACCESSIBILITY ALERT TRIGGER
  void _triggerAccessibilityAlert(String title, String alertId) async {
    NotificationService.showHighRiskNotification(
      title: "⚠️ EMERGENCY",
      body: title,
    );

    if (_userMode == "blind" || _userMode == "both") {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.speak("Emergency Alert: $title. Please check the dashboard.");
    }

    // 3. Vibration Logic
    if (_userMode == "deaf" || _userMode == "both") {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 1000, 500, 1000, 500, 1000]);
      }
    }

    if (_userMode == "both") {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 1000, 500, 1000]);
      }
    }

    if (_userMode == "deaf") {
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
                      _getAlertVisual(title, size: 220),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          title.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
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
                              fontSize: 18,
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
      body: _pages[_currentIndex],
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
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 1. Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, ask user to enable it
        setState(() => _city = "Enable GPS");
        await Geolocator.openLocationSettings();
        return;
      }

      // 2. Check permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _city = "Permission Denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        setState(() => _city = "Settings Required");
        await Geolocator.openAppSettings();
        return;
      }

      // 3. If we reached here, permissions are granted and GPS is on
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
      debugPrint("Location Error: $e");
      setState(() {
        _temp = "N/A";
        _city = "Retry Location";
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
