/// The person using the app.
class Profile {
  const Profile({
    required this.name,
    this.language = 'en',
    this.emergencyNumber = '112',
    this.medicalInfo = '',
  });

  final String name;

  /// 'en' or 'hi'.  Also used for outgoing alert messages.
  final String language;

  /// India's national emergency number (ERSS) by default.
  final String emergencyNumber;

  /// Optional blood group / allergies / conditions, appended to SOS alerts.
  final String medicalInfo;

  Profile copyWith({
    String? name,
    String? language,
    String? emergencyNumber,
    String? medicalInfo,
  }) => Profile(
    name: name ?? this.name,
    language: language ?? this.language,
    emergencyNumber: emergencyNumber ?? this.emergencyNumber,
    medicalInfo: medicalInfo ?? this.medicalInfo,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'language': language,
    'emergencyNumber': emergencyNumber,
    'medicalInfo': medicalInfo,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['name'] as String,
    language: json['language'] as String? ?? 'en',
    emergencyNumber: json['emergencyNumber'] as String? ?? '112',
    medicalInfo: json['medicalInfo'] as String? ?? '',
  );
}

enum AutoCall { off, primaryContact, emergencyNumber }

class AppSettings {
  const AppSettings({
    this.countdownSeconds = 5,
    this.updateIntervalMinutes = 5,
    this.autoCall = AutoCall.off,
    this.sirenOnSos = false,
    this.shakeToSos = true,
    this.trackingServerUrl = '',
    this.notifyJourneyStart = true,
    this.notifyArrival = true,
  });

  /// Seconds to cancel an SOS before alerts go out.
  final int countdownSeconds;

  /// How often location-update SMS are sent during SOS / live sharing.
  final int updateIntervalMinutes;
  final AutoCall autoCall;
  final bool sirenOnSos;
  final bool shakeToSos;

  /// Optional base URL of a Guardian tracking server for live-map links.
  final String trackingServerUrl;
  final bool notifyJourneyStart;
  final bool notifyArrival;

  bool get hasTrackingServer => trackingServerUrl.trim().isNotEmpty;

  AppSettings copyWith({
    int? countdownSeconds,
    int? updateIntervalMinutes,
    AutoCall? autoCall,
    bool? sirenOnSos,
    bool? shakeToSos,
    String? trackingServerUrl,
    bool? notifyJourneyStart,
    bool? notifyArrival,
  }) => AppSettings(
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    updateIntervalMinutes: updateIntervalMinutes ?? this.updateIntervalMinutes,
    autoCall: autoCall ?? this.autoCall,
    sirenOnSos: sirenOnSos ?? this.sirenOnSos,
    shakeToSos: shakeToSos ?? this.shakeToSos,
    trackingServerUrl: trackingServerUrl ?? this.trackingServerUrl,
    notifyJourneyStart: notifyJourneyStart ?? this.notifyJourneyStart,
    notifyArrival: notifyArrival ?? this.notifyArrival,
  );

  Map<String, dynamic> toJson() => {
    'countdownSeconds': countdownSeconds,
    'updateIntervalMinutes': updateIntervalMinutes,
    'autoCall': autoCall.name,
    'sirenOnSos': sirenOnSos,
    'shakeToSos': shakeToSos,
    'trackingServerUrl': trackingServerUrl,
    'notifyJourneyStart': notifyJourneyStart,
    'notifyArrival': notifyArrival,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    countdownSeconds: json['countdownSeconds'] as int? ?? 5,
    updateIntervalMinutes: json['updateIntervalMinutes'] as int? ?? 5,
    autoCall: AutoCall.values.firstWhere(
      (v) => v.name == json['autoCall'],
      orElse: () => AutoCall.off,
    ),
    sirenOnSos: json['sirenOnSos'] as bool? ?? false,
    shakeToSos: json['shakeToSos'] as bool? ?? true,
    trackingServerUrl: json['trackingServerUrl'] as String? ?? '',
    notifyJourneyStart: json['notifyJourneyStart'] as bool? ?? true,
    notifyArrival: json['notifyArrival'] as bool? ?? true,
  );
}
