import 'geo_point.dart';

enum IncidentType { sos, journey, liveShare }

enum IncidentStatus {
  active,

  /// Ended normally: "I'm safe", arrived, or live share finished.
  resolved,

  /// Stopped by the user before it completed (e.g. journey cancelled).
  cancelled,

  /// A journey whose check-in was missed and turned into an SOS.
  escalated,
}

/// What caused an SOS.
enum SosTrigger { button, shake, missedCheckIn }

/// Why a message was sent.
enum DeliveryKind {
  sosAlert,
  locationUpdate,
  safe,
  journeyStart,
  arrived,
  liveStart,
  liveEnd,
  locationOnce,
  test,
}

enum DeliveryStatus {
  /// Handed to the carrier and confirmed sent by the OS.
  sent,

  /// The OS reported a failure (no signal, invalid number, ...).
  failed,

  /// Direct sending unavailable; the SMS app was opened pre-filled.
  composer,
}

class Delivery {
  const Delivery({
    required this.contactName,
    required this.phone,
    required this.kind,
    required this.status,
    required this.at,
    this.error,
  });

  final String contactName;
  final String phone;
  final DeliveryKind kind;
  final DeliveryStatus status;
  final DateTime at;
  final String? error;

  Map<String, dynamic> toJson() => {
    'contactName': contactName,
    'phone': phone,
    'kind': kind.name,
    'status': status.name,
    'at': at.toUtc().toIso8601String(),
    if (error != null) 'error': error,
  };

  factory Delivery.fromJson(Map<String, dynamic> json) => Delivery(
    contactName: json['contactName'] as String,
    phone: json['phone'] as String,
    kind: DeliveryKind.values.byName(json['kind'] as String),
    status: DeliveryStatus.values.byName(json['status'] as String),
    at: DateTime.parse(json['at'] as String),
    error: json['error'] as String?,
  );
}

/// Credentials for a live-map session on the tracking server.
class TrackingLink {
  const TrackingLink({
    required this.sessionId,
    required this.ownerKey,
    required this.viewUrl,
  });

  final String sessionId;
  final String ownerKey;
  final String viewUrl;

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'ownerKey': ownerKey,
    'viewUrl': viewUrl,
  };

  factory TrackingLink.fromJson(Map<String, dynamic> json) => TrackingLink(
    sessionId: json['sessionId'] as String,
    ownerKey: json['ownerKey'] as String,
    viewUrl: json['viewUrl'] as String,
  );
}

/// A recorded safety event: an SOS, a journey, or a live-location share.
class Incident {
  Incident({
    required this.id,
    required this.type,
    required this.startedAt,
    this.status = IncidentStatus.active,
    this.endedAt,
    this.trigger,
    this.destination,
    this.deadline,
    this.endsAt,
    this.recipientIds = const [],
    this.tracking,
    List<GeoPoint>? path,
    List<Delivery>? deliveries,
  }) : path = path ?? [],
       deliveries = deliveries ?? [];

  static const maxPathPoints = 500;

  final String id;
  final IncidentType type;
  final DateTime startedAt;
  IncidentStatus status;
  DateTime? endedAt;

  /// SOS only.
  final SosTrigger? trigger;

  /// Journey only: where the user is heading (free text).
  final String? destination;

  /// Journey only: when the user must check in.
  DateTime? deadline;

  /// Live share only: when sharing stops automatically.
  DateTime? endsAt;

  /// Contacts who receive messages for this incident.
  final List<String> recipientIds;

  /// Live-map link, when a tracking server is configured.
  TrackingLink? tracking;

  final List<GeoPoint> path;
  final List<Delivery> deliveries;

  bool get isActive => status == IncidentStatus.active;

  GeoPoint? get lastPoint => path.isEmpty ? null : path.last;

  void addPoint(GeoPoint point) {
    path.add(point);
    if (path.length > maxPathPoints) path.removeAt(0);
  }

  int get sentCount =>
      deliveries.where((d) => d.status == DeliveryStatus.sent).length;

  int get failedCount =>
      deliveries.where((d) => d.status == DeliveryStatus.failed).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'status': status.name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toUtc().toIso8601String(),
    if (trigger != null) 'trigger': trigger!.name,
    if (destination != null) 'destination': destination,
    if (deadline != null) 'deadline': deadline!.toUtc().toIso8601String(),
    if (endsAt != null) 'endsAt': endsAt!.toUtc().toIso8601String(),
    'recipientIds': recipientIds,
    if (tracking != null) 'tracking': tracking!.toJson(),
    'path': path.map((p) => p.toJson()).toList(),
    'deliveries': deliveries.map((d) => d.toJson()).toList(),
  };

  factory Incident.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);
    return Incident(
      id: json['id'] as String,
      type: IncidentType.values.byName(json['type'] as String),
      status: IncidentStatus.values.byName(json['status'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: date('endedAt'),
      trigger: json['trigger'] == null
          ? null
          : SosTrigger.values.byName(json['trigger'] as String),
      destination: json['destination'] as String?,
      deadline: date('deadline'),
      endsAt: date('endsAt'),
      recipientIds: List<String>.from(json['recipientIds'] as List? ?? []),
      tracking: json['tracking'] == null
          ? null
          : TrackingLink.fromJson(json['tracking'] as Map<String, dynamic>),
      path: [
        for (final p in json['path'] as List? ?? [])
          GeoPoint.fromJson(p as Map<String, dynamic>),
      ],
      deliveries: [
        for (final d in json['deliveries'] as List? ?? [])
          Delivery.fromJson(d as Map<String, dynamic>),
      ],
    );
  }
}
