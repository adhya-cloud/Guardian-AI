import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../models/geo_point.dart';
import '../../models/place.dart';
import '../../services/device_bridge.dart';
import '../../services/location_service.dart';
import '../../services/places_service.dart';
import '../../state/safety_controller.dart';
import '../widgets/labels.dart';
import '../widgets/safety_map.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.active});

  /// Location updates run only while the tab is visible.
  final bool active;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  StreamSubscription<GeoPoint>? _sub;
  LocationAccess? _access;
  GeoPoint? _me;
  bool _follow = true;
  bool _mapReady = false;
  bool _centered = false;

  List<Place> _places = const [];
  bool _loadingPlaces = false;
  String? _placesError;
  GeoPoint? _searchedAt;
  PlaceCategory? _filter;
  Place? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(MapScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _start();
    if (!widget.active && old.active) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  Future<void> _start() async {
    final location = context.read<LocationService>();
    final access = await location.access();
    if (!mounted) return;
    setState(() => _access = access);
    if (access != LocationAccess.granted) return;
    final known = context.read<SafetyController>().lastLocation;
    if (_me == null && known != null) _onPosition(known);
    _sub?.cancel();
    _sub = location.positionStream().listen(
      _onPosition,
      onError: (Object _) {},
    );
    final fix = await location.currentPosition();
    if (fix != null && mounted) _onPosition(fix);
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _onPosition(GeoPoint p) {
    if (!mounted) return;
    setState(() => _me = p);
    if (_mapReady && (_follow || !_centered)) {
      // Zoom in on the first fix; afterwards keep the user's zoom level.
      _map.move(toLatLng(p), _centered ? _map.camera.zoom : 16);
      _centered = true;
    }
    if (_searchedAt == null || p.distanceTo(_searchedAt!) > 1500) {
      _loadPlaces(p);
    }
  }

  Future<void> _loadPlaces(GeoPoint center) async {
    if (_loadingPlaces) return;
    setState(() {
      _loadingPlaces = true;
      _placesError = null;
      _searchedAt = center;
    });
    final service = context.read<PlacesService>();
    try {
      var places = await service.nearby(center, radiusMeters: 3000);
      if (places.length < 5) {
        places = await service.nearby(center, radiusMeters: 8000);
      }
      if (!mounted) return;
      setState(() => _places = places);
    } on PlacesException {
      if (mounted) {
        setState(() => _placesError = AppStrings.of(context).t('placesError'));
      }
    } finally {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  void _searchHere() {
    if (!_mapReady) return;
    final c = _map.camera.center;
    _follow = false;
    _loadPlaces(
      GeoPoint(lat: c.latitude, lng: c.longitude, time: DateTime.now()),
    );
  }

  void _recenter() {
    setState(() => _follow = true);
    if (_me != null && _mapReady) _map.move(toLatLng(_me!), 16);
  }

  List<Place> get _visible => _filter == null
      ? _places
      : _places.where((p) => p.category == _filter).toList();

  void _select(Place place) {
    setState(() {
      _selected = place;
      _follow = false;
    });
    if (_mapReady) _map.move(_placeLatLng(place), 16);
    _showDetails(place);
  }

  Future<void> _showDetails(Place place) async {
    final s = AppStrings.of(context);
    final device = context.read<DeviceBridge>();
    final from = _me ?? _searchedAt;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: placeColor(place.category),
                    child: Icon(placeIcon(place.category), color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name.isEmpty
                              ? placeCategoryLabel(place.category, s)
                              : place.name,
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          [
                            placeCategoryLabel(place.category, s),
                            if (from != null)
                              s.t('distanceAway', {
                                'd': formatDistance(place.distanceFrom(from)),
                              }),
                          ].join(' · '),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (place.address != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(place.address!)),
                  ],
                ),
              ],
              if (place.openingHours != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(place.openingHours!)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(place.directionsUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.directions),
                      label: Text(s.t('directions')),
                    ),
                  ),
                  if (place.phone != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            device.call(place.phone!.split(';').first.trim()),
                        icon: const Icon(Icons.call),
                        label: Text(s.t('call')),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: s.t('share'),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${place.name.isEmpty ? placeCategoryLabel(place.category, s) : place.name}: https://maps.google.com/?q=${place.lat},${place.lng}',
                      ),
                    ),
                    icon: const Icon(Icons.share),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final visible = _visible;
    final from = _me ?? _searchedAt;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SafetyMap(
              controller: _map,
              me: _me,
              onMapReady: () {
                _mapReady = true;
                if (_me != null) {
                  _map.move(toLatLng(_me!), 16);
                  _centered = true;
                }
              },
              markers: [
                for (final p in visible)
                  Marker(
                    point: _placeLatLng(p),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => _select(p),
                      child: PinMarker(
                        icon: placeIcon(p.category),
                        color: placeColor(p.category),
                        selected: _selected?.id == p.id,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _Filter(
                      label: s.t('filterAll'),
                      selected: _filter == null,
                      onTap: () => setState(() => _filter = null),
                    ),
                    for (final cat in PlaceCategory.values)
                      _Filter(
                        label: placeCategoryLabel(cat, s),
                        icon: placeIcon(cat),
                        color: placeColor(cat),
                        selected: _filter == cat,
                        onTap: () => setState(
                          () => _filter = _filter == cat ? null : cat,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: MediaQuery.sizeOf(context).height * 0.3 + 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'search_here',
                  tooltip: s.t('searchThisArea'),
                  onPressed: _searchHere,
                  child: const Icon(Icons.travel_explore),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'recenter',
                  tooltip: s.t('myLocation'),
                  onPressed: _recenter,
                  child: Icon(
                    _follow ? Icons.my_location : Icons.location_searching,
                  ),
                ),
              ],
            ),
          ),
          if (_access != null && _access != LocationAccess.granted)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.paddingOf(context).top + 64,
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.location_off),
                  title: Text(
                    _access == LocationAccess.serviceDisabled
                        ? s.t('gpsOff')
                        : s.t('locationPermissionNeeded'),
                  ),
                  trailing: FilledButton(
                    onPressed: () async {
                      final location = context.read<LocationService>();
                      if (_access == LocationAccess.serviceDisabled) {
                        await location.openLocationSettings();
                      } else if (_access == LocationAccess.deniedForever) {
                        await context
                            .read<SafetyController>()
                            .permissions
                            .openSettings();
                      }
                      _start();
                    },
                    child: Text(s.t('enable')),
                  ),
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.12,
            maxChildSize: 0.85,
            snap: true,
            builder: (context, scroll) => Material(
              elevation: 8,
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: ListView(
                controller: scroll,
                padding: EdgeInsets.zero,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _loadingPlaces
                                ? s.t('searchingNearby')
                                : _placesError ??
                                      (from == null
                                          ? s.t('waitingForGps')
                                          : s.t('placesFound', {
                                              'n': visible.length,
                                            })),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (_loadingPlaces)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_placesError != null && from != null)
                          TextButton(
                            onPressed: () => _loadPlaces(from),
                            child: Text(s.t('retry')),
                          ),
                      ],
                    ),
                  ),
                  for (final p in visible.take(60))
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: placeColor(
                          p.category,
                        ).withValues(alpha: 0.12),
                        child: Icon(
                          placeIcon(p.category),
                          color: placeColor(p.category),
                        ),
                      ),
                      title: Text(
                        p.name.isEmpty
                            ? placeCategoryLabel(p.category, s)
                            : p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (from != null)
                            formatDistance(p.distanceFrom(from)),
                          p.address ?? placeCategoryLabel(p.category, s),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        tooltip: s.t('directions'),
                        icon: const Icon(Icons.directions),
                        onPressed: () => launchUrl(
                          Uri.parse(p.directionsUrl),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      onTap: () => _select(p),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      s.t('placesAttribution'),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: icon == null ? null : Icon(icon, size: 18, color: color),
        label: Text(label),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 2,
      ),
    );
  }
}

LatLng _placeLatLng(Place p) => LatLng(p.lat, p.lng);
