import 'package:flutter/material.dart';

import '../foundation/state_value.dart';
import '../tokens/theme.dart';

/// Style configuration for [HoloButton].
///
/// Use predefined factory constructors for common variants, or create
/// a custom style with state-aware properties.
///
/// Example:
/// ```dart
/// // Predefined variant
/// HoloButton(
///   label: 'Delete',
///   style: HoloButtonStyle.destructive(context),
/// )
///
/// // Custom style with state colors
/// HoloButton(
///   label: 'Custom',
///   style: HoloButtonStyle(
///     backgroundColor: context.colors.accent.green.primary.states(
///       hovered: context.colors.accent.green.primary.withOpacity(0.9),
///       pressed: context.colors.accent.green.primary.withOpacity(0.8),
///     ),
///   ),
/// )
/// ```
@immutable
class HoloButtonStyle {
  /// The background color, optionally varying by state.
  final StateValue<Color>? backgroundColor;

  /// The foreground (text/icon) color, optionally varying by state.
  final StateValue<Color>? foregroundColor;

  /// The border color, optionally varying by state.
  final StateValue<Color>? borderColor;

  /// The border width.
  final double? borderWidth;

  /// The border radius.
  final double? borderRadius;

  /// The padding inside the button.
  final EdgeInsets? padding;

  /// The minimum size of the button.
  final Size? minimumSize;

  /// The text style for the button label.
  final TextStyle? textStyle;

  /// The icon size.
  final double? iconSize;

  /// The gap between icon and label.
  final double? iconGap;

  /// Creates a custom button style.
  const HoloButtonStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.minimumSize,
    this.textStyle,
    this.iconSize,
    this.iconGap,
  });

  /// Creates a primary filled button style.
  ///
  /// This is the main call-to-action button with a solid purple background.
  factory HoloButtonStyle.primary(BuildContext context) {
    final colors = context.colors;

    return HoloButtonStyle(
      backgroundColor: colors.accent.purple.primary.states(
        hovered: colors.accent.purple.primary.withValues(alpha: 0.9),
        pressed: colors.accent.purple.primary.withValues(alpha: 0.8),
        disabled: colors.overlay.overlay05,
      ),
      foregroundColor: const StateValue.all(Colors.white),
      borderRadius: context.radius.sm,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.sm,
      ),
    );
  }

  /// Creates a secondary button style.
  ///
  /// A subtle button with a light background overlay.
  factory HoloButtonStyle.secondary(BuildContext context) {
    final colors = context.colors;

    return HoloButtonStyle(
      backgroundColor: colors.overlay.overlay05.states(
        hovered: colors.overlay.overlay10,
        pressed: colors.overlay.overlay15,
        disabled: colors.overlay.overlay03,
      ),
      foregroundColor: colors.foreground.muted.states(
        hovered: colors.foreground.primary,
        disabled: colors.foreground.disabled,
      ),
      borderRadius: context.radius.sm,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.sm,
      ),
    );
  }

  /// Creates a destructive button style.
  ///
  /// Used for dangerous actions like delete.
  factory HoloButtonStyle.destructive(BuildContext context) {
    final colors = context.colors;

    return HoloButtonStyle(
      backgroundColor: colors.accent.red.primary.states(
        hovered: colors.accent.red.primary.withValues(alpha: 0.9),
        pressed: colors.accent.red.primary.withValues(alpha: 0.8),
        disabled: colors.overlay.overlay05,
      ),
      foregroundColor: const StateValue.all(Colors.white),
      borderRadius: context.radius.sm,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.sm,
      ),
    );
  }

  /// Creates an outline button style.
  ///
  /// A button with a border and transparent background.
  factory HoloButtonStyle.outline(BuildContext context) {
    final colors = context.colors;

    return HoloButtonStyle(
      backgroundColor: Colors.transparent.states(
        hovered: colors.overlay.overlay05,
        pressed: colors.overlay.overlay10,
      ),
      foregroundColor: colors.foreground.muted.states(
        hovered: colors.foreground.primary,
        disabled: colors.foreground.disabled,
      ),
      borderColor: colors.overlay.overlay15.states(
        hovered: colors.overlay.overlay20,
        focused: colors.accent.purple.primary,
        disabled: colors.overlay.overlay10,
      ),
      borderWidth: 1,
      borderRadius: context.radius.sm,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.sm,
      ),
    );
  }

  /// Creates a ghost button style.
  ///
  /// A minimal button with no background until hovered.
  factory HoloButtonStyle.ghost(BuildContext context) {
    final colors = context.colors;

    return HoloButtonStyle(
      backgroundColor: Colors.transparent.states(
        hovered: colors.overlay.overlay05,
        pressed: colors.overlay.overlay10,
      ),
      foregroundColor: colors.foreground.muted.states(
        hovered: colors.foreground.primary,
        disabled: colors.foreground.disabled,
      ),
      borderRadius: context.radius.sm,
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.xs,
      ),
    );
  }

  /// Creates a copy of this style with the given fields replaced.
  HoloButtonStyle copyWith({
    StateValue<Color>? backgroundColor,
    StateValue<Color>? foregroundColor,
    StateValue<Color>? borderColor,
    double? borderWidth,
    double? borderRadius,
    EdgeInsets? padding,
    Size? minimumSize,
    TextStyle? textStyle,
    double? iconSize,
    double? iconGap,
  }) {
    return HoloButtonStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      padding: padding ?? this.padding,
      minimumSize: minimumSize ?? this.minimumSize,
      textStyle: textStyle ?? this.textStyle,
      iconSize: iconSize ?? this.iconSize,
      iconGap: iconGap ?? this.iconGap,
    );
  }

  /// Merges this style with another, with [other] taking precedence.
  HoloButtonStyle merge(HoloButtonStyle? other) {
    if (other == null) return this;
    return HoloButtonStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      borderColor: other.borderColor ?? borderColor,
      borderWidth: other.borderWidth ?? borderWidth,
      borderRadius: other.borderRadius ?? borderRadius,
      padding: other.padding ?? padding,
      minimumSize: other.minimumSize ?? minimumSize,
      textStyle: other.textStyle ?? textStyle,
      iconSize: other.iconSize ?? iconSize,
      iconGap: other.iconGap ?? iconGap,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HoloButtonStyle &&
        other.backgroundColor == backgroundColor &&
        other.foregroundColor == foregroundColor &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.borderRadius == borderRadius &&
        other.padding == padding &&
        other.minimumSize == minimumSize &&
        other.textStyle == textStyle &&
        other.iconSize == iconSize &&
        other.iconGap == iconGap;
  }

  @override
  int get hashCode => Object.hash(
    backgroundColor,
    foregroundColor,
    borderColor,
    borderWidth,
    borderRadius,
    padding,
    minimumSize,
    textStyle,
    iconSize,
    iconGap,
  );
}
