import 'dart:math' as math;

/// A single location fix.
class GeoPoint {
  const GeoPoint({
    required this.lat,
    required this.lng,
    required this.time,
    this.accuracy,
    this.speed,
    this.heading,
  });

  final double lat;
  final double lng;
  final DateTime time;

  /// Horizontal accuracy radius in metres.
  final double? accuracy;

  /// Metres per second.
  final double? speed;

  /// Degrees clockwise from north.
  final double? heading;

  String get mapsUrl =>
      'https://maps.google.com/?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

  String get coordinates =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  /// Great-circle distance in metres.
  double distanceTo(GeoPoint other) =>
      distanceMeters(lat, lng, other.lat, other.lng);

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    't': time.toUtc().toIso8601String(),
    if (accuracy != null) 'acc': accuracy,
    if (speed != null) 'spd': speed,
    if (heading != null) 'hdg': heading,
  };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    time: DateTime.parse(json['t'] as String),
    accuracy: (json['acc'] as num?)?.toDouble(),
    speed: (json['spd'] as num?)?.toDouble(),
    heading: (json['hdg'] as num?)?.toDouble(),
  );
}

/// Haversine distance in metres.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}

/// "850 m" / "2.4 km"
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters < 10000 ? 1 : 0)} km';
}
