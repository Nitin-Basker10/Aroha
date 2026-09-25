import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Tactical Avatar Widget with offline fallback for polar satellite links
class TacticalAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;

  const TacticalAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 20,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'OP';
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.appColors.surfaceHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.appColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: AppTypography.labelSm.copyWith(
            color: context.appColors.onSurface,
            fontSize: radius * 0.7,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: size,
            height: size,
            color: context.appColors.surfaceHigh,
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.appColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
