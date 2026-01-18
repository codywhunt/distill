import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../foundation/tappable.dart';
import '../../tokens/theme.dart';

/// A trigger button for select/dropdown components.
///
/// Styled as a pill-shaped button with optional leading icon,
/// label text, and trailing chevron. Matches the forui/shadcn style.
///
/// Example:
/// ```dart
/// HoloSelectTrigger(
///   label: 'iPhone 16 Pro Max',
///   leadingIcon: LucideIcons.smartphone,
///   isOpen: controller.isOpen,
///   onTap: controller.toggle,
/// )
/// ```
class HoloSelectTrigger extends StatelessWidget {
  /// The label text to display.
  final String label;

  /// An optional leading icon.
  final IconData? leadingIcon;

  /// Whether the associated popover is currently open.
  ///
  /// Affects the chevron rotation and visual state.
  final bool isOpen;

  /// Called when the trigger is tapped.
  final VoidCallback? onTap;

  /// Whether the trigger is disabled.
  final bool isDisabled;

  /// The width of the trigger.
  ///
  /// If null, sizes to fit content.
  final double? width;

  /// Placeholder text style when no value is selected.
  final bool isPlaceholder;

  /// Whether the trigger should expand to fill available width.
  ///
  /// When true, the label and chevron are spaced apart (label left, chevron right).
  /// When false (default), the trigger sizes to fit content with minimal gap.
  ///
  /// Use `expand: true` in contexts like property panels where the trigger
  /// should fill its container. Use `expand: false` (default) for compact
  /// buttons like zoom controls.
  final bool expand;

  const HoloSelectTrigger({
    super.key,
    required this.label,
    this.leadingIcon,
    this.isOpen = false,
    this.onTap,
    this.isDisabled = false,
    this.width,
    this.isPlaceholder = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return HoloTappable(
      onTap: onTap,
      enabled: !isDisabled,
      cursor: SystemMouseCursors.basic,
      builder: (context, states, _) {
        final isHighlighted = states.isHovered || states.isFocused || isOpen;

        Color bgColor;
        Color borderColor;
        Color fgColor;

        if (states.isDisabled) {
          bgColor = colors.overlay.overlay03;
          borderColor = colors.stroke;
          fgColor = colors.foreground.disabled;
        } else if (isHighlighted) {
          bgColor = colors.background.fullContrast;
          borderColor = colors.overlay.overlay10;
          fgColor = colors.foreground.primary;
        } else {
          bgColor = colors.background.primary;
          borderColor = colors.overlay.overlay10;
          fgColor =
              isPlaceholder
                  ? colors.foreground.muted
                  : colors.foreground.primary;
        }

        return Container(
          width: width,
          height: 30,
          padding: const EdgeInsets.only(left: 10, right: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(context.radius.md),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize:
                (width != null || expand) ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading icon
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 13, color: fgColor),
                const SizedBox(width: 4),
              ],

              // Label
              if (expand)
                Expanded(
                  child: Text(
                    label,
                    style: context.typography.body.medium.copyWith(
                      color: fgColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
              else
                Flexible(
                  child: Text(
                    label,
                    style: context.typography.body.medium.copyWith(
                      color: fgColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),

              const SizedBox(width: 6),

              // Chevron
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: context.motion.normal,
                  curve: context.motion.standard,
                  child: Icon(
                    LucideIcons.chevronDown200,
                    size: 14,
                    color: colors.foreground.disabled,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
