import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AlertListenerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void listenHighRiskAlerts() {
    _firestore.collection('alerts').snapshots().listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.added) {
          final data = docChange.doc.data();
          if (data != null && data['riskLevel'] == 'High') {
            // Call updated NotificationService method
            NotificationService.showHighRiskNotification(
              title: data['title'] ?? 'High-Risk Alert',
              body: data['description'] ?? '',
            );
          }
        }
      }
    });
  }
}
