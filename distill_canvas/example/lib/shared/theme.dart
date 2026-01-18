import 'package:flutter/material.dart';

/// Shared visual theme for all examples.
/// Terminal-inspired: monospace fonts, muted greys, compact, subtle.
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────────────
  // Colors - Neutral greyscale with subtle warmth
  // ─────────────────────────────────────────────────────────────────────────

  static const background = Color(0xFF09090B); // zinc-950
  static const surface = Color(0xFF0F0F12);
  static const surfaceLight = Color(0xFF18181B); // zinc-900
  static const surfaceHover = Color(0xFF1F1F23);
  static const border = Color(0xFF27272A); // zinc-800
  static const borderSubtle = Color(0xFF1C1C1F);

  // Accent - very subtle, used sparingly
  static const accent = Color(0xFF71717A); // zinc-500
  static const accentMuted = Color(0xFF52525B); // zinc-600

  // Semantic (muted versions)
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFEAB308);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Canvas
  static const canvasDefault = Color(0xFF09090B);

  // ─────────────────────────────────────────────────────────────────────────
  // Text - Zinc scale
  // ─────────────────────────────────────────────────────────────────────────

  static const textPrimary = Color(0xFFE4E4E7); // zinc-200
  static const textSecondary = Color(0xFFA1A1AA); // zinc-400
  static const textMuted = Color(0xFF71717A); // zinc-500
  static const textSubtle = Color(0xFF52525B); // zinc-600

  // ─────────────────────────────────────────────────────────────────────────
  // Typography
  // ─────────────────────────────────────────────────────────────────────────

  // Font family names matching the bundled fonts in distill_ds
  static const fontMono = 'GeistMonoVariable';
  static const fontSans = 'GeistVariable';

  // ─────────────────────────────────────────────────────────────────────────
  // Theme Data
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    fontFamily: fontSans,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    colorScheme: const ColorScheme.dark(
      primary: textSecondary,
      secondary: accent,
      surface: surface,
      error: error,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: border, width: 0.5),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: borderSubtle,
      thickness: 0.5,
      space: 0.5,
    ),
    iconTheme: const IconThemeData(color: textMuted, size: 16),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: -0.1,
      ),
      titleMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 12,
        color: textSecondary,
        letterSpacing: 0.1,
      ),
      bodySmall: TextStyle(fontSize: 11, color: textMuted, letterSpacing: 0.1),
      labelMedium: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textMuted,
        letterSpacing: 0.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: accent, width: 0.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: surfaceLight,
        foregroundColor: textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: border, width: 0.5),
        ),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textSecondary,
        side: const BorderSide(color: border, width: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: border, width: 0.5),
      ),
      textStyle: const TextStyle(
        fontFamily: fontMono,
        fontSize: 11,
        color: textPrimary,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      waitDuration: const Duration(milliseconds: 400),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      elevation: 4,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: border, width: 0.5),
      ),
      textStyle: const TextStyle(fontSize: 11, color: textPrimary),
    ),
  );
}

/// Accent color presets for different object types (muted versions).
class AccentColors {
  AccentColors._();

  static const slate = Color(0xFF64748B);
  static const zinc = Color(0xFF71717A);
  static const stone = Color(0xFF78716C);
  static const neutral = Color(0xFF737373);
  static const gray = Color(0xFF6B7280);

  // Subtle colored accents (use sparingly)
  static const blue = Color(0xFF3B82F6);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFF43F5E);
  static const violet = Color(0xFF8B5CF6);

  static const all = [slate, zinc, stone, neutral, gray, blue];
}
