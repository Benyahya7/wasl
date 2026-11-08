import 'package:firebase_core/firebase_core.dart';

/// Firebase options for the Wasl backend (project wasl-delivery-app).
/// These are client identifiers from the real google-services.json
/// (downloaded from the Firebase console, never reconstructed) — the same
/// values ship inside the Android app and are safe to embed here.
class DefaultFirebaseOptions {
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBek4297z7mTlN5JkSbiZmVYPi2cGuBR0k',
    appId: '1:716697285349:android:6844a228fb181951c99a0c',
    messagingSenderId: '716697285349',
    projectId: 'wasl-delivery-app',
    storageBucket: 'wasl-delivery-app.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform => android;
}
