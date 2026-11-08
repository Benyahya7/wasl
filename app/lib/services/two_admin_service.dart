import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';
import 'audit_service.dart';

/// Two-admin approval: big actions (removing a store/driver account,
/// changing fees) do NOT take effect at once. The first admin REQUESTS,
/// a DIFFERENT admin approves or rejects, and only the approval runs
/// the action. The requesting admin can never approve their own request
/// (enforced in the rules too).
///
/// Honest limit: this is a process control in the app, not a server
/// rule — a determined client could still write the underlying doc
/// directly, because the admin role already has those writes. True
/// server-side two-person control needs a Cloud Function (Blaze paid
/// plan, not approved). What this does guarantee: every big action in
/// the app UI goes through a second pair of eyes, and both the request
/// and the decision are in the audit trail.
class TwoAdminRequest {
  final String id;
  final String type; // 'remove_account' | 'change_fees'
  final String targetType;
  final String targetId;
  final String targetLabel;
  final Map<String, dynamic> payload;
  final String requestedBy;
  final String requestedByName;
  final String status; // pending | approved | rejected
  final DateTime? createdAt;
  final String? decidedBy;
  final String? reason;

  const TwoAdminRequest({
    required this.id,
    required this.type,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.payload,
    required this.requestedBy,
    required this.requestedByName,
    required this.status,
    this.createdAt,
    this.decidedBy,
    this.reason,
  });

  factory TwoAdminRequest.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TwoAdminRequest(
      id: doc.id,
      type: (d['type'] ?? '').toString(),
      targetType: (d['targetType'] ?? '').toString(),
      targetId: (d['targetId'] ?? '').toString(),
      targetLabel: (d['targetLabel'] ?? '').toString(),
      payload: Map<String, dynamic>.from((d['payload'] as Map?) ?? {}),
      requestedBy: (d['requestedBy'] ?? '').toString(),
      requestedByName: (d['requestedByName'] ?? '').toString(),
      status: (d['status'] ?? '').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      decidedBy: d['decidedBy'] as String?,
      reason: d['reason'] as String?,
    );
  }

  String get typeLabel => switch (type) {
        'remove_account' => 'Remove account',
        'change_fees' => 'Change fees',
        _ => type,
      };
}

class TwoAdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<TwoAdminRequest>> pendingRequestsStream() => _db
      .collection('admin_approvals')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(TwoAdminRequest.fromDoc).toList());

  /// File a request. Nothing takes effect yet — the UI must say so.
  Future<Result<void>> request({
    required String type,
    required String targetType,
    required String targetId,
    required String targetLabel,
    required Map<String, dynamic> payload,
    required String requestedBy,
    required String requestedByName,
  }) async {
    final result = await guard(() =>
        _db.collection('admin_approvals').add({
          'type': type,
          'targetType': targetType,
          'targetId': targetId,
          'targetLabel': targetLabel,
          'payload': payload,
          'requestedBy': requestedBy,
          'requestedByName': requestedByName,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        }));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: 'request_two_admin',
      targetType: targetType,
      targetId: targetId,
      targetLabel: '$targetLabel — needs a second admin',
      reason: requestedByName,
    );
  }

  /// Approve as a DIFFERENT admin: runs the requested action first,
  /// then marks the request approved. If the action fails, the request
  /// stays pending and the error is shown — never half-applied.
  Future<Result<void>> approve({
    required TwoAdminRequest request,
    required String approverUid,
    required String approverName,
  }) async {
    if (request.requestedBy == approverUid) {
      return const Err(
          'You requested this — a different admin has to approve it.');
    }
    final applied = await _apply(request);
    var ok = false;
    applied.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return applied;
    final marked = await guard(() => _db
        .collection('admin_approvals')
        .doc(request.id)
        .update({
          'status': 'approved',
          'decidedBy': approverUid,
          'decidedAt': FieldValue.serverTimestamp(),
        }));
    var markedOk = false;
    marked.fold((_) {
      markedOk = true;
    }, (_) {});
    if (!markedOk) return marked;
    return AuditService.log(
      action: 'approve_two_admin',
      targetType: request.targetType,
      targetId: request.targetId,
      targetLabel: '${request.typeLabel} — ${request.targetLabel}',
      reason: 'Requested by ${request.requestedByName}, approved by $approverName',
    );
  }

  Future<Result<void>> reject({
    required TwoAdminRequest request,
    required String approverUid,
    required String approverName,
    required String reason,
  }) async {
    if (request.requestedBy == approverUid) {
      return const Err(
          'You requested this — a different admin has to decide it.');
    }
    final marked = await guard(() => _db
        .collection('admin_approvals')
        .doc(request.id)
        .update({
          'status': 'rejected',
          'decidedBy': approverUid,
          'decidedAt': FieldValue.serverTimestamp(),
          'reason': reason,
        }));
    var ok = false;
    marked.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return marked;
    return AuditService.log(
      action: 'reject_two_admin',
      targetType: request.targetType,
      targetId: request.targetId,
      targetLabel: '${request.typeLabel} — ${request.targetLabel}',
      reason: 'Requested by ${request.requestedByName}, rejected by $approverName: $reason',
    );
  }

  /// Run the requested action. 'remove_account' deletes the store/driver
  /// record(s) and revokes the user (the users doc itself is never
  /// deleted — rules forbid it, the record stays as a trail).
  /// 'change_fees' writes the new fee values on the store/market doc.
  /// Each applied action also writes its own audit record, so the trail
  /// reads the same as a direct admin action.
  Future<Result<void>> _apply(TwoAdminRequest request) async {
    final result = await guard(() async {
      if (request.type == 'remove_account') {
        final uid = (request.payload['uid'] ?? '').toString();
        final role = (request.payload['role'] ?? '').toString();
        if (role == 'store') {
          final stores = await _db
              .collection('stores')
              .where('ownerUid', isEqualTo: uid)
              .get();
          for (final doc in stores.docs) {
            await doc.reference.delete();
          }
        } else if (role == 'own-driver' || role == 'marketplace-driver') {
          final drivers = await _db
              .collection('drivers')
              .where('userUid', isEqualTo: uid)
              .get();
          for (final doc in drivers.docs) {
            await doc.reference.delete();
          }
        }
        await _db.collection('users').doc(uid).update({
          'verificationStatus': 'rejected',
          'verificationReason': 'Removed by admin',
        });
        return;
      }
      if (request.type == 'change_fees') {
        final collection = (request.payload['collection'] ?? '').toString();
        final fees = Map<String, dynamic>.from(
            (request.payload['fees'] as Map?) ?? {});
        if (collection != 'stores' && collection != 'markets') {
          throw Exception('Unknown fee target.');
        }
        await _db
            .collection(collection)
            .doc(request.targetId)
            .update(fees);
        return;
      }
      throw Exception('Unknown two-admin action: ${request.type}');
    });
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: request.type == 'remove_account'
          ? (request.payload['role'] == 'store'
              ? 'remove_store'
              : 'remove_driver')
          : 'set_fees',
      targetType: request.targetType,
      targetId: request.targetId,
      targetLabel: request.targetLabel,
      reason: 'Two-admin approved (requested by ${request.requestedByName})',
    );
  }
}
