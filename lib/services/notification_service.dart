import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';

/// Central notification service for AROHA.
///
/// Two layers:
/// 1. In-app feed (`notifications`, `unreadCount`) — works on every
///    platform including web, drives the bell badge in [TacticalHeader].
/// 2. OS-level local notifications via `flutter_local_notifications` —
///    best-effort, fully guarded so tests / web / unsupported platforms
///    never crash (every platform call is wrapped in try/catch).
class NotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool get ready => _ready;

  final List<AppNotification> _items = [];
  List<AppNotification> get notifications => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;

  /// Initialise the OS plugin. Safe to call without await; never throws.
  Future<void> init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      const linux = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );
      const windows = WindowsInitializationSettings(
        appName: 'AROHA Polar Expedition Command',
        appUserModelId: 'NCPOR.ArohaPolar',
        guid: 'a3f1c7e2-4b5d-4e6f-8a9b-0c1d2e3f4a5b',
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
        linux: linux,
        windows: windows,
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  /// Request OS notification permissions.
  /// On web this MUST be called from a user gesture (the bell's
  /// "ENABLE ALERTS" button does exactly that).
  Future<bool> requestPermissions() async {
    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.requestNotificationsPermission();

      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final iosGranted = await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      final webImpl = _plugin
          .resolvePlatformSpecificImplementation<
            WebFlutterLocalNotificationsPlugin
          >();
      if (webImpl != null) {
        await webImpl.requestNotificationsPermission();
        return true;
      }
      return iosGranted ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Push a notification: always stored in-app, OS banner best-effort.
  /// Duplicate [id]s are ignored so Watney recalculation loops can't spam.
  Future<void> push({
    required String id,
    required String title,
    required String body,
    String severity = 'info',
    String? stationId,
  }) async {
    if (_items.any((n) => n.id == id)) return;
    _items.insert(
      0,
      AppNotification(
        id: id,
        title: title,
        body: body,
        severity: severity,
        stationId: stationId,
      ),
    );
    if (_items.length > 50) _items.removeRange(50, _items.length);
    notifyListeners();
    await _showOsNotification(id.hashCode, title, body, severity);
  }

  Future<void> _showOsNotification(
    int id,
    String title,
    String body,
    String severity,
  ) async {
    if (!_ready) return;
    try {
      Importance importance;
      switch (severity) {
        case 'critical':
          importance = Importance.max;
          break;
        case 'warning':
          importance = Importance.high;
          break;
        default:
          importance = Importance.defaultImportance;
      }
      final androidDetails = AndroidNotificationDetails(
        'aroha_$severity',
        severity == 'critical'
            ? 'AROHA Critical Alerts'
            : 'AROHA Mission Updates',
        channelDescription: 'Polar expedition alerts and dispatches',
        importance: importance,
        priority: severity == 'info' ? Priority.defaultPriority : Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails();
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (_) {
      // Headless tests / unsupported platforms: in-app feed is enough.
    }
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1 && !_items[idx].read) {
      _items[idx].read = true;
      notifyListeners();
    }
  }

  void markAllRead() {
    var changed = false;
    for (final n in _items) {
      if (!n.read) {
        n.read = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_items.isNotEmpty) {
      _items.clear();
      notifyListeners();
    }
  }
}
