import 'package:flutter_test/flutter_test.dart';
import 'package:aroha_polar/services/notification_service.dart';

void main() {
  group('NotificationService', () {
    test('starts empty with zero unread', () {
      final service = NotificationService();
      expect(service.notifications, isEmpty);
      expect(service.unreadCount, equals(0));
    });

    test('push stores in-app notification and increments unread', () async {
      final service = NotificationService();
      await service.push(
        id: 'alert_1',
        title: 'CRITICAL // MAITRI LOW-STOCK',
        body: 'Diesel exhausts before resupply',
        severity: 'critical',
        stationId: 'maitri',
      );
      expect(service.notifications.length, equals(1));
      expect(service.unreadCount, equals(1));
    });

    test('duplicate ids are ignored (no Watney spam)', () async {
      final service = NotificationService();
      await service.push(id: 'dup', title: 'T', body: 'B');
      await service.push(id: 'dup', title: 'T', body: 'B');
      expect(service.notifications.length, equals(1));
    });

    test('markRead and markAllRead update unread count', () async {
      final service = NotificationService();
      await service.push(id: 'a', title: 'T1', body: 'B1');
      await service.push(id: 'b', title: 'T2', body: 'B2');
      service.markRead('a');
      expect(service.unreadCount, equals(1));
      service.markAllRead();
      expect(service.unreadCount, equals(0));
    });

    test('push never throws without OS plugin init (test env)', () async {
      final service = NotificationService();
      // No init() call — _ready is false, OS layer skipped.
      await service.push(id: 'x', title: 'T', body: 'B');
      expect(service.notifications.length, equals(1));
    });
  });
}
