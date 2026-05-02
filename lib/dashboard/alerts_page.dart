import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String _filter = 'All';
  bool _isNewest = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Removed AppBar for the "no-header" look.
      // Using SafeArea to ensure content is clear of status bars.
      body: SafeArea(
        child: Column(
          children: [
            _buildControlRow(),
            Expanded(child: _buildAlertList()),
          ],
        ),
      ),
    );
  }

  /// Displays Filters and Sort button in one row
  Widget _buildControlRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Admin', 'NDMA'].map((label) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: _filter == label,
                      label: Text(label),
                      onSelected: (_) => setState(() => _filter = label),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => setState(() => _isNewest = !_isNewest),
            icon: Icon(_isNewest ? Icons.sort : Icons.filter_list_off),
            tooltip: "Toggle Sort Order",
          ),
        ],
      ),
    );
  }

  Widget _buildAlertList() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _combineStreams(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator.adaptive());

        final docs = _processData(snapshot.data!);
        if (docs.isEmpty) return const Center(child: Text('No updates found.'));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) => _AlertCard(doc: docs[index]),
        );
      },
    );
  }

  // Merging streams for the list
  Stream<List<DocumentSnapshot>> _combineStreams() {
    return FirebaseFirestore.instance
        .collection('advisories')
        .snapshots()
        .asyncMap((adv) async {
          final alerts = await FirebaseFirestore.instance
              .collection('alerts')
              .get();
          return [...adv.docs, ...alerts.docs];
        });
  }

  List<DocumentSnapshot> _processData(List<DocumentSnapshot> docs) {
    var processed = docs.where((doc) {
      if (_filter == 'All') return true;
      final isAlert = doc.reference.parent.id == 'alerts';
      return _filter == 'Admin' ? isAlert : !isAlert;
    }).toList();

    processed.sort((a, b) {
      DateTime dA = _parseDate(a);
      DateTime dB = _parseDate(b);
      return _isNewest ? dB.compareTo(dA) : dA.compareTo(dB);
    });
    return processed;
  }

  DateTime _parseDate(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    if (data['createdAt'] is Timestamp)
      return (data['createdAt'] as Timestamp).toDate();
    if (data['date'] is String) {
      try {
        final p = (data['date'] as String).split('-');
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      } catch (_) {}
    }
    return DateTime(2000);
  }
}

class _AlertCard extends StatelessWidget {
  final DocumentSnapshot doc;
  const _AlertCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isAlert = doc.reference.parent.id == 'alerts';
    final theme = Theme.of(context);
    final title = data['title'] ?? 'Update';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainer, // Modern M3 background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {}, // Add navigation here
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Leading Icon ---
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getIconForTitle(title),
                  size: 26,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              
              // --- Content ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // --- Inlined Metadata ---
                    Row(
                      children: [
                        // Date
                        Icon(Icons.calendar_today_rounded, size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(data),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 16),
                        
                        // Source
                        Icon(Icons.shield_outlined, size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          isAlert ? "Admin" : (data['source'] ?? 'NDMA'),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helpers ---

  IconData _getIconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('rain') || t.contains('flood') || t.contains('monsoon')) return Icons.water_drop_outlined;
    if (t.contains('snow')) return Icons.ac_unit;
    if (t.contains('heat') || t.contains('sun')) return Icons.sunny;
    if (t.contains('fire')) return Icons.local_fire_department_outlined;
    if (t.contains('earthquake')) return Icons.crisis_alert;
    if (t.contains('medical')) return Icons.medical_services_outlined;
    return Icons.warning_amber_rounded;
  }

  String _formatDate(Map<String, dynamic> data) {
    if (data['createdAt'] is Timestamp) {
      final d = (data['createdAt'] as Timestamp).toDate();
      return "${d.day}/${d.month}";
    }
    return data['date'] ?? 'Recent';
  }
}