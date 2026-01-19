import '../models/node.dart';
import 'patch_op.dart';

/// Categorizes changes from patch operations for incremental updates.
///
/// Used to determine what needs to be recomputed:
/// - [geometryDirty]: Node positions/sizes changed (spatial index update)
/// - [compilationDirty]: Node structure/style changed (recompile subtree)
/// - [frameDirty]: Frame positions/sizes changed (spatial index update)
class SceneChangeSet {
  /// Nodes with geometry changes (position/size).
  final Set<String> geometryDirty;

  /// Nodes with structure/style changes (need recompilation).
  final Set<String> compilationDirty;

  /// Frames with position/size changes.
  final Set<String> frameDirty;

  const SceneChangeSet({
    this.geometryDirty = const {},
    this.compilationDirty = const {},
    this.frameDirty = const {},
  });

  /// Whether there are no changes.
  bool get isEmpty =>
      geometryDirty.isEmpty &&
      compilationDirty.isEmpty &&
      frameDirty.isEmpty;

  /// Whether there are any changes.
  bool get isNotEmpty => !isEmpty;

  /// Merge with another change set.
  SceneChangeSet merge(SceneChangeSet other) => SceneChangeSet(
        geometryDirty: {...geometryDirty, ...other.geometryDirty},
        compilationDirty: {...compilationDirty, ...other.compilationDirty},
        frameDirty: {...frameDirty, ...other.frameDirty},
      );

  /// Create a change set from a patch operation.
  ///
  /// Requires document context to compute affected nodes correctly:
  /// - [parentIndex]: child ID → parent ID mapping
  /// - [nodes]: all nodes in the document (for subtree calculation)
  static SceneChangeSet fromPatch(
    PatchOp op,
    Map<String, String> parentIndex,
    Map<String, Node> nodes,
  ) {
    return switch (op) {
      // Geometry-only changes (position/size during drag)
      SetProp(:final id, :final path) when _isGeometryPath(path) =>
        SceneChangeSet(geometryDirty: {id}),

      // Frame position/size changes
      SetFrameProp(:final frameId, :final path) when _isGeometryPath(path) =>
        SceneChangeSet(frameDirty: {frameId}),

      // Structural/style changes need full recompile
      SetProp(:final id) =>
        SceneChangeSet(compilationDirty: _withAncestors(id, parentIndex)),

      // Node insertion: mark the new node and its subtree dirty
      InsertNode(:final node) => SceneChangeSet(
          compilationDirty: _subtree(node.id, {...nodes, node.id: node}),
        ),

      // Attaching to parent: parent, ancestors, and new subtree need recompile
      AttachChild(:final parentId, :final childId) => SceneChangeSet(
          compilationDirty: {
            ..._withAncestors(parentId, parentIndex),
            ..._subtree(childId, nodes),
          },
        ),

      // Detaching: parent and ancestors need recompile
      DetachChild(:final parentId) =>
        SceneChangeSet(compilationDirty: _withAncestors(parentId, parentIndex)),

      // Deleting node: no compilation needed (already detached)
      DeleteNode() => const SceneChangeSet(),

      // Moving: old parent, new parent, ancestors, and subtree
      MoveNode(:final id, :final newParentId) => SceneChangeSet(
          compilationDirty: {
            ..._withAncestors(parentIndex[id] ?? '', parentIndex),
            ..._withAncestors(newParentId, parentIndex),
            ..._subtree(id, nodes),
          },
        ),

      // Replacing: node and ancestors
      ReplaceNode(:final id) =>
        SceneChangeSet(compilationDirty: _withAncestors(id, parentIndex)),

      // Frame property changes (non-geometry)
      SetFrameProp(:final frameId) => SceneChangeSet(frameDirty: {frameId}),

      // Frame insertion
      InsertFrame(:final frame) => SceneChangeSet(frameDirty: {frame.id}),

      // Frame removal
      RemoveFrame(:final frameId) => SceneChangeSet(frameDirty: {frameId}),

      // Component operations don't affect scene directly
      // (instances are separate nodes that reference components)
      InsertComponent() => const SceneChangeSet(),
      RemoveComponent() => const SceneChangeSet(),
    };
  }

  /// Check if a path is a geometry-only path.
  static bool _isGeometryPath(String path) {
    // Only position changes are pure geometry (don't affect layout)
    // Size changes need recompilation because they affect auto-layout
    return path.startsWith('/layout/position') ||
        path.startsWith('/canvas/position') ||
        path.startsWith('/canvas/size');
  }

  /// Get a node and all its ancestors.
  static Set<String> _withAncestors(
    String id,
    Map<String, String> parentIndex,
  ) {
    final result = <String>{};
    if (id.isEmpty) return result;

    result.add(id);
    var current = id;
    while (true) {
      final parent = parentIndex[current];
      if (parent == null) break;
      result.add(parent);
      current = parent;
    }
    return result;
  }

  /// Get a node and all its descendants.
  static Set<String> _subtree(String id, Map<String, Node> nodes) {
    final result = <String>{id};
    final node = nodes[id];
    if (node == null) return result;

    for (final childId in node.childIds) {
      result.addAll(_subtree(childId, nodes));
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SceneChangeSet &&
          _setEquals(geometryDirty, other.geometryDirty) &&
          _setEquals(compilationDirty, other.compilationDirty) &&
          _setEquals(frameDirty, other.frameDirty);

  @override
  int get hashCode => Object.hash(
        Object.hashAll(geometryDirty),
        Object.hashAll(compilationDirty),
        Object.hashAll(frameDirty),
      );

  @override
  String toString() => 'SceneChangeSet('
      'geometry: $geometryDirty, '
      'compilation: $compilationDirty, '
      'frame: $frameDirty)';
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final item in a) {
    if (!b.contains(item)) return false;
  }
  return true;
}
