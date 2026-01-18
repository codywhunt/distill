import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// Standard editor height for property inputs.
const double editorHeight = 30.0;

/// Standard placeholder for empty/unset values.
const String editorEmptyPlaceholder = '-';

/// Standard spacing constants for property editors.
class EditorSpacing {
  EditorSpacing._();

  /// Horizontal padding inside editor containers.
  static const EdgeInsets horizontal = EdgeInsets.symmetric(horizontal: 8);

  /// Padding for multiline text inputs.
  static const EdgeInsets multiline = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 9,
  );

  /// Spacing between prefix/suffix and content.
  static const double slotGap = 0.0;

  /// Approximate line height for text in editors.
  static const double lineHeight = 20.0;

  /// Top offset for label when aligned to multiline input.
  static const double multilineLabelOffset = 7.0;
}

/// Color helpers for editor states.
class EditorColors {
  EditorColors._();

  static Color borderDefault(BuildContext context) =>
      context.colors.overlay.overlay10;

  static Color borderHovered(BuildContext context) =>
      context.colors.overlay.overlay20;

  static Color borderFocused(BuildContext context) =>
      context.colors.accent.purple.primary;

  static Color borderError(BuildContext context) =>
      context.colors.accent.red.primary;

  static Color borderDisabled(BuildContext context) =>
      context.colors.overlay.overlay05;

  /// Get border color based on state (priority: error > disabled > focused > hovered > default).
  static Color getBorderColor(
    BuildContext context, {
    bool hasError = false,
    bool disabled = false,
    bool focused = false,
    bool hovered = false,
  }) {
    if (hasError) return borderError(context);
    if (disabled) return borderDisabled(context);
    if (focused) return borderFocused(context);
    if (hovered) return borderHovered(context);
    return borderDefault(context);
  }
}

/// Text styles for editor content.
class EditorTextStyles {
  EditorTextStyles._();

  static TextStyle input(BuildContext context, {bool disabled = false}) {
    return context.typography.body.medium.copyWith(
      color:
          disabled
              ? context.colors.foreground.disabled
              : context.colors.foreground.primary,
    );
  }

  static TextStyle code(
    BuildContext context, {
    bool disabled = false,
    bool isSet = false,
  }) {
    return isSet
        ? context.typography.mono.small.copyWith(
          color: context.colors.foreground.primary,
        )
        : context.typography.body.medium.copyWith(
          color:
              disabled
                  ? context.colors.foreground.disabled
                  : context.colors.foreground.primary,
        );
  }

  static TextStyle placeholder(BuildContext context, {bool disabled = false}) {
    return context.typography.body.medium.copyWith(
      color:
          disabled
              ? context.colors.foreground.disabled
              : context.colors.foreground.disabled,
    );
  }

  /// Style for "null" placeholder text - mono small.
  static TextStyle nullPlaceholder(
    BuildContext context, {
    bool disabled = false,
  }) {
    return context.typography.mono.small.copyWith(
      color:
          disabled
              ? context.colors.foreground.disabled
              : context.colors.foreground.weak,
      fontSize: 10,
    );
  }

  static TextStyle suffix(BuildContext context) {
    return context.typography.body.small.copyWith(
      color: context.colors.foreground.disabled,
      fontSize: 9.5,
    );
  }
}

/// Text selection theme for editors.
TextSelectionThemeData editorTextSelectionTheme(BuildContext context) {
  return TextSelectionThemeData(
    cursorColor: context.colors.accent.purple.primary,
    selectionColor: context.colors.accent.purple.stroke,
  );
}

/// Border radius helper using design system tokens.
double editorBorderRadius(BuildContext context) => context.radius.md;
