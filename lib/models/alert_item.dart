/// Alert Item model matching PRD §3 `alerts/{alertId}` (top-level collection)
class AlertItem {
  final String id;
  final String stationId;
  final String
  type; // low-stock / emergency / communication-loss / delayed-resupply / system-fault
  final String severity; // info / warning / critical
  final String message;
  final DateTime createdAt;
  final bool resolved;
  final String? itemId;

  const AlertItem({
    required this.id,
    required this.stationId,
    required this.type,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.resolved = false,
    this.itemId,
  });

  AlertItem copyWith({
    String? stationId,
    String? type,
    String? severity,
    String? message,
    DateTime? createdAt,
    bool? resolved,
    String? itemId,
  }) {
    return AlertItem(
      id: id,
      stationId: stationId ?? this.stationId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      resolved: resolved ?? this.resolved,
      itemId: itemId ?? this.itemId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'stationId': stationId,
      'type': type,
      'severity': severity,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'resolved': resolved,
      'itemId': itemId,
    };
  }

  factory AlertItem.fromMap(String id, Map<String, dynamic> map) {
    return AlertItem(
      id: id,
      stationId: map['stationId'] ?? '',
      type: map['type'] ?? 'low-stock',
      severity: map['severity'] ?? 'warning',
      message: map['message'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      resolved: map['resolved'] ?? false,
      itemId: map['itemId'],
    );
  }
}
