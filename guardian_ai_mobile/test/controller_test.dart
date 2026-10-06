import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai_mobile/models/contact.dart';
import 'package:guardian_ai_mobile/models/incident.dart';
import 'package:guardian_ai_mobile/models/profile.dart';
import 'package:guardian_ai_mobile/services/notification_service.dart';
import 'package:guardian_ai_mobile/services/permissions.dart';
import 'package:guardian_ai_mobile/services/storage.dart';
import 'package:guardian_ai_mobile/services/tracking_client.dart';
import 'package:guardian_ai_mobile/state/safety_controller.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

final start = DateTime(2026, 9, 30, 20, 0);

const asha = TrustedContact(
  id: 'a',
  name: 'Amma',
  phone: '+919876543210',
  isPrimary: true,
);
const ravi = TrustedContact(id: 'r', name: 'Ravi', phone: '+919812345678');
const quiet = TrustedContact(
  id: 'q',
  name: 'Quiet',
  phone: '+919800000000',
  alertOnSos: false,
);

class Harness {
  Harness(
    this.fa, {
    Map<String, dynamic>? stored,
    bool directSms = true,
    http.Client? server,
    AppSettings? settings,
  }) {
    storage = MemorySafetyStorage(
      stored ?? _defaultState(settings ?? const AppSettings()),
    );
    device = FakeDevice(directSms: directSms);
    c = SafetyController(
      storage: storage,
      device: device,
      location: location,
      permissions: permissions,
      notifications: notifications,
      now: () => start.add(fa.elapsed),
      trackingFactory: server == null
          ? null
          : (url) => TrackingClient(url, client: server),
    );
    c.load();
    fa.flushMicrotasks();
  }

  final FakeAsync fa;
  late final MemorySafetyStorage storage;
  late final FakeDevice device;
  final location = FakeLocation(
    fix: point(28.6139, 77.2090, at: start, accuracy: 12),
  );
  final permissions = FakePermissions();
  final notifications = FakeNotifications();
  late final SafetyController c;

  static Map<String, dynamic> _defaultState(AppSettings settings) => {
    'profile': const Profile(
      name: 'Priya Sharma',
      medicalInfo: 'Blood group B+',
    ).toJson(),
    'settings': settings.toJson(),
    'contacts': [asha.toJson(), ravi.toJson(), quiet.toJson()],
    'incidents': <Object>[],
  };

  void run(Duration d) {
    fa.elapse(d);
    fa.flushMicrotasks();
  }

  List<String> smsTo(String phone) =>
      device.sms.where((s) => s.phone == phone).map((s) => s.message).toList();
}

void main() {
  group('SOS', () {
    test(
      'alerts every SOS contact with location, battery and medical info',
      () {
        fakeAsync((fa) {
          final h = Harness(fa);
          h.c.triggerSos();
          fa.flushMicrotasks();

          expect(
            h.device.sms.map((s) => s.phone),
            unorderedEquals([asha.phone, ravi.phone]),
          );
          final msg = h.device.sms.first.message;
          expect(msg, contains('SOS from Priya Sharma'));
          expect(
            msg,
            contains('https://maps.google.com/?q=28.613900,77.209000'),
          );
          expect(msg, contains('Battery 76%'));
          expect(msg, contains('Medical: Blood group B+'));

          final sos = h.c.activeSos!;
          expect(
            sos.deliveries.where(
              (d) =>
                  d.kind == DeliveryKind.sosAlert &&
                  d.status == DeliveryStatus.sent,
            ),
            hasLength(2),
          );
          expect(h.c.sendingSos, isFalse);
          expect(
            h.location.streaming,
            isTrue,
            reason: 'background tracking starts',
          );
          expect(h.location.lastStreamBackground, isTrue);
          expect(h.device.screenOn, isTrue);
          expect(h.notifications.shown.single.$1, NotificationIds.sos);
          h.c.dispose();
        });
      },
    );

    test('records carrier failures per contact', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.device.failingNumbers.add(ravi.phone);
        h.c.triggerSos();
        fa.flushMicrotasks();
        final byName = {
          for (final d in h.c.activeSos!.deliveries) d.contactName: d,
        };
        expect(byName['Amma']!.status, DeliveryStatus.sent);
        expect(byName['Ravi']!.status, DeliveryStatus.failed);
        expect(byName['Ravi']!.error, 'no_service');
        h.c.dispose();
      });
    });

    test('falls back to the SMS app when SMS permission is denied', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.permissions.states[AppPermission.sms] =
            PermissionState.permanentlyDenied;
        h.c.triggerSos();
        fa.flushMicrotasks();
        expect(h.device.sms, isEmpty);
        expect(
          h.device.composer.single.$1,
          unorderedEquals([asha.phone, ravi.phone]),
        );
        expect(
          h.c.activeSos!.deliveries.every(
            (d) => d.status == DeliveryStatus.composer,
          ),
          isTrue,
        );
        h.c.dispose();
      });
    });

    test(
      'blocked SMS opens the SMS app at once and skips background updates',
      () {
        fakeAsync((fa) {
          final h = Harness(fa);
          h.permissions.states[AppPermission.sms] = PermissionState.restricted;
          h.c.refreshSmsAccess();
          fa.flushMicrotasks();
          expect(h.c.smsPermissionMissing, isTrue);
          expect(h.c.autoSms, isFalse);

          h.c.triggerSos();
          fa.flushMicrotasks();
          // No permission dialog can be shown, so none is requested.
          expect(h.permissions.requested, isEmpty);
          expect(h.device.sms, isEmpty);
          expect(h.device.composer, hasLength(1));

          h.location.emit(
            point(19.076, 72.8777, at: start.add(const Duration(minutes: 1))),
          );
          fa.elapse(const Duration(minutes: 20));
          expect(h.device.composer, hasLength(1));
          expect(h.c.activeSos!.deliveries.map((d) => d.status).toSet(), {
            DeliveryStatus.composer,
          });
          h.c.dispose();
        });
      },
    );

    test('asks for SMS only while Android can still show the dialog', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.permissions.states[AppPermission.sms] = PermissionState.denied;
        h.c.refreshSmsAccess();
        fa.flushMicrotasks();
        // Never asked yet: SOS will ask, so alerts still count as automatic.
        expect(h.c.autoSms, isTrue);
        expect(h.c.smsPermissionMissing, isTrue);

        h.c.requestSmsAccess();
        fa.flushMicrotasks();
        expect(h.permissions.requested, [AppPermission.sms]);

        h.permissions.states[AppPermission.sms] =
            PermissionState.permanentlyDenied;
        h.c.requestSmsAccess();
        fa.flushMicrotasks();
        expect(h.permissions.requested, hasLength(1));
        expect(h.c.autoSms, isFalse);

        // Allowed in system settings; picked up when the app resumes.
        h.permissions.states[AppPermission.sms] = PermissionState.granted;
        h.c.refreshSmsAccess();
        fa.flushMicrotasks();
        expect(h.c.smsPermissionMissing, isFalse);
        expect(h.c.autoSms, isTrue);
        h.c.dispose();
      });
    });

    test('a tap on "How to allow" still tries the restricted permission', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.permissions.states[AppPermission.sms] = PermissionState.restricted;
        h.c.requestSmsAccess();
        fa.flushMicrotasks();
        expect(h.permissions.requested, isEmpty);

        // Restricted settings were allowed meanwhile: the normal dialog shows.
        h.permissions.allowOnRequest.add(AppPermission.sms);
        h.c.requestSmsAccess(userInitiated: true);
        fa.flushMicrotasks();
        expect(h.permissions.requested, [AppPermission.sms]);
        expect(h.c.smsAccess, PermissionState.granted);
        expect(h.c.smsPermissionMissing, isFalse);
        h.c.dispose();
      });
    });

    test('the lite edition never reports SMS as missing', () {
      fakeAsync((fa) {
        final h = Harness(fa, directSms: false);
        h.permissions.states[AppPermission.sms] = PermissionState.restricted;
        h.c.refreshSmsAccess();
        fa.flushMicrotasks();
        expect(h.c.smsPermissionMissing, isFalse);
        expect(h.c.autoSms, isFalse);
        h.c.dispose();
      });
    });

    test(
      'sends the location when GPS is unavailable at first, as soon as a fix arrives',
      () {
        fakeAsync((fa) {
          final h = Harness(fa);
          h.location.fix = null;
          h.c.triggerSos();
          fa.flushMicrotasks();
          expect(
            h.smsTo(asha.phone).single,
            contains('location is not available yet'),
          );

          h.location.emit(
            point(19.076, 72.8777, at: start.add(const Duration(seconds: 20))),
          );
          fa.flushMicrotasks();
          expect(h.smsTo(asha.phone), hasLength(2));
          expect(
            h.smsTo(asha.phone).last,
            contains('SOS update from Priya Sharma'),
          );
          expect(h.smsTo(asha.phone).last, contains('19.076000,72.877700'));
          h.c.dispose();
        });
      },
    );

    test('sends periodic location updates only after the user moves', () {
      fakeAsync((fa) {
        final h = Harness(
          fa,
          settings: const AppSettings(updateIntervalMinutes: 2),
        );
        h.c.triggerSos();
        fa.flushMicrotasks();
        expect(h.smsTo(asha.phone), hasLength(1));

        h.run(const Duration(minutes: 2, seconds: 10));
        expect(
          h.smsTo(asha.phone),
          hasLength(1),
          reason: 'no movement, no update',
        );

        h.location.emit(
          point(28.6200, 77.2150, at: start.add(const Duration(minutes: 3))),
        );
        h.run(const Duration(minutes: 2, seconds: 10));
        expect(h.smsTo(asha.phone), hasLength(2));
        expect(h.smsTo(asha.phone).last, contains('28.620000,77.215000'));
        expect(h.c.activeSos!.path.length, greaterThanOrEqualTo(2));
        h.c.dispose();
      });
    });

    test('stopping tells contacts the user is safe and stops tracking', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.c.triggerSos();
        fa.flushMicrotasks();
        h.c.setSiren(true);
        fa.flushMicrotasks();

        h.c.stopSos();
        fa.flushMicrotasks();
        expect(h.smsTo(ravi.phone).last, contains('is safe now'));
        expect(h.c.activeSos, isNull);
        expect(h.c.incidents.first.status, IncidentStatus.resolved);
        expect(h.location.streaming, isFalse);
        expect(h.device.sirenOn, isFalse);
        expect(h.device.screenOn, isFalse);
        h.c.dispose();
      });
    });

    test('auto-calls the primary contact when enabled', () {
      fakeAsync((fa) {
        final h = Harness(
          fa,
          settings: const AppSettings(autoCall: AutoCall.primaryContact),
        );
        h.c.triggerSos();
        fa.flushMicrotasks();
        expect(h.device.calls.single, (asha.phone, true));
        h.c.dispose();
      });
    });

    test('state survives a restart and the SOS resumes tracking', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.c.triggerSos();
        fa.flushMicrotasks();
        h.c.dispose();

        final again = Harness(fa, stored: h.storage.data);
        expect(again.c.activeSos, isNotNull);
        expect(again.c.activeSos!.deliveries, hasLength(2));
        expect(again.location.streaming, isTrue);
        again.c.dispose();
      });
    });
  });

  test('an SOS whose alert never went out is sent on the next launch', () {
    fakeAsync((fa) {
      final unsent = Incident(
        id: 's1',
        type: IncidentType.sos,
        startedAt: start.subtract(const Duration(minutes: 1)),
        trigger: SosTrigger.button,
        recipientIds: [asha.id, ravi.id],
      );
      final state = Harness._defaultState(const AppSettings())
        ..['incidents'] = [unsent.toJson()];
      final h = Harness(
        fa,
        stored: jsonDecode(jsonEncode(state)) as Map<String, dynamic>,
      );
      expect(
        h.device.sms.map((s) => s.phone),
        unorderedEquals([asha.phone, ravi.phone]),
      );
      expect(h.smsTo(asha.phone).single, contains('SOS from Priya Sharma'));
      expect(h.c.activeSos!.deliveries, hasLength(2));
      h.c.dispose();
    });
  });

  group('journey check-in', () {
    test(
      'notifies at start, reminds before the deadline and escalates when missed',
      () {
        fakeAsync((fa) {
          final h = Harness(fa);
          h.c.startJourney(
            duration: const Duration(minutes: 15),
            destination: 'Home',
            contactIds: [asha.id],
          );
          fa.flushMicrotasks();
          expect(
            h.smsTo(asha.phone).single,
            contains('started a journey to Home'),
          );
          expect(h.smsTo(ravi.phone), isEmpty);
          expect(h.location.streaming, isTrue);

          h.run(const Duration(minutes: 13, seconds: 5));
          expect(
            h.notifications.shown.map((n) => n.$1),
            contains(NotificationIds.journeyReminder),
          );
          expect(h.c.activeSos, isNull);

          h.run(const Duration(minutes: 2));
          final sos = h.c.activeSos!;
          expect(sos.trigger, SosTrigger.missedCheckIn);
          expect(
            h.c.incidents
                .firstWhere((i) => i.type == IncidentType.journey)
                .status,
            IncidentStatus.escalated,
          );
          expect(
            h.smsTo(asha.phone).last,
            contains(
              'ALERT: Priya Sharma did not check in from their journey to Home',
            ),
          );
          expect(h.smsTo(asha.phone).last, contains('maps.google.com'));
          expect(
            h.smsTo(ravi.phone),
            isEmpty,
            reason: 'only the journey contacts',
          );
          expect(
            h.notifications.shown.map((n) => n.$1),
            contains(NotificationIds.journeyEscalated),
          );
          h.c.dispose();
        });
      },
    );

    test('arriving on time sends an arrival message and nothing else', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.c.startJourney(
          duration: const Duration(minutes: 30),
          contactIds: [asha.id, ravi.id],
        );
        fa.flushMicrotasks();
        h.run(const Duration(minutes: 10));
        h.c.finishJourney(arrived: true);
        fa.flushMicrotasks();
        h.run(const Duration(minutes: 30));

        expect(h.smsTo(asha.phone).last, contains('has arrived safely'));
        expect(h.c.activeSos, isNull);
        expect(h.c.incidents.first.status, IncidentStatus.resolved);
        expect(h.location.streaming, isFalse);
        h.c.dispose();
      });
    });

    test('cancelling sends no message; extending moves the deadline', () {
      fakeAsync((fa) {
        final h = Harness(
          fa,
          settings: const AppSettings(notifyJourneyStart: false),
        );
        h.c.startJourney(
          duration: const Duration(minutes: 15),
          contactIds: [asha.id],
        );
        fa.flushMicrotasks();
        final deadline = h.c.activeJourney!.deadline!;
        h.c.extendJourney(const Duration(minutes: 15));
        fa.flushMicrotasks();
        expect(
          h.c.activeJourney!.deadline,
          deadline.add(const Duration(minutes: 15)),
        );

        h.run(const Duration(minutes: 20));
        expect(h.c.activeSos, isNull, reason: 'extended deadline not reached');
        h.c.finishJourney(arrived: false);
        fa.flushMicrotasks();
        expect(h.device.sms, isEmpty);
        expect(h.c.incidents.first.status, IncidentStatus.cancelled);
        h.c.dispose();
      });
    });

    test(
      'a deadline that passed while the app was closed escalates on launch',
      () {
        fakeAsync((fa) {
          final journey = Incident(
            id: 'j1',
            type: IncidentType.journey,
            startedAt: start.subtract(const Duration(hours: 1)),
            deadline: start.subtract(const Duration(minutes: 5)),
            recipientIds: [asha.id],
          );
          final state = Harness._defaultState(const AppSettings())
            ..['incidents'] = [journey.toJson()];
          final h = Harness(
            fa,
            stored: jsonDecode(jsonEncode(state)) as Map<String, dynamic>,
          );
          expect(h.c.activeSos?.trigger, SosTrigger.missedCheckIn);
          expect(h.smsTo(asha.phone).single, contains('did not check in'));
          h.c.dispose();
        });
      },
    );
  });

  group('live location sharing', () {
    test('without a server: SMS now, then updates, then a stop message', () {
      fakeAsync((fa) {
        final h = Harness(
          fa,
          settings: const AppSettings(updateIntervalMinutes: 5),
        );
        h.c.startLiveShare(
          duration: const Duration(minutes: 15),
          contactIds: [ravi.id],
        );
        fa.flushMicrotasks();
        expect(
          h.smsTo(ravi.phone).single,
          contains('sharing their location with you'),
        );

        h.location.emit(
          point(28.64, 77.23, at: start.add(const Duration(minutes: 4))),
        );
        h.run(const Duration(minutes: 5, seconds: 5));
        expect(
          h.smsTo(ravi.phone).last,
          contains('Location update from Priya Sharma'),
        );

        h.run(const Duration(minutes: 11));
        expect(h.c.activeLiveShare, isNull, reason: 'stops automatically');
        expect(h.smsTo(ravi.phone).last, contains('stopped sharing'));
        expect(h.location.streaming, isFalse);
        h.c.dispose();
      });
    });

    test('with a server: sends a live-map link and streams points to it', () {
      fakeAsync((fa) {
        final requests = <http.Request>[];
        final server = MockClient((req) async {
          requests.add(req);
          if (req.method == 'POST' && req.url.path == '/api/v1/sessions') {
            return http.Response(
              jsonEncode({
                'id': 's1',
                'ownerKey': 'k' * 43,
                'viewToken': 'v' * 24,
                'viewUrl': 'https://track.test/t/abc',
              }),
              201,
            );
          }
          if (req.url.path.endsWith('/points')) {
            return http.Response('{"accepted":1}', 202);
          }
          return http.Response(jsonEncode({'status': 'ended'}), 200);
        });
        final h = Harness(
          fa,
          server: server,
          settings: const AppSettings(trackingServerUrl: 'https://track.test'),
        );
        h.c.startLiveShare(
          duration: const Duration(minutes: 30),
          contactIds: [asha.id],
        );
        fa.flushMicrotasks();

        expect(
          h.smsTo(asha.phone).single,
          contains('https://track.test/t/abc'),
        );
        final created = jsonDecode(requests.first.body) as Map<String, dynamic>;
        expect(created, containsPair('reason', 'live'));
        expect(
          requests.where((r) => r.url.path == '/api/v1/sessions/s1/points'),
          isNotEmpty,
        );
        expect(requests.last.headers['authorization'], 'Bearer ${'k' * 43}');

        h.location.emit(
          point(28.70, 77.10, at: start.add(const Duration(seconds: 40))),
        );
        final before = requests.length;
        h.run(const Duration(seconds: 6));
        expect(
          requests.length,
          greaterThan(before),
          reason: 'new point pushed on the next tick',
        );

        h.c.stopLiveShare();
        fa.flushMicrotasks();
        final end = requests.lastWhere((r) => r.method == 'PATCH');
        expect(jsonDecode(end.body), {'status': 'ended'});
        h.c.dispose();
      });
    });
  });

  test(
    'a slow live-map server never blocks or breaks the SMS (overlapping uploads)',
    () {
      fakeAsync((fa) {
        final pushes = <int>[];
        final server = MockClient((req) async {
          if (req.url.path == '/api/v1/sessions') {
            return http.Response(
              jsonEncode({
                'id': 's1',
                'ownerKey': 'k',
                'viewUrl': 'https://track.test/t/abc',
              }),
              201,
            );
          }
          // Each upload takes longer than the 5 s tick, so flushes overlap.
          await Future<void>.delayed(const Duration(seconds: 7));
          pushes.add((jsonDecode(req.body)['points'] as List).length);
          return http.Response('{"accepted":1}', 202);
        });
        final h = Harness(
          fa,
          server: server,
          settings: const AppSettings(trackingServerUrl: 'https://track.test'),
        );
        h.c.startLiveShare(
          duration: const Duration(minutes: 30),
          contactIds: [asha.id],
        );
        for (var i = 1; i <= 6; i++) {
          h.location.emit(
            point(
              28.6 + i / 100,
              77.2,
              at: start.add(Duration(seconds: 40 * i)),
            ),
          );
          h.run(const Duration(seconds: 4));
        }
        h.run(const Duration(seconds: 30));

        expect(
          h.smsTo(asha.phone).single,
          contains('https://track.test/t/abc'),
        );
        final path = h.c.activeLiveShare!.path;
        expect(path.length, greaterThanOrEqualTo(6));
        expect(
          pushes.fold<int>(0, (a, b) => a + b),
          path.length,
          reason: 'every recorded point is uploaded exactly once',
        );
        h.c.dispose();
      });
    },
  );

  group('lite edition (no background SMS)', () {
    Harness lite(FakeAsync fa, {AppSettings? settings}) {
      final h = Harness(fa, settings: settings);
      h.device
        ..directSms = false
        ..directCall = false;
      h.c.load(); // Re-read capabilities.
      fa.flushMicrotasks();
      return h;
    }

    test(
      'SOS opens the SMS app pre-filled and sends no background updates',
      () {
        fakeAsync((fa) {
          final h = lite(
            fa,
            settings: const AppSettings(
              updateIntervalMinutes: 2,
              autoCall: AutoCall.primaryContact,
            ),
          );
          h.c.triggerSos();
          fa.flushMicrotasks();

          expect(h.device.sms, isEmpty);
          expect(
            h.device.composer.single.$1,
            unorderedEquals([asha.phone, ravi.phone]),
          );
          expect(
            h.device.composer.single.$2,
            contains('SOS from Priya Sharma'),
          );
          expect(h.device.calls.single, (
            asha.phone,
            false,
          ), reason: 'dialer, no CALL_PHONE');
          expect(h.permissions.requested, isNot(contains(AppPermission.phone)));
          expect(
            h.notifications.shown.single.$2,
            'SOS ready - press Send',
            reason: 'never claims an SMS the user has not sent',
          );

          h.location.emit(
            point(28.70, 77.30, at: start.add(const Duration(minutes: 1))),
          );
          h.run(const Duration(minutes: 5));
          expect(h.device.composer, hasLength(1), reason: 'no update spam');
          expect(
            h.c.activeSos!.deliveries.where(
              (d) => d.status == DeliveryStatus.failed,
            ),
            isEmpty,
          );

          expect(
            h.c.sosAlertNeedsResend,
            isTrue,
            reason: 'composer is not a confirmed send',
          );
          h.c.resendSosAlert();
          fa.flushMicrotasks();
          expect(h.device.composer, hasLength(2));
          expect(
            h.device.composer.last.$2,
            contains('28.700000,77.300000'),
            reason: 'latest location',
          );
          h.c.dispose();
        });
      },
    );

    test('a missed check-in opens the SMS app and tells the user to act', () {
      fakeAsync((fa) {
        final h = lite(
          fa,
          settings: const AppSettings(notifyJourneyStart: false),
        );
        h.c.startJourney(
          duration: const Duration(minutes: 15),
          contactIds: [asha.id],
        );
        fa.flushMicrotasks();
        h.run(const Duration(minutes: 16));

        expect(h.device.composer.single.$2, contains('did not check in'));
        final notice = h.notifications.shown.lastWhere(
          (n) => n.$1 == NotificationIds.journeyEscalated,
        );
        expect(notice.$2, 'Check-in missed');
        h.c.dispose();
      });
    });
  });

  test(
    'full edition: "send again" only re-sends to contacts whose SMS failed',
    () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.device.failingNumbers.add(ravi.phone);
        h.c.triggerSos();
        fa.flushMicrotasks();
        expect(h.c.sosAlertNeedsResend, isTrue);

        h.device.failingNumbers.clear(); // Signal is back.
        h.c.resendSosAlert();
        fa.flushMicrotasks();
        expect(h.smsTo(ravi.phone), hasLength(2));
        expect(h.smsTo(asha.phone), hasLength(1));
        expect(h.c.sosAlertNeedsResend, isFalse);
        h.c.dispose();
      });
    },
  );

  group('contacts and tools', () {
    test('only one primary contact; removing it promotes another', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.c.saveContact(ravi.copyWith(isPrimary: true));
        fa.flushMicrotasks();
        expect(h.c.contacts.where((c) => c.isPrimary).map((c) => c.id), ['r']);
        h.c.removeContact('r');
        fa.flushMicrotasks();
        expect(h.c.contacts.where((c) => c.isPrimary), hasLength(1));
        h.c.dispose();
      });
    });

    test('test message introduces the app to a new contact', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.c.sendTestMessage(ravi);
        fa.flushMicrotasks();
        expect(
          h.smsTo(ravi.phone).single,
          contains('Hi Ravi, Priya Sharma added you as a trusted contact'),
        );
        h.c.dispose();
      });
    });

    test('strobe toggles the torch until stopped', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.c.setStrobe(true);
        h.run(const Duration(seconds: 1));
        expect(h.device.torch.length, greaterThanOrEqualTo(3));
        h.c.setStrobe(false);
        fa.flushMicrotasks();
        expect(h.device.torch.last, isFalse);
        final count = h.device.torch.length;
        h.run(const Duration(seconds: 1));
        expect(h.device.torch.length, count);
        h.c.dispose();
      });
    });

    test('Hindi profile sends Hindi alerts', () {
      fakeAsync((fa) {
        final state = Harness._defaultState(
          const AppSettings(),
        )..['profile'] = const Profile(name: 'प्रिया', language: 'hi').toJson();
        final h = Harness(fa, stored: state);
        h.c.triggerSos();
        fa.flushMicrotasks();
        expect(
          h.smsTo(asha.phone).single,
          contains('प्रिया को तुरंत मदद चाहिए'),
        );
        h.c.dispose();
      });
    });

    test('delete all data wipes storage and stops sessions', () {
      fakeAsync((fa) {
        final h = Harness(fa);
        h.c.startLiveShare(
          duration: const Duration(minutes: 15),
          contactIds: [asha.id],
        );
        fa.flushMicrotasks();
        h.c.deleteAllData();
        fa.flushMicrotasks();
        expect(h.storage.data, isNull);
        expect(h.c.profile, isNull);
        expect(h.location.streaming, isFalse);
        h.c.dispose();
      });
    });
  });
}
