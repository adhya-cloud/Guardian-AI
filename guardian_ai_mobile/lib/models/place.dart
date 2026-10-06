import 'geo_point.dart';

enum PlaceCategory { police, hospital, pharmacy, fireStation }

/// A nearby place of help, from OpenStreetMap.
class Place {
  const Place({
    required this.id,
    required this.category,
    required this.name,
    required this.lat,
    required this.lng,
    this.phone,
    this.address,
    this.openingHours,
  });

  final String id;
  final PlaceCategory category;

  /// Empty when OpenStreetMap has no name for the place.
  final String name;
  final double lat;
  final double lng;
  final String? phone;
  final String? address;
  final String? openingHours;

  double distanceFrom(GeoPoint p) => distanceMeters(p.lat, p.lng, lat, lng);

  String get directionsUrl =>
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
}
