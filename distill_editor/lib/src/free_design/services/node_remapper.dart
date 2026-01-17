import '../models/node.dart';

/// Type alias for ID remapping maps.
typedef IdMap = Map<String, String>;

/// Remaps node IDs for paste operations.
///
/// Generates fresh IDs for all nodes and updates all ID references
/// (id, childIds, and any ID fields in props/layout/style).
///
/// Usage:
/// ```dart
/// final remapper = NodeRemapper();
/// final newNodes = remapper.remapNodes(originalNodes);
/// final newRootIds = remapper.remapRootIds(originalRootIds);
/// ```
class NodeRemapper {
  final IdMap _idMap = {};
  int _counter = 0;
  final int _timestamp = DateTime.now().microsecondsSinceEpoch;

  /// Generate a unique ID for pasted nodes.
  String _generateId() => 'paste_${_timestamp}_${_counter++}';

  /// Remap all nodes with fresh IDs.
  ///
  /// Phase 1: Generate new IDs for all nodes.
  /// Phase 2: Remap all ID references.
  ///
  /// Returns the remapped nodes with new IDs.
  List<Node> remapNodes(List<Node> nodes) {
    // Phase 1: Generate new IDs for all nodes
    for (final node in nodes) {
      _idMap[node.id] = _generateId();
    }

    // Phase 2: Remap all references
    return nodes.map(_remapNode).toList();
  }

  Node _remapNode(Node node) {
    return node.copyWith(
      id: _idMap[node.id]!,
      childIds: node.childIds.map((id) => _idMap[id] ?? id).toList(),
      props: node.props.remapIds(_idMap),
      layout: node.layout.remapIds(_idMap),
      style: node.style.remapIds(_idMap),
    );
  }

  /// Remap root IDs to their new values.
  ///
  /// Call after [remapNodes] to get the new IDs for the root nodes.
  List<String> remapRootIds(List<String> oldRootIds) {
    return oldRootIds.map((id) => _idMap[id]!).toList();
  }

  /// Get the ID mapping (old ID -> new ID).
  ///
  /// Useful for debugging or if you need to reference the mapping.
  IdMap get idMap => Map.unmodifiable(_idMap);
}
