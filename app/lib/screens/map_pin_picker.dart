import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import '../widgets/ofm_map_layer.dart';

/// Drop a pin on the map for the delivery location (S2).
/// Some addresses are not on the map at all — the store taps the exact
/// spot instead of trusting the typed address. The pin is optional:
/// without one, the delivery keeps the typed address only.
/// Pops a LatLng to set the pin, `false` to clear it, null on back.
class MapPinPicker extends StatefulWidget {
  final String address;
  final LatLng? initialPin;

  const MapPinPicker({
    super.key,
    required this.address,
    this.initialPin,
  });

  @override
  State<MapPinPicker> createState() => _MapPinPickerState();
}

class _MapPinPickerState extends State<MapPinPicker> {
  // Pilot area: East Boston. The store moves the pin where it belongs.
  static const _defaultCenter = LatLng(42.3781, -71.0365);
  LatLng? _pin;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialPin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pin the location')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: WaslTheme.teal.withValues(alpha: 0.08),
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.address,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Tap the map to drop the pin on the exact spot. '
              'Use this when the address is not on the map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _pin ?? _defaultCenter,
                initialZoom: 15,
                onTap: (_, point) => setState(() => _pin = point),
              ),
              children: [
                const OfmMapLayer(),
                SimpleAttributionWidget(
                  source: const Text('© OpenStreetMap contributors'),
                ),
                if (_pin != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin!,
                        width: 44,
                        height: 44,
                        child: const Icon(Icons.location_on,
                            color: WaslTheme.amber, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pin != null)
                  Text(
                    'Pin: ${_pin!.latitude.toStringAsFixed(5)}, '
                    '${_pin!.longitude.toStringAsFixed(5)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No pin'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _pin == null
                            ? null
                            : () => Navigator.pop(context, _pin),
                        child: const Text('Use this pin'),
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
