import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/geo_point.dart';

enum LocationAccess { granted, denied, deniedForever, serviceDisabled }

abstract interface class LocationService {
  /// Checks (and optionally requests) permission and that location is on.
  Future<LocationAccess> access({bool request = true});

  /// A fresh fix, or the best last-known one after [timeLimit].
  Future<GeoPoint?> currentPosition({
    Duration timeLimit = const Duration(seconds: 15),
  });

  Future<GeoPoint?> lastKnown();

  /// Continuous updates.  With [background] set, Android keeps receiving
  /// them through a foreground service (persistent notification) while the
  /// app is in the background.
  Stream<GeoPoint> positionStream({
    bool background = false,
    String notificationTitle = '',
    String notificationText = '',
  });

  Future<bool> openLocationSettings();
}

/// Location through Guardian's own Android bridge (see LocationBridge.kt),
/// which keeps all location work off the platform main thread.
class NativeLocationService implements LocationService {
  NativeLocationService();

  static const _methods = MethodChannel('guardian/native');
  static const _events = EventChannel('guardian/location');

  final _points = StreamController<GeoPoint>.broadcast();
  final _clients = <int, ({bool background, String title, String text})>{};
  StreamSubscription<dynamic>? _native;
  var _nextId = 0;
  Future<void> _applying = Future.value();

  static GeoPoint? _toPoint(Object? raw) {
    if (raw is! Map) return null;
    return GeoPoint(
      lat: (raw['lat'] as num).toDouble(),
      lng: (raw['lng'] as num).toDouble(),
      time: DateTime.fromMillisecondsSinceEpoch((raw['time'] as num).toInt()),
      accuracy: (raw['accuracy'] as num?)?.toDouble(),
      speed: (raw['speed'] as num?)?.toDouble(),
      heading: (raw['heading'] as num?)?.toDouble(),
    );
  }

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<LocationAccess> access({bool request = true}) async {
    if (await _call<bool>('locationEnabled') == false) {
      return LocationAccess.serviceDisabled;
    }
    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted && !status.isPermanentlyDenied && request) {
      status = await Permission.locationWhenInUse.request();
    }
    if (status.isGranted || status.isLimited) return LocationAccess.granted;
    return status.isPermanentlyDenied
        ? LocationAccess.deniedForever
        : LocationAccess.denied;
  }

  @override
  Future<GeoPoint?> currentPosition({
    Duration timeLimit = const Duration(seconds: 15),
  }) async => _toPoint(
    await _call<Object>('currentLocation', {
      'timeoutMs': timeLimit.inMilliseconds,
    }),
  );

  @override
  Future<GeoPoint?> lastKnown() async =>
      _toPoint(await _call<Object>('lastKnownLocation'));

  @override
  Stream<GeoPoint> positionStream({
    bool background = false,
    String notificationTitle = '',
    String notificationText = '',
  }) {
    final id = _nextId++;
    StreamSubscription<GeoPoint>? inner;
    late final StreamController<GeoPoint> controller;
    controller = StreamController<GeoPoint>(
      onListen: () {
        _clients[id] = (
          background: background,
          title: notificationTitle,
          text: notificationText,
        );
        inner = _points.stream.listen(controller.add);
        _apply();
      },
      onCancel: () {
        inner?.cancel();
        _clients.remove(id);
        _apply();
      },
    );
    return controller.stream;
  }

  /// Reconciles the native tracking state with the current listeners.
  void _apply() {
    _applying = _applying.then((_) async {
      if (_clients.isEmpty) {
        await _native?.cancel();
        _native = null;
        await _call<void>('stopTracking');
        return;
      }
      _native ??= _events.receiveBroadcastStream().listen((raw) {
        final p = _toPoint(raw);
        if (p != null) _points.add(p);
      }, onError: (Object _) {});
      ({bool background, String title, String text})? bg;
      for (final c in _clients.values) {
        if (c.background) bg = c;
      }
      await _call<bool>('startTracking', {
        'background': bg != null,
        'title': bg?.title ?? '',
        'text': bg?.text ?? '',
      });
    });
  }

  @override
  Future<bool> openLocationSettings() async =>
      await _call<bool>('openLocationSettings') ?? false;
}
