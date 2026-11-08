import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/result.dart';

/// Delivery photo proof.
/// - Capture: device camera via image_picker (compressed, 70% quality).
/// - Upload: Cloudinary free tier (25 GB, no card) with an UNSIGNED upload
///   preset — no secret in the app. Dormant until the free Cloudinary
///   account + preset exist: add `assets/cloudinary.json` with
///   {"cloudName": "...", "uploadPreset": "..."}.
///   Until then the photo is saved on the phone and shown in-app, and the
///   app says so plainly instead of pretending it uploaded.
/// A finished Cloudinary upload: the URL to show + the public id
/// (the id the admin needs in the Cloudinary console to delete the
/// file for real — see PhotoCleanupService).
class CloudUpload {
  final String url;
  final String publicId;

  const CloudUpload({required this.url, required this.publicId});
}

class PhotoService {
  final ImagePicker _picker = ImagePicker();

  Future<Result<String>> takeDeliveryPhoto() => guard(() async {
        final file = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1600,
        );
        if (file == null) {
          throw Exception('No photo taken — the delivery is not confirmed yet.');
        }
        return file.path;
      });

  /// Pick a picture for chat (camera or gallery), same compression.
  Future<Result<String>> pickImage({required ImageSource source}) =>
      guard(() async {
        final file = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1600,
        );
        if (file == null) {
          throw Exception('No picture picked.');
        }
        return file.path;
      });

  Future<Result<String?>> uploadPhoto(String localPath) async {
    final uploaded = await uploadFile(localPath, resourceType: 'image');
    return uploaded.fold(
      (u) => Ok(u?.url),
      (m) => Err(m),
    );
  }

  /// Upload a file and keep its Cloudinary public id with the URL.
  /// resourceType 'image' for pictures, 'video' for audio (Cloudinary
  /// treats audio as a video resource — verified live 2026-11-08:
  /// a .wav uploads fine through video/upload on the same unsigned
  /// preset, and the response carries a secure_url + public_id).
  /// Returns null when the Cloudinary config is missing (local-only).
  Future<Result<CloudUpload?>> uploadFile(
    String localPath, {
    required String resourceType,
  }) =>
      guard(() async {
        final config = await _loadCloudinaryConfig();
        if (config == null) return null; // local-only, honest about it
        final uri = Uri.parse(
            'https://api.cloudinary.com/v1_1/${config['cloudName']}/$resourceType/upload');
        final request = http.MultipartRequest('POST', uri)
          ..fields['upload_preset'] = config['uploadPreset'] as String
          ..files.add(await http.MultipartFile.fromPath('file', localPath));
        final response = await request.send();
        final body = await response.stream.bytesToString();
        if (response.statusCode != 200) {
          throw Exception(
              'Upload failed (${response.statusCode}).');
        }
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final url = decoded['secure_url'] as String?;
        final publicId = decoded['public_id'] as String?;
        if (url == null || publicId == null) {
          throw Exception('Upload finished but Cloudinary sent no URL.');
        }
        return CloudUpload(url: url, publicId: publicId);
      });

  Future<Map<String, dynamic>?> _loadCloudinaryConfig() async {
    try {
      final raw =
          await rootBundle.loadString('assets/cloudinary.json');
      final config = jsonDecode(raw) as Map<String, dynamic>;
      if ((config['cloudName'] as String?)?.isNotEmpty == true &&
          (config['uploadPreset'] as String?)?.isNotEmpty == true) {
        return config;
      }
      return null;
    } catch (_) {
      return null; // no config file yet — local-only mode
    }
  }

  /// Local photo file for display (works offline, no upload needed).
  File photoFile(String path) => File(path);
}
