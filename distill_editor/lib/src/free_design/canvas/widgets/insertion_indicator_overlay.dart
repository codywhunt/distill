import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';

import '../../../../modules/canvas/canvas_state.dart';
import '../drag/drag.dart';

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
      return const SizedBox.shrink();
    }

    // The indicator rect is already computed by DropPreviewBuilder
    // Just paint it - no further calculation needed!
    final indicatorWorldRect = dropPreview.indicatorWorldRect!;
    final axis = dropPreview.indicatorAxis!;

    // Convert to view coordinates
    final viewBounds = controller.worldToViewRect(indicatorWorldRect);

    return CustomPaint(
      painter: InsertionLinePainter(bounds: viewBounds, axis: axis),
    );
  }
}

/// Custom painter for the insertion indicator line.
///
/// Renders a Figma-style insertion indicator with:
/// - 2px main line (accent blue)
/// - 8px glow blur at 25% opacity
/// - 4px end nubs (circles)
/// - Pixel snapping for crisp lines
///
/// Paint order (per spec):
/// 1. Drop slot highlight (subtle 4% band)
/// 2. Glow (blurred stroke)
/// 3. Main 2px line
/// 4. End nubs
class InsertionLinePainter extends CustomPainter {
  final Rect bounds;
  final Axis axis;

  InsertionLinePainter({required this.bounds, required this.axis});

  // Styling tokens (from dragdropstyle.md)
  static const _accentColor = Color(0xFF007AFF);
  static const _lineThickness = 2.0;
  static const _glowBlur = 8.0;
  static const _glowAlpha = 0.25;
  static const _nubRadius = 4.0;
  static const _slotAlpha = 0.04;
  static const _slotSize = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Compute line endpoints with pixel snapping for crisp rendering
    final Offset start;
    final Offset end;

    if (axis == Axis.horizontal) {
      // Horizontal line (for vertical/column layout)
      final y = _snapToHalfPixel(bounds.top);
      start = Offset(bounds.left, y);
      end = Offset(bounds.right, y);
    } else {
      // Vertical line (for horizontal/row layout)
      final x = _snapToHalfPixel(bounds.left);
      start = Offset(x, bounds.top);
      end = Offset(x, bounds.bottom);
    }

    // 1. Draw drop slot highlight (subtle band behind indicator)
    _drawSlotHighlight(canvas, start, end);

    // 2. Draw glow (8px blur, 25% opacity)
    final glowPaint = Paint()
      ..color = _accentColor.withValues(alpha: _glowAlpha)
      ..strokeWidth = _lineThickness + 6 // Wider for glow spread
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _glowBlur / 2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, glowPaint);

    // 3. Draw main 2px line
    final linePaint = Paint()
      ..color = _accentColor
      ..strokeWidth = _lineThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, linePaint);

    // 4. Draw end nubs (4px radius circles)
    final nubPaint = Paint()
      ..color = _accentColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(start, _nubRadius, nubPaint);
    canvas.drawCircle(end, _nubRadius, nubPaint);
  }

  /// Draw subtle slot highlight band behind the indicator.
  void _drawSlotHighlight(Canvas canvas, Offset start, Offset end) {
    final slotPaint = Paint()
      ..color = _accentColor.withValues(alpha: _slotAlpha)
      ..style = PaintingStyle.fill;

    final Rect slotRect;
    if (axis == Axis.horizontal) {
      // Horizontal line → horizontal slot band
      slotRect = Rect.fromCenter(
        center: Offset((start.dx + end.dx) / 2, start.dy),
        width: (end.dx - start.dx).abs(),
        height: _slotSize,
      );
    } else {
      // Vertical line → vertical slot band
      slotRect = Rect.fromCenter(
        center: Offset(start.dx, (start.dy + end.dy) / 2),
        width: _slotSize,
        height: (end.dy - start.dy).abs(),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(slotRect, const Radius.circular(4)),
      slotPaint,
    );
  }

  /// Snap coordinate to half-pixel for crisp odd-width lines.
  double _snapToHalfPixel(double value) {
    return value.floorToDouble() + 0.5;
  }

  @override
  bool shouldRepaint(InsertionLinePainter oldDelegate) {
    return bounds != oldDelegate.bounds || axis != oldDelegate.axis;
  }
}
