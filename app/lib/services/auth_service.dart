import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/result.dart';
import '../models/app_user.dart';

/// Native Google sign-in (google_sign_in 7 + signInWithCredential).
/// NEVER signInWithProvider — its browser redirect dies on Android.
/// The Web Client ID (type 3 from the real google-services.json) is passed
/// as serverClientId — google_sign_in 7 on Android REQUIRES it.
class AuthService {
  static const _webClientId =
      '716697285349-u9uotvnve939g0037l0lq8783netjjfu.apps.googleusercontent.com';

  /// The admin account. On first sign-in the email-keyed admin doc
  /// (users/raiss95@gmail.com, created by the backend seed) is merged into
  /// users/{uid} with role admin — the Hanimo pattern.
  static const adminEmail = 'raiss95@gmail.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;

  Future<Result<void>> initialize() => guard(() async {
        if (!_initialized) {
          await GoogleSignIn.instance
              .initialize(serverClientId: _webClientId);
          _initialized = true;
        }
        // Best-effort silent sign-in; a failure here is not an error.
        try {
          await GoogleSignIn.instance.attemptLightweightAuthentication();
        } catch (_) {}
      });

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Result<UserCredential>> signInWithGoogle() => guard(() async {
        await initialize();
        final account = await GoogleSignIn.instance.authenticate();
        final auth = account.authentication;
        final credential =
            GoogleAuthProvider.credential(idToken: auth.idToken);
        return _auth.signInWithCredential(credential);
      });

  Future<Result<void>> signOut() => guard(() async {
        await GoogleSignIn.instance.signOut();
        await _auth.signOut();
      });

  /// Load the Wasl profile for a uid, or return null when none exists yet.
  Future<Result<AppUser?>> loadProfile(String uid) => guard(() async {
        final doc = await _db.collection('users').doc(uid).get();
        if (!doc.exists) return null;
        return AppUser.fromSnapshot(doc);
      });

  Stream<AppUser?> profileStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromSnapshot(doc) : null);

  /// After the first Google sign-in, make sure a users/{uid} doc exists.
  /// - Admin (raiss95@gmail.com): merge the seed admin doc into users/{uid}.
  /// - Everyone else: no doc yet → the app shows the role picker.
  Future<Result<AppUser?>> ensureProfile(User user) => guard(() async {
        final ref = _db.collection('users').doc(user.uid);
        final existing = await ref.get();
        if (existing.exists) return AppUser.fromSnapshot(existing);

        if ((user.email ?? '').toLowerCase() == adminEmail) {
          // Merge the email-keyed seed admin doc (if it still exists).
          final seed =
              await _db.collection('users').doc(adminEmail).get();
          final data = <String, dynamic>{
            'email': user.email,
            'name': user.displayName ?? 'Soufiane Benyahya',
            'role': 'admin',
            'verificationStatus': 'approved',
            'language': 'en',
          };
          if (seed.exists) {
            final s = seed.data() ?? {};
            for (final k in ['role', 'verificationStatus', 'language']) {
              if (s[k] != null) data[k] = s[k];
            }
          }
          await ref.set(data);
          final created = await ref.get();
          // Direct messages: the admin's uid lives in the public
          // config/wasl doc so stores/drivers can open a chat with the
          // admin (they cannot list users). Written on every admin
          // sign-in, so it heals itself.
          await _db.collection('config').doc('wasl').set({
            'adminUid': user.uid,
            'adminName': (data['name'] ?? 'Wasl admin').toString(),
            'adminEmail': adminEmail,
          }, SetOptions(merge: true));
          return AppUser.fromSnapshot(created);
        }
        return null;
      });

  /// Approved store: make sure a `stores` record exists so drivers can
  /// find and pick this store (S4 link). Created as pending — the admin
  /// approves the store record too. No-op for anyone else.
  Future<Result<void>> ensureStoreRecord(AppUser profile) =>
      guard(() async {
        if (profile.role != 'store' ||
            profile.verificationStatus != 'approved') {
          return;
        }
        final existing = await _db
            .collection('stores')
            .where('ownerUid', isEqualTo: profile.uid)
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) return;
        // The business info the store gave at sign-up (on the users doc)
        // becomes the store record — the admin approved it with that info.
        final userDoc =
            await _db.collection('users').doc(profile.uid).get();
        final u = userDoc.data() ?? {};
        await _db.collection('stores').doc().set({
          'ownerUid': profile.uid,
          'name': (u['businessName'] ?? profile.name).toString(),
          'address': (u['address'] ?? '').toString(),
          'market': (u['market'] ?? 'boston').toString(),
          'storeType': (u['storeType'] ?? '').toString(),
          'phone': (u['phone'] ?? '').toString(),
          'storeLat': (u['storeLat'] as num?)?.toDouble(),
          'storeLng': (u['storeLng'] as num?)?.toDouble(),
          'verificationStatus': 'pending',
          'paymentMethods': {'cash': true, 'card': false},
          'perDeliveryFee': null,
          'monthlyPlan': null,
        });
      });

  /// Create a pending sign-up profile (role chosen by the user).
  /// Security rules only allow creating your own doc as pending.
  /// [extra] carries the registration info the user filled in at sign-up
  /// (business name, phone, address, market, type, vehicle, store) so the
  /// admin sees the full request when approving.
  Future<Result<AppUser>> createPendingProfile({
    required User user,
    required String role,
    required String name,
    Map<String, dynamic> extra = const {},
  }) =>
      guard(() async {
        final ref = _db.collection('users').doc(user.uid);
        await ref.set({
          'email': user.email,
          'name': name,
          'role': role,
          'verificationStatus': 'pending',
          ...extra,
        });
        final created = await ref.get();
        return AppUser.fromSnapshot(created);
      });

  /// Customer sign-up (C3): approved at once, no admin approval —
  /// customers read nothing privileged (tracking is token-based).
  Future<Result<AppUser>> createCustomerProfile({
    required User user,
    required String name,
    Map<String, dynamic> extra = const {},
  }) =>
      guard(() async {
        final ref = _db.collection('users').doc(user.uid);
        await ref.set({
          'email': user.email,
          'name': name,
          'role': 'customer',
          'verificationStatus': 'approved',
          'savedAddresses': [],
          ...extra,
        });
        final created = await ref.get();
        return AppUser.fromSnapshot(created);
      });
}
