import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';

import '../../models/node_layout.dart';
import '../../../../modules/canvas/canvas_state.dart';
import '../drag_session.dart';

/// Blue line showing where dragged node will be inserted in auto-layout.
///
/// Renders a Figma-style insertion indicator (blue line) at the calculated
/// insertion index within the drop target container.
class InsertionIndicatorOverlay extends StatelessWidget {
  const InsertionIndicatorOverlay({
    required this.state,
    required this.controller,
    super.key,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final session = state.dragSession;

    // Only show during move drag with valid drop target
    if (session == null ||
        session.mode != DragMode.move ||
        session.dropTarget == null ||
        session.dropFrameId == null ||
        session.insertionIndex == null) {
      return const SizedBox.shrink();
    }

    final indicator = _calculateIndicatorBounds(
      session.dropFrameId!,
      session.dropTarget!,
      session.insertionIndex!,
    );

    if (indicator == null) return const SizedBox.shrink();

    // Convert to view coordinates
    final viewBounds = controller.worldToViewRect(indicator.bounds);

    return CustomPaint(
      painter: InsertionLinePainter(bounds: viewBounds, axis: indicator.axis),
    );
  }

  /// Calculate world bounds for insertion indicator line.
  _IndicatorBounds? _calculateIndicatorBounds(
    String frameId,
    String parentId,
    int insertionIndex,
  ) {
    final parent = state.document.nodes[parentId];
    if (parent?.layout.autoLayout == null) return null;

    final frame = state.document.frames[frameId];
    if (frame == null) return null;

    final direction = parent!.layout.autoLayout!.direction;
    final parentBounds = _getParentBounds(frameId, parentId);
    if (parentBounds == null) return null;

    // Convert parent bounds to world coordinates
    final parentWorld = Rect.fromLTWH(
      frame.canvas.position.dx + parentBounds.left,
      frame.canvas.position.dy + parentBounds.top,
      parentBounds.width,
      parentBounds.height,
    );

    // Get padding
    final padding = parent.layout.autoLayout!.padding;

    // Calculate indicator position based on insertion index
    Rect indicatorBounds;

    if (insertionIndex == 0) {
      // Insert at beginning (after padding)
      if (direction == LayoutDirection.horizontal) {
        indicatorBounds = Rect.fromLTWH(
          parentWorld.left + padding.left.toDouble(),
          parentWorld.top + padding.top.toDouble(),
          2, // Line width
          parentWorld.height -
              padding.top.toDouble() -
              padding.bottom.toDouble(),
        );
      } else {
        indicatorBounds = Rect.fromLTWH(
          parentWorld.left + padding.left.toDouble(),
          parentWorld.top + padding.top.toDouble(),
          parentWorld.width -
              padding.left.toDouble() -
              padding.right.toDouble(),
          2, // Line height
        );
      }
    } else if (insertionIndex >= parent.childIds.length) {
      // Insert at end (before padding)
      final lastChildId = parent.childIds.last;
      final lastBounds = _getChildBounds(frameId, parentId, lastChildId);

      if (lastBounds == null) return null;

      // Convert to world
      final lastWorld = Rect.fromLTWH(
        frame.canvas.position.dx + lastBounds.left,
        frame.canvas.position.dy + lastBounds.top,
        lastBounds.width,
        lastBounds.height,
      );

      final gap = parent.layout.autoLayout!.gap?.toDouble() ?? 0;

      if (direction == LayoutDirection.horizontal) {
        indicatorBounds = Rect.fromLTWH(
          lastWorld.right + gap,
          parentWorld.top + padding.top.toDouble(),
          2,
          parentWorld.height -
              padding.top.toDouble() -
              padding.bottom.toDouble(),
        );
      } else {
        indicatorBounds = Rect.fromLTWH(
          parentWorld.left + padding.left.toDouble(),
          lastWorld.bottom + gap,
          parentWorld.width -
              padding.left.toDouble() -
              padding.right.toDouble(),
          2,
        );
      }
    } else {
      // Insert between children
      final prevChildId = parent.childIds[insertionIndex - 1];
      final prevBounds = _getChildBounds(frameId, parentId, prevChildId);

      if (prevBounds == null) return null;

      final prevWorld = Rect.fromLTWH(
        frame.canvas.position.dx + prevBounds.left,
        frame.canvas.position.dy + prevBounds.top,
        prevBounds.width,
        prevBounds.height,
      );

      final gap = parent.layout.autoLayout!.gap?.toDouble() ?? 0;

      if (direction == LayoutDirection.horizontal) {
        indicatorBounds = Rect.fromLTWH(
          prevWorld.right + gap / 2,
          parentWorld.top + padding.top.toDouble(),
          2,
          parentWorld.height -
              padding.top.toDouble() -
              padding.bottom.toDouble(),
        );
      } else {
        indicatorBounds = Rect.fromLTWH(
          parentWorld.left + padding.left.toDouble(),
          prevWorld.bottom + gap / 2,
          parentWorld.width -
              padding.left.toDouble() -
              padding.right.toDouble(),
          2,
        );
      }
    }

    return _IndicatorBounds(
      bounds: indicatorBounds,
      axis: direction == LayoutDirection.horizontal
          ? Axis.vertical
          : Axis.horizontal,
    );
  }

  /// Get parent bounds in frame-local coordinates.
  Rect? _getParentBounds(String frameId, String parentId) {
    final scene = state.getExpandedScene(frameId);
    if (scene == null) return null;

    // Find expanded ID for this parent
    String? parentExpandedId;
    for (final entry in scene.patchTarget.entries) {
      if (entry.value == parentId) {
        parentExpandedId = entry.key;
        break;
      }
    }

    if (parentExpandedId == null) return null;
    return state.getNodeBounds(frameId, parentExpandedId);
  }

  /// Get child bounds in frame-local coordinates.
  Rect? _getChildBounds(String frameId, String parentId, String childId) {
    final scene = state.getExpandedScene(frameId);
    if (scene == null) return null;

    // Find expanded ID for this child
    String? childExpandedId;
    for (final entry in scene.patchTarget.entries) {
      if (entry.value == childId) {
        childExpandedId = entry.key;
        break;
      }
    }

    if (childExpandedId == null) return null;
    return state.getNodeBounds(frameId, childExpandedId);
  }
}

/// Bounds and axis for insertion indicator line.
class _IndicatorBounds {
  final Rect bounds;
  final Axis axis;

  _IndicatorBounds({required this.bounds, required this.axis});
}

/// Custom painter for the insertion indicator line.
class InsertionLinePainter extends CustomPainter {
  final Rect bounds;
  final Axis axis;

  InsertionLinePainter({required this.bounds, required this.axis});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw a thicker, brighter line with glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFF007AFF).withValues(alpha: 0.3)
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color =
          const Color(0xFF007AFF) // Figma blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    if (axis == Axis.horizontal) {
      // Horizontal line with glow
      final start = Offset(bounds.left, bounds.top);
      final end = Offset(bounds.right, bounds.top);
      canvas.drawLine(start, end, glowPaint);
      canvas.drawLine(start, end, linePaint);

      // Add small circles at ends for better visibility
      canvas.drawCircle(start, 4, linePaint..style = PaintingStyle.fill);
      canvas.drawCircle(end, 4, linePaint);
    } else {
      // Vertical line with glow
      final start = Offset(bounds.left, bounds.top);
      final end = Offset(bounds.left, bounds.bottom);
      canvas.drawLine(start, end, glowPaint);
      canvas.drawLine(start, end, linePaint);

      // Add small circles at ends for better visibility
      canvas.drawCircle(start, 4, linePaint..style = PaintingStyle.fill);
      canvas.drawCircle(end, 4, linePaint);
    }
  }

  @override
  bool shouldRepaint(InsertionLinePainter oldDelegate) {
    return bounds != oldDelegate.bounds || axis != oldDelegate.axis;
  }
}
