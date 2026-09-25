/// Cross-station resource request model for inter-station goods sharing
/// When a station has a shortage, they can request supplies from another station
class ResourceRequest {
  final String id;
  final String fromStationId;
  final String fromStationName;
  final String toStationId;
  final String toStationName;
  final String requestedItem;
  final double requestedQuantity;
  final String unit;
  final String urgency; // routine / urgent / emergency
  final String status; // pending / approved / denied / fulfilled
  final String requestedByUserId;
  final String requestedByName;
  final DateTime createdAt;
  final String? responseNotes;
  final String? respondedByName;
  final DateTime? respondedAt;

  const ResourceRequest({
    required this.id,
    required this.fromStationId,
    required this.fromStationName,
    required this.toStationId,
    required this.toStationName,
    required this.requestedItem,
    required this.requestedQuantity,
    required this.unit,
    required this.urgency,
    required this.status,
    required this.requestedByUserId,
    required this.requestedByName,
    required this.createdAt,
    this.responseNotes,
    this.respondedByName,
    this.respondedAt,
  });

  ResourceRequest copyWith({
    String? status,
    String? responseNotes,
    String? respondedByName,
    DateTime? respondedAt,
  }) {
    return ResourceRequest(
      id: id,
      fromStationId: fromStationId,
      fromStationName: fromStationName,
      toStationId: toStationId,
      toStationName: toStationName,
      requestedItem: requestedItem,
      requestedQuantity: requestedQuantity,
      unit: unit,
      urgency: urgency,
      status: status ?? this.status,
      requestedByUserId: requestedByUserId,
      requestedByName: requestedByName,
      createdAt: createdAt,
      responseNotes: responseNotes ?? this.responseNotes,
      respondedByName: respondedByName ?? this.respondedByName,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  Map<String, dynamic> toFirestore() {
    return {
      'fromStationId': fromStationId,
      'fromStationName': fromStationName,
      'toStationId': toStationId,
      'toStationName': toStationName,
      'requestedItem': requestedItem,
      'requestedQuantity': requestedQuantity,
      'unit': unit,
      'urgency': urgency,
      'status': status,
      'requestedByUserId': requestedByUserId,
      'requestedByName': requestedByName,
      'createdAt': createdAt.toIso8601String(),
      'responseNotes': responseNotes,
      'respondedByName': respondedByName,
      'respondedAt': respondedAt?.toIso8601String(),
    };
  }

  factory ResourceRequest.fromMap(String id, Map<String, dynamic> map) {
    return ResourceRequest(
      id: id,
      fromStationId: map['fromStationId'] ?? '',
      fromStationName: map['fromStationName'] ?? '',
      toStationId: map['toStationId'] ?? '',
      toStationName: map['toStationName'] ?? '',
      requestedItem: map['requestedItem'] ?? '',
      requestedQuantity: (map['requestedQuantity'] as num?)?.toDouble() ?? 0,
      unit: map['unit'] ?? 'units',
      urgency: map['urgency'] ?? 'routine',
      status: map['status'] ?? 'pending',
      requestedByUserId: map['requestedByUserId'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      responseNotes: map['responseNotes'],
      respondedByName: map['respondedByName'],
      respondedAt: map['respondedAt'] != null
          ? DateTime.parse(map['respondedAt'])
          : null,
    );
  }
}
