import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/audit_service.dart';
import '../theme.dart';

/// Admin activity (the audit trail): every admin action, newest first.
/// Filters are client-side so no composite index is needed.
class AdminActivityScreen extends StatefulWidget {
  const AdminActivityScreen({super.key});

  @override
  State<AdminActivityScreen> createState() => _AdminActivityScreenState();
}

class _AdminActivityScreenState extends State<AdminActivityScreen> {
  String _filter = 'All';

  static const _filters = [
    'All',
    'Approvals',
    'Blocks',
    'Deletes',
    'Fees',
    'Admins',
  ];

  String _when(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate().toLocal();
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${d.month}/${d.day}/${d.year} $hour:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Admin activity')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: _filters
                  .map((f) => ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection('admin_actions')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorBanner(
                          message:
                              'Could not load activity: ${snapshot.error}'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.where((doc) {
                  if (_filter == 'All') return true;
                  final action = (doc.data()['action'] ?? '').toString();
                  return AuditService.bucketFor(action) == _filter;
                }).toList();
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No admin activity yet. Approvals, blocks, deletes, '
                        'fee changes and role changes will show up here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final action = (d['action'] ?? '').toString();
                    final target = (d['targetLabel'] ?? '').toString();
                    final admin = (d['adminName'] ?? '').toString();
                    final adminEmail = (d['adminEmail'] ?? '').toString();
                    final reason = (d['reason'] as String?) ?? '';
                    final when = _when(d['createdAt'] as Timestamp?);
                    return Card(
                      child: ListTile(
                        title: Text(AuditService.labelFor(action),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (target.isNotEmpty) Text(target),
                            Text(
                                'By ${admin.isNotEmpty ? admin : adminEmail} • $when'),
                            if (reason.isNotEmpty)
                              Text('Reason: $reason',
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
