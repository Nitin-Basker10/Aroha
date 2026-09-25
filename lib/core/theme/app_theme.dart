import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 themes for the AROHA expedition command UI.
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => _buildTheme(
    brightness: Brightness.dark,
    colors: AppThemeColors.dark,
    baseTextTheme: ThemeData.dark().textTheme,
  );

  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    colors: AppThemeColors.light,
    baseTextTheme: ThemeData.light().textTheme,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppThemeColors colors,
    required TextTheme baseTextTheme,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      primaryContainer: colors.primaryContainer,
      onPrimaryContainer: colors.onPrimaryContainer,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      secondaryContainer: colors.secondaryContainer,
      onSecondaryContainer: colors.onSecondaryContainer,
      tertiary: colors.tertiary,
      onTertiary: colors.onTertiary,
      tertiaryContainer: colors.tertiaryContainer,
      onTertiaryContainer: colors.onTertiaryContainer,
      error: colors.error,
      onError: colors.onError,
      errorContainer: colors.errorContainer,
      onErrorContainer: colors.onErrorContainer,
      surface: colors.surface,
      onSurface: colors.onSurface,
      surfaceDim: colors.canvas,
      surfaceBright: colors.surfaceBright,
      surfaceContainerLowest: colors.surfaceLowest,
      surfaceContainerLow: colors.surfaceLow,
      surfaceContainer: colors.surface,
      surfaceContainerHigh: colors.surfaceHigh,
      surfaceContainerHighest: colors.surfaceHighest,
      onSurfaceVariant: colors.onSurfaceVariant,
      outline: colors.outline,
      outlineVariant: colors.border,
      inverseSurface: colors.onSurface,
      onInverseSurface: colors.canvas,
      inversePrimary: colors.primaryContainer,
    );

    final textTheme = GoogleFonts.ibmPlexSansTextTheme(
      baseTextTheme,
    ).apply(bodyColor: colors.onSurface, displayColor: colors.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      extensions: <ThemeExtension<dynamic>>[colors],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: colors.border, width: 1),
        ),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          color: colors.onSurfaceVariant,
        ),
        prefixIconColor: colors.onSurfaceVariant,
        suffixIconColor: colors.onSurfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: colors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: colors.secondary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: colors.critical, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: BorderSide(color: colors.critical, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          side: BorderSide(color: colors.border, width: 1),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceLow,
        selectedColor: colors.primaryContainer,
        disabledColor: colors.surfaceLow,
        checkmarkColor: colors.onPrimaryContainer,
        labelStyle: TextStyle(color: colors.onSurface),
        secondaryLabelStyle: TextStyle(color: colors.onSurface),
        side: BorderSide(color: colors.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceHigh,
        textStyle: TextStyle(color: colors.onSurface),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(color: colors.border, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.onSurface,
        contentTextStyle: TextStyle(color: colors.canvas),
        actionTextColor: colors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(colors.onPrimary),
        side: BorderSide(color: colors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      iconTheme: IconThemeData(color: colors.onSurfaceVariant),
      listTileTheme: ListTileThemeData(
        iconColor: colors.onSurfaceVariant,
        textColor: colors.onSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceHigh,
        circularTrackColor: colors.surfaceHigh,
      ),
    );
  }
}
