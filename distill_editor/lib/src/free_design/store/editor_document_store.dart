import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';

import '../models/editor_document.dart';
import '../models/frame.dart';
import '../models/node.dart';
import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';
import '../models/node_type.dart';
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
  ///
  /// @deprecated Use [replaceDocument] instead for clearer semantics.
  void setDocument(EditorDocument document) {
    replaceDocument(document);
  }

  /// Replace the entire document (for load/new).
  ///
  /// This is a full reset: clears undo/redo, rebuilds indexes.
  /// Use this when loading from file or creating a new document.
  void replaceDocument(EditorDocument newDoc, {bool clearUndo = true}) {
    _document = newDoc;
    _rebuildParentIndex();
    _pendingChanges = SceneChangeSet(
      compilationDirty: newDoc.nodes.keys.toSet(),
      frameDirty: newDoc.frames.keys.toSet(),
    );
    if (clearUndo) {
      _undoStack.clear();
      _redoStack.clear();
    }
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
  ///
  /// For slot content nodes (which have [ownerInstanceId] but aren't in the
  /// frame's subtree), this follows the ownership chain to find the frame.
  String? getFrameForNode(String nodeId) {
    // First check if the node is directly in a frame's subtree
    for (final frame in _document.frames.values) {
      if (_document.getSubtree(frame.rootNodeId).contains(nodeId)) {
        return frame.id;
      }
    }

    // If not found, check if this is a slot content node (has ownerInstanceId)
    final node = _document.nodes[nodeId];
    if (node?.ownerInstanceId != null) {
      // Recursively find the frame containing the owner instance
      return getFrameForNode(node!.ownerInstanceId!);
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
  ///
  /// If the node is an instance, also removes all nodes where
  /// `ownerInstanceId == nodeId` (slot content cleanup).
  void removeNode(String nodeId) {
    final patches = <PatchOp>[];
    final node = document.nodes[nodeId];

    // Collect all descendants (depth-first, children before parents)
    final subtree = document.getSubtree(nodeId).toList();

    // Detach root from parent
    final parentId = getParent(nodeId);
    if (parentId != null) {
      patches.add(DetachChild(parentId: parentId, childId: nodeId));
    }

    // Detach all internal parent-child relationships (for proper undo)
    for (final id in subtree) {
      final subtreeNode = document.nodes[id];
      if (subtreeNode != null) {
        for (final childId in subtreeNode.childIds) {
          patches.add(DetachChild(parentId: id, childId: childId));
        }
      }
    }

    // Delete all nodes (children first, then parents)
    for (final id in subtree.reversed) {
      patches.add(DeleteNode(id));
    }

    // If this is an instance, clean up owned slot content
    if (node?.type == NodeType.instance) {
      patches.addAll(_collectOwnedSlotContentPatches(nodeId));
    }

    applyPatches(patches, label: 'Delete node');
  }

  /// Collect all node IDs owned by an instance (slot content).
  List<String> collectOwnedSubtrees(String instanceId) {
    final result = <Set<String>>{}; // Use Set to deduplicate
    for (final node in document.nodes.values) {
      if (node.ownerInstanceId == instanceId) {
        result.add(document.getSubtree(node.id));
      }
    }
    // Flatten and deduplicate
    return result.expand((s) => s).toSet().toList();
  }

  /// Generate patches to delete all slot content owned by an instance.
  List<PatchOp> _collectOwnedSlotContentPatches(String instanceId) {
    final patches = <PatchOp>[];
    final ownedIds = collectOwnedSubtrees(instanceId);

    // Detach internal relationships
    for (final id in ownedIds) {
      final node = document.nodes[id];
      if (node != null) {
        for (final childId in node.childIds) {
          patches.add(DetachChild(parentId: id, childId: childId));
        }
      }
    }

    // Delete nodes (children first)
    for (final id in ownedIds.reversed) {
      patches.add(DeleteNode(id));
    }

    return patches;
  }

  /// Clear slot content for an instance.
  ///
  /// Deletes the content nodes and removes the slot assignment.
  void clearSlotContent(String instanceId, String slotName) {
    final node = document.nodes[instanceId];
    if (node?.props is! InstanceProps) return;

    final props = node!.props as InstanceProps;
    final assignment = props.slots[slotName];

    if (assignment?.rootNodeId == null) return;

    final patches = <PatchOp>[];

    // Delete old content subtree
    final oldRootId = assignment!.rootNodeId!;
    final oldSubtree = document.getSubtree(oldRootId).toList();

    // Detach internal relationships
    for (final id in oldSubtree) {
      final subtreeNode = document.nodes[id];
      if (subtreeNode != null) {
        for (final childId in subtreeNode.childIds) {
          patches.add(DetachChild(parentId: id, childId: childId));
        }
      }
    }

    // Delete nodes
    for (final id in oldSubtree.reversed) {
      patches.add(DeleteNode(id));
    }

    // Update instance props - remove slot assignment
    final newSlots = Map<String, SlotAssignment>.from(props.slots);
    newSlots.remove(slotName);
    patches.add(SetProp(
      id: instanceId,
      path: '/props/slots',
      value: newSlots.isEmpty
          ? null
          : newSlots.map((k, v) => MapEntry(k, v.toJson())),
    ));

    applyPatches(patches, label: 'Clear slot');
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

  /// Delete a frame and all its nodes atomically.
  ///
  /// Properly handles undo by detaching only cross-boundary edges
  /// (edges where parent is in subtree but child is not).
  void deleteFrameAndSubtree(String frameId) {
    final frame = document.frames[frameId];
    if (frame == null) return;

    final patches = <PatchOp>[];

    // 1. Collect all nodes in frame's subtree
    final subtreeSet = document.getSubtree(frame.rootNodeId);
    final subtreeList = subtreeSet.toList();

    // 2. Detach only cross-boundary edges (child outside subtree)
    // This is rare but ensures correctness if nodes somehow reference
    // nodes outside their frame.
    for (final id in subtreeList) {
      final node = document.nodes[id];
      if (node != null) {
        for (final childId in node.childIds) {
          if (!subtreeSet.contains(childId)) {
            patches.add(DetachChild(parentId: id, childId: childId));
          }
        }
      }
    }

    // 3. Delete all nodes bottom-up (children before parents)
    for (final id in subtreeList.reversed) {
      patches.add(DeleteNode(id));
    }

    // 4. Remove frame
    patches.add(RemoveFrame(frameId));

    applyPatches(patches, label: 'Delete frame');
  }

  /// Execute paste operation atomically.
  ///
  /// Inserts all nodes and attaches roots to the target parent.
  /// Returns the new root IDs for selection.
  List<String> executePaste({
    required List<Node> nodes,
    required List<String> rootIds,
    required String targetParentId,
    int index = -1,
    String? label,
  }) {
    final patches = <PatchOp>[];

    // 1. Insert all nodes
    for (final node in nodes) {
      patches.add(InsertNode(node));
    }

    // 2. Attach roots to target parent
    for (final rootId in rootIds) {
      patches.add(AttachChild(
        parentId: targetParentId,
        childId: rootId,
        index: index,
      ));
    }

    // 3. Apply atomically
    applyPatches(patches, label: label ?? 'Paste');

    return rootIds;
  }

  /// Create an empty frame at the given position.
  void createEmptyFrame({
    required Offset position,
    Size size = const Size(375, 812),
    String? name,
  }) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final frameId = 'frame_$timestamp';
    final rootNodeId = 'node_${timestamp}_root';
    final now = DateTime.now();
    final frameName = name ?? 'Untitled Frame';

    // Root node sized to match frame, positioned at origin (0,0) in local space
    final rootNode = Node(
      id: rootNodeId,
      name: frameName, // Same as frame name
      type: NodeType.container,
      props: ContainerProps(),
      layout: NodeLayout(
        size: SizeMode.fixed(size.width, size.height),
      ),
      style: NodeStyle(fill: SolidFill(const HexColor('#FFFFFF'))),
    );

    final frame = Frame(
      id: frameId,
      name: frameName,
      rootNodeId: rootNodeId,
      canvas: CanvasPlacement(position: position, size: size),
      createdAt: now,
      updatedAt: now,
    );

    applyPatches([
      InsertNode(rootNode),
      InsertFrame(frame),
    ], label: 'Create frame');
  }

  /// Create a frame for editing a component.
  ///
  /// Component frames share the component's root node - they don't create
  /// a new root node. The frame's `rootNodeId` points to the component's
  /// `rootNodeId`.
  ///
  /// Throws [ArgumentError] if the component doesn't exist.
  Frame createComponentFrame({
    required String componentId,
    required Offset position,
  }) {
    final component = document.components[componentId];
    if (component == null) {
      throw ArgumentError('Component not found: $componentId');
    }

    // Get size from component root node, or use default
    final rootNode = document.nodes[component.rootNodeId];
    final size = _getNodeSize(rootNode) ?? const Size(375, 400);

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final now = DateTime.now();

    final frame = Frame(
      id: 'frame_comp_$timestamp',
      name: component.name,
      rootNodeId: component.rootNodeId, // Share component's root node
      canvas: CanvasPlacement(position: position, size: size),
      kind: FrameKind.component,
      componentId: componentId,
      createdAt: now,
      updatedAt: now,
    );

    applyPatches([
      InsertFrame(frame),
    ], label: 'Create component frame');

    return frame;
  }

  /// Get the size of a node from its layout, or null if not determinable.
  Size? _getNodeSize(Node? node) {
    if (node == null) return null;

    final width = node.layout.size.width;
    final height = node.layout.size.height;

    // Only return size if both dimensions are fixed values
    if (width is AxisSizeFixed && height is AxisSizeFixed) {
      return Size(width.value, height.value);
    }

    return null;
  }
}
