import 'package:cloud_firestore/cloud_firestore.dart';

/// Delivery statuses — the same words everywhere in the app
/// (prototype IA: Accepted → Picked up → On the way → Delivered).
enum DeliveryStatus {
  offered, // open offer, marketplace drivers can see it
  assigned, // assigned to a specific own driver
  accepted, // driver accepted
  pickedUp, // pickup code confirmed
  delivering, // on the way
  delivered, // photo proof taken
  cancelled,
}

extension DeliveryStatusLabel on DeliveryStatus {
  String get label => switch (this) {
        DeliveryStatus.offered => 'Open offer',
        DeliveryStatus.assigned => 'Assigned',
        DeliveryStatus.accepted => 'Accepted',
        DeliveryStatus.pickedUp => 'Picked up',
        DeliveryStatus.delivering => 'On the way',
        DeliveryStatus.delivered => 'Delivered',
        DeliveryStatus.cancelled => 'Cancelled',
      };
}

DeliveryStatus deliveryStatusFromString(String value) =>
    DeliveryStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => DeliveryStatus.offered,
    );

/// A delivery, matching the Firestore seed field names exactly
/// (see workspace/store-delivery-app/firebase/seed.py).
class Delivery {
  final String id;
  final String orderNumber;
  final String storeId; // store owner's Firebase uid (per security rules)
  final String storeName;
  final String? driverId; // driver uid once assigned/accepted
  final String? driverName;
  final String driverMode; // 'my-driver' | 'marketplace' | 'auto'
  // Auto (S3): my driver first, then the marketplace on decline/escalate.
  final bool autoEscalate;
  // Last decline (D3): reason the driver gave + who declined.
  final String? declineReason;
  final String? declinedBy;
  final DeliveryStatus status;
  final String pickupCode; // NEVER shown on driver screens before pickup
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  // Pin the store drops on the map (some addresses are not on the map).
  // Null when the store only typed the address.
  final double? customerLat;
  final double? customerLng;
  final String items;
  final double orderTotal;
  final double fee;
  final String currency;
  final String trackingToken;
  final DateTime? createdAt;
  final String? photoPath; // local path of the delivery photo proof
  final String? photoUrl; // Cloudinary URL once uploaded (v1: local only)
  final String? runId; // set when this delivery is one stop of a run (S7)
  final double cashCollected; // cash the driver collected at the door
  final double cashReturned; // cash the driver returned to the store
  final double tipKept; // tip stays with the driver
  final bool driverPaid; // the store paid the driver their fee in cash (S6)
  // Problem reported mid-delivery (F5): reason + who reported it.
  final String? problem;
  final String? problemBy; // 'store' | 'driver'
  final DateTime? problemAt;
  final String? problemStatus; // 'open' | 'resolved'
  // Dispute decision (A7): who pays, decided case by case by the admin.
  final String? disputeDecision; // 'store' | 'driver' | 'split' | 'wasl'
  final double? disputeAmount;
  final String? disputeNote;
  final DateTime? disputeDecidedAt;

  const Delivery({
    required this.id,
    required this.orderNumber,
    required this.storeId,
    required this.storeName,
    this.driverId,
    this.driverName,
    required this.driverMode,
    this.autoEscalate = false,
    this.declineReason,
    this.declinedBy,
    required this.status,
    required this.pickupCode,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerLat,
    this.customerLng,
    required this.items,
    required this.orderTotal,
    required this.fee,
    required this.currency,
    required this.trackingToken,
    this.createdAt,
    this.photoPath,
    this.photoUrl,
    this.runId,
    this.cashCollected = 0,
    this.cashReturned = 0,
    this.tipKept = 0,
    this.driverPaid = false,
    this.problem,
    this.problemBy,
    this.problemAt,
    this.problemStatus,
    this.disputeDecision,
    this.disputeAmount,
    this.disputeNote,
    this.disputeDecidedAt,
  });

  factory Delivery.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Delivery(
      id: doc.id,
      orderNumber: (d['orderNumber'] ?? doc.id).toString(),
      storeId: (d['storeId'] ?? '').toString(),
      storeName: (d['storeName'] ?? '').toString(),
      driverId: d['driverId'] as String?,
      driverName: d['driverName'] as String?,
      driverMode: (d['driverMode'] ?? 'marketplace').toString(),
      autoEscalate: (d['autoEscalate'] as bool?) ?? false,
      declineReason: d['declineReason'] as String?,
      declinedBy: d['declinedBy'] as String?,
      status: deliveryStatusFromString((d['status'] ?? 'offered').toString()),
      pickupCode: (d['pickupCode'] ?? '').toString(),
      customerName: (d['customerName'] ?? '').toString(),
      customerPhone: (d['customerPhone'] ?? '').toString(),
      customerAddress: (d['customerAddress'] ?? '').toString(),
      customerLat: (d['customerLat'] as num?)?.toDouble(),
      customerLng: (d['customerLng'] as num?)?.toDouble(),
      items: (d['items'] ?? '').toString(),
      orderTotal: (d['orderTotal'] as num?)?.toDouble() ?? 0,
      fee: (d['fee'] as num?)?.toDouble() ?? 0,
      currency: (d['currency'] ?? 'USD').toString(),
      trackingToken: (d['trackingToken'] ?? '').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      photoPath: d['photoPath'] as String?,
      photoUrl: d['photoUrl'] as String?,
      runId: d['runId'] as String?,
      cashCollected: (d['cashCollected'] as num?)?.toDouble() ?? 0,
      cashReturned: (d['cashReturned'] as num?)?.toDouble() ?? 0,
      tipKept: (d['tipKept'] as num?)?.toDouble() ?? 0,
      driverPaid: (d['driverPaid'] as bool?) ?? false,
      problem: d['problem'] as String?,
      problemBy: d['problemBy'] as String?,
      problemAt: (d['problemAt'] as Timestamp?)?.toDate(),
      problemStatus: d['problemStatus'] as String?,
      disputeDecision: d['disputeDecision'] as String?,
      disputeAmount: (d['disputeAmount'] as num?)?.toDouble(),
      disputeNote: d['disputeNote'] as String?,
      disputeDecidedAt: (d['disputeDecidedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Cash the driver still owes the store (collected minus returned, tip kept).
  double get cashOwed => cashCollected - cashReturned;

  String get driverModeLabel => switch (driverMode) {
        'my-driver' => 'My driver',
        'auto' => 'Auto',
        _ => 'Marketplace',
      };

  String money(double amount) => '$currency ${amount.toStringAsFixed(2)}';
}
