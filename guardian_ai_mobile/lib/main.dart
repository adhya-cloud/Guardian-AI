import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'services/device_bridge.dart';
import 'services/local_notifications.dart';
import 'services/location_service.dart';
import 'services/permissions.dart';
import 'services/places_service.dart';
import 'services/storage.dart';
import 'state/safety_controller.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = LocalNotificationService();
  final controller = SafetyController(
    storage: SecureSafetyStorage(),
    device: PlatformDeviceBridge(),
    location: NativeLocationService(),
    permissions: PlatformPermissionService(),
    notifications: notifications,
  );
  runApp(
    GuardianApp(
      controller: controller,
      places: PlacesService(),
      accelerometer: () => userAccelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).map((e) => (e.x, e.y, e.z)),
    ),
  );
  notifications.init();
  controller.load();
}
