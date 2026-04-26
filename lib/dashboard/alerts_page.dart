import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  // ✅ Custom Parser for your "DD-MM-YYYY" String format
  DateTime _getDateTime(Map<String, dynamic> data) {
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      return (data['createdAt'] as Timestamp).toDate();
    }

    // Parse your "03-11-2025" String
    try {
      if (data['date'] != null && data['date'] is String) {
        List<String> parts = data['date'].split('-');
        // DateTime expects (Year, Month, Day)
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (e) {
      debugPrint("Date parsing error: $e");
    }
    return DateTime(2000); // Fallback for sorting
  }

  @override
  Widget build(BuildContext context) {
    final advisoriesStream = FirebaseFirestore.instance
        .collection('advisories')
        .snapshots();
    final alertsStream = FirebaseFirestore.instance
        .collection('alerts')
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(padding: EdgeInsets.all(16.0)),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: advisoriesStream,
                builder: (context, advSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: alertsStream,
                    builder: (context, alertSnap) {
                      if (advSnap.hasError || alertSnap.hasError)
                        return const Center(child: Text('Error loading data'));
                      if (!advSnap.hasData || !alertSnap.hasData)
                        return const Center(child: CircularProgressIndicator());

                      // Combine docs from both collections
                      List<DocumentSnapshot> allDocs = [
                        ...advSnap.data!.docs,
                        ...alertSnap.data!.docs,
                      ];

                      // ✅ Sort Descending (Newest first)
                      allDocs.sort((a, b) {
                        DateTime dateA = _getDateTime(
                          a.data() as Map<String, dynamic>,
                        );
                        DateTime dateB = _getDateTime(
                          b.data() as Map<String, dynamic>,
                        );
                        return dateB.compareTo(dateA);
                      });

                      if (allDocs.isEmpty)
                        return const Center(
                          child: Text('No active advisories or alerts.'),
                        );

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: allDocs.length,
                        itemBuilder: (context, index) {
                          final data =
                              allDocs[index].data() as Map<String, dynamic>;
                          final bool isAlertTable =
                              allDocs[index].reference.parent.id == 'alerts';

                          // 1. Set source: Admin for alerts, database source for advisories
                          final String sourceName = isAlertTable
                              ? "Admin"
                              : (data['source'] ?? 'NDMA Pakistan');
                          String displayDate = 'Recent';

                          if (isAlertTable) {
                            // If it's an alert (Timestamp), convert it to a readable date
                            if (data['createdAt'] != null &&
                                data['createdAt'] is Timestamp) {
                              DateTime dt = (data['createdAt'] as Timestamp)
                                  .toDate();
                              displayDate =
                                  "${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}";
                            }
                          } else {
                            // If it's an advisory, use your existing "date" string
                            displayDate = data['date'] ?? 'Recent';
                          }

                          // 4. Combine into subtitle
                          final String subtitle =
                              "Source: $sourceName • $displayDate";

                          return _buildAlertTile(
                            imageUrl: _getCategoryIcon(data['title'] ?? ''),
                            title: data['title'] ?? 'Safety Update',
                            subtitle: subtitle,
                            isCritical: false, // ✅ Always false as requested
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Image logic matching your title keywords
  String _getCategoryIcon(String title) {
    final t = title.toLowerCase();

    if (t.contains('rain') ||
        t.contains('thunderstorm') ||
        t.contains('monsoon')) {
      return 'assets/images/flood.png';
    } else if (t.contains('snow')) {
      return 'assets/images/snow.png';
    } else if (t.contains('heat') || t.contains('sun')) {
      return 'assets/images/heat.png';
    } else if (t.contains('fire')) {
      return 'assets/images/fire.png';
    } else if (t.contains('earthquake')) {
      return 'assets/images/earthquake.png';
    } else if (t.contains('medical')) {
      return 'assets/images/medical.png';
    }

    return 'assets/images/warning.png'; // Default fallback image
  }

  Widget _buildAlertTile({
    required String imageUrl,
    required String title,
    required String subtitle,
    required bool isCritical,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCritical
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              imageUrl,
              width: 85,
              height: 85,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 85,
                height: 85,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCritical)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      "⚠️ CRITICAL ALERT",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
