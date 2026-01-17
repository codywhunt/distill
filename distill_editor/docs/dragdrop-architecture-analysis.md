# Drag & Drop Architecture Analysis (v3)

## Executive Summary

After comprehensive analysis and planning review, we've confirmed **three contracts are missing** and **one subsystem is aiming at the wrong concept**:

| Issue | Root Cause | What's Missing |
|-------|------------|----------------|
| Can't reorder within origin parent | Stickiness is a debug log that runs AFTER target resolution | **Origin-first targeting** (pre hit-test) |
| No indicator when hovering different parent | Indicator null doesn't invalidate preview | **"No indicator = not valid" contract** |
| Grid/smart guides on node moves | No separation between frame-level and node-level snapping | Simple fix |
| Text nodes don't work | Filtered in selection/drag initiation, not drop targets | **"Any patchable node can be dragged" rule** |

**Key insight**: The system is behaving "wrong" because it's targeting "deepest container" when it should be targeting "deepest eligible drop parent" - and origin stickiness is not a feature yet, it's just a debug log.

---

## Confirmed Root Causes

### 1) "Origin stickiness" is not a feature yet

Right now it's **a debug log** that runs **after** you already chose a target. That guarantees the failure mode:

* start dragging
* hit-test picks some deeper container / weird ancestor
* you lose the ability to reorder inside origin because target already moved "up" or "sideways"

**Fix:** stickiness must be **pre-targeting**, not post-validation.

### 2) hitTestContainer selects "deepest container", not "deepest eligible drop parent"

Hit-test returns: "the first container hit in reverse paint order" where container is box/row/column and patchable.

But "container" ≠ "drop parent" in v1 spec.

**In v1, eligible drop parent = auto-layout container** (and patchable, not dragged, etc.).

So we're feeding the builder a target that is often:
* a box without auto-layout
* an inner container that shouldn't steal the drop
* something that later causes climb weirdness

### 3) Indicator failure is silently allowed

`_computeIndicatorRect()` can return null for 4 reasons, and preview stays `isValid: true`.

So you can be in a "valid" drop state but show **no indicator**. That matches exactly what you're seeing - "ghost valid" states.

---

## Answers to Specific Questions

### Q1: Does DropPreviewBuilder.compute() stickiness branch early-return/bypass hit-test?

**Answer: NO. It runs AFTER hit-test and only LOGS.**

Current code (lines 238-244):
```dart
// Step 3b: Origin Stickiness Check (Smart)
// ...
// NOTE: We don't force the target here - we just log when stickiness confirms
// a reorder. The resolved target is already correct; this check just validates
// that we're staying in the origin parent when appropriate.

if (originParentExpandedId != null &&
    originParentContentWorldRect != null &&
    originParentContentWorldRect.contains(cursorWorld) &&
    targetExpandedId == originParentExpandedId) {  // <-- Only logs if ALREADY correct
  _debugLog('Stickiness: resolved target is origin parent, confirming reorder');
}
// If resolved != origin, we allow reparent even if cursor is in origin rect
```

**The order is:**
1. Step 2: `hitTestContainer()` runs → returns `ContainerHit`
2. Step 3: `_resolveEligibleTarget()` climbs to auto-layout ancestor
3. Step 3b: Stickiness check **only logs** if target happens to equal origin
4. **No override happens** - the wrong target proceeds to indicator/reflow computation

---

### Q2: How does hitTestContainer() choose among overlapping containers?

**Answer: Reverse iteration (last in renderDoc = topmost/deepest wins), early return on first hit.**

Current code (lines 581-619 in canvas_state.dart):
```dart
// Iterate in REVERSE order (topmost/deepest containers first)
// Return on first hit for deterministic behavior
final keys = renderDoc.nodes.keys.toList(growable: false);
for (var i = keys.length - 1; i >= 0; i--) {
  final expandedId = keys[i];
  final node = renderDoc.nodes[expandedId];
  if (node == null) continue;

  // Skip non-containers (only box, row, column can accept children)
  final isContainer =
      node.type == RenderNodeType.box ||
      node.type == RenderNodeType.row ||
      node.type == RenderNodeType.column;
  if (!isContainer) continue;

  // ...exclusion checks...

  // EARLY RETURN on first hit (topmost wins)
  if (bounds.contains(frameLocalPos)) {
    return ContainerHit(expandedId: expandedId, docId: patchTargetId);
  }
}

// Fallback to frame root if no container hit
return ContainerHit(expandedId: rootExpandedId, docId: frame.rootNodeId);
```

**Key behaviors:**
- **Reverse iteration**: Assumes renderDoc.nodes is in paint order (back-to-front), so reversing gives front-to-back (topmost first)
- **Type filter**: Only `box`, `row`, `column` - excludes text, image, icon, spacer
- **Patchability filter**: Skips nodes inside instances (`patchTargetId == null`)
- **Exclusion filter**: Skips nodes in `excludeExpandedIds` (dragged nodes)
- **First hit wins**: Early return, no "smallest bounds" or depth comparison
- **Fallback**: Returns frame root if nothing else hits

**Problem**: This returns the **deepest container**, not necessarily an **eligible drop target** (auto-layout). A nested box without auto-layout will be returned, then climbing may find a different ancestor than the origin parent.

---

### Q3: Exact conditions where _computeIndicatorRect() returns null

**Answer: 4 conditions can cause null, and null does NOT invalidate the preview.**

```dart
({Rect rect, Axis axis})? _computeIndicatorRect({...}) {
  // Condition 1: Parent bounds unavailable
  final parentBounds = getBounds(frameId, targetExpandedId);
  if (parentBounds == null) return null;  // <-- SILENT NULL

  // ... padding computation ...

  // Condition 2: Content box collapsed (width or height <= 0)
  if (contentBox.width <= 0 || contentBox.height <= 0) {
    return null;  // <-- SILENT NULL
  }

  // ... indicator position computation ...

  // Condition 3: Indicator clipped to nothing meaningful
  indicatorRect = indicatorRect.intersect(contentWorld);

  // Condition 4: Indicator too small after clipping
  final minSize = kMinIndicatorSizePx / zoom;  // 6px / zoom
  if (indicatorRect.width < minSize || indicatorRect.height < minSize) {
    return null;  // <-- SILENT NULL
  }

  return (rect: indicatorRect, axis: axis);
}
```

**Critical issue**: The preview is still marked `isValid: true` even when indicator is null:
```dart
final preview = DropPreview(
  intent: intent,
  isValid: true,  // <-- ALWAYS TRUE if we reach this point
  // ...
  indicatorWorldRect: indicatorResult?.rect,  // <-- Can be null
  indicatorAxis: indicatorResult?.axis,       // <-- Can be null
);
```

**Result**: User sees no insertion line, but drop will still occur. This violates the expected visual contract.

---

## Required Fixes (Minimum Set for Stable Behavior)

### Fix A: Implement Origin-First Targeting (Pre Hit-Test)

**This is the single most important behavior fix.**

In `DropPreviewBuilder.compute()`:

1. If origin is eligible and cursor in origin content rect (+ hysteresis) → set target = origin and **skip hit-test**.
2. Only when cursor is outside the origin rect threshold → do normal target resolution.

```dart
// -------------------------------------------------------------------------
// Step 1b: Origin-First Targeting (INV-Z)
// -------------------------------------------------------------------------
// If cursor is inside origin content rect, skip hit-test entirely.
// This is PRE-TARGETING, not post-validation.

if (originParentExpandedId != null &&
    originParentContentWorldRect != null) {

  // Add hysteresis band on origin rect boundary (same idea as insertion hysteresis)
  // to prevent flapping between origin and outside
  final stickyRect = originParentContentWorldRect.inflate(kHysteresisPixels / zoom);

  if (stickyRect.contains(cursorWorld)) {
    final originDocId = lookups.getDocId(originParentExpandedId);
    if (originDocId != null) {
      final originNode = document.nodes[originDocId];
      if (originNode?.layout.autoLayout != null) {
        // HARD-GATE: Origin wins, skip hit-test
        _debugLog('Origin-first: cursor inside origin rect, target = origin');
        // Continue with origin as target...
        // (rest of computation uses originParentExpandedId, originDocId)
      }
    }
  }
}

// Step 2: Hit test (only reached if cursor outside origin rect threshold)
final hit = hitTestContainer(frameId, cursorWorld, draggedExpandedIds);
```

**Important:** Don't add the "ancestor of resolved target" constraint. That constraint is exactly what causes "can't reorder among siblings" in many layouts.

---

### Fix B: Make "Eligible Drop Parent" First-Class

Add a helper used everywhere:

```dart
bool isEligibleDropParent(String expandedId, String? docId, Set<String> draggedExpandedIds) {
  if (docId == null) return false; // unpatchable
  final docNode = document.nodes[docId];
  if (docNode?.layout.autoLayout == null) return false; // v1 restriction
  if (draggedExpandedIds.contains(expandedId)) return false;
  return true;
}
```

Then ensure targeting returns the **deepest eligible** container:

* If `hitTestContainer()` returns a non-eligible container, climb until eligible.
* If no eligible ancestor exists → invalid.

This stops random nested containers from hijacking the drop target.

---

### Fix C: "No Indicator = Not Valid"

After computing indicator:

```dart
final indicatorResult = _computeIndicatorRect(...);

// INV-Y: Valid drop requires indicator
if (indicatorResult == null && intent != DropIntent.none) {
  _debugLog('Indicator null for valid intent - marking invalid');
  return DropPreview.none(
    frameId: frameId,
    invalidReason: 'could not compute indicator for target',
    draggedDocIdsOrdered: draggedDocIdsOrdered,
    draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
  );
}
```

**(Optional but recommended):** Keep a debug counter/log of invalid reasons so you can see why it's failing most often (bounds missing vs collapsed padding vs min-size).

---

### Fix D: Separate Node Move vs Frame Move Snapping

Snapping & smart guides only for frame-level drags. Node drags should be raw world delta (plus maybe modifier keys later).

In `free_design_canvas.dart` `_handleDragUpdate()`:

```dart
final hasFrameTargets = session.targets.any((t) => t is FrameTarget);

// Only apply snapping for frame moves
final gridSize = hasFrameTargets && HardwareKeyboard.instance.isShiftPressed
    ? 10.0
    : null;
final useSmartGuides = hasFrameTargets && !HardwareKeyboard.instance.isMetaPressed;
```

This is straightforward and shouldn't be mixed with drop preview at all.

---

### Fix E: Text Nodes - Fix Drag Initiation, Not Drop Targeting

The `hitTestContainer()` filter is only about drop targets — that's fine.

The text issue is almost certainly one of:
* text nodes not selectable (hit-test for selection ignores them)
* `startDrag()` filters node types and refuses to create a `NodeTarget` for text
* patchTarget is null for text expanded nodes (meaning "inside instance" or mapping bug)

**Rule should be:**
* **Any patchable node can be dragged** (including text)
* Only auto-layout containers can be drop targets (v1)

**Investigation needed:** Check these code paths:
1. Selection hit-test method (whatever returns expandedId for selection)
2. `startDrag()` / NodeTarget creation code path
3. Any filter like `if (!isContainer) return;` or `if (node.type == text) skip`

---

## New Invariants

| ID | Description | Status |
|----|-------------|--------|
| INV-X | Target resolution returns deepest **eligible drop parent** | **MISSING** |
| INV-Y | Valid drop (intent != none) requires non-null indicator | **MISSING** |
| INV-Z | Origin stickiness enforced BEFORE hit-test (with hysteresis) | **MISSING** |

---

## Required Tests (Hard Regressions)

These encode the UX you want and will prevent backsliding:

### 1. "Origin reorder always possible"
Cursor inside origin content rect → target=origin, intent=reorder, reflow non-empty, indicator non-null.

### 2. "Reparent shows indicator"
Cursor over a different eligible parent → intent=reparent, reflow empty (INV-9), indicator non-null.

### 3. "Valid implies indicator"
If `preview.isValid == true && intent != none` → indicator rect + axis must be present.
Also: tests for each null-case noted above should produce `isValid=false` with the correct invalidReason.

### 4. "Deepest eligible drop parent"
Cursor over a nested box inside a column: if box isn't eligible (no auto-layout), target must be the column.

---

## Data Flow Overview (Current)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DRAG START                                    │
├─────────────────────────────────────────────────────────────────────┤
│  1. _handleDragStart() in free_design_canvas.dart                   │
│  2. Hit test for frames/nodes                                        │
│  3. state.startDrag() creates DragSession                           │
│  4. Captures: originParentExpandedId, originParentContentWorldRect  │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        DRAG UPDATE (per frame)                       │
├─────────────────────────────────────────────────────────────────────┤
│  1. _handleDragUpdate() receives cursor position                     │
│  2. DropPreviewBuilder.compute() called with:                        │
│     - cursorWorld                                                    │
│     - originParent info (for stickiness)                            │
│     - lastInsertionIndex (for hysteresis)                           │
│  3. Returns DropPreview with:                                        │
│     - targetParentDocId / targetParentExpandedId                    │
│     - insertionIndex                                                 │
│     - indicatorWorldRect (CAN BE NULL EVEN IF VALID!)               │
│     - reflowOffsetsByExpandedId                                      │
│  4. session.dropPreview = preview                                    │
│  5. Overlays read session.dropPreview and render                    │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        DRAG END                                      │
├─────────────────────────────────────────────────────────────────────┤
│  1. _handleDragEnd() calls state.endDrag()                          │
│  2. DropCommitPlan.fromPreview(dropPreview)                         │
│  3. generateDropPatches(plan) creates DetachChild + AttachChild     │
│  4. store.applyPatches(patches)                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## DropPreviewBuilder Algorithm (Current - 10 Steps)

```dart
DropPreview compute(...) {
  // Step 0: Validate INV-7 (same origin parent for multi-select)

  // Step 1: Use locked frame ID (INV-5)

  // Step 2: Hit test for container under cursor
  //         Returns ContainerHit(expandedId, docId)
  //         ⚠️ Returns DEEPEST container, not eligible drop target

  // Step 3: Climb to auto-layout ancestor (INV-4)
  //         ⚠️ May find different ancestor than origin parent

  // Step 3b: Origin Stickiness Check
  //         ⚠️ ONLY LOGS - does not override target

  // Step 4: Validate patchability (INV-8)

  // Step 5: Get children from render tree (INV-2)

  // Step 6: Compute insertion index with hysteresis

  // Step 7: Compute indicator rect (INV-6)
  //         ⚠️ Can return null without invalidating preview

  // Step 8: Determine intent (reorder vs reparent)

  // Step 9: Compute reflow offsets (INV-9)

  // Step 10: Build and return DropPreview
  //          ⚠️ isValid: true even if indicator null
}
```

---

## DropPreviewBuilder Algorithm (Fixed)

```dart
DropPreview compute(...) {
  // Step 0: Validate INV-7 (same origin parent for multi-select)

  // Step 1: Use locked frame ID (INV-5)

  // Step 1b: ORIGIN-FIRST TARGETING (INV-Z) ← NEW
  //          If cursor inside origin content rect (+ hysteresis):
  //            → target = origin parent, SKIP hit-test
  //          This is PRE-TARGETING, not post-validation

  // Step 2: Hit test for container under cursor (only if outside origin)
  //         Returns ContainerHit(expandedId, docId)

  // Step 3: Climb to ELIGIBLE drop parent (INV-X) ← UPDATED
  //         Eligible = auto-layout AND patchable AND not dragged

  // Step 4: Validate patchability (INV-8)

  // Step 5: Get children from render tree (INV-2)

  // Step 6: Compute insertion index with hysteresis

  // Step 7: Compute indicator rect (INV-6)

  // Step 7b: INDICATOR CONTRACT (INV-Y) ← NEW
  //          If indicator null AND intent != none → isValid = false

  // Step 8: Determine intent (reorder vs reparent)

  // Step 9: Compute reflow offsets (INV-9)

  // Step 10: Build and return DropPreview
}
```

---

## Key Data Structures

### DragSession
```dart
class DragSession {
  final DragMode mode;
  final Set<DragTarget> targets;
  final Map<DragTarget, Offset> startPositions;
  final Map<DragTarget, Size> startSizes;

  // Move-specific
  final Map<String, String> originalParents;  // docId → parentDocId
  final String? lockedFrameId;                 // INV-5
  final String? originParentExpandedId;        // For stickiness
  final Rect? originParentContentWorldRect;    // For stickiness

  // State during drag
  Offset accumulator = Offset.zero;
  DropPreview? dropPreview;
  int? lastInsertionIndex;
  Offset? lastInsertionCursor;
}
```

### DropPreview
```dart
class DropPreview {
  final bool isValid;
  final String frameId;
  final DropIntent intent;  // none, reorder, reparent

  // Target info
  final String? targetParentDocId;
  final String? targetParentExpandedId;
  final int? insertionIndex;

  // Visual state
  final Rect? indicatorWorldRect;   // ⚠️ Currently can be null even when isValid
  final Axis? indicatorAxis;
  final Map<String, Offset> reflowOffsetsByExpandedId;

  // Drag context
  final List<String> draggedDocIdsOrdered;
  final List<String> draggedExpandedIdsOrdered;

  bool get shouldShowIndicator =>
      isValid &&
      indicatorWorldRect != null &&
      indicatorAxis != null &&
      (intent == DropIntent.reorder || intent == DropIntent.reparent);
}
```

### ContainerHit
```dart
class ContainerHit {
  final String expandedId;  // PRIMARY - specific instance
  final String? docId;      // DERIVED - for patching

  bool get canPatch => docId != null;
}
```

---

## Existing Invariants

| ID | Description | Location |
|----|-------------|----------|
| INV-1 | Expanded-first hit testing | hitTestContainer, ContainerHit |
| INV-2 | Children from render tree | DropPreviewBuilder step 5 |
| INV-3 | Reflow keys exist in renderDoc | _computeReflowOffsets |
| INV-4 | Climb to auto-layout ancestor | _resolveEligibleTarget |
| INV-5 | Frame locked at drag start | DragSession constructor |
| INV-6 | Indicator clipped to content | _computeIndicatorRect |
| INV-7 | Multi-select same origin | startDrag validation |
| INV-8 | Valid → both IDs non-null | DropPreview constructor |
| INV-9 | Reflow only for reorder | Step 9 conditional |

---

## Key Files

| File | Purpose |
|------|---------|
| [drop_preview_builder.dart](../lib/src/free_design/canvas/drag/drop_preview_builder.dart) | Core drop preview computation |
| [drag_session.dart](../lib/src/free_design/canvas/drag/drag_session.dart) | Drag session state |
| [free_design_canvas.dart](../lib/src/free_design/canvas/widgets/free_design_canvas.dart) | Event handling, orchestration |
| [canvas_state.dart](../lib/modules/canvas/canvas_state.dart) | State management, hit testing |
| [insertion_indicator_overlay.dart](../lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart) | Indicator rendering |
| [drop_patches.dart](../lib/src/free_design/canvas/drag/drop_patches.dart) | Patch generation |

---

## Implementation Order

1. **Fix A: Origin-First Targeting** - Single most important behavior fix
2. **Fix C: No Indicator = Not Valid** - Eliminates "ghost valid" states
3. **Fix B: Eligible Drop Parent** - Stops nested containers from hijacking
4. **Fix D: Node vs Frame Snapping** - Simple, independent fix
5. **Fix E: Text Node Investigation** - Needs code path analysis first

---

## Summary

The current system is behaving "wrong" because:

1. **Origin stickiness is not a feature yet** - it's a debug log that runs too late
2. **Target selection aims at "deepest container"** instead of "deepest eligible drop parent"
3. **Indicator failure is silently allowed** - creating "ghost valid" states

The fixes are well-defined and the required tests will encode the expected Figma-like UX.
