import 'package:flutter/material.dart';

/// Mixin that provides hover state tracking for interactive widgets.
///
/// This mixin extracts the common pattern of tracking mouse hover state,
/// with proper handling of disabled states and mounted checks.
///
/// Usage:
/// ```dart
/// class _MyInputState extends State<MyInput> with HoverStateMixin {
///   @override
///   bool get isHoverDisabled => widget.disabled;
///
///   @override
///   Widget build(BuildContext context) {
///     return MouseRegion(
///       onEnter: onHoverEnter,
///       onExit: onHoverExit,
///       child: Container(
///         decoration: BoxDecoration(
///           border: Border.all(
///             color: isHovered ? Colors.blue : Colors.grey,
///           ),
///         ),
///         child: widget.child,
///       ),
///     );
///   }
/// }
/// ```
mixin HoverStateMixin<T extends StatefulWidget> on State<T> {
  /// Whether the widget is currently being hovered.
  bool isHovered = false;

  /// Override to provide the disabled state from your widget.
  ///
  /// When true, hover events are ignored and [isHovered] remains false.
  bool get isHoverDisabled;

  /// Sets the hover state if not disabled and mounted.
  void setHovered(bool value) {
    if (isHoverDisabled || !mounted) return;
    setState(() => isHovered = value);
  }

  /// Handler for [MouseRegion.onEnter]. Pass directly to MouseRegion.
  ///
  /// Returns null if disabled (for conditional assignment).
  void Function(PointerEvent)? get onHoverEnter =>
      isHoverDisabled ? null : (_) => setHovered(true);

  /// Handler for [MouseRegion.onExit]. Pass directly to MouseRegion.
  ///
  /// Returns null if disabled (for conditional assignment).
  void Function(PointerEvent)? get onHoverExit =>
      isHoverDisabled ? null : (_) => setHovered(false);
}
