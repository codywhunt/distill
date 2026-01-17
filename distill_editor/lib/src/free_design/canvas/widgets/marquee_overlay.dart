import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';

import '../drag/drag.dart';
import '../../../../modules/canvas/canvas_state.dart';

/// Blue selection rectangle during marquee drag.
///
/// Only visible when dragging in marquee mode. Renders a semi-transparent
/// blue rectangle from drag start to current position.
class MarqueeOverlay extends StatelessWidget {
  const MarqueeOverlay({
    required this.state,
    required this.controller,
    super.key,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    if (!state.isDragging || state.dragSession?.mode != DragMode.marquee) {
      return const SizedBox.shrink();
    }

    final rect = state.dragSession!.getMarqueeRect();
    if (rect == null) return const SizedBox.shrink();

    final viewRect = controller.worldToViewRect(rect);

    return IgnorePointer(
      child: CustomPaint(
        painter: _MarqueePainter(rect: viewRect),
        size: Size.infinite,
      ),
    );
  }
}

/// Custom painter for marquee selection rectangle.
class _MarqueePainter extends CustomPainter {
  const _MarqueePainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    // Fill with semi-transparent blue
    final fillPaint = Paint()
      ..color = const Color(0xFF007AFF).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRect(rect, fillPaint);

    // Stroke with solid blue
    final strokePaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, strokePaint);
  }

  @override
  bool shouldRepaint(_MarqueePainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
