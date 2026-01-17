import 'dart:collection';
import 'dart:ui' show Offset, Rect;

import '../../../models/page_model.dart';
import 'storyboard_config.dart';
import 'storyboard_layout.dart';

/// Represents a node in the layout graph (real page or dummy vertex).
///
/// Dummy vertices are inserted for edges spanning multiple layers,
/// allowing proper crossing minimization and edge routing.
class _LayoutNode {
  const _LayoutNode({
    required this.id,
    required this.isDummy,
    this.originalEdgeFrom,
    this.originalEdgeTo,
  });

  /// Unique identifier for this node.
  final String id;

  /// Whether this is a dummy vertex (invisible routing point).
  final bool isDummy;

  /// For dummy vertices: the source page ID of the original edge.
  final String? originalEdgeFrom;

  /// For dummy vertices: the target page ID of the original edge.
  final String? originalEdgeTo;
}

/// Engine for computing storyboard layout.
///
/// Uses a hierarchical (Sugiyama-style) layout algorithm:
/// 1. Build directed graph from page connections
/// 2. Identify root nodes (pages with no incoming edges)
/// 3. Assign layers based on longest path from roots
/// 4. Insert dummy vertices for edges spanning multiple layers
/// 5. Reduce edge crossings within layers (including dummies)
/// 6. Assign coordinates with consistent spacing
/// 7. Route connections through dummy vertex positions
///
/// Spacing is dynamically computed based on actual page sizes.
class StoryboardLayoutEngine {
  StoryboardLayoutEngine({
    this.baseLayerSpacing = StoryboardConfig.layerSpacing,
    this.baseNodeSpacing = StoryboardConfig.nodeSpacing,
    this.orphanSpacing = StoryboardConfig.orphanSpacing,
  });

  /// Base horizontal gap between layers (added to max page width).
  final double baseLayerSpacing;

  /// Base vertical gap between nodes (added to max page height in layer).
  final double baseNodeSpacing;

  /// Gap between main flowchart and orphan section.
  final double orphanSpacing;

  /// Compute layout for all pages.
  StoryboardLayout compute(List<PageModel> pages) {
    if (pages.isEmpty) {
      return StoryboardLayout.empty;
    }

    // Build page map for size lookups
    final pageMap = {for (final p in pages) p.id: p};

    // 1. Build adjacency structures
    final (graph, reverseGraph) = _buildGraphs(pages);

    // 2. Find root nodes (no incoming edges)
    final roots = _findRoots(pages, reverseGraph);

    // 3. Separate connected vs orphan pages
    final (connected, orphans) = _partitionPages(pages, graph, reverseGraph);

    // 4. Compute positions (includes dummy vertex insertion)
    final positions = <String, Offset>{};
    Map<String, Set<String>> extendedGraph = graph;
    Set<String> dummyIds = {};

    if (connected.isNotEmpty) {
      // Filter roots to only include connected pages (exclude orphans)
      final connectedIds = connected.map((p) => p.id).toSet();
      final connectedRoots = roots.where((r) => connectedIds.contains(r)).toSet();

      // Run hierarchical layout on connected pages
      // This inserts dummy vertices and returns the extended graph
      (extendedGraph, dummyIds) = _computeHierarchicalLayout(
        connected,
        connectedRoots,
        graph,
        positions,
      );
    }

    // 5. Position orphans below
    _positionOrphans(orphans, positions, pageMap);

    // 6. Respect pinned positions (override computed)
    _applyPinnedPositions(pages, positions);

    // 7. Route connections through dummy vertices
    final connections = _routeConnections(
      pages,
      positions,
      graph,
      extendedGraph,
      dummyIds,
    );

    // 8. Compute bounds (only real pages, not dummies)
    final bounds = _computeBounds(positions, pages);

    return StoryboardLayout(
      positions: positions,
      connections: connections,
      bounds: bounds,
    );
  }

  /// Build forward and reverse adjacency graphs.
  (Map<String, Set<String>>, Map<String, Set<String>>) _buildGraphs(
    List<PageModel> pages,
  ) {
    final graph = <String, Set<String>>{};
    final reverseGraph = <String, Set<String>>{};

    // Initialize all nodes
    for (final page in pages) {
      graph[page.id] = {};
      reverseGraph[page.id] = {};
    }

    // Build edges
    final pageIds = pages.map((p) => p.id).toSet();
    for (final page in pages) {
      for (final targetId in page.connectsTo) {
        if (pageIds.contains(targetId)) {
          graph[page.id]!.add(targetId);
          reverseGraph[targetId]!.add(page.id);
        }
      }
    }

    return (graph, reverseGraph);
  }

  /// Find root nodes (pages with no incoming edges).
  Set<String> _findRoots(
    List<PageModel> pages,
    Map<String, Set<String>> reverseGraph,
  ) {
    final roots = <String>{};
    for (final page in pages) {
      if (reverseGraph[page.id]?.isEmpty ?? true) {
        // Only include if it has outgoing connections or is the only page
        // This prevents orphans from being treated as roots
        roots.add(page.id);
      }
    }
    return roots;
  }

  /// Partition pages into connected and orphan sets.
  ///
  /// Connected: pages that are part of the connection graph (have edges)
  /// Orphans: pages with no connections at all
  (List<PageModel>, List<PageModel>) _partitionPages(
    List<PageModel> pages,
    Map<String, Set<String>> graph,
    Map<String, Set<String>> reverseGraph,
  ) {
    final connected = <PageModel>[];
    final orphans = <PageModel>[];

    for (final page in pages) {
      final hasOutgoing = graph[page.id]?.isNotEmpty ?? false;
      final hasIncoming = reverseGraph[page.id]?.isNotEmpty ?? false;

      if (hasOutgoing || hasIncoming) {
        connected.add(page);
      } else {
        orphans.add(page);
      }
    }

    return (connected, orphans);
  }

  /// Compute hierarchical layout positions.
  ///
  /// Returns the extended graph (with dummy vertices) and the set of dummy IDs
  /// for use in edge routing.
  (Map<String, Set<String>>, Set<String>) _computeHierarchicalLayout(
    List<PageModel> pages,
    Set<String> roots,
    Map<String, Set<String>> graph,
    Map<String, Offset> positions,
  ) {
    final pageMap = {for (final p in pages) p.id: p};

    // Phase 1: Layer assignment (longest path from roots)
    final layers = _assignLayers(pages, roots, graph);

    // Phase 2: Insert dummy vertices for edges spanning multiple layers
    final (extendedGraph, dummyNodes) = _insertDummyVertices(layers, graph);

    // Phase 3: Crossing reduction (simple barycenter) - real nodes only
    // Dummies will be positioned separately to route around nodes
    final layerOrder = _reduceCrossings(layers, extendedGraph);

    // Phase 4: Coordinate assignment
    // First position real nodes, then position dummies to route around them
    _assignCoordinates(layerOrder, positions, dummyNodes, pageMap);

    return (extendedGraph, dummyNodes.keys.toSet());
  }

  /// Insert dummy vertices for edges spanning multiple layers.
  ///
  /// For an edge A→B where A is in layer 0 and B is in layer 3:
  /// - Create dummy D1 in layer 1
  /// - Create dummy D2 in layer 2
  /// - Replace edge A→B with: A→D1, D1→D2, D2→B
  ///
  /// Returns the extended graph and a map of dummy node ID to _LayoutNode.
  (Map<String, Set<String>>, Map<String, _LayoutNode>) _insertDummyVertices(
    Map<String, int> layers,
    Map<String, Set<String>> originalGraph,
  ) {
    final extendedGraph = <String, Set<String>>{};
    final dummyNodes = <String, _LayoutNode>{};
    var dummyCounter = 0;

    // Initialize extended graph with original nodes
    for (final nodeId in originalGraph.keys) {
      extendedGraph[nodeId] = {};
    }

    // Process each edge
    for (final sourceId in originalGraph.keys) {
      final sourceLayer = layers[sourceId];
      if (sourceLayer == null) continue;

      for (final targetId in originalGraph[sourceId]!) {
        final targetLayer = layers[targetId];
        if (targetLayer == null) continue;

        final layerSpan = targetLayer - sourceLayer;

        if (layerSpan <= 0) {
          // Back-edge or same-layer edge - skip (handled elsewhere)
          continue;
        } else if (layerSpan == 1) {
          // Adjacent layers - no dummy needed
          extendedGraph[sourceId]!.add(targetId);
        } else {
          // Insert dummy vertices for each intermediate layer
          var prevId = sourceId;

          for (var layer = sourceLayer + 1; layer < targetLayer; layer++) {
            final dummyId = '_dummy_${dummyCounter++}';

            dummyNodes[dummyId] = _LayoutNode(
              id: dummyId,
              isDummy: true,
              originalEdgeFrom: sourceId,
              originalEdgeTo: targetId,
            );

            // Add dummy to layer assignment
            layers[dummyId] = layer;

            // Add edge from previous node to dummy
            extendedGraph.putIfAbsent(dummyId, () => {});
            extendedGraph[prevId]!.add(dummyId);

            prevId = dummyId;
          }

          // Add final edge from last dummy to target
          extendedGraph[prevId]!.add(targetId);
        }
      }
    }

    return (extendedGraph, dummyNodes);
  }

  /// Assign each node to a layer based on longest path from roots.
  ///
  /// Handles disconnected components by processing them as separate
  /// sub-graphs, each starting from layer 0.
  Map<String, int> _assignLayers(
    List<PageModel> pages,
    Set<String> roots,
    Map<String, Set<String>> graph,
  ) {
    final layers = <String, int>{};
    final pageIds = pages.map((p) => p.id).toSet();

    // If no roots identified, use first page
    final effectiveRoots = roots.isNotEmpty ? roots : {pages.first.id};

    // BFS for layer assignment
    // Only assigns layers to unvisited nodes (ignores back-edges in cycles)
    void bfsFromRoots(Set<String> startNodes) {
      final queue = Queue<String>.from(startNodes);
      final inQueue = <String>{...startNodes};

      for (final root in startNodes) {
        if (!layers.containsKey(root)) {
          layers[root] = 0;
        }
      }

      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        inQueue.remove(current);
        final currentLayer = layers[current]!;

        for (final target in graph[current] ?? <String>{}) {
          if (!pageIds.contains(target)) continue;

          // Skip if already has a layer assignment (handles cycles by ignoring back-edges)
          if (layers.containsKey(target)) continue;

          layers[target] = currentLayer + 1;

          if (!inQueue.contains(target)) {
            queue.add(target);
            inQueue.add(target);
          }
        }
      }
    }

    // First pass: BFS from identified roots
    bfsFromRoots(effectiveRoots);

    // Handle disconnected components (e.g., cycles not reachable from roots)
    // Keep processing until all pages have layer assignments
    var unassigned = pageIds.difference(layers.keys.toSet());

    while (unassigned.isNotEmpty) {
      // Find a node in the unassigned set to use as pseudo-root
      final pseudoRoot = unassigned.first;
      bfsFromRoots({pseudoRoot});

      unassigned = pageIds.difference(layers.keys.toSet());
    }

    return layers;
  }

  /// Reduce edge crossings using barycenter heuristic.
  ///
  /// Returns nodes grouped by layer, ordered to minimize crossings.
  List<List<String>> _reduceCrossings(
    Map<String, int> layers,
    Map<String, Set<String>> graph,
  ) {
    if (layers.isEmpty) return [];

    // Group nodes by layer
    final maxLayer = layers.values.reduce((a, b) => a > b ? a : b);
    final layerGroups = List.generate(maxLayer + 1, (_) => <String>[]);

    for (final entry in layers.entries) {
      layerGroups[entry.value].add(entry.key);
    }

    // Simple barycenter ordering (one pass for now)
    for (var i = 1; i < layerGroups.length; i++) {
      final prevLayer = layerGroups[i - 1];
      final currLayer = layerGroups[i];

      // Calculate barycenter for each node in current layer
      final barycenters = <String, double>{};
      for (final node in currLayer) {
        // Find all predecessors in previous layer
        final predecessors = <int>[];
        for (var j = 0; j < prevLayer.length; j++) {
          if (graph[prevLayer[j]]?.contains(node) ?? false) {
            predecessors.add(j);
          }
        }

        if (predecessors.isNotEmpty) {
          barycenters[node] =
              predecessors.reduce((a, b) => a + b) / predecessors.length;
        } else {
          // Keep original order for nodes without predecessors
          barycenters[node] = currLayer.indexOf(node).toDouble();
        }
      }

      // Sort by barycenter
      currLayer.sort(
        (a, b) => (barycenters[a] ?? 0).compareTo(barycenters[b] ?? 0),
      );
    }

    return layerGroups;
  }

  /// Assign x,y coordinates based on layer assignment.
  ///
  /// Two-pass approach:
  /// 1. Position real nodes with consistent spacing
  /// 2. Position dummy vertices to route AROUND real nodes (above or below)
  void _assignCoordinates(
    List<List<String>> layerGroups,
    Map<String, Offset> positions,
    Map<String, _LayoutNode> dummyNodes,
    Map<String, PageModel> pageMap,
  ) {
    final dummyIds = dummyNodes.keys.toSet();

    // Compute maximum page width across all pages for consistent layer spacing
    double maxPageWidth = 0;
    double maxPageHeight = 0;
    for (final page in pageMap.values) {
      if (page.canvasSize.width > maxPageWidth) {
        maxPageWidth = page.canvasSize.width;
      }
      if (page.canvasSize.height > maxPageHeight) {
        maxPageHeight = page.canvasSize.height;
      }
    }

    // Layer spacing is base spacing plus max page width
    final effectiveLayerSpacing = maxPageWidth + baseLayerSpacing;
    // Node spacing is base spacing (pages are centered vertically)
    final effectiveNodeSpacing = baseNodeSpacing;

    // Pass 1: Position real nodes only
    for (var layerIndex = 0; layerIndex < layerGroups.length; layerIndex++) {
      final layer = layerGroups[layerIndex];
      final layerX = layerIndex * effectiveLayerSpacing;

      final realNodes = layer.where((id) => !dummyIds.contains(id)).toList();

      // Calculate total height for this layer using actual page sizes
      double totalHeight = 0;
      for (final nodeId in realNodes) {
        final page = pageMap[nodeId];
        totalHeight += page?.canvasSize.height ?? maxPageHeight;
      }
      if (realNodes.length > 1) {
        totalHeight += (realNodes.length - 1) * effectiveNodeSpacing;
      }

      var currentY = -totalHeight / 2;

      for (final nodeId in realNodes) {
        final page = pageMap[nodeId];
        final pageHeight = page?.canvasSize.height ?? maxPageHeight;
        positions[nodeId] = Offset(layerX, currentY);
        currentY += pageHeight + effectiveNodeSpacing;
      }
    }

    // Pass 2: Position dummies to route around real nodes
    // First, determine the best Y position for each edge's dummies
    // by finding gaps that work across ALL layers the edge passes through

    // Group all dummies by their original edge
    final dummiesByEdge = <String, List<(String dummyId, int layerIndex)>>{};
    for (var layerIndex = 0; layerIndex < layerGroups.length; layerIndex++) {
      final layer = layerGroups[layerIndex];
      for (final nodeId in layer) {
        if (dummyIds.contains(nodeId)) {
          final dummyNode = dummyNodes[nodeId]!;
          final edgeKey = '${dummyNode.originalEdgeFrom}->${dummyNode.originalEdgeTo}';
          dummiesByEdge.putIfAbsent(edgeKey, () => []).add((nodeId, layerIndex));
        }
      }
    }

    // For each edge, find a Y position that works for all its dummies
    for (final edgeEntry in dummiesByEdge.entries) {
      final edgeDummies = edgeEntry.value;
      if (edgeDummies.isEmpty) continue;

      final firstDummy = dummyNodes[edgeDummies.first.$1]!;
      final sourcePos = positions[firstDummy.originalEdgeFrom];
      final targetPos = positions[firstDummy.originalEdgeTo];
      final sourcePage = pageMap[firstDummy.originalEdgeFrom];
      final targetPage = pageMap[firstDummy.originalEdgeTo];

      final sourceHeight = sourcePage?.canvasSize.height ?? maxPageHeight;
      final targetHeight = targetPage?.canvasSize.height ?? maxPageHeight;

      final sourceCenterY = sourcePos != null
          ? sourcePos.dy + sourceHeight / 2
          : 0.0;
      final targetCenterY = targetPos != null
          ? targetPos.dy + targetHeight / 2
          : 0.0;

      // The ideal Y is the midpoint between source and target
      final idealY = (sourceCenterY + targetCenterY) / 2;

      // Find gaps in each layer and collect valid Y positions
      // A valid Y must be in a gap in ALL layers the edge passes through
      List<({double top, double bottom})>? validRange;

      for (final (_, layerIndex) in edgeDummies) {
        final layer = layerGroups[layerIndex];
        final realNodes = layer.where((id) => !dummyIds.contains(id)).toList();
        final nodeBounds = <({double top, double bottom})>[];
        for (final nodeId in realNodes) {
          final pos = positions[nodeId]!;
          final page = pageMap[nodeId];
          final pageHeight = page?.canvasSize.height ?? maxPageHeight;
          nodeBounds.add((top: pos.dy, bottom: pos.dy + pageHeight));
        }
        nodeBounds.sort((a, b) => a.top.compareTo(b.top));

        // Find gaps in this layer
        final layerGaps = <({double top, double bottom})>[];
        if (nodeBounds.isEmpty) {
          layerGaps.add((top: double.negativeInfinity, bottom: double.infinity));
        } else {
          // Gap above all nodes
          layerGaps.add((top: double.negativeInfinity, bottom: nodeBounds.first.top));
          // Gaps between nodes
          for (var i = 0; i < nodeBounds.length - 1; i++) {
            layerGaps.add((top: nodeBounds[i].bottom, bottom: nodeBounds[i + 1].top));
          }
          // Gap below all nodes
          layerGaps.add((top: nodeBounds.last.bottom, bottom: double.infinity));
        }

        if (validRange == null) {
          validRange = layerGaps;
        } else {
          // Intersect with existing valid ranges
          final newValidRange = <({double top, double bottom})>[];
          for (final existing in validRange) {
            for (final gap in layerGaps) {
              final intersectTop = existing.top > gap.top ? existing.top : gap.top;
              final intersectBottom = existing.bottom < gap.bottom ? existing.bottom : gap.bottom;
              if (intersectBottom > intersectTop) {
                newValidRange.add((top: intersectTop, bottom: intersectBottom));
              }
            }
          }
          validRange = newValidRange;
        }
      }

      // Find the best Y within valid ranges (closest to idealY)
      double bestY = idealY;
      if (validRange != null && validRange.isNotEmpty) {
        double bestDistance = double.infinity;
        for (final range in validRange) {
          // Clamp idealY to this range
          final clampedY = idealY < range.top
              ? range.top + effectiveNodeSpacing / 2
              : (idealY > range.bottom ? range.bottom - effectiveNodeSpacing / 2 : idealY);
          final distance = (clampedY - idealY).abs();
          if (distance < bestDistance) {
            bestDistance = distance;
            bestY = clampedY;
          }
        }
      }

      // Position all dummies for this edge at the same Y
      for (final (dummyId, layerIndex) in edgeDummies) {
        final layerX = layerIndex * effectiveLayerSpacing;
        final dummyX = layerIndex > 0
            ? layerX - baseLayerSpacing / 2
            : layerX + maxPageWidth / 2;
        positions[dummyId] = Offset(dummyX, bestY);
      }
    }
  }

  /// Position orphan pages below the main flowchart.
  void _positionOrphans(
    List<PageModel> orphans,
    Map<String, Offset> positions,
    Map<String, PageModel> pageMap,
  ) {
    if (orphans.isEmpty) return;

    // Compute max page height for finding bottom of flowchart
    double maxPageHeight = 0;
    for (final page in pageMap.values) {
      if (page.canvasSize.height > maxPageHeight) {
        maxPageHeight = page.canvasSize.height;
      }
    }

    // Find bottom of main flowchart using actual page heights
    double maxY = 0;
    for (final entry in positions.entries) {
      final page = pageMap[entry.key];
      final pageHeight = page?.canvasSize.height ?? maxPageHeight;
      final bottom = entry.value.dy + pageHeight;
      if (bottom > maxY) maxY = bottom;
    }

    // Add gap if there are existing positions
    final startY = positions.isEmpty ? 0.0 : maxY + orphanSpacing;
    double x = 0;

    for (final orphan in orphans) {
      positions[orphan.id] = Offset(x, startY);
      x += orphan.canvasSize.width + baseNodeSpacing;
    }
  }

  /// Apply pinned positions (override computed positions).
  void _applyPinnedPositions(
    List<PageModel> pages,
    Map<String, Offset> positions,
  ) {
    for (final page in pages) {
      if (page.pinnedPosition != null) {
        positions[page.id] = page.pinnedPosition!;
      }
    }
  }

  /// Route connections between pages through dummy vertices.
  ///
  /// Connection types:
  /// - **Bidirectional** (A↔B): Rendered as single line with arrows on both ends
  /// - **Forward** (A→B): Traced through dummy vertices for clean routing
  /// - **Back-edge** (A→B where B is to the left): Hidden (implicit in hierarchy)
  ///
  /// With dummy vertices, edges naturally route around intermediate nodes
  /// without needing obstacle avoidance heuristics.
  List<ConnectionPath> _routeConnections(
    List<PageModel> pages,
    Map<String, Offset> positions,
    Map<String, Set<String>> originalGraph,
    Map<String, Set<String>> extendedGraph,
    Set<String> dummyIds,
  ) {
    final pageMap = {for (final p in pages) p.id: p};
    final connections = <ConnectionPath>[];

    // Step 1: Identify bidirectional pairs in the original graph
    final edgeSet = <String>{};
    for (final page in pages) {
      for (final targetId in page.connectsTo) {
        edgeSet.add('${page.id}->$targetId');
      }
    }

    final bidirectionalPairs = <String>{};
    for (final page in pages) {
      for (final targetId in page.connectsTo) {
        if (edgeSet.contains('$targetId->${page.id}')) {
          final pairKey = page.id.compareTo(targetId) < 0
              ? '${page.id}<->$targetId'
              : '$targetId<->${page.id}';
          bidirectionalPairs.add(pairKey);
        }
      }
    }

    final processedBidirectional = <String>{};

    // Step 2: Route each original edge through dummy vertices
    for (final page in pages) {
      final fromPos = positions[page.id];
      if (fromPos == null) continue;

      for (final targetId in page.connectsTo) {
        final toPos = positions[targetId];
        if (toPos == null) continue;

        // Check for bidirectional
        final pairKey = page.id.compareTo(targetId) < 0
            ? '${page.id}<->$targetId'
            : '$targetId<->${page.id}';
        final isBidirectional = bidirectionalPairs.contains(pairKey);

        if (isBidirectional) {
          // Only process each bidirectional pair once
          if (processedBidirectional.contains(pairKey)) continue;
          processedBidirectional.add(pairKey);

          // Always route from left to right for bidirectional
          final leftId = fromPos.dx < toPos.dx ? page.id : targetId;
          final rightId = fromPos.dx < toPos.dx ? targetId : page.id;

          final waypoints = _collectWaypoints(
            leftId,
            rightId,
            positions,
            extendedGraph,
            dummyIds,
            pageMap,
          );

          connections.add(ConnectionPath(
            fromPageId: leftId,
            toPageId: rightId,
            waypoints: waypoints,
            isBidirectional: true,
          ));
        } else {
          // Check if this is a back-edge (target is to the left)
          if (toPos.dx < fromPos.dx) continue;

          // Forward edge - trace through dummy vertices
          final waypoints = _collectWaypoints(
            page.id,
            targetId,
            positions,
            extendedGraph,
            dummyIds,
            pageMap,
          );

          connections.add(ConnectionPath(
            fromPageId: page.id,
            toPageId: targetId,
            waypoints: waypoints,
          ));
        }
      }
    }

    return connections;
  }

  /// Collect waypoints for a connection from source to target.
  ///
  /// Traces through dummy vertices in the extended graph to build
  /// orthogonal (right-angle) path waypoints.
  List<Offset> _collectWaypoints(
    String fromId,
    String toId,
    Map<String, Offset> positions,
    Map<String, Set<String>> extendedGraph,
    Set<String> dummyIds,
    Map<String, PageModel> pageMap,
  ) {
    // Collect key points the path must pass through
    final keyPoints = <Offset>[];

    // Start point: exit from right edge of source page
    final fromPos = positions[fromId]!;
    final fromPage = pageMap[fromId];
    if (fromPage == null) return [];

    final startPoint = Offset(
      fromPos.dx + fromPage.canvasSize.width + StoryboardConfig.connectionEdgeGap,
      fromPos.dy + fromPage.canvasSize.height / 2,
    );
    keyPoints.add(startPoint);

    // Find path through dummy vertices from source to target
    final dummyPath = _findPathThroughDummies(fromId, toId, extendedGraph, dummyIds);

    // Add dummy vertex positions as key points
    for (final nodeId in dummyPath) {
      if (dummyIds.contains(nodeId)) {
        keyPoints.add(positions[nodeId]!);
      }
    }

    // End point: enter left edge of target page
    final toPos = positions[toId]!;
    final toPage = pageMap[toId];
    if (toPage == null) return keyPoints;

    final endPoint = Offset(
      toPos.dx - StoryboardConfig.connectionEdgeGap,
      toPos.dy + toPage.canvasSize.height / 2,
    );
    keyPoints.add(endPoint);

    // Convert key points to orthogonal waypoints with bends
    return _createOrthogonalPath(keyPoints);
  }

  /// Convert a list of key points into an orthogonal path with right-angle bends.
  ///
  /// Creates S-curve style paths where vertical segments are positioned
  /// at appropriate X coordinates (midpoint for direct connections, or at
  /// dummy positions for routed connections).
  List<Offset> _createOrthogonalPath(List<Offset> keyPoints) {
    if (keyPoints.length < 2) return keyPoints;

    final waypoints = <Offset>[keyPoints.first];

    for (var i = 1; i < keyPoints.length; i++) {
      final prev = waypoints.last;
      final curr = keyPoints[i];

      final dx = (prev.dx - curr.dx).abs();
      final dy = (prev.dy - curr.dy).abs();

      if (dx < 1) {
        // Vertically aligned - direct vertical connection
        waypoints.add(curr);
      } else if (dy < 1) {
        // Horizontally aligned - direct horizontal connection
        waypoints.add(curr);
      } else {
        // Need S-curve with two bends
        // For connections through dummies, the dummy X is already the bend point
        // For the final segment to target, use an appropriate bend X
        final isLastSegment = i == keyPoints.length - 1;
        final isFirstSegment = i == 1 && keyPoints.length == 2;

        if (isFirstSegment || isLastSegment) {
          // Direct connection (no dummies) or final segment to target
          // Use midpoint X for the vertical segment
          final midX = (prev.dx + curr.dx) / 2;
          waypoints.add(Offset(midX, prev.dy)); // Horizontal to midpoint
          waypoints.add(Offset(midX, curr.dy)); // Vertical to target Y
          waypoints.add(curr); // Horizontal to target
        } else {
          // Intermediate segment through dummy - dummy X is the bend point
          waypoints.add(Offset(curr.dx, prev.dy)); // Horizontal to dummy X
          waypoints.add(curr); // Vertical to dummy Y
        }
      }
    }

    return waypoints;
  }

  /// Find the path from source to target through dummy vertices.
  ///
  /// Uses BFS to find the sequence of dummy vertices connecting
  /// the source to the target in the extended graph.
  List<String> _findPathThroughDummies(
    String fromId,
    String toId,
    Map<String, Set<String>> extendedGraph,
    Set<String> dummyIds,
  ) {
    // BFS to find path
    final queue = Queue<List<String>>();
    final visited = <String>{};

    queue.add([fromId]);
    visited.add(fromId);

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final current = path.last;

      if (current == toId) {
        // Found the target - return intermediate nodes (excluding source and target)
        return path.sublist(1, path.length - 1);
      }

      for (final next in extendedGraph[current] ?? <String>{}) {
        if (!visited.contains(next)) {
          visited.add(next);
          queue.add([...path, next]);
        }
      }
    }

    // No path found - return empty (direct connection)
    return [];
  }

  /// Compute bounding rectangle for all pages.
  Rect _computeBounds(
    Map<String, Offset> positions,
    List<PageModel> pages,
  ) {
    if (positions.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    final pageMap = {for (final p in pages) p.id: p};

    for (final entry in positions.entries) {
      final page = pageMap[entry.key];
      if (page == null) continue;

      final pos = entry.value;
      final size = page.canvasSize;

      if (pos.dx < minX) minX = pos.dx;
      if (pos.dy < minY) minY = pos.dy;
      if (pos.dx + size.width > maxX) maxX = pos.dx + size.width;
      if (pos.dy + size.height > maxY) maxY = pos.dy + size.height;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
