import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/call_service.dart';
import '../theme.dart';

/// In-app voice / video call (Agora). Joins the channel named after
/// the delivery, so the store and the driver on that order land in the
/// same call. Voice calls show a big contact card; video calls show
/// the other side full-screen with the local preview in the corner.
///
/// Before joining, the screen fetches a fresh RTC token from the free
/// Cloudflare token server (see CallService.fetchToken). If the token
/// fetch fails — for example the Agora certificate is not set on the
/// server yet — the screen shows the reason instead of joining.
class CallScreen extends StatefulWidget {
  final CallDoc call;
  final AppUser profile;
  final String appId;

  const CallScreen({
    super.key,
    required this.call,
    required this.profile,
    required this.appId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _calls = CallService();
  RtcEngine? _engine;
  StreamSubscription<CallDoc?>? _callSub;
  bool _joined = false;
  bool _leftByMe = false;
  int? _remoteUid;
  bool _muted = false;
  bool _speakerOn = false;
  bool _videoOff = false;
  String? _error;
  String _status = 'Connecting…';

  bool get _isVideo => widget.call.callType == 'video';

  /// The other side's name — for the caller it is the callee, and
  /// vice versa.
  String get _otherName => widget.profile.uid == widget.call.callerUid
      ? widget.call.calleeName
      : widget.call.callerName;

  @override
  void initState() {
    super.initState();
    // The other side declining or hanging up ends the call here too —
    // the caller is never left staring at "Connecting…" forever.
    _callSub = _calls.callStream(widget.call.id).listen((call) {
      if (call == null || !mounted || _leftByMe) return;
      if (call.status == 'declined') {
        setState(() => _status = '$_otherName declined the call');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else if (call.status == 'ended') {
        Navigator.pop(context);
      }
    });
    _join();
  }

  Future<void> _join() async {
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: widget.appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (mounted) {
              setState(() {
                _joined = true;
                _status = 'Connected — waiting for $_otherName…';
              });
            }
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _status = 'On call with $_otherName';
              });
            }
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (mounted) {
              setState(() {
                _remoteUid = null;
                _status = '$_otherName left the call';
              });
            }
          },
          onError: (err, msg) {
            if (mounted) {
              setState(() {
                _error = 'Call error ($err): $msg';
              });
            }
          },
        ),
      );
      if (_isVideo) {
        await engine.enableVideo();
        await engine.startPreview();
      } else {
        await engine.enableAudio();
      }
      await engine.setEnableSpeakerphone(_isVideo ? false : true);
      _speakerOn = !_isVideo;
      // The Agora project runs in token mode, so an empty token never
      // joins. Fetch a fresh token for this channel first; a failure
      // throws here and lands in the error banner below.
      final tokenRes = await _calls.fetchToken(
        channelId: widget.call.channelId,
        uid: 0,
      );
      final token = tokenRes.fold(
        (t) => t,
        (m) => throw Exception(m),
      );
      await engine.joinChannel(
        token: token,
        channelId: widget.call.channelId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: _isVideo,
          publishMicrophoneTrack: true,
        ),
      );
      _engine = engine;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Could not start the call: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  Future<void> _leave({bool endForBoth = true}) async {
    _leftByMe = true;
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (_) {}
    _engine = null;
    if (endForBoth) {
      await _calls.endCall(widget.call.id);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    setState(() => _muted = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    await _engine?.setEnableSpeakerphone(next);
    setState(() => _speakerOn = next);
  }

  Future<void> _toggleVideo() async {
    if (!_isVideo) return;
    final next = !_videoOff;
    await _engine?.muteLocalVideoStream(next);
    setState(() => _videoOff = next);
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _engine?.leaveChannel().catchError((_) {});
    _engine?.release().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: _isVideo ? Colors.black : WaslTheme.paper,
        appBar: AppBar(
          title: Text(
              '${_isVideo ? 'Video' : 'Voice'} call — ${_otherName.isEmpty ? 'order' : _otherName}'),
          leading: IconButton(
            icon: const Icon(Icons.call_end),
            color: WaslTheme.danger,
            onPressed: _leave,
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _buildCallView(engine),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorBanner(message: _error!),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isVideo ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Unmute' : 'Mute',
                    onPressed: _toggleMute,
                  ),
                  _CallButton(
                    icon: _speakerOn
                        ? Icons.volume_up
                        : Icons.volume_down,
                    label: 'Speaker',
                    onPressed: _toggleSpeaker,
                  ),
                  if (_isVideo) ...[
                    _CallButton(
                      icon: _videoOff
                          ? Icons.videocam_off
                          : Icons.videocam,
                      label: _videoOff ? 'Camera off' : 'Camera',
                      onPressed: _toggleVideo,
                    ),
                    _CallButton(
                      icon: Icons.cameraswitch,
                      label: 'Flip',
                      onPressed: () => _engine?.switchCamera(),
                    ),
                  ],
                  _CallButton(
                    icon: Icons.call_end,
                    label: 'End',
                    color: WaslTheme.danger,
                    onPressed: _leave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallView(RtcEngine? engine) {
    if (!_isVideo) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: WaslTheme.teal,
              child: Text(
                _otherName.isEmpty ? '?' : _otherName[0].toUpperCase(),
                style: const TextStyle(fontSize: 44, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _otherName.isEmpty ? 'Calling…' : _otherName,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voice call inside Wasl — free minutes from Agora.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }
    if (engine == null || !_joined) {
      return const Center(child: CircularProgressIndicator());
    }
    final remoteUid = _remoteUid;
    return Stack(
      children: [
        if (remoteUid != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: remoteUid),
              connection:
                  RtcConnection(channelId: widget.call.channelId),
            ),
          )
        else
          const Center(
            child: Text(
              'Waiting for the other side to join…',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        Positioned(
          right: 16,
          top: 16,
          width: 110,
          height: 150,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _videoOff
                ? Container(
                    color: Colors.black54,
                    child: const Icon(Icons.videocam_off,
                        color: Colors.white),
                  )
                : AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color ?? WaslTheme.teal,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
