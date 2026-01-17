import 'package:flutter/material.dart';

import 'resizable_panel.dart';

/// Wrapper that animates panel show/hide with smooth width transitions.
///
/// Uses [SizeTransition] for GPU-accelerated animations.
/// Animations can be disabled via [animate] (e.g., during context switches).
class AnimatedPanelWrapper extends StatefulWidget {
  const AnimatedPanelWrapper({
    super.key,
    required this.isVisible,
    required this.child,
    required this.position,
    this.animate = true,
  });

  /// Whether the panel is currently visible.
  final bool isVisible;

  /// The panel content to wrap.
  final Widget child;

  /// Position determines collapse direction.
  /// - [DragHandlePosition.right]: Left panel, collapses left
  /// - [DragHandlePosition.left]: Right panel, collapses right
  final DragHandlePosition position;

  /// Whether to animate visibility changes.
  /// Set to false during context switches to avoid jarring transitions.
  final bool animate;

  @override
  State<AnimatedPanelWrapper> createState() => _AnimatedPanelWrapperState();
}

class _AnimatedPanelWrapperState extends State<AnimatedPanelWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Set initial state without animation
    if (widget.isVisible) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedPanelWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.animate) {
        // Animate the transition
        widget.isVisible ? _controller.forward() : _controller.reverse();
      } else {
        // Instant change without animation
        _controller.value = widget.isVisible ? 1.0 : 0.0;
      }
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine collapse direction based on panel position
    // Left panels (with right handle) collapse to left: -1.0
    // Right panels (with left handle) collapse to right: 1.0
    final axisAlignment =
        widget.position == DragHandlePosition.right ? -1.0 : 1.0;

    return ClipRect(
      child: SizeTransition(
        sizeFactor: _animation,
        axis: Axis.horizontal,
        axisAlignment: axisAlignment,
        child: widget.child,
      ),
    );
  }
}

