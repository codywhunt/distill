import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';

import '../../models/node_layout.dart';
import '../../../../modules/canvas/canvas_state.dart';
import '../drag_session.dart';

/// Blue line showing where dragged node will be inserted in auto-layout.
///
/// Renders a Figma-style insertion indicator (blue line) at the calculated
/// insertion index within the drop target container.
///
/// ## Key Design Principle
///
/// This overlay is now "dumb" - it simply reads from `session.dropPreview.indicatorWorldRect`
/// and paints it. All calculation logic is centralized in DropPreviewEngine.
/// No derived logic or bounds lookups happen here.
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

    // Only show during move drag
    if (session == null || session.mode != DragMode.move) {
      return const SizedBox.shrink();
    }

    // Read directly from the authoritative DropPreview model
    final dropPreview = session.dropPreview;

    // Check if we should show the indicator
    if (dropPreview == null || !dropPreview.shouldShowIndicator) {
      // DEBUG: Log why indicator isn't showing
      if (dropPreview != null) {
        print('[Indicator] Not showing: '
            'isValid=${dropPreview.isValid}, '
            'indicatorRect=${dropPreview.indicatorWorldRect != null}, '
            'direction=${dropPreview.direction}, '
            'kind=${dropPreview.kind}, '
            'invalidReason=${dropPreview.invalidReason}');
      }
      return const SizedBox.shrink();
    }

    // The indicator rect is already computed by DropPreviewEngine
    // Just paint it - no further calculation needed!
    final indicatorWorldRect = dropPreview.indicatorWorldRect!;
    final direction = dropPreview.direction!;

    print('[Indicator] Drawing from DropPreview: '
        'rect=$indicatorWorldRect, '
        'direction=$direction, '
        'kind=${dropPreview.kind}, '
        'insertionIndex=${dropPreview.insertionIndex}');

    // Convert to view coordinates
    final viewBounds = controller.worldToViewRect(indicatorWorldRect);

    // Determine axis for painter (perpendicular to layout direction)
    final axis = direction == LayoutDirection.horizontal
        ? Axis.vertical
        : Axis.horizontal;

    return CustomPaint(
      painter: InsertionLinePainter(bounds: viewBounds, axis: axis),
    );
  }
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
      ..color = const Color(0xFF007AFF) // Figma blue
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
