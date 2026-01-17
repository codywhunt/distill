import 'package:flutter/material.dart';

import '../layout/storyboard_config.dart';
import '../layout/storyboard_layout.dart';

/// Renders all storyboard connection paths in world-space.
///
/// Connections are drawn behind pages and include:
/// - Orthogonal paths with rounded corners
/// - Arrow heads at target endpoints
/// - Highlighting for connections involving selected pages
class StoryboardConnections extends StatelessWidget {
  const StoryboardConnections({
    super.key,
    required this.connections,
    this.selectedPageIds = const {},
    this.color = StoryboardConfig.connectionColor,
    this.highlightColor = StoryboardConfig.connectionHighlightColor,
    this.strokeWidth = StoryboardConfig.connectionStrokeWidth,
    this.arrowSize = StoryboardConfig.arrowHeadSize,
    this.startDotRadius = StoryboardConfig.connectionStartDotRadius,
  });

  /// Connection paths to render.
  final List<ConnectionPath> connections;

  /// Currently selected page IDs (for highlighting).
  final Set<String> selectedPageIds;

  /// Default connection color.
  final Color color;

  /// Connection color when highlighted.
  final Color highlightColor;

  /// Stroke width for connection lines.
  final double strokeWidth;

  /// Arrow head size.
  final double arrowSize;

  /// Radius of the circle dot at connection start points.
  final double startDotRadius;

  @override
  Widget build(BuildContext context) {
    if (connections.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _ConnectionsPainter(
        connections: connections,
        selectedPageIds: selectedPageIds,
        color: color,
        highlightColor: highlightColor,
        strokeWidth: strokeWidth,
        arrowSize: arrowSize,
        startDotRadius: startDotRadius,
      ),
      size: Size.infinite,
    );
  }
}

/// Custom painter for rendering connection paths.
class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({
    required this.connections,
    required this.selectedPageIds,
    required this.color,
    required this.highlightColor,
    required this.strokeWidth,
    required this.arrowSize,
    required this.startDotRadius,
  });

  final List<ConnectionPath> connections;
  final Set<String> selectedPageIds;
  final Color color;
  final Color highlightColor;
  final double strokeWidth;
  final double arrowSize;
  final double startDotRadius;

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      final isHighlighted =
          selectedPageIds.contains(connection.fromPageId) ||
          selectedPageIds.contains(connection.toPageId);

      _drawConnection(canvas, connection, isHighlighted);
    }
  }

  void _drawConnection(
    Canvas canvas,
    ConnectionPath connection,
    bool isHighlighted,
  ) {
    if (connection.waypoints.length < 2) return;

    final lineColor = isHighlighted ? highlightColor : color;
    final lineWidth = isHighlighted ? strokeWidth + 1 : strokeWidth;

    final paint =
        Paint()
          ..color = lineColor
          ..strokeWidth = lineWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    // Trim waypoints so line doesn't extend past arrow heads
    final trimmedWaypoints = _trimWaypointsForArrows(
      connection.waypoints,
      trimStart: connection.isBidirectional, // Only trim start for bidirectional
      trimEnd: true, // Always trim end for arrow
    );

    // Draw the path with trimmed waypoints
    final path = _buildPath(trimmedWaypoints, connection.cornerRadius);
    canvas.drawPath(path, paint);

    if (connection.isBidirectional) {
      // Bidirectional: arrows on both ends
      _drawArrowHead(canvas, connection.waypoints, lineColor);
      _drawArrowHeadReversed(canvas, connection.waypoints, lineColor);
    } else {
      // Forward only: circle dot at start, arrow at end
      _drawStartDot(canvas, connection.waypoints.first, lineColor);
      _drawArrowHead(canvas, connection.waypoints, lineColor);
    }
  }

  /// Trim waypoints so line ends at arrow base instead of arrow tip.
  List<Offset> _trimWaypointsForArrows(
    List<Offset> waypoints, {
    required bool trimStart,
    required bool trimEnd,
  }) {
    if (waypoints.length < 2) return waypoints;

    final result = List<Offset>.from(waypoints);

    // Trim end (for forward arrow)
    if (trimEnd && result.length >= 2) {
      final end = result.last;
      final beforeEnd = result[result.length - 2];
      final direction = (end - beforeEnd);
      final length = direction.distance;
      if (length > arrowSize) {
        final unitDir = direction / length;
        result[result.length - 1] = end - unitDir * arrowSize;
      }
    }

    // Trim start (for bidirectional arrow)
    if (trimStart && result.length >= 2) {
      final start = result.first;
      final afterStart = result[1];
      final direction = (start - afterStart);
      final length = direction.distance;
      if (length > arrowSize) {
        final unitDir = direction / length;
        result[0] = start - unitDir * arrowSize;
      }
    }

    return result;
  }

  /// Build a path with rounded corners (similar to ConnectionPath.toPath).
  Path _buildPath(List<Offset> waypoints, double cornerRadius) {
    if (waypoints.length < 2) return Path();

    final path = Path();
    path.moveTo(waypoints.first.dx, waypoints.first.dy);

    if (waypoints.length == 2) {
      path.lineTo(waypoints.last.dx, waypoints.last.dy);
      return path;
    }

    for (var i = 1; i < waypoints.length - 1; i++) {
      final prev = waypoints[i - 1];
      final curr = waypoints[i];
      final next = waypoints[i + 1];

      final incoming = curr - prev;
      final outgoing = next - curr;
      final cross = incoming.dx * outgoing.dy - incoming.dy * outgoing.dx;

      // Skip corner rounding for collinear points (cross product ≈ 0)
      // Drawing an arc between collinear points creates a semicircle dip
      if (cross.abs() < 0.01) {
        path.lineTo(curr.dx, curr.dy);
        continue;
      }

      final toPrev = _normalize(prev - curr);
      final toNext = _normalize(next - curr);

      final distToPrev = (prev - curr).distance;
      final distToNext = (next - curr).distance;
      final maxRadius = (distToPrev < distToNext ? distToPrev : distToNext) / 2;
      final radius = cornerRadius < maxRadius ? cornerRadius : maxRadius;

      final cornerStart = curr + toPrev * radius;
      final cornerEnd = curr + toNext * radius;

      final clockwise = cross > 0;

      path.lineTo(cornerStart.dx, cornerStart.dy);
      path.arcToPoint(
        cornerEnd,
        radius: Radius.circular(radius),
        clockwise: clockwise,
      );
    }

    path.lineTo(waypoints.last.dx, waypoints.last.dy);
    return path;
  }

  Offset _normalize(Offset offset) {
    final length = offset.distance;
    if (length == 0) return Offset.zero;
    return offset / length;
  }

  void _drawStartDot(Canvas canvas, Offset center, Color dotColor) {
    final paint =
        Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, startDotRadius, paint);
  }

  void _drawArrowHead(
    Canvas canvas,
    List<Offset> waypoints,
    Color arrowColor,
  ) {
    if (waypoints.length < 2) return;

    final end = waypoints.last;
    final beforeEnd = waypoints[waypoints.length - 2];

    _drawArrowAtPoint(canvas, end, beforeEnd, arrowColor);
  }

  /// Draw arrow at the start of the path (pointing backward/left).
  void _drawArrowHeadReversed(
    Canvas canvas,
    List<Offset> waypoints,
    Color arrowColor,
  ) {
    if (waypoints.length < 2) return;

    final start = waypoints.first;
    final afterStart = waypoints[1];

    _drawArrowAtPoint(canvas, start, afterStart, arrowColor);
  }

  /// Draw an arrow head at [tip] pointing away from [base].
  void _drawArrowAtPoint(
    Canvas canvas,
    Offset tip,
    Offset base,
    Color arrowColor,
  ) {
    // Calculate direction vector (from base toward tip)
    final direction = (tip - base);
    final length = direction.distance;
    if (length == 0) return;

    final unitDir = direction / length;

    // Arrow head points
    final arrowTip = tip;
    final arrowBase = tip - unitDir * arrowSize;

    // Perpendicular vector for arrow wings
    final perpendicular = Offset(-unitDir.dy, unitDir.dx);
    final wingSpread = arrowSize * 0.5;

    final leftWing = arrowBase + perpendicular * wingSpread;
    final rightWing = arrowBase - perpendicular * wingSpread;

    // Draw filled arrow head
    final arrowPath =
        Path()
          ..moveTo(arrowTip.dx, arrowTip.dy)
          ..lineTo(leftWing.dx, leftWing.dy)
          ..lineTo(rightWing.dx, rightWing.dy)
          ..close();

    final arrowPaint =
        Paint()
          ..color = arrowColor
          ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(_ConnectionsPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        selectedPageIds != oldDelegate.selectedPageIds ||
        color != oldDelegate.color ||
        highlightColor != oldDelegate.highlightColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        arrowSize != oldDelegate.arrowSize ||
        startDotRadius != oldDelegate.startDotRadius;
  }
}
