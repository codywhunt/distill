import 'dart:math' as math;
import 'dart:ui';

import 'layout_algorithm.dart';

/// Force-directed layout using the Fruchterman-Reingold algorithm
/// with Barnes-Hut optimization via QuadTree.
///
/// Nodes repel each other, edges act as springs pulling connected
/// nodes together. The simulation runs until convergence or max iterations.
///
/// Complexity: O(n log n) per iteration with Barnes-Hut, O(iterations * n log n) total.
class ForceDirectedLayout implements LayoutAlgorithm {
  const ForceDirectedLayout({
    this.iterations = 100,
    this.idealEdgeLength = 100.0,
    this.repulsionStrength = 10000.0,
    this.attractionStrength = 0.1,
    this.damping = 0.9,
    this.theta = 0.8,
    this.convergenceThreshold = 0.1,
  });

  /// Maximum number of simulation iterations.
  final int iterations;

  /// Ideal length for edges (spring rest length).
  final double idealEdgeLength;

  /// Strength of repulsion between nodes.
  final double repulsionStrength;

  /// Strength of attraction along edges.
  final double attractionStrength;

  /// Velocity damping factor (0-1). Higher = faster settling.
  final double damping;

  /// Barnes-Hut theta parameter. Higher = faster but less accurate.
  /// 0 = exact N-body, 0.5-1.0 typical for graphs.
  final double theta;

  /// Stop iterating when max movement falls below this.
  final double convergenceThreshold;

  @override
  String get name => 'Force-Directed';

  @override
  String get description =>
      'Spring physics simulation with Barnes-Hut optimization';

  @override
  Set<LayoutDirection> get supportedDirections => {};

  @override
  LayoutResult layout({
    required List<LayoutNode> nodes,
    required List<LayoutEdge> edges,
    required Size bounds,
    LayoutDirection direction = LayoutDirection.topToBottom,
    Map<String, dynamic>? options,
  }) {
    final stopwatch = Stopwatch()..start();

    if (nodes.isEmpty) {
      return LayoutResult(positions: {}, computeTime: stopwatch.elapsed);
    }

    // Read spacing from options, fallback to constructor defaults
    // For force-directed, layerSpacing maps to ideal edge length
    final effectiveEdgeLength =
        (options?['layerSpacing'] as double?) ?? idealEdgeLength;

    // Initialize positions (respecting pinned positions)
    final positions = <String, Offset>{};
    final velocities = <String, Offset>{};
    final nodeMap = <String, LayoutNode>{};
    final pinnedNodes = <String>{};

    final random = math.Random(42); // Fixed seed for reproducibility

    for (final node in nodes) {
      nodeMap[node.id] = node;
      velocities[node.id] = Offset.zero;

      if (node.pinned != null) {
        positions[node.id] = node.pinned!;
        pinnedNodes.add(node.id);
      } else {
        // Random initial position within bounds
        positions[node.id] = Offset(
          bounds.width * 0.2 + random.nextDouble() * bounds.width * 0.6,
          bounds.height * 0.2 + random.nextDouble() * bounds.height * 0.6,
        );
      }
    }

    // Build adjacency for attraction forces
    final adjacency = <String, Set<String>>{};
    for (final node in nodes) {
      adjacency[node.id] = {};
    }
    for (final edge in edges) {
      if (nodeMap.containsKey(edge.fromId) && nodeMap.containsKey(edge.toId)) {
        adjacency[edge.fromId]!.add(edge.toId);
        adjacency[edge.toId]!.add(edge.fromId);
      }
    }

    // Simulation loop
    for (var iter = 0; iter < iterations; iter++) {
      // Build QuadTree for Barnes-Hut approximation
      final quadTree = _buildQuadTree(positions, nodeMap, bounds);

      // Calculate forces
      final forces = <String, Offset>{};
      for (final node in nodes) {
        forces[node.id] = Offset.zero;
      }

      // Repulsion forces (using QuadTree)
      for (final node in nodes) {
        if (pinnedNodes.contains(node.id)) continue;

        final pos = positions[node.id]!;
        final repulsion = quadTree.calculateRepulsion(
          pos,
          node.id,
          repulsionStrength,
          theta,
        );
        forces[node.id] = forces[node.id]! + repulsion;
      }

      // Attraction forces (edges as springs)
      for (final edge in edges) {
        final fromPos = positions[edge.fromId];
        final toPos = positions[edge.toId];
        if (fromPos == null || toPos == null) continue;

        final delta = toPos - fromPos;
        final distance = delta.distance;
        if (distance < 0.01) continue;

        final displacement = distance - effectiveEdgeLength;
        final force = delta / distance * displacement * attractionStrength;

        if (!pinnedNodes.contains(edge.fromId)) {
          forces[edge.fromId] = forces[edge.fromId]! + force;
        }
        if (!pinnedNodes.contains(edge.toId)) {
          forces[edge.toId] = forces[edge.toId]! - force;
        }
      }

      // Apply forces and update positions
      var maxMovement = 0.0;

      for (final node in nodes) {
        if (pinnedNodes.contains(node.id)) continue;

        // Update velocity
        var velocity = velocities[node.id]! + forces[node.id]!;
        velocity = velocity * damping;
        velocities[node.id] = velocity;

        // Update position
        var newPos = positions[node.id]! + velocity;

        // Keep within bounds with padding
        const padding = 50.0;
        newPos = Offset(
          newPos.dx.clamp(padding, bounds.width - padding),
          newPos.dy.clamp(padding, bounds.height - padding),
        );

        final movement = (newPos - positions[node.id]!).distance;
        maxMovement = math.max(maxMovement, movement);

        positions[node.id] = newPos;
      }

      // Check convergence
      if (maxMovement < convergenceThreshold) {
        break;
      }
    }

    // Calculate metrics
    final totalLength = _calculateTotalEdgeLength(positions, edges);

    stopwatch.stop();

    return LayoutResult(
      positions: positions,
      totalEdgeLength: totalLength,
      computeTime: stopwatch.elapsed,
    );
  }

  /// Build a QuadTree from node positions for Barnes-Hut.
  _ForceQuadTree _buildQuadTree(
    Map<String, Offset> positions,
    Map<String, LayoutNode> nodeMap,
    Size bounds,
  ) {
    final tree = _ForceQuadTree(
      bounds: Rect.fromLTWH(0, 0, bounds.width, bounds.height),
    );

    for (final entry in positions.entries) {
      tree.insert(entry.key, entry.value);
    }

    return tree;
  }

  double _calculateTotalEdgeLength(
    Map<String, Offset> positions,
    List<LayoutEdge> edges,
  ) {
    var total = 0.0;
    for (final edge in edges) {
      final from = positions[edge.fromId];
      final to = positions[edge.toId];
      if (from != null && to != null) {
        total += (to - from).distance;
      }
    }
    return total;
  }
}

/// QuadTree node for Barnes-Hut force calculation.
class _ForceQuadTree {
  _ForceQuadTree({required this.bounds});

  final Rect bounds;
  final List<(String, Offset)> _points = [];
  List<_ForceQuadTree>? _children;

  // Center of mass for Barnes-Hut
  Offset _centerOfMass = Offset.zero;
  int _totalMass = 0;

  static const int _maxPoints = 1;
  static const int _maxDepth = 10;
  int _depth = 0;

  void insert(String id, Offset position) {
    if (!bounds.contains(position)) return;

    _totalMass++;
    _centerOfMass = Offset(
      (_centerOfMass.dx * (_totalMass - 1) + position.dx) / _totalMass,
      (_centerOfMass.dy * (_totalMass - 1) + position.dy) / _totalMass,
    );

    if (_children != null) {
      _insertIntoChildren(id, position);
      return;
    }

    _points.add((id, position));

    if (_points.length > _maxPoints && _depth < _maxDepth) {
      _subdivide();
    }
  }

  void _subdivide() {
    final midX = bounds.center.dx;
    final midY = bounds.center.dy;

    _children = [
      _ForceQuadTree(bounds: Rect.fromLTRB(bounds.left, bounds.top, midX, midY))
        .._depth = _depth + 1,
      _ForceQuadTree(
        bounds: Rect.fromLTRB(midX, bounds.top, bounds.right, midY),
      ).._depth = _depth + 1,
      _ForceQuadTree(
        bounds: Rect.fromLTRB(bounds.left, midY, midX, bounds.bottom),
      ).._depth = _depth + 1,
      _ForceQuadTree(
        bounds: Rect.fromLTRB(midX, midY, bounds.right, bounds.bottom),
      ).._depth = _depth + 1,
    ];

    for (final point in _points) {
      _insertIntoChildren(point.$1, point.$2);
    }
    _points.clear();
  }

  void _insertIntoChildren(String id, Offset position) {
    for (final child in _children!) {
      if (child.bounds.contains(position)) {
        child.insert(id, position);
        return;
      }
    }
  }

  /// Calculate repulsion force using Barnes-Hut approximation.
  Offset calculateRepulsion(
    Offset nodePos,
    String nodeId,
    double strength,
    double theta,
  ) {
    if (_totalMass == 0) return Offset.zero;

    // If this is a leaf with only the requesting node, no force
    if (_children == null &&
        _points.length == 1 &&
        _points.first.$1 == nodeId) {
      return Offset.zero;
    }

    final delta = nodePos - _centerOfMass;
    final distance = delta.distance;

    if (distance < 0.01) return Offset.zero;

    // Barnes-Hut criterion: use approximation if node is far enough
    final nodeSize = bounds.width;

    if (_children == null || nodeSize / distance < theta) {
      // For leaf nodes, subtract 1 from mass if this node is in here
      var effectiveMass = _totalMass;
      if (_children == null) {
        for (final point in _points) {
          if (point.$1 == nodeId) {
            effectiveMass--;
            break;
          }
        }
      }
      if (effectiveMass <= 0) return Offset.zero;

      // Treat as single body
      final force = strength * effectiveMass / (distance * distance);
      return delta / distance * force;
    }

    // Recurse into children
    var totalForce = Offset.zero;
    for (final child in _children!) {
      totalForce += child.calculateRepulsion(nodePos, nodeId, strength, theta);
    }
    return totalForce;
  }
}
