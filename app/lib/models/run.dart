import 'package:cloud_firestore/cloud_firestore.dart';

/// A batched multi-stop run (S7/D6/D7): 2–5 deliveries grouped by a store
/// into one offer. The driver takes the whole batch or none of it —
/// no cherry-picking stops. Each stop keeps its own pickup code, photo
/// proof and cash; the run only tracks the batch.
enum RunStatus {
  offered, // open batch offer (marketplace)
  assigned, // assigned to a specific own driver
  accepted, // driver accepted the batch
  active, // first pickup confirmed — the run is under way
  completed, // every stop delivered
  cancelled,
}

extension RunStatusLabel on RunStatus {
  String get label => switch (this) {
        RunStatus.offered => 'Open offer',
        RunStatus.assigned => 'Assigned',
        RunStatus.accepted => 'Accepted',
        RunStatus.active => 'On the run',
        RunStatus.completed => 'Completed',
        RunStatus.cancelled => 'Cancelled',
      };
}

RunStatus runStatusFromString(String value) => RunStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => RunStatus.offered,
    );

class Run {
  final String id;
  final String storeId;
  final String storeName;
  final String? driverId;
  final String? driverName;
  final String driverMode; // 'my-driver' | 'marketplace' | 'auto'
  final RunStatus status;
  final List<String> deliveryIds;
  final double totalFee; // sum of the stops' fees (batch pricing: sum for now)
  final double totalOrder; // sum of the stops' order totals
  final DateTime? createdAt;

  const Run({
    required this.id,
    required this.storeId,
    required this.storeName,
    this.driverId,
    this.driverName,
    required this.driverMode,
    required this.status,
    required this.deliveryIds,
    required this.totalFee,
    required this.totalOrder,
    this.createdAt,
  });

  factory Run.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Run(
      id: doc.id,
      storeId: (d['storeId'] ?? '').toString(),
      storeName: (d['storeName'] ?? '').toString(),
      driverId: d['driverId'] as String?,
      driverName: d['driverName'] as String?,
      driverMode: (d['driverMode'] ?? 'marketplace').toString(),
      status: runStatusFromString((d['status'] ?? 'offered').toString()),
      deliveryIds: ((d['deliveryIds'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      totalFee: (d['totalFee'] as num?)?.toDouble() ?? 0,
      totalOrder: (d['totalOrder'] as num?)?.toDouble() ?? 0,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String money(double amount, String currency) =>
      '$currency ${amount.toStringAsFixed(2)}';
}
