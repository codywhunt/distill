import 'dart:ui';

import '../models/node.dart';
import '../utils/collection_equality.dart';
import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';
import '../models/node_type.dart';

/// A flattened view of the scene with instances expanded.
///
/// The expanded scene provides a read-only, fully-resolved view where:
/// - Component instances are replaced with their expanded node trees
/// - IDs are namespaced to prevent collisions: `instanceId::localNodeId`
/// - Overrides from instances are applied to expanded nodes
/// - patchTarget maps expanded IDs back to document nodes for editing
class ExpandedScene {
  /// The frame ID this scene represents.
  final String frameId;

  /// The root node ID (may be namespaced if inside an instance).
  final String rootId;

  /// All nodes in the expanded scene, keyed by expanded ID.
  final Map<String, ExpandedNode> nodes;

  /// Maps expanded ID → document node ID for patch targeting.
  ///
  /// For nodes inside instances, this is null (v1 behavior - instance children
  /// cannot be edited to prevent data corruption).
  final Map<String, String?> patchTarget;

  const ExpandedScene({
    required this.frameId,
    required this.rootId,
    required this.nodes,
    required this.patchTarget,
  });

  /// Get the patch target for an expanded node.
  ///
  /// Returns the document node ID that should be patched when editing
  /// the given expanded node.
  String? getPatchTarget(String expandedId) => patchTarget[expandedId];

  /// Whether the expanded ID is inside an instance (contains '::').
  bool isInsideInstance(String expandedId) => expandedId.contains('::');

  /// Get the owning instance ID for a namespaced node.
  ///
  /// Returns the first segment of a namespaced ID, or null if not namespaced.
  /// For `inst1::btn`, returns `inst1`.
  /// For `inst1::nested::child`, returns `inst1`.
  String? getOwningInstance(String expandedId) {
    if (!isInsideInstance(expandedId)) return null;
    return expandedId.split('::').first;
  }

  /// Get a node by ID.
  ExpandedNode? getNode(String id) => nodes[id];

  /// Get all root-level instance IDs in this scene.
  Set<String> get instanceIds {
    final result = <String>{};
    for (final id in nodes.keys) {
      final owner = getOwningInstance(id);
      if (owner != null) {
        result.add(owner);
      }
    }
    return result;
  }

  @override
  String toString() => 'ExpandedScene(frame: $frameId, root: $rootId, '
      'nodes: ${nodes.length}, instances: ${instanceIds.length})';
}

/// A node in the expanded scene.
///
/// Represents a fully-resolved node where:
/// - Instance nodes have been expanded
/// - Overrides have been applied
/// - IDs may be namespaced (e.g., `inst1::btn`)
class ExpandedNode {
  /// The expanded ID (may be namespaced: 'inst1::btn').
  final String id;

  /// The document node ID to patch when editing this node.
  ///
  /// For regular nodes, this equals [id].
  /// For nodes inside instances, this is null (v1 - instance children cannot
  /// be edited to prevent data corruption).
  final String? patchTargetId;

  /// The node type.
  final NodeType type;

  /// Child node IDs (expanded/namespaced).
  final List<String> childIds;

  /// Layout properties (position, size, auto-layout).
  final NodeLayout layout;

  /// Style properties (fill, stroke, shadow, etc.).
  final NodeStyle style;

  /// Type-specific properties.
  final NodeProps props;

  /// Computed bounds after layout pass (null until layout runs).
  Rect? bounds;

  ExpandedNode({
    required this.id,
    required this.patchTargetId,
    required this.type,
    required this.childIds,
    required this.layout,
    required this.style,
    required this.props,
    this.bounds,
  });

  /// Create from a document Node.
  factory ExpandedNode.fromNode(
    Node node, {
    String? expandedId,
    String? patchTargetId,
    List<String>? childIds,
  }) {
    return ExpandedNode(
      id: expandedId ?? node.id,
      patchTargetId: patchTargetId ?? node.id,
      type: node.type,
      childIds: childIds ?? node.childIds,
      layout: node.layout,
      style: node.style,
      props: node.props,
    );
  }

  /// Create a copy with overrides applied.
  ExpandedNode copyWith({
    String? id,
    String? patchTargetId,
    NodeType? type,
    List<String>? childIds,
    NodeLayout? layout,
    NodeStyle? style,
    NodeProps? props,
    Rect? bounds,
  }) {
    return ExpandedNode(
      id: id ?? this.id,
      patchTargetId: patchTargetId ?? this.patchTargetId,
      type: type ?? this.type,
      childIds: childIds ?? this.childIds,
      layout: layout ?? this.layout,
      style: style ?? this.style,
      props: props ?? this.props,
      bounds: bounds ?? this.bounds,
    );
  }

  /// Whether this node is inside an instance (ID contains '::').
  bool get isInsideInstance => id.contains('::');

  /// Get the owning instance ID, or null if not inside an instance.
  String? get owningInstance {
    if (!isInsideInstance) return null;
    return id.split('::').first;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpandedNode &&
          id == other.id &&
          patchTargetId == other.patchTargetId &&
          type == other.type &&
          listEquals(childIds, other.childIds) &&
          layout == other.layout &&
          style == other.style &&
          props == other.props;

  @override
  int get hashCode => Object.hash(
        id,
        patchTargetId,
        type,
        Object.hashAll(childIds),
        layout,
        style,
        props,
      );

  @override
  String toString() => 'ExpandedNode($id, type: $type, '
      'children: ${childIds.length})';
}
