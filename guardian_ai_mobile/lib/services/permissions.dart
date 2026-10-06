import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermission { location, sms, phone, notifications }

enum PermissionState {
  granted,
  denied,
  permanentlyDenied,

  /// Blocked by Android's "restricted settings" (apps installed from a file
  /// on Android 15+). No dialog can be shown; the user must first tap
  /// "Allow restricted settings" in the app's system settings.
  restricted,
  unavailable,
}

abstract interface class PermissionService {
  Future<PermissionState> status(AppPermission permission);
  Future<PermissionState> request(AppPermission permission);
  Future<bool> openSettings();
}

class PlatformPermissionService implements PermissionService {
  PlatformPermissionService();

  static const _native = MethodChannel('guardian/native');

  Permission? _map(AppPermission p) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    return switch (p) {
      AppPermission.location => Permission.locationWhenInUse,
      // SMS / call permissions only exist on Android; iOS uses the composer
      // and dialer, which need no permission.
      AppPermission.sms => android ? Permission.sms : null,
      AppPermission.phone => android ? Permission.phone : null,
      AppPermission.notifications => Permission.notification,
    };
  }

  PermissionState _convert(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) {
      return PermissionState.granted;
    }
    if (s.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    if (s.isRestricted) return PermissionState.unavailable;
    return PermissionState.denied;
  }

  /// Refines a non-granted SMS state: Android reports a restricted SMS
  /// permission as plain "denied", but no request can ever succeed.
  Future<PermissionState> _refine(
    AppPermission permission,
    PermissionState state,
  ) async {
    if (permission != AppPermission.sms ||
        state == PermissionState.granted ||
        state == PermissionState.unavailable) {
      return state;
    }
    try {
      final restricted = await _native.invokeMethod<bool>('smsRestricted');
      return restricted == true ? PermissionState.restricted : state;
    } on Exception {
      return state;
    }
  }

  @override
  Future<PermissionState> status(AppPermission permission) async {
    final p = _map(permission);
    if (p == null) return PermissionState.unavailable;
    return _refine(permission, _convert(await p.status));
  }

  @override
  Future<PermissionState> request(AppPermission permission) async {
    final p = _map(permission);
    if (p == null) return PermissionState.unavailable;
    return _refine(permission, _convert(await p.request()));
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
