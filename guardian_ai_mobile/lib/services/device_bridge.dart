import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsResult {
  const SmsResult.sent() : sent = true, error = null;
  const SmsResult.failed(this.error) : sent = false;

  final bool sent;
  final String? error;
}

class PickedContact {
  const PickedContact(this.name, this.phone);
  final String name;
  final String phone;
}

class DeviceCapabilities {
  const DeviceCapabilities({
    this.directSms = false,
    this.directCall = false,
    this.torch = false,
    this.siren = false,
    this.contactPicker = false,
  });

  /// Can send SMS in the background with delivery confirmation (Android).
  final bool directSms;

  /// Can place calls directly (CALL_PHONE declared; full edition only).
  final bool directCall;
  final bool torch;
  final bool siren;
  final bool contactPicker;
}

/// Phone features: SMS, calls, contact picker, torch, siren, ringtone.
abstract interface class DeviceBridge {
  Future<DeviceCapabilities> capabilities();

  /// Sends one SMS directly; resolves once the OS confirms it was sent.
  Future<SmsResult> sendSms(String phone, String message);

  /// Opens the SMS app pre-filled (fallback when direct sending is unavailable).
  Future<bool> openSmsComposer(List<String> phones, String message);

  Future<PickedContact?> pickContact();

  /// [direct] places the call immediately when CALL_PHONE is granted,
  /// otherwise the dialer opens with the number filled in.
  Future<bool> call(String number, {bool direct = false});

  Future<int?> batteryLevel();
  Future<bool> setTorch(bool on);
  Future<void> startSiren();
  Future<void> stopSiren();
  Future<void> startRingtone();
  Future<void> stopRingtone();
  Future<void> keepScreenOn(bool on);
}

class PlatformDeviceBridge implements DeviceBridge {
  PlatformDeviceBridge();

  static const _channel = MethodChannel('guardian/native');

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<DeviceCapabilities> capabilities() async {
    final caps = await _invoke<Map<Object?, Object?>>('capabilities');
    if (caps == null) return const DeviceCapabilities();
    return DeviceCapabilities(
      directSms: caps['sms'] == true,
      directCall: caps['call'] == true,
      torch: caps['torch'] == true,
      siren: true,
      contactPicker: true,
    );
  }

  @override
  Future<SmsResult> sendSms(String phone, String message) async {
    try {
      final res = await _invoke<Map<Object?, Object?>>('sendSms', {
        'phone': phone,
        'message': message,
      });
      if (res == null) return const SmsResult.failed('unsupported');
      return res['status'] == 'sent'
          ? const SmsResult.sent()
          : SmsResult.failed(res['error'] as String? ?? 'failed');
    } on PlatformException catch (e) {
      return SmsResult.failed(e.message ?? e.code);
    }
  }

  @override
  Future<bool> openSmsComposer(List<String> phones, String message) {
    final recipients = phones.join(
      defaultTargetPlatform == TargetPlatform.iOS ? ',' : ';',
    );
    final uri = Uri.parse(
      'sms:$recipients?body=${Uri.encodeComponent(message)}',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Future<PickedContact?> pickContact() async {
    final res = await _invoke<Map<Object?, Object?>>('pickContact');
    if (res == null) return null;
    return PickedContact(
      res['name'] as String? ?? '',
      res['phone'] as String? ?? '',
    );
  }

  @override
  Future<bool> call(String number, {bool direct = false}) async {
    final placed = await _invoke<bool>('call', {
      'number': number,
      'direct': direct,
    });
    if (placed != null) return placed;
    return launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<int?> batteryLevel() => _invoke<int>('batteryLevel');

  @override
  Future<bool> setTorch(bool on) async =>
      await _invoke<bool>('setTorch', {'on': on}) ?? false;

  @override
  Future<void> startSiren() => _invoke<void>('startSiren');

  @override
  Future<void> stopSiren() => _invoke<void>('stopSiren');

  @override
  Future<void> startRingtone() => _invoke<void>('startRingtone');

  @override
  Future<void> stopRingtone() => _invoke<void>('stopRingtone');

  @override
  Future<void> keepScreenOn(bool on) =>
      _invoke<void>('keepScreenOn', {'on': on});
}
