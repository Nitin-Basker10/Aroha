/// Comms Message model matching PRD §3 `messages/{messageId}`
class CommsMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderStation;
  final String recipientId;
  final String recipientName;
  final String content;
  final String priority; // routine / urgent / emergency
  final DateTime sentAt;
  final bool read;

  /// Sender-asserted transport encryption. Defaults to **false** (unknown) so
  /// a message can never claim a protection level that was not verified.
  final bool isEncrypted;
  final String? stationId; // Station context for scoping (sender station)
  final String?
  recipientStationId; // Target station context for cross-station scoping

  const CommsMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderStation,
    required this.recipientId,
    required this.recipientName,
    required this.content,
    required this.priority,
    required this.sentAt,
    this.read = false,
    this.isEncrypted = false,
    this.stationId,
    this.recipientStationId,
  });

  CommsMessage copyWith({
    String? senderId,
    String? senderName,
    String? senderStation,
    String? recipientId,
    String? recipientName,
    String? content,
    String? priority,
    DateTime? sentAt,
    bool? read,
    bool? isEncrypted,
    String? stationId,
    String? recipientStationId,
  }) {
    return CommsMessage(
      id: id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderStation: senderStation ?? this.senderStation,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      content: content ?? this.content,
      priority: priority ?? this.priority,
      sentAt: sentAt ?? this.sentAt,
      read: read ?? this.read,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      stationId: stationId ?? this.stationId,
      recipientStationId: recipientStationId ?? this.recipientStationId,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderStation': senderStation,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'content': content,
      'priority': priority,
      'sentAt': sentAt.toIso8601String(),
      'read': read,
      'isEncrypted': isEncrypted,
      'stationId': stationId,
      'recipientStationId': recipientStationId,
    };
  }

  factory CommsMessage.fromMap(String id, Map<String, dynamic> map) {
    return CommsMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? 'Operator',
      senderStation: map['senderStation'] ?? 'Maitri',
      recipientId: map['recipientId'] ?? '',
      recipientName: map['recipientName'] ?? 'NCPOR Goa HQ',
      content: map['content'] ?? '',
      priority: map['priority'] ?? 'routine',
      sentAt: map['sentAt'] != null
          ? DateTime.parse(map['sentAt'])
          : DateTime.now(),
      read: map['read'] ?? false,
      isEncrypted: map['isEncrypted'] == true,
      stationId: map['stationId'],
      recipientStationId: map['recipientStationId'],
    );
  }
}
