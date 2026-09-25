/// Personnel model matching PRD §3 `stations/{stationId}/personnel/{personId}`
class Personnel {
  final String id;
  final String stationId;
  final String name;
  final String role; // researcher / crew / medical / logistics / station-lead
  final String specialization;
  final DateTime arrivalDate;
  final DateTime? departureDate;
  final String status; // on-station / in-transit / departed
  final String bloodGroup;
  final String emergencyContact;
  final String avatarUrl;
  final bool medicalCleared;

  const Personnel({
    required this.id,
    required this.stationId,
    required this.name,
    required this.role,
    required this.specialization,
    required this.arrivalDate,
    this.departureDate,
    required this.status,
    required this.bloodGroup,
    required this.emergencyContact,
    required this.avatarUrl,
    this.medicalCleared = true,
  });

  Personnel copyWith({
    String? name,
    String? role,
    String? specialization,
    DateTime? arrivalDate,
    DateTime? departureDate,
    String? status,
    String? bloodGroup,
    String? emergencyContact,
    String? avatarUrl,
    bool? medicalCleared,
  }) {
    return Personnel(
      id: id,
      stationId: stationId,
      name: name ?? this.name,
      role: role ?? this.role,
      specialization: specialization ?? this.specialization,
      arrivalDate: arrivalDate ?? this.arrivalDate,
      departureDate: departureDate ?? this.departureDate,
      status: status ?? this.status,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      medicalCleared: medicalCleared ?? this.medicalCleared,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stationId': stationId,
      'name': name,
      'role': role,
      'specialization': specialization,
      'arrivalDate': arrivalDate.toIso8601String(),
      'departureDate': departureDate?.toIso8601String(),
      'status': status,
      'bloodGroup': bloodGroup,
      'emergencyContact': emergencyContact,
      'avatarUrl': avatarUrl,
      'medicalCleared': medicalCleared,
    };
  }

  factory Personnel.fromMap(String id, Map<String, dynamic> map) {
    return Personnel(
      id: id,
      stationId: map['stationId'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'researcher',
      specialization: map['specialization'] ?? '',
      arrivalDate: map['arrivalDate'] != null
          ? DateTime.parse(map['arrivalDate'])
          : DateTime.now(),
      departureDate: map['departureDate'] != null
          ? DateTime.parse(map['departureDate'])
          : null,
      status: map['status'] ?? 'on-station',
      bloodGroup: map['bloodGroup'] ?? 'O+',
      emergencyContact: map['emergencyContact'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
      medicalCleared: map['medicalCleared'] ?? true,
    );
  }
}
