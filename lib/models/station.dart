/// Station model matching PRD §3 `stations/{stationId}`
class Station {
  final String id;
  final String name;
  final String code;
  final String location;
  final String coordinates;
  final String status; // active, low-connectivity, emergency
  final DateTime lastContact;
  final int powerLevel; // %
  final double temperature; // Celsius
  final double windSpeed; // knots
  final double satLinkSignal; // %
  final String sectorLiveCamUrl;
  final int activePersonnelCount;
  final DateTime nextResupplyDate;

  const Station({
    required this.id,
    required this.name,
    required this.code,
    required this.location,
    required this.coordinates,
    required this.status,
    required this.lastContact,
    required this.powerLevel,
    required this.temperature,
    required this.windSpeed,
    required this.satLinkSignal,
    required this.sectorLiveCamUrl,
    required this.activePersonnelCount,
    required this.nextResupplyDate,
  });

  int get daysUntilResupply {
    final diff = nextResupplyDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isNominal =>
      status == 'active' && powerLevel > 40 && satLinkSignal > 80;

  Station copyWith({
    String? name,
    String? code,
    String? location,
    String? coordinates,
    String? status,
    DateTime? lastContact,
    int? powerLevel,
    double? temperature,
    double? windSpeed,
    double? satLinkSignal,
    String? sectorLiveCamUrl,
    int? activePersonnelCount,
    DateTime? nextResupplyDate,
  }) {
    return Station(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      location: location ?? this.location,
      coordinates: coordinates ?? this.coordinates,
      status: status ?? this.status,
      lastContact: lastContact ?? this.lastContact,
      powerLevel: powerLevel ?? this.powerLevel,
      temperature: temperature ?? this.temperature,
      windSpeed: windSpeed ?? this.windSpeed,
      satLinkSignal: satLinkSignal ?? this.satLinkSignal,
      sectorLiveCamUrl: sectorLiveCamUrl ?? this.sectorLiveCamUrl,
      activePersonnelCount: activePersonnelCount ?? this.activePersonnelCount,
      nextResupplyDate: nextResupplyDate ?? this.nextResupplyDate,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'location': location,
      'coordinates': coordinates,
      'status': status,
      'lastContact': lastContact.toIso8601String(),
      'powerLevel': powerLevel,
      'temperature': temperature,
      'windSpeed': windSpeed,
      'satLinkSignal': satLinkSignal,
      'sectorLiveCamUrl': sectorLiveCamUrl,
      'activePersonnelCount': activePersonnelCount,
      'nextResupplyDate': nextResupplyDate.toIso8601String(),
    };
  }

  factory Station.fromMap(String id, Map<String, dynamic> map) {
    return Station(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      location: map['location'] ?? '',
      coordinates: map['coordinates'] ?? '',
      status: map['status'] ?? 'active',
      lastContact: map['lastContact'] != null
          ? DateTime.parse(map['lastContact'])
          : DateTime.now(),
      powerLevel: map['powerLevel'] ?? 100,
      temperature: (map['temperature'] as num?)?.toDouble() ?? -25.0,
      windSpeed: (map['windSpeed'] as num?)?.toDouble() ?? 18.0,
      satLinkSignal: (map['satLinkSignal'] as num?)?.toDouble() ?? 99.0,
      sectorLiveCamUrl: map['sectorLiveCamUrl'] ?? '',
      activePersonnelCount: map['activePersonnelCount'] ?? 0,
      nextResupplyDate: map['nextResupplyDate'] != null
          ? DateTime.parse(map['nextResupplyDate'])
          : DateTime.now().add(const Duration(days: 120)),
    );
  }
}
