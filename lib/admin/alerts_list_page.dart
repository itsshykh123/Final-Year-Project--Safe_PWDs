import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'create_alert_page.dart';

class AlertsListPage extends StatelessWidget {
  const AlertsListPage({Key? key}) : super(key: key);

  // Helper for Severity Styling
  Color _getSeverityColor(String? level) {
    switch (level) {
      case "Low": return Colors.green;
      case "Medium": return Colors.orange;
      case "High": return Colors.red;
      case "Critical": return Colors.purple;
      default: return Colors.blueAccent;
    }
  }

  // ✅ Toggle Status directly from the list
  Future<void> _toggleStatus(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('alerts')
        .doc(docId)
        .update({'isActive': !currentStatus});
  }

  // ✅ Professional Confirmation Dialog for Deletion
  Future<void> _confirmDelete(BuildContext context, String docId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("Confirm Delete"),
          ],
        ),
        content: const Text("Are you sure you want to delete this alert? This action is permanent and cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('alerts').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Alert Control Center", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No alerts found.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bool isActive = data['isActive'] ?? true;
              final color = _getSeverityColor(data['severity']);
              
              String date = "Recently";
              if (data['createdAt'] != null) {
                date = DateFormat('MMM d, h:mm a').format((data['createdAt'] as Timestamp).toDate());
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Severity Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (data['severity'] ?? 'Medium').toUpperCase(),
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                              // ✅ Quick Toggle Switch
                              Row(
                                children: [
                                  Text(isActive ? "ACTIVE" : "INACTIVE", 
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? Colors.green : Colors.grey)),
                                  const SizedBox(width: 4),
                                  Transform.scale(
                                    scale: 0.8,
                                    child: Switch(
                                      value: isActive,
                                      activeColor: Colors.green,
                                      onChanged: (val) => _toggleStatus(doc.id, isActive),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text(data['description'] ?? '', 
                              maxLines: 2, overflow: TextOverflow.ellipsis, 
                              style: const TextStyle(color: Colors.black54, fontSize: 14)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text(data['location'] ?? 'N/A', style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                              const Spacer(),
                              Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Action Buttons Footer
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateAlertPage(editDoc: doc))),
                              icon: const Icon(Icons.edit_note, size: 20),
                              label: const Text("Edit Details"),
                            ),
                          ),
                          Container(width: 1, height: 20, color: Colors.black12),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _confirmDelete(context, doc.id),
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              label: const Text("Delete", style: TextStyle(color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}