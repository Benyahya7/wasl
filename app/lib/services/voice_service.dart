import 'dart:io';

import 'package:record/record.dart';

import '../core/result.dart';
import 'photo_service.dart';

/// Voice notes for the order chat: hold to record, release to send.
/// Recorded as a small AAC file (.m4a, mono 16 kHz — a minute is well
/// under a megabyte), uploaded to the same free Cloudinary storage as
/// the photos (the `video` upload endpoint — Cloudinary treats audio
/// as a video resource; verified live 2026-11-08 on the wasl-delivery
/// preset). Tap to play in the chat.
class VoiceService {
  final AudioRecorder _recorder = AudioRecorder();
  final PhotoService _photos = PhotoService();
  DateTime? _startedAt;

  /// True when the mic permission is granted (asks first when needed).
  Future<bool> ensurePermission() => _recorder.hasPermission();

  /// Start recording to a temp file. Returns the file path.
  Future<Result<String>> startRecording() => guard(() async {
        final ok = await _recorder.hasPermission();
        if (!ok) {
          throw Exception(
              'Microphone permission is off — allow it to send a voice note.');
        }
        final path =
            '${Directory.systemTemp.path}/wasl-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            numChannels: 1,
            sampleRate: 16000,
          ),
          path: path,
        );
        _startedAt = DateTime.now();
        return path;
      });

  /// Stop recording. Returns the file path + length in seconds.
  Future<Result<({String path, int seconds})>> stopRecording() =>
      guard(() async {
        final path = await _recorder.stop();
        final seconds = _startedAt == null
            ? 0
            : DateTime.now().difference(_startedAt!).inSeconds;
        _startedAt = null;
        if (path == null) {
          throw Exception('Nothing was recorded.');
        }
        return (path: path, seconds: seconds < 1 ? 1 : seconds);
      });

  /// Cancel a recording in progress (nothing is kept or sent).
  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    _startedAt = null;
  }

  bool get isRecording => _startedAt != null;

  /// Upload a recorded voice note. Returns null when the Cloudinary
  /// config is missing — the caller must say so plainly, never pretend.
  Future<Result<CloudUpload?>> uploadVoiceNote(String localPath) =>
      _photos.uploadFile(localPath, resourceType: 'video');

  Future<void> dispose() => _recorder.dispose();
}
