import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import '../models/delivery.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/photo_service.dart';
import '../services/voice_service.dart';
import '../theme.dart';
import 'call_screen.dart';

/// Per-order chat (S8 store, D8 driver — one thread, both sides).
/// Pinned order context at the top, quick replies, send box, no phone
/// numbers shared. Read-only once the order is delivered or cancelled.
class ChatScreen extends StatefulWidget {
  final Delivery delivery;
  final AppUser profile;

  const ChatScreen({
    super.key,
    required this.delivery,
    required this.profile,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _chat = ChatService();
  final _photos = PhotoService();
  final _voice = VoiceService();
  final _calls = CallService();
  final _player = AudioPlayer();
  String? _error;
  bool _sending = false;
  bool _recording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _playingMessageId;
  bool _startingCall = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMessageId = null);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _player.dispose();
    _voice.dispose();
    _controller.dispose();
    super.dispose();
  }

  static const _quickReplies = [
    'On my way',
    'At the store',
    'Running 5 min late',
    'Customer not answering',
  ];

  bool get _closed => widget.delivery.status == DeliveryStatus.delivered ||
      widget.delivery.status == DeliveryStatus.cancelled;

  Future<void> _send([String? text]) async {
    final value = (text ?? _controller.text).trim();
    if (value.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await _chat.sendMessage(
      deliveryId: widget.delivery.id,
      senderUid: widget.profile.uid,
      senderName: widget.profile.name,
      senderRole: widget.profile.role,
      text: value,
    );
    if (!mounted) return;
    result.fold(
      (_) {
        _controller.clear();
        setState(() => _sending = false);
      },
      (m) => setState(() {
        _error = m;
        _sending = false;
      }),
    );
  }

  /// Send a picture: pick (camera or gallery), upload to Cloudinary,
  /// then post the URL as a message. Everyone in the thread — store,
  /// driver, admin — can send and see it. A failed upload sends nothing.
  Future<void> _sendPicture() async {
    if (_closed || _sending) return;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Send a picture'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Take a photo'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Choose from gallery'),
          ),
        ],
      ),
    );
    if (source == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    String? localPath;
    final picked = await _photos.pickImage(source: source);
    picked.fold((path) => localPath = path, (m) => _error = m);
    if (localPath == null) {
      if (mounted) setState(() => _sending = false);
      return;
    }
    String? url;
    String? publicId;
    final uploaded = await _photos.uploadFile(localPath!, resourceType: 'image');
    uploaded.fold((u) {
      url = u?.url;
      publicId = u?.publicId;
    }, (m) => _error = m);
    if (url == null) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error ??= 'Could not upload the picture — try again.';
        });
      }
      return;
    }
    final result = await _chat.sendImage(
      deliveryId: widget.delivery.id,
      senderUid: widget.profile.uid,
      senderName: widget.profile.name,
      senderRole: widget.profile.role,
      imageUrl: url!,
      publicId: publicId,
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _sending = false),
      (m) => setState(() {
        _error = m;
        _sending = false;
      }),
    );
  }

  /// Hold to record a voice note; release to send it. The recording
  /// uploads to the same free Cloudinary storage as the photos, then
  /// posts as a message anyone in the thread can tap to play.
  Future<void> _startRecording() async {
    if (_closed || _sending || _recording) return;
    final started = await _voice.startRecording();
    started.fold((_) {
      setState(() {
        _recording = true;
        _recordingSeconds = 0;
        _error = null;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    }, (m) => setState(() => _error = m));
  }

  Future<void> _stopRecordingAndSend({bool cancel = false}) async {
    if (!_recording) return;
    _recordingTimer?.cancel();
    setState(() => _recording = false);
    if (cancel) {
      await _voice.cancelRecording();
      return;
    }
    final stopped = await _voice.stopRecording();
    final stoppedValue = stopped.fold((v) => v, (m) {
      setState(() => _error = m);
      return null;
    });
    if (stoppedValue == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final uploaded =
        await _voice.uploadVoiceNote(stoppedValue.path);
    String? url;
    String? publicId;
    uploaded.fold((u) {
      url = u?.url;
      publicId = u?.publicId;
    }, (m) => _error = m);
    if (url == null) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error ??= 'Could not upload the voice note — try again.';
        });
      }
      return;
    }
    final result = await _chat.sendVoice(
      deliveryId: widget.delivery.id,
      senderUid: widget.profile.uid,
      senderName: widget.profile.name,
      senderRole: widget.profile.role,
      audioUrl: url!,
      audioSeconds: stoppedValue.seconds,
      publicId: publicId,
    );
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _sending = false),
      (m) => setState(() {
        _error = m;
        _sending = false;
      }),
    );
  }

  Future<void> _togglePlay(ChatMessage message) async {
    if (message.audioUrl == null) return;
    if (_playingMessageId == message.id) {
      await _player.stop();
      setState(() => _playingMessageId = null);
      return;
    }
    try {
      await _player.stop();
      await _player.play(UrlSource(message.audioUrl!));
      setState(() => _playingMessageId = message.id);
    } catch (e) {
      setState(() => _error = 'Could not play the voice note.');
    }
  }

  /// Start a voice or video call with the other side of this order.
  /// Store ↔ driver; the admin picks which side to call. The other
  /// side sees the call while their app is open (no push on the free
  /// plan). Nothing happens until the Agora App ID is set up — the
  /// error says so plainly instead of failing silently.
  Future<void> _startCall(String callType) async {
    if (_startingCall) return;
    final d = widget.delivery;
    final me = widget.profile;
    String? calleeUid;
    String? calleeName;
    if (me.role == 'store') {
      calleeUid = d.driverId;
      calleeName = d.driverName;
    } else if (me.isDriver) {
      calleeUid = d.storeId;
      calleeName = d.storeName;
    } else {
      // Admin: pick the store or the driver of this order.
      final picked = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Call who?'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'store'),
              child: Text('Store — ${d.storeName}'),
            ),
            if (d.driverId != null)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'driver'),
                child: Text('Driver — ${d.driverName ?? ''}'),
              ),
          ],
        ),
      );
      if (picked == 'store') {
        calleeUid = d.storeId;
        calleeName = d.storeName;
      } else if (picked == 'driver') {
        calleeUid = d.driverId;
        calleeName = d.driverName;
      } else {
        return;
      }
    }
    if (calleeUid == null || calleeUid.isEmpty) {
      setState(() =>
          _error = 'Nobody to call yet — no driver on this order.');
      return;
    }
    setState(() {
      _startingCall = true;
      _error = null;
    });
    final appId = await _calls.loadAppId();
    final appIdValue = appId.fold((v) => v, (m) {
      setState(() {
        _error = m;
        _startingCall = false;
      });
      return null;
    });
    if (appIdValue == null) return;
    final created = await _calls.startCall(
      channelId: d.id,
      callerUid: me.uid,
      callerName: me.name,
      calleeUid: calleeUid,
      calleeName: calleeName ?? '',
      callType: callType,
    );
    if (!mounted) return;
    setState(() => _startingCall = false);
    created.fold((callId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            call: CallDoc(
              id: callId,
              channelId: d.id,
              callerUid: me.uid,
              callerName: me.name,
              calleeUid: calleeUid!,
              calleeName: calleeName ?? '',
              callType: callType,
              status: 'ringing',
            ),
            profile: me,
            appId: appIdValue,
          ),
        ),
      );
    }, (m) => setState(() => _error = m));
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Picture could not load.'),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.delivery;
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat — order #${d.orderNumber}'),
        actions: [
          IconButton(
            onPressed:
                _closed || _startingCall ? null : () => _startCall('voice'),
            icon: const Icon(Icons.call),
            tooltip: 'Voice call',
          ),
          IconButton(
            onPressed:
                _closed || _startingCall ? null : () => _startCall('video'),
            icon: const Icon(Icons.videocam),
            tooltip: 'Video call',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: WaslTheme.teal.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(12),
            child: Text(
              '#${d.orderNumber} • ${d.customerName} • ${d.customerAddress}\n'
              '${d.items} • ${d.money(d.orderTotal)} • ${d.status.label}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chat.messagesStream(d.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorBanner(
                          message:
                              'Could not load messages: ${snapshot.error}'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No messages yet. Say hello — no phone numbers are shared here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: messages.map((m) {
                    final mine = m.senderUid == widget.profile.uid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: mine
                              ? WaslTheme.teal
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Text(m.senderName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54)),
                            if (m.audioUrl != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _togglePlay(m),
                                    icon: Icon(
                                      _playingMessageId == m.id
                                          ? Icons.stop
                                          : Icons.play_arrow,
                                      color: mine
                                          ? Colors.white
                                          : WaslTheme.teal,
                                    ),
                                  ),
                                  Text(
                                    'Voice note • ${m.audioSeconds ?? 0}s',
                                    style: TextStyle(
                                        color: mine
                                            ? Colors.white
                                            : Colors.black87),
                                  ),
                                ],
                              ),
                            if (m.imageUrl != null)
                              GestureDetector(
                                onTap: () => _showFullImage(m.imageUrl!),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    m.imageUrl!,
                                    height: 180,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(
                                        height: 180,
                                        width: 180,
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => const Text(
                                        'Picture could not load.'),
                                  ),
                                ),
                              ),
                            if (m.text.isNotEmpty)
                              Text(m.text,
                                  style: TextStyle(
                                      color: mine
                                          ? Colors.white
                                          : Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          if (_recording)
            Container(
              width: double.infinity,
              color: WaslTheme.danger.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      color: WaslTheme.danger, size: 16),
                  const SizedBox(width: 8),
                  Text(
                      'Recording… ${_recordingSeconds}s — release to send'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _stopRecordingAndSend(cancel: true),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorBanner(message: _error!),
            ),
          if (_closed)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This order is finished — the thread is closed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            )
          else ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _quickReplies
                    .map((q) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(q),
                            onPressed: () => _send(q),
                          ),
                        ))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sending ? null : _sendPicture,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: 'Send a picture',
                  ),
                  GestureDetector(
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecordingAndSend(),
                    child: IconButton(
                      onPressed: null,
                      icon: Icon(
                        Icons.mic,
                        color: _recording
                            ? WaslTheme.danger
                            : WaslTheme.teal,
                      ),
                      tooltip: 'Hold to record a voice note',
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Write a message…',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : () => _send(),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
