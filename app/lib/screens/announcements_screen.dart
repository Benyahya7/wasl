import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/announcement_service.dart';
import '../theme.dart';

/// Admin announcements: one message to all drivers or all stores at
/// once. It shows in their app (store home / driver home), newest
/// first. No push notification — the message waits in the app until
/// they open it (push needs the Blaze paid plan, not approved).
class AnnouncementsScreen extends StatefulWidget {
  final AppUser profile;

  const AnnouncementsScreen({super.key, required this.profile});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _service = AnnouncementService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _audience = 'drivers';
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await _service.send(
      audience: _audience,
      title: _titleController.text,
      body: _bodyController.text,
      byUid: widget.profile.uid,
      byName: widget.profile.name,
    );
    if (!mounted) return;
    result.fold(
      (_) {
        _titleController.clear();
        _bodyController.clear();
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement sent.')),
        );
      },
      (m) => setState(() {
        _error = m;
        _sending = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Announcements')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'One message to everyone in a group. It shows in their app the next time they open it — there is no push notification on the free plan.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _audience,
            decoration: const InputDecoration(labelText: 'Send to'),
            items: AnnouncementService.audiences
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(AnnouncementService.audienceLabel(a)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _audience = v ?? 'drivers'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _sending ? null : _send,
            child: const Text('Send announcement'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sent announcements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Announcement>>(
            stream: _service.announcementsStream('drivers'),
            builder: (context, driversSnap) {
              return StreamBuilder<List<Announcement>>(
                stream: _service.announcementsStream('stores'),
                builder: (context, storesSnap) {
                  if (driversSnap.hasError || storesSnap.hasError) {
                    return ErrorBanner(
                      message:
                          'Could not load announcements: ${driversSnap.error ?? storesSnap.error}',
                    );
                  }
                  final all = [
                    ...(driversSnap.data ?? []),
                    ...(storesSnap.data ?? []),
                  ]..sort((a, b) {
                      final at = a.createdAt;
                      final bt = b.createdAt;
                      if (at == null && bt == null) return 0;
                      if (at == null) return 1;
                      if (bt == null) return -1;
                      return bt.compareTo(at);
                    });
                  if (all.isEmpty) {
                    return const Text(
                      'No announcements sent yet.',
                      style: TextStyle(color: Colors.black54),
                    );
                  }
                  return Column(
                    children: all
                        .map((a) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.campaign),
                                title: Text(a.title),
                                subtitle: Text(
                                  '${AnnouncementService.audienceLabel(a.audience)} • ${a.body}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ))
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Announcements card for the store / driver home: the latest messages
/// from the admin for this audience. Shown only when there is one.
class AnnouncementsCard extends StatelessWidget {
  final String audience; // 'drivers' | 'stores'

  const AnnouncementsCard({super.key, required this.audience});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementService().announcementsStream(audience),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data!;
        if (items.isEmpty) return const SizedBox.shrink();
        return Card(
          color: WaslTheme.amber.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign, color: WaslTheme.teal),
                    SizedBox(width: 8),
                    Text(
                      'From the Wasl admin',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...items.take(3).map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(a.body),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
