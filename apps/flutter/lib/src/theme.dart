import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primary = Color(0xFF2D87B8);
  static const primaryHover = Color(0xFF2474A0);
  static const danger = Color(0xFFEF4444);

  static const surfaceLight = Color(0xFFFFFFFF);
  static const cardLight = Color(0xFFF9FAFB);
  static const textLight = Color(0xFF1F2937);
  static const textSecondaryLight = Color(0xFF6B7280);
  static const borderLight = Color(0xFFE5E7EB);

  static const surfaceDark = Color(0xFF242424);
  static const cardDark = Color(0xFF303030);
  static const textDark = Color(0xFFE5E7EB);
  static const textSecondaryDark = Color(0xFF9CA3AF);
  static const borderDark = Color(0xFF3D3D3D);

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: primary,
      surface: surfaceLight,
      error: danger,
    ),
    scaffoldBackgroundColor: surfaceLight,
    textTheme: GoogleFonts.notoSansTextTheme(ThemeData.light().textTheme),
    dividerColor: borderLight,
    cardColor: cardLight,
  );

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      surface: surfaceDark,
      error: danger,
    ),
    scaffoldBackgroundColor: surfaceDark,
    textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
    dividerColor: borderDark,
    cardColor: cardDark,
  );
}
