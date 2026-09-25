import 'cargo_item.dart';

/// Resupply Cycle model matching PRD §3 `resupplyCycles/{cycleId}`
class ResupplyCycle {
  final String id;
  final String stationId;
  final String vesselName;
  final String
  expeditionCode; // e.g. "44-ISEA (Indian Scientific Expedition to Antarctica)"
  final DateTime departureDate;
  final DateTime scheduledDate; // ETA at station
  final String status; // planned / in-transit / delivered / delayed
  final String departurePort;
  final List<CargoItem> cargoItems;

  const ResupplyCycle({
    required this.id,
    required this.stationId,
    required this.vesselName,
    required this.expeditionCode,
    required this.departureDate,
    required this.scheduledDate,
    required this.status,
    required this.departurePort,
    this.cargoItems = const [],
  });

  int get daysUntilArrival {
    final diff = scheduledDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  double get totalPayloadWeightKg {
    return cargoItems.fold(0.0, (acc, item) => acc + item.weightKg);
  }

  int get packedItemsCount {
    return cargoItems
        .where(
          (i) =>
              i.status == 'packed' ||
              i.status == 'shipped' ||
              i.status == 'delivered',
        )
        .length;
  }

  ResupplyCycle copyWith({
    String? stationId,
    String? vesselName,
    String? expeditionCode,
    DateTime? departureDate,
    DateTime? scheduledDate,
    String? status,
    String? departurePort,
    List<CargoItem>? cargoItems,
  }) {
    return ResupplyCycle(
      id: id,
      stationId: stationId ?? this.stationId,
      vesselName: vesselName ?? this.vesselName,
      expeditionCode: expeditionCode ?? this.expeditionCode,
      departureDate: departureDate ?? this.departureDate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      departurePort: departurePort ?? this.departurePort,
      cargoItems: cargoItems ?? this.cargoItems,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stationId': stationId,
      'vesselName': vesselName,
      'expeditionCode': expeditionCode,
      'departureDate': departureDate.toIso8601String(),
      'scheduledDate': scheduledDate.toIso8601String(),
      'status': status,
      'departurePort': departurePort,
    };
  }

  factory ResupplyCycle.fromMap(
    String id,
    Map<String, dynamic> map, [
    List<CargoItem> cargo = const [],
  ]) {
    return ResupplyCycle(
      id: id,
      stationId: map['stationId'] ?? '',
      vesselName: map['vesselName'] ?? 'MV Vasiliy Golovnin',
      expeditionCode: map['expeditionCode'] ?? '44-ISEA',
      departureDate: map['departureDate'] != null
          ? DateTime.parse(map['departureDate'])
          : DateTime.now(),
      scheduledDate: map['scheduledDate'] != null
          ? DateTime.parse(map['scheduledDate'])
          : DateTime.now().add(const Duration(days: 90)),
      status: map['status'] ?? 'planned',
      departurePort: map['departurePort'] ?? 'Cape Town, South Africa',
      cargoItems: cargo,
    );
  }
}
