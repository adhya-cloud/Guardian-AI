import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai_mobile/core/messages.dart';
import 'package:guardian_ai_mobile/core/phone.dart';
import 'package:guardian_ai_mobile/core/strings.dart';
import 'package:guardian_ai_mobile/models/geo_point.dart';
import 'package:guardian_ai_mobile/models/incident.dart';
import 'package:guardian_ai_mobile/models/place.dart';
import 'package:guardian_ai_mobile/services/places_service.dart';
import 'package:guardian_ai_mobile/services/shake_detector.dart';
import 'package:guardian_ai_mobile/services/tracking_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('phone numbers', () {
    test('normalises Indian mobile formats', () {
      expect(normalizePhone('+91 98765 43210'), '+919876543210');
      expect(normalizePhone('098765-43210'), '09876543210');
      expect(normalizePhone('(0120) 456-7890'), '01204567890');
    });

    test('rejects text and wrong lengths', () {
      expect(normalizePhone('call me'), isNull);
      expect(normalizePhone('123456'), isNull);
      expect(normalizePhone('1234567890123456'), isNull);
    });

    test('dial numbers allow short codes', () {
      expect(normalizeDialNumber('112'), '112');
      expect(normalizeDialNumber('1-0-9-1'), '1091');
      expect(normalizeDialNumber('call 112'), isNull);
    });

    test('formats and compares', () {
      expect(formatPhone('+919876543210'), '+91 98765 43210');
      expect(formatPhone('9876543210'), '98765 43210');
      expect(samePhone('+91 98765 43210', '09876543210'), isTrue);
      expect(samePhone('+919876543210', '+919876543211'), isFalse);
    });
  });

  group('geo', () {
    test('distance and formatting', () {
      final delhi = GeoPoint(lat: 28.6139, lng: 77.2090, time: DateTime(2026));
      final noida = GeoPoint(lat: 28.5355, lng: 77.3910, time: DateTime(2026));
      expect(delhi.distanceTo(noida), closeTo(19700, 800));
      expect(formatDistance(850), '850 m');
      expect(formatDistance(2400), '2.4 km');
      expect(formatDistance(23400), '23 km');
    });
  });

  group('alert messages', () {
    final p = GeoPoint(
      lat: 12.9716,
      lng: 77.5946,
      time: DateTime(2026, 9, 30, 21, 5),
      accuracy: 9.6,
    );

    test('English SOS is plain GSM text with a maps link', () {
      final m = AlertMessages('en', name: 'Asha').sosAlert(
        location: p,
        battery: 41,
        medical: 'O+',
        liveUrl: 'https://t.example/t/x',
      );
      expect(
        m,
        'SOS from Asha: I need help now! My location: https://maps.google.com/?q=12.971600,77.594600 (+/-10m, 9:05 PM). Battery 41%. Medical: O+. Live map: https://t.example/t/x',
      );
      expect(
        RegExp(r'^[\x20-\x7E]*$').hasMatch(m),
        isTrue,
        reason: 'ASCII keeps SMS segments small',
      );
    });

    test('missed check-in names the destination and deadline', () {
      final m = AlertMessages('en', name: 'Asha').missedCheckIn(
        deadline: DateTime(2026, 9, 30, 22, 30),
        destination: 'Home',
        location: p,
      );
      expect(
        m,
        startsWith(
          'ALERT: Asha did not check in from their journey to Home by 10:30 PM.',
        ),
      );
    });

    test('Hindi messages', () {
      expect(AlertMessages('hi', name: 'आशा').safe(), contains('सुरक्षित'));
    });
  });

  group('shake detector', () {
    test(
      'fires after enough strong shakes inside the window, then cools down',
      () {
        var fired = 0;
        final d = ShakeDetector(onShake: () => fired++);
        var t = DateTime(2026);
        void shake() {
          t = t.add(const Duration(milliseconds: 200));
          d.addSample(30, 0, 0, t);
        }

        for (var i = 0; i < 3; i++) {
          shake();
        }
        expect(fired, 0);
        shake();
        expect(fired, 1);
        for (var i = 0; i < 4; i++) {
          shake();
        }
        expect(fired, 1, reason: 'cooldown');
      },
    );

    test('ignores normal movement and slow shakes', () {
      var fired = 0;
      final d = ShakeDetector(onShake: () => fired++);
      var t = DateTime(2026);
      for (var i = 0; i < 20; i++) {
        t = t.add(const Duration(milliseconds: 100));
        d.addSample(8, 3, 2, t); // walking
      }
      for (var i = 0; i < 6; i++) {
        t = t.add(const Duration(seconds: 1));
        d.addSample(30, 0, 0, t); // too far apart
      }
      expect(fired, 0);
    });
  });

  group('places', () {
    final here = GeoPoint(lat: 28.6139, lng: 77.2090, time: DateTime(2026));
    final sample = {
      'elements': [
        {
          'type': 'node',
          'id': 1,
          'lat': 28.6300,
          'lon': 77.2100,
          'tags': {
            'amenity': 'hospital',
            'name': 'City Hospital',
            'phone': '+91 11 2345 6789',
          },
        },
        {
          'type': 'way',
          'id': 2,
          'center': {'lat': 28.6150, 'lon': 77.2095},
          'tags': {
            'amenity': 'police',
            'name': 'Connaught Place PS',
            'addr:street': 'Parliament St',
            'addr:city': 'New Delhi',
          },
        },
        {
          'type': 'node',
          'id': 3,
          'lat': 28.6200,
          'lon': 77.2000,
          'tags': {'amenity': 'pharmacy'},
        },
        {
          'type': 'node',
          'id': 4,
          'lat': 28.6,
          'lon': 77.2,
          'tags': {'amenity': 'bench'},
        },
      ],
    };

    test('parses, classifies and sorts by distance', () {
      final places = PlacesService.parse(sample, here);
      expect(places.map((p) => p.category), [
        PlaceCategory.police,
        PlaceCategory.pharmacy,
        PlaceCategory.hospital,
      ]);
      expect(places.first.address, 'Parliament St, New Delhi');
      expect(places.last.phone, '+91 11 2345 6789');
      expect(places[1].name, '', reason: 'unnamed places are allowed');
    });

    test('builds an Overpass query for the requested categories', () {
      final q = PlacesService.buildQuery(here, 3000, {PlaceCategory.police});
      expect(
        q,
        contains('nwr["amenity"="police"](around:3000,28.61390,77.20900);'),
      );
      expect(q, isNot(contains('hospital')));
    });

    test('falls back to the second endpoint', () async {
      final hits = <String>[];
      final client = MockClient((req) async {
        hits.add(req.url.host);
        if (req.url.host == 'a.test') return http.Response('busy', 429);
        return http.Response(jsonEncode(sample), 200);
      });
      final service = PlacesService(
        client: client,
        endpoints: ['https://a.test/api', 'https://b.test/api'],
      );
      final places = await service.nearby(here);
      expect(hits, ['a.test', 'b.test']);
      expect(places, hasLength(3));
    });
  });

  group('tracking client', () {
    test('creates sessions and reports server errors', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        if (req.url.path == '/api/v1/sessions') {
          return http.Response(
            jsonEncode({
              'id': 'id1',
              'ownerKey': 'key',
              'viewUrl': 'https://x/t/v',
            }),
            201,
          );
        }
        return http.Response('{}', 409);
      });
      final t = TrackingClient('https://x/', client: client);
      expect(await t.ping(), isTrue);
      final link = await t.create(name: 'A', reason: 'sos', durationMinutes: 2);
      expect(link.viewUrl, 'https://x/t/v');
      expect(
        () => t.push(link, [GeoPoint(lat: 1, lng: 1, time: DateTime.now())]),
        throwsA(isA<TrackingException>()),
      );
    });
  });

  group('models', () {
    test('incident JSON round-trip', () {
      final i = Incident(
        id: 'x',
        type: IncidentType.journey,
        startedAt: DateTime.utc(2026, 9, 30, 10),
        destination: 'Office',
        deadline: DateTime.utc(2026, 9, 30, 11),
        recipientIds: const ['a'],
        tracking: const TrackingLink(
          sessionId: 's',
          ownerKey: 'k',
          viewUrl: 'u',
        ),
        path: [GeoPoint(lat: 1, lng: 2, time: DateTime.utc(2026), accuracy: 5)],
        deliveries: [
          Delivery(
            contactName: 'A',
            phone: '1',
            kind: DeliveryKind.journeyStart,
            status: DeliveryStatus.sent,
            at: DateTime.utc(2026),
          ),
        ],
      );
      final back = Incident.fromJson(
        jsonDecode(jsonEncode(i.toJson())) as Map<String, dynamic>,
      );
      expect(back.toJson(), i.toJson());
    });

    test('path is capped', () {
      final i = Incident(
        id: 'x',
        type: IncidentType.sos,
        startedAt: DateTime(2026),
      );
      for (var n = 0; n < Incident.maxPathPoints + 20; n++) {
        i.addPoint(GeoPoint(lat: 0, lng: n.toDouble(), time: DateTime(2026)));
      }
      expect(i.path, hasLength(Incident.maxPathPoints));
      expect(i.path.first.lng, 20);
    });
  });

  group('localization', () {
    test('Hindi has every English key', () {
      final missing = AppStrings.en.keys
          .where((k) => !AppStrings.hi.containsKey(k))
          .toList();
      expect(missing, isEmpty);
    });

    test('every key used in the code exists', () {
      final used = <String>{};
      final pattern = RegExp(r"\.t\('([A-Za-z0-9_]+)'");
      for (final f
          in Directory('lib')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        used.addAll(
          pattern.allMatches(f.readAsStringSync()).map((m) => m.group(1)!),
        );
      }
      final dynamicKeys = [
        for (final k in DeliveryKind.values) 'kind_${k.name}',
        for (final c in PlaceCategory.values) 'place_${c.name}',
        'notifTrackingSos',
        'notifTrackingJourney',
        'notifTrackingLive',
      ];
      final missing = [
        ...used,
        ...dynamicKeys,
      ].where((k) => !AppStrings.en.containsKey(k)).toList();
      expect(used.length, greaterThan(150));
      expect(missing, isEmpty);
    });

    test('placeholders are filled', () {
      expect(
        const AppStrings('en').t('sosSentSummary', {'sent': 2, 'total': 3}),
        'Alert sent to 2 of 3 contact(s)',
      );
      expect(
        const AppStrings('hi').t('callEmergency', {'number': '112'}),
        '112 पर कॉल करें',
      );
      expect(const AppStrings('xx').t('save'), 'Save');
    });
  });
}
