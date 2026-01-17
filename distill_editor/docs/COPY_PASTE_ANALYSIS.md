# Copy & Paste Implementation Analysis

**Priority 3 Status Report** | January 2026 | *Revised*

---

## Executive Summary

Copy & Paste functionality is **not yet implemented** in Distill. The codebase has solid architectural foundations, but implementation requires careful attention to:

1. **Dual clipboard strategy** (internal + system) for reliability
2. **Top-level root filtering** to avoid copying descendants twice
3. **Anchor-based positioning** for correct multi-select placement
4. **Deterministic paste targets** (Set iteration order is not guaranteed)

| Component | Status | Notes |
|-----------|--------|-------|
| Keyboard shortcut infrastructure | ✅ Ready | Pattern exists |
| Selection system | ✅ Ready | Need root filtering logic |
| Node serialization (JSON) | ✅ Ready | Full round-trip |
| ID generation utilities | ✅ Ready | Timestamp + counter |
| Undo/redo integration | ✅ Ready | Automatic inverses |
| Patch operations | ✅ Ready | InsertNode, AttachChild |
| Internal clipboard | ❌ Missing | Required for duplicate |
| Anchor/position tracking | ❌ Missing | Required for cursor paste |

---

## Critical Design Decisions

### 1. Dual Clipboard Architecture

**Why two clipboards?**

Flutter's `Clipboard` API is text-only and async. Relying solely on it causes:
- Flaky behavior on web (clipboard permissions, async timing)
- Slow duplicate operations (unnecessary round-trip)
- No future extensibility (binary data, multiple payloads)

**Solution:**

| Operation | Internal Clipboard | System Clipboard |
|-----------|-------------------|------------------|
| `Cmd+C` | Write | Write (JSON text) |
| `Cmd+V` | Read (if fresh) | Fallback read |
| `Cmd+X` | Write | Write (JSON text) |
| `Cmd+D` | Read/Write only | Skip entirely |

```dart
class ClipboardService {
  /// In-memory clipboard for fast, reliable operations
  ClipboardPayload? _internalClipboard;

  /// Timestamp to detect stale internal clipboard
  DateTime? _internalTimestamp;

  /// Copy to both clipboards
  Future<void> copy(ClipboardPayload payload) async {
    _internalClipboard = payload;
    _internalTimestamp = DateTime.now();

    // Best-effort system clipboard (don't await in critical path)
    Clipboard.setData(ClipboardData(text: payload.toJson()))
        .catchError((_) {}); // Ignore failures on web
  }

  /// For duplicate: use internal only, no async
  ClipboardPayload? getInternal() => _internalClipboard;

  /// For paste: prefer internal, fallback to system
  Future<ClipboardPayload?> paste() async {
    // Use internal if fresh (within last 30 seconds and same session)
    if (_internalClipboard != null && _internalTimestamp != null) {
      final age = DateTime.now().difference(_internalTimestamp!);
      if (age.inSeconds < 30) {
        return _internalClipboard;
      }
    }

    // Fallback to system clipboard
    try {
      final data = await Clipboard.getData('text/plain');
      if (data?.text != null) {
        return ClipboardPayload.fromJson(data!.text!);
      }
    } catch (_) {}

    return _internalClipboard; // Last resort
  }
}
```

---

### 2. Selection Semantics: Top-Level Roots Only

**The Bug:** If a user selects both a parent and its child, naive copying includes both—resulting in the child being pasted twice (once as part of parent's subtree, once standalone).

**Solution:** Filter selection to only include **root nodes** (nodes whose parent is NOT also selected).

```dart
/// Extract copyable node IDs, filtering to top-level roots only
List<String> getTopLevelRoots(
  Set<DragTarget> selection,
  Map<String, String> parentIndex,
  Map<String, Frame> frames,
) {
  // Step 1: Collect all selected node IDs (ignore null patchTargets)
  final selectedNodeIds = <String>{};

  for (final target in selection) {
    switch (target) {
      case NodeTarget(:final patchTarget):
        if (patchTarget != null) {
          selectedNodeIds.add(patchTarget);
        }
      case FrameTarget(:final frameId):
        final frame = frames[frameId];
        if (frame != null) {
          selectedNodeIds.add(frame.rootNodeId);
        }
    }
  }

  // Step 2: Filter to roots (parent not in selection)
  final roots = <String>[];
  for (final nodeId in selectedNodeIds) {
    final parentId = parentIndex[nodeId];
    if (parentId == null || !selectedNodeIds.contains(parentId)) {
      roots.add(nodeId);
    }
  }

  // Step 3: Sort for deterministic order (important!)
  roots.sort();
  return roots;
}
```

**Why sort?** `Set` iteration order is not guaranteed. Sorting ensures consistent behavior across paste operations.

---

### 3. Clipboard Payload Format

```json
{
  "type": "distill_clipboard",
  "version": 1,
  "source": {
    "documentId": "doc_123",
    "frameId": "frame_456"
  },
  "rootIds": ["node_A", "node_B"],
  "nodes": [
    { "id": "node_A", "type": "container", ... },
    { "id": "node_A_child1", "type": "text", ... },
    { "id": "node_B", "type": "box", ... }
  ],
  "anchor": { "x": 120, "y": 80 }
}
```

**Fields explained:**

| Field | Purpose |
|-------|---------|
| `type` | Magic string to identify Distill clipboard data |
| `version` | Schema version for future compatibility |
| `source` | Origin document/frame (for potential same-doc detection) |
| `rootIds` | Top-level selected nodes (not descendants) |
| `nodes` | All nodes in subtrees (roots + all descendants) |
| `anchor` | Bounding box top-left in **frame-local** coordinates |

**Why `anchor` matters:**

- For multi-select, each root's position is stored relative to the anchor
- On paste-at-cursor: `delta = cursorFrameLocal - anchor`, apply delta to all roots
- On duplicate: `delta = Offset(16, 16)`, apply to all roots
- Frame-local coordinates are stable across cross-frame paste

```dart
/// Compute anchor as bounding box top-left of selected roots
Offset computeAnchor(List<String> rootIds, Map<String, Node> nodes) {
  double minX = double.infinity;
  double minY = double.infinity;

  for (final rootId in rootIds) {
    final node = nodes[rootId];
    if (node != null) {
      final x = node.layout.x ?? 0;
      final y = node.layout.y ?? 0;
      minX = min(minX, x);
      minY = min(minY, y);
    }
  }

  return Offset(
    minX == double.infinity ? 0 : minX,
    minY == double.infinity ? 0 : minY,
  );
}
```

---

### 4. Paste Target Rules

Paste target determination must be **deterministic** (no `selection.first` on unordered Set).

#### Target Frame

```dart
String? determineTargetFrame(Set<DragTarget> selection, String? focusedFrameId) {
  // Priority 1: If exactly one node selected, use its frame
  final nodeTargets = selection.whereType<NodeTarget>().toList();
  if (nodeTargets.length == 1) {
    return nodeTargets.first.frameId;
  }

  // Priority 2: If exactly one frame selected, use it
  final frameTargets = selection.whereType<FrameTarget>().toList();
  if (frameTargets.length == 1) {
    return frameTargets.first.frameId;
  }

  // Priority 3: Use focused/current frame
  return focusedFrameId;
}
```

#### Target Parent

```dart
String? determineTargetParent(
  Set<DragTarget> selection,
  String targetFrameId,
  Map<String, Frame> frames,
) {
  // If exactly one node with valid patchTarget → paste INTO that node
  final nodeTargets = selection
      .whereType<NodeTarget>()
      .where((t) => t.patchTarget != null && t.frameId == targetFrameId)
      .toList();

  if (nodeTargets.length == 1) {
    return nodeTargets.first.patchTarget;
  }

  // Otherwise → paste into frame's root node
  return frames[targetFrameId]?.rootNodeId;
}
```

---

### 5. Paste Placement: Cursor vs In-Place

#### Cursor Position Tracking

Add to `CanvasState`:

```dart
class CanvasState {
  /// Last known pointer position in world coordinates
  Offset? _lastPointerWorld;

  void updatePointerPosition(Offset worldPosition) {
    _lastPointerWorld = worldPosition;
  }

  Offset? get lastPointerWorld => _lastPointerWorld;
}
```

Update on mouse move in canvas widget (likely already tracking for hit-testing).

#### Placement Calculation

```dart
Offset computePasteOffset({
  required ClipboardPayload payload,
  required Offset? cursorWorld,
  required Frame targetFrame,
  required bool isDuplicate,
}) {
  if (isDuplicate) {
    // Duplicate: fixed offset from original position
    return const Offset(16, 16);
  }

  if (cursorWorld != null) {
    // Cursor paste: translate so anchor lands at cursor
    final cursorFrameLocal = cursorWorld - targetFrame.canvas.position;
    return cursorFrameLocal - payload.anchor;
  }

  // Fallback: paste at original position (or viewport center)
  return Offset.zero;
}
```

#### Apply Translation to Pasted Nodes

```dart
List<Node> translateNodes(List<Node> nodes, List<String> rootIds, Offset delta) {
  final rootIdSet = rootIds.toSet();

  return nodes.map((node) {
    // Only translate root nodes (children are relative to parents)
    if (!rootIdSet.contains(node.id)) return node;

    final layout = node.layout;
    return node.copyWith(
      layout: layout.copyWith(
        x: (layout.x ?? 0) + delta.dx,
        y: (layout.y ?? 0) + delta.dy,
      ),
    );
  }).toList();
}
```

---

### 6. ID Remapping

Remap `id`, `childIds`, and **any other node ID references**:

```dart
class NodeRemapper {
  final Map<String, String> _idMap = {};
  int _counter = 0;

  String _generateId() =>
      'paste_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// Remap all nodes with fresh IDs
  List<Node> remapNodes(List<Node> nodes) {
    // Phase 1: Generate new IDs for all nodes
    for (final node in nodes) {
      _idMap[node.id] = _generateId();
    }

    // Phase 2: Remap references
    return nodes.map(_remapNode).toList();
  }

  Node _remapNode(Node node) {
    return node.copyWith(
      id: _idMap[node.id]!,
      childIds: node.childIds.map((id) => _idMap[id] ?? id).toList(),
      // TODO: Also remap any node ID references in:
      // - props (component instance refs?)
      // - layout (constraints referencing other nodes?)
      // - style (if any node-relative values exist)
    );
  }

  /// Get remapped root IDs
  List<String> remapRootIds(List<String> oldRootIds) {
    return oldRootIds.map((id) => _idMap[id]!).toList();
  }
}
```

**Important:** Audit `NodeProps`, `NodeLayout`, and `NodeStyle` for any fields that contain node IDs. Common culprits:
- Component instance `targetComponentId`
- Constraint anchors (`constrainTo: "node_xyz"`)
- Bindings/links between nodes

---

### 7. Atomic Patch Application

All paste operations should be a single undo entry:

```dart
void executePaste({
  required List<Node> nodes,
  required List<String> rootIds,
  required String targetParentId,
}) {
  final patches = <PatchOp>[];

  // 1. Insert all nodes (order doesn't matter for flat map)
  for (final node in nodes) {
    patches.add(InsertNode(node));
  }

  // 2. Attach roots to target parent
  for (final rootId in rootIds) {
    patches.add(AttachChild(
      parentId: targetParentId,
      childId: rootId,
      index: -1, // Append
    ));
  }

  // 3. Apply atomically
  store.applyPatches(patches, label: 'Paste');
}
```

---

### 8. Cut and Duplicate

#### Cut (`Cmd+X`)

```dart
Future<void> cut() async {
  // 1. Build payload from current selection
  final payload = buildClipboardPayload();
  if (payload == null) return;

  // 2. Copy to both clipboards
  await clipboardService.copy(payload);

  // 3. Delete using existing delete path (respects top-level roots)
  deleteSelection();
}
```

#### Duplicate (`Cmd+D`)

```dart
void duplicate() {
  // 1. Build payload from current selection (sync, no clipboard read)
  final payload = buildClipboardPayload();
  if (payload == null) return;

  // 2. Immediately paste with offset (no async clipboard)
  final remapper = NodeRemapper();
  final newNodes = remapper.remapNodes(payload.nodes);
  final newRootIds = remapper.remapRootIds(payload.rootIds);

  // 3. Translate by fixed offset
  final translatedNodes = translateNodes(
    newNodes,
    newRootIds,
    const Offset(16, 16),
  );

  // 4. Paste into same parent as original selection
  final targetParentId = determineTargetParent(...);
  executePaste(
    nodes: translatedNodes,
    rootIds: newRootIds,
    targetParentId: targetParentId,
  );

  // 5. Select newly created nodes (nice UX)
  selectNodes(newRootIds);
}
```

**Key difference from paste:** Duplicate is fully synchronous—no clipboard read, no async.

---

### 9. Edge Cases and Guards

| Case | Handling |
|------|----------|
| Empty selection | No-op, silent |
| No valid patchTargets (all instance children) | Show toast: "Can't copy instance children" |
| Paste with empty/invalid clipboard | No-op, silent |
| Paste into instance child | Prevent (patchTarget is null on target) |
| Cross-frame paste | Works naturally (use target frame for local coords) |
| Paste creates cycle | Impossible (IDs are remapped, so no existing node refs) |

```dart
/// Check if selection contains any copyable nodes
bool canCopy(Set<DragTarget> selection) {
  return selection.any((target) => switch (target) {
    NodeTarget(:final patchTarget) => patchTarget != null,
    FrameTarget() => true,
  });
}

/// Check if we can paste into current selection
bool canPaste(Set<DragTarget> selection, Map<String, Frame> frames) {
  final targetParent = determineTargetParent(selection, ...);
  return targetParent != null;
}
```

---

## Implementation Structure

### Files to Create

```
lib/src/free_design/services/
├── clipboard_service.dart      # Dual clipboard management
└── clipboard_payload.dart      # Payload model + serialization

lib/src/free_design/services/clipboard/
├── node_remapper.dart          # ID remapping logic
└── selection_roots.dart        # Top-level root extraction
```

### Files to Modify

| File | Changes |
|------|---------|
| `canvas_state.dart` | Add `lastPointerWorld` tracking |
| `free_design_canvas.dart` | Add keyboard handlers, pointer tracking |
| `editor_document_store.dart` | Add `executePaste()` method |
| `node.dart` | Verify `copyWith()` exists |

---

## Keyboard Handler Integration

```dart
// In free_design_canvas.dart

KeyEventResult _handleKeyEvent(KeyEvent event) {
  if (event is! KeyDownEvent) return KeyEventResult.ignored;

  // ... existing focus check ...

  final isMeta = HardwareKeyboard.instance.isMetaPressed;
  final isControl = HardwareKeyboard.instance.isControlPressed;
  final isModifier = isMeta || isControl;

  // Copy: Cmd+C / Ctrl+C
  if (event.logicalKey == LogicalKeyboardKey.keyC && isModifier) {
    _copy();
    return KeyEventResult.handled;
  }

  // Paste: Cmd+V / Ctrl+V
  if (event.logicalKey == LogicalKeyboardKey.keyV && isModifier) {
    _paste();
    return KeyEventResult.handled;
  }

  // Cut: Cmd+X / Ctrl+X
  if (event.logicalKey == LogicalKeyboardKey.keyX && isModifier) {
    _cut();
    return KeyEventResult.handled;
  }

  // Duplicate: Cmd+D / Ctrl+D
  if (event.logicalKey == LogicalKeyboardKey.keyD && isModifier) {
    _duplicate();
    return KeyEventResult.handled;
  }

  // ... existing handlers ...
}

void _copy() {
  final payload = _buildClipboardPayload();
  if (payload == null) {
    // Maybe show "Nothing to copy" or check for instance children
    return;
  }
  _clipboardService.copy(payload);
}

Future<void> _paste() async {
  final payload = await _clipboardService.paste();
  if (payload == null) return;

  final targetFrameId = _determineTargetFrame();
  final targetParentId = _determineTargetParent(targetFrameId);
  if (targetParentId == null) return;

  final targetFrame = widget.state.document.frames[targetFrameId];
  if (targetFrame == null) return;

  final offset = _computePasteOffset(payload, targetFrame, isDuplicate: false);

  final remapper = NodeRemapper();
  final newNodes = remapper.remapNodes(payload.nodes);
  final newRootIds = remapper.remapRootIds(payload.rootIds);
  final translatedNodes = _translateNodes(newNodes, newRootIds, offset);

  widget.state.store.executePaste(
    nodes: translatedNodes,
    rootIds: newRootIds,
    targetParentId: targetParentId,
  );
}

void _cut() {
  final payload = _buildClipboardPayload();
  if (payload == null) return;

  _clipboardService.copy(payload);
  _deleteSelection();
}

void _duplicate() {
  final payload = _buildClipboardPayload();
  if (payload == null) return;

  // ... sync paste with offset, select new nodes ...
}
```

---

## Success Criteria Checklist

From NEXT_PRIORITIES.md:

- [ ] `Cmd+C` copies selected node(s) — with top-level root filtering
- [ ] `Cmd+V` pastes at cursor or into selection — with anchor-based positioning
- [ ] `Cmd+X` cuts — copy then delete
- [ ] `Cmd+D` duplicates with offset — sync, no clipboard read
- [ ] Pasted nodes get fresh IDs (no collisions) — full ID remapping
- [ ] Cross-frame copy works — frame-local coordinates
- [ ] Undo reverses paste — atomic patch group

---

## Summary of Key Corrections from Review

1. **Dual clipboard** — Internal for speed/reliability, system for interop
2. **Top-level roots only** — Filter out descendants already in selected subtrees
3. **Anchor-based positioning** — Bounding box top-left for deterministic placement
4. **Deterministic paste target** — Don't rely on `Set.first`
5. **Duplicate is sync** — No system clipboard round-trip
6. **Remap all ID references** — Not just `id` and `childIds`
7. **Frame-local coordinates** — Stable across cross-frame paste
