import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../widgets/station_selector_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_card.dart';

/// Stitch Screen: HQ Command Center
class HqCommandScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const HqCommandScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final stations = data.stations;
    final criticalAlerts = data.activeCriticalAlerts;
    final warningAlerts = data.activeWarningAlerts;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Station Selector Strip
          const StationSelectorBar(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Global Telemetry Grid
                Row(
                  children: [
                    Expanded(
                      child: TelemetryCard(
                        label: 'Active Outposts',
                        value: '${stations.length}',
                        unit: 'STATIONS',
                        subtext: '3/3 Reporting Live',
                        icon: Icons.public,
                        accentColor: context.appColors.nominal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Total Expedition Crew',
                        value:
                            '${data.personnel.where((p) => p.status == 'on-station').length}',
                        unit: 'ON-STATION',
                        subtext: 'Wintering Roster',
                        icon: Icons.badge_outlined,
                        accentColor: context.appColors.onSurface,
                        onTap: () => onNavigateToTab?.call(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Active System Alerts',
                        value:
                            '${criticalAlerts.length + warningAlerts.length}',
                        unit: 'ALERTS',
                        subtext: '${criticalAlerts.length} Critical Risk',
                        icon: Icons.warning_amber_rounded,
                        accentColor: criticalAlerts.isNotEmpty
                            ? context.appColors.critical
                            : context.appColors.warning,
                        onTap: () => onNavigateToTab?.call(2),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Sector Live Visual Feed Panels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'SECTOR VISUAL FEEDS // OPTICAL CAM',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          letterSpacing: 1.2,
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE DOWNLINK',
                      style: AppTypography.telemetryXs.copyWith(
                        color: context.appColors.nominal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    Expanded(
                      child: _buildSectorCamCard(
                        context: context,
                        sectorName: 'Schirmacher Oasis (Maitri)',
                        camLabel: 'CAM-01 LIVE // THERMAL',
                        status: 'Nominal',
                        statusColor: context.appColors.nominal,
                        imageUrl: stations[0].sectorLiveCamUrl,
                        onTap: () {
                          data.selectStation('maitri', user: auth.currentUser);
                          onNavigateToTab?.call(1);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSectorCamCard(
                        context: context,
                        sectorName: 'Larsemann Hills (Bharati)',
                        camLabel: 'CAM-02 LIVE // RADOME',
                        status: 'Nominal',
                        statusColor: context.appColors.nominal,
                        imageUrl: stations[1].sectorLiveCamUrl,
                        onTap: () {
                          data.selectStation('bharati', user: auth.currentUser);
                          onNavigateToTab?.call(1);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Outpost Diagnostics Cards Matrix
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'FIELD OUTPOST DIAGNOSTICS & TELEMETRY',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          letterSpacing: 1.2,
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${stations.length}/${stations.length} SYNCED',
                      style: AppTypography.telemetryXs.copyWith(
                        color: context.appColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Station Cards
                ...stations.map((station) {
                  final isSelected = station.id == data.selectedStationId;
                  final stationInventory = data.inventory
                      .where((i) => i.stationId == station.id)
                      .toList();
                  final atRiskItems = stationInventory
                      .where((i) => i.isAtRisk(station.daysUntilResupply))
                      .toList();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.appColors.surfaceHigh
                          : context.appColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? context.appColors.primary
                            : context.appColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${station.code} // ${station.location.split(',').last.trim().toUpperCase()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.telemetryXs.copyWith(
                                      color: context.appColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    station.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.titleMd.copyWith(
                                      color: context.appColors.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(status: station.status),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Metrics Grid
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: context.appColors.divider,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildMiniMetric(
                                context,
                                'RESUPPLY WINDOW',
                                '${station.daysUntilResupply}d',
                                context.appColors.primary,
                              ),
                              _buildMiniMetric(
                                context,
                                'POWER GENERATION',
                                '${station.powerLevel}%',
                                station.powerLevel > 60
                                    ? context.appColors.nominal
                                    : context.appColors.warning,
                              ),
                              _buildMiniMetric(
                                context,
                                'EXTERIOR TEMP',
                                '${station.temperature.toStringAsFixed(1)}°C',
                                context.appColors.nominal,
                              ),
                              _buildMiniMetric(
                                context,
                                'WIND SPEED',
                                '${station.windSpeed.toStringAsFixed(1)} kt',
                                station.windSpeed > 30
                                    ? context.appColors.warning
                                    : context.appColors.onSurface,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // At-Risk Stock Warning bar if any
                        if (atRiskItems.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: context.appColors.errorContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: context.appColors.critical.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 14,
                                  color: context.appColors.critical,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${atRiskItems.length} inventory items projected to exhaust before next resupply (${atRiskItems.map((e) => e.name.split(' ').first).join(', ')})',
                                    style: AppTypography.telemetryXs.copyWith(
                                      color: context.appColors.critical,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    data.selectStation(
                                      station.id,
                                      user: auth.currentUser,
                                    );
                                    onNavigateToTab?.call(
                                      2,
                                    ); // Jump to inventory
                                  },
                                  child: Text(
                                    'VIEW RISK >',
                                    style: AppTypography.labelSm.copyWith(
                                      color: context.appColors.primary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Action Buttons
                        //
                        // Wrap, not Row: at 412px the two full-width labels do
                        // not fit side by side, and a Row would clip them.
                        // Wrap drops the second button onto its own line
                        // instead of overflowing.
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                data.selectStation(
                                  station.id,
                                  user: auth.currentUser,
                                );
                                onNavigateToTab?.call(2);
                              },
                              icon: Icon(Icons.inventory_2_outlined, size: 13),
                              label: Text('INVENTORY LOGISTICS'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                textStyle: AppTypography.labelSm,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                data.selectStation(
                                  station.id,
                                  user: auth.currentUser,
                                );
                                onNavigateToTab?.call(
                                  1,
                                ); // Jump to station detail
                              },
                              icon: Icon(Icons.cell_tower, size: 13),
                              label: Text('OPEN STATION TELEMETRY'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                textStyle: AppTypography.labelSm,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 14),

                // Active Mission Alert Matrix
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'ACTIVE EXPEDITION ALERTS & ANOMALIES',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSm.copyWith(
                          letterSpacing: 1.2,
                          color: context.appColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${data.alerts.where((a) => !a.resolved).length} UNRESOLVED',
                      style: AppTypography.telemetryXs.copyWith(
                        color: context.appColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (data.alerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Center(
                      child: Text(
                        'ALL SYSTEMS NOMINAL // NO ACTIVE ALERTS',
                        style: AppTypography.telemetrySm.copyWith(
                          color: context.appColors.nominal,
                        ),
                      ),
                    ),
                  )
                else
                  ...data.alerts.take(5).map((alert) {
                    final isCritical = alert.severity == 'critical';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCritical
                            ? context.appColors.errorContainer.withValues(
                                alpha: 0.25,
                              )
                            : context.appColors.surface,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isCritical
                              ? context.appColors.critical.withValues(
                                  alpha: 0.6,
                                )
                              : context.appColors.warning.withValues(
                                  alpha: 0.4,
                                ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isCritical
                                ? Icons.emergency
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: isCritical
                                ? context.appColors.critical
                                : context.appColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${alert.stationId.toUpperCase()} // ${alert.type.toUpperCase()}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.telemetryXs
                                            .copyWith(
                                              color: isCritical
                                                  ? context.appColors.critical
                                                  : context.appColors.warning,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${DateTime.now().difference(alert.createdAt).inMinutes}m ago',
                                      style: AppTypography.telemetryXs.copyWith(
                                        color:
                                            context.appColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  alert.message,
                                  style: AppTypography.bodySm.copyWith(
                                    color: context.appColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.check,
                              size: 14,
                              color: context.appColors.onSurfaceVariant,
                            ),
                            tooltip: 'Acknowledge Alert',
                            onPressed: () => data.resolveAlert(
                              alert.id,
                              user: auth.currentUser,
                            ),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectorCamCard({
    required BuildContext context,
    required String sectorName,
    required String camLabel,
    required String status,
    required Color statusColor,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: context.appColors.surfaceLow,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: context.appColors.border),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
            onError: (Object _, StackTrace? _) {},
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      camLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.telemetryXs.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sectorName,
                    style: AppTypography.labelMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'TAP TO INSPECT SECTOR >',
                    style: AppTypography.telemetryXs.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.telemetryXs.copyWith(
              fontSize: 8.5,
              color: context.appColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.telemetryMd.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
