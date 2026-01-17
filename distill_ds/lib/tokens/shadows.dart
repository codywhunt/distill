import 'package:flutter/material.dart';

/// A set of shadows at different elevation levels.
@immutable
class HoloShadowSet {
  final List<BoxShadow> elevation100;
  final List<BoxShadow> elevation200;
  final List<BoxShadow> elevation300;
  final List<BoxShadow> elevation400;
  final List<BoxShadow> elevation500;

  const HoloShadowSet({
    required this.elevation100,
    required this.elevation200,
    required this.elevation300,
    required this.elevation400,
    required this.elevation500,
  });
}

/// Shadow tokens for elevation effects.
///
/// Access via `context.shadows` extension.
/// Use `context.shadows.elevation100` etc. to get the correct
/// shadows for the current theme brightness.
@immutable
class HoloShadows extends ThemeExtension<HoloShadows> {
  final HoloShadowSet light;
  final HoloShadowSet dark;
  final List<BoxShadow> Function(int) _getShadowForCurrentTheme;

  HoloShadows({
    required this.light,
    required this.dark,
    List<BoxShadow> Function(int)? getShadowForCurrentTheme,
  }) : _getShadowForCurrentTheme =
           getShadowForCurrentTheme ?? ((elevation) => light.elevation100);

  /// Get elevation 100 shadow for the current theme.
  List<BoxShadow> get elevation100 => _getShadowForCurrentTheme(100);

  /// Get elevation 200 shadow for the current theme.
  List<BoxShadow> get elevation200 => _getShadowForCurrentTheme(200);

  /// Get elevation 300 shadow for the current theme.
  List<BoxShadow> get elevation300 => _getShadowForCurrentTheme(300);

  /// Get elevation 400 shadow for the current theme.
  List<BoxShadow> get elevation400 => _getShadowForCurrentTheme(400);

  /// Get elevation 500 shadow for the current theme.
  List<BoxShadow> get elevation500 => _getShadowForCurrentTheme(500);

  @override
  HoloShadows copyWith({
    HoloShadowSet? light,
    HoloShadowSet? dark,
    List<BoxShadow> Function(int)? getShadowForCurrentTheme,
  }) {
    return HoloShadows(
      light: light ?? this.light,
      dark: dark ?? this.dark,
      getShadowForCurrentTheme:
          getShadowForCurrentTheme ?? _getShadowForCurrentTheme,
    );
  }

  @override
  HoloShadows lerp(ThemeExtension<HoloShadows>? other, double t) {
    if (other is! HoloShadows) return this;
    return HoloShadows(
      light: light,
      dark: dark,
      getShadowForCurrentTheme: _getShadowForCurrentTheme,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light Theme Shadows
// ─────────────────────────────────────────────────────────────────────────────

const _lightShadows = HoloShadowSet(
  elevation100: [
    BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x26000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x40000000)),
  ],
  elevation200: [
    BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x1A000000)),
    BoxShadow(offset: Offset(0, 3), blurRadius: 8, color: Color(0x1A000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x2E000000)),
  ],
  elevation300: [
    BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x1A000000)),
    BoxShadow(offset: Offset(0, 5), blurRadius: 12, color: Color(0x1F000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x26000000)),
  ],
  elevation400: [
    BoxShadow(offset: Offset(0, 2), blurRadius: 5, color: Color(0x1F000000)),
    BoxShadow(offset: Offset(0, 10), blurRadius: 16, color: Color(0x1A000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x1F000000)),
  ],
  elevation500: [
    BoxShadow(offset: Offset(0, 2), blurRadius: 5, color: Color(0x24000000)),
    BoxShadow(offset: Offset(0, 10), blurRadius: 24, color: Color(0x29000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x14000000)),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// Dark Theme Shadows
// ─────────────────────────────────────────────────────────────────────────────

const _darkShadows = HoloShadowSet(
  elevation100: [
    BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x66000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x4D000000)),
    BoxShadow(
      offset: Offset(0, -0.5),
      blurRadius: 0,
      color: Color.fromARGB(25, 255, 255, 255),
    ),
    BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 0.5,
      color: Color.fromARGB(76, 255, 255, 255),
    ),
  ],
  elevation200: [
    BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x80000000)),
    BoxShadow(offset: Offset(0, 3), blurRadius: 8, color: Color(0x59000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x80000000)),
    BoxShadow(
      offset: Offset(0, -0.5),
      blurRadius: 0,
      color: Color.fromARGB(21, 255, 255, 255),
    ),
    BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 0.5,
      color: Color.fromARGB(89, 255, 255, 255),
    ),
  ],
  elevation300: [
    BoxShadow(offset: Offset(0, 1), blurRadius: 3, color: Color(0x80000000)),
    BoxShadow(offset: Offset(0, 5), blurRadius: 12, color: Color(0x59000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x80000000)),
    BoxShadow(
      offset: Offset(0, -0.5),
      blurRadius: 0,
      color: Color.fromARGB(21, 255, 255, 255),
    ),
    BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 0.5,
      color: Color.fromARGB(89, 255, 255, 255),
    ),
  ],
  elevation400: [
    BoxShadow(offset: Offset(0, 2), blurRadius: 5, color: Color(0x59000000)),
    BoxShadow(offset: Offset(0, 10), blurRadius: 16, color: Color(0x59000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x80000000)),
    BoxShadow(
      offset: Offset(0, -0.5),
      blurRadius: 0,
      color: Color.fromARGB(21, 255, 255, 255),
    ),
    BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 0.5,
      color: Color.fromARGB(89, 255, 255, 255),
    ),
  ],
  elevation500: [
    BoxShadow(offset: Offset(0, 3), blurRadius: 5, color: Color(0x59000000)),
    BoxShadow(offset: Offset(0, 10), blurRadius: 24, color: Color(0x73000000)),
    BoxShadow(offset: Offset(0, 0), blurRadius: 0.5, color: Color(0x80000000)),
    BoxShadow(
      offset: Offset(0, -0.5),
      blurRadius: 0,
      color: Color.fromARGB(21, 255, 255, 255),
    ),
    BoxShadow(
      offset: Offset(0, 0),
      blurRadius: 0.5,
      color: Color.fromARGB(89, 255, 255, 255),
    ),
  ],
);

/// The default shadows instance.
final holoShadows = HoloShadows(
  light: _lightShadows,
  dark: _darkShadows,
);

