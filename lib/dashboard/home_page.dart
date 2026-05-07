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

    if (_userMode == "blind") {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.speak("Emergency Alert: $title. Please check the dashboard.");
    }

    // 3. Vibration Logic
    if (_userMode == "deaf") {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(
          pattern: [0, 1000, 500, 1000, 500, 1000],
          repeat: 0, // loops from index 0
        );

        // Stop after 5 minutes
        Future.delayed(Duration(minutes: 5), () {
          Vibration.cancel();
        });
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

// ─── Color Tokens ────────────────────────────────────────────────
class _C {
  static const pageBg = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E5EC);

  static const text = Color(0xFF1A1D23);
  static const text2 = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9EA5B5);

  // Green (safe / clear)
  static const greenBg = Color(0xFFEAF3DE);
  static const greenBorder = Color(0xFFC0DD97);
  static const green = Color(0xFF3B6D11);
  static const greenDark = Color(0xFF27500A);
  static const greenMid = Color(0xFF639922);

  // Blue (info / location)
  static const blueBg = Color(0xFFEEF4FF);
  static const blueBorder = Color(0xFFBDD1F8);
  static const blue = Color(0xFF378ADD);
  static const blueDark = Color(0xFF185FA5);

  // Amber (weather)
  static const amberBg = Color(0xFFFEF3C7);
  static const amberBorder = Color(0xFFFDE68A);
  static const amber = Color(0xFFD97706);

  // Red (siren)
  static const redBg = Color(0xFFFFF5F5);
  static const redBorder = Color(0xFFFECACA);
  static const redBorder2 = Color(0xFFFCA5A5);
  static const red = Color(0xFFE24B4A);
  static const redDark = Color(0xFFA32D2D);
  static const redChip = Color(0xFFFECACA);
}

// ─── Widget ───────────────────────────────────────────────────────
class DashboardHomeContent extends StatefulWidget {
  const DashboardHomeContent({super.key});

  @override
  State<DashboardHomeContent> createState() => _DashboardHomeContentState();
}

class _DashboardHomeContentState extends State<DashboardHomeContent>
    with SingleTickerProviderStateMixin {
  String _temp = '—';
  String _weatherStatus = 'Fetching...';
  String _city = '—';
  String _area = 'Detecting...';
  IconData _weatherIcon = Icons.wb_sunny_rounded;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.75,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _fetchLiveStatus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _city = 'Enable GPS');
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          setState(() => _city = 'Permission Denied');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _city = 'Settings Required');
        await Geolocator.openAppSettings();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = marks[0];

      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${pos.latitude}&longitude=${pos.longitude}'
        '&current_weather=true',
      );
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['current_weather'];
        final code = data['weathercode'] as int;
        setState(() {
          _temp = '${data['temperature']}°C';
          _city = p.locality ?? 'Unknown';
          _area = p.subLocality ?? p.name ?? '';
          _weatherStatus = code == 0 ? 'Clear Sky' : 'Overcast';
          _weatherIcon = code == 0
              ? Icons.wb_sunny_rounded
              : Icons.cloud_rounded;
        });
      }
    } catch (e) {
      debugPrint('Location Error: $e');
      setState(() {
        _temp = 'N/A';
        _city = 'Retry';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusBanner(pulseAnim: _pulseAnim),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'WEATHER',
                    value: _temp,
                    sub: _weatherStatus,
                    icon: _weatherIcon,
                    chipBg: _C.amberBg,
                    chipBorder: _C.amberBorder,
                    iconColor: _C.amber,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    label: 'LOCATION',
                    value: _city,
                    valueFontSize: 15,
                    sub: _area.isEmpty ? 'Detecting...' : _area,
                    icon: Icons.location_on_rounded,
                    chipBg: _C.blueBg,
                    chipBorder: _C.blueBorder,
                    iconColor: _C.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _HazardCard(),
            const SizedBox(height: 10),
            _TipCard(),
            const SizedBox(height: 10),
            _SirenButton(),
          ],
        ),
      ),
    );
  }
}

// ─── Status Banner ────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final Animation<double> pulseAnim;
  const _StatusBanner({required this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _C.greenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.greenBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: pulseAnim,
                  builder: (_, __) => Transform.scale(
                    scale: pulseAnim.value,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _C.green.withOpacity(
                            1.0 - (pulseAnim.value - 1.0) / 0.75,
                          ),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.greenBg,
                    border: Border.all(color: _C.green, width: 1.5),
                  ),
                  child: Center(
                    child: CircleAvatar(radius: 4.5, backgroundColor: _C.green),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALL CLEAR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.greenDark,
                    letterSpacing: 0.07,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'No active threats detected',
                  style: TextStyle(fontSize: 12, color: _C.greenMid),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _C.greenBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.greenBorder),
            ),
            child: Text(
              'Live',
              style: TextStyle(
                fontSize: 11,
                color: _C.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final double valueFontSize;
  final String sub;
  final IconData icon;
  final Color chipBg;
  final Color chipBorder;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueFontSize = 19,
    required this.sub,
    required this.icon,
    required this.chipBg,
    required this.chipBorder,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: chipBorder),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _C.textMuted,
              letterSpacing: 0.07,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w600,
              color: _C.text,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: _C.text2),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Hazard Card ─────────────────────────────────────────────────
class _HazardCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _C.greenBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.greenBorder),
            ),
            child: Icon(Icons.warning_amber_rounded, color: _C.green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby hazards',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _C.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No active hazards in your area',
                  style: TextStyle(fontSize: 11, color: _C.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _C.greenBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _C.greenBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 3, backgroundColor: _C.green),
                const SizedBox(width: 5),
                Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 11,
                    color: _C.greenDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tip Card ────────────────────────────────────────────────────
class _TipCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.blueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.blueBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.blueBorder),
            ),
            child: Icon(Icons.info_outline_rounded, color: _C.blue, size: 16),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREPAREDNESS TIP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _C.blueDark,
                    letterSpacing: 0.07,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ensure your emergency kit is easily accessible and reviewed regularly.',
                  style: TextStyle(fontSize: 12, color: _C.blue, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Siren Button ────────────────────────────────────────────────
class _SirenButton extends StatefulWidget {
  @override
  State<_SirenButton> createState() => _SirenButtonState();
}

class _SirenButtonState extends State<_SirenButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        // TODO: implement siren activation
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0xFFFEE2E2) : _C.redBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _pressed ? _C.redBorder2 : _C.redBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _C.redChip,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.volume_up_rounded, color: _C.red, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Activate hardware siren',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _C.redDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
