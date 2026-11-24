import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../config.dart';
import '../../l10n/l10n.dart';

class MapPin {
  MapPin(this.point, {required this.icon, required this.color, this.label});
  final LatLng point;
  final IconData icon;
  final Color color;
  final String? label;
}

/// OpenStreetMap view. Tapping reports a point (used to place the job location pin).
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

  @override
  Widget build(BuildContext context) {
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
