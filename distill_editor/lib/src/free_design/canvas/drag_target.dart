/// Drag targets for the free design canvas.
///
/// A [DragTarget] represents something that can be selected and dragged
/// on the canvas - either a frame or a node within a frame.
library;

/// Sealed class representing selectable/draggable targets on the canvas.
sealed class DragTarget {
  const DragTarget();
}

/// A frame on the canvas, positioned in world coordinates.
///
/// Frames are the top-level containers that hold node trees.
/// Their position is stored in [Frame.canvas.position] using world coordinates.
class FrameTarget extends DragTarget {
  /// The ID of the frame.
  final String frameId;

  const FrameTarget(this.frameId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameTarget &&
          runtimeType == other.runtimeType &&
          frameId == other.frameId;

  @override
  int get hashCode => frameId.hashCode;

  @override
  String toString() => 'FrameTarget($frameId)';
}

/// A node within a frame.
///
/// Nodes are positioned relative to their parent using [Node.layout.position].
/// The [expandedId] may include instance namespacing (e.g., 'inst1::btn_label').
class NodeTarget extends DragTarget {
  /// The ID of the containing frame.
  final String frameId;

  /// The ID in the expanded scene, which may include instance path.
  ///
  /// For regular nodes, this equals the document node ID.
  /// For nodes inside instances, this is namespaced: 'instanceId::localNodeId'.
  final String expandedId;

  /// The document node ID to patch, or null if inside an instance.
  ///
  /// When a node is inside a component instance, patches go to the instance
  /// node itself (as overrides), not to the original component definition.
  /// In v1, we don't support editing inside instances, so this is null.
  final String? patchTarget;

  const NodeTarget({
    required this.frameId,
    required this.expandedId,
    this.patchTarget,
  });

  /// Whether this node can be patched directly.
  ///
  /// Returns false for nodes inside component instances, which require
  /// override handling instead of direct patches.
  bool get canPatch => patchTarget != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeTarget &&
          runtimeType == other.runtimeType &&
          frameId == other.frameId &&
          expandedId == other.expandedId &&
          patchTarget == other.patchTarget;

  @override
  int get hashCode => Object.hash(frameId, expandedId, patchTarget);

  @override
  String toString() =>
      'NodeTarget(frame: $frameId, expanded: $expandedId, patch: $patchTarget)';
}
