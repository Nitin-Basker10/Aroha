/// Cargo Item subcollection model matching PRD §3 `resupplyCycles/{cycleId}/cargoItems/{cargoId}`
class CargoItem {
  final String id;
  final String cycleId;
  final String itemName;
  final String category;
  final double quantity;
  final String unit;
  final double weightKg;
  final String status; // packed / shipped / delivered / pending
  final String recipientSection;

  const CargoItem({
    required this.id,
    required this.cycleId,
    required this.itemName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.weightKg,
    required this.status,
    this.recipientSection = 'General Logistics',
  });

  CargoItem copyWith({
    String? itemName,
    String? category,
    double? quantity,
    String? unit,
    double? weightKg,
    String? status,
    String? recipientSection,
  }) {
    return CargoItem(
      id: id,
      cycleId: cycleId,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      weightKg: weightKg ?? this.weightKg,
      status: status ?? this.status,
      recipientSection: recipientSection ?? this.recipientSection,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'cycleId': cycleId,
      'itemName': itemName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'weightKg': weightKg,
      'status': status,
      'recipientSection': recipientSection,
    };
  }

  factory CargoItem.fromMap(String id, Map<String, dynamic> map) {
    return CargoItem(
      id: id,
      cycleId: map['cycleId'] ?? '',
      itemName: map['itemName'] ?? '',
      category: map['category'] ?? 'spare-parts',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: map['unit'] ?? 'units',
      weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      recipientSection: map['recipientSection'] ?? 'General Logistics',
    );
  }
}
