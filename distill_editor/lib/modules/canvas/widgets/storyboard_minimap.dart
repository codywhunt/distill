import 'dart:math' as math;

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../layout/storyboard_layout.dart';

/// A minimap widget that shows an overview of the entire storyboard.
///
/// Displays:
/// - Simplified representations of all page nodes
/// - Connection lines between pages
/// - Current viewport indicator (what's visible on screen)
///
/// Interactive features:
/// - Tap anywhere to navigate to that position
/// - Drag the viewport indicator to pan the canvas
///
/// Only visible when the viewport doesn't contain all content (zoomed in).
class StoryboardMinimap extends StatelessWidget {
  const StoryboardMinimap({
    super.key,
    required this.controller,
    required this.layout,
    required this.pageSize,
    this.minimapSize = const Size(180, 120),
    this.margin = const EdgeInsets.all(16),
    this.contentPadding = 8.0,
    this.backgroundColor = const Color(0xFF1A1A1A),
    this.nodeColor = const Color(0xFF3A3A3A),
    this.connectionColor = const Color(0xFF4A4A4A),
    this.viewportColor = const Color(0xFF8B5CF6),
    this.viewportBorderColor = const Color(0xFFFFFFFF),
  });

  final InfiniteCanvasController controller;
  final StoryboardLayout layout;
  final Size pageSize;
  final Size minimapSize;
  final EdgeInsets margin;

  /// Internal padding around the minimap content.
  final double contentPadding;
  final Color backgroundColor;
  final Color nodeColor;
  final Color connectionColor;
  final Color viewportColor;
  final Color viewportBorderColor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Don't show if no content
        if (layout.positions.isEmpty || layout.bounds == Rect.zero) {
          return const SizedBox.shrink();
        }

        // Don't show if viewport is null
        final viewportSize = controller.viewportSize;
        if (viewportSize == null) {
          return const SizedBox.shrink();
        }

        // Get visible world bounds
        final visibleBounds = controller.getVisibleWorldBounds(viewportSize);

        // Check if all content is visible - hide minimap if so
        final contentBounds = layout.bounds;
        if (_isFullyVisible(visibleBounds, contentBounds)) {
          return const SizedBox.shrink();
        }

        // Add padding to content bounds for minimap
        final paddedBounds = contentBounds.inflate(100);

        // Calculate available space for content (minus internal padding)
        final availableSize = Size(
          minimapSize.width - contentPadding * 2,
          minimapSize.height - contentPadding * 2,
        );

        // Calculate scale to fit content in available space
        final scaleX = availableSize.width / paddedBounds.width;
        final scaleY = availableSize.height / paddedBounds.height;
        final scale = math.min(scaleX, scaleY);

        // Calculate actual content size (maintaining aspect ratio)
        final contentSize = Size(
          paddedBounds.width * scale,
          paddedBounds.height * scale,
        );

        // Total container size includes padding
        final containerSize = Size(
          contentSize.width + contentPadding * 2,
          contentSize.height + contentPadding * 2,
        );

        return Positioned(
          right: margin.right,
          bottom: margin.bottom,
          child: GestureDetector(
            onTapDown: (details) =>
                _onMinimapTap(details, paddedBounds, scale, contentPadding),
            onPanUpdate: (details) =>
                _onMinimapPan(details, paddedBounds, scale),
            child: Container(
              width: containerSize.width,
              height: containerSize.height,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: context.shadows.elevation200,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: CustomPaint(
                    size: contentSize,
                    painter: _MinimapPainter(
                      positions: layout.positions,
                      connections: layout.connections,
                      worldBounds: paddedBounds,
                      viewportBounds: visibleBounds,
                      pageSize: pageSize,
                      scale: scale,
                      nodeColor: nodeColor,
                      connectionColor: connectionColor,
                      viewportColor: viewportColor,
                      viewportBorderColor: viewportBorderColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Check if the content bounds are fully visible within the viewport.
  bool _isFullyVisible(Rect viewport, Rect content) {
    // Add a small margin to prevent flickering at edge cases
    const margin = 20.0;
    return viewport.left <= content.left + margin &&
        viewport.top <= content.top + margin &&
        viewport.right >= content.right - margin &&
        viewport.bottom >= content.bottom - margin;
  }

  /// Handle tap on minimap - navigate to that world position.
  void _onMinimapTap(
    TapDownDetails details,
    Rect worldBounds,
    double scale,
    double padding,
  ) {
    // Adjust for internal padding
    final adjustedPos = details.localPosition - Offset(padding, padding);
    final worldPos = _minimapToWorld(adjustedPos, worldBounds, scale);
    controller.animateToCenterOn(
      worldPos,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Handle pan on minimap - pan the main canvas.
  void _onMinimapPan(
    DragUpdateDetails details,
    Rect worldBounds,
    double scale,
  ) {
    // Convert minimap pixel delta to world-space delta.
    // Divide by minimap scale to get world units.
    final worldDelta = Offset(
      details.delta.dx / scale,
      details.delta.dy / scale,
    );

    // panBy() expects view-space pixels, so multiply world delta by zoom.
    // Negated because dragging the viewport indicator right should pan
    // the canvas left (revealing content to the right).
    controller.panBy(-worldDelta * controller.zoom);
  }

  /// Convert minimap coordinates to world coordinates.
  Offset _minimapToWorld(Offset minimapPos, Rect worldBounds, double scale) {
    return Offset(
      worldBounds.left + minimapPos.dx / scale,
      worldBounds.top + minimapPos.dy / scale,
    );
  }
}

/// Custom painter for minimap content.
class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.positions,
    required this.connections,
    required this.worldBounds,
    required this.viewportBounds,
    required this.pageSize,
    required this.scale,
    required this.nodeColor,
    required this.connectionColor,
    required this.viewportColor,
    required this.viewportBorderColor,
  });

  final Map<String, Offset> positions;
  final List<ConnectionPath> connections;
  final Rect worldBounds;
  final Rect viewportBounds;
  final Size pageSize;
  final double scale;
  final Color nodeColor;
  final Color connectionColor;
  final Color viewportColor;
  final Color viewportBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw connections
    final connPaint = Paint()
      ..color = connectionColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (final connection in connections) {
      if (connection.waypoints.length >= 2) {
        final path = Path();
        final firstPoint = _worldToMinimap(connection.waypoints.first);
        path.moveTo(firstPoint.dx, firstPoint.dy);

        for (var i = 1; i < connection.waypoints.length; i++) {
          final point = _worldToMinimap(connection.waypoints[i]);
          path.lineTo(point.dx, point.dy);
        }

        canvas.drawPath(path, connPaint);
      }
    }

    // 2. Draw page nodes
    final nodePaint = Paint()
      ..color = nodeColor
      ..style = PaintingStyle.fill;

    for (final entry in positions.entries) {
      // Skip dummy vertices (they start with _dummy_)
      if (entry.key.startsWith('_dummy_')) continue;

      final pos = entry.value;
      final rect = Rect.fromLTWH(
        (pos.dx - worldBounds.left) * scale,
        (pos.dy - worldBounds.top) * scale,
        pageSize.width * scale,
        pageSize.height * scale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        nodePaint,
      );
    }

    // 3. Draw viewport indicator
    final vpRect = Rect.fromLTWH(
      (viewportBounds.left - worldBounds.left) * scale,
      (viewportBounds.top - worldBounds.top) * scale,
      viewportBounds.width * scale,
      viewportBounds.height * scale,
    );

    // Viewport fill
    final vpFillPaint = Paint()
      ..color = viewportColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRect(vpRect, vpFillPaint);

    // Viewport border
    final vpBorderPaint = Paint()
      ..color = viewportBorderColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(vpRect, vpBorderPaint);
  }

  Offset _worldToMinimap(Offset worldPos) {
    return Offset(
      (worldPos.dx - worldBounds.left) * scale,
      (worldPos.dy - worldBounds.top) * scale,
    );
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) {
    return positions != oldDelegate.positions ||
        connections != oldDelegate.connections ||
        viewportBounds != oldDelegate.viewportBounds ||
        worldBounds != oldDelegate.worldBounds ||
        scale != oldDelegate.scale;
  }
}
