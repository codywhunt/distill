import 'dart:ui';

import '../algorithms/layout_algorithm.dart';
import 'edge_router.dart';

/// Simple straight-line edge router.
///
/// Draws a direct line between the port positions on source and target nodes.
/// No obstacle avoidance.
class StraightRouter implements EdgeRouter {
  const StraightRouter();

  @override
  String get name => 'Straight';

  @override
  String get description => 'Direct line between nodes';

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

    return [startPort, endPort];
  }
}
