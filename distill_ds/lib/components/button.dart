import 'package:flutter/material.dart';

import '../foundation/state_value.dart';
import '../foundation/tappable.dart';
import '../foundation/widget_states.dart';
import '../styles/button_style.dart';
import '../tokens/theme.dart';
import 'icon.dart';

/// A customizable button component built on [HoloTappable].
///
/// [HoloButton] provides a consistent button experience with built-in
/// support for loading states, icons, and state-aware styling.
///
/// Example:
/// ```dart
/// // Simple usage
/// HoloButton(
///   label: 'Save',
///   onPressed: () => save(),
/// )
///
/// // With icon (LucideIcons)
/// HoloButton(
///   label: 'Add Item',
///   icon: LucideIcons.plus.holo,
///   onPressed: () => addItem(),
/// )
///
/// // With HugeIcons
/// HoloButton(
///   label: 'Add Item',
///   icon: HoloIconData.huge(HugeIconsStrokeRounded.add01),
///   onPressed: () => addItem(),
/// )
///
/// // With predefined style variant
/// HoloButton(
///   label: 'Delete',
///   style: HoloButtonStyle.destructive(context),
///   onPressed: () => delete(),
/// )
///
/// // With custom state colors
/// HoloButton(
///   label: 'Custom',
///   backgroundColor: context.colors.accent.green.primary.states(
///     hovered: context.colors.accent.green.primary.withOpacity(0.9),
///   ),
///   onPressed: () {},
/// )
/// ```
class HoloButton extends StatelessWidget {
  /// The button label text.
  final String? label;

  /// An icon to display in the button.
  ///
  /// Supports both standard [IconData] and HugeIcons via [HoloIconData]:
  /// ```dart
  /// icon: LucideIcons.plus.holo  // LucideIcons
  /// icon: HoloIconData.huge(HugeIconsStrokeRounded.add01)  // HugeIcons
  /// ```
  final HoloIconData? icon;

  /// Called when the button is pressed.
  final VoidCallback? onPressed;

  /// The button style configuration.
  ///
  /// Use predefined variants like [HoloButtonStyle.primary] or create
  /// a custom style.
  final HoloButtonStyle? style;

  /// Whether the button is in a loading state.
  ///
  /// When true, displays a loading indicator and disables interaction.
  final bool isLoading;

  /// Whether the button is disabled.
  final bool isDisabled;

  // ─────────────────────────────────────────────────────────────────────────
  // Convenience color properties (override style if provided)
  // ─────────────────────────────────────────────────────────────────────────

  /// Direct background color that wraps in a [StateValue] with auto states.
  ///
  /// If you need custom per-state colors, use [backgroundColorStates] instead.
  final Color? backgroundColor;

  /// State-aware background colors.
  final StateColor? backgroundColorStates;

  /// Direct foreground color that wraps in a [StateValue] with auto states.
  final Color? foregroundColor;

  /// State-aware foreground colors.
  final StateColor? foregroundColorStates;

  /// The scale factor when pressed.
  ///
  /// Defaults to [HoloTappable.defaultPressScale] (0.95).
  /// Set to `null` to disable the press animation.
  final double? pressScale;

  /// Creates a [HoloButton].
  const HoloButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.style,
    this.isLoading = false,
    this.isDisabled = false,
    this.backgroundColor,
    this.backgroundColorStates,
    this.foregroundColor,
    this.foregroundColorStates,
    this.pressScale = HoloTappable.defaultPressScale,
  }) : assert(
         label != null || icon != null,
         'Either label or icon must be provided',
       );

  /// Creates a primary button.
  factory HoloButton.primary({
    Key? key,
    String? label,
    HoloIconData? icon,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool isDisabled = false,
  }) {
    return HoloButton(
      key: key,
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      isDisabled: isDisabled,
      // Style will be resolved in build using context
    );
  }

  bool get _isInteractive => !isDisabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    // Resolve the effective style
    final effectiveStyle = _resolveStyle(context);

    return HoloTappable(
      onTap: _isInteractive ? onPressed : null,
      cursor: SystemMouseCursors.basic,
      enabled: _isInteractive,
      pressScale: pressScale,
      builder:
          (context, states, _) => _buildButton(context, states, effectiveStyle),
    );
  }

  HoloButtonStyle _resolveStyle(BuildContext context) {
    // Start with the provided style or secondary as default
    final baseStyle = style ?? HoloButtonStyle.secondary(context);

    // Apply convenience color overrides
    StateColor? bgColor = backgroundColorStates;
    if (bgColor == null && backgroundColor != null) {
      bgColor = backgroundColor!.states(
        hovered: backgroundColor!.withValues(alpha: 0.9),
        pressed: backgroundColor!.withValues(alpha: 0.8),
        disabled: context.colors.overlay.overlay05,
      );
    }

    StateColor? fgColor = foregroundColorStates;
    if (fgColor == null && foregroundColor != null) {
      fgColor = foregroundColor!.states(
        disabled: context.colors.foreground.disabled,
      );
    }

    if (bgColor != null || fgColor != null) {
      return baseStyle.copyWith(
        backgroundColor: bgColor ?? baseStyle.backgroundColor,
        foregroundColor: fgColor ?? baseStyle.foregroundColor,
      );
    }

    return baseStyle;
  }

  Widget _buildButton(
    BuildContext context,
    WidgetStates states,
    HoloButtonStyle effectiveStyle,
  ) {
    // Resolve state-dependent values
    final bgColor =
        effectiveStyle.backgroundColor?.resolve(states) ??
        context.colors.overlay.overlay05;
    final fgColor =
        effectiveStyle.foregroundColor?.resolve(states) ??
        context.colors.foreground.primary;
    final borderColor = effectiveStyle.borderColor?.resolve(states);
    final borderWidth = effectiveStyle.borderWidth ?? 0;
    final borderRadius = effectiveStyle.borderRadius ?? context.radius.sm;
    final padding =
        effectiveStyle.padding ??
        EdgeInsets.symmetric(
          horizontal: context.spacing.lg,
          vertical: context.spacing.sm,
        );
    final textStyle =
        effectiveStyle.textStyle ?? context.typography.body.mediumStrong;
    final iconSize = effectiveStyle.iconSize ?? 16.0;
    final iconGap = effectiveStyle.iconGap ?? context.spacing.sm;

    return AnimatedContainer(
      duration: context.motion.fast,
      curve: context.motion.standard,
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border:
            borderColor != null && borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
      ),
      child: _buildContent(context, fgColor, textStyle, iconSize, iconGap),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Color fgColor,
    TextStyle textStyle,
    double iconSize,
    double iconGap,
  ) {
    if (isLoading) {
      return SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(fgColor),
        ),
      );
    }

    final hasIcon = icon != null;
    final hasLabel = label != null;

    if (hasIcon && hasLabel) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HoloIcon(icon!, size: iconSize, color: fgColor),
          SizedBox(width: iconGap),
          Text(label!, style: textStyle.copyWith(color: fgColor)),
        ],
      );
    }

    if (hasIcon) {
      return HoloIcon(icon!, size: iconSize, color: fgColor);
    }

    return Text(label!, style: textStyle.copyWith(color: fgColor));
  }
}

/// An icon-only button variant.
///
/// A compact button that displays only an icon.
///
/// Supports both standard [IconData] and HugeIcons via [HoloIconData]:
/// ```dart
/// HoloIconButton(icon: LucideIcons.plus.holo)
/// HoloIconButton(icon: HoloIconData.huge(HugeIconsStrokeRounded.add01))
/// ```
class HoloIconButton extends StatelessWidget {
  /// The icon to display.
  final HoloIconData icon;

  /// Called when the button is pressed.
  final VoidCallback? onPressed;

  /// The button style.
  final HoloButtonStyle? style;

  /// The size of the button (width and height).
  final double? size;

  /// The size of the icon.
  final double? iconSize;

  /// Whether the button is disabled.
  final bool isDisabled;

  /// An optional tooltip message.
  final String? tooltip;

  /// The scale factor when pressed.
  ///
  /// Defaults to [HoloTappable.defaultPressScale] (0.95).
  /// Set to `null` to disable the press animation.
  final double? pressScale;

  /// Creates a [HoloIconButton].
  const HoloIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.style,
    this.size,
    this.iconSize,
    this.isDisabled = false,
    this.tooltip,
    this.pressScale = HoloTappable.defaultPressScale,
  });

  bool get _isInteractive => !isDisabled && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? 32.0;
    final effectiveIconSize = iconSize ?? 16.0;
    final effectiveStyle = style ?? HoloButtonStyle.ghost(context);

    Widget button = HoloTappable(
      onTap: _isInteractive ? onPressed : null,
      cursor: SystemMouseCursors.basic,
      enabled: _isInteractive,
      pressScale: pressScale,
      builder: (context, states, _) {
        final bgColor =
            effectiveStyle.backgroundColor?.resolve(states) ??
            Colors.transparent;
        final fgColor =
            effectiveStyle.foregroundColor?.resolve(states) ??
            context.colors.foreground.muted;
        final borderColor = effectiveStyle.borderColor?.resolve(states);
        final borderWidth = effectiveStyle.borderWidth ?? 0;
        final borderRadius = effectiveStyle.borderRadius ?? context.radius.xs;

        return Container(
          width: effectiveSize,
          height: effectiveSize,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border:
                borderColor != null && borderWidth > 0
                    ? Border.all(color: borderColor, width: borderWidth)
                    : null,
          ),
          child: Center(
            child: HoloIcon(icon, size: effectiveIconSize, color: fgColor),
          ),
        );
      },
    );

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
