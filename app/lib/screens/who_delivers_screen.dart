import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/delivery_service.dart';
import '../services/driver_service.dart';
import '../theme.dart';

/// The delivery form, carried from S2 into S3.
class DeliveryDraft {
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final double? customerLat;
  final double? customerLng;
  final String items;
  final double orderTotal;
  final double fee;

  const DeliveryDraft({
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerLat,
    this.customerLng,
    required this.items,
    required this.orderTotal,
    required this.fee,
  });
}

/// S3 — Who delivers? My driver / Marketplace / Auto.
/// Auto means my driver first, then the marketplace if they decline or
/// don't answer. The automatic 2-minute switch needs the server piece
/// (Blaze Cloud Function, pending); until then the store escalates with
/// one tap on S5, and a decline escalates immediately.
class WhoDeliversScreen extends StatefulWidget {
  final AppUser profile;
  final DeliveryService service;
  final DeliveryDraft draft;

  const WhoDeliversScreen({
    super.key,
    required this.profile,
    required this.service,
    required this.draft,
  });

  @override
  State<WhoDeliversScreen> createState() => _WhoDeliversScreenState();
}

class _WhoDeliversScreenState extends State<WhoDeliversScreen> {
  String _mode = 'marketplace'; // 'my-driver' | 'marketplace' | 'auto'
  String? _driverId;
  String? _driverName;
  String? _error;
  bool _busy = false;

  Future<void> _create() async {
    if ((_mode == 'my-driver' || _mode == 'auto') && _driverId == null) {
      setState(() => _error = 'Pick one of your drivers first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final d = widget.draft;
    final result = await widget.service.createDelivery(
      storeUid: widget.profile.uid,
      storeName: widget.profile.name,
      customerName: d.customerName,
      customerPhone: d.customerPhone,
      customerAddress: d.customerAddress,
      customerLat: d.customerLat,
      customerLng: d.customerLng,
      items: d.items,
      orderTotal: d.orderTotal,
      fee: d.fee,
      driverId: _mode == 'marketplace' ? null : _driverId,
      driverName: _mode == 'marketplace' ? null : _driverName,
      driverMode: _mode,
      autoEscalate: _mode == 'auto',
    );
    result.fold(
      (delivery) {
        if (!mounted) return;
        Navigator.pop(context, delivery);
      },
      (message) => setState(() {
        _error = message;
        _busy = false;
      }),
    );
  }

  Widget _driverPicker(String mode) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              child: Text(
                'No approved own drivers yet. Your drivers sign up in the app, pick your store, and appear in My Drivers once the admin approves them.',
              ),
            ),
          );
        }
        return Column(
          children: drivers.map((doc) {
            final d = doc.data();
            return RadioListTile<String>(
              title: Text((d['name'] ?? '').toString()),
              subtitle: Text(
                  'Vehicle: ${(d['vehicle'] ?? '').toString()} • Rating: ${(d['rating'] ?? 0).toString()}'),
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
    final d = widget.draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Who delivers?')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '#${d.customerName} • ${d.customerAddress}\n${d.items} • ${d.orderTotal.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          RadioListTile<String>(
            title: const Text('My driver'),
            subtitle:
                const Text('Assign it to one of your own drivers'),
            value: 'my-driver',
            groupValue: _mode,
            onChanged: (v) => setState(() {
              _mode = v!;
              _driverId = null;
              _driverName = null;
            }),
          ),
          if (_mode == 'my-driver') _driverPicker('my-driver'),
          RadioListTile<String>(
            title: const Text('Marketplace'),
            subtitle: const Text(
                'Open offer — any approved marketplace driver can claim it'),
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
            subtitle: const Text(
                'Your driver first. If they decline or don\'t answer, it goes to the marketplace.'),
            value: 'auto',
            groupValue: _mode,
            onChanged: (v) => setState(() {
              _mode = v!;
              _driverId = null;
              _driverName = null;
            }),
          ),
          if (_mode == 'auto') ...[
            _driverPicker('auto'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'The automatic 2-minute switch needs the server piece — until then, if your driver has not accepted, escalate to the marketplace with one tap from the delivery screen. A decline escalates right away.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _busy ? null : _create,
            child: const Text('Create delivery'),
          ),
          const SizedBox(height: 8),
          const Text(
            'A 4-character pickup code is generated for the order label. '
            'The driver enters it at pickup — no code, no pickup.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
