import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../models/geo_point.dart';

LatLng toLatLng(GeoPoint p) => LatLng(p.lat, p.lng);

/// Centre of India, used before the first location fix.
const indiaCenter = LatLng(22.5, 79.0);

/// OpenStreetMap-based map with the user's position, an optional route and
/// extra markers.
class SafetyMap extends StatefulWidget {
  const SafetyMap({
    super.key,
    this.controller,
    this.me,
    this.path = const [],
    this.markers = const [],
    this.pathColor = AppColors.brand,
    this.meColor = AppColors.live,
    this.initialZoom = 16,
    this.interactive = true,
    this.onTap,
    this.onMapReady,
    this.followMe = false,
  });

  /// Tiles are disabled in widget tests (no network).
  static bool showTiles = true;

  final MapController? controller;
  final GeoPoint? me;
  final List<GeoPoint> path;
  final List<Marker> markers;
  final Color pathColor;
  final Color meColor;
  final double initialZoom;
  final bool interactive;
  final VoidCallback? onTap;
  final VoidCallback? onMapReady;

  /// Keep the map centred on [me] as it moves.
  final bool followMe;

  @override
  State<SafetyMap> createState() => _SafetyMapState();
}

class _SafetyMapState extends State<SafetyMap> {
  late final MapController _controller = widget.controller ?? MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(SafetyMap old) {
    super.didUpdateWidget(old);
    final me = widget.me;
    if (!widget.followMe || !_ready || me == null) return;
    if (old.me?.lat == me.lat && old.me?.lng == me.lng) return;
    // Zoom in on the first fix; afterwards keep the user's zoom level.
    final zoom = old.me == null ? widget.initialZoom : _controller.camera.zoom;
    _controller.move(toLatLng(me), zoom);
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final path = widget.path;
    final center = me != null
        ? toLatLng(me)
        : path.isNotEmpty
        ? toLatLng(path.last)
        : indiaCenter;
    final zoom = me == null && path.isEmpty ? 4.5 : widget.initialZoom;
    final meColor = widget.meColor;
    final onTap = widget.onTap;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3,
        maxZoom: 19,
        onTap: onTap == null ? null : (_, _) => onTap(),
        onMapReady: () {
          _ready = true;
          widget.onMapReady?.call();
        },
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        if (SafetyMap.showTiles)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.guardian.safety',
            maxNativeZoom: 19,
          ),
        if (path.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: path.map(toLatLng).toList(),
                strokeWidth: 5,
                color: widget.pathColor.withValues(alpha: 0.8),
              ),
            ],
          ),
        if (me != null && me.accuracy != null)
          CircleLayer(
            circles: [
              CircleMarker(
                point: toLatLng(me),
                radius: me.accuracy!,
                useRadiusInMeter: true,
                color: meColor.withValues(alpha: 0.12),
                borderColor: meColor.withValues(alpha: 0.5),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            ...widget.markers,
            if (me != null)
              Marker(
                point: toLatLng(me),
                width: 26,
                height: 26,
                child: _MeDot(color: meColor),
              ),
          ],
        ),
        if (SafetyMap.showTiles)
          SimpleAttributionWidget(
            source: const Text('OpenStreetMap'),
            onTap: () =>
                launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          ),
      ],
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
      ),
    );
  }
}

/// A round, coloured map pin with an icon.
class PinMarker extends StatelessWidget {
  const PinMarker({
    super.key,
    required this.icon,
    required this.color,
    this.selected = false,
  });
  final IconData icon;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.25 : 1,
      duration: const Duration(milliseconds: 150),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
