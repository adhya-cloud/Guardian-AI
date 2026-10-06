import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

class LocalNotificationService implements NotificationService {
  LocalNotificationService();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _alerts = AndroidNotificationChannel(
    'guardian_alerts',
    'Safety alerts',
    description: 'SOS status and missed check-in alerts',
    importance: Importance.max,
  );
  static const _status = AndroidNotificationChannel(
    'guardian_status',
    'Status updates',
    description: 'Check-in reminders and sharing status',
    importance: Importance.high,
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_guardian'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(_alerts);
      await android?.createNotificationChannel(_status);
      _ready = true;
    } on Exception {
      _ready = false;
    }
  }

  @override
  Future<void> show(
    int id,
    String title,
    String body, {
    bool alarm = false,
  }) async {
    await init();
    if (!_ready) return;
    final channel = alarm ? _alerts : _status;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: alarm ? Priority.max : Priority.high,
          category: alarm
              ? AndroidNotificationCategory.alarm
              : AndroidNotificationCategory.status,
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFFD92D20),
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: alarm
              ? InterruptionLevel.timeSensitive
              : InterruptionLevel.active,
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await init();
    if (_ready) await _plugin.cancel(id: id);
  }
}
