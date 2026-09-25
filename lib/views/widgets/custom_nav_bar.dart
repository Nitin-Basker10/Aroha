import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Data class representing a navigation tab item
class NavTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;

  const NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

/// Tactical Navigation Bar supporting dynamic role-based tabs
class CustomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;
  final List<NavTabItem> tabs;

  const CustomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.canvas.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(color: context.appColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(tabs.length, (index) {
                final item = tabs[index];
                final isSelected = selectedIndex == index;

                return InkWell(
                  onTap: () => onTabSelected(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.icon,
                              size: 20,
                              color: isSelected
                                  ? context.appColors.primary
                                  : context.appColors.onSurfaceVariant
                                        .withValues(alpha: 0.7),
                            ),
                            if (item.badgeCount != null && item.badgeCount! > 0)
                              Positioned(
                                top: -3,
                                right: -7,
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
                                    '${item.badgeCount}',
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
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: AppTypography.labelSm.copyWith(
                            fontSize: 9.5,
                            color: isSelected
                                ? context.appColors.onSurface
                                : context.appColors.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 14,
                            height: 2,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: context.appColors.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          )
                        else
                          const SizedBox(height: 4),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
