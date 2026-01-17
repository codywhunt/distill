import 'package:flutter/material.dart';

/// Animation and motion tokens for consistent timing and curves.
///
/// Access via `context.motion` extension.
///
/// Example:
/// ```dart
/// AnimatedContainer(
///   duration: context.motion.normal,
///   curve: context.motion.standard,
///   // ...
/// )
/// ```
@immutable
class HoloMotion extends ThemeExtension<HoloMotion> {
  // ─────────────────────────────────────────────────────────────────────────
  // Durations
  // ─────────────────────────────────────────────────────────────────────────

  /// Very fast transitions (50ms) - for micro-interactions like hover states.
  final Duration instant;

  /// Fast transitions (100ms) - for quick feedback like button presses.
  final Duration fast;

  /// Normal transitions (200ms) - standard UI transitions.
  final Duration normal;

  /// Slow transitions (300ms) - for larger or more important changes.
  final Duration slow;

  /// Very slow transitions (500ms) - for dramatic or page-level transitions.
  final Duration slower;

  // ─────────────────────────────────────────────────────────────────────────
  // Curves
  // ─────────────────────────────────────────────────────────────────────────

  /// Standard curve for most animations - ease out for natural deceleration.
  final Curve standard;

  /// Emphasized curve for attention-grabbing animations.
  final Curve emphasize;

  /// Deceleration curve for entering elements.
  final Curve enter;

  /// Acceleration curve for exiting elements.
  final Curve exit;

  /// Linear curve for progress indicators and loading states.
  final Curve linear;

  /// Bounce curve for playful interactions.
  final Curve bounce;

  const HoloMotion({
    required this.instant,
    required this.fast,
    required this.normal,
    required this.slow,
    required this.slower,
    required this.standard,
    required this.emphasize,
    required this.enter,
    required this.exit,
    required this.linear,
    required this.bounce,
  });

  @override
  HoloMotion copyWith({
    Duration? instant,
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Duration? slower,
    Curve? standard,
    Curve? emphasize,
    Curve? enter,
    Curve? exit,
    Curve? linear,
    Curve? bounce,
  }) {
    return HoloMotion(
      instant: instant ?? this.instant,
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      slower: slower ?? this.slower,
      standard: standard ?? this.standard,
      emphasize: emphasize ?? this.emphasize,
      enter: enter ?? this.enter,
      exit: exit ?? this.exit,
      linear: linear ?? this.linear,
      bounce: bounce ?? this.bounce,
    );
  }

  @override
  HoloMotion lerp(ThemeExtension<HoloMotion>? other, double t) {
    // Motion tokens don't interpolate meaningfully
    return this;
  }
}

/// The default motion values.
const holoMotion = HoloMotion(
  // Durations
  instant: Duration(milliseconds: 50),
  fast: Duration(milliseconds: 100),
  normal: Duration(milliseconds: 200),
  slow: Duration(milliseconds: 300),
  slower: Duration(milliseconds: 500),

  // Curves
  standard: Curves.easeOutCubic,
  emphasize: Curves.easeInOutCubic,
  enter: Curves.decelerate,
  exit: Curves.easeInCubic,
  linear: Curves.linear,
  bounce: Curves.elasticOut,
);

