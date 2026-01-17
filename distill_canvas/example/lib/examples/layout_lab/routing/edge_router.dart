import 'dart:ui';

import '../algorithms/layout_algorithm.dart';

/// Result of edge routing - a list of points forming the edge path.
class RoutedEdge {
  const RoutedEdge({required this.edgeId, required this.points});

  /// The edge this routing is for.
  final String edgeId;

  /// Points forming the edge path.
  /// First point is at the source node, last point is at the target node.
  /// Intermediate points are bends/control points.
  final List<Offset> points;

  /// Whether this is a straight line (2 points).
  bool get isStraight => points.length == 2;

  /// Whether this has bends (more than 2 points).
  bool get hasBends => points.length > 2;
}

/// Abstract interface for edge routing algorithms.
abstract class EdgeRouter {
  /// Human-readable name of the router.
  String get name;

  /// Short description of how the router works.
  String get description;

  /// Route a single edge between two nodes.
  ///
  /// [start] - Center position of the source node.
  /// [startSize] - Size of the source node.
  /// [startSide] - Which side of the source node to exit from.
  /// [end] - Center position of the target node.
  /// [endSize] - Size of the target node.
  /// [endSide] - Which side of the target node to enter.
  /// [obstacles] - Bounding boxes of other nodes to avoid.
  /// [options] - Router-specific options.
  ///
  /// Returns a list of points forming the edge path.
  List<Offset> route({
    required Offset start,
    required Size startSize,
    required PortSide startSide,
    required Offset end,
    required Size endSize,
    required PortSide endSide,
    List<Rect> obstacles = const [],
    Map<String, dynamic>? options,
  });

  /// Calculate the connection point on a node's edge given its center, size, and port side.
  static Offset getPortPosition(Offset center, Size size, PortSide side) {
    return switch (side) {
      PortSide.top => Offset(center.dx, center.dy - size.height / 2),
      PortSide.bottom => Offset(center.dx, center.dy + size.height / 2),
      PortSide.left => Offset(center.dx - size.width / 2, center.dy),
      PortSide.right => Offset(center.dx + size.width / 2, center.dy),
    };
  }
}
