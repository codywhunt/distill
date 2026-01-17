import 'dart:math' as math;
import 'dart:ui';

import 'layout_algorithm.dart';

/// Hierarchical layout algorithm (Sugiyama-style).
///
/// Arranges nodes in layers based on their dependencies, with edges
/// flowing in the specified direction. Attempts to minimize edge crossings
/// through layer ordering.
///
/// Complexity: O(V * E) due to crossing minimization phase.
class HierarchicalLayout implements LayoutAlgorithm {
  const HierarchicalLayout({
    this.layerSpacing = 80.0,
    this.nodeSpacing = 40.0,
    this.crossingMinimizationIterations = 4,
  });

  /// Spacing between layers (perpendicular to flow direction).
  final double layerSpacing;

  /// Spacing between nodes within a layer.
  final double nodeSpacing;

  /// Number of iterations for crossing minimization.
  /// Higher = better quality, slower.
  final int crossingMinimizationIterations;

  @override
  String get name => 'Hierarchical';

  @override
  String get description => 'Layered layout with edge crossing minimization';

  @override
  Set<LayoutDirection> get supportedDirections => {
    LayoutDirection.topToBottom,
    LayoutDirection.bottomToTop,
    LayoutDirection.leftToRight,
    LayoutDirection.rightToLeft,
  };

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
    final effectiveLayerSpacing =
        (options?['layerSpacing'] as double?) ?? layerSpacing;
    final effectiveNodeSpacing =
        (options?['nodeSpacing'] as double?) ?? nodeSpacing;

    // Build adjacency lists
    final nodeMap = {for (final n in nodes) n.id: n};
    final outgoing = <String, List<String>>{};
    final incoming = <String, List<String>>{};

    for (final node in nodes) {
      outgoing[node.id] = [];
      incoming[node.id] = [];
    }

    for (final edge in edges) {
      if (nodeMap.containsKey(edge.fromId) && nodeMap.containsKey(edge.toId)) {
        outgoing[edge.fromId]!.add(edge.toId);
        incoming[edge.toId]!.add(edge.fromId);
      }
    }

    // Phase 1: Assign nodes to layers using longest path (BFS-based)
    final layers = _assignLayers(nodes, outgoing, incoming);

    // Phase 2: Order nodes within layers to minimize crossings
    _minimizeCrossings(layers, outgoing, incoming);

    // Phase 3: Assign positions
    final positions = _assignPositions(
      layers,
      nodeMap,
      direction,
      bounds,
      effectiveLayerSpacing,
      effectiveNodeSpacing,
    );

    // Respect pinned positions
    for (final node in nodes) {
      if (node.pinned != null) {
        positions[node.id] = node.pinned!;
      }
    }

    // Calculate metrics
    final edgeCrossings = _countCrossings(layers, outgoing);
    final totalLength = _calculateTotalEdgeLength(positions, edges);

    // Calculate port assignments based on direction
    final entryPorts = <String, PortSide>{};
    final exitPorts = <String, PortSide>{};

    for (final node in nodes) {
      entryPorts[node.id] = _getEntryPort(direction);
      exitPorts[node.id] = _getExitPort(direction);
    }

    stopwatch.stop();

    return LayoutResult(
      positions: positions,
      entryPorts: entryPorts,
      exitPorts: exitPorts,
      edgeCrossings: edgeCrossings,
      totalEdgeLength: totalLength,
      computeTime: stopwatch.elapsed,
    );
  }

  /// Assign nodes to layers using longest path from sources (BFS-based).
  /// Handles cycles by tracking re-queue count and forcing assignment.
  List<List<String>> _assignLayers(
    List<LayoutNode> nodes,
    Map<String, List<String>> outgoing,
    Map<String, List<String>> incoming,
  ) {
    final layerAssignment = <String, int>{};

    // Find source nodes (no incoming edges)
    final sources =
        nodes.where((n) => incoming[n.id]!.isEmpty).map((n) => n.id).toList();

    // If no sources (cyclic), pick node with minimum incoming edges
    if (sources.isEmpty) {
      final minIncoming = nodes.reduce(
        (a, b) => incoming[a.id]!.length <= incoming[b.id]!.length ? a : b,
      );
      sources.add(minIncoming.id);
    }

    // Initialize all sources at layer 0
    for (final source in sources) {
      layerAssignment[source] = 0;
    }

    // BFS to assign layers - each node is at max(predecessor layers) + 1
    final queue = [...sources];
    final processed = <String>{};
    final requeueCount = <String, int>{}; // Track re-queues to detect cycles
    final maxRequeues =
        nodes.length; // If re-queued more than this, it's a cycle

    while (queue.isNotEmpty) {
      final nodeId = queue.removeAt(0);

      if (processed.contains(nodeId)) continue;

      // Check if all predecessors are assigned (ignore back-edges in cycles)
      final predecessors = incoming[nodeId]!;
      final assignedPredecessors =
          predecessors.where((p) => layerAssignment.containsKey(p)).toList();
      final allPredecessorsAssigned =
          assignedPredecessors.length == predecessors.length;

      // Track re-queues to detect cycles
      requeueCount[nodeId] = (requeueCount[nodeId] ?? 0) + 1;
      final possibleCycle = requeueCount[nodeId]! > maxRequeues;

      if (!allPredecessorsAssigned &&
          predecessors.isNotEmpty &&
          !possibleCycle) {
        // Re-queue this node - predecessors not ready yet
        queue.add(nodeId);
        continue;
      }

      // Calculate layer as max assigned predecessor layer + 1
      // (unassigned predecessors are part of a cycle, ignore them)
      if (assignedPredecessors.isNotEmpty) {
        final maxPredLayer = assignedPredecessors
            .map((p) => layerAssignment[p]!)
            .reduce(math.max);
        layerAssignment[nodeId] = maxPredLayer + 1;
      } else if (!layerAssignment.containsKey(nodeId)) {
        layerAssignment[nodeId] = 0;
      }

      processed.add(nodeId);

      // Add successors to queue
      for (final successor in outgoing[nodeId]!) {
        if (!processed.contains(successor)) {
          queue.add(successor);
        }
      }
    }

    // Handle any unprocessed nodes (disconnected components)
    for (final node in nodes) {
      if (!layerAssignment.containsKey(node.id)) {
        layerAssignment[node.id] = 0;
      }
    }

    // Convert to layer lists
    final maxLayer = layerAssignment.values.fold(0, math.max);
    final layers = List.generate(maxLayer + 1, (_) => <String>[]);

    for (final entry in layerAssignment.entries) {
      layers[entry.value].add(entry.key);
    }

    return layers;
  }

  /// Minimize edge crossings using the barycenter heuristic.
  void _minimizeCrossings(
    List<List<String>> layers,
    Map<String, List<String>> outgoing,
    Map<String, List<String>> incoming,
  ) {
    for (var iter = 0; iter < crossingMinimizationIterations; iter++) {
      // Forward sweep
      for (var i = 1; i < layers.length; i++) {
        _orderLayerByBarycenter(layers[i], layers[i - 1], incoming);
      }

      // Backward sweep
      for (var i = layers.length - 2; i >= 0; i--) {
        _orderLayerByBarycenter(layers[i], layers[i + 1], outgoing);
      }
    }
  }

  /// Order a layer by the barycenter (average position) of connected nodes.
  void _orderLayerByBarycenter(
    List<String> layer,
    List<String> referenceLayer,
    Map<String, List<String>> connections,
  ) {
    final refPositions = <String, int>{};
    for (var i = 0; i < referenceLayer.length; i++) {
      refPositions[referenceLayer[i]] = i;
    }

    final barycenters = <String, double>{};

    for (final nodeId in layer) {
      final connectedIds =
          connections[nodeId]!
              .where((id) => refPositions.containsKey(id))
              .toList();

      if (connectedIds.isEmpty) {
        barycenters[nodeId] = double.infinity;
      } else {
        final sum = connectedIds
            .map((id) => refPositions[id]!)
            .fold(0, (a, b) => a + b);
        barycenters[nodeId] = sum / connectedIds.length;
      }
    }

    layer.sort((a, b) => barycenters[a]!.compareTo(barycenters[b]!));
  }

  /// Assign final positions to nodes.
  Map<String, Offset> _assignPositions(
    List<List<String>> layers,
    Map<String, LayoutNode> nodeMap,
    LayoutDirection direction,
    Size bounds,
    double effectiveLayerSpacing,
    double effectiveNodeSpacing,
  ) {
    final positions = <String, Offset>{};
    final isHorizontal =
        direction == LayoutDirection.leftToRight ||
        direction == LayoutDirection.rightToLeft;
    final isReversed =
        direction == LayoutDirection.bottomToTop ||
        direction == LayoutDirection.rightToLeft;

    // Calculate layer positions
    double layerPosition = effectiveLayerSpacing;
    final layerPositions = <double>[];

    for (var i = 0; i < layers.length; i++) {
      layerPositions.add(layerPosition);

      // Find max node size in layer for spacing
      double maxSize = 0;
      for (final nodeId in layers[i]) {
        final node = nodeMap[nodeId]!;
        maxSize = math.max(
          maxSize,
          isHorizontal ? node.size.width : node.size.height,
        );
      }

      layerPosition += maxSize + effectiveLayerSpacing;
    }

    // Reverse if needed
    if (isReversed) {
      layerPositions.setAll(0, layerPositions.reversed.toList());
    }

    // Position nodes in each layer
    for (var layerIndex = 0; layerIndex < layers.length; layerIndex++) {
      final layer = layers[layerIndex];
      final lp = layerPositions[layerIndex];

      // Calculate total width/height of layer
      double totalSize = 0;
      for (final nodeId in layer) {
        final node = nodeMap[nodeId]!;
        totalSize += isHorizontal ? node.size.height : node.size.width;
      }
      totalSize += (layer.length - 1) * effectiveNodeSpacing;

      // Center the layer
      double currentPos =
          isHorizontal
              ? (bounds.height - totalSize) / 2
              : (bounds.width - totalSize) / 2;

      for (final nodeId in layer) {
        final node = nodeMap[nodeId]!;
        final nodeSize = isHorizontal ? node.size.height : node.size.width;

        if (isHorizontal) {
          positions[nodeId] = Offset(lp, currentPos + nodeSize / 2);
        } else {
          positions[nodeId] = Offset(currentPos + nodeSize / 2, lp);
        }

        currentPos += nodeSize + effectiveNodeSpacing;
      }
    }

    return positions;
  }

  /// Count edge crossings between adjacent layers.
  int _countCrossings(
    List<List<String>> layers,
    Map<String, List<String>> outgoing,
  ) {
    var crossings = 0;

    for (var i = 0; i < layers.length - 1; i++) {
      final layer = layers[i];
      final nextLayer = layers[i + 1];

      // Build position maps
      final pos1 = <String, int>{};
      final pos2 = <String, int>{};

      for (var j = 0; j < layer.length; j++) {
        pos1[layer[j]] = j;
      }
      for (var j = 0; j < nextLayer.length; j++) {
        pos2[nextLayer[j]] = j;
      }

      // Collect edges between these layers
      final edgeList = <(int, int)>[];
      for (final nodeId in layer) {
        for (final targetId in outgoing[nodeId]!) {
          if (pos2.containsKey(targetId)) {
            edgeList.add((pos1[nodeId]!, pos2[targetId]!));
          }
        }
      }

      // Count crossings (O(E²) but typically small)
      for (var a = 0; a < edgeList.length; a++) {
        for (var b = a + 1; b < edgeList.length; b++) {
          final e1 = edgeList[a];
          final e2 = edgeList[b];

          // Edges cross if they swap relative order
          if ((e1.$1 < e2.$1 && e1.$2 > e2.$2) ||
              (e1.$1 > e2.$1 && e1.$2 < e2.$2)) {
            crossings++;
          }
        }
      }
    }

    return crossings;
  }

  /// Calculate total edge length for quality metric.
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

  PortSide _getEntryPort(LayoutDirection direction) {
    return switch (direction) {
      LayoutDirection.topToBottom => PortSide.top,
      LayoutDirection.bottomToTop => PortSide.bottom,
      LayoutDirection.leftToRight => PortSide.left,
      LayoutDirection.rightToLeft => PortSide.right,
    };
  }

  PortSide _getExitPort(LayoutDirection direction) {
    return switch (direction) {
      LayoutDirection.topToBottom => PortSide.bottom,
      LayoutDirection.bottomToTop => PortSide.top,
      LayoutDirection.leftToRight => PortSide.right,
      LayoutDirection.rightToLeft => PortSide.left,
    };
  }
}
