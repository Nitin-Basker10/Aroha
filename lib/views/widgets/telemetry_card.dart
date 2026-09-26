import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Modular Telemetry Stat Card matching Stitch polar instrumentation
class TelemetryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? subtext;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;

  const TelemetryCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.subtext,
    this.icon,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? context.appColors.nominal;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: context.appColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: AppTypography.labelSm.copyWith(
                      color: context.appColors.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (icon != null)
                  Icon(
                    icon,
                    size: 14,
                    color: effectiveAccent.withValues(alpha: 0.7),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Flexible so a long reading + unit degrades to an ellipsis on
                // a narrow handset instead of overflowing the card.
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.telemetryLg.copyWith(
                      color: effectiveAccent,
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      unit!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.telemetrySm.copyWith(
                        color: context.appColors.onSurfaceVariant.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext!,
                style: AppTypography.telemetryXs.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
