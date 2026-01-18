# PRD: Priority 3 - Copy & Paste

## Overview

Copy & Paste is a fundamental editing primitive that users expect in any design tool. This feature enables efficient duplication and rearrangement of design elements within and across frames.

**Status:** Not Started
**Dependencies:** Priority 1 (Drag & Drop) - Completed
**Estimated Complexity:** Medium

---

## Problem Statement

Currently, users cannot copy, cut, or paste nodes. To duplicate content, they must either:
1. Manually recreate it
2. Use AI to regenerate similar content
3. Edit JSON directly (not user-friendly)

This severely limits productivity and makes iterative design workflows tedious.

---

## Goals

1. **Standard clipboard operations**: Cmd+C, Cmd+V, Cmd+X working as expected
2. **Duplicate shortcut**: Cmd+D for quick duplication with offset
3. **Cross-frame support**: Copy from one frame, paste into another
4. **Multi-select support**: Copy/paste multiple nodes while preserving relative positions
5. **Undo integration**: All clipboard operations fully undoable

---

## Non-Goals (Out of Scope)

- Cross-document copy/paste (file-to-file)
- System clipboard integration (external app interop)
- Copy/paste of frames (only nodes)
- Style-only paste ("paste properties")
- Component definition copy/paste

---

## Success Criteria

| Criterion | Metric | Validation Method |
|-----------|--------|-------------------|
| Copy selected node(s) | Cmd+C stores in internal clipboard | Unit test |
| Paste into container | Cmd+V inserts as child of selection | Unit test |
| Paste at root | Cmd+V with frame selected inserts at root | Unit test |
| Cut operation | Cmd+X copies then deletes | Unit test |
| Duplicate with offset | Cmd+D creates offset copy | Unit test |
| Fresh IDs on paste | No ID collisions | Unit test |
| Cross-frame paste | Copy in frame A, paste in frame B | Integration test |
| Multi-select paste | Relative positions preserved | Unit test |
| Undo paste | Single undo removes pasted nodes | Unit test |
| Undo cut | Single undo restores cut nodes | Unit test |

---

## Technical Architecture

### 1. Clipboard Data Model

```dart
/// Internal clipboard storage for copied nodes
class ClipboardData {
  /// Serialized node subtrees (root nodes with all descendants)
  final List<SerializedNodeTree> trees;

  /// Source frame ID (for relative positioning context)
  final String sourceFrameId;

  /// Bounding box of copied content (for offset calculation)
  final Rect boundingBox;

  /// Timestamp for potential expiry
  final DateTime copiedAt;

  ClipboardData({
    required this.trees,
    required this.sourceFrameId,
    required this.boundingBox,
    required this.copiedAt,
  });
}

/// A node and its entire subtree, serialized for clipboard
class SerializedNodeTree {
  /// The root node of this tree
  final Node rootNode;

  /// All descendant nodes (flat map for reconstruction)
  final Map<String, Node> descendants;

  /// Original position relative to copy bounding box
  final Offset relativePosition;

  SerializedNodeTree({
    required this.rootNode,
    required this.descendants,
    required this.relativePosition,
  });

  /// Deep clone with new IDs
  SerializedNodeTree cloneWithNewIds(String Function(String oldId) idGenerator) {
    final idMap = <String, String>{};

    // Generate new IDs for all nodes
    idMap[rootNode.id] = idGenerator(rootNode.id);
    for (final id in descendants.keys) {
      idMap[id] = idGenerator(id);
    }

    // Clone with remapped IDs and children references
    final newRoot = _remapNode(rootNode, idMap);
    final newDescendants = descendants.map(
      (oldId, node) => MapEntry(idMap[oldId]!, _remapNode(node, idMap)),
    );

    return SerializedNodeTree(
      rootNode: newRoot,
      descendants: newDescendants,
      relativePosition: relativePosition,
    );
  }

  Node _remapNode(Node node, Map<String, String> idMap) {
    return node.copyWith(
      id: idMap[node.id]!,
      children: node.children.map((childId) => idMap[childId]!).toList(),
    );
  }
}
```

### 2. Clipboard Service

```dart
/// Service managing clipboard operations
class ClipboardService extends ChangeNotifier {
  ClipboardData? _data;

  /// Current clipboard contents (null if empty)
  ClipboardData? get data => _data;

  /// Whether clipboard has content
  bool get hasData => _data != null;

  /// Copy nodes to clipboard
  void copy({
    required List<String> nodeIds,
    required EditorDocument document,
    required String frameId,
  }) {
    if (nodeIds.isEmpty) return;

    final trees = <SerializedNodeTree>[];
    final bounds = <Rect>[];

    for (final nodeId in nodeIds) {
      final node = document.nodes[nodeId];
      if (node == null) continue;

      // Collect subtree
      final descendants = _collectSubtree(nodeId, document);

      // Calculate node bounds
      final nodeBounds = _calculateBounds(node);
      bounds.add(nodeBounds);

      trees.add(SerializedNodeTree(
        rootNode: node,
        descendants: descendants,
        relativePosition: nodeBounds.topLeft,
      ));
    }

    if (trees.isEmpty) return;

    // Calculate combined bounding box
    final combinedBounds = bounds.reduce((a, b) => a.expandToInclude(b));

    // Adjust relative positions to bounding box origin
    final adjustedTrees = trees.map((tree) {
      return SerializedNodeTree(
        rootNode: tree.rootNode,
        descendants: tree.descendants,
        relativePosition: tree.relativePosition - combinedBounds.topLeft,
      );
    }).toList();

    _data = ClipboardData(
      trees: adjustedTrees,
      sourceFrameId: frameId,
      boundingBox: combinedBounds,
      copiedAt: DateTime.now(),
    );

    notifyListeners();
  }

  /// Collect all descendant nodes
  Map<String, Node> _collectSubtree(String nodeId, EditorDocument document) {
    final result = <String, Node>{};
    final node = document.nodes[nodeId];
    if (node == null) return result;

    for (final childId in node.children) {
      final child = document.nodes[childId];
      if (child != null) {
        result[childId] = child;
        result.addAll(_collectSubtree(childId, document));
      }
    }

    return result;
  }

  /// Clear clipboard
  void clear() {
    _data = null;
    notifyListeners();
  }
}
```

### 3. Paste Operations

```dart
/// Generates patches for paste operation
class PasteOperationBuilder {
  final EditorDocument document;
  final ClipboardData clipboardData;
  final String targetParentId;
  final int insertIndex;
  final Offset pasteOffset;

  PasteOperationBuilder({
    required this.document,
    required this.clipboardData,
    required this.targetParentId,
    required this.insertIndex,
    required this.pasteOffset,
  });

  /// Build patches for paste operation
  List<PatchOp> build() {
    final patches = <PatchOp>[];
    final idGenerator = _createIdGenerator();

    for (final tree in clipboardData.trees) {
      // Clone with new IDs
      final cloned = tree.cloneWithNewIds(idGenerator);

      // Apply position offset
      final positionedRoot = _applyPositionOffset(
        cloned.rootNode,
        pasteOffset + tree.relativePosition,
      );

      // Insert all nodes (descendants first, then root)
      for (final entry in cloned.descendants.entries) {
        patches.add(InsertNode(node: entry.value));
      }
      patches.add(InsertNode(node: positionedRoot));

      // Attach root to target parent
      patches.add(AttachChild(
        parentId: targetParentId,
        childId: positionedRoot.id,
        index: insertIndex,
      ));
    }

    return [Batch(ops: patches)];
  }

  /// Create unique ID generator
  String Function(String) _createIdGenerator() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    var counter = 0;

    return (String oldId) {
      counter++;
      // Preserve prefix pattern (e.g., n_button -> n_button_copy_123_1)
      return '${oldId}_copy_${timestamp}_$counter';
    };
  }

  /// Apply position offset to node
  Node _applyPositionOffset(Node node, Offset offset) {
    return node.copyWith(
      layout: node.layout.copyWith(
        position: Position(
          x: (node.layout.position?.x ?? 0) + offset.dx,
          y: (node.layout.position?.y ?? 0) + offset.dy,
        ),
      ),
    );
  }
}
```

### 4. Keyboard Integration

```dart
/// Clipboard keyboard shortcuts handler
class ClipboardKeyboardHandler {
  final ClipboardService clipboardService;
  final EditorDocumentStore documentStore;
  final CanvasState canvasState;

  ClipboardKeyboardHandler({
    required this.clipboardService,
    required this.documentStore,
    required this.canvasState,
  });

  /// Handle keyboard event, return true if handled
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isCmd = HardwareKeyboard.instance.isMetaPressed ||
                  HardwareKeyboard.instance.isControlPressed;

    if (!isCmd) return false;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyC:
        return _handleCopy();
      case LogicalKeyboardKey.keyV:
        return _handlePaste();
      case LogicalKeyboardKey.keyX:
        return _handleCut();
      case LogicalKeyboardKey.keyD:
        return _handleDuplicate();
      default:
        return false;
    }
  }

  bool _handleCopy() {
    final selectedNodeIds = canvasState.selectedNodeIds;
    if (selectedNodeIds.isEmpty) return false;

    final frameId = canvasState.focusedFrameId;
    if (frameId == null) return false;

    clipboardService.copy(
      nodeIds: selectedNodeIds.toList(),
      document: documentStore.document,
      frameId: frameId,
    );

    return true;
  }

  bool _handlePaste() {
    if (!clipboardService.hasData) return false;

    final targetInfo = _determinePasteTarget();
    if (targetInfo == null) return false;

    final builder = PasteOperationBuilder(
      document: documentStore.document,
      clipboardData: clipboardService.data!,
      targetParentId: targetInfo.parentId,
      insertIndex: targetInfo.index,
      pasteOffset: targetInfo.offset,
    );

    final patches = builder.build();
    documentStore.applyPatches(patches, coalesce: false);

    return true;
  }

  bool _handleCut() {
    if (!_handleCopy()) return false;

    // Delete selected nodes
    final selectedNodeIds = canvasState.selectedNodeIds.toList();
    final patches = selectedNodeIds.map((id) => DeleteNode(id: id)).toList();

    documentStore.applyPatches([Batch(ops: patches)], coalesce: false);
    canvasState.clearSelection();

    return true;
  }

  bool _handleDuplicate() {
    if (!_handleCopy()) return false;

    // Paste with offset
    final offset = const Offset(20, 20); // Standard duplication offset
    return _handlePasteWithOffset(offset);
  }

  /// Determine where to paste based on current selection
  _PasteTarget? _determinePasteTarget() {
    final selectedNodeIds = canvasState.selectedNodeIds;
    final frameId = canvasState.focusedFrameId;

    if (frameId == null) return null;

    final frame = documentStore.document.frames[frameId];
    if (frame == null) return null;

    // If a container is selected, paste into it
    if (selectedNodeIds.length == 1) {
      final selectedNode = documentStore.document.nodes[selectedNodeIds.first];
      if (selectedNode?.type == NodeType.container) {
        return _PasteTarget(
          parentId: selectedNodeIds.first,
          index: selectedNode!.children.length,
          offset: Offset.zero,
        );
      }
    }

    // Otherwise, paste into frame root with offset from clipboard position
    return _PasteTarget(
      parentId: frame.rootNodeId,
      index: -1, // Append
      offset: const Offset(20, 20),
    );
  }
}

class _PasteTarget {
  final String parentId;
  final int index;
  final Offset offset;

  _PasteTarget({
    required this.parentId,
    required this.index,
    required this.offset,
  });
}
```

---

## UI/UX Considerations

### Visual Feedback

1. **Copy indication**: Brief toast notification "Copied to clipboard"
2. **Paste indicator**: Show insertion indicator before paste commits
3. **Cut visual**: Nodes fade slightly after cut (before paste elsewhere)

### Paste Target Logic

| Selection State | Paste Behavior |
|-----------------|----------------|
| Single container selected | Paste as children of container |
| Single non-container selected | Paste as siblings after selection |
| Multiple nodes selected | Paste as siblings after last selected |
| Frame selected (no nodes) | Paste at frame root |
| Nothing selected | Paste at focused frame root |

### Duplicate Offset

- **Standard offset**: 20px right, 20px down
- **Repeat duplicate**: Subsequent Cmd+D uses same offset from new position
- **Smart offset**: If near edge, offset in available direction

---

## Test Plan

### Unit Tests

```dart
// test/free_design/services/clipboard_service_test.dart

group('ClipboardService', () {
  test('copy stores single node with descendants', () async {
    final service = ClipboardService();
    final document = createTestDocument();

    service.copy(
      nodeIds: ['n_container'],
      document: document,
      frameId: 'frame_1',
    );

    expect(service.hasData, isTrue);
    expect(service.data!.trees.length, equals(1));
    expect(service.data!.trees.first.descendants.length, greaterThan(0));
  });

  test('copy stores multiple nodes with relative positions', () async {
    final service = ClipboardService();
    final document = createTestDocument();

    service.copy(
      nodeIds: ['n_a', 'n_b'],
      document: document,
      frameId: 'frame_1',
    );

    expect(service.data!.trees.length, equals(2));
    // Verify relative positions are preserved
    final posA = service.data!.trees[0].relativePosition;
    final posB = service.data!.trees[1].relativePosition;
    expect(posA, isNot(equals(posB)));
  });

  test('clear removes clipboard data', () {
    final service = ClipboardService();
    service.copy(nodeIds: ['n_1'], document: createTestDocument(), frameId: 'f1');

    service.clear();

    expect(service.hasData, isFalse);
  });
});

group('PasteOperationBuilder', () {
  test('generates new IDs for all pasted nodes', () {
    final builder = createPasteBuilder();
    final patches = builder.build();

    final insertOps = patches
        .expand((p) => p is Batch ? p.ops : [p])
        .whereType<InsertNode>();

    final ids = insertOps.map((op) => op.node.id).toSet();

    // All IDs should be unique and contain "copy"
    expect(ids.length, equals(insertOps.length));
    expect(ids.every((id) => id.contains('copy')), isTrue);
  });

  test('preserves node structure on paste', () {
    final builder = createPasteBuilder();
    final patches = builder.build();

    // Apply patches to document
    final newDoc = applyPatches(createEmptyDocument(), patches);

    // Verify structure is preserved
    final pastedRoot = newDoc.nodes.values.firstWhere(
      (n) => n.id.contains('copy') && n.children.isNotEmpty,
    );

    expect(pastedRoot.children.length, greaterThan(0));
    expect(
      pastedRoot.children.every((childId) => newDoc.nodes.containsKey(childId)),
      isTrue,
    );
  });

  test('applies position offset', () {
    final builder = createPasteBuilder(pasteOffset: Offset(100, 50));
    final patches = builder.build();

    final insertOps = patches
        .expand((p) => p is Batch ? p.ops : [p])
        .whereType<InsertNode>();

    final rootInsert = insertOps.first;
    expect(rootInsert.node.layout.position!.x, greaterThanOrEqualTo(100));
    expect(rootInsert.node.layout.position!.y, greaterThanOrEqualTo(50));
  });
});

group('Clipboard Integration', () {
  test('Cmd+C copies selected nodes', () {
    final handler = createKeyboardHandler();
    selectNodes(['n_button']);

    final handled = handler.handleKeyEvent(cmdCKeyEvent);

    expect(handled, isTrue);
    expect(handler.clipboardService.hasData, isTrue);
  });

  test('Cmd+V pastes into selection', () {
    final handler = createKeyboardHandler();
    copyNodes(['n_button']);
    selectNodes(['n_container']);

    final initialChildCount = getNode('n_container').children.length;
    handler.handleKeyEvent(cmdVKeyEvent);

    final newChildCount = getNode('n_container').children.length;
    expect(newChildCount, equals(initialChildCount + 1));
  });

  test('Cmd+X cuts and removes nodes', () {
    final handler = createKeyboardHandler();
    selectNodes(['n_button']);

    handler.handleKeyEvent(cmdXKeyEvent);

    expect(handler.clipboardService.hasData, isTrue);
    expect(documentStore.document.nodes.containsKey('n_button'), isFalse);
  });

  test('Cmd+D duplicates with offset', () {
    final handler = createKeyboardHandler();
    selectNodes(['n_button']);
    final originalPos = getNode('n_button').layout.position;

    handler.handleKeyEvent(cmdDKeyEvent);

    // Find duplicated node
    final duplicate = documentStore.document.nodes.values
        .firstWhere((n) => n.id.contains('n_button_copy'));

    expect(duplicate.layout.position!.x, greaterThan(originalPos!.x));
    expect(duplicate.layout.position!.y, greaterThan(originalPos.y));
  });

  test('paste is undoable as single operation', () {
    final handler = createKeyboardHandler();
    copyNodes(['n_button']);
    selectNodes(['n_container']);

    handler.handleKeyEvent(cmdVKeyEvent);
    final countAfterPaste = documentStore.document.nodes.length;

    documentStore.undo();

    expect(documentStore.document.nodes.length, lessThan(countAfterPaste));
  });

  test('cross-frame paste works', () {
    final handler = createKeyboardHandler();
    focusFrame('frame_1');
    selectNodes(['n_button']);
    handler.handleKeyEvent(cmdCKeyEvent);

    focusFrame('frame_2');
    selectNodes(['n_root_2']);
    handler.handleKeyEvent(cmdVKeyEvent);

    // Verify pasted node is in frame_2's tree
    final frame2Root = documentStore.document.nodes['n_root_2']!;
    final hasPastedChild = frame2Root.children.any(
      (id) => id.contains('copy'),
    );
    expect(hasPastedChild, isTrue);
  });
});
```

### Integration Tests

```dart
// test/free_design/integration/clipboard_flow_test.dart

testWidgets('complete copy-paste workflow', (tester) async {
  await tester.pumpWidget(createTestApp());

  // Select a node
  await tester.tap(find.byKey(Key('node_n_button')));
  await tester.pump();

  // Copy (Cmd+C)
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();

  // Verify toast
  expect(find.text('Copied to clipboard'), findsOneWidget);

  // Select container
  await tester.tap(find.byKey(Key('node_n_container')));
  await tester.pump();

  // Paste (Cmd+V)
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();

  // Verify pasted node appears
  final container = tester.widget<Widget>(find.byKey(Key('node_n_container')));
  expect(container.children.length, greaterThan(originalChildCount));
});
```

---

## Implementation Order

1. **Phase 1: Core Infrastructure**
   - [ ] Create `ClipboardData` and `SerializedNodeTree` models
   - [ ] Implement `ClipboardService.copy()`
   - [ ] Add unit tests for copy operation

2. **Phase 2: Paste Operations**
   - [ ] Implement `PasteOperationBuilder`
   - [ ] Add ID generation with collision prevention
   - [ ] Implement position offset calculation
   - [ ] Add unit tests for paste operation

3. **Phase 3: Keyboard Integration**
   - [ ] Create `ClipboardKeyboardHandler`
   - [ ] Wire up Cmd+C, Cmd+V, Cmd+X
   - [ ] Implement paste target determination
   - [ ] Add unit tests for keyboard handling

4. **Phase 4: Duplicate Feature**
   - [ ] Implement Cmd+D shortcut
   - [ ] Add smart offset calculation
   - [ ] Add unit tests for duplicate

5. **Phase 5: Polish**
   - [ ] Add toast notifications
   - [ ] Add visual feedback during operations
   - [ ] Cross-frame paste testing
   - [ ] Performance optimization for large subtrees

---

## File Locations

```
lib/src/free_design/
├── clipboard/
│   ├── clipboard_data.dart          # Data models
│   ├── clipboard_service.dart       # Clipboard management
│   ├── paste_operation_builder.dart # Patch generation
│   └── clipboard_keyboard_handler.dart
└── ...

test/free_design/
├── clipboard/
│   ├── clipboard_service_test.dart
│   ├── paste_operation_builder_test.dart
│   └── clipboard_keyboard_handler_test.dart
└── integration/
    └── clipboard_flow_test.dart
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ID collision on paste | Low | High | Use timestamp + counter in ID generation |
| Large subtree paste performance | Medium | Medium | Batch all patches in single operation |
| Circular reference in subtree | Low | High | Validate subtree before serialization |
| Paste into invalid target | Medium | Low | Validate target accepts children |

---

## Dependencies

- `EditorDocumentStore` - For applying patches
- `CanvasState` - For selection state
- `PatchOp` types - For mutation operations
- `Node` model - For serialization

---

## Future Enhancements (Not in Scope)

1. **System clipboard integration** - Copy DSL to system clipboard for external use
2. **Paste style only** - Apply only style properties from clipboard
3. **Frame copy** - Copy entire frames
4. **History** - Multiple clipboard entries
