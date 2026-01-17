import 'dart:ui';

/// Direction for hierarchical/tree layouts.
enum LayoutDirection { topToBottom, bottomToTop, leftToRight, rightToLeft }

/// Which side of a node edges connect to.
enum PortSide { top, bottom, left, right }

/// A node to be positioned by a layout algorithm.
class LayoutNode {
  const LayoutNode({required this.id, required this.size, this.pinned});

  /// Unique identifier for this node.
  final String id;

  /// Size of the node (required for spacing calculations).
  final Size size;

  /// Optional pinned position (user-dragged override).
  /// If set, the algorithm should respect this position.
  final Offset? pinned;

  @override
  String toString() => 'LayoutNode($id, $size)';
}

/// An edge connecting two nodes.
class LayoutEdge {
  const LayoutEdge({
    required this.id,
    required this.fromId,
    required this.toId,
  });

  /// Unique identifier for this edge.
  final String id;

  /// ID of the source node.
  final String fromId;

  /// ID of the target node.
  final String toId;

  @override
  String toString() => 'LayoutEdge($fromId -> $toId)';
}

/// Result of a layout computation.
class LayoutResult {
  const LayoutResult({
    required this.positions,
    this.entryPorts = const {},
    this.exitPorts = const {},
    this.edgeCrossings = 0,
    this.totalEdgeLength = 0,
    this.computeTime = Duration.zero,
  });

  /// Empty result for when layout fails or has no nodes.
  static const empty = LayoutResult(positions: {});

  /// Computed positions for each node (by ID).
  final Map<String, Offset> positions;

  /// Which side edges enter each node (by node ID).
  /// Used by edge routers to determine connection points.
  final Map<String, PortSide> entryPorts;

  /// Which side edges exit each node (by node ID).
  /// Used by edge routers to determine connection points.
  final Map<String, PortSide> exitPorts;

  /// Number of edge crossings in the layout (quality metric).
  /// Lower is better.
  final int edgeCrossings;

  /// Total length of all edges (quality metric).
  /// Lower generally means more compact layout.
  final double totalEdgeLength;

  /// Time taken to compute the layout.
  final Duration computeTime;

  /// Get the entry port for a node, defaulting based on direction.
  PortSide getEntryPort(String nodeId, LayoutDirection direction) {
    return entryPorts[nodeId] ?? _defaultEntryPort(direction);
  }

  /// Get the exit port for a node, defaulting based on direction.
  PortSide getExitPort(String nodeId, LayoutDirection direction) {
    return exitPorts[nodeId] ?? _defaultExitPort(direction);
  }

  static PortSide _defaultEntryPort(LayoutDirection direction) {
    return switch (direction) {
      LayoutDirection.topToBottom => PortSide.top,
      LayoutDirection.bottomToTop => PortSide.bottom,
      LayoutDirection.leftToRight => PortSide.left,
      LayoutDirection.rightToLeft => PortSide.right,
    };
  }

  static PortSide _defaultExitPort(LayoutDirection direction) {
    return switch (direction) {
      LayoutDirection.topToBottom => PortSide.bottom,
      LayoutDirection.bottomToTop => PortSide.top,
      LayoutDirection.leftToRight => PortSide.right,
      LayoutDirection.rightToLeft => PortSide.left,
    };
  }
}

/// Abstract interface for layout algorithms.
abstract class LayoutAlgorithm {
  /// Human-readable name of the algorithm.
  String get name;

  /// Short description of how the algorithm works.
  String get description;

  /// Which directions this algorithm supports.
  /// Force-directed and circular layouts typically return an empty set
  /// (direction doesn't apply).
  Set<LayoutDirection> get supportedDirections;

  /// Compute positions for all nodes.
  ///
  /// [nodes] - The nodes to position, with their sizes.
  /// [edges] - The edges connecting nodes.
  /// [bounds] - The available space for layout.
  /// [direction] - Flow direction (for hierarchical/tree layouts).
  /// [options] - Algorithm-specific options (spacing, etc).
  LayoutResult layout({
    required List<LayoutNode> nodes,
    required List<LayoutEdge> edges,
    required Size bounds,
    LayoutDirection direction = LayoutDirection.topToBottom,
    Map<String, dynamic>? options,
  });
}
