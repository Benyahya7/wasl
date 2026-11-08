import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../core/result.dart';

/// Trip-only driver location sharing (S10/A6).
/// The driver's position is written to their drivers doc ONLY while they
/// have an active job (accepted / picked up / delivering) — never all day,
/// never when off duty. The store and the admin read it from there; the
/// position is a plain lat/lng + timestamp, and the maps only show
/// positions newer than 10 minutes.
class LocationService {
  StreamSubscription<Position>? _subscription;
  String? _driverDocId;

  bool get isSharing => _subscription != null;

  /// Start sharing while [driverDocId] has an active job. Returns an
  /// error (shown to the driver) when location is off or denied —
  /// sharing simply stays off, the job still works.
  Future<Result<void>> start(String driverDocId) async {
    if (_subscription != null && _driverDocId == driverDocId) {
      return const Ok(null);
    }
    await stop();
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      return const Err(
          'Location is off on this phone — turn it on to share your position on the live maps.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const Err(
          'Location permission denied — your position will not show on the store and admin maps.');
    }
    _driverDocId = driverDocId;
    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // a new write every 10 m moved
      ),
    ).listen((position) {
      FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverDocId)
          .update({
            'lastLat': position.latitude,
            'lastLng': position.longitude,
            'lastSeen': FieldValue.serverTimestamp(),
          })
          .catchError((_) {});
    });
    return const Ok(null);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _driverDocId = null;
  }
}
