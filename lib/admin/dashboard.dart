import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your page files
import 'create_alert_page.dart';
import 'users_list_page.dart';
import 'alerts_list_page.dart';
import '../auth/login_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? adminEmail;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // ✅ Load current admin email to hide it from the list
  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      adminEmail = prefs.getString('userEmail');
    });
  }

  // ✅ Fetch user data for the drawer
  Future<Map<String, String>> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('userName') ?? 'Admin User',
      'email': prefs.getString('userEmail') ?? 'admin@system.com',
    };
  }

  bool hasField(Map<String, dynamic> data, String key) {
    return data.containsKey(key) && data[key] != null;
  }

  Map<String, int> calculateStats(
    List<QueryDocumentSnapshot> docs,
    String? adminEmail,
  ) {
    int total = 0;
    int disabled = 0;
    int guardian = 0;
    int recent = 0;
    final now = DateTime.now();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final email = (data['email'] ?? '').toString().toLowerCase();

      // ✅ Skip the admin record entirely
      if (adminEmail != null && email == adminEmail.toLowerCase()) {
        continue;
      }

      // If it's not the admin, increment total and check other stats
      total++;

      if (hasField(data, 'disability') && data['disability'] != "Normal") {
        disabled++;
      }

      if (hasField(data, 'guardian')) {
        guardian++;
      }

      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        final created = (data['createdAt'] as Timestamp).toDate();
        if (now.difference(created).inDays <= 7) {
          recent++;
        }
      }
    }

    return {
      "total": total,
      "disabled": disabled,
      "guardian": guardian,
      "recent": recent,
    };
  }

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return ListTile(
      selected: isActive,
      selectedTileColor: Colors.blue.withOpacity(0.1),
      selectedColor: Colors.blueAccent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // ✅ FutureBuilder to load dynamic SharedPreferences data
          FutureBuilder<Map<String, String>>(
            future: _getUserData(),
            builder: (context, snapshot) {
              final name = snapshot.data?['name'] ?? 'Loading...';
              final email = snapshot.data?['email'] ?? '...';

              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.blueAccent),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 40,
                    color: Colors.blueAccent,
                  ),
                ),
                accountName: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                accountEmail: Text(email),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 20, bottom: 8),
                  child: Text(
                    "MANAGEMENT",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _drawerItem(
                  icon: Icons.dashboard_rounded,
                  label: "Dashboard",
                  isActive: true,
                  onTap: () => Navigator.pop(context),
                ),
                _drawerItem(
                  icon: Icons.people_alt_rounded,
                  label: "Users List",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsersListPage()),
                  ),
                ),
                _drawerItem(
                  icon: Icons.notification_important_rounded,
                  label: "Alert Logs",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlertsListPage()),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: Colors.red.withOpacity(0.05),
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => logout(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      drawer: buildDrawer(context),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateAlertPage()),
        ),
        icon: const Icon(Icons.add_alert),
        label: const Text("Create Alert"),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return const Center(child: Text("Error fetching data"));

          final docs = snapshot.data?.docs ?? [];
          final stats = calculateStats(docs, adminEmail);

          return Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                statCard(
                  "Total Users",
                  stats['total']!,
                  Icons.people,
                  Colors.blue,
                ),
                statCard(
                  "Disabled",
                  stats['disabled']!,
                  Icons.accessibility_new,
                  Colors.red,
                ),
                statCard(
                  "Guardians",
                  stats['guardian']!,
                  Icons.family_restroom,
                  Colors.green,
                ),
                statCard(
                  "Recent (7d)",
                  stats['recent']!,
                  Icons.trending_up,
                  Colors.orange,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
