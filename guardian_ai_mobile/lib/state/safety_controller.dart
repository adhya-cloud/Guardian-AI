import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/messages.dart';
import '../core/strings.dart';
import '../models/contact.dart';
import '../models/geo_point.dart';
import '../models/incident.dart';
import '../models/profile.dart';
import '../services/device_bridge.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/permissions.dart';
import '../services/storage.dart';
import '../services/tracking_client.dart';

typedef TrackingClientFactory = TrackingClient Function(String baseUrl);

/// In-memory bookkeeping for an active session (not persisted).
class _SessionRuntime {
  DateTime? lastUpdateSentAt;
  GeoPoint? lastSentPoint;
  bool reminderShown = false;
  bool needsFirstFix = false;
  final pendingPoints = <GeoPoint>[];
}

/// App state and all safety logic: profile, contacts, history and the live
/// sessions (SOS, journey check-in, live location sharing).
class SafetyController extends ChangeNotifier {
  SafetyController({
    required this.storage,
    required this.device,
    required this.location,
    required this.permissions,
    required this.notifications,
    TrackingClientFactory? trackingFactory,
    DateTime Function()? now,
    this.tickInterval = const Duration(seconds: 5),
  }) : _trackingFactory = trackingFactory ?? ((url) => TrackingClient(url)),
       _now = now ?? DateTime.now;

  final SafetyStorage storage;
  final DeviceBridge device;
  final LocationService location;
  final PermissionService permissions;
  final NotificationService notifications;
  final TrackingClientFactory _trackingFactory;
  final DateTime Function() _now;
  final Duration tickInterval;

  static const journeyReminderLead = Duration(minutes: 2);
  static const maxIncidents = 100;

  // ── State ──────────────────────────────────────────────────────────────
  bool loaded = false;
  Profile? profile;
  AppSettings settings = const AppSettings();
  List<TrustedContact> contacts = [];

  /// Newest first.
  List<Incident> incidents = [];
  GeoPoint? lastLocation;
  DeviceCapabilities capabilities = const DeviceCapabilities();

  /// SMS permission state (full edition only; null until known).
  PermissionState? smsAccess;

  /// Language picked on the welcome screen, before a profile exists.
  String onboardingLanguage = 'en';

  bool sirenOn = false;
  bool strobeOn = false;

  /// Set while an SOS is being sent, for the progress UI.
  bool sendingSos = false;

  final _runtime = <String, _SessionRuntime>{};
  StreamSubscription<GeoPoint>? _trackingSub;
  String? _trackingMode;
  Timer? _ticker;
  Timer? _strobeTimer;
  DateTime? _lastPersist;
  Future<void> _writeQueue = Future.value();
  bool _flushing = false;
  bool _disposed = false;

  AppStrings get strings => AppStrings(profile?.language ?? onboardingLanguage);
  AlertMessages get _messages => AlertMessages(
    profile?.language ?? 'en',
    name: profile?.name ?? 'Guardian user',
  );

  Incident? _active(IncidentType type) {
    for (final i in incidents) {
      if (i.type == type && i.isActive) return i;
    }
    return null;
  }

  Incident? get activeSos => _active(IncidentType.sos);
  Incident? get activeJourney => _active(IncidentType.journey);
  Incident? get activeLiveShare => _active(IncidentType.liveShare);
  bool get hasActiveSession =>
      activeSos != null || activeJourney != null || activeLiveShare != null;
  bool get isTracking => _trackingSub != null;

  List<TrustedContact> get sosContacts =>
      contacts.where((c) => c.alertOnSos).toList();

  TrustedContact? get primaryContact {
    for (final c in contacts) {
      if (c.isPrimary) return c;
    }
    return contacts.isEmpty ? null : contacts.first;
  }

  // ── Persistence ────────────────────────────────────────────────────────

  Future<void> load() async {
    final data = await storage.read();
    if (data != null) {
      profile = data['profile'] == null
          ? null
          : Profile.fromJson(data['profile'] as Map<String, dynamic>);
      settings = data['settings'] == null
          ? const AppSettings()
          : AppSettings.fromJson(data['settings'] as Map<String, dynamic>);
      contacts = [
        for (final c in data['contacts'] as List? ?? [])
          TrustedContact.fromJson(c as Map<String, dynamic>),
      ];
      incidents = [
        for (final i in data['incidents'] as List? ?? [])
          Incident.fromJson(i as Map<String, dynamic>),
      ];
    }
    try {
      capabilities = await device.capabilities();
    } on Exception {
      capabilities = const DeviceCapabilities();
    }
    await refreshSmsAccess();
    loaded = true;
    _notify();
    await _resumeSessions();
  }

  Map<String, dynamic> _snapshot() => {
    if (profile != null) 'profile': profile!.toJson(),
    'settings': settings.toJson(),
    'contacts': contacts.map((c) => c.toJson()).toList(),
    'incidents': incidents.map((i) => i.toJson()).toList(),
  };

  /// Serialises writes so concurrent saves never interleave.
  Future<void> _persist() {
    _lastPersist = _now();
    final snapshot = _snapshot();
    return _writeQueue = _writeQueue
        .then((_) => storage.write(snapshot))
        .catchError((Object _) {});
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Profile, settings, contacts ────────────────────────────────────────

  void setOnboardingLanguage(String language) {
    onboardingLanguage = language;
    _notify();
  }

  Future<void> saveProfile(Profile value) async {
    profile = value;
    _notify();
    await _persist();
  }

  Future<void> saveSettings(AppSettings value) async {
    settings = value;
    _notify();
    await _persist();
  }

  Future<void> saveContact(TrustedContact contact) async {
    final index = contacts.indexWhere((c) => c.id == contact.id);
    var list = [...contacts];
    if (index == -1) {
      list.add(contact);
    } else {
      list[index] = contact;
    }
    if (contact.isPrimary) {
      list = [
        for (final c in list)
          c.id == contact.id ? c : c.copyWith(isPrimary: false),
      ];
    } else if (!list.any((c) => c.isPrimary)) {
      list[0] = list[0].copyWith(isPrimary: true);
    }
    contacts = list;
    _notify();
    await _persist();
  }

  Future<void> removeContact(String id) async {
    contacts = contacts.where((c) => c.id != id).toList();
    if (contacts.isNotEmpty && !contacts.any((c) => c.isPrimary)) {
      contacts[0] = contacts[0].copyWith(isPrimary: true);
    }
    _notify();
    await _persist();
  }

  Future<void> deleteIncident(String id) async {
    incidents.removeWhere((i) => i.id == id && !i.isActive);
    _notify();
    await _persist();
  }

  Future<void> clearHistory() async {
    incidents.removeWhere((i) => !i.isActive);
    _notify();
    await _persist();
  }

  Future<void> deleteAllData() async {
    for (final i in incidents.where((i) => i.isActive)) {
      i.status = IncidentStatus.cancelled;
    }
    await _stopAllTools();
    _syncTracking();
    // Queue behind any pending save so nothing is written after the delete.
    await (_writeQueue = _writeQueue
        .then((_) => storage.delete())
        .catchError((Object _) {}));
    profile = null;
    settings = const AppSettings();
    contacts = [];
    incidents = [];
    _runtime.clear();
    _notify();
  }

  String _newId() => _now().microsecondsSinceEpoch.toRadixString(36);

  void _addIncident(Incident incident) {
    incidents.insert(0, incident);
    _runtime[incident.id] = _SessionRuntime();
    // Trim old, finished history.
    while (incidents.length > maxIncidents) {
      final idx = incidents.lastIndexWhere((i) => !i.isActive);
      if (idx == -1) break;
      incidents.removeAt(idx);
    }
  }

  _SessionRuntime _rt(Incident i) =>
      _runtime.putIfAbsent(i.id, _SessionRuntime.new);

  List<TrustedContact> _recipients(Incident incident) {
    final ids = incident.recipientIds.toSet();
    return contacts.where((c) => ids.contains(c.id)).toList();
  }

  // ── Location helpers ───────────────────────────────────────────────────

  /// A recent fix if we have one, otherwise asks the GPS.
  Future<GeoPoint?> freshLocation({
    Duration maxAge = const Duration(seconds: 45),
  }) async {
    final last = lastLocation;
    if (last != null && _now().difference(last.time).abs() < maxAge) {
      return last;
    }
    final access = await location.access();
    if (access != LocationAccess.granted) return last;
    final fix = await location.currentPosition(
      timeLimit: const Duration(seconds: 12),
    );
    if (fix != null) _onPosition(fix, fromTracking: false);
    return fix ?? last;
  }

  Future<int?> _battery() async {
    try {
      return await device.batteryLevel();
    } on Exception {
      return null;
    }
  }

  void _onPosition(GeoPoint p, {bool fromTracking = true}) {
    lastLocation = p;
    for (final incident in incidents.where((i) => i.isActive)) {
      final last = incident.lastPoint;
      final moved =
          last == null ||
          p.distanceTo(last) >= 10 ||
          p.time.difference(last.time).inSeconds >= 30;
      if (!moved) continue;
      incident.addPoint(p);
      final rt = _rt(incident);
      if (incident.tracking != null) rt.pendingPoints.add(p);
      if (rt.needsFirstFix && incident.type == IncidentType.sos) {
        rt.needsFirstFix = false;
        unawaited(_sendLocationUpdate(incident, force: true));
      }
    }
    _notify();
  }

  /// Location stream + ticker run while any session is active.
  void _syncTracking() {
    final mode = activeSos != null
        ? 'sos'
        : activeJourney != null
        ? 'journey'
        : activeLiveShare != null
        ? 'live'
        : null;
    if (mode == _trackingMode) return;
    _trackingSub?.cancel();
    _trackingSub = null;
    _trackingMode = mode;
    if (mode == null) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    final s = strings;
    _trackingSub = location
        .positionStream(
          background: true,
          notificationTitle: s.t('notifTrackingTitle'),
          notificationText: s.t(switch (mode) {
            'sos' => 'notifTrackingSos',
            'journey' => 'notifTrackingJourney',
            _ => 'notifTrackingLive',
          }),
        )
        .listen(_onPosition, onError: (Object _) {});
    _ticker ??= Timer.periodic(tickInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    final now = _now();
    final journey = activeJourney;
    if (journey != null && journey.deadline != null) {
      final rt = _rt(journey);
      if (!rt.reminderShown &&
          journey.deadline!.difference(now) <= journeyReminderLead) {
        rt.reminderShown = true;
        final mins = journey.deadline!.difference(now).inMinutes.clamp(0, 999);
        unawaited(
          notifications.show(
            NotificationIds.journeyReminder,
            strings.t('notifJourneyReminderTitle'),
            strings.t('notifJourneyReminderBody', {'min': '${mins + 1}'}),
            alarm: true,
          ),
        );
        _notify();
      }
      if (!now.isBefore(journey.deadline!)) {
        await _escalateJourney(journey);
      }
    }

    final live = activeLiveShare;
    if (live != null && live.endsAt != null && !now.isBefore(live.endsAt!)) {
      await stopLiveShare(auto: true);
    }

    final interval = Duration(minutes: settings.updateIntervalMinutes);
    // Without background SMS (lite edition, or the permission is blocked)
    // updates would only pile up as failures, so they are skipped (the live
    // map still updates).
    for (final incident in [
      if (autoSms) ...[activeSos, activeLiveShare],
    ].whereType<Incident>()) {
      // Live shares with a map link don't need SMS updates.
      if (incident.type == IncidentType.liveShare &&
          incident.tracking != null) {
        continue;
      }
      final rt = _rt(incident);
      final last = rt.lastUpdateSentAt ?? incident.startedAt;
      if (now.difference(last) >= interval) await _sendLocationUpdate(incident);
    }

    await _flushTracking();
    if (_lastPersist == null ||
        now.difference(_lastPersist!) > const Duration(seconds: 30)) {
      await _persist();
    }
  }

  // ── Messaging ──────────────────────────────────────────────────────────

  /// Whether alerts can go out without the user pressing Send. A permission
  /// that was never asked for still counts: SOS asks for it when triggered.
  bool get autoSms =>
      capabilities.directSms &&
      smsAccess != PermissionState.restricted &&
      smsAccess != PermissionState.permanentlyDenied;

  /// The full edition is running without the SMS permission.
  bool get smsPermissionMissing =>
      capabilities.directSms &&
      smsAccess != null &&
      smsAccess != PermissionState.granted;

  Future<PermissionState> refreshSmsAccess() async {
    if (!capabilities.directSms) return PermissionState.unavailable;
    PermissionState state;
    try {
      state = await permissions.status(AppPermission.sms);
    } on Exception {
      return smsAccess ?? PermissionState.denied;
    }
    _setSmsAccess(state);
    return state;
  }

  /// Asks for the SMS permission when Android can still show the dialog.
  ///
  /// A restricted permission is only requested when the user asks for it
  /// ([userInitiated]): Android then shows its own "denied access" message,
  /// which unlocks "Allow restricted settings" in App info, or the normal
  /// dialog if restricted settings are already allowed. SOS never waits on
  /// that message.
  Future<PermissionState> requestSmsAccess({bool userInitiated = false}) async {
    var state = await refreshSmsAccess();
    if (state == PermissionState.denied ||
        (userInitiated && state == PermissionState.restricted)) {
      try {
        state = await permissions.request(AppPermission.sms);
      } on Exception {
        return state;
      }
      _setSmsAccess(state);
    }
    return state;
  }

  void _setSmsAccess(PermissionState state) {
    if (state == smsAccess) return;
    smsAccess = state;
    _notify();
  }

  Future<bool> _smsPermission() async =>
      await requestSmsAccess() == PermissionState.granted;

  /// Sends [message] to [to] and records per-contact results on [incident].
  Future<List<Delivery>> _deliver(
    Incident? incident,
    List<TrustedContact> to,
    String message,
    DeliveryKind kind, {
    bool allowComposer = true,
  }) async {
    if (to.isEmpty) return const [];
    final List<Delivery> results;
    if (capabilities.directSms && await _smsPermission()) {
      results = await Future.wait(
        to.map((c) async {
          final r = await device.sendSms(c.phone, message);
          return Delivery(
            contactName: c.name,
            phone: c.phone,
            kind: kind,
            status: r.sent ? DeliveryStatus.sent : DeliveryStatus.failed,
            error: r.error,
            at: _now(),
          );
        }),
      );
    } else if (allowComposer) {
      final opened = await device.openSmsComposer(
        to.map((c) => c.phone).toList(),
        message,
      );
      results = [
        for (final c in to)
          Delivery(
            contactName: c.name,
            phone: c.phone,
            kind: kind,
            status: opened ? DeliveryStatus.composer : DeliveryStatus.failed,
            error: opened ? null : 'sms_unavailable',
            at: _now(),
          ),
      ];
    } else {
      results = [
        for (final c in to)
          Delivery(
            contactName: c.name,
            phone: c.phone,
            kind: kind,
            status: DeliveryStatus.failed,
            error: 'sms_unavailable',
            at: _now(),
          ),
      ];
    }
    incident?.deliveries.addAll(results);
    _notify();
    await _persist();
    return results;
  }

  Future<void> _sendLocationUpdate(
    Incident incident, {
    bool force = false,
  }) async {
    final rt = _rt(incident);
    final point = incident.lastPoint ?? lastLocation;
    rt.lastUpdateSentAt = _now();
    if (point == null) return;
    // Skip if nothing changed since the last update (unless forced).
    if (!force &&
        rt.lastSentPoint != null &&
        point.distanceTo(rt.lastSentPoint!) < 25) {
      return;
    }
    rt.lastSentPoint = point;
    final msg = _messages.locationUpdate(
      point,
      battery: await _battery(),
      sos: incident.type == IncidentType.sos,
    );
    await _deliver(
      incident,
      _recipients(incident),
      msg,
      DeliveryKind.locationUpdate,
      allowComposer: false,
    );
  }

  // ── Live-map server ────────────────────────────────────────────────────

  Future<TrackingLink?> _createLink(
    String reason,
    int minutes, {
    String? note,
  }) async {
    if (!settings.hasTrackingServer) return null;
    try {
      return await _trackingFactory(settings.trackingServerUrl).create(
        name: profile?.name ?? 'Guardian user',
        reason: reason,
        durationMinutes: minutes,
        note: note,
      );
    } on Exception {
      return null; // SMS still works without the live map.
    }
  }

  /// Pushes pending points to the live-map server.  Never throws: the
  /// live map is optional and must not interfere with SMS alerts.
  Future<void> _flushTracking() async {
    if (_flushing) return; // The ticker and session actions can overlap.
    _flushing = true;
    try {
      for (final incident in incidents.where(
        (i) => i.isActive && i.tracking != null,
      )) {
        final rt = _rt(incident);
        if (rt.pendingPoints.isEmpty) continue;
        // Take the batch before awaiting so concurrent additions are kept.
        final count = rt.pendingPoints.length < 100
            ? rt.pendingPoints.length
            : 100;
        final batch = rt.pendingPoints.sublist(0, count);
        rt.pendingPoints.removeRange(0, count);
        try {
          await _trackingFactory(
            settings.trackingServerUrl,
          ).push(incident.tracking!, batch, battery: await _battery());
        } on Exception {
          // Put the points back and retry on the next tick (bounded).
          rt.pendingPoints.insertAll(0, batch);
          if (rt.pendingPoints.length > 300) {
            rt.pendingPoints.removeRange(0, rt.pendingPoints.length - 300);
          }
        }
      }
    } catch (_) {
      // Defensive: a live-map failure must never stop the caller.
    } finally {
      _flushing = false;
    }
  }

  Future<void> _updateLink(
    Incident incident, {
    String? reason,
    int? extendMinutes,
    bool end = false,
  }) async {
    final link = incident.tracking;
    if (link == null || !settings.hasTrackingServer) return;
    try {
      if (end) await _flushTracking();
      await _trackingFactory(
        settings.trackingServerUrl,
      ).update(link, reason: reason, extendMinutes: extendMinutes, end: end);
    } on Exception {
      // Server-side sessions expire on their own.
    }
  }

  // ── SOS ────────────────────────────────────────────────────────────────

  /// Sends the SOS alert to all SOS contacts and starts continuous location
  /// updates.  Returns the active SOS incident.
  Future<Incident> triggerSos({SosTrigger trigger = SosTrigger.button}) async {
    final existing = activeSos;
    if (existing != null) return existing;

    final recipients = sosContacts;
    final incident = Incident(
      id: _newId(),
      type: IncidentType.sos,
      startedAt: _now(),
      trigger: trigger,
      recipientIds: recipients.map((c) => c.id).toList(),
    );
    _addIncident(incident);
    // Saved immediately so the alert is re-sent on relaunch if the app dies.
    unawaited(_persist());
    unawaited(device.keepScreenOn(true));
    if (settings.sirenOnSos) unawaited(setSiren(true));
    await _sendSosAlert(incident);
    return incident;
  }

  /// Gets a location fix and sends the SOS alert for [incident].  Also used
  /// on launch when an SOS was started but its alert never went out.
  Future<void> _sendSosAlert(Incident incident) async {
    final recipients = _recipients(incident);
    sendingSos = true;
    _notify();
    // Start background tracking first so a fix arrives as early as possible.
    _syncTracking();

    final results = await Future.wait([
      freshLocation(),
      _battery(),
      // A slow or unreachable live-map server must never delay the SMS.
      _createLink(
        'sos',
        12 * 60,
      ).timeout(const Duration(seconds: 6), onTimeout: () => null),
    ]);
    final point = results[0] as GeoPoint?;
    final battery = results[1] as int?;
    incident.tracking = results[2] as TrackingLink?;
    if (point != null) {
      // freshLocation() may already have recorded this fix.
      if (!identical(incident.lastPoint, point)) incident.addPoint(point);
      _rt(incident).pendingPoints.add(point);
    } else {
      _rt(incident).needsFirstFix = true;
    }

    final message = _messages.sosAlert(
      location: point,
      battery: battery,
      medical: profile?.medicalInfo ?? '',
      liveUrl: incident.tracking?.viewUrl,
    );
    final deliveries = await _deliver(
      incident,
      recipients,
      message,
      DeliveryKind.sosAlert,
    );
    _rt(incident)
      ..lastUpdateSentAt = _now()
      ..lastSentPoint = point;
    sendingSos = false;
    _syncTracking();
    await _flushTracking();
    _notify();

    // Only OS-confirmed messages count as sent; the composer still needs
    // the user to press Send.
    final sent = deliveries
        .where((d) => d.status == DeliveryStatus.sent)
        .length;
    final awaitingSend =
        sent == 0 && deliveries.any((d) => d.status == DeliveryStatus.composer);
    unawaited(
      notifications.show(
        NotificationIds.sos,
        awaitingSend
            ? strings.t('notifSosComposerTitle')
            : strings.t('notifSosTitle'),
        awaitingSend
            ? strings.t('notifSosComposerBody')
            : strings.t('notifSosBody', {
                'sent': '$sent',
                'total': '${recipients.length}',
              }),
      ),
    );

    await _autoCall();
  }

  /// Sends the SOS alert again with the latest location: to everyone whose
  /// alert was not confirmed sent (failed, or only opened in the SMS app).
  Future<void> resendSosAlert() async {
    final incident = activeSos;
    if (incident == null) return;
    final confirmed = {
      for (final d in incident.deliveries)
        if (d.kind == DeliveryKind.sosAlert && d.status == DeliveryStatus.sent)
          d.phone,
    };
    final to = _recipients(
      incident,
    ).where((c) => !confirmed.contains(c.phone)).toList();
    if (to.isEmpty) return;
    final point = await freshLocation();
    final message = _messages.sosAlert(
      location: point,
      battery: await _battery(),
      medical: profile?.medicalInfo ?? '',
      liveUrl: incident.tracking?.viewUrl,
    );
    await _deliver(incident, to, message, DeliveryKind.sosAlert);
  }

  /// True when some SOS recipient has no confirmed-sent alert yet.
  bool get sosAlertNeedsResend {
    final incident = activeSos;
    if (incident == null || sendingSos) return false;
    final confirmed = {
      for (final d in incident.deliveries)
        if (d.kind == DeliveryKind.sosAlert && d.status == DeliveryStatus.sent)
          d.phone,
    };
    return _recipients(incident).any((c) => !confirmed.contains(c.phone));
  }

  Future<void> _autoCall() async {
    final number = switch (settings.autoCall) {
      AutoCall.off => null,
      AutoCall.primaryContact => primaryContact?.phone,
      AutoCall.emergencyNumber => profile?.emergencyNumber,
    };
    if (number == null || number.isEmpty) return;
    if (!capabilities.directCall) {
      await device.call(number);
      return;
    }
    var phone = await permissions.status(AppPermission.phone);
    if (phone == PermissionState.denied) {
      phone = await permissions.request(AppPermission.phone);
    }
    await device.call(number, direct: phone == PermissionState.granted);
  }

  /// Ends the SOS; optionally tells contacts the user is safe.
  Future<void> stopSos({bool notifyContacts = true}) async {
    final incident = activeSos;
    if (incident == null) return;
    incident
      ..status = IncidentStatus.resolved
      ..endedAt = _now();
    _notify();
    await _stopAllTools();
    unawaited(device.keepScreenOn(false));
    unawaited(notifications.cancel(NotificationIds.sos));
    _syncTracking();
    await _updateLink(incident, end: true);
    if (notifyContacts) {
      await _deliver(
        incident,
        _recipients(incident),
        _messages.safe(),
        DeliveryKind.safe,
        allowComposer: true,
      );
    }
    _runtime.remove(incident.id);
    await _persist();
  }

  // ── Journey check-in ───────────────────────────────────────────────────

  Future<Incident> startJourney({
    required Duration duration,
    String? destination,
    required List<String> contactIds,
  }) async {
    final existing = activeJourney;
    if (existing != null) return existing;
    final start = _now();
    final incident = Incident(
      id: _newId(),
      type: IncidentType.journey,
      startedAt: start,
      destination: destination?.trim().isEmpty == true
          ? null
          : destination?.trim(),
      deadline: start.add(duration),
      recipientIds: contactIds,
    );
    _addIncident(incident);
    _notify();
    await location.access();
    _syncTracking();
    final point = await freshLocation();
    if (point != null && !identical(incident.lastPoint, point)) {
      incident.addPoint(point);
    }
    // Leave room for escalation after the deadline.
    incident.tracking = await _createLink(
      'journey',
      duration.inMinutes + 60,
      note: incident.destination,
    );
    if (settings.notifyJourneyStart) {
      await _deliver(
        incident,
        _recipients(incident),
        _messages.journeyStart(
          deadline: incident.deadline!,
          destination: incident.destination,
          liveUrl: incident.tracking?.viewUrl,
        ),
        DeliveryKind.journeyStart,
      );
    }
    await _persist();
    return incident;
  }

  Future<void> extendJourney(Duration by) async {
    final incident = activeJourney;
    if (incident == null) return;
    incident.deadline = incident.deadline!.add(by);
    _rt(incident).reminderShown = false;
    unawaited(notifications.cancel(NotificationIds.journeyReminder));
    _notify();
    await _updateLink(incident, extendMinutes: by.inMinutes);
    await _persist();
  }

  /// [arrived] true = checked in safely; false = cancelled the journey.
  Future<void> finishJourney({required bool arrived}) async {
    final incident = activeJourney;
    if (incident == null) return;
    incident
      ..status = arrived ? IncidentStatus.resolved : IncidentStatus.cancelled
      ..endedAt = _now();
    unawaited(notifications.cancel(NotificationIds.journeyReminder));
    _notify();
    _syncTracking();
    await _updateLink(incident, end: true);
    if (arrived && settings.notifyArrival) {
      await _deliver(
        incident,
        _recipients(incident),
        _messages.arrived(destination: incident.destination),
        DeliveryKind.arrived,
      );
    }
    _runtime.remove(incident.id);
    await _persist();
  }

  /// Missed check-in: alert the journey contacts and switch to SOS mode.
  Future<void> _escalateJourney(Incident journey) async {
    if (!journey.isActive) return;
    journey
      ..status = IncidentStatus.escalated
      ..endedAt = _now();
    unawaited(notifications.cancel(NotificationIds.journeyReminder));

    final recipients = _recipients(journey).isEmpty
        ? sosContacts
        : _recipients(journey);
    final sos = Incident(
      id: _newId(),
      type: IncidentType.sos,
      startedAt: _now(),
      trigger: SosTrigger.missedCheckIn,
      destination: journey.destination,
      recipientIds: recipients.map((c) => c.id).toList(),
      tracking: journey.tracking,
      path: [...journey.path],
    );
    _addIncident(sos);
    _runtime.remove(journey.id);
    _syncTracking();
    _notify();

    final point = await freshLocation(maxAge: const Duration(minutes: 5));
    if (point != null && sos.lastPoint != point) sos.addPoint(point);
    await _updateLink(sos, reason: 'sos', extendMinutes: 12 * 60);
    final deliveries = await _deliver(
      sos,
      recipients,
      _messages.missedCheckIn(
        deadline: journey.deadline!,
        destination: journey.destination,
        location: point,
        battery: await _battery(),
        liveUrl: sos.tracking?.viewUrl,
      ),
      DeliveryKind.sosAlert,
    );
    _rt(sos)
      ..lastUpdateSentAt = _now()
      ..lastSentPoint = point
      ..needsFirstFix = point == null;
    final sent = deliveries
        .where((d) => d.status == DeliveryStatus.sent)
        .length;
    unawaited(
      notifications.show(
        NotificationIds.journeyEscalated,
        sent > 0
            ? strings.t('notifJourneyEscalatedTitle')
            : strings.t('notifJourneyMissedTitle'),
        sent > 0
            ? strings.t('notifJourneyEscalatedBody', {
                'sent': '$sent',
                'total': '${recipients.length}',
              })
            : strings.t('notifJourneyMissedBody'),
        alarm: true,
      ),
    );
    await _persist();
  }

  // ── Live location sharing ──────────────────────────────────────────────

  Future<Incident> startLiveShare({
    required Duration duration,
    required List<String> contactIds,
  }) async {
    final existing = activeLiveShare;
    if (existing != null) return existing;
    final start = _now();
    final incident = Incident(
      id: _newId(),
      type: IncidentType.liveShare,
      startedAt: start,
      endsAt: start.add(duration),
      recipientIds: contactIds,
    );
    _addIncident(incident);
    _notify();
    await location.access();
    _syncTracking();
    final point = await freshLocation();
    if (point != null) {
      // freshLocation() may already have recorded this fix.
      if (!identical(incident.lastPoint, point)) incident.addPoint(point);
      _rt(incident).pendingPoints.add(point);
    }
    incident.tracking = await _createLink('live', duration.inMinutes);
    await _flushTracking();
    _rt(incident)
      ..lastUpdateSentAt = _now()
      ..lastSentPoint = point;
    await _deliver(
      incident,
      _recipients(incident),
      _messages.liveStart(
        until: incident.endsAt!,
        location: point,
        liveUrl: incident.tracking?.viewUrl,
        intervalMinutes: settings.updateIntervalMinutes,
      ),
      DeliveryKind.liveStart,
    );
    await _persist();
    return incident;
  }

  Future<void> stopLiveShare({bool auto = false}) async {
    final incident = activeLiveShare;
    if (incident == null) return;
    incident
      ..status = IncidentStatus.resolved
      ..endedAt = _now();
    _notify();
    _syncTracking();
    await _updateLink(incident, end: true);
    await _deliver(
      incident,
      _recipients(incident),
      _messages.liveEnd(),
      DeliveryKind.liveEnd,
      allowComposer: !auto,
    );
    _runtime.remove(incident.id);
    await _persist();
  }

  // ── One-off actions ────────────────────────────────────────────────────

  /// Text for the system share sheet, or null without a location.
  Future<String?> locationShareText() async {
    final point = await freshLocation();
    return point == null ? null : _messages.locationOnce(point);
  }

  Future<List<Delivery>> sendLocationTo(List<TrustedContact> to) async {
    final point = await freshLocation();
    if (point == null) return const [];
    return _deliver(
      null,
      to,
      _messages.locationOnce(point),
      DeliveryKind.locationOnce,
    );
  }

  Future<Delivery?> sendTestMessage(TrustedContact contact) async {
    final results = await _deliver(
      null,
      [contact],
      _messages.test(contact.name),
      DeliveryKind.test,
    );
    return results.isEmpty ? null : results.first;
  }

  Future<bool> callEmergency() =>
      device.call(profile?.emergencyNumber ?? '112', direct: false);

  // ── Siren and strobe ───────────────────────────────────────────────────

  Future<void> setSiren(bool on) async {
    sirenOn = on;
    _notify();
    on ? await device.startSiren() : await device.stopSiren();
  }

  Future<void> setStrobe(bool on) async {
    _strobeTimer?.cancel();
    _strobeTimer = null;
    strobeOn = on;
    _notify();
    if (!on) {
      await device.setTorch(false);
      return;
    }
    var lit = false;
    _strobeTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      lit = !lit;
      device.setTorch(lit);
    });
  }

  Future<void> _stopAllTools() async {
    if (sirenOn) await setSiren(false);
    if (strobeOn) await setStrobe(false);
  }

  // ── Restoring sessions after the app restarts ──────────────────────────

  Future<void> _resumeSessions() async {
    final now = _now();
    final live = activeLiveShare;
    if (live != null && live.endsAt != null && !now.isBefore(live.endsAt!)) {
      live
        ..status = IncidentStatus.resolved
        ..endedAt = live.endsAt;
    }
    final journey = activeJourney;
    if (journey != null &&
        journey.deadline != null &&
        !now.isBefore(journey.deadline!)) {
      await _escalateJourney(journey);
    }
    for (final i in incidents.where((i) => i.isActive)) {
      _rt(i).lastUpdateSentAt = now;
    }
    if (hasActiveSession) {
      _syncTracking();
      if (activeSos != null) unawaited(device.keepScreenOn(true));
    }
    _notify();
    await _persist();
    // The app stopped before the SOS alert went out: send it now.
    final sos = activeSos;
    if (sos != null &&
        !sos.deliveries.any((d) => d.kind == DeliveryKind.sosAlert)) {
      await _sendSosAlert(sos);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _trackingSub?.cancel();
    _ticker?.cancel();
    _strobeTimer?.cancel();
    super.dispose();
  }
}
