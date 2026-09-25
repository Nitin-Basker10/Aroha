import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';

/// Shared light/dark control used by both the login terminal and the
/// authenticated mission header.
class ThemeToggleButton extends StatelessWidget {
  final bool showLabel;

  const ThemeToggleButton({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? colors.nominal : colors.primary;
    final tooltip = isDark ? 'Switch to light mode' : 'Switch to dark mode';

    return Semantics(
      button: true,
      toggled: isDark,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: themeProvider.toggle,
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.all(showLabel ? 7 : 6),
            decoration: BoxDecoration(
              color: colors.surfaceHigh,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 16,
                  color: accent,
                ),
                if (showLabel) ...[
                  const SizedBox(width: 5),
                  Text(
                    isDark ? 'LIGHT' : 'DARK',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
