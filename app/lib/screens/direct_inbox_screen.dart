import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/direct_message_service.dart';
import '../theme.dart';

/// Direct admin inbox: one thread per store/driver, outside any order.
/// The admin sees every conversation here; a store/driver sees only
/// their own chat with the admin (from "Message the Wasl admin" on
/// their profile). Text only — photos live in the order chat.
class DirectInboxScreen extends StatefulWidget {
  final AppUser profile;

  const DirectInboxScreen({super.key, required this.profile});

  @override
  State<DirectInboxScreen> createState() => _DirectInboxScreenState();
}

class _DirectInboxScreenState extends State<DirectInboxScreen> {
  final _service = DirectMessageService();
  String? _error;

  Future<void> _newChat() async {
    final picked = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _PickPersonDialog(),
    );
    if (picked == null || !mounted) return;
    final result = await _service.getOrCreateChat(
      adminUid: widget.profile.uid,
      adminName: widget.profile.name,
      otherUid: picked['uid']!,
      otherName: picked['name']!,
    );
    result.fold((chatId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectChatScreen(
            chatId: chatId,
            otherName: picked['name']!,
            profile: widget.profile,
          ),
        ),
      );
    }, (m) => setState(() => _error = m));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Direct messages')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newChat,
        icon: const Icon(Icons.message),
        label: const Text('New message'),
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorBanner(message: _error!),
            ),
          Expanded(
            child: StreamBuilder<List<DirectChat>>(
              stream: _service.chatsStream(widget.profile.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorBanner(
                        message: 'Could not load messages: ${snapshot.error}',
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final chats = snapshot.data!;
                if (chats.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No direct messages yet. Tap "New message" to write to a store or driver.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView(
                  children: chats.map((chat) {
                    final other = chat.otherName(widget.profile.uid);
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(other),
                        subtitle: Text(
                          chat.lastMessage.isEmpty
                              ? 'No messages yet'
                              : chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: chat.lastMessageAt == null
                            ? null
                            : Text(
                                '${chat.lastMessageAt!.month}/${chat.lastMessageAt!.day} '
                                '${chat.lastMessageAt!.hour.toString().padLeft(2, '0')}:${chat.lastMessageAt!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DirectChatScreen(
                              chatId: chat.id,
                              otherName: other,
                              profile: widget.profile,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick an approved store/driver to message.
class _PickPersonDialog extends StatelessWidget {
  const _PickPersonDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Message who?'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where('role', whereIn: [
                'store',
                'own-driver',
                'marketplace-driver',
              ])
              .where('verificationStatus', isEqualTo: 'approved')
              .limit(100)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Could not load people: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Text('No approved stores or drivers yet.');
            }
            return ListView(
              shrinkWrap: true,
              children: docs.map((doc) {
                final d = doc.data();
                return ListTile(
                  title: Text((d['name'] ?? '').toString()),
                  subtitle: Text(
                      '${d['role'] ?? ''} • ${(d['email'] ?? '').toString()}'),
                  onTap: () => Navigator.pop(context, {
                        'uid': doc.id,
                        'name': (d['name'] ?? '').toString(),
                      }),
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// One direct thread: the admin and one store/driver.
class DirectChatScreen extends StatefulWidget {
  final String chatId;
  final String otherName;
  final AppUser profile;

  const DirectChatScreen({
    super.key,
    required this.chatId,
    required this.otherName,
    required this.profile,
  });

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _controller = TextEditingController();
  final _service = DirectMessageService();
  String? _error;
  bool _sending = false;

  Future<void> _send() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await _service.sendMessage(
      chatId: widget.chatId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat — ${widget.otherName}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DirectMessage>>(
              stream: _service.messagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorBanner(
                        message: 'Could not load messages: ${snapshot.error}',
                      ),
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
                        'No messages yet. This is a direct chat with the admin — outside any order.',
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
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: mine ? WaslTheme.teal : Colors.white,
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorBanner(message: _error!),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
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
      ),
    );
  }
}
