import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import 'editor_styling.dart';
import 'mixins/hover_state_mixin.dart';

/// The shared chrome container for all property editor inputs.
///
/// Provides consistent styling across all input types:
/// - Standard height (28px)
/// - Border with hover/focus/error states
/// - Optional prefix and suffix widget slots
///
/// Example usage:
/// ```dart
/// EditorInputContainer(
///   prefix: ColorSquare(color: selectedColor),
///   suffix: Text('px'),
///   focusNode: _myFocusNode, // Clicking container focuses this node
///   child: TextField(...),
/// )
/// ```
class EditorInputContainer extends StatefulWidget {
  /// The main content widget (text field, display text, etc.).
  final Widget child;

  /// Optional prefix widget (e.g., color square, icon).
  final Widget? prefix;

  /// Optional suffix widget (e.g., units text, dropdown arrow).
  final Widget? suffix;

  /// Called when the container is tapped (for button-style inputs).
  final VoidCallback? onTap;

  /// Optional focus node to request focus when container is tapped.
  /// This allows clicking anywhere in the container to focus the input.
  final FocusNode? focusNode;

  /// Whether the input is currently focused.
  final bool focused;

  /// Whether the input is disabled (blocks interaction).
  final bool disabled;

  /// Whether the input has a validation error.
  final bool hasError;

  const EditorInputContainer({
    super.key,
    required this.child,
    this.prefix,
    this.suffix,
    this.onTap,
    this.focusNode,
    this.focused = false,
    this.disabled = false,
    this.hasError = false,
  });

  @override
  State<EditorInputContainer> createState() => _EditorInputContainerState();
}

class _EditorInputContainerState extends State<EditorInputContainer>
    with HoverStateMixin {
  @override
  bool get isHoverDisabled => widget.disabled;

  void _handleTap() {
    if (widget.disabled) return;

    // Request focus if a focus node is provided
    widget.focusNode?.requestFocus();

    // Call onTap callback if provided
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: onHoverEnter,
      onExit: onHoverExit,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: editorHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(editorBorderRadius(context)),
            border: Border.all(
              color: EditorColors.getBorderColor(
                context,
                hasError: widget.hasError,
                disabled: widget.disabled,
                focused: widget.focused,
                hovered: isHovered,
              ),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              if (widget.prefix != null) ...[
                Padding(
                  padding: EdgeInsets.only(left: context.spacing.xxs + 1),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: widget.prefix,
                  ),
                ),
                const SizedBox(width: EditorSpacing.slotGap),
              ],
              Expanded(child: widget.child),
              if (widget.suffix != null) ...[
                const SizedBox(width: EditorSpacing.slotGap),
                Padding(
                  padding: EdgeInsets.only(right: context.spacing.xxs),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: widget.suffix,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
