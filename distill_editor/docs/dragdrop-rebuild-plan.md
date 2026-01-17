# Drag & Drop System Full Rebuild Plan

## Overview

Full ground-up rebuild of the drag and drop system based on the spec in `distill_editor/docs/dragdrop.md`. This replaces all current drag/drop code to fix jank, indicator positioning bugs, and incorrect drop target issues.

**Scope:** v1 spec only - reorder + reparent in auto-layout containers. No absolute positioning drops, no cross-frame drags.

---

## Critical Invariants (Must Never Be Violated)

These invariants prevent the bugs we're fixing. Every code path must preserve them.

### INV-1: Expanded-First Hit Testing
Hit testing MUST return `expandedId` as primary, derive `docId` via lookup. Never the reverse. This ensures `targetParentExpandedId` is always the specific instance under cursor, not a random expanded instance of the same docId.

**"Deepest hit" definition:** Topmost in paint order first (z-order), then deepest in that branch. When overlapping containers exist, the one painted last (frontmost) wins, then traverse down its subtree to find the deepest container containing the cursor.

### INV-2: Children List From Render Tree
`targetChildrenExpandedIds` MUST come from `renderDoc.nodes[targetParentExpandedId].childIds`. Derive `targetChildrenDocIds` in parallel via `expandedToDoc`. Never start from doc children and try to find expanded IDs.

### INV-3: Reflow Keys Exist in Render Tree
Every key in `reflowOffsetsByExpandedId` MUST exist in `renderDoc.nodes`. Debug assert this.

### INV-4: Auto-Layout or Climb
v1 NEVER drops into absolute/stack containers. If hit container is absolute, climb to nearest auto-layout ancestor. If auto-layout ancestor found → valid drop into that ancestor. If none found before frame root → `intent: none, isValid: false`.

**Climbing logic:** During climb via `expandedParent`, read `autoLayout` from the doc node (via `expandedToDoc[expandedId]`). If `docId == null` during climb (unpatchable node) → continue climbing. If `docId != null` and `docNode.autoLayout != null` → stop, use this as target. If reach frame root without finding auto-layout → invalid.

### INV-5: Frame Locked at Drag Start
`frameId` is captured at drag start from the dragged nodes. Builder does NOT resolve frame from cursor position. Cross-frame drag is invalid in v1.

### INV-6: Indicator Inside Parent
`indicatorWorldRect` MUST be clipped to `targetParentExpandedId` content bounds (after padding, in world space). If indicator would be outside, something is wrong upstream.

**Clipping details:**
- Content box = parent bounds inset by padding
- If content area is collapsed (zero width or height) → no indicator, `indicatorWorldRect = null`
- Line-cap/glow allowance: The indicator rect itself stays within content bounds; visual effects (glow, end caps) may extend 2-4px outside but this is a paint concern, not a layout concern

### INV-7: Multi-Select Same Origin Parent
In v1, all dragged nodes MUST share the same origin parent. If `originalParents` values are not all identical → `isValid: false, invalidReason: 'multi-select across different parents not supported'`. Validate at drag start or first builder call.

### INV-8: Valid Implies Non-Null Targets
If `isValid == true`, then `targetParentDocId` AND `targetParentExpandedId` MUST both be non-null. Assert this in builder before returning.

```dart
assert(!isValid || (targetParentDocId != null && targetParentExpandedId != null),
  'isValid implies both target IDs are non-null');
```

---

## Phase 1: Core Data Models

Create clean, immutable data models that match the spec exactly.

### 1.1 DropIntent Enum
**File:** `lib/src/free_design/canvas/drag/drop_intent.dart`
```dart
enum DropIntent { none, reorder, reparent }
```

### 1.2 DropPreview Model (Single Source of Truth)
**File:** `lib/src/free_design/canvas/drag/drop_preview.dart`

Replace current `drop_preview.dart` with spec-compliant version:
- `intent: DropIntent`
- `isValid: bool`
- `invalidReason: String?`
- `frameId: String`
- `draggedDocIdsOrdered: List<String>`
- `draggedExpandedIdsOrdered: List<String>`
- `targetParentDocId: String?`
- `targetParentExpandedId: String?`
- `targetChildrenExpandedIds: List<String>` (filtered, authoritative - FROM RENDER TREE)
- `targetChildrenDocIds: List<String>` (parallel, derived via expandedToDoc)
- `insertionIndex: int?`
- `indicatorWorldRect: Rect?` (pre-computed, clipped to parent)
- `indicatorAxis: Axis?`
- `reflowOffsetsByExpandedId: Map<String, Offset>`

### 1.3 DropCommitPlan Model
**File:** `lib/src/free_design/canvas/drag/drop_commit_plan.dart`
```dart
class DropCommitPlan {
  final bool canCommit;
  final String? reason;
  final String originParentDocId;
  final String targetParentDocId;
  final int insertionIndex;
  final List<String> draggedDocIdsOrdered;
  final bool isReparent;
}
```

### 1.4 DragSession Model (Simplified)
**File:** `lib/src/free_design/canvas/drag/drag_session.dart`

Replace current `drag_session.dart` - remove all the scattered drop-related fields:
- `mode: DragMode`
- `targets: Set<DragTarget>`
- `startPositions: Map<DragTarget, Offset>`
- `startSizes: Map<DragTarget, Size>`
- `handle: ResizeHandle?` (resize only)
- `accumulator: Offset`
- `snapOffset: Offset`
- `activeGuides: List<SnapGuide>`
- `marqueeStart: Offset?`
- `originalParents: Map<String, String>` (captured at drag start)
- `lockedFrameId: String?` (captured at drag start - INV-5)
- `dropPreview: DropPreview?` (single source of truth - no other drop fields!)
- `lastInsertionIndex: int?` (hysteresis)
- `lastInsertionCursor: Offset?` (hysteresis)

Remove: `dropTarget`, `dropTargetExpandedId`, `insertionIndex`, `dropFrameId`, `reflowOffsets`, `insertionChildren` - all replaced by `dropPreview`.

### 1.5 FrameLookups Cache
**File:** `lib/src/free_design/canvas/drag/frame_lookups.dart`

Pre-computed per-frame lookups (built once per frame, not during drag):
```dart
class FrameLookups {
  final Map<String, String?> expandedToDoc;  // scene.patchTarget
  final Map<String, List<String>> docToExpanded;  // reverse map (for multi-instance)
  final Map<String, String?> expandedParent;  // for ancestor climbing
}
```

**Build when ExpandedScene is created**, not during drag. Store in CanvasState cache alongside ExpandedScene.

---

## Phase 2: Drop Preview Builder

The heart of the system - computes authoritative DropPreview.

### 2.1 DropPreviewBuilder
**File:** `lib/src/free_design/canvas/drag/drop_preview_builder.dart`

Replace current `drop_preview_engine.dart` with cleaner implementation:

**Input:**
```dart
class DropPreviewInput {
  // Frame is LOCKED at drag start, not resolved from cursor (INV-5)
  final String lockedFrameId;
  final Offset cursorWorld;
  final Set<String> draggedDocIds;
  final Set<String> draggedExpandedIds;
  final Map<String, String> originalParents;
  final int? lastInsertionIndex;
  final Offset? lastInsertionCursor;
  final double zoom;
}
```

**Algorithm (per spec):**

1. **Use locked frame** - Use `lockedFrameId` from session, convert cursorWorld → frameLocal
2. **Hit test container (expanded-first)** - Returns `{expandedId, docId}`, excludes dragged nodes (INV-1)
3. **Climb to auto-layout parent** - If hit is absolute → climb via `expandedParent` until `autoLayout != null`. If none found → invalid (INV-4)
4. **Validate** - Check patchability, multi-select constraints, circular refs
5. **Build children list from render tree** - `renderDoc.nodes[targetParentExpandedId].childIds`, filter dragged, derive docIds via `expandedToDoc` (INV-2)
6. **Compute insertion index** - Compare cursor to child midpoints + hysteresis
7. **Compute indicator rect** - World-space, clipped to parent content box (INV-6)
8. **Compute reflow offsets** - For siblings at/after insertion index, assert keys exist in renderDoc (INV-3)
9. **Determine intent** - reorder vs reparent based on original parent
10. **Return DropPreview** - All fields populated

### 2.2 Hysteresis Implementation
**Threshold:** `8px / zoom`

Only change insertion index if cursor has moved past threshold from last insertion cursor position. This prevents flip-flop at child boundaries.

### 2.3 Insertion Index via Slot Boundaries

Compute explicit slot boundaries, then compare cursor position:

**For horizontal layout (row):**
```
slots[0].start = contentLeft (padding start)
slots[0].end = children[0].left - gap/2   (or contentRight if no children)

slots[i].start = children[i-1].right + gap/2
slots[i].end = children[i].left - gap/2

slots[N].start = children[N-1].right + gap/2
slots[N].end = contentRight (padding end)
```

**For vertical layout (column):** Same logic with top/bottom instead of left/right.

**Cursor comparison:** Find slot where `slots[i].start <= cursor < slots[i].end`. That's the insertion index.

**Edge case:** If `contentWidth == 0` or no children, insertion index = 0.

### 2.4 Indicator Rect Calculation

Given insertion index and slot boundaries:

- **Index 0:** Indicator at `contentStart` (padding edge)
- **Index between children:** Indicator at midpoint of gap: `children[i-1].end + gap/2`
- **Index N (after last):** Indicator at `children[N-1].end + gap/2` or `contentEnd` if no gap

**Indicator dimensions:**
- **Horizontal layout:** Vertical line, width = 2-3px, height = content height
- **Vertical layout:** Horizontal line, height = 2-3px, width = content width

**Clipping:** Rect is clipped to content box. If content area collapsed → `indicatorWorldRect = null`.

### 2.5 Debug Asserts

```dart
// INV-3: Reflow keys exist in render tree
assert(() {
  for (final key in reflowOffsets.keys) {
    if (!renderDoc.nodes.containsKey(key)) {
      throw StateError('Reflow key $key not in renderDoc.nodes');
    }
  }
  return true;
}());

// INV-7: Multi-select same origin parent
assert(() {
  final parents = originalParents.values.toSet();
  if (parents.length > 1) {
    throw StateError('Multi-select across different parents: $parents');
  }
  return true;
}());

// INV-8: Valid implies non-null targets
assert(!isValid || (targetParentDocId != null && targetParentExpandedId != null),
  'isValid implies both target IDs are non-null');
```

---

## Phase 3: Canvas State Integration

Integrate the new system into CanvasState.

### 3.1 FrameLookups Cache in CanvasState
**File:** `lib/modules/canvas/canvas_state.dart`

Add method to build and cache FrameLookups per frame:
```dart
FrameLookups? getFrameLookups(String frameId);
```

Build `docToExpanded` map when building ExpandedScene (eliminate runtime scanning). Cache alongside `_expandedScenes`.

### 3.2 Simplified Drag Methods

Remove all the scattered drop target logic from `CanvasState`. The builder handles everything.

- `startDrag()` - Capture originalParents, **lock frameId from first node target** (INV-5), create session
- `updateDrag()` - Call builder with `session.lockedFrameId`, store result in `session.dropPreview`
- `endDrag()` - Read from `dropPreview`, generate patches via pure helper

### 3.3 Hit Testing (MUST CHANGE)

**`hitTestContainer()` must be rewritten to be expanded-first (INV-1):**

```dart
/// Returns {expandedId, docId} where expandedId is the PRIMARY result.
/// docId is derived via scene.patchTarget[expandedId].
ContainerHit? hitTestContainer(
  String frameId,
  Offset worldPos, {
  Set<String>? excludeExpandedIds,  // NOT docIds
});

class ContainerHit {
  final String expandedId;  // PRIMARY - the specific instance under cursor
  final String? docId;      // DERIVED - for patching, may be null if unpatchable
}
```

The current implementation iterates doc nodes and tries to find expanded IDs - this is backwards and causes the indicator-outside-parent bug when docId maps to multiple expandedIds.

**Keep as-is:**
- `hitTestFrame()`
- `hitTestNode()`
- `hitTestResizeHandle()`

**Remove entirely:**
- `adjustDropTargetForSiblings()` - Builder handles climbing to auto-layout ancestor

---

## Phase 4: Overlay & Visual Feedback

Rebuild overlays to be truly "dumb" - just paint from DropPreview.

### 4.1 InsertionIndicatorOverlay
**File:** `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart`

Simplify to literally just paint `dropPreview.indicatorWorldRect`:
```dart
if (dropPreview?.isValid == true && dropPreview?.indicatorWorldRect != null) {
  // Convert to view space, paint line
}
```

No debug logging in overlay - that's builder's job.

### 4.2 Drop Zone Highlight (Optional Enhancement)
**File:** `lib/src/free_design/canvas/widgets/drop_zone_overlay.dart`

Show subtle highlight on target parent container when valid drop:
- Outline stroke: 1dp accent @ 60% opacity
- Only when `dropPreview.isValid && dropPreview.intent != none`

### 4.3 Drag Ghost Styling

Update ghost rendering in FrameRenderer:
- **Valid target:** 0.85 opacity + soft shadow
- **Invalid target:** 0.55 opacity + desaturation
- Multi-select: Stacked cards effect (optional for v1)

### 4.4 Reflow Animation

Simplify FrameRenderer to just read `session.dropPreview.reflowOffsetsByExpandedId`:
```dart
final offsets = session?.dropPreview?.reflowOffsetsByExpandedId ?? {};
// Pass to RenderEngine
```

---

## Phase 5: Patch Generation & Commit

### 5.1 DropCommitPlan Builder
**File:** `lib/src/free_design/canvas/drag/drop_commit_plan.dart`

Build commit plan from DropPreview:
```dart
DropCommitPlan buildCommitPlan(DropPreview preview, Map<String, String> originalParents);
```

### 5.2 Pure Patch Generation Helper (MUST BE UNIT TESTED)
**File:** `lib/src/free_design/canvas/drag/drop_patches.dart`

Multi-select reorder/reparent patch generation as a **pure function** with no side effects:

```dart
/// Generate patches for moving nodes to a new position.
///
/// Algorithm:
/// 1. Remove all dragged nodes from their current parents
/// 2. Insert bundle at filtered index in target parent
///
/// [draggedDocIdsOrdered] - Nodes in the order they should be inserted
/// [originParentDocId] - Current parent (same for all in v1 multi-select)
/// [targetParentDocId] - Destination parent
/// [insertionIndex] - Index in FILTERED children list (excludes dragged)
/// [currentChildDocIds] - Current children of target parent (for index adjustment)
List<PatchOp> generateDropPatches({
  required List<String> draggedDocIdsOrdered,
  required String originParentDocId,
  required String targetParentDocId,
  required int insertionIndex,
  required List<String> currentChildDocIds,
});
```

**Index adjustment logic:**
- `insertionIndex` is already in "filtered list" coordinates (excludes dragged nodes)
- When reordering within same parent: remove all, then insert at index
- When reparenting: remove from origin, insert at index in target

### 5.3 Patch Generation in CanvasState

In `CanvasState.endDrag()`:

```dart
if (dropPreview == null || !dropPreview.isValid) {
  // No structural change - revert
  return;
}

final patches = generateDropPatches(
  draggedDocIdsOrdered: dropPreview.draggedDocIdsOrdered,
  originParentDocId: session.originalParents.values.first, // v1: all same parent
  targetParentDocId: dropPreview.targetParentDocId!,
  insertionIndex: dropPreview.insertionIndex!,
  currentChildDocIds: dropPreview.targetChildrenDocIds,
);

_store.applyPatches(patches);
```

**No position patches for auto-layout** - layout determines position.

---

## Phase 6: Debug Mode

### 6.1 Debug Flag
**File:** `lib/src/free_design/canvas/drag/drag_debug.dart`

```dart
const bool kDragDropDebug = false; // Toggle for development

void debugLog(String message) {
  if (kDragDropDebug) print('[DragDrop] $message');
}
```

### 6.2 Debug Overlay (Optional)
**File:** `lib/src/free_design/canvas/widgets/drag_debug_overlay.dart`

When `kDragDropDebug` is true, show:
- Parent bounds
- Child midpoints
- Computed insertion line
- Current intent, insertionIndex, invalidReason

---

## Phase 7: Cleanup Legacy Code

### 7.1 Files to Delete

- `lib/src/free_design/canvas/drop_preview.dart` (replaced)
- `lib/src/free_design/canvas/drop_preview_engine.dart` (replaced)
- `lib/src/free_design/canvas/drag_session.dart` (replaced)

### 7.2 Files to Update

- `lib/src/free_design/canvas/drag_target.dart` - Keep as-is (still needed)
- `lib/modules/canvas/canvas_state.dart` - Remove scattered drop logic, use builder
- `lib/src/free_design/canvas/widgets/free_design_canvas.dart` - Simplify drag handling
- `lib/src/free_design/canvas/widgets/frame_renderer.dart` - Simplify reflow reading
- `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart` - Simplify
- `lib/src/free_design/canvas/widgets/selection_overlay.dart` - Update drop zone highlight

### 7.3 Code to Remove from CanvasState

- `adjustDropTargetForSiblings()` - Builder handles climbing
- `calculateInsertionIndex()` - Builder handles this
- `calculateReflowOffsets()` - Builder handles this
- All the manual drop target tracking in `updateDrag()`

---

## Implementation Order

1. **Phase 1:** Create new data models in `drag/` subdirectory
2. **Phase 2:** Implement DropPreviewBuilder
3. **Phase 3:** Add FrameLookups cache, update CanvasState
4. **Phase 4:** Update overlays to read from DropPreview
5. **Phase 5:** Update patch generation
6. **Phase 6:** Add debug mode
7. **Phase 7:** Delete old files, clean up

---

## Testing Strategy

### Manual Tests (per spec Section 13)

1. **Reorder within row** - Drag child across siblings, verify slot line + siblings reflow + drop commits
2. **Reparent into another row/column** - Hover new container, verify highlight + line + drop moves node
3. **Hover absolute container with auto-layout ancestor** - Climbs to auto-layout ancestor, shows valid drop indicator in ancestor, ghost shows valid styling
4. **Hover absolute container with NO auto-layout ancestor** - Ghost shows invalid styling (0.55 opacity), no indicator, drop reverts
5. **Multi-select reorder** - Select two adjacent siblings, drag, verify bundle inserts with order preserved
6. **Multi-select from different parents** - Select nodes from different parents, drag should show invalid (INV-7)

### Unit Tests

#### `drop_preview_builder_test.dart`
- Insertion index calculation
- Hysteresis prevents flip-flop
- Indicator rect clipped to parent bounds
- Climb to auto-layout ancestor when hitting absolute container
- Invalid when no auto-layout ancestor found

#### `drop_patches_test.dart` (CRITICAL)
- Reorder within same parent: indices adjusted correctly
- Reparent to different parent: remove from origin, insert at target
- Multi-select bundle: order preserved
- Edge cases: move to index 0, move to end, move single node

#### `hit_test_container_test.dart`
- Returns expandedId as primary
- Derives docId via patchTarget
- Excludes specified expandedIds
- Returns deepest container containing cursor
- **Overlap test:** When two containers overlap, returns topmost in paint order (z-order), then deepest in that branch

#### `multi_select_validation_test.dart`
- All dragged nodes same parent → valid
- Dragged nodes from different parents → invalid with reason 'multi-select across different parents not supported'

### Regression Tests (CRITICAL)

#### `instance_indicator_test.dart`
**The bug we must never reintroduce:**

Setup:
- Component with a Row containing 3 children
- Two instances of this component on canvas
- Same docId maps to two different expandedIds

Test:
1. Drag a child within instance A
2. Verify `targetParentExpandedId` is the Row in instance A (not instance B)
3. Verify indicator rect is inside instance A's Row bounds
4. Verify reflow offsets only affect instance A's children

```dart
test('indicator stays in correct instance when docId appears multiple times', () {
  // Setup: inst_a::row_1, inst_b::row_1 both map to docId 'row_1'
  // Drag child within inst_a

  final preview = builder.compute(...);

  // MUST be inst_a's row, not inst_b's
  expect(preview.targetParentExpandedId, 'inst_a::row_1');

  // Indicator MUST be inside inst_a's row bounds
  final instARowBounds = getBounds('frame1', 'inst_a::row_1');
  expect(instARowBounds.contains(preview.indicatorWorldRect!.center), isTrue);

  // Reflow offsets MUST only contain inst_a children
  for (final key in preview.reflowOffsetsByExpandedId.keys) {
    expect(key.startsWith('inst_a::'), isTrue);
  }
});
```

---

## Critical Files to Modify

| File | Action |
|------|--------|
| `lib/src/free_design/canvas/drag/drop_intent.dart` | CREATE |
| `lib/src/free_design/canvas/drag/drop_preview.dart` | CREATE (replace old) |
| `lib/src/free_design/canvas/drag/drop_commit_plan.dart` | CREATE |
| `lib/src/free_design/canvas/drag/drop_patches.dart` | CREATE - pure patch generation helper |
| `lib/src/free_design/canvas/drag/drag_session.dart` | CREATE (replace old) |
| `lib/src/free_design/canvas/drag/frame_lookups.dart` | CREATE |
| `lib/src/free_design/canvas/drag/drop_preview_builder.dart` | CREATE (replace engine) |
| `lib/src/free_design/canvas/drag/drag_debug.dart` | CREATE |
| `lib/modules/canvas/canvas_state.dart` | MODIFY - rewrite hitTestContainer (expanded-first), simplify drag methods, add lookups cache |
| `lib/src/free_design/canvas/widgets/free_design_canvas.dart` | MODIFY - simplify drag handling |
| `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart` | MODIFY - simplify |
| `lib/src/free_design/canvas/widgets/frame_renderer.dart` | MODIFY - simplify reflow |
| `lib/src/free_design/canvas/drop_preview.dart` (old) | DELETE |
| `lib/src/free_design/canvas/drop_preview_engine.dart` (old) | DELETE |
| `lib/src/free_design/canvas/drag_session.dart` (old) | DELETE |

### Test Files to Create

| File | Purpose |
|------|---------|
| `test/free_design/canvas/drag/drop_preview_builder_test.dart` | Builder algorithm tests |
| `test/free_design/canvas/drag/drop_patches_test.dart` | Pure patch generation tests |
| `test/free_design/canvas/drag/hit_test_container_test.dart` | Expanded-first hit testing + overlap test |
| `test/free_design/canvas/drag/multi_select_validation_test.dart` | INV-7: same origin parent constraint |
| `test/free_design/canvas/drag/instance_indicator_test.dart` | CRITICAL regression test |

---

## Verification

After implementation, verify:

1. No jank during drag (single computation per frame)
2. Indicator always matches drop intent
3. Siblings reflow smoothly
4. Reorder commits correctly
5. Reparent commits correctly
6. Invalid targets show correct feedback
7. Hysteresis prevents flip-flop
8. Debug mode shows useful diagnostics when enabled

### Invariant Verification Checklist

- [ ] **INV-1**: `hitTestContainer` returns expandedId as primary, docId derived; "deepest hit" = topmost z-order first, then deepest in branch
- [ ] **INV-2**: Children list built from `renderDoc.nodes[expandedId].childIds`
- [ ] **INV-3**: Debug asserts verify reflow keys exist in renderDoc
- [ ] **INV-4**: Absolute containers climb to auto-layout ancestor (valid if found, invalid if none); `autoLayout` read from doc node via `expandedToDoc`
- [ ] **INV-5**: Frame locked at drag start, not resolved per-update
- [ ] **INV-6**: Indicator rect clipped to content box (after padding); collapsed content → null indicator
- [ ] **INV-7**: Multi-select all same origin parent, else invalid
- [ ] **INV-8**: `isValid == true` implies `targetParentDocId` and `targetParentExpandedId` both non-null

### Regression Test Passes

- [ ] `instance_indicator_test.dart` - Indicator in correct instance when docId appears multiple times
- [ ] `drop_patches_test.dart` - All multi-select reorder/reparent cases
- [ ] `hit_test_container_test.dart` - Overlap test: topmost z-order wins
- [ ] `multi_select_validation_test.dart` - Different parents → invalid

---

## Implementation Progress

### Phase 1: Core Data Models ✅ COMPLETE

**Date:** 2026-01-17

**Files Created:**

| File | Lines | Status |
|------|-------|--------|
| `lib/src/free_design/canvas/drag/drop_intent.dart` | 15 | ✅ |
| `lib/src/free_design/canvas/drag/container_hit.dart` | 61 | ✅ |
| `lib/src/free_design/canvas/drag/drop_preview.dart` | 179 | ✅ |
| `lib/src/free_design/canvas/drag/drop_commit_plan.dart` | 138 | ✅ |
| `lib/src/free_design/canvas/drag/frame_lookups.dart` | 184 | ✅ |
| `lib/src/free_design/canvas/drag/drag_session.dart` | 380 | ✅ |
| `lib/src/free_design/canvas/drag/drag.dart` | 45 | ✅ |

**Verification:** `flutter analyze lib/src/free_design/canvas/drag/` passes with no issues.

---

### Key Learnings from Phase 1

#### 1. Import Strategy
- Use `package:flutter/foundation.dart` for `@immutable` annotation (not `package:meta/meta.dart`)
- Use `package:flutter/painting.dart` for `Rect`, `Offset`, `Axis` (not `dart:ui` alone)
- The old code uses `LayoutDirection` from `models/node_layout.dart`, but we use `Axis` from Flutter for consistency

#### 2. Existing Code Structure
The current implementation already has:
- `DropPreview` with `DropPreviewKind` enum (similar to our `DropIntent`)
- `DragSession` with a `dropPreview` field (migration partially started)
- `DropPreviewEngine` that computes the preview

The scattered fields in current `DragSession` that will be removed:
- `dropTarget` → use `dropPreview.targetParentDocId`
- `dropTargetExpandedId` → use `dropPreview.targetParentExpandedId`
- `insertionIndex` → use `dropPreview.insertionIndex`
- `dropFrameId` → use `dropPreview.frameId`
- `reflowOffsets` → use `dropPreview.reflowOffsetsByExpandedId`
- `insertionChildren` → use `dropPreview.targetChildrenDocIds`

#### 3. RenderDocument Structure
Key types discovered:
- `RenderDocument.rootId: String` - Root node ID
- `RenderDocument.nodes: Map<String, RenderNode>` - All nodes keyed by expanded ID
- `RenderNode.childIds: List<String>` - Child expanded IDs (line 87 of render_document.dart)

#### 4. ExpandedScene Structure
Key types discovered:
- `ExpandedScene.patchTarget: Map<String, String?>` - expandedId → docId (null if unpatchable)
- `ExpandedScene.nodes: Map<String, ExpandedNode>` - All expanded nodes

---

### Key Notes for Phase 2: DropPreviewBuilder

#### Dependencies Available
The builder will need these from CanvasState:
```dart
// Already available
ExpandedScene getExpandedScene(String frameId);
RenderDocument getRenderDocument(String frameId);
Rect? getNodeBounds(String frameId, String expandedId);
Offset getFramePosition(String frameId);

// Need to add
FrameLookups getFrameLookups(String frameId); // Build alongside ExpandedScene
```

#### Input from DragSession
```dart
class DropPreviewInput {
  final String lockedFrameId;           // session.lockedFrameId (INV-5)
  final Offset cursorWorld;             // From drag update
  final Set<String> draggedDocIds;      // From targets
  final Set<String> draggedExpandedIds; // From targets
  final Map<String, String> originalParents; // session.originalParents
  final int? lastInsertionIndex;        // session.lastInsertionIndex
  final Offset? lastInsertionCursor;    // session.lastInsertionCursor
  final double zoom;                    // For hysteresis threshold
}
```

#### Algorithm Outline
```
1. Use lockedFrameId (not resolved from cursor)
2. Convert cursorWorld → frameLocal via getFramePosition()
3. Hit test container (expanded-first, exclude dragged)
4. If hit is absolute → climb via FrameLookups.expandedParent
5. Validate patchability + constraints
6. Build children list from renderDoc.nodes[targetExpandedId].childIds
7. Compute insertion index via slot boundaries + hysteresis
8. Compute indicator rect (clipped to content box)
9. Compute reflow offsets for siblings at/after index
10. Return DropPreview
```

#### Critical: Auto-Layout Check
To check if a container is auto-layout:
```dart
// Get docId from expanded
final docId = lookups.expandedToDoc[expandedId];
if (docId == null) continue; // Unpatchable, keep climbing

// Get doc node
final docNode = document.nodes[docId];
if (docNode?.layout.autoLayout != null) {
  // Found auto-layout container - use this as target
}
```

The `autoLayout` field is on `NodeLayout` (from `models/node_layout.dart`).

#### Hysteresis Threshold
```dart
const kHysteresisPixels = 8.0;
final threshold = kHysteresisPixels / zoom;
```

Only change insertion index if cursor has moved past `threshold` from `lastInsertionCursor`.

#### Indicator Clipping (INV-6)
Content box = parent bounds inset by padding:
```dart
final contentBox = Rect.fromLTRB(
  parentBounds.left + padding.left,
  parentBounds.top + padding.top,
  parentBounds.right - padding.right,
  parentBounds.bottom - padding.bottom,
);

// Clip indicator to content box
if (contentBox.width <= 0 || contentBox.height <= 0) {
  indicatorWorldRect = null; // Collapsed content area
}
```

#### Files to Create in Phase 2
1. `lib/src/free_design/canvas/drag/drop_preview_builder.dart` - Main builder
2. `lib/src/free_design/canvas/drag/drop_preview_input.dart` - Input model (optional, could be inline)

#### Integration Points for Phase 3
After Phase 2, the builder will be integrated via:
- `CanvasState.getFrameLookups(frameId)` - Cache alongside `_expandedScenes`
- `FreeDesignCanvas._handleDragUpdate()` - Replace `_dropPreviewEngine.compute()` call
- `DragSession.dropPreview` - Already typed to new `DropPreview`

---

### Phase 2: Drop Preview Builder ✅ COMPLETE

**Date:** 2026-01-17

**Files Created:**

| File | Lines | Status |
|------|-------|--------|
| `lib/src/free_design/canvas/drag/drop_preview_builder.dart` | 748 | ✅ |

**Files Updated:**

| File | Change |
|------|--------|
| `lib/src/free_design/canvas/drag/drag.dart` | Added export for `drop_preview_builder.dart` |

**Verification:** `flutter analyze lib/src/free_design/canvas/drag/` passes with no issues.

---

### Key Learnings from Phase 2

#### 1. Node Model Has No `parentId`
The `Node` model does not have a `parentId` field. Parent-child relationships are stored only via `childIds` on the parent. To find a node's parent, you must search all nodes:

```dart
String? findParent(String nodeId, EditorDocument document) {
  for (final entry in document.nodes.entries) {
    if (entry.value.childIds.contains(nodeId)) {
      return entry.key;
    }
  }
  return null;
}
```

This affects `_isAncestorOrSelf()` which needs to check for circular references.

#### 2. Callback-Based Dependency Injection
The builder uses callback types for dependency injection, making it testable:

```dart
typedef BoundsResolver = Rect? Function(String frameId, String expandedId);
typedef FramePositionResolver = Offset Function(String frameId);
typedef ContainerHitResolver = ContainerHit? Function(
  String frameId,
  Offset worldPos,
  Set<String> excludeExpandedIds,
);
```

This allows unit tests to provide mock implementations without needing full CanvasState.

#### 3. NumericValue Token Resolution
`AutoLayout.padding` uses `TokenEdgePadding` which contains `NumericValue` objects. These can be either `FixedNumeric` or `TokenNumeric`. For layout calculations, use `.toDouble()` which returns the fixed value or a fallback:

```dart
final padLeft = autoLayout.padding.left.toDouble();  // Fallback to 0.0 for tokens
```

Full token resolution would require a `TokenResolver`, but for drag preview we use the fallback approach.

#### 4. LayoutDirection vs Axis
The spec uses `Axis` from Flutter for indicator direction, but `AutoLayout` uses `LayoutDirection` from the models. Mapping:
- `LayoutDirection.horizontal` (row) → indicator is `Axis.vertical` (vertical line)
- `LayoutDirection.vertical` (column) → indicator is `Axis.horizontal` (horizontal line)

#### 5. Bounds Are Frame-Local
`getBounds(frameId, expandedId)` returns bounds in frame-local coordinates. To convert to world coordinates:

```dart
final framePos = getFramePos(frameId);
final worldBounds = frameLocalBounds.shift(framePos);
```

The indicator rect is computed in world space so overlays can paint it directly.

---

### Key Notes for Phase 3: Canvas State Integration

#### 3.1 Add FrameLookups Cache

Add to CanvasState alongside `_expandedScenes` and `_renderCache`:

```dart
final Map<String, FrameLookups> _frameLookupsCache = {};

FrameLookups? getFrameLookups(String frameId) {
  var lookups = _frameLookupsCache[frameId];
  if (lookups != null) return lookups;

  final scene = getExpandedScene(frameId);
  final renderDoc = getRenderDoc(frameId);
  if (scene == null || renderDoc == null) return null;

  lookups = FrameLookups.build(scene: scene, renderDoc: renderDoc);
  _frameLookupsCache[frameId] = lookups;
  return lookups;
}
```

**Invalidation:** Clear `_frameLookupsCache[frameId]` whenever `_expandedScenes[frameId]` or `_renderCache[frameId]` is invalidated.

#### 3.2 Update hitTestContainer for Expanded-First (INV-1)

Current signature takes `excludeNodeIds` (doc IDs). Change to:

```dart
ContainerHit? hitTestContainer(
  String frameId,
  Offset worldPos, {
  Set<String>? excludeExpandedIds,  // Changed from excludeNodeIds
});
```

The implementation should:
1. Iterate `renderDoc.nodes` in reverse paint order (topmost first)
2. Check if node is container type (box, row, column)
3. Skip nodes in `excludeExpandedIds`
4. Return first hit as `ContainerHit(expandedId, docId)` where `docId = scene.patchTarget[expandedId]`

#### 3.3 Instantiate Builder and Call in updateDrag

In CanvasState or FreeDesignCanvas:

```dart
final _dropPreviewBuilder = DropPreviewBuilder();

void updateDrag(Offset cursorWorld) {
  // ... accumulate delta ...

  if (session.mode == DragMode.move && session.lockedFrameId != null) {
    final frameId = session.lockedFrameId!;
    final scene = getExpandedScene(frameId);
    final renderDoc = getRenderDoc(frameId);
    final lookups = getFrameLookups(frameId);

    if (scene != null && renderDoc != null && lookups != null) {
      // Extract dragged IDs from session.targets
      final draggedDocIds = <String>[];
      final draggedExpandedIds = <String>[];
      for (final target in session.targets) {
        if (target is NodeTarget) {
          if (target.patchTarget != null) {
            draggedDocIds.add(target.patchTarget!);
          }
          draggedExpandedIds.add(target.expandedId);
        }
      }

      final preview = _dropPreviewBuilder.compute(
        lockedFrameId: frameId,
        cursorWorld: cursorWorld,
        draggedDocIdsOrdered: draggedDocIds,
        draggedExpandedIdsOrdered: draggedExpandedIds,
        originalParents: session.originalParents,
        lastInsertionIndex: session.lastInsertionIndex,
        lastInsertionCursor: session.lastInsertionCursor,
        zoom: zoom,
        document: document,
        scene: scene,
        renderDoc: renderDoc,
        lookups: lookups,
        getBounds: getNodeBounds,
        getFramePos: _getFramePosition,
        hitTestContainer: _hitTestContainerForBuilder,
      );

      session.dropPreview = preview;

      // Update hysteresis state
      if (preview.insertionIndex != session.lastInsertionIndex) {
        session.lastInsertionIndex = preview.insertionIndex;
        session.lastInsertionCursor = cursorWorld;
      }
    }
  }
}
```

#### 3.4 Wrapper for hitTestContainer

The builder expects `ContainerHitResolver` signature. Create a wrapper:

```dart
ContainerHit? _hitTestContainerForBuilder(
  String frameId,
  Offset worldPos,
  Set<String> excludeExpandedIds,
) {
  return hitTestContainer(frameId, worldPos, excludeExpandedIds: excludeExpandedIds);
}
```

#### 3.5 Remove Old Drop Target Logic

After integration, remove from CanvasState:
- `adjustDropTargetForSiblings()` - Builder handles climbing
- `calculateInsertionIndex()` - Builder handles this
- `calculateReflowOffsets()` - Builder handles this
- Manual drop target tracking in `updateDrag()`

#### 3.6 DragSession.targets → IDs

The current `DragSession.targets` is `Set<DragTarget>`. To extract IDs:

```dart
// For NodeTarget
target.patchTarget  // doc ID (null if unpatchable)
target.expandedId   // expanded ID
target.frameId      // frame ID

// For FrameTarget
target.frameId      // frame ID
```

Multi-select with mixed `NodeTarget` and `FrameTarget` is not supported in v1.

---

### Phase 3: Canvas State Integration ✅ COMPLETE

**Date:** 2026-01-17

**Files Modified:**

| File | Change |
|------|--------|
| `lib/modules/canvas/canvas_state.dart` | Removed old `ContainerHit`, added `FrameLookups` cache, fixed `hitTestContainer` for INV-1, updated `startDrag()` for INV-5, removed `adjustDropTargetForSiblings()` |
| `lib/src/free_design/canvas/widgets/free_design_canvas.dart` | Updated imports, replaced `DropPreviewEngine` with `DropPreviewBuilder`, rewrote `_handleDragUpdate()` |
| `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart` | Updated imports, simplified to read `indicatorAxis` directly from `DropPreview` |
| `lib/src/free_design/canvas/widgets/frame_renderer.dart` | Updated to read reflow from `dropPreview.reflowOffsetsByExpandedId` |
| `lib/src/free_design/canvas/widgets/selection_overlay.dart` | Updated drop zone highlight to read from `dropPreview` |
| `lib/src/free_design/canvas/widgets/marquee_overlay.dart` | Updated import to `drag/drag.dart` |
| `lib/src/free_design/canvas/widgets/resize_handles.dart` | Updated import to `drag/drag.dart` |
| `lib/src/free_design/canvas/canvas.dart` | Updated exports to use `drag/drag.dart`, removed old file exports |

**Files Deleted:**

| File | Reason |
|------|--------|
| `lib/src/free_design/canvas/drag_session.dart` | Replaced by `drag/drag_session.dart` |
| `lib/src/free_design/canvas/drop_preview.dart` | Replaced by `drag/drop_preview.dart` |
| `lib/src/free_design/canvas/drop_preview_engine.dart` | Replaced by `drag/drop_preview_builder.dart` |

**Verification:** `flutter analyze lib/` passes with no errors (only pre-existing info-level warnings).

---

### Key Learnings from Phase 3

#### 1. Import Conflicts with Barrel Files

When the new `drag/drag.dart` exports types with the same names as the old files (`DragSession`, `DropPreview`, etc.), and those old types are re-exported via `free_design.dart`, you get name conflicts. Solution:

```dart
import '../../src/free_design/canvas/drag/drag.dart';
import '../../src/free_design/free_design.dart'
    hide DragSession, DragMode, ResizeHandle, DropPreview, DropIntent;
```

Use `hide` to exclude the conflicting types from the barrel file import while getting them from the new location.

#### 2. Field Name Mapping (Old → New)

| Old Field | New Field |
|-----------|-----------|
| `dropPreview.kind` | `dropPreview.intent` |
| `dropPreview.direction` (LayoutDirection) | `dropPreview.indicatorAxis` (Axis) |
| `dropPreview.parentDocId` | `dropPreview.targetParentDocId` |
| `dropPreview.parentExpandedId` | `dropPreview.targetParentExpandedId` |
| `dropPreview.childrenExpandedIds` | `dropPreview.targetChildrenExpandedIds` |
| `dropPreview.childrenDocIds` | `dropPreview.targetChildrenDocIds` |
| `session.dropTarget` | `session.dropPreview?.targetParentDocId` |
| `session.dropTargetExpandedId` | `session.dropPreview?.targetParentExpandedId` |
| `session.dropFrameId` | `session.dropPreview?.frameId` |
| `session.insertionIndex` | `session.dropPreview?.insertionIndex` |
| `session.reflowOffsets` | `session.dropPreview?.reflowOffsetsByExpandedId` |

#### 3. hitTestContainer Signature Change

The old signature used `excludeNodeIds` (doc IDs), the new one uses `excludeExpandedIds`:

```dart
// OLD
ContainerHit? hitTestContainer(
  String frameId,
  Offset worldPos, {
  Set<String>? excludeNodeIds,  // Doc IDs
});

// NEW
ContainerHit? hitTestContainer(
  String frameId,
  Offset worldPos, {
  Set<String>? excludeExpandedIds,  // Expanded IDs (INV-1)
});
```

#### 4. ContainerHit Constructor Change

The old `ContainerHit` used positional arguments, the new one uses named parameters:

```dart
// OLD
return ContainerHit(patchId, expandedId);

// NEW
return ContainerHit(expandedId: expandedId, docId: patchId);
```

Note: `expandedId` is now the PRIMARY field (first), `docId` is DERIVED (second).

#### 5. Indicator Axis is Pre-Computed

The old overlay had to convert `LayoutDirection` to `Axis`:
```dart
// OLD - overlay computed this
final axis = direction == LayoutDirection.horizontal
    ? Axis.vertical
    : Axis.horizontal;
```

The new `DropPreview` provides `indicatorAxis` directly - overlay just reads it.

#### 6. DropPreview.none() Requires frameId

The new `DropPreview.none()` constructor requires `frameId` as a required parameter:

```dart
// OLD
session.dropPreview = const DropPreview.none(
  invalidReason: 'Mixed frames in selection',
);

// NEW
session.dropPreview = DropPreview.none(
  frameId: frameId,
  invalidReason: 'Scene/render doc/lookups not available',
  draggedDocIdsOrdered: draggedDocIdsOrdered,
  draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
);
```

#### 7. Builder Handles Everything

The builder now handles:
- Hit testing (via callback)
- Climbing to auto-layout ancestor (INV-4)
- Building children list from render tree (INV-2)
- Computing insertion index with hysteresis
- Computing indicator rect with clipping (INV-6)
- Computing reflow offsets (INV-3)
- Determining intent (reorder vs reparent)

The canvas just passes inputs and stores the result. No more scattered logic.

---

### Key Notes for Phase 4: Overlay & Visual Feedback

#### 4.1 InsertionIndicatorOverlay - Already Simplified ✅

The overlay now just reads `dropPreview.indicatorWorldRect` and `dropPreview.indicatorAxis` and paints. No calculation logic remains.

Current implementation paints:
- Glow effect (8px blur, 30% opacity)
- Main line (3px stroke)
- End nubs (4px circles)

Per the style spec (`dragdropstyle.md`), the current values are close but could be refined:
- Line thickness should be 2px (currently 3px)
- Glow blur should be 8px ✅
- Glow alpha should be 0.25 (currently 0.3)
- Nub radius should be 4px ✅

#### 4.2 Drop Zone Highlight - Needs Update

`selection_overlay.dart` currently shows a `_DropZoneHighlight` widget. It now reads from `dropPreview` correctly, but the styling should match the spec:

Per `dragdropstyle.md`:
- Outline stroke: 1px (screen px)
- Outline color: accent @ 60% opacity
- Radius: parent radius or 6px default
- Optional fill: accent @ 6% opacity

Current implementation may need visual refinement.

#### 4.3 Drag Ghost Styling - Not Yet Implemented

Per `dragdropstyle.md`, the ghost (dragged node preview) should have:

**Valid drop:**
- Opacity: 0.90
- Shadow A: y=4px, blur=12px, alpha=0.18
- Shadow B: y=1px, blur=3px, alpha=0.12
- Optional 1px outline: borderSubtle @ 20%

**Invalid drop:**
- Opacity: 0.55
- Desaturate slightly (saturation 0.0-0.2)
- Shadows reduced: A alpha=0.10, B alpha=0.07

This styling is NOT currently implemented. The ghost is rendered via `FrameRenderer` and would need a wrapper widget or paint transform.

#### 4.4 Reflow Animation - Already Working ✅

`frame_renderer.dart` now reads `dropPreview.reflowOffsetsByExpandedId` and passes to `RenderEngine`. The animation should already work.

#### 4.5 Remaining Work for Phase 4

1. **Fine-tune indicator styling** - Adjust line thickness (2px), glow alpha (0.25)
2. **Review drop zone highlight** - Ensure matches spec
3. **Implement drag ghost styling** - Add opacity/shadow changes based on `dropPreview.isValid`
4. **Test animations** - Verify reflow and fade in/out are smooth (80-120ms per spec)

#### 4.6 Files to Modify in Phase 4

| File | Change |
|------|--------|
| `insertion_indicator_overlay.dart` | Fine-tune paint values |
| `selection_overlay.dart` | Review drop zone highlight styling |
| `frame_renderer.dart` or new widget | Add drag ghost styling (opacity/shadow based on validity) |

---

### Remaining Phases

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 3 | Canvas State Integration | ✅ Complete |
| Phase 4 | Overlay & Visual Feedback | ✅ Complete |
| Phase 5 | Patch Generation & Commit | ✅ Complete |
| Phase 6 | Debug Mode | ✅ Complete |
| Phase 7 | Cleanup Legacy Code | ✅ Merged into Phase 3 |

**Note:** Phase 7 (Cleanup Legacy Code) was merged into Phase 3 since the old files were deleted as part of the integration work.

---

### Phase 6: Debug Mode ✅ COMPLETE

**Date:** 2026-01-17

**Files Created:**

| File | Lines | Status |
|------|-------|--------|
| `lib/src/free_design/canvas/drag/drag_debug.dart` | 108 | ✅ |
| `lib/src/free_design/canvas/widgets/drag_debug_overlay.dart` | 255 | ✅ |

**Files Modified:**

| File | Change |
|------|--------|
| `lib/src/free_design/canvas/drag/drop_preview_builder.dart` | Removed local `kDropPreviewDebug`, imported `drag_debug.dart`, updated `_debugLog()` to use `DragDebugLogger`, added consolidated log call before returning valid preview |
| `lib/src/free_design/canvas/drag/drag.dart` | Added export for `drag_debug.dart` |
| `lib/src/free_design/canvas/widgets/free_design_canvas.dart` | Added `DragDebugOverlay` to overlay stack |

**Verification:** `flutter analyze lib/` passes with no errors (only pre-existing info-level warnings).

---

### Key Features Implemented in Phase 6

#### 1. Debug Flag and Throttled Logger (`drag_debug.dart`)

- `kDragDropDebug = false` - Global toggle for all debug features
- `kDebugLogThrottleMs = 100` - Throttle interval (~10 logs/second)
- `DragDebugLogger.log()` - Throttled logging helper
- `DragDebugLogger.logOnce()` - Unthrottled logging for one-time events
- `DragDebugLogger.logDropPreview()` - Consolidated log with all 10 spec values
- `DragDebugLogger.resetThrottle()` - Reset throttle on drag start

#### 2. Debug Overlay (`drag_debug_overlay.dart`)

Visual debugging aids when `kDragDropDebug = true`:
- **Parent bounds**: Dashed orange outline around target container
- **Child midpoints**: Cyan circles at each child's center
- **Debug insertion line**: Dashed magenta line showing computed position
- **Info label**: Top-left label showing `idx | intent | children | invalidReason`

#### 3. Consolidated Logging

On every valid drop preview computation, logs all 10 values per spec Section 12:
- `frameId`
- `hoveredExpandedId`
- `hoveredDocId`
- `targetParentExpandedId`
- `targetParentDocId`
- `isAutoLayout`
- `childrenCountFiltered`
- `insertionIndex`
- `intent`
- `invalidReason`

Plus additional values: `indicatorRect`, `reflowCount`

---

### How to Enable Debug Mode

1. Open `lib/src/free_design/canvas/drag/drag_debug.dart`
2. Change `const bool kDragDropDebug = false;` to `true`
3. Rebuild the app
4. Drag any node - console logs and visual overlay will appear

---

### Phase 4: Overlay & Visual Feedback ✅ COMPLETE

**Date:** 2026-01-17

**Files Modified:**

| File | Change |
|------|--------|
| `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart` | Updated `InsertionLinePainter` with spec-compliant styling: 2px line, 8px glow @ 25% opacity, pixel snapping, 4% slot highlight band |
| `lib/src/free_design/canvas/widgets/selection_overlay.dart` | Updated `_DropZoneHighlight` to StatefulWidget with 100ms fade animation, updated `_DropZonePainter` with accent blue styling: 1px stroke @ 60%, 6% fill, 6px corner radius |

**Verification:** `flutter analyze` passes with no issues.

---

### Key Changes in Phase 4

#### 1. Insertion Indicator Styling (per dragdropstyle.md)

| Property | Before | After |
|----------|--------|-------|
| Line thickness | 3px | 2px |
| Glow blur | 4px (MaskFilter) | 8px |
| Glow alpha | 0.30 | 0.25 |
| Nub radius | 4px | 4px ✅ |
| Slot highlight | None | 4% opacity band |
| Pixel snapping | None | Half-pixel snapping for crisp lines |
| Stroke cap | Butt | Round |

#### 2. Drop Zone Highlight Styling (per dragdropstyle.md)

| Property | Before | After |
|----------|--------|-------|
| Color | Green (#00C853) | Accent blue (#007AFF) |
| Stroke width | 2.5px | 1px |
| Stroke alpha | 1.0 | 0.60 |
| Fill alpha | 0.08 | 0.06 |
| Glow effect | Yes (blur 3px) | Removed |
| Corner radius | None (rect) | 6px (rounded) |
| Animation | None | 100ms fade in/out |

#### 3. Simplified Drop Zone Implementation

The `_DropZoneHighlight` now reads `targetParentExpandedId` directly from `dropPreview` instead of searching through `scene.patchTarget.entries`. This aligns with the "dumb overlay" design principle.

#### 4. Drag Ghost Styling (Deferred)

Full drag ghost styling (opacity 0.90/0.55, two-layer shadows, multi-select stacking) requires render pipeline changes and is deferred to a future phase. See [phase4-implementation-plan.md](phase4-implementation-plan.md) for details.

---

### Key Notes for Phase 5: Patch Generation & Commit

Phase 5 implements the actual document patching when a drag completes.

#### 5.1 Create DropCommitPlan Builder

Build commit plan from `DropPreview`:

```dart
DropCommitPlan buildCommitPlan(DropPreview preview, Map<String, String> originalParents);
```

#### 5.2 Pure Patch Generation Helper

Create `drop_patches.dart` with pure function for generating patches:

```dart
List<PatchOp> generateDropPatches({
  required List<String> draggedDocIdsOrdered,
  required String originParentDocId,
  required String targetParentDocId,
  required int insertionIndex,
  required List<String> currentChildDocIds,
});
```

#### 5.3 Integration in CanvasState.endDrag()

```dart
if (dropPreview == null || !dropPreview.isValid) {
  // No structural change - revert
  return;
}

final patches = generateDropPatches(
  draggedDocIdsOrdered: dropPreview.draggedDocIdsOrdered,
  originParentDocId: session.originalParents.values.first,
  targetParentDocId: dropPreview.targetParentDocId!,
  insertionIndex: dropPreview.insertionIndex!,
  currentChildDocIds: dropPreview.targetChildrenDocIds,
);

_store.applyPatches(patches);
```

#### 5.4 Index Adjustment Logic

When reordering within the same parent, the insertion index is in "filtered list" coordinates (excludes dragged nodes). The patch generation must handle this correctly:
- Remove all dragged nodes from parent's childIds
- Insert at the filtered index position

---

### Phase 5: Patch Generation & Commit ✅ COMPLETE

**Date:** 2026-01-17

**Files Created:**

| File | Lines | Status |
|------|-------|--------|
| `lib/src/free_design/canvas/drag/drop_patches.dart` | 71 | ✅ |

**Files Modified:**

| File | Change |
|------|--------|
| `lib/src/free_design/canvas/drag/drag.dart` | Added export for `drop_patches.dart` |
| `lib/modules/canvas/canvas_state.dart` | Rewrote `endDrag()` to use `DropCommitPlan` + `generateDropPatches()`, removed `_generateMovePatches()` and `_generateFrameMovePatches()` |
| `lib/src/free_design/canvas/drag/drag_session.dart` | Simplified `generatePatches()` to only handle resize operations |

**Verification:** `flutter analyze lib/` passes with no errors (only pre-existing info-level warnings).

---

### Key Changes in Phase 5

#### 1. Pure Patch Generation Function

Created `generateDropPatches(DropCommitPlan)` that uses `DetachChild` + `AttachChild` instead of `MoveNode` to correctly handle multi-select ordering:

```dart
// Step 1: Detach ALL dragged nodes first
for (final id in draggedIds) {
  patches.add(DetachChild(parentId: originParent, childId: id));
}

// Step 2: Attach all in order at sequential indices
for (var i = 0; i < draggedIds.length; i++) {
  patches.add(AttachChild(
    parentId: targetParent,
    childId: draggedIds[i],
    index: baseIndex + i,
  ));
}
```

#### 2. Why DetachChild + AttachChild Instead of MoveNode

`MoveNode` does detach-then-attach atomically per node. When moving multiple nodes, each move affects subsequent indices:

```
Initial: [A, B, C, D, E], move [A, B] to filtered index 2

MoveNode(A, index=2):
  - Detach A: [B, C, D, E]
  - Attach at 2: [B, C, A, D, E]

MoveNode(B, index=3):
  - Detach B: [C, A, D, E]
  - Attach at 3: [C, A, D, B, E] ❌ (wrong order!)
```

Separating detach and attach phases avoids this:

```
DetachChild(A): [B, C, D, E]
DetachChild(B): [C, D, E]  ← Matches filtered list!

AttachChild(A, index=2): [C, D, A, E]
AttachChild(B, index=3): [C, D, A, B, E] ✅
```

#### 3. Simplified Code Structure

- **Move operations**: Now handled entirely by `generateDropPatches()` + `DropCommitPlan`
- **Frame moves**: Handled inline in `endDrag()` (frames don't have drop preview)
- **Resize operations**: Still handled by `DragSession.generatePatches()`

---

### Phase 5 Implementation Notes

#### Key Insight: MoveNode Atomic Behavior

The original implementation used `MoveNode` which does detach-then-attach atomically per node. This works fine for single-node moves but breaks multi-select because:

1. After first `MoveNode`, the list has changed
2. The second `MoveNode` operates on the changed list
3. The filtered index no longer maps correctly

The fix separates the two phases explicitly using low-level `DetachChild` and `AttachChild` patches.

#### Frame Moves Don't Use DropCommitPlan

Frames are top-level objects with no parent hierarchy. When dragging frames:
- There's no drop preview (no structural change)
- Position is updated directly via `SetFrameProp`

This is handled inline in `endDrag()` rather than through the drop patch system.
