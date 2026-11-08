import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/delivery.dart';
import '../services/delivery_service.dart';
import '../services/driver_service.dart';
import '../services/run_service.dart';
import '../theme.dart';

/// S7 — Build a Run: the store groups 2–5 open offers into one batch.
/// The stops stay in the order the store picks them — automatic route
/// optimisation needs the Mapbox token (the screen says so).
/// Batch total is the sum of the stops' fees (the batch pricing rule is
/// still open — the prototype's $18.50 was an example, not a rule).
class BuildRunScreen extends StatefulWidget {
  final AppUser profile;

  const BuildRunScreen({super.key, required this.profile});

  @override
  State<BuildRunScreen> createState() => _BuildRunScreenState();
}

class _BuildRunScreenState extends State<BuildRunScreen> {
  final _selected = <String>{};
  String _mode = 'marketplace'; // 'my-driver' | 'marketplace' | 'auto'
  String? _driverId;
  String? _driverName;
  String? _error;
  bool _busy = false;

  Future<void> _create(List<Delivery> stops) async {
    if (_selected.length < 2 || _selected.length > 5) {
      setState(() => _error = 'Pick 2 to 5 stops for a run.');
      return;
    }
    if ((_mode == 'my-driver' || _mode == 'auto') && _driverId == null) {
      setState(() => _error = 'Pick one of your drivers first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final picked =
        stops.where((d) => _selected.contains(d.id)).toList();
    final result = await RunService().createRun(
      storeUid: widget.profile.uid,
      storeName: widget.profile.name,
      stops: picked,
      driverMode: _mode,
      driverId: _mode == 'marketplace' ? null : _driverId,
      driverName: _mode == 'marketplace' ? null : _driverName,
    );
    result.fold(
      (run) {
        if (!mounted) return;
        Navigator.pop(context, run);
      },
      (message) => setState(() {
        _error = message;
        _busy = false;
      }),
    );
  }

  Widget _driverPicker() {
    return StreamBuilder(
      stream: DriverService().storeDriversStream(widget.profile.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorBanner(
              message: 'Could not load drivers: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final drivers = snapshot.data!.docs.where((doc) {
          final d = doc.data();
          return (d['verificationStatus'] ?? '') == 'approved';
        }).toList();
        if (drivers.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No approved own drivers yet.'),
            ),
          );
        }
        return Column(
          children: drivers.map((doc) {
            final d = doc.data();
            return RadioListTile<String>(
              title: Text((d['name'] ?? '').toString()),
              value: (d['userUid'] ?? '').toString(),
              groupValue: _driverId,
              onChanged: (v) => setState(() {
                _driverId = v;
                _driverName = (d['name'] ?? '').toString();
              }),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = DeliveryService();
    return Scaffold(
      appBar: AppBar(title: const Text('Build a Run')),
      body: StreamBuilder<List<Delivery>>(
        stream: service.storeDeliveriesStream(widget.profile.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                    message: 'Could not load deliveries: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final open = snapshot.data!
              .where((d) =>
                  d.status == DeliveryStatus.offered && d.runId == null)
              .toList();
          final picked =
              open.where((d) => _selected.contains(d.id)).toList();
          final totalFee =
              picked.fold<double>(0, (s, d) => s + d.fee);
          final totalOrder =
              picked.fold<double>(0, (s, d) => s + d.orderTotal);
          final currency = picked.isEmpty
              ? 'USD'
              : picked.first.currency;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Pick 2 to 5 open deliveries. They become one batch offer — the driver takes all of them or none.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 8),
              if (open.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No open deliveries to group. Create deliveries first.'),
                  ),
                ),
              ...open.map((d) => CheckboxListTile(
                    title: Text('#${d.orderNumber} — ${d.customerName}'),
                    subtitle: Text(
                        '${d.items} • ${d.money(d.orderTotal)} • Fee ${d.money(d.fee)}'),
                    value: _selected.contains(d.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          if (_selected.length < 5) _selected.add(d.id);
                        } else {
                          _selected.remove(d.id);
                        }
                      });
                    },
                  )),
              const SizedBox(height: 8),
              Card(
                color: WaslTheme.teal.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${_selected.length} stop${_selected.length == 1 ? '' : 's'} • Batch fee $currency ${totalFee.toStringAsFixed(2)} • Orders total $currency ${totalOrder.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      const Text(
                        'Batch fee is the sum of the stops\' fees for now — the batch pricing rule is still to decide.',
                        style:
                            TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                      const Text(
                        'Stops stay in the order you pick them — automatic route optimisation needs the Mapbox token.',
                        style:
                            TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Who takes the run?',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              RadioListTile<String>(
                title: const Text('My driver'),
                value: 'my-driver',
                groupValue: _mode,
                onChanged: (v) => setState(() {
                  _mode = v!;
                  _driverId = null;
                  _driverName = null;
                }),
              ),
              if (_mode == 'my-driver') _driverPicker(),
              RadioListTile<String>(
                title: const Text('Marketplace'),
                subtitle: const Text('Open batch offer — one driver takes it all'),
                value: 'marketplace',
                groupValue: _mode,
                onChanged: (v) => setState(() {
                  _mode = v!;
                  _driverId = null;
                  _driverName = null;
                }),
              ),
              RadioListTile<String>(
                title: const Text('Auto'),
                subtitle: const Text('Your driver first, then the marketplace'),
                value: 'auto',
                groupValue: _mode,
                onChanged: (v) => setState(() {
                  _mode = v!;
                  _driverId = null;
                  _driverName = null;
                }),
              ),
              if (_mode == 'auto') _driverPicker(),
              const SizedBox(height: 16),
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: _busy ? null : () => _create(open),
                child: const Text('Create run'),
              ),
            ],
          );
        },
      ),
    );
  }
}
