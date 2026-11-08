import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';
import 'audit_service.dart';

/// Admin photo cleanup by period: count the chat photos older than a
/// week / a month / 3 months / a year, confirm, and remove them from
/// the chats (the message docs are deleted — admin-only, photo
/// messages only, by the rules).
///
/// HONEST LIMIT, verified live 2026-11-08 and shown in the UI:
/// removing a photo from the chat does NOT delete the file from
/// Cloudinary storage, so it does NOT free space on its own. Why:
/// deleting a Cloudinary file needs the API secret (signed Destroy /
/// Admin API), and the secret must never live in the app; the
/// no-secret delete token only works within ~10 minutes of upload
/// (and this preset does not return one at all — the "return delete
/// token" switch lives in the Cloudinary console, not the app).
/// To actually free space, delete the files in the Cloudinary console
/// (Media Library) — the cleanup screen says so and the count it
/// shows is the number of files to delete there. A server step (or a
/// future signed-delete endpoint) is what would make this one tap.
/// What cleanup DOES do: old photos stop showing in the chats.
class PhotoCleanupResult {
  final int examined;
  final int removedFromChats;
  final int failed;

  const PhotoCleanupResult({
    required this.examined,
    required this.removedFromChats,
    required this.failed,
  });
}

class PhotoCleanupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const periods = <String, Duration>{
    'Older than a week': Duration(days: 7),
    'Older than a month': Duration(days: 30),
    'Older than 3 months': Duration(days: 90),
    'Older than a year': Duration(days: 365),
  };

  /// All photo messages older than [cutoff] across every order chat.
  /// Single range filter on createdAt (no composite index needed);
  /// the imageUrl check is client-side.
  Future<Result<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>
      _oldPhotoMessages(DateTime cutoff) => guard(() async {
            final snap = await _db
                .collectionGroup('messages')
                .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
                .limit(1000)
                .get();
            return snap.docs
                .where((d) => (d.data()['imageUrl'] as String?) != null)
                .toList();
          });

  Future<Result<int>> countPhotosOlderThan(Duration period) async {
    final cutoff = DateTime.now().subtract(period);
    final found = await _oldPhotoMessages(cutoff);
    return found.fold((docs) => Ok(docs.length), (m) => Err(m));
  }

  /// Remove the old photo messages from the chats. Each deletion is
  /// attempted on its own — one failure never stops the rest.
  Future<Result<PhotoCleanupResult>> cleanupOlderThan(Duration period) async {
    final cutoff = DateTime.now().subtract(period);
    final found = await _oldPhotoMessages(cutoff);
    return found.fold((docs) async {
      var removed = 0;
      var failed = 0;
      for (final doc in docs) {
        try {
          await doc.reference.delete();
          removed++;
        } catch (_) {
          failed++;
        }
      }
      final result = PhotoCleanupResult(
        examined: docs.length,
        removedFromChats: removed,
        failed: failed,
      );
      final logged = await AuditService.log(
        action: 'photo_cleanup',
        targetType: 'photos',
        targetId: '${period.inDays}d',
        targetLabel:
            'Removed $removed photo(s) older than ${period.inDays} days from chats ($failed failed)',
      );
      var logOk = false;
      logged.fold((_) {
        logOk = true;
      }, (_) {});
      if (!logOk) return logged.fold((_) => Ok(result), (m) => Err(m));
      return Ok(result);
    }, (m) => Future.value(Err(m)));
  }
}
