import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/incident.dart';
import '../../models/place.dart';

String incidentTitle(Incident i, AppStrings s) => switch (i.type) {
  IncidentType.sos =>
    i.trigger == SosTrigger.missedCheckIn
        ? s.t('incidentMissedCheckIn')
        : s.t('incidentSos'),
  IncidentType.journey => s.t('incidentJourney'),
  IncidentType.liveShare => s.t('incidentLiveShare'),
};

IconData incidentIcon(Incident i) => switch (i.type) {
  IncidentType.sos => Icons.sos,
  IncidentType.journey => Icons.route,
  IncidentType.liveShare => Icons.share_location,
};

Color incidentColor(Incident i) => switch (i.type) {
  IncidentType.sos => AppColors.sos,
  IncidentType.journey => AppColors.journey,
  IncidentType.liveShare => AppColors.live,
};

String incidentStatusLabel(Incident i, AppStrings s) => switch (i.status) {
  IncidentStatus.active => s.t('statusActive'),
  IncidentStatus.resolved =>
    i.type == IncidentType.journey ? s.t('statusArrived') : s.t('statusEnded'),
  IncidentStatus.cancelled => s.t('statusCancelled'),
  IncidentStatus.escalated => s.t('statusEscalated'),
};

String deliveryKindLabel(DeliveryKind k, AppStrings s) => s.t('kind_${k.name}');

String deliveryStatusLabel(Delivery d, AppStrings s) => switch (d.status) {
  DeliveryStatus.sent => s.t('deliverySent'),
  DeliveryStatus.composer => s.t('deliveryComposer'),
  DeliveryStatus.failed =>
    d.error == 'permission_denied'
        ? s.t('deliveryFailedPermission')
        : d.error == 'sms_unavailable'
        ? s.t('deliveryFailedUnavailable')
        : s.t('deliveryFailed'),
};

Color deliveryStatusColor(DeliveryStatus st) => switch (st) {
  DeliveryStatus.sent => AppColors.success,
  DeliveryStatus.composer => AppColors.journey,
  DeliveryStatus.failed => AppColors.sos,
};

IconData deliveryStatusIcon(DeliveryStatus st) => switch (st) {
  DeliveryStatus.sent => Icons.check_circle,
  DeliveryStatus.composer => Icons.edit_note,
  DeliveryStatus.failed => Icons.error,
};

String placeCategoryLabel(PlaceCategory c, AppStrings s) =>
    s.t('place_${c.name}');

IconData placeIcon(PlaceCategory c) => switch (c) {
  PlaceCategory.police => Icons.local_police,
  PlaceCategory.hospital => Icons.local_hospital,
  PlaceCategory.pharmacy => Icons.local_pharmacy,
  PlaceCategory.fireStation => Icons.local_fire_department,
};

Color placeColor(PlaceCategory c) => switch (c) {
  PlaceCategory.police => AppColors.police,
  PlaceCategory.hospital => AppColors.hospital,
  PlaceCategory.pharmacy => AppColors.pharmacy,
  PlaceCategory.fireStation => AppColors.fire,
};

String formatDateTime(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).add_jm().format(t.toLocal());
}

String formatTime(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.jm(locale).format(t.toLocal());
}

/// "12:05" / "1:02:05"
String formatCountdown(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

String formatDuration(Duration d, AppStrings s) {
  if (d.inMinutes < 60) return s.t('minutesShort', {'n': d.inMinutes});
  final h = d.inMinutes ~/ 60;
  final m = d.inMinutes % 60;
  return m == 0
      ? s.t('hoursShort', {'n': h})
      : s.t('hoursMinutesShort', {'h': h, 'm': m});
}
