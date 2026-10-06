import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/geo_point.dart';
import '../models/incident.dart';

class TrackingException implements Exception {
  TrackingException(this.message);
  final String message;
  @override
  String toString() => 'TrackingException: $message';
}

/// Client for the Guardian tracking server (see /tracking-server).
///
/// The phone creates a session, receives a secret owner key plus a public
/// view link, and posts location points that contacts watch on a web map.
class TrackingClient {
  TrackingClient(
    String baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
       _http = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers([String? ownerKey]) => {
    'content-type': 'application/json',
    if (ownerKey != null) 'authorization': 'Bearer $ownerKey',
  };

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(timeout);
    } on Exception catch (e) {
      throw TrackingException('Server unreachable: $e');
    }
  }

  Future<bool> ping() async {
    try {
      final res = await _http.get(_uri('/health')).timeout(timeout);
      return res.statusCode == 200 &&
          (jsonDecode(res.body) as Map<String, dynamic>)['status'] == 'ok';
    } on Exception {
      return false;
    }
  }

  /// [reason] is 'sos', 'journey' or 'live'.
  Future<TrackingLink> create({
    required String name,
    required String reason,
    required int durationMinutes,
    String? note,
  }) async {
    final res = await _send(
      _http.post(
        _uri('/api/v1/sessions'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'reason': reason,
          'durationMinutes': durationMinutes < 5 ? 5 : durationMinutes,
          if (note != null && note.isNotEmpty) 'note': note,
        }),
      ),
    );
    if (res.statusCode != 201) {
      throw TrackingException('Create failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return TrackingLink(
      sessionId: body['id'] as String,
      ownerKey: body['ownerKey'] as String,
      viewUrl: body['viewUrl'] as String,
    );
  }

  Future<void> push(
    TrackingLink link,
    List<GeoPoint> points, {
    int? battery,
  }) async {
    if (points.isEmpty) return;
    final res = await _send(
      _http.post(
        _uri('/api/v1/sessions/${link.sessionId}/points'),
        headers: _headers(link.ownerKey),
        body: jsonEncode({
          'points': [
            for (final (i, p) in points.indexed)
              {
                'lat': p.lat,
                'lng': p.lng,
                't': p.time.millisecondsSinceEpoch,
                if (p.accuracy != null) 'accuracy': p.accuracy,
                if (p.speed != null) 'speed': p.speed,
                if (p.heading != null) 'heading': p.heading,
                if (battery != null && i == points.length - 1)
                  'battery': battery,
              },
          ],
        }),
      ),
    );
    if (res.statusCode != 202) {
      throw TrackingException('Push failed (${res.statusCode})');
    }
  }

  Future<void> update(
    TrackingLink link, {
    String? reason,
    int? extendMinutes,
    bool end = false,
  }) async {
    final res = await _send(
      _http.patch(
        _uri('/api/v1/sessions/${link.sessionId}'),
        headers: _headers(link.ownerKey),
        body: jsonEncode({
          'reason': ?reason,
          'extendMinutes': ?extendMinutes,
          if (end) 'status': 'ended',
        }),
      ),
    );
    if (res.statusCode != 200) {
      throw TrackingException('Update failed (${res.statusCode})');
    }
  }
}
