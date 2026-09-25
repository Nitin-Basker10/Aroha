import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../widgets/station_selector_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_card.dart';

/// Stitch Screen: Station Detail (Maitri / Bharati / Himadri)
class StationDetailScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const StationDetailScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final station = data.selectedStation;
    final personnel = data.selectedStationPersonnel;
    final alerts = data.selectedStationAlerts
        .where((a) => !a.resolved)
        .toList();
    final reading = data.selectedStationReading;

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
                // Station Hero Banner & Live Feed
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceLow,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.appColors.border),
                    image: DecorationImage(
                      image: NetworkImage(station.sectorLiveCamUrl),
                      fit: BoxFit.cover,
                      onError: (Object _, StackTrace? _) {},
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.appColors.surfaceLowest
                                    .withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: context.appColors.nominal.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.videocam,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${station.code} CAM-01 // OPTICAL LIVE',
                                    style: AppTypography.telemetryXs.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: station.status),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.name.toUpperCase(),
                              style: AppTypography.headlineSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'COORDINATES: ${station.coordinates}',
                              style: AppTypography.telemetryXs.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'LOCATION: ${station.location}',
                              style: AppTypography.telemetryXs.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Environmental & Power Telemetry Grid
                Row(
                  children: [
                    Expanded(
                      child: TelemetryCard(
                        label: 'Core Power',
                        value: '${station.powerLevel}',
                        unit: '%',
                        subtext: 'Cummins Diesel #1 Active',
                        icon: Icons.bolt,
                        accentColor: station.powerLevel > 60
                            ? context.appColors.nominal
                            : context.appColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Ambient Temp',
                        value: station.temperature.toStringAsFixed(1),
                        unit: '°C',
                        // Derived from the fetched window — never a typed-in
                        // figure. Null hides the line rather than inventing it.
                        subtext: reading?.temperatureMinC != null
                            ? '24h low ${reading!.temperatureMinC!.toStringAsFixed(1)}°C'
                            : null,
                        icon: Icons.thermostat,
                        accentColor: context.appColors.nominal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TelemetryCard(
                        label: 'Wind Vector',
                        value: station.windSpeed.toStringAsFixed(1),
                        unit: 'KTS',
                        subtext: reading?.windMaxKnots != null
                            ? 'Gust ${reading!.windMaxKnots!.toStringAsFixed(0)} kt'
                            : null,
                        icon: Icons.air,
                        accentColor: station.windSpeed > 30
                            ? context.appColors.warning
                            : context.appColors.onSurface,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Life-Support Subsystem Diagnostics
                Text(
                  'LIFE-SUPPORT & UTILITY POD STATUS',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.2,
                    color: context.appColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.appColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.appColors.border),
                  ),
                  child: Column(
                    children: [
                      _buildSubsystemRow(
                        context: context,
                        title: 'Atmospheric Heating (HVAC Thermal Loop)',
                        statusText: 'NOMINAL // +19.5°C INTERIOR',
                        status: 'nominal',
                        icon: Icons.heat_pump_outlined,
                      ),
                      Divider(color: context.appColors.divider, height: 16),
                      _buildSubsystemRow(
                        context: context,
                        title: 'Reverse Osmosis Water Desalination / Melter',
                        statusText: '3,800 L/DAY // RESERVE 82%',
                        status: 'nominal',
                        icon: Icons.water_drop_outlined,
                      ),
                      Divider(color: context.appColors.divider, height: 16),
                      _buildSubsystemRow(
                        context: context,
                        title: 'Emergency Medical Oxygen Manifold',
                        statusText: '8 CYLINDERS // AT REORDER THRESHOLD',
                        status: 'warning',
                        icon: Icons.medical_services_outlined,
                      ),
                      Divider(color: context.appColors.divider, height: 16),
                      _buildSubsystemRow(
                        context: context,
                        title: 'Primary Inmarsat / VSAT Radome Feed',
                        statusText: 'SIGNAL 99.4% // DUPLEX SYNCHRONIZED',
                        status: 'nominal',
                        icon: Icons.satellite_alt,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Station Local Alerts (if any)
                if (alerts.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LOCAL OUTPOST ANOMALIES (${alerts.length})',
                        style: AppTypography.labelSm.copyWith(
                          letterSpacing: 1.2,
                          color: context.appColors.critical,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...alerts.map((alert) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.appColors.errorContainer.withValues(
                          alpha: 0.25,
                        ),
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
                            Icons.warning_amber,
                            size: 16,
                            color: context.appColors.critical,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alert.message,
                              style: AppTypography.telemetryXs.copyWith(
                                color: context.appColors.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.check,
                              size: 14,
                              color: context.appColors.onSurfaceVariant,
                            ),
                            tooltip: 'Acknowledge Alert',
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            onPressed: () => data.resolveAlert(
                              alert.id,
                              user: auth.currentUser,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                ],

                // Station Wintering Personnel Preview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'WINTERING EXPEDITION CREW (${personnel.length})',
                      style: AppTypography.labelSm.copyWith(
                        letterSpacing: 1.2,
                        color: context.appColors.onSurfaceVariant,
                      ),
                    ),
                    InkWell(
                      onTap: () => onNavigateToTab?.call(4),
                      child: Text(
                        'MANAGE ROSTER >',
                        style: AppTypography.labelSm.copyWith(
                          color: context.appColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ...personnel.map((person) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: context.appColors.border),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(person.avatarUrl),
                          onBackgroundImageError: (Object _, StackTrace? _) {},
                          backgroundColor: context.appColors.surfaceHigh,
                          child: Icon(
                            Icons.person,
                            size: 14,
                            color: context.appColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person.name,
                                style: AppTypography.titleSm.copyWith(
                                  color: context.appColors.onSurface,
                                ),
                              ),
                              Text(
                                '${person.role.toUpperCase()} // ${person.specialization}',
                                style: AppTypography.telemetryXs.copyWith(
                                  color: context.appColors.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(status: person.status, isPill: true),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Tactical Operational Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onNavigateToTab?.call(2), // Inventory
                        icon: Icon(Icons.analytics_outlined, size: 14),
                        label: Text('LOG CONSUMPTION'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => onNavigateToTab?.call(5), // Comms
                        icon: Icon(Icons.send, size: 14),
                        label: Text('DISPATCH COMMS'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsystemRow({
    required BuildContext context,
    required String title,
    required String statusText,
    required String status,
    required IconData icon,
  }) {
    final color = context.appColors.status(status);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMd.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
              Text(
                statusText,
                style: AppTypography.telemetryXs.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }
}
