import 'dart:math' as math;
import 'dart:ui';

import 'algorithms/layout_algorithm.dart';

/// Predefined graph configurations for testing layout algorithms.
class GraphPreset {
  const GraphPreset({
    required this.name,
    required this.description,
    required this.nodes,
    required this.edges,
  });

  final String name;
  final String description;
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;

  /// Simple DAG with clear hierarchy (6 nodes).
  static GraphPreset simpleDag() {
    const nodeSize = Size(80, 50);
    return GraphPreset(
      name: 'Simple DAG',
      description: '6 nodes, clear hierarchy',
      nodes: [
        LayoutNode(id: 'a', size: nodeSize),
        LayoutNode(id: 'b', size: nodeSize),
        LayoutNode(id: 'c', size: nodeSize),
        LayoutNode(id: 'd', size: nodeSize),
        LayoutNode(id: 'e', size: nodeSize),
        LayoutNode(id: 'f', size: nodeSize),
      ],
      edges: [
        LayoutEdge(id: 'e1', fromId: 'a', toId: 'b'),
        LayoutEdge(id: 'e2', fromId: 'a', toId: 'c'),
        LayoutEdge(id: 'e3', fromId: 'b', toId: 'd'),
        LayoutEdge(id: 'e4', fromId: 'c', toId: 'd'),
        LayoutEdge(id: 'e5', fromId: 'c', toId: 'e'),
        LayoutEdge(id: 'e6', fromId: 'd', toId: 'f'),
        LayoutEdge(id: 'e7', fromId: 'e', toId: 'f'),
      ],
    );
  }

  /// Binary tree (15 nodes, balanced).
  static GraphPreset binaryTree() {
    const nodeSize = Size(60, 40);
    final nodes = <LayoutNode>[];
    final edges = <LayoutEdge>[];

    // Create 4 levels of binary tree
    for (var i = 0; i < 15; i++) {
      nodes.add(LayoutNode(id: 'n$i', size: nodeSize));

      // Connect to children
      final leftChild = 2 * i + 1;
      final rightChild = 2 * i + 2;

      if (leftChild < 15) {
        edges.add(LayoutEdge(id: 'e${i}l', fromId: 'n$i', toId: 'n$leftChild'));
      }
      if (rightChild < 15) {
        edges.add(
          LayoutEdge(id: 'e${i}r', fromId: 'n$i', toId: 'n$rightChild'),
        );
      }
    }

    return GraphPreset(
      name: 'Binary Tree',
      description: '15 nodes, balanced',
      nodes: nodes,
      edges: edges,
    );
  }

  /// Wide tree (20 nodes, shallow and wide).
  static GraphPreset wideTree() {
    const nodeSize = Size(60, 40);
    final nodes = <LayoutNode>[LayoutNode(id: 'root', size: nodeSize)];
    final edges = <LayoutEdge>[];

    // First level: 5 children
    for (var i = 0; i < 5; i++) {
      nodes.add(LayoutNode(id: 'l1_$i', size: nodeSize));
      edges.add(LayoutEdge(id: 'e_root_$i', fromId: 'root', toId: 'l1_$i'));

      // Second level: 2-3 children each
      final childCount = i < 3 ? 3 : 2;
      for (var j = 0; j < childCount; j++) {
        nodes.add(LayoutNode(id: 'l2_${i}_$j', size: nodeSize));
        edges.add(
          LayoutEdge(id: 'e_l1${i}_$j', fromId: 'l1_$i', toId: 'l2_${i}_$j'),
        );
      }
    }

    return GraphPreset(
      name: 'Wide Tree',
      description: '${nodes.length} nodes, shallow and wide',
      nodes: nodes,
      edges: edges,
    );
  }

  /// Deep chain (10 nodes, linear).
  static GraphPreset deepChain() {
    const nodeSize = Size(70, 45);
    final nodes = <LayoutNode>[];
    final edges = <LayoutEdge>[];

    for (var i = 0; i < 10; i++) {
      nodes.add(LayoutNode(id: 'n$i', size: nodeSize));
      if (i > 0) {
        edges.add(LayoutEdge(id: 'e$i', fromId: 'n${i - 1}', toId: 'n$i'));
      }
    }

    return GraphPreset(
      name: 'Deep Chain',
      description: '10 nodes, linear',
      nodes: nodes,
      edges: edges,
    );
  }

  /// Diamond shape (5 nodes).
  static GraphPreset diamond() {
    const nodeSize = Size(80, 50);
    return GraphPreset(
      name: 'Diamond',
      description: '5 nodes, tests crossing minimization',
      nodes: [
        LayoutNode(id: 'top', size: nodeSize),
        LayoutNode(id: 'left', size: nodeSize),
        LayoutNode(id: 'right', size: nodeSize),
        LayoutNode(id: 'center', size: nodeSize),
        LayoutNode(id: 'bottom', size: nodeSize),
      ],
      edges: [
        LayoutEdge(id: 'e1', fromId: 'top', toId: 'left'),
        LayoutEdge(id: 'e2', fromId: 'top', toId: 'right'),
        LayoutEdge(id: 'e3', fromId: 'left', toId: 'center'),
        LayoutEdge(id: 'e4', fromId: 'right', toId: 'center'),
        LayoutEdge(id: 'e5', fromId: 'center', toId: 'bottom'),
        // Cross edges to test crossing minimization
        LayoutEdge(id: 'e6', fromId: 'left', toId: 'bottom'),
        LayoutEdge(id: 'e7', fromId: 'right', toId: 'bottom'),
      ],
    );
  }

  /// Random sparse graph (15 nodes, few edges).
  static GraphPreset randomSparse({int seed = 42}) {
    const nodeSize = Size(70, 45);
    final random = math.Random(seed);
    final nodes = <LayoutNode>[];
    final edges = <LayoutEdge>[];

    for (var i = 0; i < 15; i++) {
      nodes.add(LayoutNode(id: 'n$i', size: nodeSize));
    }

    // Add ~12 edges (sparse)
    var edgeCount = 0;
    for (var i = 0; i < 14 && edgeCount < 12; i++) {
      final target = i + 1 + random.nextInt(14 - i);
      if (target < 15) {
        edges.add(
          LayoutEdge(id: 'e$edgeCount', fromId: 'n$i', toId: 'n$target'),
        );
        edgeCount++;
      }
    }

    return GraphPreset(
      name: 'Random Sparse',
      description: '15 nodes, ${edges.length} edges',
      nodes: nodes,
      edges: edges,
    );
  }

  /// Random dense graph (15 nodes, many edges).
  static GraphPreset randomDense({int seed = 42}) {
    const nodeSize = Size(70, 45);
    final random = math.Random(seed);
    final nodes = <LayoutNode>[];
    final edges = <LayoutEdge>[];
    final edgeSet = <String>{};

    for (var i = 0; i < 15; i++) {
      nodes.add(LayoutNode(id: 'n$i', size: nodeSize));
    }

    // Add ~40 edges (dense)
    var edgeCount = 0;
    while (edgeCount < 40) {
      final from = random.nextInt(15);
      final to = random.nextInt(15);
      if (from != to) {
        final key = from < to ? '$from-$to' : '$to-$from';
        if (!edgeSet.contains(key)) {
          edgeSet.add(key);
          edges.add(
            LayoutEdge(
              id: 'e$edgeCount',
              fromId: 'n${math.min(from, to)}',
              toId: 'n${math.max(from, to)}',
            ),
          );
          edgeCount++;
        }
      }
    }

    return GraphPreset(
      name: 'Random Dense',
      description: '15 nodes, ${edges.length} edges',
      nodes: nodes,
      edges: edges,
    );
  }

  /// Typical workflow pattern with multiple forks and joins.
  ///
  /// Structure:
  /// ```
  /// trigger -> validate ─┬─> fast_track ──────────────────────────────┐
  ///                      │                                            │
  ///                      ├─> route ─┬─> api_call ──┬─> transform ─────┼─> check ─┬─> success -> notify ─┬─> end
  ///                      │          │              │                  │          │                      │
  ///                      │          └─> db_query ──┤                  │          └─> failure -> alert ──┤
  ///                      │                         │                  │                                 │
  ///                      └─> error_handler ────────┴──────────────────┘                                 │
  ///                                                                                                     │
  ///                                                                             log <───────────────────┘
  /// ```
  static GraphPreset workflow() {
    const nodeSize = Size(80, 45);
    return GraphPreset(
      name: 'Workflow',
      description: '16 nodes, multi-fork action flow',
      nodes: [
        // Entry
        LayoutNode(id: 'trigger', size: nodeSize),
        LayoutNode(id: 'validate', size: nodeSize),
        // First fork (3-way)
        LayoutNode(id: 'fast_track', size: nodeSize),
        LayoutNode(id: 'route', size: nodeSize),
        LayoutNode(id: 'error_handler', size: nodeSize),
        // Second fork (from route)
        LayoutNode(id: 'api_call', size: nodeSize),
        LayoutNode(id: 'db_query', size: nodeSize),
        // Merge and process
        LayoutNode(id: 'transform', size: nodeSize),
        LayoutNode(id: 'check', size: nodeSize),
        // Final fork (success/failure)
        LayoutNode(id: 'success', size: nodeSize),
        LayoutNode(id: 'failure', size: nodeSize),
        // Actions
        LayoutNode(id: 'notify', size: nodeSize),
        LayoutNode(id: 'alert', size: nodeSize),
        // Final merge
        LayoutNode(id: 'log', size: nodeSize),
        LayoutNode(id: 'end', size: nodeSize),
        // Extra conditional branch
        LayoutNode(id: 'archive', size: nodeSize),
      ],
      edges: [
        // Entry flow
        LayoutEdge(id: 'e1', fromId: 'trigger', toId: 'validate'),
        // First fork (validate -> 3 paths)
        LayoutEdge(id: 'e2', fromId: 'validate', toId: 'fast_track'),
        LayoutEdge(id: 'e3', fromId: 'validate', toId: 'route'),
        LayoutEdge(id: 'e4', fromId: 'validate', toId: 'error_handler'),
        // Second fork (route -> 2 paths)
        LayoutEdge(id: 'e5', fromId: 'route', toId: 'api_call'),
        LayoutEdge(id: 'e6', fromId: 'route', toId: 'db_query'),
        // Merge to transform (4 inputs)
        LayoutEdge(id: 'e7', fromId: 'fast_track', toId: 'check'),
        LayoutEdge(id: 'e8', fromId: 'api_call', toId: 'transform'),
        LayoutEdge(id: 'e9', fromId: 'db_query', toId: 'transform'),
        LayoutEdge(id: 'e10', fromId: 'error_handler', toId: 'transform'),
        LayoutEdge(id: 'e11', fromId: 'transform', toId: 'check'),
        // Final fork (check -> success/failure)
        LayoutEdge(id: 'e12', fromId: 'check', toId: 'success'),
        LayoutEdge(id: 'e13', fromId: 'check', toId: 'failure'),
        // Success path
        LayoutEdge(id: 'e14', fromId: 'success', toId: 'notify'),
        LayoutEdge(id: 'e15', fromId: 'notify', toId: 'log'),
        // Failure path
        LayoutEdge(id: 'e16', fromId: 'failure', toId: 'alert'),
        LayoutEdge(id: 'e17', fromId: 'alert', toId: 'log'),
        // Final merge to end
        LayoutEdge(id: 'e18', fromId: 'log', toId: 'end'),
        // Extra conditional: notify can also archive
        LayoutEdge(id: 'e19', fromId: 'notify', toId: 'archive'),
        LayoutEdge(id: 'e20', fromId: 'archive', toId: 'end'),
      ],
    );
  }

  /// All available presets.
  static List<GraphPreset> get all => [
    simpleDag(),
    binaryTree(),
    wideTree(),
    deepChain(),
    diamond(),
    randomSparse(),
    randomDense(),
    workflow(),
  ];
}
