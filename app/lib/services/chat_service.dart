import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/result.dart';

/// Per-order chat (S8 store side, D8 driver side — the same thread).
/// Messages live under deliveries/{id}/messages. The rules let only the
/// store that created the order, the assigned driver, and the admin
/// read/write; nobody can edit or delete a message. The thread closes
/// after delivery (the UI goes read-only then).
class ChatMessage {
  final String id;
  final String senderUid;
  final String senderName;
  final String senderRole;
  final String text;
  final String? imageUrl; // Cloudinary URL when the message is a picture
  final String? audioUrl; // Cloudinary URL when the message is a voice note
  final int? audioSeconds; // voice note length in seconds
  final String? publicId; // Cloudinary public id (console deletes need it)
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.senderRole,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.audioSeconds,
    this.publicId,
    this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ChatMessage(
      id: doc.id,
      senderUid: (d['senderUid'] ?? '').toString(),
      senderName: (d['senderName'] ?? '').toString(),
      senderRole: (d['senderRole'] ?? '').toString(),
      text: (d['text'] ?? '').toString(),
      imageUrl: d['imageUrl'] as String?,
      audioUrl: d['audioUrl'] as String?,
      audioSeconds: (d['audioSeconds'] as num?)?.toInt(),
      publicId: d['publicId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<ChatMessage>> messagesStream(String deliveryId) => _db
      .collection('deliveries')
      .doc(deliveryId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromDoc).toList());

  Future<Result<void>> sendMessage({
    required String deliveryId,
    required String senderUid,
    required String senderName,
    required String senderRole,
    required String text,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return Future.value(const Err('Write a message first.'));
    }
    return guard(() => _db
        .collection('deliveries')
        .doc(deliveryId)
        .collection('messages')
        .add({
          'senderUid': senderUid,
          'senderName': senderName,
          'senderRole': senderRole,
          'text': trimmed,
          'createdAt': FieldValue.serverTimestamp(),
        }));
  }

  /// A picture message: the image is already uploaded (Cloudinary) and
  /// its URL goes on the message. Anyone in the thread — store, driver,
  /// admin — can send and see it. Text is optional. The Cloudinary
  /// public id is saved with it (the admin needs it to delete the file
  /// in the Cloudinary console — see PhotoCleanupService).
  Future<Result<void>> sendImage({
    required String deliveryId,
    required String senderUid,
    required String senderName,
    required String senderRole,
    required String imageUrl,
    String? publicId,
    String? text,
  }) {
    return guard(() => _db
        .collection('deliveries')
        .doc(deliveryId)
        .collection('messages')
        .add({
          'senderUid': senderUid,
          'senderName': senderName,
          'senderRole': senderRole,
          'text': (text ?? '').trim(),
          'imageUrl': imageUrl,
          if (publicId != null) 'publicId': publicId,
          'createdAt': FieldValue.serverTimestamp(),
        }));
  }

  /// A voice note: the audio is already uploaded (Cloudinary) and its
  /// URL goes on the message. Tap to play in the chat.
  Future<Result<void>> sendVoice({
    required String deliveryId,
    required String senderUid,
    required String senderName,
    required String senderRole,
    required String audioUrl,
    required int audioSeconds,
    String? publicId,
  }) {
    return guard(() => _db
        .collection('deliveries')
        .doc(deliveryId)
        .collection('messages')
        .add({
          'senderUid': senderUid,
          'senderName': senderName,
          'senderRole': senderRole,
          'text': '',
          'audioUrl': audioUrl,
          'audioSeconds': audioSeconds,
          if (publicId != null) 'publicId': publicId,
          'createdAt': FieldValue.serverTimestamp(),
        }));
  }
}
