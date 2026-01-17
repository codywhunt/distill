import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'dart:ui';

import 'algorithms/layout_algorithm.dart';
import 'algorithms/hierarchical_layout.dart';
import 'algorithms/force_directed.dart';
import 'algorithms/tree_layout.dart';
import 'routing/edge_router.dart';
import 'routing/straight_router.dart';
import 'routing/curved_router.dart';
import 'routing/orthogonal_router.dart';
import 'graph_presets.dart';

/// State management for the Layout Lab example.
class LayoutState extends ChangeNotifier {
  LayoutState() {
    _preset = GraphPreset.simpleDag();
    _nodes = List.from(_preset.nodes);
    _edges = List.from(_preset.edges);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Graph Data
  // ─────────────────────────────────────────────────────────────────────────

  late GraphPreset _preset;
  late List<LayoutNode> _nodes;
  late List<LayoutEdge> _edges;

  GraphPreset get preset => _preset;
  List<LayoutNode> get nodes => _nodes;
  List<LayoutEdge> get edges => _edges;

  /// Current node positions (after layout).
  final Map<String, Offset> _positions = {};
  Map<String, Offset> get positions => Map.unmodifiable(_positions);

  /// Current layout result (for metrics).
  LayoutResult? _layoutResult;
  LayoutResult? get layoutResult => _layoutResult;

  // ─────────────────────────────────────────────────────────────────────────
  // Algorithm Selection
  // ─────────────────────────────────────────────────────────────────────────

  static final List<LayoutAlgorithm> availableAlgorithms = [
    const HierarchicalLayout(),
    const ForceDirectedLayout(),
    const TreeLayout(),
  ];

  int _selectedAlgorithmIndex = 0;
  LayoutAlgorithm get selectedAlgorithm =>
      availableAlgorithms[_selectedAlgorithmIndex];
  int get selectedAlgorithmIndex => _selectedAlgorithmIndex;

  void selectAlgorithm(int index) {
    if (index != _selectedAlgorithmIndex &&
        index < availableAlgorithms.length) {
      _selectedAlgorithmIndex = index;
      runLayout();
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Direction
  // ─────────────────────────────────────────────────────────────────────────

  LayoutDirection _direction = LayoutDirection.topToBottom;
  LayoutDirection get direction => _direction;

  void setDirection(LayoutDirection dir) {
    if (dir != _direction) {
      _direction = dir;
      runLayout();
      notifyListeners();
    }
  }

  bool get supportsDirection =>
      selectedAlgorithm.supportedDirections.isNotEmpty;

  // ─────────────────────────────────────────────────────────────────────────
  // Edge Router Selection
  // ─────────────────────────────────────────────────────────────────────────

  static final List<EdgeRouter> availableRouters = [
    const StraightRouter(),
    const CurvedRouter(),
    const OrthogonalRouter(),
    const OrthogonalRouter(usePathfinding: true),
  ];

  int _selectedRouterIndex = 1; // Default to curved
  EdgeRouter get selectedRouter => availableRouters[_selectedRouterIndex];
  int get selectedRouterIndex => _selectedRouterIndex;

  void selectRouter(int index) {
    if (index != _selectedRouterIndex && index < availableRouters.length) {
      _selectedRouterIndex = index;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Layout Options
  // ─────────────────────────────────────────────────────────────────────────

  double _spacing = 80.0;
  double get spacing => _spacing;

  void setSpacing(double value) {
    if (value != _spacing) {
      _spacing = value;
      runLayout();
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Preset Selection
  // ─────────────────────────────────────────────────────────────────────────

  void loadPreset(GraphPreset preset) {
    _preset = preset;
    _nodes = List.from(preset.nodes);
    _edges = List.from(preset.edges);
    _positions.clear();
    runLayout();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Layout Execution
  // ─────────────────────────────────────────────────────────────────────────

  Size _bounds = const Size(1000, 800);

  void setBounds(Size bounds) {
    if (bounds != _bounds) {
      _bounds = bounds;
      if (_positions.isEmpty) {
        runLayout();
      }
    }
  }

  void runLayout() {
    if (_nodes.isEmpty) return;

    // Get algorithm-specific options
    final options = <String, dynamic>{
      'layerSpacing': _spacing,
      'nodeSpacing': _spacing * 0.5,
    };

    // Run the layout algorithm
    _layoutResult = selectedAlgorithm.layout(
      nodes: _nodes,
      edges: _edges,
      bounds: _bounds,
      direction: _direction,
      options: options,
    );

    // Apply positions immediately
    _positions.clear();
    _positions.addAll(_layoutResult!.positions);

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Node Interaction
  // ─────────────────────────────────────────────────────────────────────────

  String? _selectedNodeId;
  String? get selectedNodeId => _selectedNodeId;

  void selectNode(String? id) {
    if (id != _selectedNodeId) {
      _selectedNodeId = id;
      notifyListeners();
    }
  }

  bool _isDragging = false;
  bool get isDragging => _isDragging;

  void startDrag(String nodeId) {
    _selectedNodeId = nodeId;
    _isDragging = true;
    notifyListeners();
  }

  void updateDrag(Offset delta) {
    if (!_isDragging || _selectedNodeId == null) return;

    final currentPos = _positions[_selectedNodeId!];
    if (currentPos != null) {
      _positions[_selectedNodeId!] = currentPos + delta;
      notifyListeners();
    }
  }

  void endDrag() {
    if (!_isDragging) return;

    // Pin the node at its new position
    if (_selectedNodeId != null) {
      final pos = _positions[_selectedNodeId!];
      if (pos != null) {
        final nodeIndex = _nodes.indexWhere((n) => n.id == _selectedNodeId);
        if (nodeIndex >= 0) {
          final oldNode = _nodes[nodeIndex];
          _nodes[nodeIndex] = LayoutNode(
            id: oldNode.id,
            size: oldNode.size,
            pinned: pos,
          );
        }
      }
    }

    _isDragging = false;
    notifyListeners();
  }

  /// Clear all pinned positions.
  void clearPinned() {
    _nodes =
        _nodes
            .map((n) => LayoutNode(id: n.id, size: n.size, pinned: null))
            .toList();
    runLayout();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hit Testing
  // ─────────────────────────────────────────────────────────────────────────

  String? hitTest(Offset worldPos) {
    for (final node in _nodes) {
      final pos = _positions[node.id];
      if (pos == null) continue;

      final bounds = Rect.fromCenter(
        center: pos,
        width: node.size.width,
        height: node.size.height,
      );

      if (bounds.contains(worldPos)) {
        return node.id;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Computed Properties
  // ─────────────────────────────────────────────────────────────────────────

  Rect? get allNodesBounds {
    if (_positions.isEmpty) return null;

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final node in _nodes) {
      final pos = _positions[node.id];
      if (pos == null) continue;

      minX = math.min(minX, pos.dx - node.size.width / 2);
      maxX = math.max(maxX, pos.dx + node.size.width / 2);
      minY = math.min(minY, pos.dy - node.size.height / 2);
      maxY = math.max(maxY, pos.dy + node.size.height / 2);
    }

    if (minX == double.infinity) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Get obstacles for edge routing (all node bounds except for a specific edge).
  List<Rect> getObstacles({String? excludeFrom, String? excludeTo}) {
    final obstacles = <Rect>[];

    for (final node in _nodes) {
      if (node.id == excludeFrom || node.id == excludeTo) continue;

      final pos = _positions[node.id];
      if (pos == null) continue;

      obstacles.add(
        Rect.fromCenter(
          center: pos,
          width: node.size.width,
          height: node.size.height,
        ),
      );
    }

    return obstacles;
  }
}
