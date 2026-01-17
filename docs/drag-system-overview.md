# Drag & Drop System Overview

A comprehensive technical overview of the drag and drop system in distill_editor.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [File Structure](#file-structure)
3. [Core Components](#core-components)
   - [DragTarget](#dragtarget)
   - [DragSession](#dragsession)
   - [CanvasState](#canvasstate)
4. [Event Handling](#event-handling)
5. [Hit Testing](#hit-testing)
6. [Drop Target Detection](#drop-target-detection)
7. [Patch Generation](#patch-generation)
8. [Visual Feedback](#visual-feedback)
9. [Data Flow](#data-flow)
10. [Coordinate Systems](#coordinate-systems)

---

## Architecture Overview

The drag system follows a clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│                    FreeDesignCanvas                              │
│  (Event handling, coordinate transformation, gesture detection) │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       CanvasState                                │
│  (Orchestrator: selection, drag lifecycle, hit testing, caches) │
└─────────────────────────────┬───────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
       ┌────────────┐  ┌────────────┐  ┌────────────┐
       │ DragSession│  │ DragTarget │  │  PatchOp   │
       │ (ephemeral │  │ (what's    │  │ (document  │
       │  drag state)│  │  selected) │  │  changes)  │
       └────────────┘  └────────────┘  └────────────┘
```

**Key Principles:**
- `DragSession`: Ephemeral state during drag - no document access
- `CanvasState`: Central orchestrator managing document, selection, and drag lifecycle
- `FreeDesignCanvas`: Input handling and coordinate transformation
- Overlays: Stateless visual feedback components

---

## File Structure

### Core Drag/Drop Files

| File | Purpose |
|------|---------|
| `lib/src/free_design/canvas/drag_target.dart` | Target types (Frame, Node) |
| `lib/src/free_design/canvas/drag_session.dart` | Ephemeral drag state |
| `lib/modules/canvas/canvas_state.dart` | Central orchestrator |

### Canvas Widget & Event Handling

| File | Purpose |
|------|---------|
| `lib/src/free_design/canvas/widgets/free_design_canvas.dart` | Main canvas widget, event handling |
| `lib/src/free_design/canvas/widgets/frame_renderer.dart` | Frame rendering, bounds tracking |

### Visual Feedback Overlays

| File | Purpose |
|------|---------|
| `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart` | Blue insertion line |
| `lib/src/free_design/canvas/widgets/snap_guides_overlay.dart` | Smart snap guides |
| `lib/src/free_design/canvas/widgets/selection_overlay.dart` | Selection outlines, drop zones |
| `lib/src/free_design/canvas/widgets/marquee_overlay.dart` | Marquee selection rectangle |
| `lib/src/free_design/canvas/widgets/resize_handles.dart` | 8-point resize handles |

### Patch Operations

| File | Purpose |
|------|---------|
| `lib/src/free_design/patch/patch_op.dart` | Document change operations |

---

## Core Components

### DragTarget

**File:** `drag_target.dart`

Sealed class representing selectable/draggable targets on the canvas.

```dart
/// Sealed class representing selectable/draggable targets on the canvas.
sealed class DragTarget {
  const DragTarget();
}

/// A frame on the canvas, positioned in world coordinates.
class FrameTarget extends DragTarget {
  final String frameId;
  const FrameTarget(this.frameId);
}

/// A node within a frame.
class NodeTarget extends DragTarget {
  final String frameId;      // Containing frame ID
  final String expandedId;   // May include instance path (e.g., 'inst1::btn_label')
  final String? patchTarget; // Document node ID, or null if inside instance

  bool get canPatch => patchTarget != null;
}
```

**Key Points:**
- `FrameTarget`: Top-level containers positioned in world coordinates
- `NodeTarget`: Nodes positioned relative to parent
- `expandedId`: Namespaced ID for nodes inside component instances
- `patchTarget`: null for nodes inside instances (can't edit inside instances in v1)

---

### DragSession

**File:** `drag_session.dart`

Ephemeral state during a drag operation. Created when user starts dragging, destroyed on release.

#### DragMode Enum

```dart
enum DragMode {
  move,    // Moving selected objects (frames or nodes)
  resize,  // Resizing a selected frame
  marquee, // Drag-to-select multiple frames
}
```

#### ResizeHandle Enum

```dart
enum ResizeHandle {
  topLeft, topCenter, topRight,
  middleLeft, middleRight,
  bottomLeft, bottomCenter, bottomRight;

  bool get isLeft => ...;
  bool get isRight => ...;
  bool get isTop => ...;
  bool get isBottom => ...;
  bool get isHorizontalOnly => this == middleLeft || this == middleRight;
  bool get isVerticalOnly => this == topCenter || this == bottomCenter;
  Set<ResizeEdge> get activeEdges => ...; // For snap engine
}
```

#### DragSession Class

```dart
class DragSession {
  // Core properties
  final DragMode mode;
  final Set<DragTarget> targets;
  final Map<DragTarget, Offset> startPositions;  // Original positions
  final Map<DragTarget, Size> startSizes;        // Original sizes
  final ResizeHandle? handle;                    // For resize mode

  // Accumulator (raw user input)
  Offset accumulator;

  // Smart snap (separate from accumulator to avoid jank)
  Offset snapOffset;
  List<SnapGuide> activeGuides;

  // Drop target tracking (for node reparenting)
  String? dropTarget;       // Parent container ID
  int? insertionIndex;      // Position within parent
  String? dropFrameId;      // Frame containing drop target
  final Map<String, String> originalParents;  // For reparenting detection

  // Sibling animation
  Map<String, Offset> reflowOffsets;  // node ID → offset

  // Marquee
  final Offset? marqueeStart;

  // Computed properties
  Offset get effectiveOffset => accumulator + snapOffset;

  // Factory constructors
  factory DragSession.move({...});
  factory DragSession.resize({...});
  factory DragSession.marquee({...});

  // Methods
  Rect? getCurrentBounds(DragTarget target);
  Rect? getMarqueeRect();
  List<PatchOp> generatePatches();
}
```

**Key Design Decisions:**
- `accumulator` vs `snapOffset`: Kept separate to preserve user input feel while snapping visually
- `originalParents`: Captured at drag start to detect reparenting
- `reflowOffsets`: Pre-calculated sibling animations for Figma-style feedback

---

### CanvasState

**File:** `canvas_state.dart`

Central orchestrator managing document, selection, and drag lifecycle.

#### Selection Management

```dart
void select(DragTarget target, {bool addToSelection = false});
void selectFrame(String frameId, {bool addToSelection = false});
void selectNode(String frameId, String expandedId, {bool addToSelection = false});
void deselect(DragTarget target);
void deselectAll();
void selectFramesInRect(Rect worldRect);  // Marquee selection
void setHovered(DragTarget? target);
```

#### Drag Lifecycle

```dart
// Start
void startDrag();                        // Move session for selection
void startResize(ResizeHandle handle);   // Resize session (single target)
void startMarquee(Offset worldPos);      // Marquee session

// Update
void updateDrag(Offset worldDelta, {double? gridSize, bool useSmartGuides, double zoom});
void updateResize(Offset worldDelta, {double? gridSize, bool useSmartGuides, double zoom});
void updateMarquee(Offset worldPos);

// End
void endDrag();      // Commit changes
void cancelDrag();   // Discard changes
void endMarquee();   // Apply marquee selection
```

#### Hit Testing

```dart
FrameTarget? hitTestFrame(Offset worldPos);
NodeTarget? hitTestNode(Offset worldPos, String frameId);
String? hitTestContainer(String frameId, Offset worldPos, {Set<String>? excludeNodeIds});
ResizeHandle? hitTestResizeHandle(Offset viewPos, ...);
```

#### Drop Target Helpers

```dart
bool canReparent(String nodeId, String targetParentId);
String? getParent(String nodeId);
String? adjustDropTargetForSiblings(String? dropTarget, Set<String> draggedNodeIds);
int calculateInsertionIndex(String frameId, String parentId, Offset worldCursorPos, {Set<String>? draggedNodeIds});
Map<String, Offset> calculateReflowOffsets(String frameId, String parentId, int insertionIndex, Size draggedNodeSize);
```

#### Coordinate Transformation

```dart
Offset frameLocalToParentLocal(Offset frameLocal, String parentId, String frameId);
```

---

## Event Handling

**File:** `free_design_canvas.dart`

Uses `Listener` pattern (not `GestureDetector`) to avoid ~300ms tap delay.

### Pointer Down

```dart
void _handlePointerDown(PointerDownEvent event) {
  // Hit testing priority:
  // 1. Frame label (screen-space) → select frame or detect double-tap
  // 2. Resize handle → don't change selection
  // 3. Node within frames → select node
  // 4. Empty space → deselect
}
```

### Drag Start

```dart
void _handleDragStart(CanvasDragStartDetails details) {
  // Priority:
  // 1. Frame label drag
  // 2. Resize handle → startResize()
  // 3. Dragging selected item → startDrag()
  // 4. Empty space → startMarquee()
}
```

### Drag Update

```dart
void _handleDragUpdate(CanvasDragUpdateDetails details) {
  // For move mode with nodes:
  // 1. Hit test for drop target (excluding dragged nodes)
  // 2. Adjust for sibling reordering
  // 3. Calculate insertion index
  // 4. Calculate reflow offsets
  // 5. Apply snap (grid or smart guides)
  // 6. Update drag session

  // Modifiers:
  // - Shift: Grid snap (10px)
  // - Cmd/Meta: Disable smart guides
}
```

### Double-Tap Detection

Manual detection (time < 300ms, distance < 10px):
- Frame label: zoom to fit frame
- Empty space: create new blank frame
- Frame: zoom to fit frame
- Node: zoom to fit node

---

## Hit Testing

### Frame Hit Test

```dart
FrameTarget? hitTestFrame(Offset worldPos) {
  // Uses QuadTree spatial index for O(log n) lookup
  // Returns topmost frame at position
}
```

### Node Hit Test

```dart
NodeTarget? hitTestNode(Offset worldPos, String frameId) {
  // 1. Convert world → frame-local coordinates
  // 2. Find all nodes containing point (by bounds)
  // 3. Return smallest by area (most specific)
  // 4. Includes root node in hit testing
}
```

### Container Hit Test (for drop targets)

```dart
String? hitTestContainer(String frameId, Offset worldPos, {Set<String>? excludeNodeIds}) {
  // 1. Find deepest container (box, row, column)
  // 2. Skip non-containers (text, image, icon)
  // 3. Skip excluded nodes (dragged nodes during reordering)
  // 4. Return frame's root node as fallback
}
```

### Resize Handle Hit Test

```dart
ResizeHandle? hitTestResizeHandle(Offset viewPos, ...) {
  // Only for single selection (frames only)
  // Tests all 8 handles in view/screen space
  // Returns closest handle within radius
}
```

---

## Drop Target Detection

When dragging nodes, the system determines where they will be dropped:

### 1. Find Container Under Cursor

```dart
var dropTarget = hitTestContainer(frameId, worldPos, excludeNodeIds: draggedNodeIds);
```

- Excludes dragged nodes so we can "see through" them
- Returns deepest container at cursor position

### 2. Adjust for Sibling Reordering

```dart
dropTarget = adjustDropTargetForSiblings(dropTarget, draggedNodeIds);
```

**Problem:** When cursor lands on a sibling container, `hitTestContainer` returns that sibling as the drop target. This would be interpreted as "drop INTO sibling" instead of "reorder WITHIN parent".

**Solution:** Check if drop target shares the same parent as dragged nodes. If so, use the parent instead.

```dart
String? adjustDropTargetForSiblings(String? dropTarget, Set<String> draggedNodeIds) {
  if (dropTarget == null) return null;

  final draggedParentId = getParent(draggedNodeIds.first);
  final dropTargetParentId = getParent(dropTarget);

  if (dropTargetParentId == draggedParentId) {
    // Sibling detected - use parent for reordering
    return draggedParentId;
  }

  return dropTarget;
}
```

### 3. Calculate Insertion Index

```dart
int calculateInsertionIndex(String frameId, String parentId, Offset worldCursorPos, {Set<String>? draggedNodeIds}) {
  // 1. If no auto-layout: append to end
  // 2. Convert world → frame-local → parent-local
  // 3. Filter out dragged nodes (avoid off-by-one)
  // 4. Compare cursor to child centers:
  //    - cursor < center → insert before this child
  //    - past all children → insert at end
}
```

### 4. Calculate Reflow Offsets

```dart
Map<String, Offset> calculateReflowOffsets(String frameId, String parentId, int insertionIndex, Size draggedNodeSize) {
  // Creates Figma-style animation where siblings shift to make room
  // 1. Get layout direction (horizontal/vertical)
  // 2. Calculate space needed: draggedNodeSize + gap
  // 3. Shift siblings at/after insertionIndex by that amount
}
```

---

## Patch Generation

### Move Mode - Same Parent (Absolute Position)

```dart
SetProp(
  id: patchTarget,
  path: '/layout/position',
  value: {'mode': 'absolute', 'x': newPos.dx, 'y': newPos.dy},
)
```

### Move Mode - Reparenting

```dart
// 1. Move node to new parent
MoveNode(id: patchTarget, newParentId: newParent, index: insertionIndex)

// 2. Transform position to new parent's local coordinates
SetProp(
  id: patchTarget,
  path: '/layout/position',
  value: {'mode': 'absolute', 'x': parentLocalPos.dx, 'y': parentLocalPos.dy},
)
```

### Move Mode - Reordering (Same Parent, Auto-Layout)

```dart
MoveNode(id: patchTarget, newParentId: originalParent, index: insertionIndex)
```

### Resize Mode - Frame

```dart
SetFrameProp(frameId, '/canvas/position', {'x': bounds.left, 'y': bounds.top})
SetFrameProp(frameId, '/canvas/size', {'width': bounds.width, 'height': bounds.height})
```

### Resize Mode - Node

```dart
SetProp(id, '/layout/position', {'mode': 'absolute', 'x': ..., 'y': ...})
SetProp(id, '/layout/size/width', bounds.width)
SetProp(id, '/layout/size/height', bounds.height)
```

---

## Visual Feedback

### Insertion Indicator Overlay

**File:** `insertion_indicator_overlay.dart`

Shows Figma-style blue line indicating where node will be inserted.

```dart
class InsertionIndicatorOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Only show during move drag with valid drop target
    if (session?.mode != DragMode.move ||
        session.dropTarget == null ||
        session.insertionIndex == null) {
      return const SizedBox.shrink();
    }

    final indicator = _calculateIndicatorBounds(...);
    return CustomPaint(painter: InsertionLinePainter(...));
  }
}

class InsertionLinePainter extends CustomPainter {
  void paint(Canvas canvas, Size size) {
    // Draw glow effect
    final glowPaint = Paint()
      ..color = Color(0xFF007AFF).withAlpha(0.3)
      ..strokeWidth = 8.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0);

    // Draw main line
    final linePaint = Paint()
      ..color = Color(0xFF007AFF)  // Figma blue
      ..strokeWidth = 3.0;

    // Draw line with circles at ends
    canvas.drawLine(start, end, glowPaint);
    canvas.drawLine(start, end, linePaint);
    canvas.drawCircle(start, 4, linePaint);
    canvas.drawCircle(end, 4, linePaint);
  }
}
```

### Selection Overlay

- Selection outlines (solid blue rectangles)
- Hover outlines (dashed blue rectangles)
- Drop zone highlight (green dashed during drag)
- Frame labels (name + dimensions)

### Marquee Overlay

Semi-transparent blue rectangle showing selection area during marquee drag.

### Snap Guides Overlay

Magenta guide lines during smart snap (from `SnapEngine`).

### Resize Handles

8-point handles around single selection:
- `kHandleSize = 8.0`
- `kHandleHitRadius = 12.0`
- Hidden during drag

---

## Data Flow

```
User Input (Pointer Down)
    │
    ▼
_handlePointerDown (Hit Testing Priority)
    ├─ Frame label? → selectFrame() or zoomToFit()
    ├─ Resize handle? → startResize()
    ├─ Selected item? → startDrag()
    └─ Empty? → startMarquee()

    │ (If drag starts)
    ▼

DragSession Created
    ├─ Captures: startPositions, startSizes, originalParents
    └─ mode: move | resize | marquee

User Drags (Pointer Move)
    │
    ▼
_handleDragUpdate (Continuous)
    │
    ├─ For MOVE with nodes:
    │  ├─ hitTestContainer() → find drop target
    │  ├─ adjustDropTargetForSiblings() → handle reordering
    │  ├─ calculateInsertionIndex() → find insert position
    │  ├─ calculateReflowOffsets() → sibling animation
    │  └─ Set session.dropTarget, insertionIndex, reflowOffsets
    │
    ├─ Smart guide snapping:
    │  ├─ Get original bounds (not preview)
    │  ├─ SnapEngine.calculate(proposed bounds)
    │  └─ session.snapOffset = snap adjustment
    │
    ├─ state.updateDrag()
    │  └─ session.accumulator += worldDelta
    │
    └─ Listeners notify (render overlays)
       ├─ InsertionIndicatorOverlay (blue line)
       ├─ SnapGuidesOverlay (magenta guides)
       ├─ SelectionOverlay (drop zone highlight)
       ├─ MarqueeOverlay (selection rectangle)
       ├─ FrameRenderer (reflow animation)
       └─ ResizeHandles (hidden during drag)

User Releases (Pointer Up)
    │
    ▼
_handleDragEnd
    ├─ If marquee: endMarquee() → selectFramesInRect()
    └─ If move/resize: endDrag()
       ├─ Generate patches via _generateMovePatches()
       ├─ Transform coordinates for reparenting
       └─ _store.applyPatches(patches)

    │
    ▼
Document Updated
    ├─ Store notifies listeners
    ├─ CanvasState invalidates caches
    └─ UI rebuilds with new layout
```

---

## Coordinate Systems

The system uses multiple coordinate spaces:

| System | Origin | Used For |
|--------|--------|----------|
| **World** | Canvas origin (0,0) | Frame positions, hit testing, smart guides |
| **View** | Screen top-left | UI rendering, handle positions |
| **Frame-local** | Frame top-left | Node positions within frame |
| **Parent-local** | Parent container top-left | Relative node positioning |

### Conversions

```dart
// View ↔ World
Offset worldPos = controller.viewToWorld(viewPos);
Offset viewPos = controller.worldToView(worldPos);

// World → Frame-local
Offset frameLocal = worldPos - frame.canvas.position;

// Frame-local → Parent-local
Offset parentLocal = frameLocalToParentLocal(frameLocal, parentId, frameId);
```

### Bounds Caching

Three-tier fallback system for node bounds:

1. **Measured bounds** (from `BoundsTracker` - most accurate)
2. **Compiled bounds** (from `RenderCompiler` for absolute/fixed nodes)
3. **Props fallback** (safety measure from node layout props)

---

## Key Patterns

### Snap Offset Separation

```dart
// Raw user input
session.accumulator += worldDelta;

// Snap adjustment calculated separately
session.snapOffset = snapEngine.calculate(...);

// Combined for rendering
Offset effectiveOffset = accumulator + snapOffset;
```

**Why?** Preserves user input feel while snapping visually. Avoids jank when entering/exiting snap zones.

### Original Parents Tracking

```dart
// Captured at drag start
for (final target in selection) {
  if (target is NodeTarget && target.patchTarget != null) {
    final parentId = _store.parentIndex[target.patchTarget];
    if (parentId != null) {
      originalParents[target.patchTarget] = parentId;
    }
  }
}

// Used at drag end to detect reparenting
if (newParent != originalParent) {
  // Generate MoveNode + position patches
} else {
  // Just update position
}
```

### Dragged Node Exclusion

When hit testing for drop targets, exclude dragged nodes:

```dart
final dropTarget = hitTestContainer(
  frameId,
  worldPos,
  excludeNodeIds: draggedNodeIds,  // "See through" dragged nodes
);
```

When calculating insertion index, exclude dragged nodes:

```dart
final index = calculateInsertionIndex(
  frameId,
  parentId,
  worldPos,
  draggedNodeIds: draggedNodeIds,  // Avoid off-by-one errors
);
```

---

## Tests

| File | Coverage |
|------|----------|
| `test/free_design/canvas/drag_session_test.dart` | DragSession creation, bounds calculation, patch generation |
| `test/free_design/canvas/drag_drop_test.dart` | Insertion index, coordinate transforms, sibling adjustment, move patches |
| `test/free_design/canvas/drag_target_test.dart` | Target equality, hash codes |

---

## Recent Fixes (Phase 1 & 2)

### Phase 1: Core Fixes
- `_generateMovePatches()`: Proper coordinate transformation for reparenting
- `calculateInsertionIndex()`: Exclude dragged nodes to avoid off-by-one
- Multi-select drop validation for all selected nodes

### Phase 2: Sibling Reordering
- `excludeNodeIds` in `hitTestContainer()`: Skip dragged nodes during hit testing
- `adjustDropTargetForSiblings()`: When drop target is a sibling, use parent instead

---

## Future Work (Phase 3)

- Apply reflow offsets during rendering (sibling animation preview)
- Animate insertion indicator appearance
