import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF090909);
  static const Color panel = Color(0xFF151515);
  static const Color surface = Color(0xFF1C1C1C);
  static const Color outline = Color(0xFF323232);
  static const Color accent = Color(0xFFFF7A1A);
  static const Color accentSoft = Color(0xFFFFB273);
  static const Color foreground = Color(0xFFF5F7FA);
  static const Color muted = Color(0xFF9A9A9A);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFFC857);

  static const Color lightBackground = Color(0xFFF7F7F7);
  static const Color lightPanel = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF2F2F2);
  static const Color lightOutline = Color(0xFFDADADA);
  static const Color lightForeground = Color(0xFF171717);
  static const Color lightMuted = Color(0xFF6E6E6E);

  static TextTheme _textTheme(TextTheme base, Color textColor) {
    return base.copyWith(
      displayLarge: GoogleFonts.orbitron(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
      headlineLarge: GoogleFonts.orbitron(
        color: textColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
      headlineMedium: GoogleFonts.orbitron(
        color: textColor,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      titleLarge: GoogleFonts.orbitron(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.rajdhani(
        color: textColor,
        fontWeight: FontWeight.w500,
        fontSize: 18,
      ),
      bodyMedium: GoogleFonts.rajdhani(
        color: textColor,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentSoft,
        surface: surface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: foreground,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: foreground, displayColor: foreground),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, foreground),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        labelStyle: const TextStyle(color: foreground),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.rajdhani(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: accent),
        selectedLabelTextStyle: GoogleFonts.rajdhani(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: GoogleFonts.rajdhani(
          color: muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        selectedColor: accent.withValues(alpha: 0.2),
        side: const BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: GoogleFonts.rajdhani(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.orbitron(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: accent,
        secondary: accentSoft,
        surface: lightSurface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: lightForeground,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(
        ThemeData.light().textTheme,
      ).apply(bodyColor: lightForeground, displayColor: lightForeground),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, lightForeground),
      cardTheme: CardThemeData(
        color: lightPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: lightForeground),
        hintStyle: const TextStyle(color: lightMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: lightOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.rajdhani(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: accent),
        selectedLabelTextStyle: GoogleFonts.rajdhani(
          color: lightForeground,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: GoogleFonts.rajdhani(
          color: lightMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF1F1F1),
        selectedColor: accent.withValues(alpha: 0.2),
        side: const BorderSide(color: lightOutline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: GoogleFonts.rajdhani(
          color: lightForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.orbitron(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
