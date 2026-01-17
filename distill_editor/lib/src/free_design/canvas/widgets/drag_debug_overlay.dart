import 'dart:ui' as ui;

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';

import '../../../../modules/canvas/canvas_state.dart';
import '../drag/drag.dart';

/// Debug overlay for the drag and drop system.
///
/// When [kDragDropDebug] is true, this overlay paints visual debugging aids:
/// - Parent container bounds (dashed orange outline)
/// - Child midpoints (cyan circles)
/// - Debug insertion line (dashed magenta)
/// - Info label with key values
///
/// This overlay is rendered BELOW the actual insertion indicator so it doesn't
/// obscure the real UI, but provides visibility into what the system computed.
class DragDebugOverlay extends StatelessWidget {
  const DragDebugOverlay({
    required this.state,
    required this.controller,
    super.key,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    // Early exit if debug mode is disabled
    if (!kDragDropDebug) return const SizedBox.shrink();

    final session = state.dragSession;
    if (session == null || session.mode != DragMode.move) {
      return const SizedBox.shrink();
    }

    final preview = session.dropPreview;
    if (preview == null) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _DragDebugPainter(
        state: state,
        controller: controller,
        preview: preview,
      ),
      size: Size.infinite,
    );
  }
}

/// Custom painter for debug visualizations.
///
/// Paints in view-space (after zoom) so stroke widths are consistent.
class _DragDebugPainter extends CustomPainter {
  _DragDebugPainter({
    required this.state,
    required this.controller,
    required this.preview,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;
  final DropPreview preview;

  // Debug colors (distinct from actual UI colors)
  static const _parentBoundsColor = Color(0xB3FF9500); // Orange @ 70%
  static const _childMidpointColor = Color(0xCC00CED1); // Cyan @ 80%
  static const _debugLineColor = Color(0x99FF00FF); // Magenta @ 60%
  static const _labelBgColor = Color(0xD9111111); // Dark @ 85%
  static const _labelTextColor = Color(0xE6FFFFFF); // White @ 90%

  @override
  void paint(Canvas canvas, Size size) {
    final targetExpandedId = preview.targetParentExpandedId;
    if (targetExpandedId == null) {
      _paintInvalidState(canvas, size);
      return;
    }

    // Get frame position
    final frame = state.document.frames[preview.frameId];
    if (frame == null) return;
    final framePos = frame.canvas.position;

    // Get parent bounds in frame-local coordinates
    final parentBounds = state.getNodeBounds(preview.frameId, targetExpandedId);
    if (parentBounds == null) return;

    // Convert to world space then view space
    final parentWorldBounds = parentBounds.shift(framePos);
    final parentViewBounds = controller.worldToViewRect(parentWorldBounds);

    // 1. Draw parent bounds (dashed orange outline)
    _drawParentBounds(canvas, parentViewBounds);

    // 2. Draw child midpoints (cyan circles)
    _drawChildMidpoints(canvas, framePos);

    // 3. Draw debug insertion line (dashed magenta)
    if (preview.indicatorWorldRect != null) {
      _drawDebugInsertionLine(canvas);
    }

    // 4. Draw info label
    _drawInfoLabel(canvas, size);
  }

  void _drawParentBounds(Canvas canvas, Rect viewBounds) {
    final paint = Paint()
      ..color = _parentBoundsColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw dashed rectangle
    final path = Path()..addRect(viewBounds);
    _drawDashedPath(canvas, path, paint, dashLength: 4, gapLength: 4);
  }

  void _drawChildMidpoints(Canvas canvas, Offset framePos) {
    final axis = preview.indicatorAxis;
    if (axis == null) return;

    final paint = Paint()
      ..color = _childMidpointColor
      ..style = PaintingStyle.fill;

    for (final childExpandedId in preview.targetChildrenExpandedIds) {
      final childBounds = state.getNodeBounds(preview.frameId, childExpandedId);
      if (childBounds == null) continue;

      // Get midpoint based on layout direction
      final Offset midpoint;
      if (axis == Axis.vertical) {
        // Row layout: midpoint is center-x
        midpoint = Offset(childBounds.center.dx, childBounds.center.dy);
      } else {
        // Column layout: midpoint is center-y
        midpoint = Offset(childBounds.center.dx, childBounds.center.dy);
      }

      // Convert to view space
      final worldMidpoint = midpoint + framePos;
      final viewMidpoint = controller.worldToView(worldMidpoint);

      canvas.drawCircle(viewMidpoint, 4.0, paint);
    }
  }

  void _drawDebugInsertionLine(Canvas canvas) {
    final indicatorRect = preview.indicatorWorldRect!;
    final viewRect = controller.worldToViewRect(indicatorRect);

    final paint = Paint()
      ..color = _debugLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Offset start;
    final Offset end;

    if (preview.indicatorAxis == Axis.horizontal) {
      // Horizontal line
      start = Offset(viewRect.left, viewRect.center.dy);
      end = Offset(viewRect.right, viewRect.center.dy);
    } else {
      // Vertical line
      start = Offset(viewRect.center.dx, viewRect.top);
      end = Offset(viewRect.center.dx, viewRect.bottom);
    }

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    _drawDashedPath(canvas, path, paint, dashLength: 3, gapLength: 3);
  }

  void _drawInfoLabel(Canvas canvas, Size size) {
    final text =
        'idx: ${preview.insertionIndex ?? "-"} | '
        '${preview.intent.name} | '
        'children: ${preview.targetChildrenExpandedIds.length}'
        '${preview.invalidReason != null ? " | ${preview.invalidReason}" : ""}';

    final textStyle = ui.TextStyle(
      color: _labelTextColor,
      fontSize: 11,
      fontFamily: 'monospace',
    );

    final paragraphBuilder =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.left))
          ..pushStyle(textStyle)
          ..addText(text);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 400));

    // Position in top-left corner with padding
    const padding = 8.0;
    final labelRect = Rect.fromLTWH(
      padding,
      padding,
      paragraph.longestLine + 16,
      paragraph.height + 12,
    );

    // Draw background
    final bgPaint = Paint()
      ..color = _labelBgColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
      bgPaint,
    );

    // Draw text
    canvas.drawParagraph(paragraph, Offset(padding + 8, padding + 6));
  }

  void _paintInvalidState(Canvas canvas, Size size) {
    if (preview.invalidReason == null) return;

    final text = 'Invalid: ${preview.invalidReason}';

    final textStyle = ui.TextStyle(
      color: const Color(0xCCFF6B6B), // Reddish
      fontSize: 11,
      fontFamily: 'monospace',
    );

    final paragraphBuilder =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.left))
          ..pushStyle(textStyle)
          ..addText(text);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 400));

    const padding = 8.0;
    final labelRect = Rect.fromLTWH(
      padding,
      padding,
      paragraph.longestLine + 16,
      paragraph.height + 12,
    );

    final bgPaint = Paint()
      ..color = _labelBgColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(6)),
      bgPaint,
    );

    canvas.drawParagraph(paragraph, Offset(padding + 8, padding + 6));
  }

  /// Draw a dashed path.
  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dashLength,
    required double gapLength,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final nextDistance = distance + dashLength;
        final extractPath = metric.extractPath(
          distance,
          nextDistance.clamp(0, metric.length),
        );
        canvas.drawPath(extractPath, paint);
        distance = nextDistance + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DragDebugPainter oldDelegate) {
    return preview != oldDelegate.preview;
  }
}
