import 'package:flutter/foundation.dart';

import '../models/editor_document.dart';
import '../models/node.dart';
import '../patch/patch_applier.dart';
import '../patch/patch_op.dart';
import '../patch/scene_change_set.dart';
import 'undo_redo.dart';

/// State manager for an [EditorDocument].
///
/// Manages:
/// - Immutable document state
/// - Patch application
/// - Change tracking for incremental updates
/// - Parent index for efficient tree queries
class EditorDocumentStore extends ChangeNotifier {
  EditorDocument _document;
  final PatchApplier _applier;

  /// Parent index: child ID → parent ID.
  Map<String, String> _parentIndex = {};

  /// Pending changes since last notification.
  SceneChangeSet _pendingChanges = const SceneChangeSet();

  // Undo/redo history
  final List<UndoEntry> _undoStack = [];
  final List<UndoEntry> _redoStack = [];
  static const _maxHistorySize = 100;

  /// Max time between edits to coalesce (2 seconds).
  static const _coalesceThreshold = Duration(seconds: 2);

  // Active grouping context
  String? _activeGroupId;

  EditorDocumentStore({
    required EditorDocument document,
    PatchApplier applier = const PatchApplier(),
  })  : _document = document,
        _applier = applier {
    _rebuildParentIndex();
  }

  /// Create a store with an empty document.
  factory EditorDocumentStore.empty({String? documentId}) {
    return EditorDocumentStore(
      document: EditorDocument.empty(documentId: documentId),
    );
  }

  // ===========================================================================
  // Getters
  // ===========================================================================

  /// The current document state.
  EditorDocument get document => _document;

  /// Parent index for efficient tree queries.
  Map<String, String> get parentIndex => Map.unmodifiable(_parentIndex);

  /// Pending changes since last clear.
  SceneChangeSet get pendingChanges => _pendingChanges;

  // ===========================================================================
  // Mutation
  // ===========================================================================

  /// Apply a single patch operation.
  void applyPatch(PatchOp op, {String? groupId, String? label}) {
    applyPatches([op], groupId: groupId, label: label);
  }

  /// Apply multiple patch operations atomically.
  void applyPatches(Iterable<PatchOp> ops, {String? groupId, String? label}) {
    final patches = ops.toList();
    if (patches.isEmpty) return;

    // Compute inverses BEFORE applying (need old state)
    final inverses = patches
        .map((p) => PatchInverter.invert(p, _document, _parentIndex))
        .toList()
        .reversed
        .toList();

    // Apply patches
    for (final op in patches) {
      _document = _applier.apply(_document, op);
      _trackChanges(op);
    }
    _rebuildParentIndex();

    // Record for undo with coalescing
    final effectiveGroupId = groupId ?? _activeGroupId ?? _generateGroupId();
    final newEntry = UndoEntry(
      groupId: effectiveGroupId,
      patches: patches,
      inversePatches: inverses,
      timestamp: DateTime.now(),
      label: label,
    );

    // Coalesce if same group AND within time threshold
    final shouldCoalesce = _undoStack.isNotEmpty &&
        _undoStack.last.groupId == effectiveGroupId &&
        newEntry.timestamp.difference(_undoStack.last.timestamp) <
            _coalesceThreshold;

    if (shouldCoalesce) {
      final lastEntry = _undoStack.removeLast();
      _undoStack.add(lastEntry.merge(newEntry));
    } else {
      _undoStack.add(newEntry);
      // Only clear redo on NEW group
      _redoStack.clear();
    }

    // Enforce stack limit
    while (_undoStack.length > _maxHistorySize) {
      _undoStack.removeAt(0);
    }

    notifyListeners();
  }

  /// Replace the entire document.
  void setDocument(EditorDocument document) {
    _document = document;
    _rebuildParentIndex();
    _pendingChanges = SceneChangeSet(
      compilationDirty: document.nodes.keys.toSet(),
      frameDirty: document.frames.keys.toSet(),
    );
    // Clear undo/redo stacks when replacing entire document
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  /// Clear pending changes.
  void clearChanges() {
    _pendingChanges = const SceneChangeSet();
  }

  // ===========================================================================
  // Undo/Redo
  // ===========================================================================

  /// Whether undo is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Start grouping operations under a single undo entry.
  void beginGroup(String groupId) => _activeGroupId = groupId;

  /// End the current grouping context.
  void endGroup() => _activeGroupId = null;

  /// Undo the last operation.
  void undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    _applyWithoutHistory(entry.inversePatches);
    _redoStack.add(entry);
    notifyListeners();
  }

  /// Redo the last undone operation.
  void redo() {
    if (_redoStack.isEmpty) return;
    final entry = _redoStack.removeLast();
    _applyWithoutHistory(entry.patches);
    _undoStack.add(entry);
    notifyListeners();
  }

  void _applyWithoutHistory(List<PatchOp> ops) {
    for (final op in ops) {
      _document = _applier.apply(_document, op);
      _trackChanges(op);
    }
    _rebuildParentIndex();
  }

  String _generateGroupId() => 'g_${DateTime.now().microsecondsSinceEpoch}';

  // ===========================================================================
  // Query Helpers
  // ===========================================================================

  /// Get the parent of a node.
  String? getParent(String nodeId) => _parentIndex[nodeId];

  /// Get all ancestors of a node (from immediate parent to root).
  List<String> getAncestors(String nodeId) {
    final result = <String>[];
    var current = nodeId;
    while (true) {
      final parent = _parentIndex[current];
      if (parent == null) break;
      result.add(parent);
      current = parent;
    }
    return result;
  }

  /// Get all descendants of a node.
  Set<String> getDescendants(String nodeId) {
    return _document.getSubtree(nodeId)..remove(nodeId);
  }

  /// Get the frame containing a node.
  String? getFrameForNode(String nodeId) {
    for (final frame in _document.frames.values) {
      if (_document.getSubtree(frame.rootNodeId).contains(nodeId)) {
        return frame.id;
      }
    }
    return null;
  }

  // ===========================================================================
  // Internals
  // ===========================================================================

  void _trackChanges(PatchOp op) {
    final changes = SceneChangeSet.fromPatch(
      op,
      _parentIndex,
      _document.nodes,
    );
    _pendingChanges = _pendingChanges.merge(changes);
  }

  void _rebuildParentIndex() {
    _parentIndex = _document.buildParentIndex();
  }
}

/// Extension methods for convenient document manipulation.
extension EditorDocumentStoreExtensions on EditorDocumentStore {
  /// Add a node and attach it to a parent.
  void addNode(Node node, {required String parentId, int index = -1}) {
    applyPatches([
      InsertNode(node),
      AttachChild(parentId: parentId, childId: node.id, index: index),
    ]);
  }

  /// Remove a node and all its descendants.
  void removeNode(String nodeId) {
    final patches = <PatchOp>[];

    // Collect all descendants (depth-first, children before parents)
    final subtree = document.getSubtree(nodeId).toList();

    // Detach root from parent
    final parentId = getParent(nodeId);
    if (parentId != null) {
      patches.add(DetachChild(parentId: parentId, childId: nodeId));
    }

    // Detach all internal parent-child relationships (for proper undo)
    for (final id in subtree) {
      final node = document.nodes[id];
      if (node != null) {
        for (final childId in node.childIds) {
          patches.add(DetachChild(parentId: id, childId: childId));
        }
      }
    }

    // Delete all nodes (children first, then parents)
    for (final id in subtree.reversed) {
      patches.add(DeleteNode(id));
    }

    applyPatches(patches, label: 'Delete node');
  }

  /// Move a node to a new parent.
  void moveNode(String nodeId, {required String newParentId, int index = -1}) {
    applyPatch(MoveNode(id: nodeId, newParentId: newParentId, index: index));
  }

  /// Update a node property.
  ///
  /// Rapid edits to the same property are coalesced into a single undo entry.
  void updateNodeProp(String nodeId, String path, dynamic value) {
    // Generate stable groupId for coalescing rapid edits to same property
    final groupId = 'prop_${nodeId}_$path';
    applyPatch(SetProp(id: nodeId, path: path, value: value), groupId: groupId);
  }

  /// Update multiple properties on a node atomically.
  ///
  /// This method batches multiple property updates into a single notification,
  /// reducing rebuild count by 75% for composite editors.
  ///
  /// Usage:
  /// ```dart
  /// store.updateNodeProps(nodeId, {
  ///   '/style/cornerRadius/topLeft': 8.0,
  ///   '/style/cornerRadius/topRight': 8.0,
  ///   '/style/cornerRadius/bottomLeft': 8.0,
  ///   '/style/cornerRadius/bottomRight': 8.0,
  /// });
  /// ```
  void updateNodeProps(String nodeId, Map<String, dynamic> updates) {
    final patches = updates.entries.map(
      (e) => SetProp(id: nodeId, path: e.key, value: e.value),
    );
    // Generate stable groupId for coalescing
    final groupId = 'props_${nodeId}_${updates.keys.join('_')}';
    applyPatches(patches, groupId: groupId);
  }

  /// Update a frame property.
  ///
  /// Rapid edits to the same property are coalesced into a single undo entry.
  void updateFrameProp(String frameId, String path, dynamic value) {
    // Generate stable groupId for coalescing rapid edits to same property
    final groupId = 'frame_${frameId}_$path';
    applyPatch(
      SetFrameProp(frameId: frameId, path: path, value: value),
      groupId: groupId,
    );
  }
}
