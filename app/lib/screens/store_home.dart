import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import '../core/result.dart';
import '../models/app_user.dart';
import '../models/delivery.dart';
import '../models/run.dart';
import '../services/auth_service.dart';
import '../services/delivery_service.dart';
import '../services/direct_message_service.dart';
import '../services/driver_service.dart';
import '../services/run_service.dart';
import '../theme.dart';
import 'announcements_screen.dart';
import 'build_run_screen.dart';
import 'chat_screen.dart';
import 'direct_inbox_screen.dart';
import 'driver_home.dart';
import 'map_pin_picker.dart';
import 'my_drivers_screen.dart';
import 'who_delivers_screen.dart';
import '../widgets/market_paused_banner.dart';
import '../widgets/ofm_map_layer.dart';

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

/// Store home (S1 dashboard + S2 new delivery + S5 live status + S6 cash).
/// The store sees the pickup code on its own screens (S1/S3/S5/S7) —
/// drivers never see it before pickup.
class StoreHome extends StatefulWidget {
  final AppUser profile;
  final AuthService auth;

  const StoreHome({super.key, required this.profile, required this.auth});

  @override
  State<StoreHome> createState() => _StoreHomeState();
}

class _StoreHomeState extends State<StoreHome> {
  String? _storeRecordError;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.auth
        .ensureStoreRecord(widget.profile)
        .then(
          (r) => r.fold((_) {}, (m) {
            if (mounted) setState(() => _storeRecordError = m);
          }),
        );
  }

  Color _statusColor(DeliveryStatus s) => switch (s) {
    DeliveryStatus.offered => Colors.blueGrey,
    DeliveryStatus.assigned => WaslTheme.marketplaceBlue,
    DeliveryStatus.accepted => WaslTheme.teal,
    DeliveryStatus.pickedUp => WaslTheme.teal,
    DeliveryStatus.delivering => WaslTheme.amber,
    DeliveryStatus.delivered => WaslTheme.okGreen,
    DeliveryStatus.cancelled => WaslTheme.danger,
  };

  void _onDeliveryCreated(Delivery d) {
    setState(() => _index = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Delivery #${d.orderNumber} created — pickup code ${d.pickupCode} (on the order label).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    final profile = widget.profile;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _StoreDashboard(
            profile: profile,
            auth: widget.auth,
            service: service,
            storeRecordError: _storeRecordError,
            statusColor: _statusColor,
          ),
          NewDeliveryScreen(
            profile: profile,
            service: service,
            onCreated: _onDeliveryCreated,
          ),
          MyDriversScreen(profile: profile),
          HistoryPayScreen(profile: profile),
          StoreProfileScreen(profile: profile),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        selectedItemColor: WaslTheme.teal,
        unselectedItemColor: Colors.black54,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'New',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'My Drivers',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Cash'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

/// S1 dashboard (Home tab): cash summary, Build a Run, live map,
/// runs and the deliveries list. The other tabs (New, My Drivers, Cash,
/// Profile) live in the bottom nav — this screen no longer links to them.
class _StoreDashboard extends StatelessWidget {
  final AppUser profile;
  final AuthService auth;
  final DeliveryService service;
  final String? storeRecordError;
  final Color Function(DeliveryStatus) statusColor;

  const _StoreDashboard({
    required this.profile,
    required this.auth,
    required this.service,
    required this.storeRecordError,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const WaslAppBarLogo(),
        title: Text('Wasl — ${profile.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<List<Delivery>>(
        stream: service.storeDeliveriesStream(profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load deliveries: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final deliveries = snapshot.data!;
          final delivered = deliveries.where(
            (d) => d.status == DeliveryStatus.delivered,
          );
          final cashCollected = delivered.fold<double>(
            0,
            (s, d) => s + d.cashCollected,
          );
          final cashOwed = delivered.fold<double>(0, (s, d) => s + d.cashOwed);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (storeRecordError != null) ...[
                ErrorBanner(
                  message:
                      'Could not set up your store record: $storeRecordError',
                ),
                const SizedBox(height: 8),
              ],
              const AnnouncementsCard(audience: 'stores'),
              MarketPausedBanner(storeUid: profile.uid),
              Card(
                color: WaslTheme.teal,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cash ledger',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Collected ${deliveries.isEmpty ? 'USD' : deliveries.first.currency} ${cashCollected.toStringAsFixed(2)}  •  Still owed ${cashOwed.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const Text(
                        'Drivers return all cash to the store and keep the tip.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final run = await Navigator.push<Run>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BuildRunScreen(profile: profile),
                    ),
                  );
                  if (run != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Run created — ${run.deliveryIds.length} stops, batch fee ${run.money(run.totalFee, 'USD')}.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.route),
                label: const Text('Build a Run'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreLiveMapScreen(profile: profile),
                  ),
                ),
                icon: const Icon(Icons.map),
                label: const Text('Live map'),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 16),
              const Text(
                'Runs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Run>>(
                stream: RunService().storeRunsStream(profile.uid),
                builder: (context, runsSnapshot) {
                  if (runsSnapshot.hasError) {
                    return ErrorBanner(
                      message: 'Could not load runs: ${runsSnapshot.error}',
                    );
                  }
                  if (!runsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final runs = runsSnapshot.data!
                      .where((r) => r.status != RunStatus.cancelled)
                      .toList();
                  if (runs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'No runs yet.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }
                  return Column(
                    children: runs
                        .map(
                          (r) => Card(
                            child: ListTile(
                              title: Text(
                                'Run • ${r.deliveryIds.length} stops — ${r.driverName ?? 'No driver yet'}',
                              ),
                              subtitle: Text(
                                'Batch fee ${r.money(r.totalFee, 'USD')} • ${r.status.label}',
                              ),
                              trailing: StatusChip(
                                label: r.status.label,
                                color: WaslTheme.teal,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RunDetailScreen(
                                    run: r,
                                    profile: profile,
                                    service: service,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (deliveries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No deliveries yet. Tap “New delivery” to create one.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ...deliveries.map(
                (d) => Card(
                  child: ListTile(
                    title: Text('#${d.orderNumber} — ${d.customerName}'),
                    subtitle: Text(
                      '${d.items} • ${d.money(d.orderTotal)} • ${d.driverName ?? 'No driver yet'}',
                    ),
                    trailing: StatusChip(
                      label: d.status.label,
                      color: statusColor(d.status),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoreDeliveryDetail(
                          delivery: d,
                          profile: profile,
                          service: service,
                        ),
                      ),
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

/// S5 timeline: Accepted → Picked up → On the way → Delivered.
/// Same status words everywhere in the app (IA principle 2).
class _StatusTimeline extends StatelessWidget {
  final DeliveryStatus status;

  const _StatusTimeline({required this.status});

  static const _steps = ['Accepted', 'Picked up', 'On the way', 'Delivered'];

  int get _current => switch (status) {
    DeliveryStatus.accepted => 0,
    DeliveryStatus.pickedUp => 1,
    DeliveryStatus.delivering => 2,
    DeliveryStatus.delivered => 3,
    _ => -1,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: i <= _current ? WaslTheme.teal : Colors.black12,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  i <= _current ? Icons.check : Icons.circle_outlined,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _steps[i],
                style: TextStyle(
                  fontWeight: i == _current ? FontWeight.w700 : FontWeight.w400,
                  color: i <= _current ? Colors.black87 : Colors.black45,
                ),
              ),
            ],
          ),
        if (_current == -1)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Waiting for a driver.',
              style: TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }
}

/// S2 — create a delivery. Assign to one of my own drivers, or leave it as
/// an open marketplace offer.
class NewDeliveryScreen extends StatefulWidget {
  final AppUser profile;
  final DeliveryService service;

  /// When set (the New tab in the bottom nav), a created delivery is
  /// reported here instead of popping the screen — a tab has nowhere to pop to.
  final void Function(Delivery)? onCreated;

  const NewDeliveryScreen({
    super.key,
    required this.profile,
    required this.service,
    this.onCreated,
  });

  @override
  State<NewDeliveryScreen> createState() => _NewDeliveryScreenState();
}

class _NewDeliveryScreenState extends State<NewDeliveryScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _items = TextEditingController();
  final _total = TextEditingController();
  final _fee = TextEditingController(text: '6');
  LatLng? _pin;
  String? _error;

  Future<void> _pickPin() async {
    final address = _address.text.trim();
    // The picker pops a LatLng to set the pin, `false` to clear it,
    // and null when the store just goes back (pin unchanged).
    final picked = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPinPicker(
          address: address.isEmpty ? 'Delivery location' : address,
          initialPin: _pin,
        ),
      ),
    );
    if (picked is LatLng) {
      setState(() => _pin = picked);
    } else if (picked == false) {
      setState(() => _pin = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New delivery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Customer name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Customer phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Delivery address'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickPin,
            icon: const Icon(Icons.location_on),
            label: Text(
              _pin == null
                  ? 'Pin the location on the map'
                  : 'Pin set: ${_pin!.latitude.toStringAsFixed(5)}, ${_pin!.longitude.toStringAsFixed(5)} — tap to move it',
            ),
          ),
          const Text(
            'Some addresses are not on the map — drop the pin on the exact spot so the driver finds it.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _items,
            decoration: const InputDecoration(
              labelText: 'Items (e.g. 2x Mint Tea, 1x Croissant)',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _total,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Order total'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fee,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Delivery fee'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _continue,
            child: const Text('Continue: who delivers?'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Next step: pick who delivers — your driver, the marketplace, or Auto.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    final total = double.tryParse(_total.text.trim());
    final fee = double.tryParse(_fee.text.trim());
    if (_name.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _items.text.trim().isEmpty ||
        total == null ||
        fee == null) {
      setState(
        () => _error = 'Fill in the customer, address, items, total and fee.',
      );
      return;
    }
    final created = await Navigator.push<Delivery>(
      context,
      MaterialPageRoute(
        builder: (_) => WhoDeliversScreen(
          profile: widget.profile,
          service: widget.service,
          draft: DeliveryDraft(
            customerName: _name.text.trim(),
            customerPhone: _phone.text.trim(),
            customerAddress: _address.text.trim(),
            customerLat: _pin?.latitude,
            customerLng: _pin?.longitude,
            items: _items.text.trim(),
            orderTotal: total,
            fee: fee,
          ),
        ),
      ),
    );
    if (created != null && mounted) {
      if (widget.onCreated != null) {
        widget.onCreated!(created);
        _resetForm();
      } else {
        Navigator.pop(context, created);
      }
    }
  }

  void _resetForm() {
    _name.clear();
    _phone.clear();
    _address.clear();
    _items.clear();
    _total.clear();
    _fee.text = '6';
    setState(() {
      _pin = null;
      _error = null;
    });
  }
}

/// Store delivery detail — shows the pickup code (store side only).
class StoreDeliveryDetail extends StatelessWidget {
  final Delivery delivery;
  final AppUser profile;
  final DeliveryService service;

  const StoreDeliveryDetail({
    super.key,
    required this.delivery,
    required this.profile,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order #${delivery.orderNumber}')),
      body: StreamBuilder<Delivery?>(
        stream: service.deliveryStream(delivery.id),
        builder: (context, snapshot) {
          final d = snapshot.data ?? delivery;
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
                      Text('${d.customerName} • ${d.customerPhone}'),
                      Text(d.customerAddress),
                      Text(d.items),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: WaslTheme.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code, color: WaslTheme.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pickup code: ${d.pickupCode} — print it on the order label. Read it out if the label is unreadable.',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Driver: ${d.driverName ?? 'not assigned yet'}'
                        ' (${d.driverModeLabel})',
                      ),
                      if (d.declineReason != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: WaslTheme.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${d.declinedBy ?? 'The driver'} declined: ${d.declineReason} — the delivery is back as an open offer.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (d.status == DeliveryStatus.assigned &&
                          d.autoEscalate) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () async {
                            final result = await service.escalateToMarketplace(
                              d,
                            );
                            result.fold((_) {}, (m) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(m)));
                              }
                            });
                          },
                          child: const Text('Escalate to marketplace now'),
                        ),
                      ],
                      Text('Delivery fee: ${d.money(d.fee)}'),
                      if (d.status == DeliveryStatus.delivered) ...[
                        Text('Cash collected: ${d.money(d.cashCollected)}'),
                        Text('Cash returned: ${d.money(d.cashReturned)}'),
                        Text('Tip kept by driver: ${d.money(d.tipKept)}'),
                        if (d.cashOwed > 0)
                          Text(
                            'Still owed: ${d.money(d.cashOwed)}',
                            style: const TextStyle(
                              color: WaslTheme.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // S5 timeline: Accepted → Picked up → On the way → Delivered.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (d.status == DeliveryStatus.cancelled)
                        const Text(
                          'Cancelled',
                          style: TextStyle(
                            color: WaslTheme.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        _StatusTimeline(status: d.status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (d.customerLat != null && d.customerLng != null)
                SizedBox(
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(d.customerLat!, d.customerLng!),
                        initialZoom: 16,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        const OfmMapLayer(),
                        SimpleAttributionWidget(
                          source: const Text('© OpenStreetMap contributors'),
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(d.customerLat!, d.customerLng!),
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_on,
                                color: WaslTheme.amber,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(delivery: d, profile: profile),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat with driver'),
              ),
              if (d.status != DeliveryStatus.delivered &&
                  d.status != DeliveryStatus.cancelled) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final reason = await _askProblemReason(context);
                    if (reason == null || reason.isEmpty) return;
                    final result = await service.reportProblem(
                      d,
                      problem: reason,
                      reportedBy: 'store',
                    );
                    result.fold(
                      (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Problem reported — the driver and the admin can see it.',
                              ),
                            ),
                          );
                        }
                      },
                      (m) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(m)));
                        }
                      },
                    );
                  },
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Report a problem'),
                ),
              ],
              if (d.problemStatus == 'open' && d.problem != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: WaslTheme.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Problem reported (${d.problemBy ?? ''}): ${d.problem}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final link =
                      'https://benyahya7.github.io/wasl/track.html?d=${d.id}&t=${d.trackingToken}';
                  await Clipboard.setData(ClipboardData(text: link));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tracking link copied — send it to the customer. No app needed to open it.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.link),
                label: const Text('Share tracking link'),
              ),
              if (d.status == DeliveryStatus.delivered) ...[
                const SizedBox(height: 12),
                if (d.photoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(d.photoUrl!),
                  )
                else
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Photo proof stays on the driver\'s phone until photo uploads land.',
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              if (d.status == DeliveryStatus.offered ||
                  d.status == DeliveryStatus.assigned)
                ElevatedButton(
                  onPressed: () async {
                    final result = await service.cancelDelivery(d);
                    result.fold(
                      (_) {
                        if (context.mounted) Navigator.pop(context);
                      },
                      (message) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WaslTheme.danger,
                  ),
                  child: const Text('Cancel delivery'),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// S10 — store live map: the store's active deliveries as pins (where the
/// customer is) and its drivers' live positions while they are on a job.
/// Driver positions only appear while a driver is on an active job — the
/// app never tracks drivers all day — and only if the position is fresh
/// (under 10 minutes old). Deliveries without a dropped pin have no
/// position to show and stay in the list.
class StoreLiveMapScreen extends StatefulWidget {
  final AppUser profile;

  const StoreLiveMapScreen({super.key, required this.profile});

  @override
  State<StoreLiveMapScreen> createState() => _StoreLiveMapScreenState();
}

class _StoreLiveMapScreenState extends State<StoreLiveMapScreen> {
  Delivery? _selectedDelivery;
  Map<String, dynamic>? _selectedDriver;

  bool _fresh(Map<String, dynamic> d) {
    final seen = d['lastSeen'];
    if (seen == null) return false;
    final when = (seen as Timestamp).toDate();
    return DateTime.now().difference(when).inMinutes < 10;
  }

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('Live map')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.storeDeliveriesStream(widget.profile.uid),
        builder: (context, deliveriesSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: DriverService().storeDriversStream(widget.profile.uid),
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
              final active = deliveriesSnapshot.data!
                  .where(
                    (d) =>
                        (d.status == DeliveryStatus.accepted ||
                            d.status == DeliveryStatus.pickedUp ||
                            d.status == DeliveryStatus.delivering) &&
                        d.customerLat != null &&
                        d.customerLng != null,
                  )
                  .toList();
              final drivers = driversSnapshot.data!.docs
                  .map((doc) => doc.data())
                  .where(
                    (d) =>
                        d['lastLat'] != null &&
                        d['lastLng'] != null &&
                        _fresh(d),
                  )
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
                          markers: [
                            ...active.map(
                              (d) => Marker(
                                point: LatLng(d.customerLat!, d.customerLng!),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedDelivery = d;
                                    _selectedDriver = null;
                                  }),
                                  child: Icon(
                                    Icons.location_on,
                                    color: d.status == DeliveryStatus.accepted
                                        ? WaslTheme.amber
                                        : WaslTheme.teal,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ),
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
                            '#${_selectedDelivery!.orderNumber} — ${_selectedDelivery!.customerName}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${_selectedDelivery!.items} • ${_selectedDelivery!.status.label} • Driver ${_selectedDelivery!.driverName ?? '—'}',
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoreDeliveryDetail(
                                  delivery: _selectedDelivery!,
                                  profile: widget.profile,
                                  service: service,
                                ),
                              ),
                            ),
                            child: const Text('View delivery'),
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
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
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
                            : '${active.length} active deliver${active.length == 1 ? 'y' : 'ies'} • ${drivers.length} driver${drivers.length == 1 ? '' : 's'} sharing a live position. Tap a pin.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
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

/// S6 — History & pay: the full cash ledger. Every delivered order with
/// cash collected / returned / still owed, plus whether the driver has
/// been paid their fee. "Mark driver paid" appears only once the cash is
/// back at the store (returned == collected) — the store pays the driver
/// in cash after that, and the ledger records it.
class HistoryPayScreen extends StatefulWidget {
  final AppUser profile;

  const HistoryPayScreen({super.key, required this.profile});

  @override
  State<HistoryPayScreen> createState() => _HistoryPayScreenState();
}

class _HistoryPayScreenState extends State<HistoryPayScreen> {
  String _filter = 'all'; // 'all' | 'owed' | 'paid'
  String? _error;

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('History & pay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportsScreen(profile: widget.profile),
              ),
            ),
            tooltip: 'Reports',
          ),
        ],
      ),
      body: StreamBuilder<List<Delivery>>(
        stream: service.storeDeliveriesStream(widget.profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load history: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final delivered = snapshot.data!
              .where((d) => d.status == DeliveryStatus.delivered)
              .toList();
          final collected = delivered.fold<double>(
            0,
            (s, d) => s + d.cashCollected,
          );
          final returned = delivered.fold<double>(
            0,
            (s, d) => s + d.cashReturned,
          );
          final owed = collected - returned;
          final payOwed = delivered
              .where((d) => !d.driverPaid)
              .fold<double>(0, (s, d) => s + d.fee);
          final visible = delivered.where((d) {
            if (_filter == 'owed') return d.cashOwed > 0 || !d.driverPaid;
            if (_filter == 'paid') return d.driverPaid && d.cashOwed == 0;
            return true;
          }).toList();
          final currency = delivered.isEmpty ? 'USD' : delivered.first.currency;
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: WaslTheme.teal,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collected $currency ${collected.toStringAsFixed(2)}  •  Returned ${returned.toStringAsFixed(2)}  •  Still owed ${owed.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Driver pay still owed: $currency ${payOwed.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Owed'),
                      selected: _filter == 'owed',
                      onSelected: (_) => setState(() => _filter = 'owed'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Paid'),
                      selected: _filter == 'paid',
                      onSelected: (_) => setState(() => _filter = 'paid'),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorBanner(message: _error!),
                ),
              Expanded(
                child: visible.isEmpty
                    ? const Center(
                        child: Text(
                          'Nothing here yet.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: visible.map((d) {
                          final canPay = d.cashOwed == 0 && !d.driverPaid;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '#${d.orderNumber} — ${d.customerName} • ${d.driverName ?? '—'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '${d.items} • ${d.money(d.orderTotal)} • Fee ${d.money(d.fee)}',
                                  ),
                                  Text(
                                    'Cash: collected ${d.money(d.cashCollected)} • returned ${d.money(d.cashReturned)} • owed ${d.money(d.cashOwed)}',
                                  ),
                                  Text(
                                    d.driverPaid
                                        ? 'Driver paid ✓'
                                        : 'Driver not paid yet',
                                  ),
                                  if (canPay) ...[
                                    const SizedBox(height: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final result = await service
                                            .markDriverPaid(d);
                                        result.fold(
                                          (_) {},
                                          (m) => setState(() => _error = m),
                                        );
                                      },
                                      child: const Text(
                                        'Mark driver paid in cash',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reports — printable summaries for taxes or the workday. The store picks
/// a period (today / this week / this month); the report lists every
/// delivered order in that period with cash collected / returned / owed,
/// driver fees and tips. "Share report" opens the phone's share sheet, so
/// the store can send it to a printer, email or WhatsApp and print it there.
/// "Copy report" puts the same text on the clipboard. No paid plugin.
class ReportsScreen extends StatefulWidget {
  final AppUser profile;

  const ReportsScreen({super.key, required this.profile});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _range = 'today'; // 'today' | 'week' | 'month'
  String? _error;

  DateTime get _start {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      'week' => today.subtract(const Duration(days: 7)),
      'month' => DateTime(now.year, now.month, 1),
      _ => today,
    };
  }

  String get _rangeLabel => switch (_range) {
    'week' => 'This week',
    'month' => 'This month',
    _ => 'Today',
  };

  String _buildReportText(
    List<Delivery> delivered,
    String currency,
    String storeName,
  ) {
    final count = delivered.length;
    final orderTotal = delivered.fold<double>(0, (s, d) => s + d.orderTotal);
    final collected = delivered.fold<double>(0, (s, d) => s + d.cashCollected);
    final returned = delivered.fold<double>(0, (s, d) => s + d.cashReturned);
    final owed = collected - returned;
    final fees = delivered.fold<double>(0, (s, d) => s + d.fee);
    final feesOwed = delivered
        .where((d) => !d.driverPaid)
        .fold<double>(0, (s, d) => s + d.fee);
    final tips = delivered.fold<double>(0, (s, d) => s + d.tipKept);
    final lines = StringBuffer()
      ..writeln('Wasl — Delivery report — $storeName')
      ..writeln('Period: $_rangeLabel')
      ..writeln('')
      ..writeln('Deliveries: $count')
      ..writeln('Order totals: $currency ${orderTotal.toStringAsFixed(2)}')
      ..writeln('Cash collected: $currency ${collected.toStringAsFixed(2)}')
      ..writeln(
        'Cash returned to store: $currency ${returned.toStringAsFixed(2)}',
      )
      ..writeln('Cash still owed: $currency ${owed.toStringAsFixed(2)}')
      ..writeln(
        'Driver fees: $currency ${fees.toStringAsFixed(2)} (still owed to drivers: ${feesOwed.toStringAsFixed(2)})',
      )
      ..writeln('Tips kept by drivers: $currency ${tips.toStringAsFixed(2)}')
      ..writeln('')
      ..writeln('Deliveries:');
    for (final d in delivered) {
      lines.writeln(
        '#${d.orderNumber} — ${d.customerName} — ${d.items} — total $currency ${d.orderTotal.toStringAsFixed(2)} — cash ${d.cashCollected.toStringAsFixed(2)} / returned ${d.cashReturned.toStringAsFixed(2)} — fee ${d.fee.toStringAsFixed(2)}${d.driverPaid ? ' (driver paid)' : ''}',
      );
    }
    return lines.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: StreamBuilder<List<Delivery>>(
        stream: DeliveryService().storeDeliveriesStream(widget.profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load deliveries: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final start = _start;
          final delivered = snapshot.data!
              .where(
                (d) =>
                    d.status == DeliveryStatus.delivered &&
                    (d.createdAt == null || !d.createdAt!.isBefore(start)),
              )
              .toList();
          final currency = delivered.isEmpty ? 'USD' : delivered.first.currency;
          final report = _buildReportText(
            delivered,
            currency,
            widget.profile.name,
          );
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Today'),
                      selected: _range == 'today',
                      onSelected: (_) => setState(() => _range = 'today'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('This week'),
                      selected: _range == 'week',
                      onSelected: (_) => setState(() => _range = 'week'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('This month'),
                      selected: _range == 'month',
                      onSelected: (_) => setState(() => _range = 'month'),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorBanner(message: _error!),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await Share.share(
                              report,
                              subject: 'Wasl report — $_rangeLabel',
                            );
                          } catch (e) {
                            setState(() => _error = 'Could not share: $e');
                          }
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share report'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: report));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report copied.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy report'),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Share it to a printer, email or WhatsApp to print it — for taxes or the workday.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
              Expanded(
                child: delivered.isEmpty
                    ? const Center(
                        child: Text(
                          'No delivered orders in this period.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            color: WaslTheme.teal,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                report.split('\n').take(9).join('\n'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          ...delivered.map(
                            (d) => Card(
                              child: ListTile(
                                title: Text(
                                  '#${d.orderNumber} — ${d.customerName}',
                                ),
                                subtitle: Text(
                                  '${d.items} • total ${d.money(d.orderTotal)} • cash ${d.money(d.cashCollected)} / returned ${d.money(d.cashReturned)} • fee ${d.money(d.fee)}${d.driverPaid ? ' • driver paid' : ''}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// S9 — store profile: the store's own record (name, address, market,
/// zone, payment methods, fees, verification). Name and address are
/// editable by the owner; payment, fees and verification stay admin-only.
class StoreProfileScreen extends StatefulWidget {
  final AppUser profile;

  const StoreProfileScreen({super.key, required this.profile});

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  String? _error;
  bool _saved = false;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store profile')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('stores')
            .where('ownerUid', isEqualTo: widget.profile.uid)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                  message: 'Could not load profile: ${snapshot.error}',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No store record yet — it is created when you first open the store home.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final doc = docs.first;
          final d = doc.data();
          if (!_loaded) {
            _name.text = (d['name'] ?? '').toString();
            _address.text = (d['address'] ?? '').toString();
            _loaded = true;
          }
          final methods = Map<String, dynamic>.from(d['paymentMethods'] ?? {});
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
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Store name',
                        ),
                      ),
                      TextField(
                        controller: _address,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await guard(
                            () => FirebaseFirestore.instance
                                .collection('stores')
                                .doc(doc.id)
                                .update({
                                  'name': _name.text.trim(),
                                  'address': _address.text.trim(),
                                }),
                          );
                          result.fold(
                            (_) => setState(() => _saved = true),
                            (m) => setState(() => _error = m),
                          );
                        },
                        child: const Text('Save name & address'),
                      ),
                      if (_saved)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Saved.',
                            style: TextStyle(color: WaslTheme.okGreen),
                          ),
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
                      Text('Market: ${(d['market'] ?? '').toString()}'),
                      Text('Zone: ${(d['zone'] ?? '').toString()}'),
                      Text(
                        'Payment: cash ${methods['cash'] == true ? 'on' : 'off'} • card ${methods['card'] == true ? 'on' : 'off'}',
                      ),
                      Text(
                        'Per-delivery fee: ${(d['perDeliveryFee'] ?? 'not set').toString()} • Monthly plan: ${(d['monthlyPlan'] ?? 'not set').toString()}',
                      ),
                      Text(
                        'Verification: ${(d['verificationStatus'] ?? '').toString()}',
                      ),
                      const Text(
                        'Payment, fees and verification are set by the admin.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Manage',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: const Text('My Drivers'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MyDriversScreen(profile: widget.profile),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.payments),
                      title: const Text('History & pay'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              HistoryPayScreen(profile: widget.profile),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.summarize),
                      title: const Text('Reports'),
                      subtitle: const Text(
                        'Printable summaries for taxes or work',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReportsScreen(profile: widget.profile),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.map),
                      title: const Text('Live map'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              StoreLiveMapScreen(profile: widget.profile),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.message),
                      title: const Text('Message the Wasl admin'),
                      subtitle: const Text(
                        'A direct conversation, outside any order',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result =
                            await DirectMessageService().getOrCreateAdminChat(
                          myUid: widget.profile.uid,
                          myName: widget.profile.name,
                        );
                        result.fold((chatId) {
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DirectChatScreen(
                                chatId: chatId,
                                profile: widget.profile,
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
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
