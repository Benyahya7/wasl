import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/result.dart';

/// Admin audit trail: one doc per admin action in `admin_actions`.
/// The acting admin is always the signed-in user, resolved here so no
/// screen has to thread the admin profile through. A failed log write
/// returns Err — callers surface it, so an admin action is never logged
/// silently or left unlogged without the admin seeing the error.
class AuditService {
  static Future<Result<void>> log({
    required String action,
    required String targetType,
    required String targetId,
    required String targetLabel,
    String? reason,
  }) =>
      guard(() async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Not signed in.');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final d = doc.data() ?? {};
        await FirebaseFirestore.instance.collection('admin_actions').add({
          'adminUid': user.uid,
          'adminEmail': (d['email'] ?? user.email ?? '').toString(),
          'adminName': (d['name'] ?? '').toString(),
          'action': action,
          'targetType': targetType,
          'targetId': targetId,
          'targetLabel': targetLabel,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

  /// Human label for an action code, for the activity screen.
  static String labelFor(String action) {
    return switch (action) {
      'approve_user' => 'Approved account',
      'reject_user' => 'Rejected account',
      'approve_store' => 'Approved store profile',
      'reject_store' => 'Rejected store profile',
      'approve_driver' => 'Approved driver profile',
      'reject_driver' => 'Rejected driver profile',
      'block_account' => 'Blocked account',
      'unblock_account' => 'Unblocked account',
      'revoke_account' => 'Revoked account',
      'remove_store' => 'Removed store',
      'remove_driver' => 'Removed driver',
      'reassign_delivery' => 'Reassigned delivery',
      'delete_delivery' => 'Deleted delivery',
      'set_fees' => 'Set store fees',
      'set_payment_methods' => 'Changed payment methods',
      'grant_admin' => 'Granted admin',
      'revoke_admin' => 'Revoked admin',
      'set_role' => 'Changed role',
      'decide_dispute' => 'Decided a dispute',
      'resolve_problem' => 'Resolved a problem',
      'settle_payout' => 'Marked payout settled',
      _ => action,
    };
  }

  /// Which filter bucket an action belongs to (client-side filtering).
  static String bucketFor(String action) {
    if (action.startsWith('approve_') || action.startsWith('reject_')) {
      return 'Approvals';
    }
    if (action.startsWith('block_') ||
        action.startsWith('unblock_') ||
        action == 'revoke_account') {
      return 'Blocks';
    }
    if (action == 'delete_delivery' ||
        action == 'remove_store' ||
        action == 'remove_driver') {
      return 'Deletes';
    }
    if (action == 'set_fees' ||
        action == 'set_payment_methods' ||
        action == 'settle_payout') {
      return 'Fees';
    }
    if (action == 'grant_admin' ||
        action == 'revoke_admin' ||
        action == 'set_role') {
      return 'Admins';
    }
    return 'Other';
  }
}
