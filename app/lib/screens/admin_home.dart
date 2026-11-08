import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../core/result.dart';
import '../models/app_user.dart';
import '../models/delivery.dart';
import '../services/admin_service.dart';
import '../services/audit_service.dart';
import '../services/auth_service.dart';
import '../services/market_service.dart';
import '../services/two_admin_service.dart';
import '../theme.dart';
import '../widgets/ofm_map_layer.dart';
import 'admin_activity_screen.dart';
import 'admins_screen.dart';
import 'announcements_screen.dart';
import 'chat_screen.dart';
import 'direct_inbox_screen.dart';
import 'photo_cleanup_screen.dart';

/// Delete a delivery (admin). Shared by the deliveries list and the A6 live map.
Future<void> adminDeleteDelivery(
  BuildContext context,
  String id,
  String orderNumber,
  void Function(String) onError,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete delivery #$orderNumber?'),
      content: const Text(
        'This removes the delivery and its tracking link. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  final result = await guard(() async {
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('deliveries').doc(id);
    final tracking = await docRef.collection('tracking').get();
    for (final doc in tracking.docs) {
      await doc.reference.delete();
    }
    await docRef.delete();
  });
  var ok = false;
  result.fold((_) {
    ok = true;
  }, (m) => onError(m));
  if (!ok) return;
  final logged = await AuditService.log(
    action: 'delete_delivery',
    targetType: 'delivery',
    targetId: id,
    targetLabel: '#$orderNumber',
  );
  logged.fold((_) {}, onError);
}

/// Reassign a delivery to another approved driver (admin). Shared by the deliveries list and the A6 live map.
Future<void> adminReassignDelivery(
  BuildContext context,
  String id,
  String orderNumber,
  void Function(String) onError,
) async {
  final db = FirebaseFirestore.instance;
  final driversSnap = await db
      .collection('users')
      .where('verificationStatus', isEqualTo: 'approved')
      .where('role', whereIn: ['own-driver', 'marketplace-driver'])
      .get();
  if (!context.mounted) return;
  final drivers = driversSnap.docs;
  if (drivers.isEmpty) {
    onError('No approved drivers to reassign to.');
    return;
  }
  final picked = await showDialog<DocumentSnapshot<Map<String, dynamic>>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reassign #$orderNumber'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: drivers.map((doc) {
            final d = doc.data();
            return ListTile(
              title: Text('${d['name'] ?? ''}'),
              subtitle: Text('${d['role'] ?? ''}'),
              onTap: () => Navigator.pop(context, doc),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (picked == null) return;
  final pickedData = picked.data();
  if (pickedData == null) {
    onError('That driver record is gone — pick another.');
    return;
  }
  final result = await guard(
    () => db.collection('deliveries').doc(id).update({
      'driverId': picked.id,
      'driverName': pickedData['name'],
      'status': 'assigned',
    }),
  );
  var ok = false;
  result.fold((_) {
    ok = true;
  }, (m) => onError(m));
  if (!ok) return;
  final logged = await AuditService.log(
    action: 'reassign_delivery',
    targetType: 'delivery',
    targetId: id,
    targetLabel: '#$orderNumber → ${pickedData['name'] ?? ''}',
  );
  logged.fold((_) {}, onError);
}

/// Block an account (admin): the user record and the store/driver profile
/// both go to rejected with the reason shown. The profile record stays —
/// blocking is reversible, unlike Remove (which deletes the record).
/// Shared by the A4 store detail and A5 driver detail screens.
Future<void> adminBlockAccount(
  BuildContext context,
  String userUid,
  String profileCollection,
  String profileDocId,
  String label,
  void Function(String) onError,
) async {
  final db = FirebaseFirestore.instance;
  final result = await guard(() async {
    await db.collection('users').doc(userUid).update({
      'verificationStatus': 'rejected',
      'verificationReason': 'Blocked by admin',
    });
    await db.collection(profileCollection).doc(profileDocId).update({
      'verificationStatus': 'rejected',
      'verificationReason': 'Blocked by admin',
    });
  });
  var ok = false;
  result.fold((_) {
    ok = true;
  }, onError);
  if (!ok) return;
  final logged = await AuditService.log(
    action: 'block_account',
    targetType: 'user',
    targetId: userUid,
    targetLabel: label,
  );
  logged.fold((_) {}, onError);
}

/// Unblock an account (admin): user record + profile back to approved.
Future<void> adminUnblockAccount(
  BuildContext context,
  String userUid,
  String profileCollection,
  String profileDocId,
  String label,
  void Function(String) onError,
) async {
  final db = FirebaseFirestore.instance;
  final result = await guard(() async {
    await db.collection('users').doc(userUid).update({
      'verificationStatus': 'approved',
      'verificationReason': FieldValue.delete(),
    });
    await db.collection(profileCollection).doc(profileDocId).update({
      'verificationStatus': 'approved',
      'verificationReason': FieldValue.delete(),
    });
  });
  var ok = false;
  result.fold((_) {
    ok = true;
  }, onError);
  if (!ok) return;
  final logged = await AuditService.log(
    action: 'unblock_account',
    targetType: 'user',
    targetId: userUid,
    targetLabel: label,
  );
  logged.fold((_) {}, onError);
}

/// Admin dashboard numbers at a glance (Home tab): today's deliveries,
/// cash still owed across all stores, open problems, accounts waiting
/// for approval. Each number is a live stream; a failed stream shows
/// its error in place instead of a wrong number. Cash owed is computed
/// live from delivered orders (collected minus returned) — the settled
/// ledger view stays in Payouts.
class AdminDashboardCard extends StatelessWidget {
  const AdminDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return Card(
      color: WaslTheme.teal.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today at a glance",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db
                        .collection('deliveries')
                        .where('createdAt',
                            isGreaterThanOrEqualTo:
                                Timestamp.fromDate(startOfToday))
                        .snapshots(),
                    builder: (context, snapshot) => _DashboardNumber(
                      label: "Today's deliveries",
                      value: snapshot.hasError
                          ? '!'
                          : snapshot.hasData
                              ? '${snapshot.data!.docs.length}'
                              : '…',
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db
                        .collection('deliveries')
                        .where('status', isEqualTo: 'delivered')
                        .limit(500)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const _DashboardNumber(
                            label: 'Cash still owed', value: '!');
                      }
                      if (!snapshot.hasData) {
                        return const _DashboardNumber(
                            label: 'Cash still owed', value: '…');
                      }
                      var owed = 0.0;
                      for (final doc in snapshot.data!.docs) {
                        final d = doc.data();
                        final collected =
                            (d['cashCollected'] as num?)?.toDouble() ?? 0;
                        final returned =
                            (d['cashReturned'] as num?)?.toDouble() ?? 0;
                        owed += collected - returned;
                      }
                      return _DashboardNumber(
                        label: 'Cash still owed',
                        value: owed.toStringAsFixed(2),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db
                        .collection('deliveries')
                        .where('problemStatus', isEqualTo: 'open')
                        .snapshots(),
                    builder: (context, snapshot) => _DashboardNumber(
                      label: 'Open problems',
                      value: snapshot.hasError
                          ? '!'
                          : snapshot.hasData
                              ? '${snapshot.data!.docs.length}'
                              : '…',
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: db
                        .collection('users')
                        .where('verificationStatus', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) => _DashboardNumber(
                      label: 'Waiting for approval',
                      value: snapshot.hasError
                          ? '!'
                          : snapshot.hasData
                              ? '${snapshot.data!.docs.length}'
                              : '…',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardNumber extends StatelessWidget {
  final String label;
  final String value;

  const _DashboardNumber({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: WaslTheme.teal,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Admin home (A1 dashboard + A2 approvals + A3 review).
/// Admin: Soufiane, raiss95@gmail.com — only admin at launch.
class AdminHome extends StatefulWidget {
  final AppUser profile;
  final AuthService auth;

  const AdminHome({super.key, required this.profile, required this.auth});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  String? _error;
  bool _activeOnly = true; // default: the live driving the admin watches
  String _searchQuery = '';

  /// Run an admin write, then write its audit record. A failed audit
  /// returns Err so the admin sees it — never silent, never unlogged.
  Future<Result<void>> _withAudit(
    Future<Result<void>> run, {
    required String action,
    required String targetType,
    required String targetId,
    required String targetLabel,
    String? reason,
  }) async {
    final result = await run;
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (_) {});
    if (!ok) return result;
    return AuditService.log(
      action: action,
      targetType: targetType,
      targetId: targetId,
      targetLabel: targetLabel,
      reason: reason,
    );
  }

  Future<Result<void>> _approve(String uid, String name) => _withAudit(
    guard(
      () => FirebaseFirestore.instance.collection('users').doc(uid).update({
        'verificationStatus': 'approved',
      }),
    ),
    action: 'approve_user',
    targetType: 'user',
    targetId: uid,
    targetLabel: name,
  );

  /// Approve/reject a pending stores or drivers record (the second
  /// approval step: the account is approved first, then the profile).
  Future<Result<void>> _approveRecord(
    String collection,
    String id,
    String name,
  ) => _withAudit(
    guard(
      () => FirebaseFirestore.instance.collection(collection).doc(id).update({
        'verificationStatus': 'approved',
      }),
    ),
    action: collection == 'stores' ? 'approve_store' : 'approve_driver',
    targetType: collection == 'stores' ? 'store' : 'driver',
    targetId: id,
    targetLabel: name,
  );

  Future<void> _rejectRecord(String collection, String id, String name) async {
    final reason = await _askReason('Reject $name?', 'Reason (shown to them)');
    if (reason == null) return;
    final result = await _withAudit(
      guard(
        () => FirebaseFirestore.instance.collection(collection).doc(id).update({
          'verificationStatus': 'rejected',
          'verificationReason': reason,
        }),
      ),
      action: collection == 'stores' ? 'reject_store' : 'reject_driver',
      targetType: collection == 'stores' ? 'store' : 'driver',
      targetId: id,
      targetLabel: name,
      reason: reason,
    );
    result.fold((_) {}, (m) => setState(() => _error = m));
  }

  /// Ask for a reason, then run the action. Returns the reason or null.
  Future<String?> _askReason(String title, String label) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, reasonController.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return reason;
  }

  Future<void> _reject(String uid, String name) async {
    final reason = await _askReason('Reject $name?', 'Reason (shown to them)');
    if (reason == null) return;
    final result = await _withAudit(
      guard(
        () => FirebaseFirestore.instance.collection('users').doc(uid).update({
          'verificationStatus': 'rejected',
          'verificationReason': reason,
        }),
      ),
      action: 'reject_user',
      targetType: 'user',
      targetId: uid,
      targetLabel: name,
      reason: reason,
    );
    result.fold((_) {}, (m) => setState(() => _error = m));
  }

  /// One pending-records section (stores or drivers): name + detail line,
  /// Approve / Reject. Without this the admin could never approve a
  /// driver or store profile after approving their account.
  Widget _pendingRecordsSection({
    required String title,
    required String collection,
    required String Function(Map<String, dynamic> d) detail,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(collection)
              .where('verificationStatus', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorBanner(
                message: 'Could not load $title: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pending = snapshot.data!.docs;
            if (pending.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nothing waiting.'),
                ),
              );
            }
            return Column(
              children: pending.map((doc) {
                final d = doc.data();
                final name = (d['name'] ?? '').toString();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(detail(d)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final result = await _approveRecord(
                                    collection,
                                    doc.id,
                                    name,
                                  );
                                  result.fold(
                                    (_) {},
                                    (m) => setState(() => _error = m),
                                  );
                                },
                                child: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _rejectRecord(collection, doc.id, name),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Revoke an APPROVED account: it loses access but the record stays,
  /// so there is always a trail. The admin can never revoke themself.
  Future<void> _revoke(String uid, String name) async {
    final reason = await _askReason('Revoke $name?', 'Reason (shown to them)');
    if (reason == null) return;
    final result = await _withAudit(
      guard(
        () => FirebaseFirestore.instance.collection('users').doc(uid).update({
          'verificationStatus': 'rejected',
          'verificationReason': reason,
        }),
      ),
      action: 'revoke_account',
      targetType: 'user',
      targetId: uid,
      targetLabel: name,
      reason: reason,
    );
    result.fold((_) {}, (m) => setState(() => _error = m));
  }

  /// Remove an account completely: delete its store/driver record(s) and
  /// revoke the user. The users doc itself is never deleted (rules forbid
  /// it — the record stays as a trail).
  // NOTE: removing an account no longer happens here — it goes through
  // the two-admin request flow (_requestRemove → TwoAdminService), so a
  // second admin must approve before anything is deleted.

  Future<void> _deleteDelivery(String id, String orderNumber) =>
      adminDeleteDelivery(
        context,
        id,
        orderNumber,
        (m) => setState(() => _error = m),
      );

  Future<void> _reassign(String id, String orderNumber) =>
      adminReassignDelivery(
        context,
        id,
        orderNumber,
        (m) => setState(() => _error = m),
      );

  Future<void> _resolveProblemDialog(String id, String orderNumber) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resolve the problem on #$orderNumber?'),
        content: const Text(
          'This marks the reported problem resolved. The report stays on the delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await AdminService.resolveProblem(
      deliveryId: id,
      orderLabel: '#$orderNumber',
    );
    result.fold((_) {}, (m) => setState(() => _error = m));
  }

  Future<void> _decideDisputeDialog(String id, Map<String, dynamic> d) async {
    final orderNumber = (d['orderNumber'] ?? '').toString();
    final total = (d['orderTotal'] as num?)?.toDouble() ?? 0;
    var decision = (d['disputeDecision'] as String?) ?? 'store';
    final amountController = TextEditingController(
      text: total.toStringAsFixed(2),
    );
    final noteController = TextEditingController(
      text: (d['disputeNote'] ?? '').toString(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Decide dispute — #$orderNumber'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Who pays?'),
                ...AdminService.disputeOptions.map(
                  (option) => RadioListTile<String>(
                    title: Text(AdminService.disputeLabel(option)),
                    value: option,
                    groupValue: decision,
                    onChanged: (v) =>
                        setDialogState(() => decision = v ?? decision),
                  ),
                ),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (order total)',
                  ),
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save decision'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text.trim()) ?? total;
    final result = await AdminService.decideDispute(
      deliveryId: id,
      orderLabel: '#$orderNumber',
      decision: decision,
      amount: amount,
      note: noteController.text.trim(),
    );
    result.fold((_) {}, (m) => setState(() => _error = m));
  }

  int _tabIndex = 0;

  static const _tabTitles = [
    'Wasl Admin',
    'Live map',
    'Approvals',
    'Payouts',
    'More',
  ];

  /// Export the latest deliveries as a plain-text report and share it
  /// (admin reports for taxes / records). Nothing is written to a file.
  Future<void> _exportDeliveriesReport() async {
    final result = await guard(() async {
      final snap = await FirebaseFirestore.instance
          .collection('deliveries')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      final lines = <String>[
        'Wasl deliveries report — ${DateTime.now().toIso8601String().substring(0, 10)}',
        'Orders: ${snap.docs.length}',
        '',
      ];
      for (final doc in snap.docs) {
        final d = doc.data();
        lines.add(
          '#${d['orderNumber'] ?? ''} — ${d['storeName'] ?? ''} — ${d['customerName'] ?? ''} — driver: ${d['driverName'] ?? 'none'} — ${d['status'] ?? ''} — total ${(d['orderTotal'] as num?)?.toStringAsFixed(2) ?? ''} — fee ${(d['fee'] as num?)?.toStringAsFixed(2) ?? ''}',
        );
      }
      await Share.share(lines.join('\n'), subject: 'Wasl deliveries report');
    });
    result.fold((_) {}, (m) => setState(() => _error = m));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const WaslAppBarLogo(),
        title: Text(_tabTitles[_tabIndex]),
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _homeTab(),
          const AdminLiveMapScreen(embedded: true),
          _approvalsTab(),
          const PayoutsScreen(embedded: true),
          _moreTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: WaslTheme.teal,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Live map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg),
            label: 'Approvals',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Payouts'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }

  /// Home tab: open live orders + search — the live driving the admin
  /// watches. Everything else lives in the other tabs.
  Widget _homeTab() {
    final db = FirebaseFirestore.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        const AdminDashboardCard(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _activeOnly ? 'Open live orders' : 'All deliveries',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('Open live'),
              selected: _activeOnly,
              onSelected: (_) => setState(() => _activeOnly = true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('All'),
              selected: !_activeOnly,
              onSelected: (_) => setState(() => _activeOnly = false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Search orders',
            hintText: 'Order number, customer, driver or store',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.trim()),
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _exportDeliveriesReport,
          icon: const Icon(Icons.share),
          label: const Text('Export deliveries report'),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _activeOnly
              ? db
                    .collection('deliveries')
                    .where(
                      'status',
                      whereIn: const [
                        'offered',
                        'assigned',
                        'accepted',
                        'pickedUp',
                        'delivering',
                      ],
                    )
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots()
              : db
                    .collection('deliveries')
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorBanner(
                message: 'Could not load deliveries: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final q = _searchQuery.toLowerCase();
            final deliveries = snapshot.data!.docs.where((doc) {
              if (q.isEmpty) return true;
              final d = doc.data();
              final haystack = [
                (d['orderNumber'] ?? '').toString(),
                (d['customerName'] ?? '').toString(),
                (d['driverName'] ?? '').toString(),
                (d['storeName'] ?? '').toString(),
              ].join(' ').toLowerCase();
              return haystack.contains(q);
            }).toList();
            if (deliveries.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? 'No orders match "$_searchQuery".'
                        : _activeOnly
                        ? 'No open live orders right now.'
                        : 'No deliveries yet.',
                  ),
                ),
              );
            }
            return Column(
              children: deliveries.map((doc) {
                final d = doc.data();
                final status = (d['status'] ?? '').toString();
                final canReassign =
                    status == 'offered' ||
                    status == 'assigned' ||
                    status == 'accepted';
                final hasProblem = (d['problemStatus'] ?? '') == 'open';
                final problem = (d['problem'] ?? '').toString();
                final dispute = (d['disputeDecision'] ?? '').toString();
                final orderLabel =
                    '#${d['orderNumber'] ?? ''} — ${d['storeName'] ?? ''}';
                return Card(
                  child: ListTile(
                    title: Text(orderLabel),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d['customerName'] ?? ''} • ${d['driverName'] ?? 'no driver'} • $status',
                        ),
                        if (hasProblem)
                          Text(
                            'Problem: $problem',
                            style: const TextStyle(
                              color: WaslTheme.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (dispute.isNotEmpty)
                          Text(
                            'Dispute: ${AdminService.disputeLabel(dispute)}${(d['disputeAmount'] as num?) != null ? ' — ${(d['disputeAmount'] as num).toStringAsFixed(2)}' : ''}',
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'reassign') {
                          _reassign(
                            doc.id,
                            (d['orderNumber'] ?? '').toString(),
                          );
                        } else if (value == 'delete') {
                          _deleteDelivery(
                            doc.id,
                            (d['orderNumber'] ?? '').toString(),
                          );
                        } else if (value == 'resolve') {
                          _resolveProblemDialog(
                            doc.id,
                            (d['orderNumber'] ?? '').toString(),
                          );
                        } else if (value == 'dispute') {
                          _decideDisputeDialog(doc.id, d);
                        } else if (value == 'chat') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                delivery: Delivery.fromDoc(doc),
                                profile: widget.profile,
                              ),
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        if (canReassign)
                          const PopupMenuItem(
                            value: 'reassign',
                            child: Text('Reassign driver'),
                          ),
                        if (hasProblem)
                          const PopupMenuItem(
                            value: 'resolve',
                            child: Text('Resolve problem'),
                          ),
                        const PopupMenuItem(
                          value: 'dispute',
                          child: Text('Decide dispute'),
                        ),
                        const PopupMenuItem(
                          value: 'chat',
                          child: Text('Chat with store & driver'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete delivery'),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  /// Two-admin queue: big actions (removing an account, changing fees)
  /// requested by one admin wait here until a DIFFERENT admin approves
  /// or rejects them. Your own requests show here too, but you cannot
  /// approve them yourself — add a second admin in Admins & roles if
  /// you are the only admin.
  Widget _twoAdminSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Needs a second admin',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Removing an account or changing fees only takes effect after a different admin approves it here.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<TwoAdminRequest>>(
          stream: TwoAdminService().pendingRequestsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorBanner(
                message: 'Could not load requests: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data!;
            if (requests.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nothing waiting for a second admin.'),
                ),
              );
            }
            return Column(
              children: requests.map((req) {
                final mine = req.requestedBy == widget.profile.uid;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${req.typeLabel} — ${req.targetLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('Requested by ${req.requestedByName}'),
                        if (req.type == 'change_fees')
                          Text(
                            'New fees: ${(req.payload['fees'] as Map?)?.entries.map((e) => '${e.key}: ${e.value}').join(', ') ?? ''}',
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: mine
                                    ? null
                                    : () async {
                                        final result =
                                            await TwoAdminService().approve(
                                          request: req,
                                          approverUid: widget.profile.uid,
                                          approverName: widget.profile.name,
                                        );
                                        result.fold(
                                          (_) {},
                                          (m) => setState(() => _error = m),
                                        );
                                      },
                                child: Text(
                                    mine ? 'Waiting for another admin' : 'Approve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: mine
                                    ? null
                                    : () async {
                                        final reason = await _askReason(
                                            'Reject this request?',
                                            'Reason');
                                        if (reason == null) return;
                                        final result =
                                            await TwoAdminService().reject(
                                          request: req,
                                          approverUid: widget.profile.uid,
                                          approverName: widget.profile.name,
                                          reason: reason,
                                        );
                                        result.fold(
                                          (_) {},
                                          (m) => setState(() => _error = m),
                                        );
                                      },
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// File a remove-account request for the second admin instead of
  /// deleting at once. The account stays untouched until approved.
  Future<void> _requestRemove(
      String uid, String name, String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
          'This needs a second admin to approve it. Until then nothing changes — the account keeps working. Once approved, their store/driver record is deleted and the account is revoked. Their past deliveries stay on record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send for approval'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final result = await TwoAdminService().request(
      type: 'remove_account',
      targetType: role == 'store' ? 'store' : 'driver',
      targetId: uid,
      targetLabel: name,
      payload: {'uid': uid, 'name': name, 'role': role},
      requestedBy: widget.profile.uid,
      requestedByName: widget.profile.name,
    );
    result.fold(
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Sent for a second admin to approve — nothing changed yet.'),
          ),
        );
      },
      (m) => setState(() => _error = m),
    );
  }

  /// Approvals tab: pending accounts + pending store/driver profiles +
  /// approved accounts.
  Widget _approvalsTab() {
    final db = FirebaseFirestore.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        const Text(
          'Approvals',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('users')
              .where('verificationStatus', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorBanner(
                message: 'Could not load approvals: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final pending = snapshot.data!.docs;
            if (pending.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No accounts waiting for approval.'),
                ),
              );
            }
            return Column(
              children: pending.map((doc) {
                final d = doc.data();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${d['name'] ?? ''} — ${d['role'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('${d['email'] ?? ''}'),
                        if ((d['businessName'] ?? '').toString().isNotEmpty)
                          Text(
                            'Business: ${(d['businessName'] ?? '').toString()}',
                          ),
                        if ((d['phone'] ?? '').toString().isNotEmpty)
                          Text('Phone: ${(d['phone'] ?? '').toString()}'),
                        if ((d['address'] ?? '').toString().isNotEmpty)
                          Text('Address: ${(d['address'] ?? '').toString()}'),
                        if ((d['market'] ?? '').toString().isNotEmpty)
                          Text('Market: ${(d['market'] ?? '').toString()}'),
                        if ((d['storeType'] ?? '').toString().isNotEmpty)
                          Text('Type: ${(d['storeType'] ?? '').toString()}'),
                        if ((d['vehicle'] ?? '').toString().isNotEmpty)
                          Text('Vehicle: ${(d['vehicle'] ?? '').toString()}'),
                        if ((d['homeZone'] ?? '').toString().isNotEmpty)
                          Text(
                            'Home zone: ${(d['homeZone'] ?? '').toString()}',
                          ),
                        const SizedBox(height: 8),
                        if ((d['proofImageUrl'] ?? '').toString().isNotEmpty)
                          GestureDetector(
                            onTap: () => showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: InteractiveViewer(
                                  child: Image.network(
                                    (d['proofImageUrl'] ?? '').toString(),
                                    errorBuilder: (_, __, ___) =>
                                        const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                          'Proof photo could not load.'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ID / licence photo — tap to check it:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    (d['proofImageUrl'] ?? '').toString(),
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Text(
                                        'Proof photo could not load.'),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if ((d['role'] ?? '').toString() != 'customer')
                          const Text(
                            'No ID / licence photo uploaded.',
                            style: TextStyle(
                              color: WaslTheme.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final result = await _approve(
                                    doc.id,
                                    (d['name'] ?? '').toString(),
                                  );
                                  result.fold(
                                    (_) {},
                                    (m) => setState(() => _error = m),
                                  );
                                },
                                child: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _reject(
                                  doc.id,
                                  (d['name'] ?? '').toString(),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        _twoAdminSection(),
        _pendingRecordsSection(
          title: 'Store profiles waiting',
          collection: 'stores',
          detail: (d) => 'Owner: ${(d['ownerUid'] ?? '').toString()}',
        ),
        _pendingRecordsSection(
          title: 'Driver profiles waiting',
          collection: 'drivers',
          detail: (d) =>
              '${(d['type'] ?? '').toString()} • Vehicle: ${(d['vehicle'] ?? '').toString()}',
        ),
        const Text(
          'Approved accounts',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db
              .collection('users')
              .where('verificationStatus', isEqualTo: 'approved')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final users = snapshot.data!.docs;
            return Column(
              children: users.map((doc) {
                final d = doc.data();
                final isSelf =
                    doc.id == widget.profile.uid ||
                    doc.id == 'raiss95@gmail.com';
                return Card(
                  child: ListTile(
                    title: Text('${d['name'] ?? ''}'),
                    subtitle: Text('${d['role'] ?? ''} • ${d['email'] ?? ''}'),
                    trailing: isSelf
                        ? const Text(
                            'you',
                            style: TextStyle(color: Colors.black45),
                          )
                        : PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'revoke') {
                                _revoke(doc.id, (d['name'] ?? '').toString());
                              } else if (value == 'remove') {
                                _requestRemove(
                                  doc.id,
                                  (d['name'] ?? '').toString(),
                                  (d['role'] ?? '').toString(),
                                );
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'revoke',
                                child: Text('Revoke access'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove completely (needs a second admin)'),
                              ),
                            ],
                          ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Admin controls cash/card per store, fees and markets in the full console. '
          'This screen covers approvals, accounts and deliveries; fee and payment switches land with the admin web surface.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  /// More tab: manage screens + sign out.
  Widget _moreTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Manage',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AdminStoresScreen(profile: widget.profile)),
              ),
              icon: const Icon(Icons.store),
              label: const Text('Stores'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDriversScreen()),
              ),
              icon: const Icon(Icons.delivery_dining),
              label: const Text('Drivers'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PayoutsScreen()),
              ),
              icon: const Icon(Icons.payments),
              label: const Text('Payouts'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MarketsScreen(profile: widget.profile)),
              ),
              icon: const Icon(Icons.public),
              label: const Text('Markets'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminActivityScreen()),
              ),
              icon: const Icon(Icons.history),
              label: const Text('Admin activity'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminsScreen()),
              ),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admins & roles'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        AnnouncementsScreen(profile: widget.profile)),
              ),
              icon: const Icon(Icons.campaign),
              label: const Text('Announcements'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        DirectInboxScreen(profile: widget.profile)),
              ),
              icon: const Icon(Icons.message),
              label: const Text('Direct messages'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PhotoCleanupScreen(profile: widget.profile)),
              ),
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Photo cleanup'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => widget.auth.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

/// A6 — admin live map: every active delivery as a pin (where the customer
/// is) and every driver sharing a live position while on a job. Tap a
/// delivery pin to reassign its driver or delete it — the same controls
/// as the deliveries list, from the map. Driver positions only appear
/// while a driver is on an active job and only if fresh (under 10 min).
class AdminLiveMapScreen extends StatefulWidget {
  final bool embedded; // true inside the admin bottom-nav tab (no own bar)

  const AdminLiveMapScreen({super.key, this.embedded = false});

  @override
  State<AdminLiveMapScreen> createState() => _AdminLiveMapScreenState();
}

class _AdminLiveMapScreenState extends State<AdminLiveMapScreen> {
  Map<String, dynamic>? _selectedDelivery;
  String? _selectedDeliveryId;
  Map<String, dynamic>? _selectedDriver;
  String? _error;

  bool _fresh(Map<String, dynamic> d) {
    final seen = d['lastSeen'];
    if (seen == null) return false;
    final when = (seen as Timestamp).toDate();
    return DateTime.now().difference(when).inMinutes < 10;
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('deliveries')
          .where(
            'status',
            whereIn: const ['accepted', 'pickedUp', 'delivering'],
          )
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, deliveriesSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('drivers').snapshots(),
          builder: (context, driversSnapshot) {
            if (deliveriesSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorBanner(
                    message:
                        'Could not load deliveries: ${deliveriesSnapshot.error}',
                  ),
                ),
              );
            }
            if (!deliveriesSnapshot.hasData || !driversSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final active = deliveriesSnapshot.data!.docs.where((doc) {
              final d = doc.data();
              return d['customerLat'] != null && d['customerLng'] != null;
            }).toList();
            final drivers = driversSnapshot.data!.docs
                .map((doc) => doc.data())
                .where(
                  (d) =>
                      d['lastLat'] != null && d['lastLng'] != null && _fresh(d),
                )
                .toList();
            return Column(
              children: [
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorBanner(message: _error!),
                  ),
                ],
                Expanded(
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(42.3781, -71.0365),
                      initialZoom: 13,
                    ),
                    children: [
                      const OfmMapLayer(),
                      SimpleAttributionWidget(
                        source: const Text('© OpenStreetMap contributors'),
                      ),
                      MarkerLayer(
                        markers: [
                          ...active.map((doc) {
                            final d = doc.data();
                            final status = (d['status'] ?? '').toString();
                            return Marker(
                              point: LatLng(
                                (d['customerLat'] as num).toDouble(),
                                (d['customerLng'] as num).toDouble(),
                              ),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedDelivery = d;
                                  _selectedDeliveryId = doc.id;
                                  _selectedDriver = null;
                                }),
                                child: Icon(
                                  Icons.location_on,
                                  color: status == 'accepted'
                                      ? WaslTheme.amber
                                      : WaslTheme.teal,
                                  size: 36,
                                ),
                              ),
                            );
                          }),
                          ...drivers.map(
                            (d) => Marker(
                              point: LatLng(
                                (d['lastLat'] as num).toDouble(),
                                (d['lastLng'] as num).toDouble(),
                              ),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedDriver = d;
                                  _selectedDelivery = null;
                                  _selectedDeliveryId = null;
                                }),
                                child: const Icon(
                                  Icons.person_pin_circle,
                                  color: WaslTheme.marketplaceBlue,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_selectedDelivery != null)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '#${_selectedDelivery!['orderNumber'] ?? ''} — ${_selectedDelivery!['storeName'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${_selectedDelivery!['customerName'] ?? ''} • ${_selectedDelivery!['driverName'] ?? 'no driver'} • ${_selectedDelivery!['status'] ?? ''}',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (((_selectedDelivery!['status'] ?? '')
                                        .toString() ==
                                    'offered') ||
                                ((_selectedDelivery!['status'] ?? '')
                                        .toString() ==
                                    'assigned') ||
                                ((_selectedDelivery!['status'] ?? '')
                                        .toString() ==
                                    'accepted'))
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => adminReassignDelivery(
                                    context,
                                    _selectedDeliveryId!,
                                    (_selectedDelivery!['orderNumber'] ?? '')
                                        .toString(),
                                    (m) => setState(() => _error = m),
                                  ),
                                  child: const Text('Reassign driver'),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => adminDeleteDelivery(
                                  context,
                                  _selectedDeliveryId!,
                                  (_selectedDelivery!['orderNumber'] ?? '')
                                      .toString(),
                                  (m) => setState(() => _error = m),
                                ),
                                child: const Text('Delete delivery'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                else if (_selectedDriver != null)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedDriver!['name'] ?? ''} — ${(_selectedDriver!['type'] ?? '').toString() == 'own-driver' ? 'Own driver' : 'Marketplace driver'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Vehicle: ${_selectedDriver!['vehicle'] ?? ''} • On duty: ${_selectedDriver!['onDuty'] == true ? 'yes' : 'no'}',
                        ),
                        const Text(
                          'Position shared only while on an active job.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      active.isEmpty && drivers.isEmpty
                          ? 'Nothing moving right now — active deliveries and drivers on a job appear here.'
                          : '${active.length} active deliver${active.length == 1 ? 'y' : 'ies'} • ${drivers.length} driver${drivers.length == 1 ? '' : 's'} sharing a live position. Tap a pin to act on it.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Live map — all deliveries')),
      body: body,
    );
  }
}

/// A4 list — every store, tap for the detail screen.
class AdminStoresScreen extends StatelessWidget {
  final AppUser profile;

  const AdminStoresScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('stores').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load stores: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stores = snapshot.data!.docs;
          if (stores.isEmpty) {
            return const Center(child: Text('No stores yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: stores.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  title: Text((d['name'] ?? '').toString()),
                  subtitle: Text(
                    '${(d['market'] ?? '').toString()} • ${(d['verificationStatus'] ?? '').toString()}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreDetailScreen(
                        storeDocId: doc.id,
                        profile: profile,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// A4 — store detail: payment switches (cash/card, never both off, card
/// needs a payout account), per-delivery fee + monthly plan, live stats,
/// Block / Unblock. Fees are still to test — Boston $4–$7, Morocco MAD.
class StoreDetailScreen extends StatefulWidget {
  final String storeDocId;
  final AppUser profile;

  const StoreDetailScreen({
    super.key,
    required this.storeDocId,
    required this.profile,
  });

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final _fee = TextEditingController();
  final _monthly = TextEditingController();
  final _payout = TextEditingController();
  String? _error;
  bool _saved = false;
  String _savedMessage = 'Saved.';

  @override
  void dispose() {
    _fee.dispose();
    _monthly.dispose();
    _payout.dispose();
    super.dispose();
  }

  /// Save the payout account at once (account details, not a fee);
  /// the fee values go to a second admin — they only take effect after
  /// approval (two-admin rule). The screen says so after saving.
  Future<void> _saveFees(String label) async {
    final fee = double.tryParse(_fee.text.trim());
    final monthly = double.tryParse(_monthly.text.trim());
    final saved = await guard(
      () => FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeDocId)
          .update({'payoutAccount': _payout.text.trim()}),
    );
    var ok = false;
    saved.fold((_) {
      ok = true;
    }, (m) => setState(() => _error = m));
    if (!ok) return;
    final requested = await TwoAdminService().request(
      type: 'change_fees',
      targetType: 'store',
      targetId: widget.storeDocId,
      targetLabel: label,
      payload: {
        'collection': 'stores',
        'fees': {'perDeliveryFee': fee, 'monthlyPlan': monthly},
      },
      requestedBy: widget.profile.uid,
      requestedByName: widget.profile.name,
    );
    requested.fold(
      (_) => setState(() {
        _saved = true;
        _savedMessage =
            'Payout account saved. Fee change sent for a second admin to approve — the fees stay as they were until then.';
      }),
      (m) => setState(() => _error = m),
    );
  }

  Future<void> _setPayment(
    Map<String, dynamic> d,
    String key,
    bool value,
  ) async {
    final methods = Map<String, dynamic>.from(d['paymentMethods'] ?? {});
    final otherKey = key == 'cash' ? 'card' : 'cash';
    if (!value && methods[otherKey] != true) {
      setState(
        () => _error =
            'Never both off — a store must take at least one payment method.',
      );
      return;
    }
    if (key == 'card' && value && (_payout.text.trim().isEmpty)) {
      setState(
        () => _error = 'Card needs a payout account first — fill it in below, save, then switch card on.',
      );
      return;
    }
    methods[key] = value;
    final result = await guard(
      () => FirebaseFirestore.instance
          .collection('stores')
          .doc(widget.storeDocId)
          .update({'paymentMethods': methods}),
    );
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (m) => setState(() => _error = m));
    if (!ok) return;
    setState(() => _error = null);
    final logged = await AuditService.log(
      action: 'set_payment_methods',
      targetType: 'store',
      targetId: widget.storeDocId,
      targetLabel:
          '${(d['name'] ?? '').toString()} — $key ${value ? 'on' : 'off'}',
    );
    logged.fold((_) {}, (m) => setState(() => _error = m));
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Store')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('stores').doc(widget.storeDocId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load store: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snapshot.data!.data() ?? {};
          final methods = Map<String, dynamic>.from(d['paymentMethods'] ?? {});
          final ownerUid = (d['ownerUid'] ?? '').toString();
          if (_fee.text.isEmpty && d['perDeliveryFee'] != null) {
            _fee.text = (d['perDeliveryFee'] as num).toString();
          }
          if (_monthly.text.isEmpty && d['monthlyPlan'] != null) {
            _monthly.text = (d['monthlyPlan'] as num).toString();
          }
          if (_payout.text.isEmpty && d['payoutAccount'] != null) {
            _payout.text = (d['payoutAccount'] ?? '').toString();
          }
          final blocked = (d['verificationStatus'] ?? '') == 'rejected';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (d['name'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text((d['address'] ?? '').toString()),
                      Text(
                        'Market: ${(d['market'] ?? '').toString()} • Zone: ${(d['zone'] ?? '').toString()}',
                      ),
                      Text(
                        'Verification: ${(d['verificationStatus'] ?? '').toString()}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment methods',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SwitchListTile(
                        title: const Text('Cash'),
                        value: methods['cash'] == true,
                        onChanged: (v) => _setPayment(d, 'cash', v),
                      ),
                      SwitchListTile(
                        title: const Text('Card (in-app)'),
                        subtitle: const Text(
                          'Needs a payout account + fee agreement.',
                        ),
                        value: methods['card'] == true,
                        onChanged: (v) => _setPayment(d, 'card', v),
                      ),
                      const Text(
                        'Payment is unified in the area — the same options for every store in a market, set here per store for now.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fees & payout account',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextField(
                        controller: _fee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Per-delivery fee (store currency)',
                        ),
                      ),
                      TextField(
                        controller: _monthly,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Monthly plan (store currency)',
                        ),
                      ),
                      TextField(
                        controller: _payout,
                        decoration: const InputDecoration(
                          labelText: 'Payout account reference',
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            _saveFees((d['name'] ?? '').toString()),
                        child: const Text('Save fees & payout account'),
                      ),
                      if (_saved)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _savedMessage,
                            style: const TextStyle(color: WaslTheme.okGreen),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('deliveries')
                    .where('storeId', isEqualTo: ownerUid)
                    .where('status', isEqualTo: 'delivered')
                    .snapshots(),
                builder: (context, statsSnapshot) {
                  final delivered = statsSnapshot.data?.docs ?? [];
                  final cashOwed = delivered.fold<double>(0, (s, doc) {
                    final dd = doc.data();
                    final collected =
                        (dd['cashCollected'] as num?)?.toDouble() ?? 0;
                    final returned =
                        (dd['cashReturned'] as num?)?.toDouble() ?? 0;
                    return s + collected - returned;
                  });
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live stats',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Deliveries done: ${delivered.length} • Cash still owed to the store: ${cashOwed.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live orders',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('deliveries')
                            .where('storeId', isEqualTo: ownerUid)
                            .orderBy('createdAt', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, liveSnapshot) {
                          if (liveSnapshot.hasError) {
                            return ErrorBanner(
                              message:
                                  'Could not load live orders: ${liveSnapshot.error}',
                            );
                          }
                          if (!liveSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          const activeStatuses = {
                            'offered',
                            'assigned',
                            'accepted',
                            'pickedUp',
                            'delivering',
                          };
                          final live = liveSnapshot.data!.docs
                              .where(
                                (doc) => activeStatuses.contains(
                                  (doc.data()['status'] ?? '').toString(),
                                ),
                              )
                              .toList();
                          if (live.isEmpty) {
                            return const Text('No live orders right now.');
                          }
                          return Column(
                            children: live.map((doc) {
                              final ld = doc.data();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '#${ld['orderNumber'] ?? ''} — ${(ld['customerName'] ?? '').toString()}',
                                ),
                                subtitle: Text(
                                  'To: ${(ld['customerAddress'] ?? '').toString()} • Driver: ${(ld['driverName'] ?? 'not assigned').toString()}',
                                ),
                                trailing: Text((ld['status'] ?? '').toString()),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Drivers',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('drivers')
                            .where('storeId', isEqualTo: ownerUid)
                            .snapshots(),
                        builder: (context, driversSnapshot) {
                          if (driversSnapshot.hasError) {
                            return ErrorBanner(
                              message:
                                  'Could not load drivers: ${driversSnapshot.error}',
                            );
                          }
                          if (!driversSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final storeDrivers = driversSnapshot.data!.docs;
                          if (storeDrivers.isEmpty) {
                            return const Text('No drivers for this store yet.');
                          }
                          return Column(
                            children: storeDrivers.map((doc) {
                              final dd = doc.data();
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text((dd['name'] ?? '').toString()),
                                subtitle: Text(
                                  '${(dd['type'] ?? '').toString()} • ${(dd['vehicle'] ?? '').toString()} • ${(dd['verificationStatus'] ?? '').toString()} • on duty: ${(dd['onDuty'] == true ? 'yes' : 'no')}',
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (blocked) {
                    await adminUnblockAccount(
                      context,
                      ownerUid,
                      'stores',
                      widget.storeDocId,
                      (d['name'] ?? '').toString(),
                      (m) => setState(() => _error = m),
                    );
                  } else {
                    await adminBlockAccount(
                      context,
                      ownerUid,
                      'stores',
                      widget.storeDocId,
                      (d['name'] ?? '').toString(),
                      (m) => setState(() => _error = m),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blocked
                      ? WaslTheme.okGreen
                      : WaslTheme.danger,
                ),
                child: Text(blocked ? 'Unblock store' : 'Block store'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A5 list — every driver, tap for the detail screen.
class AdminDriversScreen extends StatelessWidget {
  const AdminDriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drivers')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load drivers: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final drivers = snapshot.data!.docs;
          if (drivers.isEmpty) {
            return const Center(child: Text('No drivers yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: drivers.map((doc) {
              final d = doc.data();
              return Card(
                child: ListTile(
                  title: Text((d['name'] ?? '').toString()),
                  subtitle: Text(
                    '${(d['type'] ?? '').toString()} • ${(d['verificationStatus'] ?? '').toString()} • rating ${(d['rating'] ?? 0).toString()}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverDetailScreen(driverDocId: doc.id),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

/// A5 — driver detail: profile, verification, stats, Block / Unblock.
class DriverDetailScreen extends StatefulWidget {
  final String driverDocId;

  const DriverDetailScreen({super.key, required this.driverDocId});

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Driver')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: db.collection('drivers').doc(widget.driverDocId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load driver: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snapshot.data!.data() ?? {};
          final userUid = (d['userUid'] ?? '').toString();
          final blocked = (d['verificationStatus'] ?? '') == 'rejected';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (d['name'] ?? '').toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${(d['type'] ?? '').toString() == 'own-driver' ? 'Own driver' : 'Marketplace driver'} • Vehicle: ${(d['vehicle'] ?? '').toString()}',
                      ),
                      Text(
                        'Verification: ${(d['verificationStatus'] ?? '').toString()}',
                      ),
                      Text('Rating: ${(d['rating'] ?? 0).toString()}'),
                      Text('On duty: ${d['onDuty'] == true ? 'yes' : 'no'}'),
                      Text('Home zone: ${(d['homeZone'] ?? '').toString()}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: db
                    .collection('deliveries')
                    .where('driverId', isEqualTo: userUid)
                    .where('status', isEqualTo: 'delivered')
                    .snapshots(),
                builder: (context, statsSnapshot) {
                  final delivered = statsSnapshot.data?.docs ?? [];
                  final cashOwed = delivered.fold<double>(0, (s, doc) {
                    final dd = doc.data();
                    final collected =
                        (dd['cashCollected'] as num?)?.toDouble() ?? 0;
                    final returned =
                        (dd['cashReturned'] as num?)?.toDouble() ?? 0;
                    return s + collected - returned;
                  });
                  final tips = delivered.fold<double>(0, (s, doc) {
                    final dd = doc.data();
                    return s + ((dd['tipKept'] as num?)?.toDouble() ?? 0);
                  });
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live stats',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('Deliveries done: ${delivered.length}'),
                          Text(
                            'Cash to return: ${cashOwed.toStringAsFixed(2)} • Tips kept: ${tips.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (blocked) {
                    await adminUnblockAccount(
                      context,
                      userUid,
                      'drivers',
                      widget.driverDocId,
                      (d['name'] ?? '').toString(),
                      (m) => setState(() => _error = m),
                    );
                  } else {
                    await adminBlockAccount(
                      context,
                      userUid,
                      'drivers',
                      widget.driverDocId,
                      (d['name'] ?? '').toString(),
                      (m) => setState(() => _error = m),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: blocked
                      ? WaslTheme.okGreen
                      : WaslTheme.danger,
                ),
                child: Text(blocked ? 'Unblock driver' : 'Block driver'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A7 — payouts & disputes: Wasl fees owed per store (computed live),
/// manual settlement, and the dispute rule. The admin decides each
/// dispute case by case from the deliveries list (Decide dispute).
class PayoutsScreen extends StatefulWidget {
  final bool embedded; // true inside the admin bottom-nav tab (no own bar)

  const PayoutsScreen({super.key, this.embedded = false});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  String? _error;

  Future<void> _settleDialog(
    String storeId,
    String storeName,
    double stillOwed,
  ) async {
    final amountController = TextEditingController(
      text: stillOwed.toStringAsFixed(2),
    );
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark settled — $storeName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount settled'),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark settled'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text.trim()) ?? stillOwed;
    final result = await AdminService.settlePayout(
      storeId: storeId,
      storeName: storeName,
      amount: amount,
      note: noteController.text.trim(),
    );
    result.fold((_) {}, (m) => setState(() => _error = m));
  }

  String _when(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate().toLocal();
    return '${d.month}/${d.day}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts & disputes')),
      body: body,
    );
  }

  Widget _body(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Disputes', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  'Decided: a late order is the restaurant\'s and the driver\'s shared responsibility.',
                ),
                Text(
                  'The admin decides each dispute case by case from the deliveries list — store pays, driver pays, split 50-50, or Wasl covers it — with the amount and a note. Cold or lost orders are decided the same way.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
        ],
        const Text(
          'Wasl fees owed per store',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const Text(
          'Computed live: delivered × per-delivery fee + monthly plan, minus settled payouts. Set the fees on each store first (Stores screen).',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: db.collection('stores').snapshots(),
          builder: (context, storesSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('deliveries')
                  .where('status', isEqualTo: 'delivered')
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, deliveredSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: db
                      .collection('payouts')
                      .where('status', isEqualTo: 'settled')
                      .limit(200)
                      .snapshots(),
                  builder: (context, payoutsSnapshot) {
                    if (storesSnapshot.hasError ||
                        deliveredSnapshot.hasError ||
                        payoutsSnapshot.hasError) {
                      return const ErrorBanner(
                        message: 'Could not load payouts.',
                      );
                    }
                    if (!storesSnapshot.hasData ||
                        !deliveredSnapshot.hasData ||
                        !payoutsSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final stores = storesSnapshot.data!.docs;
                    final delivered = deliveredSnapshot.data!.docs;
                    final settledDocs = payoutsSnapshot.data!.docs;
                    if (stores.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No stores yet.'),
                        ),
                      );
                    }
                    return Column(
                      children: stores.map((storeDoc) {
                        final s = storeDoc.data();
                        final ownerUid = (s['ownerUid'] ?? '').toString();
                        final count = delivered
                            .where(
                              (doc) =>
                                  (doc.data()['storeId'] ?? '') == ownerUid,
                            )
                            .length;
                        final fee = (s['perDeliveryFee'] as num?)?.toDouble();
                        final monthly = (s['monthlyPlan'] as num?)?.toDouble();
                        final owed = fee == null
                            ? null
                            : count * fee + (monthly ?? 0);
                        final storeSettled =
                            settledDocs
                                .where(
                                  (doc) =>
                                      (doc.data()['storeId'] ?? '') == ownerUid,
                                )
                                .toList()
                              ..sort((a, b) {
                                final at =
                                    (a.data()['settledAt'] as Timestamp?);
                                final bt =
                                    (b.data()['settledAt'] as Timestamp?);
                                final ad = at?.toDate();
                                final bd = bt?.toDate();
                                if (ad == null || bd == null) return 0;
                                return bd.compareTo(ad);
                              });
                        final settled = storeSettled.fold<double>(
                          0,
                          (sum, doc) =>
                              sum +
                              ((doc.data()['amount'] as num?)?.toDouble() ?? 0),
                        );
                        final stillOwed = owed == null ? null : owed - settled;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (s['name'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text('Delivered: $count'),
                                Text(
                                  'Per-delivery fee: ${fee == null ? 'not set' : fee.toString()} • Monthly plan: ${monthly == null ? 'not set' : monthly.toString()}',
                                ),
                                Text(
                                  owed == null
                                      ? 'Fees owed: set the per-delivery fee first.'
                                      : 'Fees owed: ${owed.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (owed != null) ...[
                                  Text(
                                    'Settled: ${settled.toStringAsFixed(2)}',
                                  ),
                                  Text(
                                    'Still owed: ${stillOwed!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (stillOwed > 0.005) ...[
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () => _settleDialog(
                                        ownerUid,
                                        (s['name'] ?? '').toString(),
                                        stillOwed,
                                      ),
                                      child: const Text('Mark as settled'),
                                    ),
                                  ],
                                  if (storeSettled.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ...storeSettled.map((p) {
                                      final pd = p.data();
                                      final amt =
                                          (pd['amount'] as num?)?.toDouble() ??
                                          0;
                                      final note = (pd['note'] ?? '')
                                          .toString();
                                      return Text(
                                        'Settled ${amt.toStringAsFixed(2)} • ${_when(pd['settledAt'] as Timestamp?)}${note.isNotEmpty ? ' • $note' : ''}',
                                      );
                                    }),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// A8 — markets, zones & fees: the admin adds markets, sets market fees,
/// and adds zones inside a market. Wasl is global by design — nothing
/// here assumes only Boston + Morocco.
/// Pause a market to stop new orders there (storm / holiday); pause a
/// zone to mark it closed. Market pause is enforced at order creation.
class MarketsScreen extends StatefulWidget {
  final AppUser profile;

  const MarketsScreen({super.key, required this.profile});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final _marketName = TextEditingController();
  final _marketCurrency = TextEditingController();
  final _marketLanguages = TextEditingController();
  final _zoneName = TextEditingController();
  String _zoneMarket = 'boston';
  String? _error;

  @override
  void dispose() {
    _marketName.dispose();
    _marketCurrency.dispose();
    _marketLanguages.dispose();
    _zoneName.dispose();
    super.dispose();
  }

  Future<void> _addMarket() async {
    final name = _marketName.text.trim();
    final currency = _marketCurrency.text.trim();
    if (name.isEmpty || currency.isEmpty) {
      setState(() => _error = 'A market needs a name and a currency.');
      return;
    }
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final languages = _marketLanguages.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final result = await guard(
      () => FirebaseFirestore.instance.collection('markets').doc(id).set({
        'name': name,
        'currency': currency,
        'languages': languages,
        'perDeliveryFee': null,
        'monthlyPlan': null,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    result.fold(
      (_) => setState(() {
        _error = null;
        _marketName.clear();
        _marketCurrency.clear();
        _marketLanguages.clear();
      }),
      (m) => setState(() => _error = m),
    );
  }

  Future<void> _addZone() async {
    final name = _zoneName.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'A zone needs a name.');
      return;
    }
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final result = await guard(
      () => FirebaseFirestore.instance.collection('zones').doc(id).set({
        'name': name,
        'market': _zoneMarket,
      }),
    );
    result.fold(
      (_) => setState(() {
        _error = null;
        _zoneName.clear();
      }),
      (m) => setState(() => _error = m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Markets, zones & fees')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('markets').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorBanner(
                  message: 'Could not load markets: ${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final markets = snapshot.data!.docs;
              return Column(
                children: markets
                    .map(
                      (doc) => _MarketCard(
                        marketId: doc.id,
                        data: doc.data(),
                        profile: widget.profile,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Add a market',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _marketName,
            decoration: const InputDecoration(
              labelText: 'Market name (e.g. Casablanca)',
            ),
          ),
          TextField(
            controller: _marketCurrency,
            decoration: const InputDecoration(labelText: 'Currency (e.g. MAD)'),
          ),
          TextField(
            controller: _marketLanguages,
            decoration: const InputDecoration(
              labelText: 'Languages, comma separated (e.g. ar, fr)',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _addMarket,
            child: const Text('Add market'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add a zone',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('markets').snapshots(),
            builder: (context, snapshot) {
              final markets = snapshot.data?.docs ?? [];
              final items = markets
                  .map(
                    (doc) => DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text((doc.data()['name'] ?? '').toString()),
                    ),
                  )
                  .toList();
              if (items.isNotEmpty &&
                  !items.any((i) => i.value == _zoneMarket)) {
                _zoneMarket = items.first.value!;
              }
              return DropdownButton<String>(
                value: items.any((i) => i.value == _zoneMarket)
                    ? _zoneMarket
                    : null,
                hint: const Text('Market'),
                items: items,
                onChanged: (v) =>
                    setState(() => _zoneMarket = v ?? _zoneMarket),
              );
            },
          ),
          TextField(
            controller: _zoneName,
            decoration: const InputDecoration(
              labelText: 'Zone name (e.g. Maârif)',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _addZone, child: const Text('Add zone')),
          const SizedBox(height: 16),
          const Text(
            'Zones',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db.collection('zones').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final zones = snapshot.data!.docs;
              if (zones.isEmpty) {
                return const Text(
                  'No zones yet.',
                  style: TextStyle(color: Colors.black54),
                );
              }
              return Column(
                children: zones.map((doc) {
                  final d = doc.data();
                  final paused = (d['paused'] as bool?) ?? false;
                  return Card(
                    child: ListTile(
                      title: Text((d['name'] ?? '').toString()),
                      subtitle: Text(
                        'Market: ${(d['market'] ?? '').toString()}${paused ? ' • PAUSED' : ''}',
                      ),
                      trailing: Switch(
                        value: paused,
                        onChanged: (value) async {
                          final result =
                              await MarketService().setZonePaused(
                            zoneId: doc.id,
                            zoneName: (d['name'] ?? '').toString(),
                            paused: value,
                            byName: widget.profile.name,
                          );
                          result.fold(
                            (_) {},
                            (m) => setState(() => _error = m),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One market card with editable market-level fees.
class _MarketCard extends StatefulWidget {
  final String marketId;
  final Map<String, dynamic> data;
  final AppUser profile;

  const _MarketCard({
    required this.marketId,
    required this.data,
    required this.profile,
  });

  @override
  State<_MarketCard> createState() => _MarketCardState();
}

class _MarketCardState extends State<_MarketCard> {
  late final TextEditingController _fee;
  late final TextEditingController _monthly;
  String? _error;
  bool _saved = false;
  String _savedMessage = 'Saved.';

  @override
  void initState() {
    super.initState();
    _fee = TextEditingController(
      text: widget.data['perDeliveryFee']?.toString() ?? '',
    );
    _monthly = TextEditingController(
      text: widget.data['monthlyPlan']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _fee.dispose();
    _monthly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languages = ((widget.data['languages'] as List?) ?? [])
        .map((e) => e.toString())
        .join(', ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (widget.data['name'] ?? '').toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              'Currency: ${(widget.data['currency'] ?? '').toString()} • Languages: ${languages.isEmpty ? (widget.data['language'] ?? '').toString() : languages}',
            ),
            Row(
              children: [
                const Text('Paused — no new orders in this market'),
                const Spacer(),
                Switch(
                  value: (widget.data['paused'] as bool?) ?? false,
                  onChanged: (value) async {
                    final result = await MarketService().setMarketPaused(
                      marketId: widget.marketId,
                      marketName: (widget.data['name'] ?? '').toString(),
                      paused: value,
                      byName: widget.profile.name,
                    );
                    result.fold(
                      (_) {},
                      (m) => setState(() => _error = m),
                    );
                  },
                ),
              ],
            ),
            TextField(
              controller: _fee,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Per-delivery fee (market currency)',
              ),
            ),
            TextField(
              controller: _monthly,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Monthly plan'),
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: () async {
                final fee = double.tryParse(_fee.text.trim());
                final monthly = double.tryParse(_monthly.text.trim());
                // Market fees need a second admin — they only take effect
                // after approval (two-admin rule).
                final result = await TwoAdminService().request(
                  type: 'change_fees',
                  targetType: 'market',
                  targetId: widget.marketId,
                  targetLabel: (widget.data['name'] ?? '').toString(),
                  payload: {
                    'collection': 'markets',
                    'fees': {'perDeliveryFee': fee, 'monthlyPlan': monthly},
                  },
                  requestedBy: widget.profile.uid,
                  requestedByName: widget.profile.name,
                );
                result.fold(
                  (_) => setState(() {
                    _saved = true;
                    _savedMessage =
                        'Sent for a second admin to approve — the fees stay as they were until then.';
                  }),
                  (m) => setState(() => _error = m),
                );
              },
              child: const Text('Save market fees'),
            ),
            if (_saved)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _savedMessage,
                  style: const TextStyle(color: WaslTheme.okGreen),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
