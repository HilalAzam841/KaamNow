import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../core/maps/google_maps.dart';
import '../../core/session.dart';
import '../../l10n/l10n.dart';

class MapPin {
  MapPin(this.point, {required this.icon, required this.color, this.label});
  final LatLng point;
  final IconData icon;
  final Color color;
  final String? label;
}

/// The app's map: Google Maps when set up (see MapProvider), OpenStreetMap otherwise.
/// Tapping reports a point (used to place the job location pin).
class KaamMap extends StatelessWidget {
  const KaamMap({super.key, required this.center, this.zoom = 14, this.pins = const [], this.trail = const [],
      this.onTap, this.controller, this.height = 260});

  final LatLng center;
  final double zoom;
  final List<MapPin> pins;
  final List<LatLng> trail;
  final void Function(LatLng)? onTap;
  final MapController? controller;
  final double height;

  static String _browserKey(BuildContext context) {
    try {
      return context.read<Session>().config.googleMapsBrowserKey;
    } on ProviderNotFoundException {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _browserKey(context);
    final osm = _osm(context);
    if (!MapProvider.useGoogle(browserKey: key)) return osm;
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FutureBuilder<bool>(
          future: MapProvider.ready(key),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return snap.data! ? _GoogleMap(map: this) : osm;
          },
        ),
      ),
    );
  }

  Widget _osm(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              onTap: onTap == null ? null : (_, p) => onTap!(p),
            ),
            children: [
              TileLayer(urlTemplate: AppConfig.tileUrl, userAgentPackageName: 'pk.kaamnow.app'),
              if (trail.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: trail, strokeWidth: 4, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
                ]),
              MarkerLayer(markers: [
                for (final p in pins)
                  Marker(
                    point: p.point,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Tooltip(message: p.label ?? '', child: Icon(p.icon, color: p.color, size: 40)),
                  ),
              ]),
            ],
          ),
          Positioned(
            right: 6,
            bottom: 4,
            child: Container(
              color: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(context.t.osmCredit, style: TextStyle(fontSize: 10, color: Colors.black87)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Google Maps with the same pins, trail and tap behaviour as the OpenStreetMap view.
class _GoogleMap extends StatelessWidget {
  const _GoogleMap({required this.map});
  final KaamMap map;

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  /// Google's pins come in hues; blue pins (the worker) stay blue, the rest are red.
  static double _hue(Color c) => c.b > c.r ? gm.BitmapDescriptor.hueAzure : gm.BitmapDescriptor.hueRed;

  @override
  Widget build(BuildContext context) {
    return gm.GoogleMap(
      key: const Key('google-map'),
      initialCameraPosition: gm.CameraPosition(target: _g(map.center), zoom: map.zoom),
      onTap: map.onTap == null ? null : (p) => map.onTap!(LatLng(p.latitude, p.longitude)),
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: kIsWeb,
      // Lets the map pan and zoom inside scrolling pages.
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
      markers: {
        for (final (i, p) in map.pins.indexed)
          gm.Marker(
            markerId: gm.MarkerId('pin-$i'),
            position: _g(p.point),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(_hue(p.color)),
            infoWindow: p.label == null ? gm.InfoWindow.noText : gm.InfoWindow(title: p.label),
          ),
      },
      polylines: {
        if (map.trail.length > 1)
          gm.Polyline(
            polylineId: const gm.PolylineId('trail'),
            points: [for (final p in map.trail) _g(p)],
            width: 4,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ),
      },
    );
  }
}
