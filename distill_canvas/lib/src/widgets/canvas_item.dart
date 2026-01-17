import 'package:flutter/material.dart';

/// Positions a child widget at a world-space location.
///
/// Use this inside the `content` layer of [CanvasLayers]. The content layer
/// is automatically transformed by the camera, so positions here are in
/// world-space coordinates.
///
/// ## Basic Usage
///
/// ```dart
/// content: (ctx, ctrl) => Stack(
///   clipBehavior: Clip.none,
///   children: nodes.map((node) => CanvasItem(
///     position: node.position,
///     size: node.size,
///     child: NodeWidget(node),
///   )).toList(),
/// )
/// ```
///
/// ## With Culling
///
/// For better performance with many items, cull items outside the viewport:
///
/// ```dart
/// content: (ctx, ctrl) {
///   final visible = ctrl.getVisibleWorldBounds(MediaQuery.sizeOf(ctx));
///   return Stack(
///     clipBehavior: Clip.none,
///     children: nodes
///       .where((n) => visible.overlaps(n.bounds))
///       .map((n) => CanvasItem(
///         position: n.position,
///         size: n.size,
///         child: NodeWidget(n),
///       ))
///       .toList(),
///   );
/// }
/// ```
class CanvasItem extends StatelessWidget {
  const CanvasItem({
    super.key,
    required this.position,
    this.size,
    required this.child,
  });

  /// Top-left position in world-space coordinates.
  final Offset position;

  /// Size in world-space units.
  ///
  /// If null, the child sizes itself and the CanvasItem will be
  /// positioned but not constrained.
  final Size? size;

  /// The widget to render at this position.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (size != null) {
      return Positioned(
        left: position.dx,
        top: position.dy,
        width: size!.width,
        height: size!.height,
        child: child,
      );
    }

    return Positioned(left: position.dx, top: position.dy, child: child);
  }
}
