import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/photo_cleanup_service.dart';
import '../theme.dart';

/// Admin photo cleanup by period: pick how old, see how many chat
/// photos that covers, confirm, and remove them from the chats.
///
/// Read this before using it: removing a photo from the chat does NOT
/// delete the file from Cloudinary storage, so it does NOT free space
/// on its own. Deleting a Cloudinary file needs the API secret, and
/// the secret must never live in the app; the no-secret delete token
/// only works within ~10 minutes of upload. To actually free space,
/// delete the files in the Cloudinary console (Media Library) — this
/// screen tells you exactly how many files that is. A server step is
/// what would make this one tap. What cleanup DOES do: old photos
/// stop showing in the chats.
class PhotoCleanupScreen extends StatefulWidget {
  final AppUser profile;

  const PhotoCleanupScreen({super.key, required this.profile});

  @override
  State<PhotoCleanupScreen> createState() => _PhotoCleanupScreenState();
}

class _PhotoCleanupScreenState extends State<PhotoCleanupScreen> {
  final _service = PhotoCleanupService();
  String _periodLabel = 'Older than a month';
  int? _count;
  bool _counting = false;
  bool _cleaning = false;
  String? _error;
  String? _result;

  Duration get _period => PhotoCleanupService.periods[_periodLabel]!;

  Future<void> _countPhotos() async {
    setState(() {
      _counting = true;
      _error = null;
      _result = null;
      _count = null;
    });
    final result = await _service.countPhotosOlderThan(_period);
    if (!mounted) return;
    result.fold(
      (n) => setState(() {
        _count = n;
        _counting = false;
      }),
      (m) => setState(() {
        _error = m;
        _counting = false;
      }),
    );
  }

  Future<void> _cleanup() async {
    final count = _count ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $count photo(s) from the chats?'),
        content: const Text(
          'The photos stop showing in the order chats. This does NOT delete the files from Cloudinary storage — freeing space still needs the Cloudinary console (Media Library). This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove them'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _cleaning = true;
      _error = null;
      _result = null;
    });
    final result = await _service.cleanupOlderThan(_period);
    if (!mounted) return;
    result.fold(
      (r) => setState(() {
        _cleaning = false;
        _count = null;
        _result =
            'Removed ${r.removedFromChats} photo(s) from the chats (${r.failed} failed). The files are still in Cloudinary storage — delete them in the Cloudinary console (Media Library) to free space.';
      }),
      (m) => setState(() {
        _error = m;
        _cleaning = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo cleanup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Old chat photos, by period. Removing them clears them from the order chats.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WaslTheme.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Important: this does NOT free Cloudinary space. Deleting a file from storage needs the Cloudinary API secret, which must never live in the app. To free space, delete the files in the Cloudinary console (Media Library) — the count below is how many files that is.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _periodLabel,
            decoration: const InputDecoration(labelText: 'Remove photos'),
            items: PhotoCleanupService.periods.keys
                .map((label) => DropdownMenuItem(
                      value: label,
                      child: Text(label),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _periodLabel = v ?? _periodLabel;
              _count = null;
              _result = null;
            }),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _counting || _cleaning ? null : _countPhotos,
            child: _counting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Count photos'),
          ),
          if (_count != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_count photo(s) — $_periodLabel',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'These are photo messages in the order chats. Text messages and voice notes are never touched.',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed:
                          _cleaning || _count == 0 ? null : _cleanup,
                      child: _cleaning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Remove from chats'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WaslTheme.okGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_result!),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}
