import 'dart:ui' show Offset, Path, Radius, Rect;

import 'storyboard_config.dart';

/// Result of storyboard layout computation.
class StoryboardLayout {
  const StoryboardLayout({
    required this.positions,
    required this.connections,
    required this.bounds,
  });

  /// Computed positions for each page (pageId -> position).
  final Map<String, Offset> positions;

  /// Routed connection paths between pages.
  final List<ConnectionPath> connections;

  /// Bounding rectangle containing all pages.
  final Rect bounds;

  /// Empty layout for initial state.
  static const empty = StoryboardLayout(
    positions: {},
    connections: [],
    bounds: Rect.zero,
  );
}

/// A routed connection path between two pages.
class ConnectionPath {
  const ConnectionPath({
    required this.fromPageId,
    required this.toPageId,
    required this.waypoints,
    this.cornerRadius = StoryboardConfig.connectionRadius,
    this.isBidirectional = false,
  });

  /// Source page ID (for bidirectional, this is just one of the two pages).
  final String fromPageId;

  /// Target page ID (for bidirectional, this is just one of the two pages).
  final String toPageId;

  /// Waypoints defining the orthogonal path.
  /// Minimum 2 points (start and end).
  final List<Offset> waypoints;

  /// Radius for rounded corners at bends.
  final double cornerRadius;

  /// Whether this connection goes both ways (A ↔ B).
  /// If true, arrows should be drawn at both ends.
  final bool isBidirectional;

  /// Build a Flutter Path with rounded corners at bends.
  Path toPath() {
    if (waypoints.length < 2) return Path();

    final path = Path();
    path.moveTo(waypoints.first.dx, waypoints.first.dy);

    if (waypoints.length == 2) {
      // Straight line
      path.lineTo(waypoints.last.dx, waypoints.last.dy);
      return path;
    }

    // Process intermediate waypoints with rounded corners
    for (var i = 1; i < waypoints.length - 1; i++) {
      final prev = waypoints[i - 1];
      final curr = waypoints[i];
      final next = waypoints[i + 1];

      // Direction vectors
      final toPrev = _normalize(prev - curr);
      final toNext = _normalize(next - curr);

      // Clamp corner radius to half the shortest segment
      final distToPrev = (prev - curr).distance;
      final distToNext = (next - curr).distance;
      final maxRadius = (distToPrev < distToNext ? distToPrev : distToNext) / 2;
      final radius = cornerRadius < maxRadius ? cornerRadius : maxRadius;

      // Corner start and end points
      final cornerStart = curr + toPrev * radius;
      final cornerEnd = curr + toNext * radius;

      // Determine turn direction using cross product of incoming/outgoing vectors
      // incoming = curr - prev (direction we're coming from)
      // outgoing = next - curr (direction we're going to)
      final incoming = curr - prev;
      final outgoing = next - curr;
      final cross = incoming.dx * outgoing.dy - incoming.dy * outgoing.dx;

      // cross < 0: right turn, need clockwise=false for inner corner
      // cross > 0: left turn, need clockwise=true for inner corner
      final clockwise = cross > 0;

      // Line to corner start
      path.lineTo(cornerStart.dx, cornerStart.dy);

      // Arc to corner end with correct direction
      path.arcToPoint(
        cornerEnd,
        radius: Radius.circular(radius),
        clockwise: clockwise,
      );
    }

    // Final line to last waypoint
    path.lineTo(waypoints.last.dx, waypoints.last.dy);

    return path;
  }

  /// Normalize an offset to unit length.
  static Offset _normalize(Offset offset) {
    final length = offset.distance;
    if (length == 0) return Offset.zero;
    return offset / length;
  }
}
