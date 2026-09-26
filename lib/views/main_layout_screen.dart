import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/polar_data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/user_role.dart';
import 'widgets/tactical_header.dart';
import 'widgets/custom_nav_bar.dart';
import 'command_center/hq_command_screen.dart';
import 'station_detail/station_detail_screen.dart';
import 'inventory/inventory_screen.dart';
import 'resupply/resupply_screen.dart';
import 'personnel/personnel_screen.dart';
import 'comms/comms_hub_screen.dart';
import 'family/family_portal_screen.dart';

/// Navigation tab definition with permission gating
class _AppTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Permission requiredPermission;
  final Widget Function(Function(int)? onNavigateToTab) screenBuilder;
  final int? Function(PolarDataService data)? badgeCountBuilder;

  const _AppTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.requiredPermission,
    required this.screenBuilder,
    this.badgeCountBuilder,
  });
}

/// Master Application Scaffold with role-based tab filtering
class MainLayoutScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const MainLayoutScreen({super.key, this.onLogout});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentTabIndex = 0;

  /// IDs already seen by the notification watcher (prevents repeat alerts
  /// when Watney recalculates on every inventory mutation).
  final Set<String> _seenAlertIds = {};
  final Set<String> _seenMessageIds = {};
  final Set<String> _seenRequestIds = {};
  bool _watcherPrimed = false;

  /// Full tab registry — filtered at runtime by user permissions
  static final List<_AppTab> _allTabs = [
    _AppTab(
      label: 'HQ Command',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      requiredPermission: Permission.accessCommandCenter,
      screenBuilder: (nav) => HqCommandScreen(onNavigateToTab: nav),
    ),
    _AppTab(
      label: 'Station View',
      icon: Icons.cell_tower_outlined,
      activeIcon: Icons.cell_tower,
      requiredPermission: Permission.accessStationDetail,
      screenBuilder: (nav) => StationDetailScreen(onNavigateToTab: nav),
    ),
    _AppTab(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      requiredPermission: Permission.accessInventory,
      screenBuilder: (_) => const InventoryScreen(),
      badgeCountBuilder: (data) => data.activeCriticalAlerts.length,
    ),
    _AppTab(
      label: 'Resupply',
      icon: Icons.sailing_outlined,
      activeIcon: Icons.sailing,
      requiredPermission: Permission.accessResupply,
      screenBuilder: (_) => const ResupplyScreen(),
    ),
    _AppTab(
      label: 'Personnel',
      icon: Icons.group_outlined,
      activeIcon: Icons.group,
      requiredPermission: Permission.accessPersonnel,
      screenBuilder: (_) => const PersonnelScreen(),
    ),
    _AppTab(
      label: 'Comms',
      icon: Icons.chat_outlined,
      activeIcon: Icons.chat,
      requiredPermission: Permission.accessComms,
      screenBuilder: (_) => const CommsHubScreen(),
    ),
    _AppTab(
      label: 'Family',
      icon: Icons.family_restroom_outlined,
      activeIcon: Icons.family_restroom,
      requiredPermission: Permission.accessFamilyPortal,
      screenBuilder: (_) => const FamilyPortalScreen(),
    ),
  ];

  List<_AppTab> _getVisibleTabs(AuthService auth) {
    return _allTabs
        .where((tab) => auth.hasPermission(tab.requiredPermission))
        .toList();
  }

  void _onTabSelected(int index) {
    final auth = context.read<AuthService>();
    final visibleTabs = _getVisibleTabs(auth);
    if (index >= 0 && index < visibleTabs.length) {
      setState(() {
        _currentTabIndex = index;
      });
    }
  }

  /// Navigate to a tab by its global index (from _allTabs).
  /// Maps from the global index to the visible tab index for the current role.
  void _onGlobalTabNavigate(int globalIndex) {
    final auth = context.read<AuthService>();
    final visibleTabs = _getVisibleTabs(auth);
    final targetTab = _allTabs[globalIndex];

    // Find this tab in the visible tabs
    final visibleIndex = visibleTabs.indexWhere(
      (t) => t.requiredPermission == targetTab.requiredPermission,
    );
    if (visibleIndex != -1) {
      setState(() {
        _currentTabIndex = visibleIndex;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final data = context.read<PolarDataService>();
      data.addListener(_onDataChanged);
      _onDataChanged(); // prime seen-sets without notifying
      _watcherPrimed = true;
    });
  }

  @override
  void dispose() {
    try {
      context.read<PolarDataService>().removeListener(_onDataChanged);
    } catch (_) {}
    super.dispose();
  }

  /// Watches PolarDataService for new critical alerts, incoming messages
  /// and resource requests visible to the current user, and pushes them
  /// through NotificationService (in-app feed + OS banner).
  void _onDataChanged() {
    if (!mounted) return;
    final data = context.read<PolarDataService>();
    final auth = context.read<AuthService>();
    final notifs = context.read<NotificationService>();
    final user = auth.currentUser;
    if (user == null) return;
    // Family sessions are invite-scoped to their own call slot only —
    // never push station operations into a family session.
    if (user.role == UserRole.familyMember) return;

    // 1. Critical alerts on stations the user can access
    for (final alert in data.activeCriticalAlerts) {
      if (_seenAlertIds.contains(alert.id)) continue;
      _seenAlertIds.add(alert.id);
      if (!_watcherPrimed) continue;
      if (!user.canAccessStation(alert.stationId)) continue;
      notifs.push(
        id: alert.id,
        title:
            'CRITICAL // ${alert.stationId.toUpperCase()} ${alert.type.toUpperCase()}',
        body: alert.message,
        severity: 'critical',
        stationId: alert.stationId,
      );
      _showHeadsUp(alert.message);
    }

    // 2. Incoming messages (skip ones the user sent)
    for (final msg in data.getMessagesForUser(user)) {
      if (_seenMessageIds.contains(msg.id)) continue;
      _seenMessageIds.add(msg.id);
      if (!_watcherPrimed) continue;
      if (msg.senderId == user.uid) continue;
      notifs.push(
        id: 'msg_${msg.id}',
        title: '${msg.priority.toUpperCase()} DISPATCH // ${msg.senderName}',
        body: msg.content,
        severity: msg.priority == 'routine' ? 'info' : 'warning',
        stationId: msg.stationId,
      );
    }

    // 3. Resource requests involving the user's station (HQ sees all)
    final requests = user.role == UserRole.hqAdmin
        ? data.resourceRequests
        : data.getResourceRequestsForStation(user.linkedStationId);
    for (final req in requests) {
      if (_seenRequestIds.contains(req.id)) continue;
      _seenRequestIds.add(req.id);
      if (!_watcherPrimed) continue;
      if (req.requestedByUserId == user.uid) continue;
      notifs.push(
        id: 'req_${req.id}_${req.status}',
        title: '${req.urgency.toUpperCase()} REQUEST // ${req.requestedItem}',
        body:
            '${req.fromStationName} → ${req.toStationName}: '
            '${req.requestedQuantity.toStringAsFixed(0)} ${req.unit} (${req.status})',
        severity: req.urgency == 'routine' ? 'info' : 'warning',
        stationId: req.toStationId,
      );
    }
  }

  void _showHeadsUp(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
        backgroundColor: context.appColors.critical,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final visibleTabs = _getVisibleTabs(auth);

    // Clamp current index to visible tabs range
    if (_currentTabIndex >= visibleTabs.length) {
      _currentTabIndex = 0;
    }

    // Auto-select the station for station staff users
    if (auth.currentRole == UserRole.stationStaff &&
        auth.currentUser?.linkedStationId != null) {
      final linkedStation = auth.currentUser!.linkedStationId!;
      if (data.selectedStationId != linkedStation) {
        // Use addPostFrameCallback to avoid calling setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          data.selectStation(linkedStation, user: auth.currentUser);
        });
      }
    }

    final screens = visibleTabs
        .map((tab) => tab.screenBuilder(_onGlobalTabNavigate))
        .toList();

    return Scaffold(
      backgroundColor: context.appColors.canvas,
      appBar: TacticalHeader(onLogout: widget.onLogout),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => auth.touchSession(),
        child: IndexedStack(index: _currentTabIndex, children: screens),
      ),
      bottomNavigationBar: CustomNavBar(
        selectedIndex: _currentTabIndex,
        onTabSelected: _onTabSelected,
        tabs: visibleTabs.map((tab) {
          return NavTabItem(
            icon: tab.icon,
            activeIcon: tab.activeIcon,
            label: tab.label,
            badgeCount: tab.badgeCountBuilder?.call(data),
          );
        }).toList(),
      ),
    );
  }
}
