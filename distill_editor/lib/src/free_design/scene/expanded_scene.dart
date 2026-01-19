import 'dart:ui';

import '../models/node.dart';
import '../utils/collection_equality.dart';
import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';
import '../models/node_type.dart';

/// Categorizes where an expanded node came from.
///
/// Makes UI logic trivial (tree rendering, prop panel, context menus).
enum OriginKind {
  /// Regular node in a frame (not from component).
  frameNode,

  /// The instance node itself (the root that references a component).
  instanceRoot,

  /// A node inside a component (not directly editable).
  componentChild,

  /// Content injected into a slot (editable, owned by instance).
  slotContent,

  /// Error placeholder (cycle detected, missing component, etc.).
  errorPlaceholder,
}

/// Tracks slot injection origin for expanded nodes.
class SlotOrigin {
  final String slotName;
  final String instanceId;

  const SlotOrigin({required this.slotName, required this.instanceId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotOrigin &&
          slotName == other.slotName &&
          instanceId == other.instanceId;

  @override
  int get hashCode => Object.hash(slotName, instanceId);
}

/// Metadata about where an expanded node came from.
///
/// This enables UI to make decisions about editability, display badges,
/// context menu options, etc.
class ExpandedNodeOrigin {
  /// The kind of origin (frame node, component child, etc.).
  final OriginKind kind;

  /// Which component this node came from (if any).
  final String? componentId;

  /// The stable template UID within the component (for param bindings).
  final String? componentTemplateUid;

  /// The path of instance IDs from root to this node.
  ///
  /// For example, if instance A contains instance B which contains this node,
  /// instancePath would be ['instA', 'instB'].
  final List<String> instancePath;

  /// Whether any overrides were applied to this node.
  final bool isOverridden;

  /// If this node came from slot injection, tracks the slot info.
  final SlotOrigin? slotOrigin;

  const ExpandedNodeOrigin({
    required this.kind,
    this.componentId,
    this.componentTemplateUid,
    this.instancePath = const [],
    this.isOverridden = false,
    this.slotOrigin,
  });
}

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

  /// Index of slot content roots by instance expanded ID.
  ///
  /// Enables O(1) lookup for layer tree display. Built during expansion.
  /// Key is the instance's expanded ID, value is list of slot content root
  /// expanded IDs that should appear as virtual children of that instance.
  final Map<String, List<String>> slotChildrenByInstance;

  const ExpandedScene({
    required this.frameId,
    required this.rootId,
    required this.nodes,
    required this.patchTarget,
    this.slotChildrenByInstance = const {},
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
  /// For `inst1::comp_button::btn_root`, returns `inst1`.
  /// For `inst1::inst2::comp_button::btn_root`, returns `inst1`.
  ///
  /// This works because instance IDs are simple strings (no `::`) while
  /// component node IDs contain `::` (e.g., `comp_button::btn_root`).
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

  /// Origin metadata for UI decisions (editability, badges, context menus).
  ///
  /// Note: Excluded from equality/hashCode as it's metadata, not identity.
  final ExpandedNodeOrigin? origin;

  ExpandedNode({
    required this.id,
    required this.patchTargetId,
    required this.type,
    required this.childIds,
    required this.layout,
    required this.style,
    required this.props,
    this.bounds,
    this.origin,
  });

  /// Create from a document Node.
  ///
  /// If [patchTargetId] is not provided, defaults to `node.id`.
  /// To explicitly set patchTargetId to null (for non-editable nodes),
  /// pass [editableTarget] = false.
  factory ExpandedNode.fromNode(
    Node node, {
    String? expandedId,
    String? patchTargetId,
    bool editableTarget = true,
    List<String>? childIds,
    ExpandedNodeOrigin? origin,
  }) {
    return ExpandedNode(
      id: expandedId ?? node.id,
      patchTargetId: editableTarget ? (patchTargetId ?? node.id) : null,
      type: node.type,
      childIds: childIds ?? node.childIds,
      layout: node.layout,
      style: node.style,
      props: node.props,
      origin: origin,
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
    ExpandedNodeOrigin? origin,
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
      origin: origin ?? this.origin,
    );
  }

  /// Whether this node is inside an instance (ID contains '::').
  bool get isInsideInstance => id.contains('::');

  /// Get the owning instance ID, or null if not inside an instance.
  ///
  /// For `inst1::comp_button::btn_root`, returns `inst1`.
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
