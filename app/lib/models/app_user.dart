import 'package:cloud_firestore/cloud_firestore.dart';

/// The signed-in user's Wasl profile (users/{uid}).
class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role; // admin | store | own-driver | marketplace-driver | customer
  final String verificationStatus; // pending | approved | rejected
  final String? verificationReason;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.verificationStatus,
    this.verificationReason,
  });

  bool get isAdmin => role == 'admin';
  bool get isStore => role == 'store';
  bool get isDriver => role == 'own-driver' || role == 'marketplace-driver';
  bool get isCustomer => role == 'customer';
  bool get isApproved => verificationStatus == 'approved';
  bool get isPending => verificationStatus == 'pending';

  factory AppUser.fromDoc(String uid, Map<String, dynamic> d) => AppUser(
        uid: uid,
        email: (d['email'] ?? '').toString(),
        name: (d['name'] ?? '').toString(),
        role: (d['role'] ?? '').toString(),
        verificationStatus: (d['verificationStatus'] ?? 'pending').toString(),
        verificationReason: d['verificationReason'] as String?,
      );

  factory AppUser.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AppUser.fromDoc(doc.id, doc.data() ?? {});
}
