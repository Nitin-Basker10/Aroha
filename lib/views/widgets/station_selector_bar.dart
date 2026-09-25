import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/ncpor_reading.dart';
import '../../services/polar_data_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_role.dart';

/// Horizontal Station Telemetry Selector Strip matching Stitch designs
/// - HQ Admin: shows all 3 stations with full selector
/// - Station Staff: locked to assigned station only
class StationSelectorBar extends StatelessWidget {
  const StationSelectorBar({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PolarDataService>();
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final selectedId = data.selectedStationId;

    // Family sessions never see station telemetry — hard scope by role.
    if (user?.role == UserRole.familyMember) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: context.appColors.canvas,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FAMILY CALL ACCESS // PRIVATE SLOT',
              style: AppTypography.labelSm.copyWith(
                letterSpacing: 1.2,
                color: context.appColors.nominal,
              ),
            ),
            Text(
              'NO STATION DATA',
              style: AppTypography.telemetryXs.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Filter stations based on role
    final stations =
        (user != null &&
            user.role == UserRole.stationStaff &&
            user.linkedStationId != null)
        ? data.stations.where((s) => s.id == user.linkedStationId).toList()
        : data.stations;

    final isLocked = user?.role == UserRole.stationStaff;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.appColors.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isLocked ? 'YOUR STATION' : 'STATION TELEMETRY SELECT',
                style: AppTypography.labelSm.copyWith(
                  letterSpacing: 1.2,
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              Row(children: [_buildUplinkChip(context, data)]),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: stations.map((station) {
              final isSelected = station.id == selectedId;
              final statusColor = context.appColors.status(station.status);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: isLocked
                        ? null
                        : () => data.selectStation(station.id),
                    borderRadius: BorderRadius.circular(3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? context.appColors.surfaceHigh
                            : context.appColors.surfaceLow,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: isSelected
                              ? context.appColors.primary
                              : context.appColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: context.appColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                station.name.split(' ').first,
                                style: AppTypography.titleSm.copyWith(
                                  color: isSelected
                                      ? context.appColors.primary
                                      : context.appColors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            station.coordinates.split(' ').first,
                            style: AppTypography.telemetryXs.copyWith(
                              color: context.appColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${station.satLinkSignal.toStringAsFixed(1)}% SIG',
                            style: AppTypography.telemetryXs.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          // Attribution required by the NPDC data policy (Antarctic Treaty
          // §III.1.c / IPY): the data owner must be acknowledged wherever
          // the data is presented.
          Text(
            'TELEMETRY SOURCE: NATIONAL POLAR DATA CENTER (NCPOR · MoES) — data.ncpor.res.in',
            style: AppTypography.telemetryXs.copyWith(
              color: context.appColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// Honest uplink indicator: says LIVE only for fresh NPDC samples, and
  /// names the actual observation time and lag instead of a bare badge.
  Widget _buildUplinkChip(BuildContext context, PolarDataService data) {
    final status = data.selectedStationStatus;
    final reading = data.selectedStationReading;

    Color color = context.appColors.onSurfaceVariant;
    String label = '';
    String tooltip = '';

    switch (status) {
      case NporTelemetryStatus.live:
        color = context.appColors.nominal;
        label = 'NCPOR LIVE · ${reading!.observedLabel}';
        tooltip =
            'Observed ${reading.observedLabel} — ${reading.ageLabel} ago'
            '\nSource: ${reading.endpoints.join(', ')}'
            '\nCoverage: ${reading.coverageLabel}';
      case NporTelemetryStatus.stale:
        color = context.appColors.warning;
        label = 'NCPOR STALE · ${reading!.ageLabel} old';
        tooltip =
            'Newest sample ${reading.observedLabel} is older than the '
            '${NporReading.freshFor.inHours}h freshness window.'
            '\nValues are real but not current.';
      case NporTelemetryStatus.syncing:
        color = context.appColors.onSurfaceVariant;
        label = 'SYNCING NCPOR…';
        tooltip = 'Fetching live telemetry from data.ncpor.res.in';
      case NporTelemetryStatus.unavailable:
        color = context.appColors.critical;
        label = 'MOCK TELEMETRY';
        tooltip =
            'NPDC unreachable — showing seeded values, not live data.'
            '${reading?.error != null ? '\nReason: ${reading!.error}' : ''}';
      case NporTelemetryStatus.idle:
        color = context.appColors.onSurfaceVariant;
        label = 'SEED DATA';
        tooltip = 'No portal poll has completed yet.';
    }

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.telemetryXs.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
