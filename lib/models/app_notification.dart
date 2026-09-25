/// In-app notification record (mirrors an OS-level local notification).
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String severity; // critical / warning / info
  final String? stationId;
  final DateTime createdAt;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    this.stationId,
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();
}
