import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../infinite_canvas_controller.dart';

/// Result of a snap calculation.
///
/// Contains the potentially adjusted bounds and any guide lines to render.
class SnapResult {
  /// Creates a snap result with snapped bounds and optional guides.
  const SnapResult({required this.snappedBounds, this.guides = const []});

  /// Creates a result indicating no snapping occurred.
  const SnapResult.none(Rect bounds)
    : snappedBounds = bounds,
      guides = const [];

  /// The bounds after snapping adjustments.
  ///
  /// If no snap occurred, this equals the original input bounds.
  final Rect snappedBounds;

  /// Guide lines to render in the overlay.
  ///
  /// Empty if no snapping occurred.
  final List<SnapGuide> guides;

  /// Whether any snapping occurred.
  bool get didSnap => guides.isNotEmpty;
}

/// A guide line to render when snapping occurs.
///
/// Guides are rendered in the overlay layer to show alignment with other objects.
class SnapGuide {
  /// Creates a snap guide.
  const SnapGuide({
    required this.axis,
    required this.position,
    this.start,
    this.end,
    this.type = SnapGuideType.edge,
  });

  /// The axis of the guide line.
  ///
  /// - [Axis.vertical]: A vertical line at [position] on the X axis.
  /// - [Axis.horizontal]: A horizontal line at [position] on the Y axis.
  final Axis axis;

  /// Position of the guide line in world coordinates.
  ///
  /// For vertical guides, this is the X coordinate.
  /// For horizontal guides, this is the Y coordinate.
  final double position;

  /// Start of the guide line in world coordinates.
  ///
  /// For vertical guides, this is the top Y coordinate.
  /// For horizontal guides, this is the left X coordinate.
  /// If null, extends to the viewport edge.
  final double? start;

  /// End of the guide line in world coordinates.
  ///
  /// For vertical guides, this is the bottom Y coordinate.
  /// For horizontal guides, this is the right X coordinate.
  /// If null, extends to the viewport edge.
  final double? end;

  /// Type of guide, which affects rendering style.
  final SnapGuideType type;
}

/// Types of snap guides with different visual treatments.
enum SnapGuideType {
  /// Edge alignment (solid line).
  edge,

  /// Center alignment (dashed line).
  center,

  /// Equal spacing indicator (dotted line with measurement).
  spacing,
}

/// Edges of a rectangle that can be resized.
enum ResizeEdge {
  /// Left edge (affects x position and width).
  left,

  /// Right edge (affects width only).
  right,

  /// Top edge (affects y position and height).
  top,

  /// Bottom edge (affects height only).
  bottom,
}

/// Calculates snap alignment for objects being dragged.
///
/// The snap engine detects alignment with nearby objects and optionally
/// snaps to a grid. Object-to-object snapping takes priority over grid snapping.
///
/// Example usage:
/// ```dart
/// final engine = SnapEngine(threshold: 8.0);
///
/// // During drag
/// final result = engine.calculate(
///   movingBounds: draggedObject.bounds,
///   otherBounds: nearbyObjects.map((o) => o.bounds),
///   zoom: controller.zoom,
/// );
///
/// // Apply snapped position
/// draggedObject.bounds = result.snappedBounds;
///
/// // Render guides in overlay
/// for (final guide in result.guides) {
///   // Draw guide line...
/// }
/// ```
///
/// Usage modes:
/// - Object snap only: `SnapEngine()`
/// - Grid snap only: `SnapEngine(enableEdgeSnap: false, enableCenterSnap: false, gridSize: 25)`
/// - Both (object priority): `SnapEngine(gridSize: 25)`
class SnapEngine {
  /// Creates a snap engine with the given configuration.
  const SnapEngine({
    this.threshold = 8.0,
    this.enableEdgeSnap = true,
    this.enableCenterSnap = true,
    this.gridSize,
  });

  /// Snap threshold in screen pixels.
  ///
  /// Objects within this distance (after zoom) will snap together.
  final double threshold;

  /// Whether to snap to object edges (left, right, top, bottom).
  final bool enableEdgeSnap;

  /// Whether to snap to object centers.
  final bool enableCenterSnap;

  /// Optional grid size for grid snapping.
  ///
  /// If provided and no object snap occurs, bounds will snap to grid.
  /// Set to null to disable grid snapping.
  final double? gridSize;

  /// Calculate snap for moving bounds against other objects.
  ///
  /// - [movingBounds]: The bounds being dragged.
  /// - [otherBounds]: Bounds of other objects to snap against.
  /// - [zoom]: Current zoom level (used to convert threshold to world units).
  ///
  /// Returns a [SnapResult] with potentially adjusted bounds and guide lines.
  SnapResult calculate({
    required Rect movingBounds,
    required Iterable<Rect> otherBounds,
    required double zoom,
  }) {
    // Convert threshold to world units
    final worldThreshold = threshold / zoom;

    final guides = <SnapGuide>[];
    var snappedBounds = movingBounds;

    // Collect all snap candidates
    final xSnaps = <_SnapCandidate>[];
    final ySnaps = <_SnapCandidate>[];

    for (final other in otherBounds) {
      if (enableEdgeSnap) {
        // Left edge alignments
        _addIfClose(
          xSnaps,
          movingBounds.left,
          other.left,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );
        _addIfClose(
          xSnaps,
          movingBounds.left,
          other.right,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );

        // Right edge alignments
        _addIfClose(
          xSnaps,
          movingBounds.right,
          other.left,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );
        _addIfClose(
          xSnaps,
          movingBounds.right,
          other.right,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );

        // Top edge alignments
        _addIfClose(
          ySnaps,
          movingBounds.top,
          other.top,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );
        _addIfClose(
          ySnaps,
          movingBounds.top,
          other.bottom,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );

        // Bottom edge alignments
        _addIfClose(
          ySnaps,
          movingBounds.bottom,
          other.top,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );
        _addIfClose(
          ySnaps,
          movingBounds.bottom,
          other.bottom,
          worldThreshold,
          SnapGuideType.edge,
          movingBounds,
          other,
        );
      }

      if (enableCenterSnap) {
        // Center alignments
        _addIfClose(
          xSnaps,
          movingBounds.center.dx,
          other.center.dx,
          worldThreshold,
          SnapGuideType.center,
          movingBounds,
          other,
        );
        _addIfClose(
          ySnaps,
          movingBounds.center.dy,
          other.center.dy,
          worldThreshold,
          SnapGuideType.center,
          movingBounds,
          other,
        );
      }
    }

    // Find best X snap (smallest distance)
    if (xSnaps.isNotEmpty) {
      xSnaps.sort((a, b) => a.distance.compareTo(b.distance));
      final best = xSnaps.first;
      final dx = best.snapTo - best.current;
      snappedBounds = snappedBounds.shift(Offset(dx, 0));
      guides.add(
        SnapGuide(
          axis: Axis.vertical,
          position: best.snapTo,
          start: math.min(snappedBounds.top, best.otherBounds.top) - 10,
          end: math.max(snappedBounds.bottom, best.otherBounds.bottom) + 10,
          type: best.type,
        ),
      );
    }

    // Find best Y snap
    if (ySnaps.isNotEmpty) {
      ySnaps.sort((a, b) => a.distance.compareTo(b.distance));
      final best = ySnaps.first;
      final dy = best.snapTo - best.current;
      snappedBounds = snappedBounds.shift(Offset(0, dy));
      guides.add(
        SnapGuide(
          axis: Axis.horizontal,
          position: best.snapTo,
          start: math.min(snappedBounds.left, best.otherBounds.left) - 10,
          end: math.max(snappedBounds.right, best.otherBounds.right) + 10,
          type: best.type,
        ),
      );
    }

    // Grid snapping (only if no object snap occurred)
    if (guides.isEmpty && gridSize != null && gridSize! > 0) {
      snappedBounds = _snapToGrid(snappedBounds, gridSize!);
      // No guides for grid snap - the grid itself is the guide
    }

    return SnapResult(snappedBounds: snappedBounds, guides: guides);
  }

  /// Calculate snap for resize operations.
  ///
  /// Unlike [calculate] which snaps the whole object position, this method
  /// only snaps the edges being actively resized based on [activeEdges].
  ///
  /// - [currentBounds]: The bounds before resize delta is applied.
  /// - [activeEdges]: Which edges are being resized (based on resize handle).
  /// - [delta]: The accumulated resize delta.
  /// - [otherBounds]: Bounds of other objects to snap against.
  /// - [zoom]: Current zoom level (used to convert threshold to world units).
  ///
  /// Returns a [SnapResult] with adjusted bounds and guide lines for snapped edges.
  SnapResult calculateResize({
    required Rect currentBounds,
    required Set<ResizeEdge> activeEdges,
    required Offset delta,
    required Iterable<Rect> otherBounds,
    required double zoom,
  }) {
    if (!enableEdgeSnap || activeEdges.isEmpty) {
      // No edge snapping enabled or no edges to snap
      final proposedBounds = _applyResizeDelta(currentBounds, activeEdges, delta);
      return SnapResult.none(proposedBounds);
    }

    final worldThreshold = threshold / zoom;
    final guides = <SnapGuide>[];

    // Calculate proposed bounds after applying delta
    var proposedBounds = _applyResizeDelta(currentBounds, activeEdges, delta);

    // Collect snap candidates for active edges only
    final xSnaps = <_ResizeSnapCandidate>[];
    final ySnaps = <_ResizeSnapCandidate>[];

    for (final other in otherBounds) {
      // Left edge snapping (only if left edge is being resized)
      if (activeEdges.contains(ResizeEdge.left)) {
        _addResizeIfClose(
          xSnaps,
          proposedBounds.left,
          other.left,
          worldThreshold,
          ResizeEdge.left,
          proposedBounds,
          other,
        );
        _addResizeIfClose(
          xSnaps,
          proposedBounds.left,
          other.right,
          worldThreshold,
          ResizeEdge.left,
          proposedBounds,
          other,
        );
      }

      // Right edge snapping
      if (activeEdges.contains(ResizeEdge.right)) {
        _addResizeIfClose(
          xSnaps,
          proposedBounds.right,
          other.left,
          worldThreshold,
          ResizeEdge.right,
          proposedBounds,
          other,
        );
        _addResizeIfClose(
          xSnaps,
          proposedBounds.right,
          other.right,
          worldThreshold,
          ResizeEdge.right,
          proposedBounds,
          other,
        );
      }

      // Top edge snapping
      if (activeEdges.contains(ResizeEdge.top)) {
        _addResizeIfClose(
          ySnaps,
          proposedBounds.top,
          other.top,
          worldThreshold,
          ResizeEdge.top,
          proposedBounds,
          other,
        );
        _addResizeIfClose(
          ySnaps,
          proposedBounds.top,
          other.bottom,
          worldThreshold,
          ResizeEdge.top,
          proposedBounds,
          other,
        );
      }

      // Bottom edge snapping
      if (activeEdges.contains(ResizeEdge.bottom)) {
        _addResizeIfClose(
          ySnaps,
          proposedBounds.bottom,
          other.top,
          worldThreshold,
          ResizeEdge.bottom,
          proposedBounds,
          other,
        );
        _addResizeIfClose(
          ySnaps,
          proposedBounds.bottom,
          other.bottom,
          worldThreshold,
          ResizeEdge.bottom,
          proposedBounds,
          other,
        );
      }
    }

    // Apply best X snap (for left or right edge)
    if (xSnaps.isNotEmpty) {
      xSnaps.sort((a, b) => a.distance.compareTo(b.distance));
      final best = xSnaps.first;

      // Adjust bounds based on which edge snapped
      if (best.edge == ResizeEdge.left) {
        proposedBounds = Rect.fromLTRB(
          best.snapTo,
          proposedBounds.top,
          proposedBounds.right,
          proposedBounds.bottom,
        );
      } else {
        proposedBounds = Rect.fromLTRB(
          proposedBounds.left,
          proposedBounds.top,
          best.snapTo,
          proposedBounds.bottom,
        );
      }

      guides.add(
        SnapGuide(
          axis: Axis.vertical,
          position: best.snapTo,
          start: math.min(proposedBounds.top, best.otherBounds.top) - 10,
          end: math.max(proposedBounds.bottom, best.otherBounds.bottom) + 10,
          type: SnapGuideType.edge,
        ),
      );
    }

    // Apply best Y snap (for top or bottom edge)
    if (ySnaps.isNotEmpty) {
      ySnaps.sort((a, b) => a.distance.compareTo(b.distance));
      final best = ySnaps.first;

      // Adjust bounds based on which edge snapped
      if (best.edge == ResizeEdge.top) {
        proposedBounds = Rect.fromLTRB(
          proposedBounds.left,
          best.snapTo,
          proposedBounds.right,
          proposedBounds.bottom,
        );
      } else {
        proposedBounds = Rect.fromLTRB(
          proposedBounds.left,
          proposedBounds.top,
          proposedBounds.right,
          best.snapTo,
        );
      }

      guides.add(
        SnapGuide(
          axis: Axis.horizontal,
          position: best.snapTo,
          start: math.min(proposedBounds.left, best.otherBounds.left) - 10,
          end: math.max(proposedBounds.right, best.otherBounds.right) + 10,
          type: SnapGuideType.edge,
        ),
      );
    }

    return SnapResult(snappedBounds: proposedBounds, guides: guides);
  }

  /// Apply resize delta to bounds based on active edges.
  Rect _applyResizeDelta(Rect bounds, Set<ResizeEdge> edges, Offset delta) {
    var left = bounds.left;
    var top = bounds.top;
    var right = bounds.right;
    var bottom = bounds.bottom;

    if (edges.contains(ResizeEdge.left)) {
      left += delta.dx;
    }
    if (edges.contains(ResizeEdge.right)) {
      right += delta.dx;
    }
    if (edges.contains(ResizeEdge.top)) {
      top += delta.dy;
    }
    if (edges.contains(ResizeEdge.bottom)) {
      bottom += delta.dy;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _addResizeIfClose(
    List<_ResizeSnapCandidate> list,
    double current,
    double target,
    double threshold,
    ResizeEdge edge,
    Rect movingBounds,
    Rect otherBounds,
  ) {
    final distance = (current - target).abs();
    if (distance < threshold) {
      list.add(
        _ResizeSnapCandidate(
          current: current,
          snapTo: target,
          distance: distance,
          edge: edge,
          movingBounds: movingBounds,
          otherBounds: otherBounds,
        ),
      );
    }
  }

  void _addIfClose(
    List<_SnapCandidate> list,
    double current,
    double target,
    double threshold,
    SnapGuideType type,
    Rect movingBounds,
    Rect otherBounds,
  ) {
    final distance = (current - target).abs();
    if (distance < threshold) {
      list.add(
        _SnapCandidate(
          current: current,
          snapTo: target,
          distance: distance,
          type: type,
          movingBounds: movingBounds,
          otherBounds: otherBounds,
        ),
      );
    }
  }

  Rect _snapToGrid(Rect bounds, double grid) {
    return Rect.fromLTWH(
      (bounds.left / grid).round() * grid,
      (bounds.top / grid).round() * grid,
      bounds.width,
      bounds.height,
    );
  }
}

class _SnapCandidate {
  _SnapCandidate({
    required this.current,
    required this.snapTo,
    required this.distance,
    required this.type,
    required this.movingBounds,
    required this.otherBounds,
  });

  final double current;
  final double snapTo;
  final double distance;
  final SnapGuideType type;
  final Rect movingBounds;
  final Rect otherBounds;
}

class _ResizeSnapCandidate {
  _ResizeSnapCandidate({
    required this.current,
    required this.snapTo,
    required this.distance,
    required this.edge,
    required this.movingBounds,
    required this.otherBounds,
  });

  final double current;
  final double snapTo;
  final double distance;
  final ResizeEdge edge;
  final Rect movingBounds;
  final Rect otherBounds;
}

/// Widget that renders snap guide lines in the overlay layer.
///
/// Place this in the overlay builder to show alignment guides during drag:
///
/// ```dart
/// InfiniteCanvas(
///   layers: CanvasLayers(
///     overlay: (ctx, ctrl) => Stack(
///       children: [
///         // ... other overlay content
///         SnapGuidesOverlay(
///           guides: _activeGuides,
///           controller: ctrl,
///         ),
///       ],
///     ),
///   ),
/// )
/// ```
class SnapGuidesOverlay extends StatelessWidget {
  /// Creates a snap guides overlay.
  const SnapGuidesOverlay({
    super.key,
    required this.guides,
    required this.controller,
    this.color = const Color(0xFFFF00FF),
    this.strokeWidth = 1.0,
  });

  /// The guide lines to render.
  final List<SnapGuide> guides;

  /// The canvas controller for coordinate conversion.
  final InfiniteCanvasController controller;

  /// Color of the guide lines.
  final Color color;

  /// Width of the guide lines in screen pixels.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    if (guides.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      painter: _SnapGuidesPainter(
        guides: guides,
        controller: controller,
        color: color,
        strokeWidth: strokeWidth,
      ),
      size: Size.infinite,
    );
  }
}

class _SnapGuidesPainter extends CustomPainter {
  _SnapGuidesPainter({
    required this.guides,
    required this.controller,
    required this.color,
    required this.strokeWidth,
  });

  final List<SnapGuide> guides;
  final InfiniteCanvasController controller;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (final guide in guides) {
      final paint =
          Paint()
            ..color = color
            ..strokeWidth = strokeWidth
            ..style = PaintingStyle.stroke;

      // Adjust style for center guides
      if (guide.type == SnapGuideType.center) {
        paint.strokeWidth = strokeWidth * 0.75;
      }

      if (guide.axis == Axis.vertical) {
        // Vertical line at x position
        final screenX = controller.worldToView(Offset(guide.position, 0)).dx;
        final startY =
            guide.start != null
                ? controller.worldToView(Offset(0, guide.start!)).dy
                : 0.0;
        final endY =
            guide.end != null
                ? controller.worldToView(Offset(0, guide.end!)).dy
                : size.height;

        if (guide.type == SnapGuideType.center) {
          _drawDashedLine(
            canvas,
            Offset(screenX, startY),
            Offset(screenX, endY),
            paint,
          );
        } else {
          canvas.drawLine(
            Offset(screenX, startY),
            Offset(screenX, endY),
            paint,
          );
        }
      } else {
        // Horizontal line at y position
        final screenY = controller.worldToView(Offset(0, guide.position)).dy;
        final startX =
            guide.start != null
                ? controller.worldToView(Offset(guide.start!, 0)).dx
                : 0.0;
        final endX =
            guide.end != null
                ? controller.worldToView(Offset(guide.end!, 0)).dx
                : size.width;

        if (guide.type == SnapGuideType.center) {
          _drawDashedLine(
            canvas,
            Offset(startX, screenY),
            Offset(endX, screenY),
            paint,
          );
        } else {
          canvas.drawLine(
            Offset(startX, screenY),
            Offset(endX, screenY),
            paint,
          );
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 5.0;
    const gapLength = 3.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final unitX = dx / distance;
    final unitY = dy / distance;

    var currentDistance = 0.0;
    var drawing = true;

    while (currentDistance < distance) {
      final segmentLength = drawing ? dashLength : gapLength;
      final nextDistance = math.min(currentDistance + segmentLength, distance);

      if (drawing) {
        canvas.drawLine(
          Offset(
            start.dx + unitX * currentDistance,
            start.dy + unitY * currentDistance,
          ),
          Offset(
            start.dx + unitX * nextDistance,
            start.dy + unitY * nextDistance,
          ),
          paint,
        );
      }

      currentDistance = nextDistance;
      drawing = !drawing;
    }
  }

  @override
  bool shouldRepaint(_SnapGuidesPainter oldDelegate) {
    return guides != oldDelegate.guides ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth;
  }
}
