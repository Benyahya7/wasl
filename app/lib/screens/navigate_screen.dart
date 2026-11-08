import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/delivery.dart';
import '../theme.dart';
import '../widgets/ofm_map_layer.dart';

/// Which leg of the trip this screen shows. The driver goes to the store
/// FIRST (toStore, right after accepting) and only then to the customer
/// (toCustomer, after the pickup code).
enum NavigateLeg { toStore, toCustomer }

/// D10 Navigate: in-app map (flutter_map + free OpenStreetMap tiles) with
/// the route drawn, plus the Google Maps handoff for turn-by-turn. The
/// driver always has the choice.
/// Mapbox in-app routing + ETA is the next step once the free Mapbox token
/// exists; until then the route is a direct line and the ETA is the
/// prototype estimate.
class NavigateScreen extends StatelessWidget {
  final Delivery delivery;
  final VoidCallback onArrived;
  final NavigateLeg leg;

  /// The store's real pin (dropped at registration). Null → the pilot
  /// fallback point while the store has no pin yet.
  final LatLng? storePoint;

  const NavigateScreen({
    super.key,
    required this.delivery,
    required this.onArrived,
    this.leg = NavigateLeg.toCustomer,
    this.storePoint,
  });

  // Pilot area: East Boston. Real geocoding needs the Mapbox token.
  static const _pilotStorePoint =
      LatLng(42.3817, -71.0320); // Mira's Coffee
  static const _fallbackCustomerPoint =
      LatLng(42.3765, -71.0355); // Bennington St

  /// The store point: the pin the store dropped at registration, or the
  /// pilot fallback while no pin exists.
  LatLng get _storePoint => storePoint ?? _pilotStorePoint;

  /// The customer point: the pin the store dropped (S2), or the pilot
  /// fallback while no pin exists.
  LatLng get _customerPoint =>
      delivery.customerLat != null && delivery.customerLng != null
          ? LatLng(delivery.customerLat!, delivery.customerLng!)
          : _fallbackCustomerPoint;

  Future<void> _openGoogleMaps() async {
    // toStore: no origin — Google starts from the driver's current
    // location and routes to the store. toCustomer: store → customer.
    final uri = leg == NavigateLeg.toStore
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&destination=${_storePoint.latitude},${_storePoint.longitude}'
            '&travelmode=driving',
          )
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1'
            '&origin=${_storePoint.latitude},${_storePoint.longitude}'
            '&destination=${_customerPoint.latitude},${_customerPoint.longitude}'
            '&travelmode=driving',
          );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Google Maps.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(leg == NavigateLeg.toStore
              ? 'Go to ${delivery.storeName}'
              : 'Delivering #${delivery.orderNumber}')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: leg == NavigateLeg.toStore
                    ? _storePoint
                    : LatLng(
                        (_storePoint.latitude + _customerPoint.latitude) / 2,
                        (_storePoint.longitude + _customerPoint.longitude) / 2,
                      ),
                initialZoom: 15,
              ),
              children: [
                const OfmMapLayer(),
                SimpleAttributionWidget(
                  source: const Text('© OpenStreetMap contributors'),
                ),
                if (leg == NavigateLeg.toCustomer)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_storePoint, _customerPoint],
                        color: WaslTheme.teal,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _storePoint,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.store,
                          color: WaslTheme.teal, size: 36),
                    ),
                    if (leg == NavigateLeg.toCustomer)
                      Marker(
                        point: _customerPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on,
                            color: WaslTheme.amber, size: 36),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  leg == NavigateLeg.toStore
                      ? delivery.storeName
                      : delivery.customerAddress,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  leg == NavigateLeg.toStore
                      ? 'Pick up ${delivery.items} — enter the code from the order label at the store.'
                      : '${delivery.customerName} • ${delivery.items}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ETA ~6 min (estimate — live routing needs the Mapbox token)',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await _openGoogleMaps();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text('Google Maps'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onArrived,
                        child: Text(leg == NavigateLeg.toStore
                            ? "I'm at the store"
                            : "I've arrived"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
