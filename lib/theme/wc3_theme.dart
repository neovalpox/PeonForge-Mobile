import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WC3Colors {
  static const Color goldDark = Color(0xFF8B6914);
  static const Color goldLight = Color(0xFFDFBD5E);
  static const Color goldText = Color(0xFFC8B88A);
  static const Color bgDark = Color(0xFF0E0C08);
  static const Color bgCard = Color(0xFF16120A);
  static const Color bgSurface = Color(0xFF1E1A10);
  static const Color textDim = Color(0xFF5A5040);
  static const Color textMid = Color(0xFF7A7055);
  static const Color green = Color(0xFF5AFF5A);
  static const Color blue = Color(0xFF64C8FF);
  static const Color red = Color(0xFFFF5050);
  static const Color purple = Color(0xFFB482FF);
  static const Color orange = Color(0xFFFFC832);
  static const Color humanColor = Color(0xFF64C8FF);
  static const Color orcColor = Color(0xFFFF6644);
}

ThemeData wc3Theme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: WC3Colors.bgDark,
    colorScheme: const ColorScheme.dark(
      primary: WC3Colors.goldLight,
      secondary: WC3Colors.goldDark,
      surface: WC3Colors.bgCard,
    ),
    textTheme: GoogleFonts.notoSansTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      titleLarge: GoogleFonts.cinzelDecorative(
        color: WC3Colors.goldLight,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.cinzelDecorative(
        color: WC3Colors.goldLight,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: const TextStyle(color: WC3Colors.goldText, fontSize: 14),
      bodySmall: const TextStyle(color: WC3Colors.textMid, fontSize: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: WC3Colors.bgCard,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: WC3Colors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: WC3Colors.goldDark, width: 1.5),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: WC3Colors.bgCard,
      selectedItemColor: WC3Colors.goldLight,
      unselectedItemColor: WC3Colors.textDim,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: WC3Colors.goldLight,
      inactiveTrackColor: WC3Colors.goldDark.withValues(alpha: 0.3),
      thumbColor: WC3Colors.goldLight,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? WC3Colors.goldLight : WC3Colors.textDim),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? WC3Colors.goldDark : WC3Colors.bgSurface),
    ),
  );
}
