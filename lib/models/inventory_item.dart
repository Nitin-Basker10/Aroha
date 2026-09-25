/// Inventory Item model matching PRD §3 `stations/{stationId}/inventory/{itemId}`
class InventoryItem {
  final String id;
  final String stationId;
  final String name;
  final String category; // food / fuel / medical / spare-parts / equipment
  final double currentQuantity;
  final String unit; // liters, kg, units, kits, cylinders
  final double dailyConsumptionRate;
  final double reorderThreshold;
  final DateTime lastUpdated;
  final String storageLocation;
  final String notes;

  const InventoryItem({
    required this.id,
    required this.stationId,
    required this.name,
    required this.category,
    required this.currentQuantity,
    required this.unit,
    required this.dailyConsumptionRate,
    required this.reorderThreshold,
    required this.lastUpdated,
    this.storageLocation = 'Main Depot',
    this.notes = '',
  });

  /// The core "Mark Watney" calculation:
  /// daysRemaining = currentQuantity / dailyConsumptionRate
  double get daysRemaining {
    if (dailyConsumptionRate <= 0 ||
        dailyConsumptionRate.isNaN ||
        dailyConsumptionRate.isInfinite) {
      return 999.0;
    }
    if (currentQuantity <= 0 ||
        currentQuantity.isNaN ||
        currentQuantity.isInfinite) {
      return 0.0;
    }
    final res = currentQuantity / dailyConsumptionRate;
    return (res.isNaN || res.isInfinite) ? 999.0 : res;
  }

  /// Calculates risk relative to days until next resupply
  bool isAtRisk(int daysUntilResupply) {
    return daysRemaining < daysUntilResupply ||
        currentQuantity <= reorderThreshold;
  }

  bool isCritical(int daysUntilResupply) {
    return daysRemaining < (daysUntilResupply * 0.5) ||
        currentQuantity <= (reorderThreshold * 0.5);
  }

  InventoryItem copyWith({
    String? name,
    String? category,
    double? currentQuantity,
    String? unit,
    double? dailyConsumptionRate,
    double? reorderThreshold,
    DateTime? lastUpdated,
    String? storageLocation,
    String? notes,
  }) {
    return InventoryItem(
      id: id,
      stationId: stationId,
      name: name ?? this.name,
      category: category ?? this.category,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      unit: unit ?? this.unit,
      dailyConsumptionRate: dailyConsumptionRate ?? this.dailyConsumptionRate,
      reorderThreshold: reorderThreshold ?? this.reorderThreshold,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      storageLocation: storageLocation ?? this.storageLocation,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stationId': stationId,
      'name': name,
      'category': category,
      'currentQuantity': currentQuantity,
      'unit': unit,
      'dailyConsumptionRate': dailyConsumptionRate,
      'reorderThreshold': reorderThreshold,
      'lastUpdated': lastUpdated.toIso8601String(),
      'storageLocation': storageLocation,
      'notes': notes,
    };
  }

  factory InventoryItem.fromMap(String id, Map<String, dynamic> map) {
    return InventoryItem(
      id: id,
      stationId: map['stationId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? 'spare-parts',
      currentQuantity: (map['currentQuantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] ?? 'units',
      dailyConsumptionRate:
          (map['dailyConsumptionRate'] as num?)?.toDouble() ?? 1.0,
      reorderThreshold: (map['reorderThreshold'] as num?)?.toDouble() ?? 10.0,
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'])
          : DateTime.now(),
      storageLocation: map['storageLocation'] ?? 'Main Depot',
      notes: map['notes'] ?? '',
    );
  }
}
