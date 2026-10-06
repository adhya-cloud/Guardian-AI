/// A person who receives SOS alerts and location updates.
class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship = '',
    this.isPrimary = false,
    this.alertOnSos = true,
  });

  final String id;
  final String name;

  /// Normalised digits with optional leading `+`.
  final String phone;
  final String relationship;

  /// The primary contact is called automatically when auto-call is enabled.
  final bool isPrimary;

  /// Whether this contact receives SOS alerts and journey escalations.
  final bool alertOnSos;

  TrustedContact copyWith({
    String? name,
    String? phone,
    String? relationship,
    bool? isPrimary,
    bool? alertOnSos,
  }) => TrustedContact(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    relationship: relationship ?? this.relationship,
    isPrimary: isPrimary ?? this.isPrimary,
    alertOnSos: alertOnSos ?? this.alertOnSos,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relationship': relationship,
    'isPrimary': isPrimary,
    'alertOnSos': alertOnSos,
  };

  factory TrustedContact.fromJson(Map<String, dynamic> json) => TrustedContact(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    relationship: json['relationship'] as String? ?? '',
    isPrimary: json['isPrimary'] as bool? ?? false,
    alertOnSos: json['alertOnSos'] as bool? ?? true,
  );
}
