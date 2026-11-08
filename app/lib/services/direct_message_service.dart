import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';

/// Direct admin inbox: a 1:1 conversation between the admin and one
/// store or driver, OUTSIDE any order (per-order chat already exists
/// in deliveries/{id}/messages). One chat doc per pair — the id is
/// deterministic from the two uids, so both sides always land in the
/// same thread. Text only for now (photos live in the order chat).
class DirectMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime? createdAt;

  const DirectMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.createdAt,
  });

  factory DirectMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DirectMessage(
      id: doc.id,
      senderUid: (d['senderUid'] ?? '').toString(),
      senderName: (d['senderName'] ?? '').toString(),
      senderRole: (d['senderRole'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class DirectChat {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final DateTime? lastMessageAt;

  const DirectChat({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.lastMessage,
    this.lastMessageAt,
  });

  factory DirectChat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final names = <String, String>{};
    for (final e in ((d['participantNames'] as Map?) ?? {}).entries) {
      names[e.key.toString()] = e.value.toString();
    }
    return DirectChat(
      id: doc.id,
      participants:
          ((d['participants'] as List?) ?? []).map((e) => e.toString()).toList(),
      participantNames: names,
      lastMessage: (d['lastMessage'] ?? '').toString(),
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
    );
  }

  /// The other side of the chat for [uid] — their name, or the uid.
  String otherName(String uid) {
    for (final p in participants) {
      if (p != uid) return participantNames[p] ?? p;
    }
    return '';
  }
}

class DirectMessageService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Deterministic chat id for a pair of uids (sorted, so both sides
  /// compute the same one).
  static String chatIdFor(String a, String b) {
    final pair = [a, b]..sort();
    return '${pair[0]}_${pair[1]}';
  }

  /// Open the admin's chat with one store/driver, creating it when it
  /// does not exist yet. Returns the chat id.
  Future<Result<String>> getOrCreateChat({
    required String adminUid,
    required String adminName,
    required String otherUid,
    required String otherName,
  }) =>
      guard(() async {
        final id = chatIdFor(adminUid, otherUid);
        final ref = _db.collection('direct_chats').doc(id);
        final existing = await ref.get();
        if (!existing.exists) {
          await ref.set({
            'participants': [adminUid, otherUid],
            'participantNames': {adminUid: adminName, otherUid: otherName},
            'lastMessage': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        return id;
      });

  /// The store/driver side: open (or create) my chat with the Wasl
  /// admin. The admin's uid lives in the public `config/wasl` doc
  /// (written by the admin on sign-in) — stores and drivers cannot
  /// list users, so the uid cannot come from a users query.
  Future<Result<String>> getOrCreateAdminChat({
    required String myUid,
    required String myName,
  }) =>
      guard(() async {
        final config = await _db.collection('config').doc('wasl').get();
        final adminUid = (config.data()?['adminUid'] ?? '').toString();
        final adminName =
            (config.data()?['adminName'] ?? 'Wasl admin').toString();
        if (adminUid.isEmpty) {
          throw Exception(
              'Direct messages are not set up yet — the admin opens the app once to set them up.');
        }
        final id = chatIdFor(adminUid, myUid);
        final ref = _db.collection('direct_chats').doc(id);
        final existing = await ref.get();
        if (!existing.exists) {
          await ref.set({
            'participants': [adminUid, myUid],
            'participantNames': {adminUid: adminName, myUid: myName},
            'lastMessage': '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        return id;
      });

  /// All direct chats for one user, newest message first (sorted
  /// client-side — no composite index needed at pilot scale).
  Stream<List<DirectChat>> chatsStream(String uid) => _db
      .collection('direct_chats')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((s) {
        final chats = s.docs.map(DirectChat.fromDoc).toList();
        chats.sort((a, b) {
          final at = a.lastMessageAt;
          final bt = b.lastMessageAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        });
        return chats;
      });

  Stream<List<DirectMessage>> messagesStream(String chatId) => _db
      .collection('direct_chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(DirectMessage.fromDoc).toList());

  Future<Result<void>> sendMessage({
    required String chatId,
    required String senderUid,
    required String senderName,
    required String senderRole,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return Future.value(const Err('Write a message first.'));
    }
    return guard(() async {
      final batch = _db.batch();
      final messages = _db
          .collection('direct_chats')
          .doc(chatId)
          .collection('messages')
          .doc();
      batch.set(messages, {
        'senderUid': senderUid,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(_db.collection('direct_chats').doc(chatId), {
        'lastMessage': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    });
  }
}
