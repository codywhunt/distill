import '../models/editor_document.dart';
import '../patch/patch_op.dart';

/// A single undo/redo entry with forward and inverse patches.
class UndoEntry {
  final String groupId;
  final List<PatchOp> patches;
  final List<PatchOp> inversePatches;
  final DateTime timestamp;
  final String? label;

  const UndoEntry({
    required this.groupId,
    required this.patches,
    required this.inversePatches,
    required this.timestamp,
    this.label,
  });

  /// Merge another entry into this one (for coalescing).
  UndoEntry merge(UndoEntry other) {
    return UndoEntry(
      groupId: groupId,
      patches: [...patches, ...other.patches],
      // Inverses go in reverse order - new inverses first
      inversePatches: [...other.inversePatches, ...inversePatches],
      timestamp: other.timestamp,
      label: other.label ?? label,
    );
  }
}

/// Computes inverse patches for undo.
class PatchInverter {
  /// Compute inverse of a patch given current document state.
  /// MUST be called BEFORE the patch is applied.
  static PatchOp invert(
    PatchOp patch,
    EditorDocument doc,
    Map<String, String> parentIndex,
  ) {
    return switch (patch) {
      SetProp(:final id, :final path) =>
        SetProp(id: id, path: path, value: _getNodeValue(doc, id, path)),
      SetFrameProp(:final frameId, :final path) => SetFrameProp(
          frameId: frameId,
          path: path,
          value: _getFrameValue(doc, frameId, path),
        ),
      InsertNode(:final node) => DeleteNode(node.id),
      DeleteNode(:final id) => InsertNode(doc.nodes[id]!),
      AttachChild(:final parentId, :final childId) =>
        DetachChild(parentId: parentId, childId: childId),
      DetachChild(:final parentId, :final childId) => AttachChild(
          parentId: parentId,
          childId: childId,
          index: _getChildIndex(doc, parentId, childId),
        ),
      MoveNode(:final id) => () {
          final oldParentId = parentIndex[id];
          if (oldParentId == null) {
            // Node was a frame root - shouldn't happen, handle gracefully
            throw StateError('Cannot invert MoveNode for root node $id');
          }
          return MoveNode(
            id: id,
            newParentId: oldParentId,
            index: _getChildIndex(doc, oldParentId, id),
          );
        }(),
      ReplaceNode(:final id) => ReplaceNode(id: id, node: doc.nodes[id]!),
      InsertFrame(:final frame) => RemoveFrame(frame.id),
      RemoveFrame(:final frameId) => InsertFrame(doc.frames[frameId]!),
    };
  }

  /// Get child's index in parent's childIds list.
  static int _getChildIndex(
    EditorDocument doc,
    String parentId,
    String childId,
  ) {
    final parent = doc.nodes[parentId];
    if (parent == null) return -1;
    return parent.childIds.indexOf(childId);
  }

  /// Get value at JSON Pointer path from a Node.
  static dynamic _getNodeValue(EditorDocument doc, String nodeId, String path) {
    final node = doc.nodes[nodeId];
    if (node == null) return null;

    final segments = _parsePath(path);
    if (segments.isEmpty) return null;

    // Convert node to JSON and walk the path
    final json = node.toJson();
    return _getValueAtPath(json, segments);
  }

  /// Get value at JSON Pointer path from a Frame.
  static dynamic _getFrameValue(
    EditorDocument doc,
    String frameId,
    String path,
  ) {
    final frame = doc.frames[frameId];
    if (frame == null) return null;

    final segments = _parsePath(path);
    if (segments.isEmpty) return null;

    final json = frame.toJson();
    return _getValueAtPath(json, segments);
  }

  static List<String> _parsePath(String path) {
    if (path.isEmpty) return [];
    if (!path.startsWith('/')) return [path];
    return path.substring(1).split('/');
  }

  static dynamic _getValueAtPath(
    Map<String, dynamic> json,
    List<String> segments,
  ) {
    dynamic current = json;
    for (final segment in segments) {
      if (current is Map<String, dynamic>) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }
}
