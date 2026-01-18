import 'package:flutter/material.dart';

import 'colors.dart';
import 'motion.dart';
import 'radius.dart';
import 'shadows.dart';
import 'spacing.dart';
import 'typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Context Extensions
// ─────────────────────────────────────────────────────────────────────────────

/// Extension on [BuildContext] to access design system tokens.
///
/// Example:
/// ```dart
/// Container(
///   color: context.colors.background.primary,
///   padding: EdgeInsets.all(context.spacing.md),
///   child: Text(
///     'Hello',
///     style: context.typography.body.medium,
///   ),
/// )
/// ```
extension HoloTokens on BuildContext {
  /// Access color tokens.
  HoloColors get colors => Theme.of(this).extension<HoloColors>()!;

  /// Access typography tokens.
  HoloTypography get typography => Theme.of(this).extension<HoloTypography>()!;

  /// Access spacing tokens.
  HoloSpacing get spacing => Theme.of(this).extension<HoloSpacing>()!;

  /// Access border radius tokens.
  HoloRadius get radius => Theme.of(this).extension<HoloRadius>()!;

  /// Access shadow tokens with automatic light/dark selection.
  HoloShadows get shadows {
    final shadows = Theme.of(this).extension<HoloShadows>()!;
    final brightness = Theme.of(this).brightness;
    final shadowSet = brightness == Brightness.dark
        ? shadows.dark
        : shadows.light;

    return HoloShadows(
      light: shadows.light,
      dark: shadows.dark,
      getShadowForCurrentTheme: (elevation) {
        switch (elevation) {
          case 100:
            return shadowSet.elevation100;
          case 200:
            return shadowSet.elevation200;
          case 300:
            return shadowSet.elevation300;
          case 400:
            return shadowSet.elevation400;
          case 500:
            return shadowSet.elevation500;
          default:
            return shadowSet.elevation100;
        }
      },
    );
  }

  /// Access motion tokens.
  HoloMotion get motion => Theme.of(this).extension<HoloMotion>()!;

  /// Whether the current theme is dark mode.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme Data Builders
// ─────────────────────────────────────────────────────────────────────────────

/// Creates a [ColorScheme] from [HoloColors].
ColorScheme _createColorScheme(HoloColors colors, Brightness brightness) {
  return ColorScheme(
    brightness: brightness,
    // Primary colors
    primary: colors.background.primary,
    onPrimary: colors.foreground.primary,
    primaryContainer: colors.background.primary,
    onPrimaryContainer: colors.foreground.primary,

    // Secondary colors
    secondary: colors.background.secondary,
    onSecondary: colors.foreground.primary,
    secondaryContainer: colors.background.secondary,
    onSecondaryContainer: colors.foreground.primary,

    // Error colors
    error: colors.accent.red.primary,
    onError: Colors.white,
    errorContainer: colors.accent.red.overlay,
    onErrorContainer: colors.accent.red.primary,

    // Surface colors
    surface: colors.background.primary,
    onSurface: colors.foreground.primary,
    surfaceContainerHighest: colors.background.primary,
    onSurfaceVariant: colors.foreground.muted,

    // Other colors
    outline: colors.stroke,
    outlineVariant: colors.overlay.overlay10,
    shadow: colors.overlay.overlay20,
    scrim: colors.overlay.overlay20,

    // Inverse colors
    inverseSurface: brightness == Brightness.light
        ? colors.background.fullContrast
        : colors.background.secondary,
    onInverseSurface: brightness == Brightness.light
        ? colors.foreground.primary
        : colors.background.fullContrast,
    inversePrimary: colors.accent.purple.stroke,
  );
}

/// The default font family for the design system.
const String _defaultFontFamily = 'GeistVariable';

/// Builds the light theme [ThemeData].
ThemeData _buildLightTheme() {
  return ThemeData(
    brightness: Brightness.light,
    fontFamily: _defaultFontFamily,
    colorScheme: _createColorScheme(holoColorsLight, Brightness.light),
    extensions: [
      holoColorsLight,
      holoTypography,
      holoSpacing,
      holoRadius,
      holoShadows,
      holoMotion,
    ],
  );
}

/// Builds the dark theme [ThemeData].
ThemeData _buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    fontFamily: _defaultFontFamily,
    colorScheme: _createColorScheme(holoColorsDark, Brightness.dark),
    extensions: [
      holoColorsDark,
      holoTypography,
      holoSpacing,
      holoRadius,
      holoShadows,
      holoMotion,
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

/// Provides access to the design system themes.
///
/// Example:
/// ```dart
/// MaterialApp(
///   theme: HoloTheme.light,
///   darkTheme: HoloTheme.dark,
///   themeMode: ThemeMode.system,
///   // ...
/// )
/// ```
class HoloTheme {
  HoloTheme._();

  /// The light theme.
  static final ThemeData light = _buildLightTheme();

  /// The dark theme.
  static final ThemeData dark = _buildDarkTheme();
}
