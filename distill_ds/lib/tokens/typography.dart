import 'package:flutter/material.dart';

const String _headingsFontFamily = 'GeistVariable';
const String _bodyFontFamily = 'GeistVariable';
const String _monoFontFamily = 'GeistMonoVariable';

const _defaultFontWeight = FontVariation('wght', 300);
const _mediumFontWeight = FontVariation('wght', 300);
const _strongFontWeight = FontVariation('wght', 400);

/// Heading text styles.
class HoloHeadingTextStyles {
  final TextStyle display;
  final TextStyle large;
  final TextStyle medium;
  final TextStyle small;

  const HoloHeadingTextStyles({
    required this.display,
    required this.large,
    required this.medium,
    required this.small,
  });
}

/// Body text styles with regular and strong variants.
class HoloBodyTextStyles {
  final TextStyle large;
  final TextStyle medium;
  final TextStyle small;
  final TextStyle largeStrong;
  final TextStyle mediumStrong;
  final TextStyle smallStrong;

  const HoloBodyTextStyles({
    required this.large,
    required this.medium,
    required this.small,
    required this.largeStrong,
    required this.mediumStrong,
    required this.smallStrong,
  });
}

/// Monospace text styles for code.
class HoloMonoTextStyles {
  final TextStyle large;
  final TextStyle medium;
  final TextStyle small;
  final TextStyle largeStrong;
  final TextStyle mediumStrong;
  final TextStyle smallStrong;

  const HoloMonoTextStyles({
    required this.large,
    required this.medium,
    required this.small,
    required this.largeStrong,
    required this.mediumStrong,
    required this.smallStrong,
  });
}

/// The main typography token collection for the design system.
///
/// Access via `context.typography` extension.
@immutable
class HoloTypography extends ThemeExtension<HoloTypography> {
  final HoloHeadingTextStyles headings;
  final HoloBodyTextStyles body;
  final HoloMonoTextStyles mono;

  const HoloTypography({
    required this.headings,
    required this.body,
    required this.mono,
  });

  @override
  HoloTypography copyWith({
    HoloHeadingTextStyles? headings,
    HoloBodyTextStyles? body,
    HoloMonoTextStyles? mono,
  }) {
    return HoloTypography(
      headings: headings ?? this.headings,
      body: body ?? this.body,
      mono: mono ?? this.mono,
    );
  }

  @override
  HoloTypography lerp(
    covariant ThemeExtension<HoloTypography>? other,
    double t,
  ) {
    // Typography doesn't lerp well, just return this
    return this;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Predefined Text Styles
// ─────────────────────────────────────────────────────────────────────────────

const _headingTextStyles = HoloHeadingTextStyles(
  display: TextStyle(
    fontSize: 36,
    fontVariations: [_defaultFontWeight],
    fontFamily: _headingsFontFamily,
  ),
  large: TextStyle(
    fontSize: 16,
    fontVariations: [_strongFontWeight],
    fontFamily: _headingsFontFamily,
  ),
  medium: TextStyle(
    fontSize: 13,
    fontVariations: [_strongFontWeight],
    fontFamily: _headingsFontFamily,
  ),
  small: TextStyle(
    fontSize: 11.5,
    fontVariations: [_strongFontWeight],
    fontFamily: _headingsFontFamily,
  ),
);

const _bodyTextStyles = HoloBodyTextStyles(
  large: TextStyle(
    fontSize: 13,
    fontVariations: [_mediumFontWeight],
    fontFamily: _bodyFontFamily,
  ),
  medium: TextStyle(
    fontSize: 11.5,
    fontVariations: [_mediumFontWeight],
    fontFamily: _bodyFontFamily,
  ),
  small: TextStyle(
    fontSize: 10.5,
    fontVariations: [_defaultFontWeight],
    fontFamily: _bodyFontFamily,
  ),
  largeStrong: TextStyle(
    fontSize: 13,
    fontVariations: [_strongFontWeight],
    fontFamily: _bodyFontFamily,
  ),
  mediumStrong: TextStyle(
    fontSize: 11.5,
    fontVariations: [_strongFontWeight],
    fontFamily: _bodyFontFamily,
  ),
  smallStrong: TextStyle(
    fontSize: 10.5,
    fontVariations: [_strongFontWeight],
    fontFamily: _bodyFontFamily,
  ),
);

/// Disable ligatures for all mono text styles used in rendering code.
const _disableLigatures = <FontFeature>[
  FontFeature.disable('liga'),
  FontFeature.disable('clig'),
  FontFeature.disable('dlig'),
  FontFeature.disable('hlig'),
  FontFeature.disable('calt'),
];

const _monoTextStyles = HoloMonoTextStyles(
  large: TextStyle(
    fontSize: 12.5,
    fontVariations: [_defaultFontWeight],
    fontFamily: _monoFontFamily,
    fontFeatures: _disableLigatures,
  ),
  medium: TextStyle(
    fontSize: 11.5,
    fontVariations: [_mediumFontWeight],
    fontFamily: _monoFontFamily,
    fontFeatures: _disableLigatures,
  ),
  small: TextStyle(
    fontSize: 10.5,
    fontVariations: [_defaultFontWeight],
    fontFamily: _monoFontFamily,
    fontFeatures: _disableLigatures,
  ),
  largeStrong: TextStyle(
    fontSize: 12.5,
    fontVariations: [_strongFontWeight],
    fontFamily: _monoFontFamily,
    fontFeatures: _disableLigatures,
  ),
  mediumStrong: TextStyle(
    fontSize: 11.5,
    fontVariations: [_strongFontWeight],
    fontFamily: _monoFontFamily,
    fontFeatures: _disableLigatures,
  ),
  smallStrong: TextStyle(
    fontSize: 10.5,
    fontVariations: [_strongFontWeight],
    fontFamily: _monoFontFamily,
    fontFeatures: _disableLigatures,
  ),
);

/// The default typography instance.
const holoTypography = HoloTypography(
  headings: _headingTextStyles,
  body: _bodyTextStyles,
  mono: _monoTextStyles,
);
