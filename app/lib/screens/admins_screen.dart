import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/result.dart';
import '../services/audit_service.dart';
import '../theme.dart';

/// Admins & roles: the main admin assigns roles to people.
/// - Pick any approved person and set their role: Admin, Store,
///   Own driver or Marketplace driver.
/// - Making someone an admin gives them full control (approvals, blocks,
///   deletes, fees) and their store/driver screens stop opening.
/// - Changing an admin back to another role takes that control away.
/// Guards: the main admin can never change their own role, and the last
/// admin can never be moved to another role — Wasl always keeps one admin.
/// Role changes apply on the person's next sign-in.
class AdminsScreen extends StatefulWidget {
  const AdminsScreen({super.key});

  @override
  State<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends State<AdminsScreen> {
  String? _error;

  static const _roles = [
    'admin',
    'store',
    'own-driver',
    'marketplace-driver',
  ];

  static String roleLabel(String role) {
    return switch (role) {
      'admin' => 'Admin',
      'store' => 'Store',
      'own-driver' => 'Own driver',
      'marketplace-driver' => 'Marketplace driver',
      _ => role,
    };
  }

  Future<void> _pickRole(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> all,
  ) async {
    final d = doc.data();
    final currentRole = (d['role'] ?? '').toString();
    final name = (d['name'] ?? '').toString();
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    var picked = currentRole;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Role for $name'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._roles.map((role) => RadioListTile<String>(
                      title: Text(roleLabel(role)),
                      subtitle: role == 'admin'
                          ? const Text(
                              'Full control: approvals, blocks, deletes, fees. Their store/driver screens will no longer open.')
                          : null,
                      value: role,
                      groupValue: picked,
                      onChanged: (v) =>
                          setDialogState(() => picked = v ?? currentRole),
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Their old store/driver profile stays — remove it from Stores or Drivers if it is not needed. The new role applies on their next sign-in.',
                  style: TextStyle(fontSize: 12),
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
              child: const Text('Set role'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (picked == currentRole) return;
    if (!context.mounted) return;

    // Guards: never your own role, never the last admin.
    if (doc.id == myUid) {
      setState(() => _error = 'You can\'t change your own role.');
      return;
    }
    final adminCount =
        all.where((u) => (u.data()['role'] ?? '') == 'admin').length;
    if (currentRole == 'admin' && picked != 'admin' && adminCount <= 1) {
      setState(() => _error =
          'There must always be at least one admin — make someone else an admin first.');
      return;
    }

    final result = await guard(() => FirebaseFirestore.instance
        .collection('users')
        .doc(doc.id)
        .update({'role': picked}));
    var ok = false;
    result.fold((_) {
      ok = true;
    }, (m) => setState(() => _error = m));
    if (!ok || !context.mounted) return;
    final logged = await AuditService.log(
      action: 'set_role',
      targetType: 'user',
      targetId: doc.id,
      targetLabel: '$name: ${roleLabel(currentRole)} → ${roleLabel(picked)}',
    );
    logged.fold((_) {}, (m) {
      if (mounted) setState(() => _error = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Admins & roles')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .where('verificationStatus', isEqualTo: 'approved')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBanner(
                    message: 'Could not load people: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) => ((a.data()['name'] ?? '').toString())
                .compareTo((b.data()['name'] ?? '').toString()));
          final myUid = FirebaseAuth.instance.currentUser?.uid;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              const Text(
                'Tap a person to set their role. Only the main admin can change roles.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ...docs.map((doc) {
                final d = doc.data();
                final role = (d['role'] ?? '').toString();
                final isMe = doc.id == myUid;
                return Card(
                  child: ListTile(
                    title: Text(
                        '${(d['name'] ?? '').toString()}${isMe ? ' (you)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text((d['email'] ?? '').toString()),
                    trailing: Chip(
                      label: Text(roleLabel(role)),
                      backgroundColor: role == 'admin'
                          ? WaslTheme.teal.withValues(alpha: 0.15)
                          : null,
                    ),
                    onTap: () => _pickRole(context, doc, docs),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
