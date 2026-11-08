import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/result.dart';

/// In-app voice + video calls (Agora). Signalling is a lightweight
/// Firestore `calls` doc: the caller creates it as `ringing`, the
/// callee's app — while open — shows the incoming call, and both sides
/// join the same Agora channel (the channel is the delivery id).
///
/// Every call joins with a fresh RTC token minted by the free
/// Cloudflare Worker (assets/agora.json `tokenServerUrl`). The Agora
/// App Certificate lives on the Worker as a secret, never in the app.
/// If the token fetch fails, the call screen shows the reason instead
/// of joining with an empty token.
///
/// Honest limits, stated in the app too:
/// - No push notifications (Blaze paid plan, not approved), so the
///   other side only sees an incoming call while the app is open.
/// - Free tier: 10,000 minutes/month, audio AND video. After that
///   audio $0.99/1,000 min, HD video $3.99/1,000 min. The service
///   STOPS at the limit instead of billing.
class CallDoc {
  final String id;
  final String channelId; // delivery id — one call per order
  final String callerUid;
  final String callerName;
  final String calleeUid;
  final String calleeName;
  final String callType; // 'voice' | 'video'
  final String status; // ringing | accepted | declined | ended
  final DateTime? createdAt;

  const CallDoc({
    required this.id,
    required this.channelId,
    required this.callerUid,
    required this.callerName,
    required this.calleeUid,
    required this.calleeName,
    required this.callType,
    required this.status,
    this.createdAt,
  });

  factory CallDoc.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CallDoc(
      id: doc.id,
      channelId: (d['channelId'] ?? '').toString(),
      callerUid: (d['callerUid'] ?? '').toString(),
      callerName: (d['callerName'] ?? '').toString(),
      calleeUid: (d['calleeUid'] ?? '').toString(),
      calleeName: (d['calleeName'] ?? '').toString(),
      callType: (d['callType'] ?? 'voice').toString(),
      status: (d['status'] ?? '').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class CallService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const placeholderAppId = 'REPLACE_WITH_YOUR_AGORA_APP_ID';

  /// The Agora App ID from assets/agora.json. The user creates the
  /// free Agora project himself and pastes the App ID there — no
  /// account is created by the app, no key is hard-coded.
  Future<Result<String>> loadAppId() => guard(() async {
        final raw = await rootBundle.loadString('assets/agora.json');
        final config = jsonDecode(raw) as Map<String, dynamic>;
        final appId = (config['appId'] as String?)?.trim() ?? '';
        if (appId.isEmpty || appId == placeholderAppId) {
          throw Exception(
              'Calls are not set up yet — the admin adds the Agora App ID in the app settings first.');
        }
        return appId;
      });

  /// The token server URL from assets/agora.json (the free Cloudflare
  /// Worker that mints a fresh RTC token per call). The App
  /// Certificate lives there as a secret, never in the app.
  Future<Result<String>> loadTokenServerUrl() => guard(() async {
        final raw = await rootBundle.loadString('assets/agora.json');
        final config = jsonDecode(raw) as Map<String, dynamic>;
        final url = (config['tokenServerUrl'] as String?)?.trim() ?? '';
        if (url.isEmpty) {
          throw Exception(
              'Calls are not set up yet — the token server URL is missing from the app settings.');
        }
        return url;
      });

  /// Fetch a fresh RTC token for [channelId] and [uid] from the token
  /// server. The token is minted per call and is valid for 1 hour.
  /// A failed fetch returns an Err with a readable reason instead of
  /// a silent empty token.
  Future<Result<String>> fetchToken({
    required String channelId,
    required int uid,
  }) =>
      guard(() async {
        final urlRes = await loadTokenServerUrl();
        final url = urlRes.fold(
          (v) => v,
          (m) => throw Exception(m),
        );
        final uri = Uri.parse(
            '$url/token?channel=${Uri.encodeComponent(channelId)}&uid=$uid');
        final resp =
            await http.get(uri).timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) {
          String detail = 'token server answered ${resp.statusCode}';
          try {
            final body = jsonDecode(resp.body) as Map<String, dynamic>;
            final err = (body['error'] as String?)?.trim();
            if (err != null && err.isNotEmpty) detail = err;
          } catch (_) {}
          if (detail == 'server not configured') {
            throw Exception(
                'Call server not configured yet — the Agora certificate still has to be added in Cloudflare first.');
          }
          throw Exception('Could not get a call token ($detail).');
        }
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final token = (body['token'] as String?)?.trim() ?? '';
        if (token.isEmpty) {
          throw Exception('Call token came back empty — try again.');
        }
        return token;
      });

  /// Start a call: creates the ringing doc, returns its id.
  Future<Result<String>> startCall({
    required String channelId,
    required String callerUid,
    required String callerName,
    required String calleeUid,
    required String calleeName,
    required String callType, // 'voice' | 'video'
  }) =>
      guard(() async {
        final ref = await _db.collection('calls').add({
          'channelId': channelId,
          'callerUid': callerUid,
          'callerName': callerName,
          'calleeUid': calleeUid,
          'calleeName': calleeName,
          'callType': callType,
          'status': 'ringing',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return ref.id;
      });

  /// Calls ringing for [uid] right now (the app must be open to see
  /// them — no push notifications on the free plan).
  Stream<List<CallDoc>> incomingCallStream(String uid) => _db
      .collection('calls')
      .where('calleeUid', isEqualTo: uid)
      .where('status', isEqualTo: 'ringing')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.map(CallDoc.fromDoc).toList());

  Stream<CallDoc?> callStream(String callId) => _db
      .collection('calls')
      .doc(callId)
      .snapshots()
      .map((doc) => doc.exists ? CallDoc.fromDoc(doc) : null);

  Future<Result<void>> _setStatus(String callId, String status) =>
      guard(() => _db.collection('calls').doc(callId).update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          }));

  Future<Result<void>> acceptCall(String callId) => _setStatus(callId, 'accepted');

  Future<Result<void>> declineCall(String callId) =>
      _setStatus(callId, 'declined');

  Future<Result<void>> endCall(String callId) => _setStatus(callId, 'ended');
}
