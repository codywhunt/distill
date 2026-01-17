import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Border radius tokens for consistent rounding.
///
/// Access via `context.radius` extension.
@immutable
class HoloRadius extends ThemeExtension<HoloRadius> {
  /// 2px
  final double xxs;

  /// 4px
  final double xs;

  /// 6px
  final double sm;

  /// 8px
  final double md;

  /// 10px
  final double lg;

  /// 12px
  final double xl;

  /// 14px
  final double xxl;

  /// 9999px - for fully rounded (pill) shapes
  final double full;

  const HoloRadius({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.full,
  });

  @override
  HoloRadius copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? full,
  }) {
    return HoloRadius(
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      full: full ?? this.full,
    );
  }

  @override
  HoloRadius lerp(ThemeExtension<HoloRadius>? other, double t) {
    if (other is! HoloRadius) return this;
    return HoloRadius(
      xxs: lerpDouble(xxs, other.xxs, t)!,
      xs: lerpDouble(xs, other.xs, t)!,
      sm: lerpDouble(sm, other.sm, t)!,
      md: lerpDouble(md, other.md, t)!,
      lg: lerpDouble(lg, other.lg, t)!,
      xl: lerpDouble(xl, other.xl, t)!,
      xxl: lerpDouble(xxl, other.xxl, t)!,
      full: lerpDouble(full, other.full, t)!,
    );
  }
}

/// The default border radius values.
const holoRadius = HoloRadius(
  xxs: 2,
  xs: 4,
  sm: 6,
  md: 8,
  lg: 10,
  xl: 12,
  xxl: 14,
  full: 9999,
);

