import 'dart:math' as math;
import 'dart:ui';

import '../algorithms/layout_algorithm.dart';
import 'edge_router.dart';

/// Curved edge router using Bezier curves.
///
/// Draws smooth curves between nodes with control points offset
/// perpendicular to the port direction.
class CurvedRouter implements EdgeRouter {
  const CurvedRouter({this.curvature = 0.5, this.minControlDistance = 30.0});

  /// How curved the edges are (0 = straight, 1 = very curved).
  final double curvature;

  /// Minimum distance for control points from nodes.
  final double minControlDistance;

  @override
  String get name => 'Curved';

  @override
  String get description => 'Bezier curves with smooth bends';

  @override
  List<Offset> route({
    required Offset start,
    required Size startSize,
    required PortSide startSide,
    required Offset end,
    required Size endSize,
    required PortSide endSide,
    List<Rect> obstacles = const [],
    Map<String, dynamic>? options,
  }) {
    final startPort = EdgeRouter.getPortPosition(start, startSize, startSide);
    final endPort = EdgeRouter.getPortPosition(end, endSize, endSide);

    // Calculate control point distance based on edge length
    final distance = (endPort - startPort).distance;
    final controlDistance = math.max(distance * curvature, minControlDistance);

    // Get direction vectors for each port
    final startDir = _getPortDirection(startSide);
    final endDir = _getPortDirection(endSide);

    // Control points extend in the port direction
    final cp1 = startPort + startDir * controlDistance;
    final cp2 = endPort + endDir * controlDistance;

    // Return 4 points for cubic Bezier: start, cp1, cp2, end
    return [startPort, cp1, cp2, endPort];
  }

  Offset _getPortDirection(PortSide side) {
    return switch (side) {
      PortSide.top => const Offset(0, -1),
      PortSide.bottom => const Offset(0, 1),
      PortSide.left => const Offset(-1, 0),
      PortSide.right => const Offset(1, 0),
    };
  }
}
