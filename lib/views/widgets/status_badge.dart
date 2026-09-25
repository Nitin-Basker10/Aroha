import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Compact status chip with 6px circular indicator matching Stitch specs
class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;
  final bool isPill;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
    this.isPill = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.status(status);
    final label = customLabel ?? status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: context.appColors.surfaceLow,
        borderRadius: BorderRadius.circular(isPill ? 12 : 2),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
