import 'dart:math' as math;
import 'dart:ui';

import 'layout_algorithm.dart';

/// Reingold-Tilford tree layout algorithm.
///
/// Produces compact, aesthetically pleasing tree layouts by:
/// 1. Computing preliminary x-coordinates bottom-up
/// 2. Adjusting for subtree separation
/// 3. Centering parent nodes over children
///
/// Handles DAGs by converting to a spanning tree first.
///
/// Complexity: O(n)
class TreeLayout implements LayoutAlgorithm {
  const TreeLayout({
    this.levelSpacing = 80.0,
    this.siblingSpacing = 40.0,
    this.subtreeSpacing = 20.0,
  });

  /// Spacing between levels (parent to child).
  final double levelSpacing;

  /// Spacing between sibling nodes.
  final double siblingSpacing;

  /// Minimum spacing between subtrees.
  final double subtreeSpacing;

  @override
  String get name => 'Tree';

  @override
  String get description => 'Reingold-Tilford compact tree layout';

  @override
  Set<LayoutDirection> get supportedDirections => {
    LayoutDirection.topToBottom,
    LayoutDirection.leftToRight,
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
    final effectiveLevelSpacing =
        (options?['layerSpacing'] as double?) ?? levelSpacing;
    final effectiveSiblingSpacing =
        (options?['nodeSpacing'] as double?) ?? siblingSpacing;

    // Build tree structure
    final nodeMap = {for (final n in nodes) n.id: n};
    final children = <String, List<String>>{};
    final parents = <String, String>{};

    for (final node in nodes) {
      children[node.id] = [];
    }

    for (final edge in edges) {
      if (nodeMap.containsKey(edge.fromId) && nodeMap.containsKey(edge.toId)) {
        children[edge.fromId]!.add(edge.toId);
        parents[edge.toId] = edge.fromId;
      }
    }

    // Find root nodes (no parent)
    final roots =
        nodes
            .where((n) => !parents.containsKey(n.id))
            .map((n) => n.id)
            .toList();

    if (roots.isEmpty) {
      // Cyclic graph - pick first node as root
      roots.add(nodes.first.id);
    }

    // Build tree data for each root (track visited to handle DAGs)
    final treeNodes = <String, _TreeNode>{};
    final visited = <String>{};

    void buildTree(String nodeId, int depth) {
      if (visited.contains(nodeId)) return; // Already in tree via another path
      visited.add(nodeId);

      final node = nodeMap[nodeId]!;
      final treeNode = _TreeNode(id: nodeId, size: node.size, depth: depth);
      treeNodes[nodeId] = treeNode;

      for (final childId in children[nodeId]!) {
        if (!visited.contains(childId)) {
          // Only add if not already in tree
          buildTree(childId, depth + 1);
          final childTree = treeNodes[childId];
          if (childTree != null && childTree.parent == null) {
            treeNode.children.add(childTree);
            childTree.parent = treeNode;
          }
        }
      }
    }

    for (final root in roots) {
      buildTree(root, 0);
    }

    // Compute layout for each tree
    final isHorizontal = direction == LayoutDirection.leftToRight;

    for (final root in roots) {
      final rootNode = treeNodes[root];
      if (rootNode != null) {
        _firstWalk(rootNode, isHorizontal, effectiveSiblingSpacing);
        _secondWalk(rootNode, -rootNode.prelim, isHorizontal);
      }
    }

    // Convert to positions and center in bounds
    final positions = <String, Offset>{};
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final treeNode in treeNodes.values) {
      final x = treeNode.x;
      final y = treeNode.depth * effectiveLevelSpacing + effectiveLevelSpacing;

      minX = math.min(minX, x);
      maxX = math.max(maxX, x + treeNode.size.width);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y + treeNode.size.height);
    }

    // Center in bounds
    final contentWidth = maxX - minX;
    final contentHeight = maxY - minY;
    final offsetX = (bounds.width - contentWidth) / 2 - minX;
    final offsetY = (bounds.height - contentHeight) / 2 - minY;

    for (final treeNode in treeNodes.values) {
      final x = treeNode.x + offsetX;
      final y =
          treeNode.depth * effectiveLevelSpacing +
          effectiveLevelSpacing +
          offsetY;

      if (isHorizontal) {
        positions[treeNode.id] = Offset(y, x);
      } else {
        positions[treeNode.id] = Offset(x, y);
      }
    }

    // Respect pinned positions
    for (final node in nodes) {
      if (node.pinned != null) {
        positions[node.id] = node.pinned!;
      }
    }

    // Calculate port assignments
    final entryPorts = <String, PortSide>{};
    final exitPorts = <String, PortSide>{};

    for (final node in nodes) {
      entryPorts[node.id] = isHorizontal ? PortSide.left : PortSide.top;
      exitPorts[node.id] = isHorizontal ? PortSide.right : PortSide.bottom;
    }

    // Calculate metrics
    final totalLength = _calculateTotalEdgeLength(positions, edges);

    stopwatch.stop();

    return LayoutResult(
      positions: positions,
      entryPorts: entryPorts,
      exitPorts: exitPorts,
      totalEdgeLength: totalLength,
      computeTime: stopwatch.elapsed,
    );
  }

  /// First walk: compute preliminary x-coordinates bottom-up.
  void _firstWalk(
    _TreeNode node,
    bool isHorizontal,
    double effectiveSiblingSpacing,
  ) {
    if (node.children.isEmpty) {
      // Leaf node
      if (node.leftSibling != null) {
        final siblingSize =
            isHorizontal
                ? node.leftSibling!.size.height
                : node.leftSibling!.size.width;
        node.prelim =
            node.leftSibling!.prelim + siblingSize + effectiveSiblingSpacing;
      } else {
        node.prelim = 0;
      }
    } else {
      // Internal node
      var defaultAncestor = node.children.first;

      for (final child in node.children) {
        _firstWalk(child, isHorizontal, effectiveSiblingSpacing);
        defaultAncestor = _apportion(
          child,
          defaultAncestor,
          isHorizontal,
          effectiveSiblingSpacing,
        );
      }

      _executeShifts(node);

      final midpoint =
          (node.children.first.prelim + node.children.last.prelim) / 2;

      if (node.leftSibling != null) {
        final siblingSize =
            isHorizontal
                ? node.leftSibling!.size.height
                : node.leftSibling!.size.width;
        node.prelim =
            node.leftSibling!.prelim + siblingSize + effectiveSiblingSpacing;
        node.mod = node.prelim - midpoint;
      } else {
        node.prelim = midpoint;
      }
    }
  }

  /// Second walk: compute final x-coordinates top-down.
  void _secondWalk(_TreeNode node, double m, bool isHorizontal) {
    node.x = node.prelim + m;

    for (final child in node.children) {
      _secondWalk(child, m + node.mod, isHorizontal);
    }
  }

  /// Apportion: space out subtrees.
  _TreeNode _apportion(
    _TreeNode node,
    _TreeNode defaultAncestor,
    bool isHorizontal,
    double effectiveSubtreeSpacing,
  ) {
    if (node.leftSibling == null) return defaultAncestor;

    var vInnerRight = node;
    var vOuterRight = node;
    var vInnerLeft = node.leftSibling!;
    var vOuterLeft = vInnerRight.parent!.children.first;

    var sInnerRight = vInnerRight.mod;
    var sOuterRight = vOuterRight.mod;
    var sInnerLeft = vInnerLeft.mod;
    var sOuterLeft = vOuterLeft.mod;

    while (_nextRight(vInnerLeft) != null && _nextLeft(vInnerRight) != null) {
      vInnerLeft = _nextRight(vInnerLeft)!;
      vInnerRight = _nextLeft(vInnerRight)!;
      vOuterLeft = _nextLeft(vOuterLeft)!;
      vOuterRight = _nextRight(vOuterRight)!;

      vOuterRight.ancestor = node;

      final nodeSize = isHorizontal ? node.size.height : node.size.width;
      final shift =
          (vInnerLeft.prelim + sInnerLeft) -
          (vInnerRight.prelim + sInnerRight) +
          nodeSize +
          effectiveSubtreeSpacing;

      if (shift > 0) {
        final ancestor = _ancestor(vInnerLeft, node, defaultAncestor);
        _moveSubtree(ancestor, node, shift);
        sInnerRight += shift;
        sOuterRight += shift;
      }

      sInnerLeft += vInnerLeft.mod;
      sInnerRight += vInnerRight.mod;
      sOuterLeft += vOuterLeft.mod;
      sOuterRight += vOuterRight.mod;
    }

    if (_nextRight(vInnerLeft) != null && _nextRight(vOuterRight) == null) {
      vOuterRight.thread = _nextRight(vInnerLeft);
      vOuterRight.mod += sInnerLeft - sOuterRight;
    }

    if (_nextLeft(vInnerRight) != null && _nextLeft(vOuterLeft) == null) {
      vOuterLeft.thread = _nextLeft(vInnerRight);
      vOuterLeft.mod += sInnerRight - sOuterLeft;
      return node;
    }

    return defaultAncestor;
  }

  _TreeNode? _nextLeft(_TreeNode node) {
    return node.children.isNotEmpty ? node.children.first : node.thread;
  }

  _TreeNode? _nextRight(_TreeNode node) {
    return node.children.isNotEmpty ? node.children.last : node.thread;
  }

  void _moveSubtree(_TreeNode wl, _TreeNode wr, double shift) {
    final index = wr.siblingIndex - wl.siblingIndex;
    if (index == 0) return;

    wr.change -= shift / index;
    wr.shift += shift;
    wl.change += shift / index;
    wr.prelim += shift;
    wr.mod += shift;
  }

  void _executeShifts(_TreeNode node) {
    var shift = 0.0;
    var change = 0.0;

    for (var i = node.children.length - 1; i >= 0; i--) {
      final child = node.children[i];
      child.prelim += shift;
      child.mod += shift;
      change += child.change;
      shift += child.shift + change;
    }
  }

  _TreeNode _ancestor(_TreeNode vil, _TreeNode v, _TreeNode defaultAncestor) {
    if (vil.ancestor.parent == v.parent) {
      return vil.ancestor;
    }
    return defaultAncestor;
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

/// Internal tree node for Reingold-Tilford algorithm.
class _TreeNode {
  _TreeNode({required this.id, required this.size, required this.depth});

  final String id;
  final Size size;
  final int depth;

  _TreeNode? parent;
  final List<_TreeNode> children = [];

  // Algorithm state
  double prelim = 0;
  double mod = 0;
  double x = 0;
  double shift = 0;
  double change = 0;
  _TreeNode? thread;
  late _TreeNode ancestor = this;

  _TreeNode? get leftSibling {
    if (parent == null) return null;
    final index = parent!.children.indexOf(this);
    if (index <= 0) return null;
    return parent!.children[index - 1];
  }

  int get siblingIndex {
    if (parent == null) return 0;
    return parent!.children.indexOf(this);
  }
}
