import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/result.dart';
import 'audit_service.dart';

/// Admin-only writes (A7): dispute decisions, problem resolution and
/// manual payout settlement. Every one writes its audit record; a failed
/// audit returns Err so the admin sees it — never silent, never unlogged.
class AdminService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const disputeOptions = ['store', 'driver', 'split', 'wasl'];

  static String disputeLabel(String decision) => switch (decision) {
        'store' => 'Store pays',
        'driver' => 'Driver pays',
        'split' => 'Split 50-50',
        'wasl' => 'Wasl covers',
        _ => decision,
      };

  /// Decide a dispute case by case: who pays the disputed amount.
  /// No fixed split is invented — the admin picks per case.
  static Future<Result<void>> decideDispute({
    required String deliveryId,
    required String orderLabel,
    required String decision,
    required double amount,
    required String note,
  }) async {
    final result = await guard(() =>
        _db.collection('deliveries').doc(deliveryId).update({
          'disputeDecision': decision,
          'disputeAmount': amount,
          'disputeNote': note,
          'disputeDecidedBy': _uid,
          'disputeDecidedAt': FieldValue.serverTimestamp(),
        }));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: 'decide_dispute',
      targetType: 'delivery',
      targetId: deliveryId,
      targetLabel:
          '$orderLabel — ${disputeLabel(decision)} ${amount.toStringAsFixed(2)}',
      reason: note.isEmpty ? null : note,
    );
  }

  /// Mark an open problem resolved.
  static Future<Result<void>> resolveProblem({
    required String deliveryId,
    required String orderLabel,
  }) async {
    final result = await guard(() =>
        _db.collection('deliveries').doc(deliveryId).update({
          'problemStatus': 'resolved',
        }));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: 'resolve_problem',
      targetType: 'delivery',
      targetId: deliveryId,
      targetLabel: orderLabel,
    );
  }

  /// Manual payout settlement: records that the admin settled the
  /// store's Wasl fees for `amount`. A7 subtracts settled payouts from
  /// the live fees-owed total, so the books stay true.
  static Future<Result<void>> settlePayout({
    required String storeId,
    required String storeName,
    required double amount,
    required String note,
  }) async {
    final result = await guard(() => _db.collection('payouts').add({
          'storeId': storeId,
          'storeName': storeName,
          'amount': amount,
          'status': 'settled',
          'settledAt': FieldValue.serverTimestamp(),
          'settledBy': _uid,
          'note': note,
        }));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: 'settle_payout',
      targetType: 'store',
      targetId: storeId,
      targetLabel: '$storeName — settled ${amount.toStringAsFixed(2)}',
      reason: note.isEmpty ? null : note,
    );
  }
}
