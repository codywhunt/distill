import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../infinite_canvas_controller.dart';

/// A simple grid background for the canvas.
///
/// This widget renders a grid pattern in world-space. It should be used
/// inside a transformed layer (which [InfiniteCanvas] does automatically
/// for the background layer).
///
/// ```dart
/// InfiniteCanvas(
///   layers: CanvasLayers(
///     background: (ctx, ctrl) => GridBackground(controller: ctrl),
///     content: (ctx, ctrl) => MyContent(),
///   ),
/// )
/// ```
///
/// ## Customization
///
/// - [spacing]: Base grid line spacing in world units
/// - [color]: Grid line color
/// - [strokeWidth]: Grid line thickness (in screen pixels, stays constant)
/// - [showAxes]: Whether to show origin axes (X and Y at 0)
/// - [axisColor]: Color for origin axes
/// - [minPixelSpacing]: Minimum spacing in screen pixels (for adaptive LOD)
///
/// ## Note on Rebuilds
///
/// This widget does NOT contain its own ListenableBuilder because it's
/// designed to be used inside [CanvasLayers], which already rebuilds
/// its children when the controller notifies. If you use this widget
/// outside of CanvasLayers, wrap it in a ListenableBuilder yourself.
class GridBackground extends StatelessWidget {
  const GridBackground({
    super.key,
    required this.controller,
    this.spacing = 50.0,
    this.color,
    this.strokeWidth = 1.0,
    this.showAxes = true,
    this.axisColor,
    this.minPixelSpacing = 20.0,
  });

  /// The canvas controller (used for zoom level and viewport calculations).
  final InfiniteCanvasController controller;

  /// Base grid line spacing in world units.
  final double spacing;

  /// Grid line color. Defaults to a semi-transparent gray.
  final Color? color;

  /// Grid line stroke width in screen pixels.
  ///
  /// This is divided by zoom to maintain constant visual thickness
  /// regardless of zoom level.
  final double strokeWidth;

  /// Whether to show origin axes (heavier lines at x=0 and y=0).
  final bool showAxes;

  /// Color for origin axes. Defaults to a more visible gray.
  final Color? axisColor;

  /// Minimum spacing between grid lines in screen pixels.
  ///
  /// When zoomed out far, the grid spacing adapts to prevent drawing
  /// thousands of lines. This is the minimum pixel spacing before
  /// the grid doubles its spacing.
  final double minPixelSpacing;

  @override
  Widget build(BuildContext context) {
    final viewportSize = controller.viewportSize;
    if (viewportSize == null) return const SizedBox.shrink();

    final visibleBounds = controller.getVisibleWorldBounds(viewportSize);

    return CustomPaint(
      painter: _GridPainter(
        zoom: controller.zoom,
        visibleBounds: visibleBounds,
        spacing: spacing,
        color: color ?? Colors.grey.withValues(alpha: 0.2),
        strokeWidth: strokeWidth,
        showAxes: showAxes,
        axisColor: axisColor ?? Colors.grey.withValues(alpha: 0.4),
        minPixelSpacing: minPixelSpacing,
      ),
      size: Size.infinite,
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.zoom,
    required this.visibleBounds,
    required this.spacing,
    required this.color,
    required this.strokeWidth,
    required this.showAxes,
    required this.axisColor,
    required this.minPixelSpacing,
  });

  final double zoom;
  final Rect visibleBounds;
  final double spacing;
  final Color color;
  final double strokeWidth;
  final bool showAxes;
  final Color axisColor;
  final double minPixelSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    // Adaptive LOD: double spacing when lines would be too close on screen
    var effectiveSpacing = spacing;
    while (effectiveSpacing * zoom < minPixelSpacing) {
      effectiveSpacing *= 2;
    }

    // Stroke width that maintains constant screen thickness
    final effectiveStrokeWidth = strokeWidth / zoom;

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = effectiveStrokeWidth
          ..style = PaintingStyle.stroke;

    // Calculate grid line positions (snapped to grid boundaries)
    final startX =
        (visibleBounds.left / effectiveSpacing).floor() * effectiveSpacing;
    final endX =
        (visibleBounds.right / effectiveSpacing).ceil() * effectiveSpacing;
    final startY =
        (visibleBounds.top / effectiveSpacing).floor() * effectiveSpacing;
    final endY =
        (visibleBounds.bottom / effectiveSpacing).ceil() * effectiveSpacing;

    // Safety cap on line count
    final lineCountX =
        ((endX - startX) / effectiveSpacing).abs().clamp(0, 500).toInt();
    final lineCountY =
        ((endY - startY) / effectiveSpacing).abs().clamp(0, 500).toInt();

    // Draw vertical lines (in world coordinates - Transform handles the rest)
    for (var i = 0; i <= lineCountX; i++) {
      final x = startX + i * effectiveSpacing;
      canvas.drawLine(
        Offset(x, visibleBounds.top),
        Offset(x, visibleBounds.bottom),
        paint,
      );
    }

    // Draw horizontal lines
    for (var i = 0; i <= lineCountY; i++) {
      final y = startY + i * effectiveSpacing;
      canvas.drawLine(
        Offset(visibleBounds.left, y),
        Offset(visibleBounds.right, y),
        paint,
      );
    }

    // Draw origin axes
    if (showAxes) {
      final axisPaint =
          Paint()
            ..color = axisColor
            ..strokeWidth = effectiveStrokeWidth * 2
            ..style = PaintingStyle.stroke;

      // Y axis (vertical line at x=0)
      if (visibleBounds.left <= 0 && visibleBounds.right >= 0) {
        canvas.drawLine(
          Offset(0, visibleBounds.top),
          Offset(0, visibleBounds.bottom),
          axisPaint,
        );
      }

      // X axis (horizontal line at y=0)
      if (visibleBounds.top <= 0 && visibleBounds.bottom >= 0) {
        canvas.drawLine(
          Offset(visibleBounds.left, 0),
          Offset(visibleBounds.right, 0),
          axisPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) {
    return zoom != oldDelegate.zoom ||
        visibleBounds != oldDelegate.visibleBounds ||
        spacing != oldDelegate.spacing ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        showAxes != oldDelegate.showAxes ||
        axisColor != oldDelegate.axisColor ||
        minPixelSpacing != oldDelegate.minPixelSpacing;
  }
}

/// A dot grid background for the canvas (Figma-style).
///
/// This widget renders a dot pattern in world-space. It should be used
/// inside a transformed layer (which [InfiniteCanvas] does automatically
/// for the background layer).
///
/// ```dart
/// InfiniteCanvas(
///   layers: CanvasLayers(
///     background: (ctx, ctrl) => DotBackground(controller: ctrl),
///     content: (ctx, ctrl) => MyContent(),
///   ),
/// )
/// ```
class DotBackground extends StatelessWidget {
  const DotBackground({
    super.key,
    required this.controller,
    this.spacing = 20.0,
    this.dotRadius = 1.0,
    this.color,
    this.minPixelSpacing = 12.0,
  });

  /// The canvas controller (used for zoom level and viewport calculations).
  final InfiniteCanvasController controller;

  /// Base dot spacing in world units.
  final double spacing;

  /// Dot radius in screen pixels (stays constant regardless of zoom).
  final double dotRadius;

  /// Dot color. Defaults to a semi-transparent gray.
  final Color? color;

  /// Minimum spacing between dots in screen pixels.
  ///
  /// When zoomed out far, the spacing adapts to prevent drawing
  /// thousands of dots. Spacing doubles when it would fall below this.
  final double minPixelSpacing;

  @override
  Widget build(BuildContext context) {
    final viewportSize = controller.viewportSize;
    if (viewportSize == null) return const SizedBox.shrink();

    final visibleBounds = controller.getVisibleWorldBounds(viewportSize);

    return CustomPaint(
      painter: _DotPainter(
        zoom: controller.zoom,
        visibleBounds: visibleBounds,
        spacing: spacing,
        dotRadius: dotRadius,
        color: color ?? Colors.grey.withValues(alpha: 0.3),
        minPixelSpacing: minPixelSpacing,
      ),
      size: Size.infinite,
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.zoom,
    required this.visibleBounds,
    required this.spacing,
    required this.dotRadius,
    required this.color,
    required this.minPixelSpacing,
  });

  final double zoom;
  final Rect visibleBounds;
  final double spacing;
  final double dotRadius;
  final Color color;
  final double minPixelSpacing;

  /// Maximum dots to draw (performance safety cap).
  static const int _maxDots = 10000;

  @override
  void paint(Canvas canvas, Size size) {
    // Single-pass LOD: increase spacing until both conditions are met
    var effectiveSpacing = spacing;

    while (true) {
      // Check 1: Screen-space density
      if (effectiveSpacing * zoom < minPixelSpacing) {
        effectiveSpacing *= 2;
        continue;
      }

      // Check 2: Total dot count
      final cols = (visibleBounds.width / effectiveSpacing).ceil() + 1;
      final rows = (visibleBounds.height / effectiveSpacing).ceil() + 1;
      if (cols * rows > _maxDots) {
        effectiveSpacing *= 2;
        continue;
      }

      break;
    }

    // Calculate grid positions (snapped to grid boundaries)
    final startX =
        (visibleBounds.left / effectiveSpacing).floor() * effectiveSpacing;
    final startY =
        (visibleBounds.top / effectiveSpacing).floor() * effectiveSpacing;
    final endX =
        (visibleBounds.right / effectiveSpacing).ceil() * effectiveSpacing;
    final endY =
        (visibleBounds.bottom / effectiveSpacing).ceil() * effectiveSpacing;

    // Collect points for batch drawing (in world coordinates)
    final points = <Offset>[];
    for (var x = startX; x <= endX; x += effectiveSpacing) {
      for (var y = startY; y <= endY; y += effectiveSpacing) {
        points.add(Offset(x, y));
      }
    }

    if (points.isEmpty) return;

    // Radius in world units that produces constant screen-pixel size
    final worldRadius = dotRadius / zoom;

    // Batch draw with drawPoints
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = worldRadius * 2
          ..strokeCap = StrokeCap.round;

    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_DotPainter oldDelegate) {
    return zoom != oldDelegate.zoom ||
        visibleBounds != oldDelegate.visibleBounds ||
        spacing != oldDelegate.spacing ||
        dotRadius != oldDelegate.dotRadius ||
        color != oldDelegate.color ||
        minPixelSpacing != oldDelegate.minPixelSpacing;
  }
}
