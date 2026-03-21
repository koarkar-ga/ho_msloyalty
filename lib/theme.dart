import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HOColors {
  static const Color primary = Color(0xFF1B4F72); // Navy Blue
  static const Color accent = Color(0xFFD4AF37); // Gold
  static const Color background = Color(0xFF0A192F); // Deep Dark Blue
  static const Color surface = Color(0xFF132B4F); // Lighter Surface Blue
  static const Color textBody = Color(0xFFE6E6E6);
  static const Color textHeader = Colors.white;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFE6E6E6);
  static const Color divider = Colors.white10;

  // ── Glassmorphism Tokens ──────────────────────────────────────────
  static const Color glassBackground = Color(
    0x1A64B5F6,
  ); // Very transparent blue
  static const Color glassBorder = Color(0x33FFFFFF); // Transparent white
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFFB8860B), Color(0xFFD4AF37), Color(0xFFFFD700)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class HOTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: HOColors.background,
      colorScheme: const ColorScheme.dark(
        primary: HOColors.primary,
        secondary: HOColors.accent,
        surface: HOColors.surface,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: HOColors.textBody,
        displayColor: HOColors.textHeader,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HOColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: HOColors.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
