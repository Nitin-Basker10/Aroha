import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../models/user_role.dart';
import 'theme_toggle.dart';

/// Persistent Tactical Mission Header matching Stitch top app bar
class TacticalHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onLogout;

  const TacticalHeader({super.key, this.title = 'COLDCHAIN', this.onLogout});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final notifs = context.watch<NotificationService>();
    final colors = context.appColors;
    final user = auth.currentUser;

    final roleColor = _getRoleColor(context, user?.role);
    final roleIcon = _getRoleIcon(user?.role);
    final roleLabel = _getRoleLabel(user);
    final isFamilySession = user?.role == UserRole.familyMember;

    // Adaptive surface colors
    final headerBg = colors.canvas.withValues(alpha: 0.95);
    final chipBg = colors.surfaceHigh;
    final borderColor = colors.border;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Mission Logo / Insignia icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: context.appColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                Icons.ac_unit,
                color: context.appColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),

            // Title & Version
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AROHA',
                      style: AppTypography.headlineSm.copyWith(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: context.appColors.nominal.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        'OPS-v4.2',
                        style: AppTypography.telemetryXs.copyWith(
                          color: context.appColors.nominal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 32,
                  height: 2,
                  margin: const EdgeInsets.only(top: 2),
                  color: context.appColors.primary,
                ),
              ],
            ),

            const Spacer(),

            // Family sessions are invite-scoped: keep station telemetry and
            // operational alert controls out of their header entirely.
            if (!isFamilySession) ...[
              // SAT-LINK Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: context.appColors.nominal,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.appColors.nominal,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SAT-LINK 99.4%',
                      style: AppTypography.telemetryXs.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],

            // Active Role Indicator (read-only, no switcher)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: roleColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(roleIcon, size: 14, color: roleColor),
                  const SizedBox(width: 5),
                  Text(
                    roleLabel,
                    style: AppTypography.labelSm.copyWith(
                      color: colors.onSurface,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Light / dark theme toggle
            const ThemeToggleButton(),

            if (!isFamilySession) ...[
              const SizedBox(width: 8),

              // Notification bell with unread badge
              InkWell(
                onTap: () => _showNotifications(context),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: notifs.unreadCount > 0
                          ? context.appColors.primary.withValues(alpha: 0.6)
                          : borderColor,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 16,
                        color: colors.onSurface,
                      ),
                      if (notifs.unreadCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: context.appColors.critical,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${notifs.unreadCount}',
                              style: TextStyle(
                                color: context.appColors.onCritical,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(width: 8),

            // Logout Button
            InkWell(
              onTap: () => _confirmLogout(context),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: context.appColors.critical.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.logout,
                  size: 16,
                  color: context.appColors.critical,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final notifs = context.read<NotificationService>();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.appColors.surfaceHigh,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MISSION ALERTS (${notifs.notifications.length})',
                style: AppTypography.titleMd.copyWith(
                  letterSpacing: 1,
                  color: context.appColors.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  notifs.markAllRead();
                  Navigator.of(ctx).pop();
                },
                child: Text('MARK ALL READ'),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: notifs.notifications.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ALL SYSTEMS NOMINAL // NO NOTIFICATIONS',
                      style: AppTypography.telemetrySm.copyWith(
                        color: context.appColors.nominal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await notifs.requestPermissions();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'OS alerts enabled'
                                        : 'OS alerts unavailable — in-app feed still active',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            Icons.notifications_active_outlined,
                            size: 14,
                          ),
                          label: Text('ENABLE OS ALERTS'),
                        ),
                        const SizedBox(height: 8),
                        ...notifs.notifications.map((n) {
                          final color = context.appColors.status(
                            n.severity == 'info' ? 'routine' : n.severity,
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: n.read
                                  ? context.appColors.surfaceLow
                                  : context.appColors.surface,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: n.read
                                    ? context.appColors.border
                                    : color.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  n.severity == 'critical'
                                      ? Icons.emergency
                                      : Icons.notifications_outlined,
                                  size: 14,
                                  color: color,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: AppTypography.labelSm.copyWith(
                                          color: context.appColors.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.body,
                                        style: AppTypography.bodySm.copyWith(
                                          color: context.appColors.onSurface,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!n.read)
                                  InkWell(
                                    onTap: () {
                                      notifs.markRead(n.id);
                                      Navigator.of(ctx).pop();
                                      _showNotifications(context);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color:
                                            context.appColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.appColors.surfaceHigh,
          title: Text(
            'TERMINATE SESSION',
            style: AppTypography.titleMd.copyWith(
              letterSpacing: 1,
              color: context.appColors.onSurface,
            ),
          ),
          content: Text(
            'This will securely end your active session and return to the login terminal.',
            style: AppTypography.bodyMd.copyWith(
              color: context.appColors.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'CANCEL',
                style: AppTypography.labelSm.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                final auth = context.read<AuthService>();
                auth.logout();
                onLogout?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appColors.critical,
                foregroundColor: context.appColors.onCritical,
              ),
              child: Text(
                'END SESSION',
                style: AppTypography.labelSm.copyWith(
                  color: context.appColors.onCritical,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Color _getRoleColor(BuildContext context, UserRole? role) {
    final colors = context.appColors;
    switch (role) {
      case UserRole.hqAdmin:
        return colors.primary;
      case UserRole.stationStaff:
        return colors.warning;
      case UserRole.familyMember:
        return colors.nominal;
      case null:
        return colors.onSurfaceVariant;
    }
  }

  static IconData _getRoleIcon(UserRole? role) {
    switch (role) {
      case UserRole.hqAdmin:
        return Icons.admin_panel_settings;
      case UserRole.stationStaff:
        return Icons.cell_tower;
      case UserRole.familyMember:
        return Icons.family_restroom;
      case null:
        return Icons.person;
    }
  }

  static String _getRoleLabel(UserProfile? user) {
    if (user == null) return 'OFFLINE';
    switch (user.role) {
      case UserRole.hqAdmin:
        return 'HQ ADMIN';
      case UserRole.stationStaff:
        return user.linkedStationId?.toUpperCase() ?? 'STATION';
      case UserRole.familyMember:
        return 'FAMILY';
    }
  }
}
