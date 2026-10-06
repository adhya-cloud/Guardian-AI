import 'dart:async';

import 'package:guardian_ai_mobile/models/geo_point.dart';
import 'package:guardian_ai_mobile/services/device_bridge.dart';
import 'package:guardian_ai_mobile/services/location_service.dart';
import 'package:guardian_ai_mobile/services/notification_service.dart';
import 'package:guardian_ai_mobile/services/permissions.dart';

class SentSms {
  SentSms(this.phone, this.message);
  final String phone;
  final String message;
  @override
  String toString() => '$phone: $message';
}

class FakeDevice implements DeviceBridge {
  FakeDevice({this.directSms = true});

  bool directSms;
  bool directCall = true;
  final sms = <SentSms>[];
  final composer = <(List<String>, String)>[];
  final calls = <(String, bool)>[];
  final failingNumbers = <String>{};
  final torch = <bool>[];
  int? battery = 76;
  bool sirenOn = false;
  bool ringing = false;
  bool screenOn = false;
  (String, String)? contactToPick;

  @override
  Future<DeviceCapabilities> capabilities() async => DeviceCapabilities(
    directSms: directSms,
    directCall: directCall,
    torch: true,
    siren: true,
    contactPicker: true,
  );

  @override
  Future<SmsResult> sendSms(String phone, String message) async {
    sms.add(SentSms(phone, message));
    return failingNumbers.contains(phone)
        ? const SmsResult.failed('no_service')
        : const SmsResult.sent();
  }

  @override
  Future<bool> openSmsComposer(List<String> phones, String message) async {
    composer.add((phones, message));
    return true;
  }

  @override
  Future<PickedContact?> pickContact() async => contactToPick == null
      ? null
      : PickedContact(contactToPick!.$1, contactToPick!.$2);

  @override
  Future<bool> call(String number, {bool direct = false}) async {
    calls.add((number, direct));
    return true;
  }

  @override
  Future<int?> batteryLevel() async => battery;

  @override
  Future<bool> setTorch(bool on) async {
    torch.add(on);
    return true;
  }

  @override
  Future<void> startSiren() async => sirenOn = true;

  @override
  Future<void> stopSiren() async => sirenOn = false;

  @override
  Future<void> startRingtone() async => ringing = true;

  @override
  Future<void> stopRingtone() async => ringing = false;

  @override
  Future<void> keepScreenOn(bool on) async => screenOn = on;
}

class FakeLocation implements LocationService {
  FakeLocation({this.fix});

  GeoPoint? fix;
  LocationAccess accessResult = LocationAccess.granted;
  StreamController<GeoPoint>? stream;
  bool lastStreamBackground = false;
  String lastNotificationText = '';
  int streamsOpened = 0;

  bool get streaming =>
      stream != null && !stream!.isClosed && stream!.hasListener;

  void emit(GeoPoint p) {
    fix = p;
    stream?.add(p);
  }

  @override
  Future<LocationAccess> access({bool request = true}) async => accessResult;

  @override
  Future<GeoPoint?> currentPosition({
    Duration timeLimit = const Duration(seconds: 15),
  }) async => fix;

  @override
  Future<GeoPoint?> lastKnown() async => fix;

  @override
  Stream<GeoPoint> positionStream({
    bool background = false,
    String notificationTitle = '',
    String notificationText = '',
  }) {
    streamsOpened++;
    lastStreamBackground = background;
    lastNotificationText = notificationText;
    stream = StreamController<GeoPoint>.broadcast();
    return stream!.stream;
  }

  @override
  Future<bool> openLocationSettings() async => true;
}

class FakePermissions implements PermissionService {
  final states = <AppPermission, PermissionState>{
    for (final p in AppPermission.values) p: PermissionState.granted,
  };
  final requested = <AppPermission>[];

  /// Permissions the user allows when the dialog is shown.
  final allowOnRequest = <AppPermission>{};

  @override
  Future<PermissionState> status(AppPermission permission) async =>
      states[permission]!;

  @override
  Future<PermissionState> request(AppPermission permission) async {
    requested.add(permission);
    if (allowOnRequest.contains(permission)) {
      states[permission] = PermissionState.granted;
    }
    return states[permission]!;
  }

  @override
  Future<bool> openSettings() async => true;
}

class FakeNotifications implements NotificationService {
  final shown = <(int, String, String)>[];
  final cancelled = <int>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> show(
    int id,
    String title,
    String body, {
    bool alarm = false,
  }) async => shown.add((id, title, body));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

GeoPoint point(double lat, double lng, {DateTime? at, double accuracy = 8}) =>
    GeoPoint(
      lat: lat,
      lng: lng,
      time: at ?? DateTime.now(),
      accuracy: accuracy,
    );
