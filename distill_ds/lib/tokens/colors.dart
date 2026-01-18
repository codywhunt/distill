import 'package:flutter/material.dart';

/// Background color tokens.
class HoloBackgroundColors {
  final Color primary;
  final Color secondary;
  final Color alternate;
  final Color fullContrast;
  final Color tooltip;

  const HoloBackgroundColors({
    required this.primary,
    required this.secondary,
    required this.alternate,
    required this.fullContrast,
    required this.tooltip,
  });
}

/// Foreground (text/icon) color tokens.
class HoloForegroundColors {
  final Color primary;
  final Color muted;
  final Color weak;
  final Color disabled;
  final Color tooltip;
  final Color tooltipMuted;
  final Color tooltipLink;

  const HoloForegroundColors({
    required this.primary,
    required this.muted,
    required this.weak,
    required this.disabled,
    required this.tooltip,
    required this.tooltipMuted,
    required this.tooltipLink,
  });
}

/// Overlay color tokens with varying opacity levels.
class HoloOverlayColors {
  final Color overlay03;
  final Color overlay05;
  final Color overlay10;
  final Color overlay15;
  final Color overlay20;

  const HoloOverlayColors({
    required this.overlay03,
    required this.overlay05,
    required this.overlay10,
    required this.overlay15,
    required this.overlay20,
  });
}

/// A set of accent colors with primary, overlay, and stroke variants.
class HoloAccentColorSet {
  final Color primary;
  final Color overlay;
  final Color stroke;

  const HoloAccentColorSet({
    required this.primary,
    required this.overlay,
    required this.stroke,
  });
}

/// Semantic accent color groups.
class HoloAccentColors {
  final HoloAccentColorSet purple;
  final HoloAccentColorSet orange;
  final HoloAccentColorSet green;
  final HoloAccentColorSet red;
  final HoloAccentColorSet pink;
  final HoloAccentColorSet teal;

  const HoloAccentColors({
    required this.purple,
    required this.orange,
    required this.green,
    required this.red,
    required this.pink,
    required this.teal,
  });
}

/// Diff view colors for additions and removals.
class HoloDiffColors {
  final Color addition;
  final Color removal;

  const HoloDiffColors({required this.addition, required this.removal});
}

/// The main color token collection for the design system.
///
/// Access via `context.colors` extension.
@immutable
class HoloColors extends ThemeExtension<HoloColors> {
  final HoloBackgroundColors background;
  final HoloForegroundColors foreground;
  final HoloOverlayColors overlay;
  final HoloAccentColors accent;
  final HoloDiffColors diff;
  final Color stroke;

  const HoloColors({
    required this.background,
    required this.foreground,
    required this.overlay,
    required this.accent,
    required this.diff,
    required this.stroke,
  });

  @override
  HoloColors copyWith({
    HoloBackgroundColors? background,
    HoloForegroundColors? foreground,
    HoloOverlayColors? overlay,
    HoloAccentColors? accent,
    HoloDiffColors? diff,
    Color? stroke,
  }) {
    return HoloColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      overlay: overlay ?? this.overlay,
      accent: accent ?? this.accent,
      diff: diff ?? this.diff,
      stroke: stroke ?? this.stroke,
    );
  }

  @override
  HoloColors lerp(ThemeExtension<HoloColors>? other, double t) {
    if (other is! HoloColors) return this;
    return HoloColors(
      background: HoloBackgroundColors(
        primary: Color.lerp(background.primary, other.background.primary, t)!,
        secondary:
            Color.lerp(background.secondary, other.background.secondary, t)!,
        alternate:
            Color.lerp(background.alternate, other.background.alternate, t)!,
        fullContrast:
            Color.lerp(
              background.fullContrast,
              other.background.fullContrast,
              t,
            )!,
        tooltip: Color.lerp(background.tooltip, other.background.tooltip, t)!,
      ),
      foreground: HoloForegroundColors(
        primary: Color.lerp(foreground.primary, other.foreground.primary, t)!,
        muted: Color.lerp(foreground.muted, other.foreground.muted, t)!,
        weak: Color.lerp(foreground.weak, other.foreground.weak, t)!,
        disabled:
            Color.lerp(foreground.disabled, other.foreground.disabled, t)!,
        tooltip: Color.lerp(foreground.tooltip, other.foreground.tooltip, t)!,
        tooltipMuted:
            Color.lerp(
              foreground.tooltipMuted,
              other.foreground.tooltipMuted,
              t,
            )!,
        tooltipLink:
            Color.lerp(
              foreground.tooltipLink,
              other.foreground.tooltipLink,
              t,
            )!,
      ),
      overlay: HoloOverlayColors(
        overlay03: Color.lerp(overlay.overlay03, other.overlay.overlay03, t)!,
        overlay05: Color.lerp(overlay.overlay05, other.overlay.overlay05, t)!,
        overlay10: Color.lerp(overlay.overlay10, other.overlay.overlay10, t)!,
        overlay15: Color.lerp(overlay.overlay15, other.overlay.overlay15, t)!,
        overlay20: Color.lerp(overlay.overlay20, other.overlay.overlay20, t)!,
      ),
      accent: HoloAccentColors(
        purple: _lerpAccent(accent.purple, other.accent.purple, t),
        orange: _lerpAccent(accent.orange, other.accent.orange, t),
        green: _lerpAccent(accent.green, other.accent.green, t),
        red: _lerpAccent(accent.red, other.accent.red, t),
        pink: _lerpAccent(accent.pink, other.accent.pink, t),
        teal: _lerpAccent(accent.teal, other.accent.teal, t),
      ),
      diff: HoloDiffColors(
        addition: Color.lerp(diff.addition, other.diff.addition, t)!,
        removal: Color.lerp(diff.removal, other.diff.removal, t)!,
      ),
      stroke: Color.lerp(stroke, other.stroke, t)!,
    );
  }

  static HoloAccentColorSet _lerpAccent(
    HoloAccentColorSet a,
    HoloAccentColorSet b,
    double t,
  ) {
    return HoloAccentColorSet(
      primary: Color.lerp(a.primary, b.primary, t)!,
      overlay: Color.lerp(a.overlay, b.overlay, t)!,
      stroke: Color.lerp(a.stroke, b.stroke, t)!,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light Theme Colors
// ─────────────────────────────────────────────────────────────────────────────

final holoColorsLight = HoloColors(
  background: HoloBackgroundColors(
    primary: const Color(0xFFFCFCFC),
    secondary: const Color(0xFFF5F5F5),
    alternate: const Color(0xFFFDFDFD),
    fullContrast: const Color(0xFFFFFFFF),
    tooltip: const Color(0xFF575757).withAlpha(242),
  ),
  foreground: const HoloForegroundColors(
    primary: Color(0xFF09090B),
    muted: Color(0xFF727274),
    weak: Color(0xFFA4A4A4),
    disabled: Color(0xFFB4B4B4),
    tooltip: Color(0xFFF0F0F0),
    tooltipMuted: Color(0xFFC1C9D7),
    tooltipLink: Color(0xFFB6B6F7),
  ),
  overlay: HoloOverlayColors(
    overlay03: const Color(0xFF21252B).withAlpha(8),
    overlay05: const Color(0xFF21252B).withAlpha(13),
    overlay10: const Color(0xFF21252B).withAlpha(26),
    overlay15: const Color(0xFF21252B).withAlpha(38),
    overlay20: const Color(0xFF21252B).withAlpha(51),
  ),
  accent: HoloAccentColors(
    purple: HoloAccentColorSet(
      primary: const Color(0xFF4C52D1),
      overlay: const Color(0xFF4C52D1).withAlpha(26),
      stroke: const Color(0xFF4C52D1).withAlpha(64),
    ),
    orange: HoloAccentColorSet(
      primary: const Color(0xFFEB9758),
      overlay: const Color(0xFFEB9758).withAlpha(26),
      stroke: const Color(0xFFEB9758).withAlpha(64),
    ),
    green: HoloAccentColorSet(
      primary: const Color(0xFF50A150),
      overlay: const Color(0xFF50A150).withAlpha(26),
      stroke: const Color(0xFF50A150).withAlpha(64),
    ),
    red: HoloAccentColorSet(
      primary: const Color(0xFFE45649),
      overlay: const Color(0xFFE45649).withAlpha(26),
      stroke: const Color(0xFFE45649).withAlpha(64),
    ),
    pink: HoloAccentColorSet(
      primary: const Color(0xFFD46CB3),
      overlay: const Color(0xFFD46CB3).withAlpha(26),
      stroke: const Color(0xFFD46CB3).withAlpha(64),
    ),
    teal: HoloAccentColorSet(
      primary: const Color(0xFF22808D),
      overlay: const Color(0xFF22808D).withAlpha(26),
      stroke: const Color(0xFF22808D).withAlpha(64),
    ),
  ),
  diff: HoloDiffColors(
    addition: const Color(0xFFB9D2C9).withAlpha(130),
    removal: const Color(0xFFFBCECE).withAlpha(130),
  ),
  stroke: const Color(0xFFDBDBE4),
);

// ─────────────────────────────────────────────────────────────────────────────
// Dark Theme Colors
// ─────────────────────────────────────────────────────────────────────────────

final holoColorsDark = HoloColors(
  background: HoloBackgroundColors(
    primary: const Color(0xFF181818),
    secondary: const Color(0xFF121212),
    alternate: const Color(0xFF1C1F24),
    fullContrast: const Color.fromARGB(255, 13, 13, 13),
    tooltip: const Color(0xFFF0F0F0).withAlpha(242),
  ),
  foreground: const HoloForegroundColors(
    primary: Color(0xFFF0F0F0),
    muted: Color(0xFFABB2BF),
    weak: Color(0xFF767D89),
    disabled: Color(0xFF52575F),
    tooltip: Color(0xFF09090B),
    tooltipMuted: Color(0xFF8F8FA0),
    tooltipLink: Color(0xFF4C52D1),
  ),
  overlay: HoloOverlayColors(
    overlay03: const Color(0xFFF9F9F9).withAlpha(8),
    overlay05: const Color(0xFFF9F9F9).withAlpha(13),
    overlay10: const Color(0xFFF9F9F9).withAlpha(26),
    overlay15: const Color(0xFFF9F9F9).withAlpha(38),
    overlay20: const Color(0xFFF9F9F9).withAlpha(51),
  ),
  accent: HoloAccentColors(
    purple: HoloAccentColorSet(
      primary: const Color(0xFF8C8CEF),
      overlay: const Color(0xFF8C8CEF).withAlpha(26),
      stroke: const Color(0xFF8C8CEF).withAlpha(64),
    ),
    orange: HoloAccentColorSet(
      primary: const Color(0xFFD19A66),
      overlay: const Color(0xFFD19A66).withAlpha(26),
      stroke: const Color(0xFFD19A66).withAlpha(64),
    ),
    green: HoloAccentColorSet(
      primary: const Color(0xFF81B88B),
      overlay: const Color(0xFF81B88B).withAlpha(26),
      stroke: const Color(0xFF81B88B).withAlpha(64),
    ),
    red: HoloAccentColorSet(
      primary: const Color(0xFFE06C75),
      overlay: const Color(0xFFE06C75).withAlpha(26),
      stroke: const Color(0xFFE06C75).withAlpha(64),
    ),
    pink: HoloAccentColorSet(
      primary: const Color(0xFFD18BBA),
      overlay: const Color(0xFFD18BBA).withAlpha(26),
      stroke: const Color(0xFFD18BBA).withAlpha(64),
    ),
    teal: HoloAccentColorSet(
      primary: const Color(0xFF22808D),
      overlay: const Color(0xFF22808D).withAlpha(26),
      stroke: const Color(0xFF22808D).withAlpha(64),
    ),
  ),
  diff: HoloDiffColors(
    addition: const Color(0xFF395955).withAlpha(130),
    removal: const Color(0xFF5A222A).withAlpha(130),
  ),
  stroke: const Color(0xFF373A44),
);
