import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo_point.dart';
import '../models/place.dart';

class PlacesException implements Exception {
  PlacesException(this.message);
  final String message;
  @override
  String toString() => 'PlacesException: $message';
}

/// Finds nearby police stations, hospitals, pharmacies and fire stations
/// using OpenStreetMap data via the public Overpass API (no API key).
class PlacesService {
  PlacesService({http.Client? client, List<String>? endpoints})
    : _http = client ?? http.Client(),
      endpoints =
          endpoints ??
          const [
            'https://overpass-api.de/api/interpreter',
            'https://overpass.kumi.systems/api/interpreter',
          ];

  final http.Client _http;
  final List<String> endpoints;

  static const _tags = {
    PlaceCategory.police: ['amenity=police'],
    PlaceCategory.hospital: [
      'amenity=hospital',
      'amenity=clinic',
      'healthcare=hospital',
    ],
    PlaceCategory.pharmacy: ['amenity=pharmacy'],
    PlaceCategory.fireStation: ['amenity=fire_station'],
  };

  final _cache = <String, (DateTime, List<Place>)>{};

  static String buildQuery(
    GeoPoint center,
    int radiusMeters,
    Set<PlaceCategory> categories,
  ) {
    final around =
        '(around:$radiusMeters,${center.lat.toStringAsFixed(5)},${center.lng.toStringAsFixed(5)})';
    final parts = <String>[];
    for (final c in categories) {
      for (final tag in _tags[c]!) {
        final [k, v] = tag.split('=');
        parts.add('nwr["$k"="$v"]$around;');
      }
    }
    return '[out:json][timeout:25];(${parts.join()});out center tags 200;';
  }

  /// Parses an Overpass JSON response; nearest first.
  static List<Place> parse(Map<String, dynamic> json, GeoPoint from) {
    final places = <Place>[];
    final seen = <String>{};
    for (final raw in json['elements'] as List? ?? const []) {
      final el = raw as Map<String, dynamic>;
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final center = el['center'] as Map<String, dynamic>?;
      final lat = (el['lat'] ?? center?['lat']) as num?;
      final lng = (el['lon'] ?? center?['lon']) as num?;
      if (lat == null || lng == null) continue;
      final category = _categoryOf(tags);
      if (category == null) continue;
      final id = '${el['type']}/${el['id']}';
      if (!seen.add(id)) continue;
      places.add(
        Place(
          id: id,
          category: category,
          name: (tags['name:en'] ?? tags['name'] ?? '') as String,
          lat: lat.toDouble(),
          lng: lng.toDouble(),
          phone:
              (tags['phone'] ??
                      tags['contact:phone'] ??
                      tags['emergency:phone'])
                  as String?,
          address: _address(tags),
          openingHours: tags['opening_hours'] as String?,
        ),
      );
    }
    places.sort((a, b) => a.distanceFrom(from).compareTo(b.distanceFrom(from)));
    return places;
  }

  static PlaceCategory? _categoryOf(Map<String, dynamic> tags) {
    final amenity = tags['amenity'];
    if (amenity == 'police') return PlaceCategory.police;
    if (amenity == 'hospital' ||
        amenity == 'clinic' ||
        tags['healthcare'] == 'hospital') {
      return PlaceCategory.hospital;
    }
    if (amenity == 'pharmacy') return PlaceCategory.pharmacy;
    if (amenity == 'fire_station') return PlaceCategory.fireStation;
    return null;
  }

  static String? _address(Map<String, dynamic> tags) {
    final full = tags['addr:full'] as String?;
    if (full != null) return full;
    final parts = [
      [
        tags['addr:housenumber'],
        tags['addr:street'],
      ].whereType<String>().join(' '),
      tags['addr:suburb'] ?? tags['addr:neighbourhood'],
      tags['addr:city'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  Future<List<Place>> nearby(
    GeoPoint center, {
    int radiusMeters = 3000,
    Set<PlaceCategory> categories = const {...PlaceCategory.values},
  }) async {
    // Re-use results for ~5 min when the user hasn't moved far.
    final key =
        '${center.lat.toStringAsFixed(2)},${center.lng.toStringAsFixed(2)},$radiusMeters,${categories.map((c) => c.index).join()}';
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1).inMinutes < 5) {
      return cached.$2;
    }

    final query = buildQuery(center, radiusMeters, categories);
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        final res = await _http
            .post(
              Uri.parse(endpoint),
              body: {'data': query},
              headers: {'User-Agent': 'GuardianSafetyApp/2.0'},
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) {
          lastError = 'HTTP ${res.statusCode}';
          continue;
        }
        final places = parse(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
          center,
        );
        _cache[key] = (DateTime.now(), places);
        return places;
      } on Exception catch (e) {
        lastError = e;
      }
    }
    throw PlacesException('Could not load nearby places ($lastError)');
  }
}
