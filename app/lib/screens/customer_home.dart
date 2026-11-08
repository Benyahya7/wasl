import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/result.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../theme.dart';

/// C3 — customer profile (optional). A customer signs in with Google and
/// needs no approval. Saved addresses live on their users doc.
/// Order history cannot be linked yet: v1 deliveries are created by the
/// store and carry no customer account — it lands with v2 ordering, when
/// the customer orders from the app. The screen says so plainly instead
/// of showing an empty list as if it were a bug.
class CustomerHome extends StatefulWidget {
  final AppUser profile;
  final AuthService auth;

  const CustomerHome({super.key, required this.profile, required this.auth});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  final _address = TextEditingController();
  final _phone = TextEditingController();
  String? _error;
  bool _loaded = false;

  @override
  void dispose() {
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    final result = await guard(() => FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .update({'phone': _phone.text.trim()}));
    result.fold(
      (_) => setState(() => _error = null),
      (m) => setState(() => _error = m),
    );
  }

  Future<void> _addAddress() async {
    final address = _address.text.trim();
    if (address.isEmpty) return;
    final result = await guard(() => FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .update({
          'savedAddresses': FieldValue.arrayUnion([address]),
        }));
    result.fold(
      (_) => setState(() {
        _error = null;
        _address.clear();
      }),
      (m) => setState(() => _error = m),
    );
  }

  Future<void> _removeAddress(String address) async {
    final result = await guard(() => FirebaseFirestore.instance
        .collection('users')
        .doc(widget.profile.uid)
        .update({
          'savedAddresses': FieldValue.arrayRemove([address]),
        }));
    result.fold(
      (_) {},
      (m) => setState(() => _error = m),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const WaslAppBarLogo(),
        title: Text('Wasl — ${widget.profile.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => widget.auth.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.profile.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                    message: 'Could not load profile: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snapshot.data!.data() ?? {};
          if (!_loaded) {
            _phone.text = (d['phone'] ?? '').toString();
            _loaded = true;
          }
          final addresses = ((d['savedAddresses'] as List?) ?? [])
              .map((e) => e.toString())
              .toList();
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
                      Text(widget.profile.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(widget.profile.email),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: 'Phone'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _savePhone,
                        child: const Text('Save phone'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Saved addresses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (addresses.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No saved addresses yet — add the places you order to.'),
                  ),
                ),
              ...addresses.map((a) => Card(
                    child: ListTile(
                      title: Text(a),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _removeAddress(a),
                      ),
                    ),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: _address,
                decoration: const InputDecoration(
                    labelText: 'New address (e.g. 1189 Saratoga St)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _addAddress,
                child: const Text('Add address'),
              ),
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your orders will appear here once you order from the Wasl app (v2). For now, track any delivery with the link the store sends you — no account needed for that.',
                    style: TextStyle(color: Colors.black54),
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
