import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography specification for AROHA.
///
/// Color is intentionally omitted from these shared styles. The active
/// ThemeData supplies the correct foreground color, so the same typography
/// remains readable in both light and dark modes.
class AppTypography {
  AppTypography._();

  // Primary IBM Plex Sans typography
  static TextStyle headlineLg = GoogleFonts.ibmPlexSans(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: 0.5,
  );

  static TextStyle headlineMd = GoogleFonts.ibmPlexSans(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle headlineSm = GoogleFonts.ibmPlexSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.2,
  );

  static TextStyle titleMd = GoogleFonts.ibmPlexSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle titleSm = GoogleFonts.ibmPlexSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle bodyLg = GoogleFonts.ibmPlexSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle bodyMd = GoogleFonts.ibmPlexSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static TextStyle bodySm = GoogleFonts.ibmPlexSans(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static TextStyle labelMd = GoogleFonts.ibmPlexSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.3,
  );

  static TextStyle labelSm = GoogleFonts.ibmPlexSans(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // JetBrains Mono for telemetry, numbers, coordinates, timestamps
  static TextStyle telemetryLg = GoogleFonts.jetBrainsMono(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static TextStyle telemetryMd = GoogleFonts.jetBrainsMono(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static TextStyle telemetrySm = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );

  static TextStyle telemetryXs = GoogleFonts.jetBrainsMono(
    fontSize: 9.5,
    fontWeight: FontWeight.w400,
    height: 1.1,
  );
}
