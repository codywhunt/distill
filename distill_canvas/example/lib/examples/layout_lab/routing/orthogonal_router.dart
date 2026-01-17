import 'dart:math' as math;
import 'dart:ui';

import '../algorithms/layout_algorithm.dart';
import 'edge_router.dart';

/// Orthogonal edge router with right-angle bends.
///
/// V1: Simple midpoint routing (no obstacle avoidance)
/// V2: A* pathfinding on visibility grid (full obstacle avoidance)
class OrthogonalRouter implements EdgeRouter {
  const OrthogonalRouter({
    this.usePathfinding = false,
    this.gridSize = 10.0,
    this.cornerRadius = 0.0,
    this.padding = 20.0,
  });

  /// Whether to use A* pathfinding (V2) or simple midpoint routing (V1).
  final bool usePathfinding;

  /// Grid cell size for pathfinding.
  final double gridSize;

  /// Radius for rounded corners (0 for sharp corners).
  final double cornerRadius;

  /// Padding around obstacles.
  final double padding;

  @override
  String get name => usePathfinding ? 'Orthogonal (A*)' : 'Orthogonal';

  @override
  String get description =>
      usePathfinding
          ? 'Right-angle edges with obstacle avoidance'
          : 'Right-angle edges via midpoint';

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

    if (usePathfinding && obstacles.isNotEmpty) {
      return _routeWithPathfinding(
        startPort,
        startSide,
        endPort,
        endSide,
        obstacles,
      );
    } else {
      return _routeSimple(startPort, startSide, endPort, endSide);
    }
  }

  /// V1: Simple midpoint routing - one or two bends.
  List<Offset> _routeSimple(
    Offset start,
    PortSide startSide,
    Offset end,
    PortSide endSide,
  ) {
    final points = <Offset>[start];

    // Determine routing strategy based on port sides
    final isStartHorizontal =
        startSide == PortSide.left || startSide == PortSide.right;
    final isEndHorizontal =
        endSide == PortSide.left || endSide == PortSide.right;

    if (isStartHorizontal == isEndHorizontal) {
      // Same orientation - use L-shape or Z-shape
      if (isStartHorizontal) {
        // Both horizontal - route via vertical midpoint
        final midX = (start.dx + end.dx) / 2;
        points.add(Offset(midX, start.dy));
        points.add(Offset(midX, end.dy));
      } else {
        // Both vertical - route via horizontal midpoint
        final midY = (start.dy + end.dy) / 2;
        points.add(Offset(start.dx, midY));
        points.add(Offset(end.dx, midY));
      }
    } else {
      // Perpendicular - single bend
      if (isStartHorizontal) {
        points.add(Offset(end.dx, start.dy));
      } else {
        points.add(Offset(start.dx, end.dy));
      }
    }

    points.add(end);
    return points;
  }

  /// V2: A* pathfinding with obstacle avoidance.
  List<Offset> _routeWithPathfinding(
    Offset start,
    PortSide startSide,
    Offset end,
    PortSide endSide,
    List<Rect> obstacles,
  ) {
    // Expand obstacles by padding
    final expandedObstacles = obstacles.map((r) => r.inflate(padding)).toList();

    // Calculate bounds for the routing grid
    var minX = math.min(start.dx, end.dx);
    var maxX = math.max(start.dx, end.dx);
    var minY = math.min(start.dy, end.dy);
    var maxY = math.max(start.dy, end.dy);

    for (final obs in expandedObstacles) {
      minX = math.min(minX, obs.left);
      maxX = math.max(maxX, obs.right);
      minY = math.min(minY, obs.top);
      maxY = math.max(maxY, obs.bottom);
    }

    // Add margin
    minX -= gridSize * 2;
    maxX += gridSize * 2;
    minY -= gridSize * 2;
    maxY += gridSize * 2;

    // Convert to grid coordinates
    int toGridX(double x) => ((x - minX) / gridSize).round();
    int toGridY(double y) => ((y - minY) / gridSize).round();
    double fromGridX(int gx) => minX + gx * gridSize;
    double fromGridY(int gy) => minY + gy * gridSize;

    final startGrid = (toGridX(start.dx), toGridY(start.dy));
    final endGrid = (toGridX(end.dx), toGridY(end.dy));

    // A* search using a simple sorted list (not optimal but avoids dependency)
    final openSet = <_AStarNode>[];
    final cameFrom = <(int, int), (int, int)>{};
    final gScore = <(int, int), double>{};
    final visited = <(int, int)>{};

    bool isBlocked(int gx, int gy) {
      final worldX = fromGridX(gx);
      final worldY = fromGridY(gy);
      for (final obs in expandedObstacles) {
        if (obs.contains(Offset(worldX, worldY))) {
          return true;
        }
      }
      return false;
    }

    double heuristic((int, int) a, (int, int) b) {
      // Manhattan distance for orthogonal movement
      return ((a.$1 - b.$1).abs() + (a.$2 - b.$2).abs()).toDouble();
    }

    gScore[startGrid] = 0;
    openSet.add(
      _AStarNode(
        pos: startGrid,
        g: 0,
        f: heuristic(startGrid, endGrid),
        direction: _directionFromSide(startSide),
      ),
    );

    // Direction offsets for orthogonal movement
    const directions = [
      (0, -1, _Direction.up),
      (0, 1, _Direction.down),
      (-1, 0, _Direction.left),
      (1, 0, _Direction.right),
    ];

    while (openSet.isNotEmpty) {
      // Sort by f-score and take the lowest
      openSet.sort((a, b) => a.f.compareTo(b.f));
      final current = openSet.removeAt(0);

      if (current.pos == endGrid) {
        // Reconstruct path
        final path = <Offset>[end];
        var node = endGrid;
        while (cameFrom.containsKey(node)) {
          node = cameFrom[node]!;
          path.add(Offset(fromGridX(node.$1), fromGridY(node.$2)));
        }
        path.add(start);

        // Simplify path - remove collinear points
        return _simplifyPath(path.reversed.toList());
      }

      if (visited.contains(current.pos)) continue;
      visited.add(current.pos);

      for (final (dx, dy, dir) in directions) {
        final neighbor = (current.pos.$1 + dx, current.pos.$2 + dy);

        if (visited.contains(neighbor)) continue;
        if (isBlocked(neighbor.$1, neighbor.$2)) continue;

        // Cost includes penalty for direction changes (bends)
        var moveCost = 1.0;
        if (current.direction != dir) {
          moveCost += 0.5; // Penalty for bends
        }

        final tentativeG = gScore[current.pos]! + moveCost;

        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current.pos;
          gScore[neighbor] = tentativeG;
          openSet.add(
            _AStarNode(
              pos: neighbor,
              g: tentativeG,
              f: tentativeG + heuristic(neighbor, endGrid),
              direction: dir,
            ),
          );
        }
      }
    }

    // Pathfinding failed - fall back to simple routing
    return _routeSimple(start, startSide, end, endSide);
  }

  _Direction _directionFromSide(PortSide side) {
    return switch (side) {
      PortSide.top => _Direction.up,
      PortSide.bottom => _Direction.down,
      PortSide.left => _Direction.left,
      PortSide.right => _Direction.right,
    };
  }

  /// Remove collinear points from path.
  List<Offset> _simplifyPath(List<Offset> path) {
    if (path.length <= 2) return path;

    final simplified = <Offset>[path.first];

    for (var i = 1; i < path.length - 1; i++) {
      final prev = path[i - 1];
      final curr = path[i];
      final next = path[i + 1];

      // Check if points are collinear (on same horizontal or vertical line)
      final isHorizontal =
          (prev.dy - curr.dy).abs() < 0.01 && (curr.dy - next.dy).abs() < 0.01;
      final isVertical =
          (prev.dx - curr.dx).abs() < 0.01 && (curr.dx - next.dx).abs() < 0.01;

      if (!isHorizontal && !isVertical) {
        simplified.add(curr);
      }
    }

    simplified.add(path.last);
    return simplified;
  }
}

enum _Direction { up, down, left, right }

class _AStarNode {
  const _AStarNode({
    required this.pos,
    required this.g,
    required this.f,
    required this.direction,
  });

  final (int, int) pos;
  final double g;
  final double f;
  final _Direction direction;
}
