import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../screens/call_screen.dart';
import '../services/call_service.dart';

/// Incoming-call overlay: wraps a signed-in home screen and watches
/// for calls ringing for this user. While the app is open, an incoming
/// call pops up with Accept / Decline — no push notification exists
/// (Blaze paid plan, not approved), so a call only rings while the app
/// is open. Accepting joins the Agora channel; declining tells the
/// caller at once.
class CallOverlay extends StatefulWidget {
  final AppUser profile;
  final Widget child;

  const CallOverlay({super.key, required this.profile, required this.child});

  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  final _calls = CallService();
  StreamSubscription<List<CallDoc>>? _sub;
  final _shown = <String>{};
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _sub = _calls.incomingCallStream(widget.profile.uid).listen((calls) {
      if (calls.isEmpty || _dialogOpen || !mounted) return;
      final call = calls.first;
      if (_shown.contains(call.id)) return;
      _shown.add(call.id);
      _showIncoming(call);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _showIncoming(CallDoc call) async {
    _dialogOpen = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
            '${call.callType == 'video' ? 'Video' : 'Voice'} call — ${call.callerName}'),
        content: const Text(
          'Someone from this order is calling you inside Wasl.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;
    if (accepted == true) {
      final appId = await _calls.loadAppId();
      appId.fold((id) async {
        await _calls.acceptCall(call.id);
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              call: call,
              profile: widget.profile,
              appId: id,
            ),
          ),
        );
      }, (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    } else {
      await _calls.declineCall(call.id);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
