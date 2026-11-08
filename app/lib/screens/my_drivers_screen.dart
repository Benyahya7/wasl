import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/driver_service.dart';
import '../theme.dart';

/// S4 — My Drivers: the store's own-driver roster with verification status
/// and stats. A store adds drivers by having them sign up in the app as
/// "Own driver" and pick this store; they appear here once the admin
/// approves their driver profile. Removal is the admin's job (A5).
class MyDriversScreen extends StatelessWidget {
  final AppUser profile;

  const MyDriversScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Drivers')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your drivers sign up in the Wasl app, choose "Own driver", and pick your store. Once the admin approves them, they show up here and you can assign deliveries to them.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: DriverService().storeDriversStream(profile.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorBanner(
                    message: 'Could not load drivers: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final drivers = snapshot.data!.docs;
              if (drivers.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No own drivers yet.'),
                  ),
                );
              }
              return Column(
                children: drivers.map((doc) {
                  final d = doc.data();
                  final status = (d['verificationStatus'] ?? '').toString();
                  return Card(
                    child: ListTile(
                      title: Text((d['name'] ?? '').toString()),
                      subtitle: Text(
                          'Vehicle: ${(d['vehicle'] ?? '').toString()} • Rating: ${(d['rating'] ?? 0).toString()}'),
                      trailing: StatusChip(
                        label: status == 'approved'
                            ? 'Approved'
                            : status == 'rejected'
                                ? 'Rejected'
                                : 'Pending',
                        color: status == 'approved'
                            ? WaslTheme.okGreen
                            : status == 'rejected'
                                ? WaslTheme.danger
                                : WaslTheme.amber,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverDetailScreen(
                            driverDoc: doc,
                            storeUid: profile.uid,
                          ),
                        ),
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

/// One driver: verification, vehicle, rating, deliveries done + cash owed.
class DriverDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> driverDoc;
  final String storeUid;

  const DriverDetailScreen({
    super.key,
    required this.driverDoc,
    required this.storeUid,
  });

  @override
  Widget build(BuildContext context) {
    final d = driverDoc.data();
    final name = (d['name'] ?? '').toString();
    final userUid = (d['userUid'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type: ${(d['type'] ?? '').toString()}'),
                  Text('Vehicle: ${(d['vehicle'] ?? '').toString()}'),
                  Text('Rating: ${(d['rating'] ?? 0).toString()}'),
                  Text(
                      'Verification: ${(d['verificationStatus'] ?? '').toString()}'),
                  if ((d['verificationReason'] ?? '').toString().isNotEmpty)
                    Text(
                        'Reason: ${(d['verificationReason'] ?? '').toString()}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('deliveries')
                .where('storeId', isEqualTo: storeUid)
                .where('driverId', isEqualTo: userUid)
                .where('status', isEqualTo: 'delivered')
                .get(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorBanner(
                    message: 'Could not load stats: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              var cashOwed = 0.0;
              for (final doc in docs) {
                final data = doc.data();
                final collected =
                    (data['cashCollected'] as num?)?.toDouble() ?? 0;
                final returned =
                    (data['cashReturned'] as num?)?.toDouble() ?? 0;
                cashOwed += collected - returned;
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deliveries done: ${docs.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                      Text('Cash still owed: \$${cashOwed.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Only the admin can remove a driver from your store.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
