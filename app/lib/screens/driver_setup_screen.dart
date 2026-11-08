import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/driver_service.dart';
import '../theme.dart';

/// One-time driver setup, shown to an approved driver who has no driver
/// record yet (S4 needs the record to exist before a store can pick them).
/// Own drivers pick their store from the approved stores list; marketplace
/// drivers skip that step. The record is created as pending — the admin
/// approves it before the store can assign them directly.
class DriverSetupScreen extends StatefulWidget {
  final AppUser profile;

  const DriverSetupScreen({super.key, required this.profile});

  @override
  State<DriverSetupScreen> createState() => _DriverSetupScreenState();
}

class _DriverSetupScreenState extends State<DriverSetupScreen> {
  final _name = TextEditingController();
  String _vehicle = 'car';
  String? _storeId;
  String? _error;
  bool _busy = false;

  static const _vehicles = ['car', 'bike', 'scooter', 'on foot'];

  @override
  void initState() {
    super.initState();
    _name.text = widget.profile.name;
    // Prefill from what the driver gave at sign-up (vehicle + store) so
    // they only confirm it here instead of entering it twice.
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .get()
        .then((doc) {
      if (!mounted) return;
      final d = doc.data() ?? {};
      final vehicle = (d['vehicle'] ?? '').toString();
      final storeId = (d['storeId'] ?? '').toString();
      if (vehicle.isNotEmpty || storeId.isNotEmpty) {
        setState(() {
          if (_vehicles.contains(vehicle)) _vehicle = vehicle;
          if (storeId.isNotEmpty) _storeId = storeId;
        });
      }
    });
  }

  bool get _isOwnDriver => widget.profile.role == 'own-driver';

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    if (_isOwnDriver && _storeId == null) {
      setState(() => _error = 'Pick the store you drive for.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await DriverService().createDriverProfile(
      uid: widget.profile.uid,
      name: name,
      type: widget.profile.role,
      storeId: _isOwnDriver ? _storeId : null,
      vehicle: _vehicle,
    );
    result.fold(
      (_) {
        // The stream in DriverHome sees the new record and moves on.
      },
      (m) => setState(() {
        _error = m;
        _busy = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your driver profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _isOwnDriver
                ? 'You drive for one store. Pick it below — the store sees you in My Drivers once the admin approves your profile.'
                : 'You take deliveries from any store. Set up your profile once and you are on the board.',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
          ),
          const SizedBox(height: 16),
          const Text('Vehicle',
              style: TextStyle(fontWeight: FontWeight.w600)),
          Wrap(
            spacing: 8,
            children: _vehicles
                .map((v) => ChoiceChip(
                      label: Text(v),
                      selected: _vehicle == v,
                      onSelected: (_) => setState(() => _vehicle = v),
                    ))
                .toList(),
          ),
          if (_isOwnDriver) ...[
            const SizedBox(height: 16),
            const Text('My store',
                style: TextStyle(fontWeight: FontWeight.w600)),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: DriverService().approvedStoresStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorBanner(
                      message: 'Could not load stores: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stores = snapshot.data!.docs;
                if (stores.isEmpty) {
                  return const Text(
                      'No approved stores yet — ask your store to sign up first.',
                      style: TextStyle(color: Colors.black54));
                }
                return Column(
                  children: stores.map((doc) {
                    final d = doc.data();
                    final name = (d['name'] ?? '').toString();
                    // The value is the store OWNER's uid: drivers link to a
                    // store by ownerUid (the same key S2/S4 use for storeId).
                    final ownerUid = (d['ownerUid'] ?? '').toString();
                    return RadioListTile<String>(
                      title: Text(name),
                      value: ownerUid,
                      groupValue: _storeId,
                      onChanged: (v) => setState(() {
                        _storeId = v;
                      }),
                    );
                  }).toList(),
                );
              },
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Create driver profile'),
          ),
        ],
      ),
    );
  }
}
