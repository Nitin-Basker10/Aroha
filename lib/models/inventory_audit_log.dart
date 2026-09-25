/// Audit log entry for inventory mutations
class InventoryAuditLog {
  final String id;
  final String itemId;
  final String itemName;
  final String stationId;
  final String action; // 'consumption', 'create', 'update', 'delete'
  final double previousQuantity;
  final double newQuantity;
  final String performedByUserId;
  final String performedByUserName;
  final DateTime timestamp;
  final String? notes;

  const InventoryAuditLog({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.stationId,
    required this.action,
    required this.previousQuantity,
    required this.newQuantity,
    required this.performedByUserId,
    required this.performedByUserName,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'stationId': stationId,
      'action': action,
      'previousQuantity': previousQuantity,
      'newQuantity': newQuantity,
      'performedByUserId': performedByUserId,
      'performedByUserName': performedByUserName,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }

  factory InventoryAuditLog.fromMap(Map<String, dynamic> map) {
    return InventoryAuditLog(
      id: map['id'] ?? '',
      itemId: map['itemId'] ?? '',
      itemName: map['itemName'] ?? '',
      stationId: map['stationId'] ?? '',
      action: map['action'] ?? '',
      previousQuantity: (map['previousQuantity'] as num?)?.toDouble() ?? 0.0,
      newQuantity: (map['newQuantity'] as num?)?.toDouble() ?? 0.0,
      performedByUserId: map['performedByUserId'] ?? '',
      performedByUserName: map['performedByUserName'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      notes: map['notes'],
    );
  }
}
