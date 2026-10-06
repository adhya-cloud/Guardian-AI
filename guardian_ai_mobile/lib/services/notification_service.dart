/// Local notifications (check-in reminders, SOS status).
abstract interface class NotificationService {
  Future<void> init();

  /// [alarm] uses the high-importance channel that sounds even in silent
  /// mode where the OS allows it.
  Future<void> show(int id, String title, String body, {bool alarm = false});

  Future<void> cancel(int id);
}

class NotificationIds {
  static const sos = 1;
  static const journeyReminder = 2;
  static const journeyEscalated = 3;
  static const liveShare = 4;
}
