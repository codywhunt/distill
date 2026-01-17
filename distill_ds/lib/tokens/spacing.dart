import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Spacing tokens for consistent margins and padding.
///
/// Access via `context.spacing` extension.
@immutable
class HoloSpacing extends ThemeExtension<HoloSpacing> {
  /// 4px
  final double xxs;

  /// 6px
  final double xs;

  /// 8px
  final double sm;

  /// 10px
  final double md;

  /// 16px
  final double lg;

  /// 24px
  final double xl;

  /// 32px
  final double xxl;

  const HoloSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
  });

  @override
  HoloSpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) {
    return HoloSpacing(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  HoloSpacing lerp(ThemeExtension<HoloSpacing>? other, double t) {
    if (other is! HoloSpacing) return this;
    return HoloSpacing(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
    );
  }
}

/// The default spacing values.
const holoSpacing = HoloSpacing(
  xxs: 4,
  xs: 6,
  sm: 8,
  md: 10,
  lg: 16,
  xl: 24,
  xxl: 32,
);

