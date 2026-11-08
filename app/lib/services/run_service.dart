import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';
import '../models/delivery.dart';
import '../models/run.dart';
import 'delivery_service.dart';

/// Batched multi-stop runs (S7/D6/D7).
/// A run is one offer for 2–5 stops: the driver takes the whole batch or
/// none of it. Each stop stays its own delivery (own pickup code, photo,
/// cash); the run only groups them and tracks the batch.
class RunService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _runs =>
      _db.collection('runs');
  CollectionReference<Map<String, dynamic>> get _deliveries =>
      _db.collection('deliveries');

  /// Store builds a run from 2–5 of their open offers. The stops get
  /// runId so they stop appearing as single jobs on the board.
  Future<Result<Run>> createRun({
    required String storeUid,
    required String storeName,
    required List<Delivery> stops,
    required String driverMode,
    String? driverId,
    String? driverName,
  }) =>
      guard(() async {
        if (stops.length < 2 || stops.length > 5) {
          throw Exception('A run has 2 to 5 stops.');
        }
        final docRef = _runs.doc();
        final totalFee =
            stops.fold<double>(0, (s, d) => s + d.fee);
        final totalOrder =
            stops.fold<double>(0, (s, d) => s + d.orderTotal);
        final data = <String, dynamic>{
          'storeId': storeUid,
          'storeName': storeName,
          'driverId': driverId,
          'driverName': driverName,
          'driverMode': driverMode,
          'status': driverId != null ? 'assigned' : 'offered',
          'deliveryIds': stops.map((d) => d.id).toList(),
          'totalFee': totalFee,
          'totalOrder': totalOrder,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await docRef.set(data);
        for (final stop in stops) {
          await _deliveries.doc(stop.id).update({'runId': docRef.id});
        }
        final snap = await docRef.get();
        return Run.fromDoc(snap);
      });

  Stream<Run?> runStream(String id) => _runs.doc(id).snapshots().map(
      (doc) => doc.exists ? Run.fromDoc(doc) : null);

  /// Stops of a run, in the run's order.
  Stream<List<Delivery>> runStopsStream(Run run) {
    if (run.deliveryIds.isEmpty) {
      return Stream.value(const []);
    }
    return _deliveries
        .where(FieldPath.documentId, whereIn: run.deliveryIds)
        .snapshots()
        .map((s) {
          final byId = {for (final d in s.docs) d.id: Delivery.fromDoc(d)};
          return run.deliveryIds
              .map((id) => byId[id])
              .whereType<Delivery>()
              .toList();
        });
  }

  /// Driver board: open batch offers + batches assigned to me.
  Stream<List<Run>> driverRunsStream(String driverUid) => _runs
      .where('status', whereIn: ['offered', 'assigned'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map(Run.fromDoc)
          .where((r) =>
              r.status == RunStatus.offered || r.driverId == driverUid)
          .toList());

  /// Store's runs (latest first).
  Stream<List<Run>> storeRunsStream(String storeUid) => _runs
      .where('storeId', isEqualTo: storeUid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Run.fromDoc).toList());

  /// Marketplace driver claims a whole batch: claim each stop first
  /// (the delivery claim clause), then the run itself. If a stop fails,
  /// the run is untouched and the error names the stop.
  Future<Result<void>> claimRun(Run run, String uid, String name) =>
      guard(() async {
        for (final id in run.deliveryIds) {
          final stop = await _deliveries.doc(id).get();
          if (!stop.exists) {
            throw Exception('A stop of this run is gone.');
          }
          final data = stop.data() ?? {};
          if ((data['status'] ?? '') != 'offered') {
            throw Exception(
                'Stop #${data['orderNumber'] ?? ''} was already taken.');
          }
          await _deliveries.doc(id).update({
            'driverId': uid,
            'driverName': name,
            'status': 'accepted',
          });
          await syncTrackingMirror(Delivery.fromDoc(stop), {
            'status': 'accepted',
            'driverName': name,
          });
        }
        await _runs.doc(run.id).update({
          'driverId': uid,
          'driverName': name,
          'status': 'accepted',
        });
      });

  /// Own driver accepts an assigned batch.
  Future<Result<void>> acceptRun(Run run) =>
      guard(() => _runs.doc(run.id).update({'status': 'accepted'}));

  /// Assigned driver declines the whole batch: the stops go back to
  /// single open offers and the run is cancelled (a batch is all or
  /// nothing — it cannot half-exist). Two updates per stop: clearing
  /// runId first (general clause), then the release (release clause
  /// only allows driverId/driverName/status to change). The mirror is
  /// synced BEFORE the release — after it the driver is no longer the
  /// assigned driver and the mirror write is denied.
  Future<Result<void>> releaseRun(Run run) => guard(() async {
        for (final id in run.deliveryIds) {
          final stop = await _deliveries.doc(id).get();
          if (stop.exists) {
            await syncTrackingMirror(Delivery.fromDoc(stop), {
              'status': 'offered',
              'driverName': null,
            });
          }
          await _deliveries.doc(id).update({'runId': FieldValue.delete()});
          await _deliveries.doc(id).update({
            'driverId': null,
            'driverName': null,
            'status': 'offered',
          });
        }
        await _runs.doc(run.id).update({'status': 'cancelled'});
      });

  /// Store cancels a run that has not started: the stops go back to
  /// single open offers and the run is cancelled.
  Future<Result<void>> cancelRun(Run run) => guard(() async {
        for (final id in run.deliveryIds) {
          await _deliveries.doc(id).update({
            'runId': FieldValue.delete(),
            'driverId': null,
            'driverName': null,
            'status': 'offered',
          });
          final stop = await _deliveries.doc(id).get();
          if (stop.exists) {
            await syncTrackingMirror(Delivery.fromDoc(stop), {
              'status': 'offered',
              'driverName': null,
            });
          }
        }
        await _runs.doc(run.id).update({'status': 'cancelled'});
      });

  /// The run goes active on the first pickup of any stop.
  Future<Result<void>> markRunActive(String runId) =>
      guard(() => _runs.doc(runId).update({'status': 'active'}));

  /// After a stop is delivered: if every stop is delivered, the run
  /// is completed. No-op otherwise.
  Future<Result<void>> maybeCompleteRun(String runId) =>
      guard(() async {
        final runDoc = await _runs.doc(runId).get();
        if (!runDoc.exists) return;
        final run = Run.fromDoc(runDoc);
        var allDelivered = true;
        for (final id in run.deliveryIds) {
          final stop = await _deliveries.doc(id).get();
          if ((stop.data()?['status'] ?? '') != 'delivered') {
            allDelivered = false;
            break;
          }
        }
        if (allDelivered) {
          await _runs.doc(runId).update({'status': 'completed'});
        }
      });
}
