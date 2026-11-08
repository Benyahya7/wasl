import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';

/// Driver records (the `drivers` collection).
/// The app never created these before 1.0.9 — only the seed docs existed,
/// so a real store's "My driver" picker was always empty. A driver creates
/// their own record after the admin approves their account (the rules only
/// allow the driver themself to create it, with verificationStatus pending);
/// the admin then approves the driver record too.
class DriverService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// My driver record, if I have one (at most one per account).
  Stream<QuerySnapshot<Map<String, dynamic>>> myDriverDocStream(String uid) =>
      _db
          .collection('drivers')
          .where('userUid', isEqualTo: uid)
          .limit(1)
          .snapshots();

  /// A store's own drivers (S4 roster + S3 picker).
  Stream<QuerySnapshot<Map<String, dynamic>>> storeDriversStream(
          String storeUid) =>
      _db
          .collection('drivers')
          .where('storeId', isEqualTo: storeUid)
          .where('type', isEqualTo: 'own-driver')
          .snapshots();

  /// Approved stores an own-driver can pick from (drivers may list stores).
  Stream<QuerySnapshot<Map<String, dynamic>>> approvedStoresStream() => _db
      .collection('stores')
      .where('verificationStatus', isEqualTo: 'approved')
      .snapshots();

  Future<Result<void>> createDriverProfile({
    required String uid,
    required String name,
    required String type,
    String? storeId,
    required String vehicle,
  }) =>
      guard(() => _db.collection('drivers').doc().set({
            'userUid': uid,
            'name': name,
            'type': type,
            'storeId': storeId,
            'vehicle': vehicle,
            'verificationStatus': 'pending',
            'rating': 0,
            'onDuty': true,
            'homeZone': '',
          }));
}
