import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';
import 'audit_service.dart';

/// Pause a market or a zone (storm, holiday, closure): while paused,
/// no NEW orders can be created in that market — the store sees the
/// banner and the create call is refused with a plain message.
/// Unpause resumes orders at once.
///
/// Market pause is enforced where orders are created
/// (DeliveryService.createDelivery checks the store's market).
/// Zone pause is recorded and shown in the Markets screen; it does not
/// block orders by itself, because deliveries carry a market, not a
/// zone — zone-level blocking needs zones on stores, a later step.
/// Both toggles are admin-only and audit-logged.
class MarketService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<bool> marketPausedStream(String marketId) => _db
      .collection('markets')
      .doc(marketId)
      .snapshots()
      .map((doc) => (doc.data()?['paused'] as bool?) ?? false);

  Future<Result<bool>> isMarketPaused(String marketId) => guard(() async {
        final doc = await _db.collection('markets').doc(marketId).get();
        return (doc.data()?['paused'] as bool?) ?? false;
      });

  Future<Result<void>> setMarketPaused({
    required String marketId,
    required String marketName,
    required bool paused,
    required String byName,
  }) async {
    final result = await guard(() => _db
        .collection('markets')
        .doc(marketId)
        .update({'paused': paused}));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: paused ? 'pause_market' : 'unpause_market',
      targetType: 'market',
      targetId: marketId,
      targetLabel: marketName,
      reason: byName,
    );
  }

  Future<Result<void>> setZonePaused({
    required String zoneId,
    required String zoneName,
    required bool paused,
    required String byName,
  }) async {
    final result = await guard(() =>
        _db.collection('zones').doc(zoneId).update({'paused': paused}));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: paused ? 'pause_zone' : 'unpause_zone',
      targetType: 'zone',
      targetId: zoneId,
      targetLabel: zoneName,
      reason: byName,
    );
  }
}
