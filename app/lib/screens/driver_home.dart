import 'dart:io';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/delivery.dart';
import '../models/run.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';
import '../services/direct_message_service.dart';
import '../services/driver_service.dart';
import '../services/location_service.dart';
import '../services/photo_service.dart';
import '../services/run_service.dart';
import '../theme.dart';
import 'announcements_screen.dart';
import 'chat_screen.dart';
import 'direct_inbox_screen.dart';
import 'driver_setup_screen.dart';
import 'navigate_screen.dart';
import '../widgets/ofm_map_layer.dart';

/// Driver home (D1 jobs board + D2 map view is the board list for v1 +
/// D5 earnings). One app for own and marketplace drivers.
Color _driverStatusColor(DeliveryStatus s) => switch (s) {
  DeliveryStatus.offered => Colors.blueGrey,
  DeliveryStatus.assigned => WaslTheme.marketplaceBlue,
  DeliveryStatus.accepted => WaslTheme.teal,
  DeliveryStatus.pickedUp => WaslTheme.teal,
  DeliveryStatus.delivering => WaslTheme.amber,
  DeliveryStatus.delivered => WaslTheme.okGreen,
  DeliveryStatus.cancelled => WaslTheme.danger,
};

/// Driver home: bottom nav with Jobs / My Runs / Earning / Chat / Profile,
/// as in the high-fidelity prototype. The driver-record gate (setup screen
/// when no record, pending banner until the admin approves) and the
/// trip-only location reporter live here in the shell, above the tabs.
class DriverHome extends StatefulWidget {
  final AppUser profile;
  final AuthService auth;

  const DriverHome({super.key, required this.profile, required this.auth});

  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Scaffold(
      // No driver record yet → one-time setup (S4 needs the record to
      // exist before a store can pick this driver). The record is created
      // as pending; the admin approves it.
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DriverService().myDriverDocStream(profile.uid),
        builder: (context, docSnapshot) {
          if (docSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load your driver profile.',
                ),
              ),
            );
          }
          if (!docSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = docSnapshot.data!.docs;
          if (docs.isEmpty) {
            return DriverSetupScreen(profile: profile);
          }
          final pending =
              (docs.first.data()['verificationStatus'] ?? '') != 'approved';
          return Column(
            children: [
              // Trip-only location sharing: on while an active job exists,
              // off otherwise. Invisible — it only reports the position.
              _LocationReporter(
                driverDocId: docs.first.id,
                profileUid: profile.uid,
              ),
              if (pending)
                Container(
                  width: double.infinity,
                  color: WaslTheme.amber.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(12),
                  child: const Text(
                    'Your driver profile is waiting for admin approval — stores can\'t assign you directly until then, but you can still take marketplace offers.',
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: [
                    _DriverJobsTab(profile: profile, auth: widget.auth),
                    _DriverRunsTab(profile: profile),
                    _DriverEarningsTab(profile: profile),
                    _DriverChatsTab(profile: profile),
                    DriverProfileScreen(profile: profile),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: WaslTheme.teal,
        unselectedItemColor: Colors.black54,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            label: 'Jobs',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'My Runs'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Earning'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// Jobs tab (D1): the active job on top, then the open job board.
class _DriverJobsTab extends StatelessWidget {
  final AppUser profile;
  final AuthService auth;

  const _DriverJobsTab({required this.profile, required this.auth});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(
        leading: const WaslAppBarLogo(),
        title: Text('Wasl — ${profile.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    JobMapScreen(profile: profile, service: service),
              ),
            ),
            tooltip: 'Job map',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, mySnapshot) {
          return StreamBuilder<List<Delivery>>(
            stream: service.driverBoardStream(profile.uid),
            builder: (context, boardSnapshot) {
              if (boardSnapshot.hasError || mySnapshot.hasError) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: ErrorBanner(
                      message: 'Could not load jobs — check connection.',
                    ),
                  ),
                );
              }
              if (!boardSnapshot.hasData || !mySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final board = boardSnapshot.data!;
              final mine = mySnapshot.data!;
              final active = mine
                  .where(
                    (d) =>
                        d.status == DeliveryStatus.accepted ||
                        d.status == DeliveryStatus.pickedUp ||
                        d.status == DeliveryStatus.delivering,
                  )
                  .toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const AnnouncementsCard(audience: 'drivers'),
                  if (active.isNotEmpty) ...[
                    const Text(
                      'Active job',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...active.map(
                      (d) => _JobCard(
                        delivery: d,
                        profile: profile,
                        service: service,
                        color: _driverStatusColor(d.status),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Job board',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (board.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No open jobs right now.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...board.map(
                    (d) => _JobCard(
                      delivery: d,
                      profile: profile,
                      service: service,
                      color: _driverStatusColor(d.status),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// My Runs tab (D6/D7): batched run offers and the active run, plus the
/// driver's past deliveries.
class _DriverRunsTab extends StatelessWidget {
  final AppUser profile;

  const _DriverRunsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('My Runs')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, mySnapshot) {
          if (mySnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(message: 'Could not load runs.'),
              ),
            );
          }
          if (!mySnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mine = mySnapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Batched runs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Run>>(
                stream: RunService().driverRunsStream(profile.uid),
                builder: (context, runsSnapshot) {
                  if (runsSnapshot.hasError) {
                    return ErrorBanner(
                      message: 'Could not load runs: ${runsSnapshot.error}',
                    );
                  }
                  if (!runsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final runs = runsSnapshot.data!;
                  if (runs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'No batch offers right now.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return Column(
                    children: runs
                        .map(
                          (r) => _RunCard(
                            run: r,
                            profile: profile,
                            service: service,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'My deliveries',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...mine
                  .where(
                    (d) =>
                        d.status == DeliveryStatus.delivered ||
                        d.status == DeliveryStatus.cancelled,
                  )
                  .map(
                    (d) => Card(
                      child: ListTile(
                        title: Text('#${d.orderNumber} — ${d.storeName}'),
                        subtitle: Text('${d.items} • ${d.money(d.orderTotal)}'),
                        trailing: StatusChip(
                          label: d.status.label,
                          color: _driverStatusColor(d.status),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Earning tab (D5): what the store owes the driver, cash still to return
/// to the store, and tips kept — plus every delivered order behind it.
class _DriverEarningsTab extends StatelessWidget {
  final AppUser profile;

  const _DriverEarningsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('My Earning')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(message: 'Could not load earnings.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final delivered = snapshot.data!
              .where((d) => d.status == DeliveryStatus.delivered)
              .toList();
          final payOwed = delivered.fold<double>(0, (s, d) => s + d.fee);
          final cashOwed = delivered.fold<double>(0, (s, d) => s + d.cashOwed);
          final tips = delivered.fold<double>(0, (s, d) => s + d.tipKept);
          final currency = delivered.isEmpty ? 'USD' : delivered.first.currency;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: WaslTheme.teal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My earnings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Pay owed $currency ${payOwed.toStringAsFixed(2)}  •  Cash to return ${cashOwed.toStringAsFixed(2)}  •  Tips kept ${tips.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Text(
                        'You return all cash to the store and keep the tip. The store pays your fee in cash.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (delivered.isEmpty)
                const Text(
                  'No delivered orders yet.',
                  style: TextStyle(color: Colors.black54),
                ),
              ...delivered.map(
                (d) => Card(
                  child: ListTile(
                    title: Text('#${d.orderNumber} — ${d.storeName}'),
                    subtitle: Text(
                      '${d.items} • fee ${d.money(d.fee)} • tip ${d.money(d.tipKept)} • cash to return ${d.money(d.cashOwed)}${d.driverPaid ? ' • paid' : ' • not paid yet'}',
                    ),
                    trailing: StatusChip(
                      label: d.status.label,
                      color: _driverStatusColor(d.status),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Chat tab (D8): one conversation per delivery, with the store.
/// Only deliveries the driver has or had — nothing else.
class _DriverChatsTab extends StatelessWidget {
  final AppUser profile;

  const _DriverChatsTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.myDeliveriesStream(profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: ErrorBanner(message: 'Could not load chats.'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final mine = snapshot.data!;
          if (mine.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No deliveries yet — your chats with stores will show here.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: mine
                .map(
                  (d) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text('#${d.orderNumber} — ${d.storeName}'),
                      subtitle: Text('${d.items} • ${d.status.label}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ChatScreen(delivery: d, profile: profile),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Ask the user to describe a problem mid-delivery (F5). Returns the
/// typed reason, or null when cancelled.
Future<String?> _askProblemReason(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Report a problem'),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'What went wrong?',
          hintText: 'e.g. customer not answering, wrong address',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Report'),
        ),
      ],
    ),
  );
}

/// The store's real pin (dropped at registration), or null while the
/// store has no pin — the navigate screen falls back to the pilot point.
Future<LatLng?> _storePointFor(Delivery d) async {
  final snap = await FirebaseFirestore.instance
      .collection('stores')
      .where('ownerUid', isEqualTo: d.storeId)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  final data = snap.docs.first.data();
  final lat = (data['storeLat'] as num?)?.toDouble();
  final lng = (data['storeLng'] as num?)?.toDouble();
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

/// Directions to the store FIRST — the driver goes there to pick up, right
/// after accepting. Shared by the job card, the job detail and the pickup
/// code screen.
Future<void> _openStoreDirections(BuildContext context, Delivery d) async {
  final point = await _storePointFor(d);
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NavigateScreen(
        delivery: d,
        leg: NavigateLeg.toStore,
        storePoint: point,
        onArrived: () => Navigator.pop(context),
      ),
    ),
  );
}

/// Start delivering → Navigate (D10) → on arrival, the Delivered form.
/// Shared by the job card and the job detail screen.
Future<void> _startDeliveringFlow(
  BuildContext context,
  Delivery d,
  DeliveryService service,
) async {
  final result = await service.startDelivering(d);
  result.fold((_) async {
    final point = await _storePointFor(d);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NavigateScreen(
            delivery: d,
            storePoint: point,
            onArrived: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      DeliveredFormScreen(delivery: d, service: service),
                ),
              );
            },
          ),
        ),
      );
    }
  }, (m) => _showError(context, m));
}

/// Navigate to the Delivered form (already on the way).
void _openDeliveredForm(
  BuildContext context,
  Delivery d,
  DeliveryService service,
) async {
  final point = await _storePointFor(d);
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NavigateScreen(
        delivery: d,
        storePoint: point,
        onArrived: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DeliveredFormScreen(delivery: d, service: service),
            ),
          );
        },
      ),
    ),
  );
}

class _JobCard extends StatelessWidget {
  final Delivery delivery;
  final AppUser profile;
  final DeliveryService service;
  final Color color;

  const _JobCard({
    required this.delivery,
    required this.profile,
    required this.service,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final isMine = d.driverId == profile.uid;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              JobDetailScreen(delivery: d, profile: profile, service: service),
        ),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '#${d.orderNumber} — ${d.storeName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusChip(label: d.status.label, color: color),
                ],
              ),
              Text('${d.items} • ${d.money(d.orderTotal)}'),
              Text(
                d.customerAddress,
                style: const TextStyle(color: Colors.black54),
              ),
              Text('Fee: ${d.money(d.fee)} • ${d.driverModeLabel}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (d.status == DeliveryStatus.offered)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await service.claimOffer(
                            d,
                            profile.uid,
                            profile.name,
                          );
                          result.fold((_) {}, (m) => _showError(context, m));
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                  if (d.status == DeliveryStatus.assigned && isMine) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await service.acceptAssignment(d);
                          result.fold((_) {}, (m) => _showError(context, m));
                        },
                        child: const Text('Accept'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          // D3: a decline asks for a reason — the store sees
                          // it on S5 and an Auto delivery escalates at once.
                          final reason = await showDialog<String>(
                            context: context,
                            builder: (context) => SimpleDialog(
                              title: const Text('Why decline?'),
                              children: [
                                for (final r in [
                                  'Busy',
                                  'Too far',
                                  'Vehicle problem',
                                  'Other',
                                ])
                                  SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, r),
                                    child: Text(r),
                                  ),
                              ],
                            ),
                          );
                          if (reason == null) return;
                          final result = await service.releaseDelivery(
                            d,
                            reason: reason,
                            declinedBy: profile.name,
                          );
                          result.fold((_) {}, (m) => _showError(context, m));
                        },
                        child: const Text('Decline'),
                      ),
                    ),
                  ],
                  if (d.status == DeliveryStatus.accepted && isMine) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _openStoreDirections(context, d),
                        child: const Text('Directions to store'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PickupCodeScreen(delivery: d, service: service),
                          ),
                        ),
                        child: const Text('Enter pickup code'),
                      ),
                    ),
                  ],
                  if (d.status == DeliveryStatus.pickedUp && isMine)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _startDeliveringFlow(context, d, service),
                        child: const Text('Start delivering'),
                      ),
                    ),
                  if (d.status == DeliveryStatus.delivering && isMine)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _openDeliveredForm(context, d, service),
                        child: const Text('Navigate'),
                      ),
                    ),
                  if (d.status == DeliveryStatus.delivered &&
                      isMine &&
                      d.cashOwed > 0)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await service.markCashReturned(d);
                          result.fold((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Cash marked as returned to the store.',
                                ),
                              ),
                            );
                          }, (m) => _showError(context, m));
                        },
                        child: Text('Cash returned (${d.money(d.cashOwed)})'),
                      ),
                    ),
                ],
              ),
              if (isMine && d.status != DeliveryStatus.offered)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ChatScreen(delivery: d, profile: profile),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat with store'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D4 — pickup code entry. The code comes from the physical order label;
/// it is NEVER shown on driver screens.
class PickupCodeScreen extends StatefulWidget {
  final Delivery delivery;
  final DeliveryService service;

  const PickupCodeScreen({
    super.key,
    required this.delivery,
    required this.service,
  });

  @override
  State<PickupCodeScreen> createState() => _PickupCodeScreenState();
}

class _PickupCodeScreenState extends State<PickupCodeScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.service.confirmPickup(
      widget.delivery,
      _code.text,
    );
    result.fold(
      (_) async {
        // First pickup of a run stop starts the run.
        if (widget.delivery.runId != null) {
          await RunService().markRunActive(widget.delivery.runId!);
        }
        if (mounted) Navigator.pop(context);
      },
      (message) => setState(() {
        _error = message;
        _busy = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pickup #${widget.delivery.orderNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.delivery.storeName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(widget.delivery.items),
            const SizedBox(height: 24),
            const Text(
              'Enter the 4-character code from the order label.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                letterSpacing: 12,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: 'K7M2',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: () => _openStoreDirections(context, widget.delivery),
              icon: const Icon(Icons.directions),
              label: const Text('Directions to the store'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _busy ? null : _confirm,
              child: const Text('Confirm pickup'),
            ),
            const SizedBox(height: 12),
            const Text(
              'No code, no pickup — this stops anyone taking the wrong order.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delivered: photo proof + cash collected + tip kept.
class DeliveredFormScreen extends StatefulWidget {
  final Delivery delivery;
  final DeliveryService service;

  const DeliveredFormScreen({
    super.key,
    required this.delivery,
    required this.service,
  });

  @override
  State<DeliveredFormScreen> createState() => _DeliveredFormScreenState();
}

class _DeliveredFormScreenState extends State<DeliveredFormScreen> {
  final _cash = TextEditingController();
  final _tip = TextEditingController(text: '0');
  String? _photoPath;
  String? _uploadNote;
  String? _error;
  bool _busy = false;
  final _photos = PhotoService();

  @override
  void initState() {
    super.initState();
    _cash.text = widget.delivery.orderTotal.toStringAsFixed(0);
  }

  Future<void> _takePhoto() async {
    final result = await _photos.takeDeliveryPhoto();
    result.fold(
      (path) => setState(() => _photoPath = path),
      (message) => setState(() => _error = message),
    );
  }

  Future<void> _finish() async {
    if (_photoPath == null) {
      setState(() => _error = 'Take a photo of the delivered order first.');
      return;
    }
    final cash = double.tryParse(_cash.text.trim());
    final tip = double.tryParse(_tip.text.trim()) ?? 0;
    if (cash == null) {
      setState(() => _error = 'Enter the cash collected at the door.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // Upload in the background if Cloudinary is configured; the delivery
    // is confirmed regardless — the photo lives on the phone too.
    // The uploaded URL is saved on the delivery so the STORE receives
    // the picture (before this fix the URL was thrown away).
    String? photoUrl;
    final upload = await _photos.uploadPhoto(_photoPath!);
    upload.fold((url) {
      photoUrl = url;
      _uploadNote = url == null
          ? 'Photo saved on this phone (upload not set up yet).'
          : 'Photo uploaded.';
    }, (message) => _uploadNote = message);
    final result = await widget.service.markDelivered(
      widget.delivery,
      photoPath: _photoPath!,
      photoUrl: photoUrl,
      cashCollected: cash,
      tipKept: tip,
    );
    result.fold(
      (_) async {
        // Last stop delivered completes the run.
        if (widget.delivery.runId != null) {
          await RunService().maybeCompleteRun(widget.delivery.runId!);
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Delivered. ${_uploadNote ?? ''} Cash ${widget.delivery.money(cash)} — return it all to the store, keep the tip.',
              ),
            ),
          );
        }
      },
      (message) => setState(() {
        _error = message;
        _busy = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Delivered #${widget.delivery.orderNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.delivery.customerAddress,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(widget.delivery.items),
          const SizedBox(height: 16),
          if (_photoPath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_photoPath!),
                height: 220,
                fit: BoxFit.cover,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take delivery photo'),
            ),
          if (_photoPath != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.refresh),
              label: const Text('Retake photo'),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _cash,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Cash collected at the door (${widget.delivery.currency})',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tip,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Tip kept (${widget.delivery.currency})',
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _busy ? null : _finish,
            child: const Text('Confirm delivered'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cash rule: return ALL cash to the store, get paid later, keep any tip.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// D3 — assignment / job detail. Tap any job on the board to open it:
/// the full order, the store, the fee, and the action for its status.
/// The pickup code is never shown here — it comes from the order label.
class JobDetailScreen extends StatelessWidget {
  final Delivery delivery;
  final AppUser profile;
  final DeliveryService service;

  const JobDetailScreen({
    super.key,
    required this.delivery,
    required this.profile,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Job #${delivery.orderNumber}')),
      body: StreamBuilder<Delivery?>(
        stream: service.deliveryStream(delivery.id),
        builder: (context, snapshot) {
          final d = snapshot.data ?? delivery;
          final mine = d.driverId == profile.uid;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            d.status.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            d.money(d.orderTotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Store: ${d.storeName}'),
                      Text('Customer: ${d.customerName}'),
                      Text('Phone: ${d.customerPhone}'),
                      Text('Address: ${d.customerAddress}'),
                      Text('Items: ${d.items}'),
                      Text('Fee: ${d.money(d.fee)} • ${d.driverModeLabel}'),
                      if (d.declineReason != null)
                        Text(
                          'Last decline: ${d.declinedBy ?? ''} — ${d.declineReason}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (d.status == DeliveryStatus.offered)
                ElevatedButton(
                  onPressed: () async {
                    final result = await service.claimOffer(
                      d,
                      profile.uid,
                      profile.name,
                    );
                    result.fold((_) {
                      if (context.mounted) Navigator.pop(context);
                    }, (m) => _showError(context, m));
                  },
                  child: const Text('Claim this job'),
                ),
              if (d.status == DeliveryStatus.assigned && mine) ...[
                ElevatedButton(
                  onPressed: () async {
                    final result = await service.acceptAssignment(d);
                    result.fold((_) {
                      if (context.mounted) Navigator.pop(context);
                    }, (m) => _showError(context, m));
                  },
                  child: const Text('Accept'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final reason = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('Why decline?'),
                        children: [
                          for (final r in [
                            'Busy',
                            'Too far',
                            'Vehicle problem',
                            'Other',
                          ])
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(context, r),
                              child: Text(r),
                            ),
                        ],
                      ),
                    );
                    if (reason == null) return;
                    final result = await service.releaseDelivery(
                      d,
                      reason: reason,
                      declinedBy: profile.name,
                    );
                    result.fold((_) {
                      if (context.mounted) Navigator.pop(context);
                    }, (m) => _showError(context, m));
                  },
                  child: const Text('Decline'),
                ),
              ],
              if (d.status == DeliveryStatus.accepted && mine) ...[
                OutlinedButton.icon(
                  onPressed: () => _openStoreDirections(context, d),
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions to the store'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PickupCodeScreen(delivery: d, service: service),
                    ),
                  ),
                  child: const Text('Enter pickup code'),
                ),
              ],
              if (d.status == DeliveryStatus.pickedUp && mine)
                ElevatedButton(
                  onPressed: () => _startDeliveringFlow(context, d, service),
                  child: const Text('Start delivering'),
                ),
              if (d.status == DeliveryStatus.delivering && mine)
                ElevatedButton(
                  onPressed: () => _openDeliveredForm(context, d, service),
                  child: const Text('Navigate'),
                ),
              if (d.status == DeliveryStatus.delivered &&
                  mine &&
                  d.cashOwed > 0)
                ElevatedButton(
                  onPressed: () async {
                    final result = await service.markCashReturned(d);
                    result.fold((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cash marked as returned to the store.',
                          ),
                        ),
                      );
                    }, (m) => _showError(context, m));
                  },
                  child: Text('Cash returned (${d.money(d.cashOwed)})'),
                ),
              if (mine && d.status != DeliveryStatus.offered) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(delivery: d, profile: profile),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat with store'),
                ),
              ],
              if (mine &&
                  (d.status == DeliveryStatus.accepted ||
                      d.status == DeliveryStatus.pickedUp ||
                      d.status == DeliveryStatus.delivering)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final reason = await _askProblemReason(context);
                    if (reason == null || reason.isEmpty) return;
                    final result = await service.reportProblem(
                      d,
                      problem: reason,
                      reportedBy: 'driver',
                    );
                    result.fold((_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Problem reported — the store and the admin can see it.',
                            ),
                          ),
                        );
                      }
                    }, (m) => _showError(context, m));
                  },
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Report a problem'),
                ),
              ],
              if (d.problemStatus == 'open' && d.problem != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WaslTheme.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Problem reported: ${d.problem}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'The pickup code is on the physical order label — never on this screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// D2 — job map: open offers as pins on the map. Only deliveries with a
/// location pin (dropped by the store on S2) can be placed — the rest
/// stay in the list. Tap a pin to see the job, then open it.
class JobMapScreen extends StatefulWidget {
  final AppUser profile;
  final DeliveryService service;

  const JobMapScreen({super.key, required this.profile, required this.service});

  @override
  State<JobMapScreen> createState() => _JobMapScreenState();
}

class _JobMapScreenState extends State<JobMapScreen> {
  Delivery? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job map')),
      body: StreamBuilder<List<Delivery>>(
        stream: widget.service.driverBoardStream(widget.profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load jobs: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final offered = snapshot.data!
              .where((d) => d.status == DeliveryStatus.offered)
              .toList();
          final pinned = offered
              .where((d) => d.customerLat != null && d.customerLng != null)
              .toList();
          return Column(
            children: [
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
                      markers: pinned
                          .map(
                            (d) => Marker(
                              point: LatLng(d.customerLat!, d.customerLng!),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => setState(() => _selected = d),
                                child: Icon(
                                  Icons.location_on,
                                  color: _selected?.id == d.id
                                      ? WaslTheme.teal
                                      : WaslTheme.amber,
                                  size: 36,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              if (_selected != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '#${_selected!.orderNumber} — ${_selected!.storeName}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_selected!.items} • ${_selected!.money(_selected!.orderTotal)} • Fee ${_selected!.money(_selected!.fee)}',
                      ),
                      Text(
                        _selected!.customerAddress,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => JobDetailScreen(
                              delivery: _selected!,
                              profile: widget.profile,
                              service: widget.service,
                            ),
                          ),
                        ),
                        child: const Text('View job'),
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
                    pinned.isEmpty
                        ? 'No open jobs with a location pin yet — check the list.'
                        : '${pinned.length} open job${pinned.length == 1 ? '' : 's'} on the map — tap a pin. Jobs without a pin stay in the list.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// D9 — driver profile. Type badge (Own vs Marketplace) front and centre,
/// verification, vehicle, store, and the numbers the store sees plus the
/// driver-only pay/tips/cash-to-return.
class DriverProfileScreen extends StatelessWidget {
  final AppUser profile;

  const DriverProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    final isOwn = profile.role == 'own-driver';
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DriverService().myDriverDocStream(profile.uid),
        builder: (context, docSnapshot) {
          final doc = docSnapshot.data?.docs.firstOrNull?.data();
          final verification = (doc?['verificationStatus'] ?? '').toString();
          final vehicle = (doc?['vehicle'] ?? '').toString();
          final rating = (doc?['rating'] ?? 0).toString();
          final storeId = (doc?['storeId'] ?? '').toString();
          return StreamBuilder<List<Delivery>>(
            stream: service.myDeliveriesStream(profile.uid),
            builder: (context, snapshot) {
              final mine = snapshot.data ?? [];
              final delivered = mine.where(
                (d) => d.status == DeliveryStatus.delivered,
              );
              final payOwed = delivered.fold<double>(0, (s, d) => s + d.fee);
              final cashOwed = delivered.fold<double>(
                0,
                (s, d) => s + d.cashOwed,
              );
              final tips = delivered.fold<double>(0, (s, d) => s + d.tipKept);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: isOwn ? WaslTheme.teal : WaslTheme.marketplaceBlue,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            isOwn ? 'Own driver' : 'Marketplace driver',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            verification.isEmpty
                                ? 'Profile not set up yet'
                                : 'Verification: $verification',
                            style: const TextStyle(color: Colors.white70),
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
                          Text('Vehicle: $vehicle'),
                          Text('Rating: $rating'),
                          if (isOwn && storeId.isNotEmpty)
                            FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              future: FirebaseFirestore.instance
                                  .collection('stores')
                                  .where('ownerUid', isEqualTo: storeId)
                                  .limit(1)
                                  .get(),
                              builder: (context, storeSnapshot) {
                                final storeName =
                                    storeSnapshot.data?.docs.firstOrNull
                                        ?.data()['name'] ??
                                    '';
                                return Text(
                                  'My store: ${storeName.toString().isEmpty ? storeId : storeName}',
                                );
                              },
                            ),
                          Text('Deliveries done: ${delivered.length}'),
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
                            'Pay & cash',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Pay owed: ${delivered.isEmpty ? 'USD' : delivered.first.currency} ${payOwed.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Cash to return: ${cashOwed.toStringAsFixed(2)}',
                          ),
                          Text('Tips kept: ${tips.toStringAsFixed(2)}'),
                          const Text(
                            'Only you see this — the store sees deliveries and ratings, not your pay.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.message),
                      title: const Text('Message the Wasl admin'),
                      subtitle: const Text(
                        'A direct conversation, outside any order',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result =
                            await DirectMessageService().getOrCreateAdminChat(
                          myUid: profile.uid,
                          myName: profile.name,
                        );
                        result.fold((chatId) {
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                chatId: chatId,
                                profile: profile,
                                otherName: 'Wasl admin',
                              ),
                            ),
                          );
                        }, (m) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(m)),
                          );
                        });
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Trip-only location reporter (S10/A6): watches the driver's own
/// deliveries and starts sharing the position while one is active
/// (accepted / picked up / delivering), stops the moment none is.
/// Invisible widget — it only reports, it shows nothing.
class _LocationReporter extends StatefulWidget {
  final String driverDocId;
  final String profileUid;

  const _LocationReporter({
    required this.driverDocId,
    required this.profileUid,
  });

  @override
  State<_LocationReporter> createState() => _LocationReporterState();
}

class _LocationReporterState extends State<_LocationReporter> {
  final _location = LocationService();
  StreamSubscription<List<Delivery>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = DeliveryService()
        .myDeliveriesStream(widget.profileUid)
        .listen((deliveries) {
          final active = deliveries.any(
            (d) =>
                d.status == DeliveryStatus.accepted ||
                d.status == DeliveryStatus.pickedUp ||
                d.status == DeliveryStatus.delivering,
          );
          if (active) {
            _location.start(widget.driverDocId);
          } else {
            _location.stop();
          }
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _location.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// D6 — one batched offer on the board. Whole batch or nothing: the
/// driver never picks stops out of a run.
class _RunCard extends StatelessWidget {
  final Run run;
  final AppUser profile;
  final DeliveryService service;

  const _RunCard({
    required this.run,
    required this.profile,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final r = run;
    final isMine = r.driverId == profile.uid;
    final currency = 'USD';
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RunDetailScreen(run: r, profile: profile, service: service),
        ),
      ),
      child: Card(
        color: WaslTheme.teal.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Run • ${r.deliveryIds.length} stops — ${r.storeName}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  StatusChip(label: r.status.label, color: WaslTheme.teal),
                ],
              ),
              Text(
                'Batch fee ${r.money(r.totalFee, currency)} • Orders ${r.money(r.totalOrder, currency)}',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (r.status == RunStatus.offered)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await RunService().claimRun(
                            r,
                            profile.uid,
                            profile.name,
                          );
                          result.fold((_) {}, (m) => _showError(context, m));
                        },
                        child: const Text('Claim whole run'),
                      ),
                    ),
                  if (r.status == RunStatus.assigned && isMine) ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await RunService().acceptRun(r);
                          result.fold((_) {}, (m) => _showError(context, m));
                        },
                        child: const Text('Accept run'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final result = await RunService().releaseRun(r);
                          result.fold((_) {}, (m) => _showError(context, m));
                        },
                        child: const Text('Decline run'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D7 — active multi-stop run. Each stop is its own delivery: pickup code,
/// navigate, photo proof, cash, chat. The run completes when the last
/// stop is delivered. The store sees the same screen read-only.
class RunDetailScreen extends StatelessWidget {
  final Run run;
  final AppUser profile;
  final DeliveryService service;

  const RunDetailScreen({
    super.key,
    required this.run,
    required this.profile,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final isStore = profile.role == 'store';
    return Scaffold(
      appBar: AppBar(title: Text('Run • ${run.deliveryIds.length} stops')),
      body: StreamBuilder<Run?>(
        stream: RunService().runStream(run.id),
        builder: (context, runSnapshot) {
          final r = runSnapshot.data ?? run;
          return StreamBuilder<List<Delivery>>(
            stream: RunService().runStopsStream(r),
            builder: (context, stopsSnapshot) {
              if (stopsSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ErrorBanner(
                      message: 'Could not load stops: ${stopsSnapshot.error}',
                    ),
                  ),
                );
              }
              if (!stopsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final stops = stopsSnapshot.data!;
              final mine = r.driverId == profile.uid;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                r.status.label,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Batch fee ${r.money(r.totalFee, 'USD')}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Text('Store: ${r.storeName}'),
                          Text('Driver: ${r.driverName ?? 'not assigned yet'}'),
                          Text('Orders total: ${r.money(r.totalOrder, 'USD')}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isStore && r.status == RunStatus.offered)
                    ElevatedButton(
                      onPressed: () async {
                        final result = await RunService().claimRun(
                          r,
                          profile.uid,
                          profile.name,
                        );
                        result.fold((_) {}, (m) => _showError(context, m));
                      },
                      child: const Text('Claim whole run'),
                    ),
                  if (!isStore && r.status == RunStatus.assigned && mine) ...[
                    ElevatedButton(
                      onPressed: () async {
                        final result = await RunService().acceptRun(r);
                        result.fold((_) {}, (m) => _showError(context, m));
                      },
                      child: const Text('Accept run'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await RunService().releaseRun(r);
                        result.fold((_) {
                          if (context.mounted) Navigator.pop(context);
                        }, (m) => _showError(context, m));
                      },
                      child: const Text('Decline whole run'),
                    ),
                  ],
                  if (isStore &&
                      (r.status == RunStatus.offered ||
                          r.status == RunStatus.assigned)) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await RunService().cancelRun(r);
                        result.fold((_) {
                          if (context.mounted) Navigator.pop(context);
                        }, (m) => _showError(context, m));
                      },
                      child: const Text('Cancel run'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'Stops',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...stops.asMap().entries.map((entry) {
                    final i = entry.key;
                    final d = entry.value;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: d.status == DeliveryStatus.delivered
                              ? WaslTheme.okGreen
                              : WaslTheme.teal,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text('#${d.orderNumber} — ${d.customerName}'),
                        subtitle: Text(
                          '${d.items} • ${d.money(d.orderTotal)} • ${d.status.label}',
                        ),
                        trailing: !isStore && mine
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: !isStore && mine
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobDetailScreen(
                                    delivery: d,
                                    profile: profile,
                                    service: service,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  const Text(
                    'Each stop has its own pickup code, photo proof and cash — open a stop to work it. The run completes when the last stop is delivered.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
