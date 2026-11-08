import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/pickup_code.dart';
import '../core/result.dart';
import '../models/delivery.dart';

/// Keep the public tracking mirror in step with the delivery.
/// The mirror is what the customer's tracking link reads (C1/C2) — it was
/// written once at creation and never updated, so the page showed a stale
/// status forever. Best-effort: a failed sync never fails the delivery
/// update itself. The mirror NEVER holds the pickup code or the
/// customer's phone. Who may write it (rules): the owning store, the
/// assigned driver, or the admin — so a driver syncs AFTER becoming the
/// assigned driver, and BEFORE releasing (after release they are not
/// the assigned driver any more and the write is denied).
Future<void> syncTrackingMirror(
    Delivery d, Map<String, dynamic> fields) async {
  if (d.trackingToken.isEmpty) return;
  await FirebaseFirestore.instance
      .collection('deliveries')
      .doc(d.id)
      .collection('tracking')
      .doc(d.trackingToken)
      .update(fields)
      .catchError((_) {});
}

/// All delivery reads/writes against the live Wasl backend.
/// Field names and status words match the backend seed exactly.
/// Writes respect the deployed security rules (see BACKEND.md):
/// - store creates as 'offered' (open) or 'assigned' (own driver),
///   storeId == the store owner's uid, pickupCode is a 4-char string.
/// - the assigned driver moves status; pickupCode/fee/storeId are immutable.
/// - open-offer claim + release are allowed by the rules
///   (added 2026-11-06: a driver claims an 'offered' delivery by setting
///   driverId == own uid + status 'accepted', changing nothing else).
class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Random _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _deliveries =>
      _db.collection('deliveries');

  String _trackingToken(String orderNumber) {
    const chars = 'abcdef0123456789';
    final suffix =
        List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
    return 'trk-$orderNumber-$suffix';
  }

  /// Store creates a delivery. Generates the pickup code server-side-style
  /// (in-app until the Blaze intake function exists) and the public
  /// tracking mirror in a SECOND write after the delivery exists — the
  /// tracking rule reads the delivery to check storeId, and a batch
  /// cannot see the delivery it creates in the same commit, which made
  /// every create fail PERMISSION_DENIED (2026-11-07).
  Future<Result<Delivery>> createDelivery({
    required String storeUid,
    required String storeName,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String items,
    required double orderTotal,
    required double fee,
    String currency = 'USD',
    String? driverId,
    String? driverName,
    String driverMode = 'marketplace',
    bool autoEscalate = false,
    double? customerLat,
    double? customerLng,
  }) =>
      guard(() async {
        // Market pause: while the admin has paused the store's market,
        // no NEW orders can be created there (storm / holiday / closure).
        // The store record carries the market id; a missing record (old
        // store, not set up yet) never blocks — the check is skipped.
        final storeSnap = await _db
            .collection('stores')
            .where('ownerUid', isEqualTo: storeUid)
            .limit(1)
            .get();
        if (storeSnap.docs.isNotEmpty) {
          final marketId =
              (storeSnap.docs.first.data()['market'] ?? '').toString();
          if (marketId.isNotEmpty) {
            final marketDoc =
                await _db.collection('markets').doc(marketId).get();
            if ((marketDoc.data()?['paused'] as bool?) == true) {
              final marketName =
                  (marketDoc.data()?['name'] ?? marketId).toString();
              throw Exception(
                  'New orders are paused in $marketName right now — the admin paused this market. Try again later.');
            }
          }
        }
        final orderNumber =
            (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
        final docRef = _deliveries.doc();
        final pickupCode = PickupCode.generate();
        final trackingToken = _trackingToken(orderNumber);
        final isAssigned = driverId != null;
        final data = <String, dynamic>{
          'orderNumber': orderNumber,
          'storeId': storeUid,
          'storeName': storeName,
          'driverId': driverId,
          'driverName': driverName,
          'driverMode': driverMode,
          'autoEscalate': autoEscalate,
          'status': isAssigned ? 'assigned' : 'offered',
          'pickupCode': pickupCode,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'customerAddress': customerAddress,
          'customerLat': customerLat,
          'customerLng': customerLng,
          'items': items,
          'orderTotal': orderTotal,
          'fee': fee,
          'currency': currency,
          'trackingToken': trackingToken,
          'createdAt': FieldValue.serverTimestamp(),
          'cashCollected': 0,
          'cashReturned': 0,
          'tipKept': 0,
        };
        // Write the delivery FIRST, then the tracking mirror: the mirror's
        // rule reads the delivery to verify storeId, so it must exist.
        // The mirror holds only what the customer may see (C1/C2) — never
        // the pickup code or the customer's phone.
        await docRef.set(data);
        await docRef.collection('tracking').doc(trackingToken).set({
          'status': data['status'],
          'storeName': storeName,
          'driverName': driverName,
          'items': items,
          'orderTotal': orderTotal,
          'currency': currency,
          'customerArea': customerAddress,
          'customerLat': customerLat,
          'customerLng': customerLng,
        });
        final snap = await docRef.get();
        return Delivery.fromDoc(snap);
      });

  Stream<List<Delivery>> storeDeliveriesStream(String storeUid) => _deliveries
      .where('storeId', isEqualTo: storeUid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Delivery.fromDoc).toList());

  /// Driver job board: open offers + deliveries assigned to me.
  /// Stops of a run never appear here as single jobs — the run itself
  /// is the offer (D6). A stop stays visible to the driver on it.
  Stream<List<Delivery>> driverBoardStream(String driverUid) => _deliveries
      .where('status', whereIn: ['offered', 'assigned'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs
          .map(Delivery.fromDoc)
          .where((d) =>
              (d.status == DeliveryStatus.offered ||
                      d.driverId == driverUid) &&
                  (d.runId == null || d.driverId == driverUid))
          .toList());

  /// My active + past deliveries as a driver.
  Stream<List<Delivery>> myDeliveriesStream(String driverUid) => _deliveries
      .where('driverId', isEqualTo: driverUid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Delivery.fromDoc).toList());

  Stream<Delivery?> deliveryStream(String id) => _deliveries
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? Delivery.fromDoc(doc) : null);

  /// Marketplace driver claims an open offer.
  Future<Result<void>> claimOffer(Delivery d, String uid, String name) =>
      guard(() async {
        await _deliveries.doc(d.id).update({
          'driverId': uid,
          'driverName': name,
          'status': 'accepted',
        });
        await syncTrackingMirror(d, {
          'status': 'accepted',
          'driverName': name,
        });
      });

  /// Own driver accepts an assignment.
  Future<Result<void>> acceptAssignment(Delivery d) =>
      guard(() async {
        await _deliveries.doc(d.id).update({'status': 'accepted'});
        await syncTrackingMirror(d, {'status': 'accepted'});
      });

  /// Assigned driver releases the delivery back to open offers.
  /// With a reason (D3): the reason is saved FIRST while the driver is
  /// still assigned (the release clause only allows driverId/driverName/
  /// status to change in that second update, so the reason cannot ride
  /// along with it — two updates, both allowed by the rules as written).
  /// The mirror is synced BEFORE the release too — after it, the driver
  /// is no longer the assigned driver and the mirror write is denied.
  Future<Result<void>> releaseDelivery(Delivery d,
      {String? reason, String? declinedBy}) async {
    if (reason != null) {
      final saved = await guard(() => _deliveries.doc(d.id).update({
            'declineReason': reason,
            'declinedBy': declinedBy,
          }));
      if (saved is Err) return saved;
    }
    await syncTrackingMirror(d, {
      'status': 'offered',
      'driverName': null,
    });
    return guard(() => _deliveries.doc(d.id).update({
          'driverId': null,
          'driverName': null,
          'status': 'offered',
        }));
  }

  /// Store escalates an assigned Auto delivery to the marketplace
  /// (S3/S5): the owning store may clear the driver (the store update
  /// clause only forbids pickupCode/fee/storeId).
  Future<Result<void>> escalateToMarketplace(Delivery d) =>
      guard(() async {
        await _deliveries.doc(d.id).update({
          'driverId': null,
          'driverName': null,
          'status': 'offered',
        });
        await syncTrackingMirror(d, {
          'status': 'offered',
          'driverName': null,
        });
      });

  /// Confirm pickup with the 4-character code from the order label.
  /// The code is checked in-app and is NEVER displayed on driver screens.
  /// Server-side code validation needs the Blaze Cloud Function (pending);
  /// until then the rules still protect the code from being changed.
  Future<Result<void>> confirmPickup(Delivery d, String typedCode) async {
    if (!PickupCode.isValidFormat(typedCode.trim())) {
      return const Err(
          'That code is not 4 letters and numbers — check the order label.');
    }
    if (!PickupCode.matches(typedCode, d.pickupCode)) {
      return const Err(
          'Wrong code — check the label on the order and try again.');
    }
    return guard(() async {
      await _deliveries.doc(d.id).update({
        'status': 'pickedUp',
      });
      await syncTrackingMirror(d, {'status': 'pickedUp'});
    });
  }

  Future<Result<void>> startDelivering(Delivery d) =>
      guard(() async {
        await _deliveries.doc(d.id).update({'status': 'delivering'});
        await syncTrackingMirror(d, {'status': 'delivering'});
      });

  /// Delivered: photo proof + cash collected at the door + tip kept.
  Future<Result<void>> markDelivered(
    Delivery d, {
    required String photoPath,
    String? photoUrl,
    required double cashCollected,
    required double tipKept,
  }) =>
      guard(() async {
        await _deliveries.doc(d.id).update({
          'status': 'delivered',
          'photoPath': photoPath,
          if (photoUrl != null) 'photoUrl': photoUrl,
          'cashCollected': cashCollected,
          'tipKept': tipKept,
        });
        await syncTrackingMirror(d, {
          'status': 'delivered',
          if (photoUrl != null) 'photoUrl': photoUrl,
          'deliveredAt': FieldValue.serverTimestamp(),
        });
      });

  /// Store marks the driver paid in cash (S6): the cash is back at the
  /// store and the driver got their fee. Only the owning store.
  Future<Result<void>> markDriverPaid(Delivery d) =>
      guard(() => _deliveries.doc(d.id).update({'driverPaid': true}));

  /// Store or driver reports a problem mid-delivery (F5): the reason is
  /// written on the delivery itself (not the audit trail — stores and
  /// drivers cannot write admin_actions). The admin sees the open
  /// problem on the delivery and resolves it.
  Future<Result<void>> reportProblem(
    Delivery d, {
    required String problem,
    required String reportedBy, // 'store' | 'driver'
  }) =>
      guard(() => _deliveries.doc(d.id).update({
            'problem': problem,
            'problemBy': reportedBy,
            'problemAt': FieldValue.serverTimestamp(),
            'problemStatus': 'open',
          }));

  /// Driver returns ALL cash to the store (keeps the tip).
  Future<Result<void>> markCashReturned(Delivery d) =>
      guard(() => _deliveries.doc(d.id).update({
            'cashReturned': d.cashCollected,
          }));

  /// Store cancels a delivery that has not been picked up yet.
  Future<Result<void>> cancelDelivery(Delivery d) =>
      guard(() async {
        await _deliveries.doc(d.id).update({'status': 'cancelled'});
        await syncTrackingMirror(d, {'status': 'cancelled'});
      });
}
