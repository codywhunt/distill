# Priority 2: Document & Frame Management - Architecture Report

## Executive Summary

This report provides architectural context for implementing Priority 2 (Document & Frame Management) in the Distill design tool. The codebase has **strong foundations** for this feature—complete JSON serialization exists but no file I/O, and frame/navigation infrastructure is mature.

**Key insight:** The data + commands already exist. This is a **wiring + thin service layer** task, not a model refactor.

---

## Feature Requirements Recap

From NEXT_PRIORITIES.md:
- [ ] Create new document (empty canvas)
- [ ] Save document to file (JSON serialization)
- [ ] Load document from file
- [ ] Frame list panel showing all frames
- [ ] Click frame in list → canvas pans to frame
- [ ] Double-click frame → edit name inline
- [ ] Delete frame with confirmation
- [ ] Create new empty frame at canvas position

---

## Guiding Principles

### 1. Keep ALL mutations going through PatchOps

Already get undo/redo, coalescing, parent index rebuild, selection sync "for free":

| Operation | Patch(es) |
|-----------|-----------|
| Rename frame | `SetFrameProp('/name')` |
| Delete frame | `RemoveFrame` + subtree cleanup |
| Create frame | `InsertNode` + `InsertFrame` |
| New document | Replace store's document via dedicated method |

### 2. Put file I/O behind a single `DocumentPersistenceService`

Do **not** let UI directly touch `file_picker`, JSON encoding, etc. Keep UI dumb.

### 3. Add a "DocumentController" layer (or extend store)

User-facing operations (`newDocument()`, `saveDocument()`, `loadDocument()`) live here. Also handles error toasts, version migration, "unsaved changes" prompt (later).

---

## 1. Document Model Architecture

### Core Data Structures

**EditorDocument** ([editor_document.dart](../lib/src/free_design/models/editor_document.dart))
```dart
class EditorDocument {
  final String irVersion;                    // "1.0"
  final String documentId;                   // Unique ID
  final Map<String, Frame> frames;           // All frames
  final Map<String, Node> nodes;             // All nodes
  final Map<String, ComponentDef> components;
  final ThemeDocument theme;
}
```

**Frame** ([frame.dart](../lib/src/free_design/models/frame.dart))
```dart
class Frame {
  final String id;
  final String name;
  final String rootNodeId;        // Root of node tree
  final CanvasPlacement canvas;   // Position + size
  final DateTime createdAt;
  final DateTime updatedAt;
}

class CanvasPlacement {
  final Offset position;
  final Size size;
  Rect get bounds => ...;
}
```

### Key Insight
- Frames and nodes are stored as **flat maps** (not nested)
- Each frame references a `rootNodeId` that anchors its node tree
- All models are **immutable** with `copyWith()` methods
- Document provides `withFrame()`, `withoutFrame()` for updates

---

## 2. Serialization Status

### ✅ Complete JSON Round-Trip

All models implement `toJson()` and `fromJson()`:

| Model | Serialization | Notes |
|-------|--------------|-------|
| EditorDocument | ✅ Complete | Handles nested maps |
| Frame | ✅ Complete | Includes CanvasPlacement |
| Node | ✅ Complete | All 7 node types |
| NodeLayout | ✅ Complete | Position, size, auto-layout |
| NodeStyle | ✅ Complete | Fill, stroke, shadow |
| ThemeDocument | ✅ Complete | Token schema |

**Test Coverage:** [editor_document_test.dart](../test/free_design/models/editor_document_test.dart)

### ❌ No File I/O

- No `path_provider` or `file_picker` in pubspec
- Only persistence: `shared_preferences` for workspace layout
- App initializes with hardcoded demo document

---

## 3. State Management

### Provider + ChangeNotifier Pattern

**EditorDocumentStore** ([editor_document_store.dart](../lib/src/free_design/store/editor_document_store.dart))
- Holds immutable `EditorDocument`
- Applies patches atomically
- Manages undo/redo (100 entries with coalescing)
- Maintains parent index for tree queries

**CanvasState** ([canvas_state.dart](../lib/modules/canvas/canvas_state.dart))
- Selection state (`Set<DragTarget>`)
- Spatial index for frame hit testing
- Render/bounds caching
- Provides `selectFrame()`, `selectedFrameIds`

### Current Initialization Flow

```
main.dart
  └─ WorkspaceRouter
       └─ _WorkspaceProvider
            └─ CanvasState.demo()
                 └─ createMinimalDemoFrames()  // Hardcoded demo
```

---

## 4. Canvas Navigation

### InfiniteCanvasController ([infinite_canvas_controller.dart](../../distill_canvas/lib/src/infinite_canvas_controller.dart))

Already supports everything needed for "pan to frame":

```dart
// Animate viewport to fit a rect
Future<void> animateToFit(
  Rect worldRect,
  {EdgeInsets padding, Duration duration, Curve curve}
)

// Center on a point
Future<void> animateToCenterOn(Offset worldPoint, {double? zoom})

// Coordinate conversion
Offset viewToWorld(Offset viewPoint)
Offset worldToView(Offset worldPoint)
```

### Existing Frame Navigation Pattern

From [selection_overlay.dart](../lib/src/free_design/canvas/widgets/selection_overlay.dart):
- Frame labels are always visible
- Double-click label → `animateToFit(frame.canvas.bounds)`
- Single-click → select frame

---

## 5. UI Architecture

### Workspace Layout

```
┌─────────────────────────────────────────────────────┐
│ SideNavigation │ LeftPanel │ Center │ RightPanel    │
│                │           │        │               │
│  Module icons  │ Layer     │ Canvas │ Properties    │
│                │ tree      │        │ panel         │
└─────────────────────────────────────────────────────┘
```

**Relevant Files:**
- [workspace_shell.dart](../lib/workspace/workspace_shell.dart) - Main layout
- [widget_tree_panel.dart](../lib/modules/canvas/widgets/widget_tree_panel.dart) - Layer tree (left panel)

### Layer Tree (Reference for Frame List)

The existing layer tree shows nodes in the "focus" frame:
- Hierarchical tree with expand/collapse
- Selection sync with canvas
- Hover sync with canvas
- Auto-scroll to selected items

**This is a good template for the Frame List panel.**

---

## 6. Patch System

Frame operations already exist in [patch_op.dart](../lib/src/free_design/patch/patch_op.dart):

```dart
class InsertFrame extends PatchOp { final Frame frame; }
class RemoveFrame extends PatchOp { final String frameId; }
class SetFrameProp extends PatchOp {
  final String frameId;
  final String path;      // '/name' or '/canvas/position'
  final dynamic value;
}
```

These integrate with undo/redo automatically.

---

## 7. Architecture: Persistence Layer

### File Structure
```
lib/src/free_design/persistence/
├── document_persistence_service.dart
└── document_migrations.dart  (optional but recommended)
```

### Document Wrapper Format

Wrap the document JSON to enable safe versioning:

```json
{
  "type": "distill_editor_document",
  "version": "1.0",
  "document": { ...existing toJson... }
}
```

This prevents accidentally loading random JSON without a clear error.

### DocumentPersistenceService

```dart
class DocumentPersistenceService {
  Future<void> save(EditorDocument doc);  // pick path → encode → write
  Future<EditorDocument> load();          // pick file → read → decode → migrate → return
  // Optional: remember "last path" for save-in-place
}
```

### Store API Additions

Add to `EditorDocumentStore`:

```dart
void replaceDocument(EditorDocument newDoc, {bool clearUndo = true});
bool get hasUnsavedChanges;  // optional, but needed soon
```

Loading a document must reset:
- Undo/redo stacks
- Selection state (delegate to CanvasState)
- Derived indexes/caches

---

## 8. Architecture: Frame Lifecycle (Critical Gotcha)

### The Problem

`RemoveFrame` deletes the frame record, but leaves the node subtree as orphans. This creates memory bloat and ghost nodes.

### Solution: Compound Delete

Introduce a helper that expands to multiple ops:

```dart
List<PatchOp> deleteFrameAndSubtree(String frameId, EditorDocument doc) {
  final frame = doc.frames[frameId];
  if (frame == null) return [];

  // 1. Find all nodes in subtree (using parent index)
  final subtreeIds = collectDescendants(frame.rootNodeId, doc);

  // 2. Emit RemoveNode ops bottom-up
  final patches = subtreeIds.reversed
      .map((id) => RemoveNode(id))
      .toList();

  // 3. Emit RemoveFrame
  patches.add(RemoveFrame(frameId));

  return patches;
}
```

Apply as one atomic patch batch so undo restores everything cleanly.

---

## 9. UI Plan: Frame List Panel

### Location: Tabbed Left Panel

Current left panel shows layer tree for focused frame.

**Change:** Make left panel tabbed: **Frames | Layers**
- Frames = list of all frames in document
- Layers = existing widget tree for selected frame
- Default to Frames when no frame selected
- Switch to Layers when a frame is selected

This matches Figma-ish tools without adding a new sidebar.

### Frame List Interactions

| Action | Behavior |
|--------|----------|
| Single click | `selectFrame(frameId)` + `animateToFit(frame.canvas.bounds)` |
| Double-click name | Inline edit (TextField), commit on Enter/blur → `SetFrameProp('/name')`, Escape cancels |
| Delete icon/context menu | Confirm dialog → `deleteFrameAndSubtree()` |

### Create Empty Frame

"+ Frame" button at top of Frames tab:

1. Get viewport center: `canvasController.viewToWorld(viewportCenter)`
2. Default size: 375×812 (or last-used)
3. Create root node: empty container sized to frame
4. Position frame: `centerWorld - size/2`
5. Apply as atomic batch: `InsertNode(root)` + `InsertFrame(frame)`

---

## 10. Menu / Shortcuts

Add to command surface (menu bar / command palette / toolbar):

| Command | Shortcut |
|---------|----------|
| New Document | Cmd+N |
| Save | Cmd+S |
| Open/Load | Cmd+O |
| New Frame | Cmd+Shift+N |
| Delete Frame | Backspace (when frame selected) |

Even without "unsaved changes" prompt, this makes the tool immediately usable for real projects.

---

## 8. Key Files Reference

### Models
- [editor_document.dart](../lib/src/free_design/models/editor_document.dart)
- [frame.dart](../lib/src/free_design/models/frame.dart)
- [node.dart](../lib/src/free_design/models/node.dart)

### State
- [editor_document_store.dart](../lib/src/free_design/store/editor_document_store.dart)
- [canvas_state.dart](../lib/modules/canvas/canvas_state.dart)

### Patches
- [patch_op.dart](../lib/src/free_design/patch/patch_op.dart)
- [patch_applier.dart](../lib/src/free_design/patch/patch_applier.dart)

### Navigation
- [infinite_canvas_controller.dart](../../distill_canvas/lib/src/infinite_canvas_controller.dart)

### UI
- [workspace_shell.dart](../lib/workspace/workspace_shell.dart)
- [widget_tree_panel.dart](../lib/modules/canvas/widgets/widget_tree_panel.dart)
- [selection_overlay.dart](../lib/src/free_design/canvas/widgets/selection_overlay.dart)

### Existing Persistence
- [workspace_layout_state.dart](../lib/workspace/workspace_layout_state.dart) - Pattern for SharedPreferences

---

## 11. Gaps Summary

| Requirement | Current State | Work Needed |
|-------------|---------------|-------------|
| New document | Demo only | `replaceDocument()` + UI |
| Save to file | Serialization exists | `DocumentPersistenceService` + file_picker |
| Load from file | Serialization exists | Load + migration + reset state |
| Frame list panel | None | Tabbed panel component |
| Pan to frame | `animateToFit` exists | Wire to list click |
| Rename frame | `SetFrameProp` exists | Inline edit UI |
| Delete frame | `RemoveFrame` exists | Subtree cleanup + confirm |
| Create empty frame | AI-only | Non-AI creation path |

---

## 12. Implementation Order (Optimized for "Real Projects" Fast)

1. **DocumentPersistenceService** + minimal save/load hooks
2. **`replaceDocument()`** store API + load resets selection/undo
3. **Frames panel (basic)**: list + click-to-navigate + selection sync
4. **New Frame** button (non-AI)
5. **Rename inline** (double click)
6. **Delete frame** with subtree cleanup + confirm dialog
7. (Optional but soon) **Dirty state + unsaved changes prompt**

---

## 13. What NOT to Do Yet

- Don't add autosave until basic manual save/load is stable
- Don't refactor the document model (it's already correct)
- Don't build complex file-history UI (recent files) until workflow is validated
