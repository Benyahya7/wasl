import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';
import 'audit_service.dart';

/// Announcements: one message from the admin to all drivers or all
/// stores at once. They show in the app (store home / driver home),
/// newest first. No push notification — the admin's message waits in
/// the app until the driver/store opens it (push needs the Blaze paid
/// plan, not approved). Admin-only write; approved accounts read.
class Announcement {
  final String id;
  final String audience; // 'drivers' | 'stores'
  final String title;
  final String body;
  final String createdByName;
  final DateTime? createdAt;

  const Announcement({
    required this.id,
    required this.audience,
    required this.title,
    required this.body,
    required this.createdByName,
    this.createdAt,
  });

  factory Announcement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Announcement(
      id: doc.id,
      audience: (d['audience'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      body: (d['body'] ?? '').toString(),
      createdByName: (d['createdByName'] ?? '').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AnnouncementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const audiences = ['drivers', 'stores'];

  static String audienceLabel(String audience) => switch (audience) {
        'drivers' => 'All drivers',
        'stores' => 'All stores',
        _ => audience,
      };

  /// Latest announcements for one audience (stores see 'stores',
  /// drivers see 'drivers'), newest first.
  Stream<List<Announcement>> announcementsStream(String audience) => _db
      .collection('announcements')
      .where('audience', isEqualTo: audience)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((s) => s.docs.map(Announcement.fromDoc).toList());

  /// Send one announcement. Logged in the admin audit trail.
  Future<Result<void>> send({
    required String audience,
    required String title,
    required String body,
    required String byUid,
    required String byName,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      return const Err('Write a title and a message first.');
    }
    if (!audiences.contains(audience)) {
      return const Err('Pick who this goes to — drivers or stores.');
    }
    final result = await guard(() => _db.collection('announcements').add({
          'audience': audience,
          'title': trimmedTitle,
          'body': trimmedBody,
          'createdBy': byUid,
          'createdByName': byName,
          'createdAt': FieldValue.serverTimestamp(),
        }));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: 'send_announcement',
      targetType: 'announcement',
      targetId: audience,
      targetLabel: '${audienceLabel(audience)} — $trimmedTitle',
    );
  }
}
