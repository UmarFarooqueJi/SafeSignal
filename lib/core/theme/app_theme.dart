import 'package:flutter/material.dart';

class AppTheme {
  // ─── Brand Palette ────────────────────────────────────────────
  static const Color primary      = Color(0xFF2979FF);
  static const Color primaryDeep  = Color(0xFF1565C0);
  static const Color accent       = Color(0xFF7C4DFF);
  static const Color accentTeal   = Color(0xFF00BCD4);

  // ─── Verdict Colors ───────────────────────────────────────────
  static const Color scamRed      = Color(0xFFEF5350);
  static const Color scamRedBg    = Color(0xFFFFEBEE);
  static const Color scamRedDark  = Color(0xFF4A0000);

  static const Color cautionAmber = Color(0xFFFFB300);
  static const Color cautionBg    = Color(0xFFFFF8E1);
  static const Color cautionDark  = Color(0xFF3E2000);

  static const Color safeGreen    = Color(0xFF00C853);
  static const Color safeBg       = Color(0xFFE8F5E9);
  static const Color safeDark     = Color(0xFF00200A);

  // ─── Light Surface ────────────────────────────────────────────
  static const Color lightBg      = Color(0xFFFFFFFF);
  static const Color lightCard    = Color(0xFFFFFFFF);
  static const Color lightCardAlt = Color(0xFFF5F7FF);

  // ─── Dark Surface ─────────────────────────────────────────────
  static const Color darkBg       = Color(0xFF06090F);
  static const Color darkSurface  = Color(0xFF0D1117);
  static const Color darkCard     = Color(0xFF1E2638);
  static const Color darkCardAlt  = Color(0xFF253046);
  static const Color darkBorder   = Color(0xFF3A4456);

  // ─── Text Sizes ───────────────────────────────────────────────
  static const double textNormal  = 1.0;
  static const double textBada    = 1.2;
  static const double textSabse   = 1.5;

  // ─── Gradients ────────────────────────────────────────────────
  static const LinearGradient primaryGrad = LinearGradient(
    colors: [Color(0xFF2979FF), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scamGrad = LinearGradient(
    colors: [Color(0xFFEF5350), Color(0xFFD32F2F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGrad = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cautionGrad = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGrad = LinearGradient(
    colors: [Color(0xFF06090F), Color(0xFF0D1117)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Light Theme ──────────────────────────────────────────────
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: lightBg,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: lightBg,
    ),
    scaffoldBackgroundColor: lightBg,
    fontFamily: 'Roboto',
    cardTheme: CardThemeData(
      color: lightCard,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFF1F4F9), width: 1.2),
      ),
      shadowColor: const Color(0xFF0A1020).withValues(alpha: 0.04),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shadowColor: primary.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE8EEF5), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF0F172A),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Color(0xFF0F172A),
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightCard,
      indicatorColor: primary.withValues(alpha: 0.1),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      elevation: 0,
    ),
  );

  // ─── Dark Theme ───────────────────────────────────────────────
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: darkSurface,
    ),
    scaffoldBackgroundColor: darkBg,
    fontFamily: 'Roboto',
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: darkBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkCard,
      indicatorColor: primary.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      elevation: 0,
    ),
  );

  // ─── Verdict Helpers ──────────────────────────────────────────
  static Color verdictColor(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'SCAM': return scamRed;
      case 'LIKELY_SAFE': return safeGreen;
      default: return cautionAmber;
    }
  }

  static LinearGradient verdictGradient(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'SCAM': return scamGrad;
      case 'LIKELY_SAFE': return safeGrad;
      default: return cautionGrad;
    }
  }

  static Color verdictBgColor(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'SCAM': return scamRedBg;
      case 'LIKELY_SAFE': return safeBg;
      default: return cautionBg;
    }
  }

  static String verdictEmoji(String verdict) {
    switch (verdict.toUpperCase()) {
      case 'SCAM': return '🔴';
      case 'LIKELY_SAFE': return '🟢';
      default: return '🟡';
    }
  }
}
