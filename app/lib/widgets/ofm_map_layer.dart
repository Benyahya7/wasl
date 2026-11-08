import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

/// OpenFreeMap vector base map (liberty style) as a flutter_map layer.
/// Free, no API key, no account, no billing. The style bundle is cached
/// on disk by StyleReader, so reopening a map is instant.
/// Live tracking is unaffected: driver/store pins are MarkerLayers fed by
/// Firestore, drawn on top of this base map.
class OfmMapLayer extends StatefulWidget {
  const OfmMapLayer({super.key});

  @override
  State<OfmMapLayer> createState() => _OfmMapLayerState();
}

class _OfmMapLayerState extends State<OfmMapLayer> {
  vt.Style? _style;

  @override
  void initState() {
    super.initState();
    vt.StyleReader(
      uri: 'https://tiles.openfreemap.org/styles/liberty',
    ).read().then((style) {
      if (mounted) setState(() => _style = style);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _style?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    if (style == null) {
      return const SizedBox.shrink();
    }
    return vt.VectorTileLayer(
      theme: style.theme,
      tileProviders: style.providers,
      rasterSources: style.rasterSources,
      sprites: style.sprites,
      glyphs: style.glyphs,
    );
  }
}
