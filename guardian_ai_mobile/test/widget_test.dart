import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai_mobile/models/contact.dart';
import 'package:guardian_ai_mobile/models/profile.dart';
import 'package:guardian_ai_mobile/services/permissions.dart';
import 'package:guardian_ai_mobile/services/places_service.dart';
import 'package:guardian_ai_mobile/services/storage.dart';
import 'package:guardian_ai_mobile/state/safety_controller.dart';
import 'package:guardian_ai_mobile/ui/app.dart';
import 'package:guardian_ai_mobile/ui/widgets/safety_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

class App {
  App({Map<String, dynamic>? stored}) {
    controller = SafetyController(
      storage: MemorySafetyStorage(stored),
      device: device,
      location: location,
      permissions: permissions,
      notifications: FakeNotifications(),
    );
  }

  final device = FakeDevice();
  final location = FakeLocation(fix: point(28.6139, 77.2090));
  final permissions = FakePermissions();
  late final SafetyController controller;

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      GuardianApp(
        controller: controller,
        places: PlacesService(
          client: MockClient(
            (_) async => http.Response('{"elements":[]}', 200),
          ),
        ),
      ),
    );
    await controller.load();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> dispose(WidgetTester tester) async {
    // Leave the widget tree before tearing down timers.
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  }
}

Map<String, dynamic> onboarded({
  String language = 'en',
  List<TrustedContact>? contacts,
}) => {
  'profile': Profile(name: 'Priya Sharma', language: language).toJson(),
  'settings': const AppSettings(countdownSeconds: 3).toJson(),
  'contacts':
      (contacts ??
              const [
                TrustedContact(
                  id: 'a',
                  name: 'Amma',
                  phone: '+919876543210',
                  isPrimary: true,
                ),
                TrustedContact(id: 'r', name: 'Ravi', phone: '+919812345678'),
              ])
          .map((c) => c.toJson())
          .toList(),
  'incidents': <Object>[],
};

Future<void> settle(WidgetTester tester, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => SafetyMap.showTiles = false);

  testWidgets('onboarding: profile, first contact, permissions, then home', (
    tester,
  ) async {
    final app = App();
    await app.pump(tester);

    expect(find.text('Help is one tap away'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await settle(tester);

    await tester.enterText(
      find.byKey(const ValueKey('onboarding_name')),
      'Priya Sharma',
    );
    await tester.pump();
    expect(
      find.text('112'),
      findsOneWidget,
      reason: 'emergency number defaults to 112',
    );
    await tester.tap(find.text('Next'));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('add_contact_manual')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('contact_name')), 'Amma');
    await tester.enterText(
      find.byKey(const ValueKey('contact_phone')),
      '98765 43210',
    );
    await tester.pump();
    final save = find.byKey(const ValueKey('contact_save'));
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'consent required',
    );
    await tester.tap(find.byKey(const ValueKey('contact_informed')));
    await tester.pump();
    await tester.tap(save);
    await settle(tester);
    expect(app.controller.contacts.single.phone, '9876543210');
    expect(app.controller.contacts.single.isPrimary, isTrue);

    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Send SMS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding_finish')));
    await settle(tester);

    expect(app.controller.profile!.name, 'Priya Sharma');
    expect(find.textContaining('Priya'), findsOneWidget);
    expect(find.byKey(const ValueKey('sos_button')), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('SOS countdown can be cancelled without sending anything', (
    tester,
  ) async {
    final app = App(stored: onboarded());
    await app.pump(tester);

    await tester.tap(find.byKey(const ValueKey('sos_button')));
    await settle(tester, 4);
    expect(find.byKey(const ValueKey('sos_countdown_value')), findsOneWidget);
    expect(
      find.text('2 trusted contact(s) will get an SMS with your location.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('sos_cancel')));
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(app.device.sms, isEmpty);
    expect(app.controller.activeSos, isNull);
    await app.dispose(tester);
  });

  testWidgets('SOS countdown sends alerts and the user can stop it', (
    tester,
  ) async {
    final app = App(stored: onboarded());
    await app.pump(tester);

    await tester.tap(find.byKey(const ValueKey('sos_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(app.device.sms, hasLength(2));
    expect(find.text('Alert sent to 2 of 2 contact(s)'), findsOneWidget);
    expect(find.text('SOS active'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('sos_stop')),
      200,
    );
    await tester.tap(find.byKey(const ValueKey('sos_stop')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sos_stop_confirm')));
    await settle(tester);

    expect(app.controller.activeSos, isNull);
    expect(app.device.sms.last.message, contains('is safe now'));
    await app.dispose(tester);
  });

  testWidgets('"Send now" skips the countdown', (tester) async {
    final app = App(stored: onboarded());
    await app.pump(tester);
    await tester.tap(find.byKey(const ValueKey('sos_button')));
    await settle(tester, 3);
    await tester.tap(find.byKey(const ValueKey('sos_send_now')));
    await settle(tester);
    expect(app.device.sms, hasLength(2));
    await app.dispose(tester);
  });

  testWidgets('journey check-in shows a live countdown and can be completed', (
    tester,
  ) async {
    final app = App(stored: onboarded());
    await app.pump(tester);

    await tester.tap(find.text('Journey check-in'));
    await settle(tester);
    await tester.tap(find.text('15 min'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('journey_start')));
    await settle(tester);

    expect(find.text('Journey in progress'), findsOneWidget);
    final countdown = find.byKey(const ValueKey('journey_countdown'));
    final before = tester.widget<Text>(countdown).data;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<Text>(countdown).data,
      isNot(before),
      reason: 'the countdown ticks',
    );
    expect(
      app.device.sms.map((s) => s.phone),
      containsAll(['+919876543210', '+919812345678']),
    );

    await tester.tap(find.text('I\'ve arrived'));
    await settle(tester);
    expect(app.controller.activeJourney, isNull);
    expect(app.device.sms.last.message, contains('arrived safely'));
    await app.dispose(tester);
  });

  testWidgets('contacts tab lists contacts and sends a test SMS', (
    tester,
  ) async {
    final app = App(stored: onboarded());
    await app.pump(tester);
    await tester.tap(find.text('Contacts'));
    await settle(tester);

    expect(find.text('Amma'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);

    await tester.tap(find.byTooltip('More').first);
    await settle(tester);
    await tester.tap(find.text('Send test SMS'));
    await settle(tester);
    expect(app.device.sms.single.message, contains('Hi Amma'));
    expect(find.text('Test SMS sent to Amma'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('blocked SMS: banner, how-to sheet, and recovery on resume', (
    tester,
  ) async {
    final app = App(stored: onboarded());
    app.permissions.states[AppPermission.sms] = PermissionState.restricted;
    await app.pump(tester);

    expect(find.text('Automatic SMS is off'), findsOneWidget);
    expect(find.textContaining('your SMS app opens'), findsWidgets);
    await tester.tap(find.text('How to allow'));
    await settle(tester);
    expect(find.text('Allow SMS for Guardian'), findsOneWidget);
    expect(find.byKey(const ValueKey('sms_open_settings')), findsOneWidget);

    // The user allows it in system settings and comes back to the app.
    app.permissions.states[AppPermission.sms] = PermissionState.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(
      find.text('SMS allowed. Alerts will now be sent automatically.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text('Automatic SMS is off'), findsNothing);
    expect(find.textContaining('Alerts 2 contact(s)'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('home works in Hindi', (tester) async {
    final app = App(stored: onboarded(language: 'hi'));
    await app.pump(tester);
    expect(find.text('मदद के लिए टैप करें'), findsOneWidget);
    expect(find.text('त्वरित विकल्प'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('without contacts the home screen explains what to do', (
    tester,
  ) async {
    final app = App(stored: onboarded(contacts: const []));
    await app.pump(tester);
    expect(find.textContaining('No trusted contacts yet'), findsOneWidget);
    await app.dispose(tester);
  });

  testWidgets('helplines are one tap away', (tester) async {
    final app = App(stored: onboarded());
    await app.pump(tester);
    await tester.ensureVisible(find.text('See all'));
    await tester.pump();
    await tester.tap(find.text('See all'));
    await settle(tester);
    expect(find.text('Emergency helplines'), findsOneWidget);
    await tester.tap(find.text('1091'));
    await settle(tester);
    expect(app.device.calls.single, ('1091', false));
    await app.dispose(tester);
  });
}
