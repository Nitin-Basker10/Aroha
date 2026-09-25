import 'package:flutter/material.dart';

/// Stitch Coldchain Design Tokens for Antarctic Mission Command UI.
///
/// The constants in [AppColors] are the source palette. UI code should use
/// [AppThemeColors] through `context.appColors` so a widget can adapt to the
/// active light or dark theme without duplicating brightness checks.
class AppColors {
  AppColors._();

  // Base background & surfaces
  static const Color glacierInk = Color(0xFF09151C); // #09151c - Ground base
  static const Color packIce = Color(0xFF152128); // #152128 - Surface container
  static const Color packIceLow = Color(
    0xFF111D24,
  ); // #111d24 - Surface container low
  static const Color packIceHigh = Color(
    0xFF202B33,
  ); // #202b33 - Surface container high
  static const Color packIceHighest = Color(
    0xFF2A363E,
  ); // #2a363e - Surface variant / border elevated
  static const Color surfaceLowest = Color(
    0xFF041016,
  ); // #041016 - Deep recessed panel
  static const Color surfaceBright = Color(0xFF2F3B42); // #2f3b42

  // Brand & Action Accents
  static const Color expeditionOrange = Color(
    0xFFF1642F,
  ); // #f1642f - Primary container
  static const Color expeditionOrangeDark = Color(
    0xFFD9531E,
  ); // #d9531e - Primary trigger
  static const Color primaryFixed = Color(0xFFFFDBCF); // #ffdbcf
  static const Color primaryFixedDim = Color(0xFFFFB59C); // #ffb59c
  static const Color onPrimary = Color(0xFF5C1900); // #5c1900
  static const Color onPrimaryContainer = Color(0xFF511500);

  // Telemetry & Nominal Accents (Meltwater Teal)
  static const Color meltwaterTeal = Color(
    0xFF5FA8A0,
  ); // Nominal operational indicator
  static const Color meltwaterTealLight = Color(0xFF8AD4CB); // Secondary
  static const Color secondaryContainer = Color(0xFF005D57); // #005d57
  static const Color onSecondaryContainer = Color(0xFF8AD3CB);

  // Warning & Anomaly Accents (Ochre Warning)
  static const Color ochreWarning = Color(0xFFC98A2C); // Sub-threshold warning
  static const Color ochreWarningLight = Color(
    0xFFFFB958,
  ); // Tertiary fixed dim
  static const Color tertiaryContainer = Color(0xFFC28426);
  static const Color onTertiary = Color(0xFF462B00);

  // Alarm & Critical Accents (Brick Red)
  static const Color brickRed = Color(0xFFB23A2E); // Critical emergency
  static const Color brickRedLight = Color(0xFFFFB4AB); // Error text
  static const Color errorContainer = Color(0xFF93000A); // #93000a
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Typography & Lines
  static const Color snowfield = Color(
    0xFFEDEFEA,
  ); // Off-white high legibility text
  static const Color onSurface = Color(0xFFD7E4EE); // Primary text
  static const Color onSurfaceVariant = Color(
    0xFFE1BFB5,
  ); // Muted secondary text
  static const Color outline = Color(0xFFA88A81); // #a88a81
  static const Color outlineVariant = Color(0xFF594139); // #594139
  static const Color structuralBorder = Color(0x1FEDEFEA); // 12% opacity border
  static const Color subtleDivider = Color(0x0FEDEFEA); // 6% opacity divider

  // ── Light-mode source primitives ────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F6F1);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLow = Color(0xFFECEEEB);
  static const Color lightSurfaceHigh = Color(0xFFE2E5DF);
  static const Color lightSurfaceHighest = Color(0xFFD8DBD6);
  static const Color lightOnSurface = Color(0xFF1A2420);
  static const Color lightOnSurfaceVariant = Color(0xFF4B5B57);
  static const Color lightSnowfield = Color(0xFF1A2420);
  static const Color lightStructuralBorder = Color(0x26000000);
  static const Color lightSubtleDivider = Color(0x12000000);

  /// Legacy dark-palette status lookup retained for compatibility.
  /// New UI must use `context.appColors.status(status)` instead.
  @Deprecated('Use AppThemeColors.status through context.appColors')
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'nominal':
      case 'synced':
      case 'on-station':
      case 'delivered':
      case 'routine':
        return meltwaterTealLight;
      case 'warning':
      case 'delayed':
      case 'in-transit':
      case 'planned':
      case 'urgent':
      case 'low-connectivity':
        return ochreWarningLight;
      case 'critical':
      case 'emergency':
      case 'alarm':
      case 'departed':
      case 'at-risk':
        return brickRedLight;
      default:
        return onSurfaceVariant;
    }
  }
}

/// Semantic colors exposed through [ThemeData.extensions].
///
/// Keeping these roles separate from the raw brand constants makes it
/// possible to preserve the expedition palette while ensuring every surface,
/// label, border, and status indicator has suitable contrast in both modes.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.canvas,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.surfaceLowest,
    required this.surfaceBright,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.border,
    required this.divider,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.nominal,
    required this.onNominal,
    required this.nominalContainer,
    required this.onNominalContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.critical,
    required this.onCritical,
    required this.criticalContainer,
    required this.onCriticalContainer,
    required this.inputFill,
  });

  static const AppThemeColors dark = AppThemeColors(
    canvas: AppColors.glacierInk,
    surface: AppColors.packIce,
    surfaceLow: AppColors.packIceLow,
    surfaceHigh: AppColors.packIceHigh,
    surfaceHighest: AppColors.packIceHighest,
    surfaceLowest: AppColors.surfaceLowest,
    surfaceBright: AppColors.surfaceBright,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    border: AppColors.structuralBorder,
    divider: AppColors.subtleDivider,
    primary: AppColors.expeditionOrange,
    onPrimary: AppColors.glacierInk,
    primaryContainer: AppColors.expeditionOrangeDark,
    onPrimaryContainer: AppColors.glacierInk,
    secondary: AppColors.meltwaterTeal,
    onSecondary: AppColors.glacierInk,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.ochreWarning,
    onTertiary: AppColors.glacierInk,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.glacierInk,
    error: AppColors.brickRed,
    onError: Colors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    nominal: AppColors.meltwaterTealLight,
    onNominal: AppColors.glacierInk,
    nominalContainer: Color(0xFF173D3A),
    onNominalContainer: AppColors.snowfield,
    warning: AppColors.ochreWarningLight,
    onWarning: AppColors.glacierInk,
    warningContainer: Color(0xFF4A3510),
    onWarningContainer: AppColors.snowfield,
    critical: AppColors.brickRedLight,
    onCritical: AppColors.glacierInk,
    criticalContainer: AppColors.errorContainer,
    onCriticalContainer: AppColors.onErrorContainer,
    inputFill: AppColors.glacierInk,
  );

  static const AppThemeColors light = AppThemeColors(
    canvas: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    surfaceLow: AppColors.lightSurfaceLow,
    surfaceHigh: AppColors.lightSurfaceHigh,
    surfaceHighest: AppColors.lightSurfaceHighest,
    surfaceLowest: Color(0xFFF0F2EE),
    surfaceBright: AppColors.lightSurface,
    onSurface: AppColors.lightOnSurface,
    onSurfaceVariant: AppColors.lightOnSurfaceVariant,
    outline: AppColors.lightOnSurfaceVariant,
    border: AppColors.lightStructuralBorder,
    divider: AppColors.lightSubtleDivider,
    primary: Color(0xFFB84618),
    onPrimary: Colors.white,
    primaryContainer: AppColors.expeditionOrange,
    onPrimaryContainer: Color(0xFF3B1307),
    secondary: Color(0xFF2F7772),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFB2E8E2),
    onSecondaryContainer: Color(0xFF003733),
    tertiary: Color(0xFF8A5A00),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFDEA0),
    onTertiaryContainer: Color(0xFF462B00),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF690005),
    nominal: Color(0xFF2F7772),
    onNominal: Colors.white,
    nominalContainer: Color(0xFFD4EFEB),
    onNominalContainer: Color(0xFF003733),
    warning: Color(0xFF8A5A00),
    onWarning: Colors.white,
    warningContainer: Color(0xFFFFF0C2),
    onWarningContainer: Color(0xFF3F2A00),
    critical: Color(0xFFB3261E),
    onCritical: Colors.white,
    criticalContainer: Color(0xFFFFDAD6),
    onCriticalContainer: Color(0xFF690005),
    inputFill: AppColors.lightSurfaceLow,
  );

  final Color canvas;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color surfaceLowest;
  final Color surfaceBright;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outline;
  final Color border;
  final Color divider;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color nominal;
  final Color onNominal;
  final Color nominalContainer;
  final Color onNominalContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color critical;
  final Color onCritical;
  final Color criticalContainer;
  final Color onCriticalContainer;
  final Color inputFill;

  /// Returns a contrast-safe status color for the active theme.
  Color status(String value) {
    switch (value.toLowerCase()) {
      case 'active':
      case 'nominal':
      case 'synced':
      case 'on-station':
      case 'delivered':
      case 'routine':
      case 'packed':
      case 'shipped':
      case 'booked':
      case 'live':
      case 'approved':
      case 'fulfilled':
      case 'completed':
        return nominal;
      case 'warning':
      case 'delayed':
      case 'in-transit':
      case 'planned':
      case 'pending':
      case 'urgent':
      case 'low-connectivity':
        return warning;
      case 'critical':
      case 'emergency':
      case 'alarm':
      case 'departed':
      case 'at-risk':
      case 'cancelled':
      case 'denied':
        return critical;
      default:
        return onSurfaceVariant;
    }
  }

  @override
  AppThemeColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceLow,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? surfaceLowest,
    Color? surfaceBright,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? outline,
    Color? border,
    Color? divider,
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondary,
    Color? onSecondary,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? error,
    Color? onError,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? nominal,
    Color? onNominal,
    Color? nominalContainer,
    Color? onNominalContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? critical,
    Color? onCritical,
    Color? criticalContainer,
    Color? onCriticalContainer,
    Color? inputFill,
  }) {
    return AppThemeColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceLow: surfaceLow ?? this.surfaceLow,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      surfaceLowest: surfaceLowest ?? this.surfaceLowest,
      surfaceBright: surfaceBright ?? this.surfaceBright,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      secondaryContainer: secondaryContainer ?? this.secondaryContainer,
      onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
      tertiary: tertiary ?? this.tertiary,
      onTertiary: onTertiary ?? this.onTertiary,
      tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorContainer: errorContainer ?? this.errorContainer,
      onErrorContainer: onErrorContainer ?? this.onErrorContainer,
      nominal: nominal ?? this.nominal,
      onNominal: onNominal ?? this.onNominal,
      nominalContainer: nominalContainer ?? this.nominalContainer,
      onNominalContainer: onNominalContainer ?? this.onNominalContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      critical: critical ?? this.critical,
      onCritical: onCritical ?? this.onCritical,
      criticalContainer: criticalContainer ?? this.criticalContainer,
      onCriticalContainer: onCriticalContainer ?? this.onCriticalContainer,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  AppThemeColors lerp(covariant AppThemeColors? other, double t) {
    if (other == null) return this;
    Color blend(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppThemeColors(
      canvas: blend(canvas, other.canvas),
      surface: blend(surface, other.surface),
      surfaceLow: blend(surfaceLow, other.surfaceLow),
      surfaceHigh: blend(surfaceHigh, other.surfaceHigh),
      surfaceHighest: blend(surfaceHighest, other.surfaceHighest),
      surfaceLowest: blend(surfaceLowest, other.surfaceLowest),
      surfaceBright: blend(surfaceBright, other.surfaceBright),
      onSurface: blend(onSurface, other.onSurface),
      onSurfaceVariant: blend(onSurfaceVariant, other.onSurfaceVariant),
      outline: blend(outline, other.outline),
      border: blend(border, other.border),
      divider: blend(divider, other.divider),
      primary: blend(primary, other.primary),
      onPrimary: blend(onPrimary, other.onPrimary),
      primaryContainer: blend(primaryContainer, other.primaryContainer),
      onPrimaryContainer: blend(onPrimaryContainer, other.onPrimaryContainer),
      secondary: blend(secondary, other.secondary),
      onSecondary: blend(onSecondary, other.onSecondary),
      secondaryContainer: blend(secondaryContainer, other.secondaryContainer),
      onSecondaryContainer: blend(
        onSecondaryContainer,
        other.onSecondaryContainer,
      ),
      tertiary: blend(tertiary, other.tertiary),
      onTertiary: blend(onTertiary, other.onTertiary),
      tertiaryContainer: blend(tertiaryContainer, other.tertiaryContainer),
      onTertiaryContainer: blend(
        onTertiaryContainer,
        other.onTertiaryContainer,
      ),
      error: blend(error, other.error),
      onError: blend(onError, other.onError),
      errorContainer: blend(errorContainer, other.errorContainer),
      onErrorContainer: blend(onErrorContainer, other.onErrorContainer),
      nominal: blend(nominal, other.nominal),
      onNominal: blend(onNominal, other.onNominal),
      nominalContainer: blend(nominalContainer, other.nominalContainer),
      onNominalContainer: blend(onNominalContainer, other.onNominalContainer),
      warning: blend(warning, other.warning),
      onWarning: blend(onWarning, other.onWarning),
      warningContainer: blend(warningContainer, other.warningContainer),
      onWarningContainer: blend(onWarningContainer, other.onWarningContainer),
      critical: blend(critical, other.critical),
      onCritical: blend(onCritical, other.onCritical),
      criticalContainer: blend(criticalContainer, other.criticalContainer),
      onCriticalContainer: blend(
        onCriticalContainer,
        other.onCriticalContainer,
      ),
      inputFill: blend(inputFill, other.inputFill),
    );
  }
}

extension AppThemeColorsContext on BuildContext {
  /// Returns the semantic palette for the nearest [Theme].
  AppThemeColors get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppThemeColors>() ??
        (theme.brightness == Brightness.dark
            ? AppThemeColors.dark
            : AppThemeColors.light);
  }
}
