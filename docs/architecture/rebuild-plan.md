# Distill Architecture Convergence Plan

> This plan emerged from iterative review. The goal is to **delete categories of complexity**, not add new abstractions.

## The Invariants

These rules, once established, cannot be violated anywhere in the codebase.

### Invariant 1: Local Stored, World Derived

```
STORED:    localTransform(entity)  — position/size relative to parent
DERIVED:   worldTransform(entity)  — accumulated from root (computed)
CANONICAL: world space             — all interaction/hit-testing uses this

FORBIDDEN:
  ✗ Multiple competing authored spaces (frame-local AND parent-local AND world)
  ✗ Conversion helper soup (toFrameLocal, toParentSpace, etc.)
  ✗ Storing world coordinates as authored data
```

**Rationale:** You need parent-relative positions for reparenting to work sensibly. But interaction code should never think in anything other than world space.

### Invariant 2: Unique Entity IDs

```
Every entity has a globally unique ID. Period.

FORBIDDEN:
  ✗ Namespaced IDs like "instanceId::nodeId"
  ✗ IDs that change based on context
  ✗ Any code that "expands" or "collapses" IDs
```

**Rationale:** ID namespacing is a tax paid everywhere. Kill it at the source.

### Invariant 3: Flat Storage, Derived Trees

```
Data lives in flat tables. Trees are computed views.

FORBIDDEN:
  ✗ node.children as stored nested data
  ✗ Deep copyWith on mutations
  ✗ Recursive cloning for single-node updates
```

**Rationale:** O(1) updates, trivial serialization, easy indexing.

### Invariant 4: Stable Override Addressing

```
Overrides target entities by SLOT KEY, not by structure.

GOOD:
  ✓ SlotKey("header") → fill: blue
  ✓ SlotKey("cta-button") → text: "Buy Now"

BAD:
  ✗ children[2].fill (breaks on reorder)
  ✗ container.row.button (breaks on rename)
```

**Invariant 4b: Overrides must be resilient to component edits.**

When a component author deletes/replaces a node:
- Override becomes "orphaned"
- UI shows orphaned overrides with option to remap or discard
- Slot-key based addressing makes auto-remap possible

**Rationale:** Instance systems blow up when overrides break silently.

---

## Phase 0: Measure (2 days)

### Do
- Profile 3 workloads: small (10 nodes), medium (100 nodes), large (500+ nodes)
- Record metrics:
  - Frame time while panning/zooming
  - Frame time while dragging
  - Time to apply common commands (move, resize, style change)
- Establish budgets: e.g., "panning must stay under 8ms on large doc"

### Exit Criteria
- You have numbers written down
- You know what's actually slow (not guessing)

---

## Phase 1: Coordinate Unification + State Machine (2 weeks)

### Scope Lock
```
World space is canonical for:
  ✓ Hit testing
  ✓ Selection rectangles
  ✓ Snap guides
  ✓ Drag deltas
  ✓ Drop targets
  ✓ Resize handles

Only two transform types at runtime:
  ✓ localTransform(entity)  — stored, parent-relative
  ✓ worldTransform(entity)  — derived, root-relative

View transform (camera) is separate:
  ✓ viewTransform.worldToScreen(point)
  ✓ viewTransform.screenToWorld(point)
```

### Deliverables
1. `WorldTransform` component computed for every entity
2. `InteractionState` sealed class:
   ```dart
   sealed class InteractionState {}
   class Idle extends InteractionState {}
   class Hovering extends InteractionState { Entity? entity; }
   class Dragging extends InteractionState { List<Entity> entities; Offset startWorld; }
   class Resizing extends InteractionState { Entity entity; HandleType handle; }
   class Panning extends InteractionState { Offset startScreen; Offset startPan; }
   class MarqueeSelecting extends InteractionState { Offset startWorld; Offset currentWorld; }
   ```
3. All hit-test functions take world coordinates only
4. All drag deltas computed in world space

### Exit Criteria
- `grep -rE "toFrameLocal|toParentSpace|parentLocal|frameLocal" lib/` returns zero hits
- `InteractionState` is the single source of truth for gesture state
- No boolean combinations like `isDragging && !isResizing`

### What Gets Deleted
- Coordinate conversion helpers
- Coordinate space enums
- Scattered drag/resize state booleans across multiple classes

---

## Phase 2: Flatten Storage (3 weeks)

### Table Structure (start lean, split later)
```dart
class World {
  // Core tables - don't over-shard
  final Table<EntityMeta> entities;     // kind, flags, name
  final Table<Hierarchy> hierarchy;     // parent, childIndex
  final Table<Transform> transforms;    // x, y, width, height, rotation
  final Table<Style> styles;            // fill, stroke, opacity, radius, shadows
  final Table<TextContent> text;        // text nodes only
  final Table<LayoutConfig> layout;     // auto-layout containers only

  // Index for O(k) child iteration (not O(n) scan)
  final Map<Entity, List<Entity>> _childrenIndex;
}
```

### Migration Strategy (timeboxed dual-write)
```
Week 1: Introduce tables, dual-write on mutations
Week 2: Migrate reads (hit-test reads new, render reads old)
Week 3: Flip render to new, DELETE old paths immediately
        Do not let dual-write linger
```

### Exit Criteria
- `git grep "copyWith" lib/src/free_design/models/` count drops 80%+
- Common commands don't allocate (verify with `--track-widget-creation` or allocation profiler)
- Child iteration is O(k) via index, not O(n) table scan

### What Gets Deleted
- `Node.copyWith` chains
- `EditorDocument.copyWith` for node mutations
- Recursive tree clone utilities

---

## Phase 3: Instances Redesign (2 weeks)

### Override Addressing Strategy
```dart
// Slot-key based (preferred for design tools)
class Override {
  final String slotKey;      // Author-defined: "header", "cta", "icon"
  final String property;     // "fill", "text", "opacity"
  final dynamic value;
}

// Orphan handling
class OverrideSet {
  final List<Override> active;
  final List<OrphanedOverride> orphaned;  // Slot no longer exists

  // UI can show: "This override targets 'old-button' which was removed. Remap or discard?"
}
```

### Cached Resolution
```dart
// Compute once per frame, not per property access
class ResolvedEntity {
  final Fill fill;
  final Stroke? stroke;
  final double opacity;
  // All properties flattened from prototype chain
}

// Invalidation triggers:
//   - Instance override changes
//   - Prototype (component definition) changes
final Map<Entity, ResolvedEntity> _resolvedCache;
```

### Exit Criteria
- Zero code paths that "expand" instances into copied trees
- `grep -r "::" lib/ | grep -v import | grep -v comment` returns nothing
- Instance creation is O(1) - no tree cloning

### What Gets Deleted
- `ExpandedSceneBuilder`
- ID namespacing utilities (`expandId`, `collapseId`, etc.)
- Instance expansion caches

---

## Phase 4: Rendering Optimization (only if Phase 0 showed need)

### Order of Operations

**First (often sufficient):**
1. Ensure canvas widget rebuilds ONLY on camera change or doc change
2. Tool overlays rebuild independently from canvas content
3. Selection state changes don't trigger full canvas rebuild
4. Viewport culling with spatial index (R-tree or quadtree)

**Second (if still needed):**
5. Cache expensive node paints as `ui.Picture`
6. Cache `TextPainter` instances (text layout is expensive)

**Last resort:**
7. Retained data scene graph with dirty tracking
8. Custom RenderObjects (really last resort)

### Exit Criteria
- Panning/zooming on "large doc" stays under frame budget from Phase 0
- Profile shows time in actual painting, not tree walks or allocations
- `flutter run --profile` shows no unexpected rebuilds during pan/zoom

### What Gets Deleted
- Over-engineered invalidation systems
- Redundant repaint triggers

---

## Phase 5: Undo Evolution (last, when command surface is stable)

### Op Classification
```dart
// Easy ops: trivial before/after, small data
sealed class EasyOp {
  SetPosition(entity, oldPos, newPos);
  SetSize(entity, oldSize, newSize);
  SetStyle(entity, oldStyle, newStyle);
  ReorderChild(parent, oldIndex, newIndex);
}

// Hard ops: snapshot affected subgraph (NOT whole document)
sealed class HardOp {
  // Store table rows for specific entity set, not document blob
  Paste(affectedEntities, rowsBefore, rowsAfter);
  Duplicate(affectedEntities, rowsBefore, rowsAfter);
  PropagateEdit(affectedEntities, rowsBefore, rowsAfter);
}
```

### Snapshot Granularity
```dart
// GOOD: Snapshot specific rows
class Snapshot {
  final Set<Entity> affectedEntities;
  final Map<Entity, Transform> transforms;
  final Map<Entity, Style> styles;
  final Map<Entity, Hierarchy> hierarchies;
  // Only what changed, bounded memory
}

// BAD: Serialize half the world
class Snapshot {
  final String entireDocumentJson;  // Don't do this
}
```

### Exit Criteria
- Undo/redo works correctly for all ops
- No `computeInverse()` methods - just swap before/after
- Coalescing works (rapid drags = single undo entry)
- Hard op snapshots are bounded (log their size to verify)

### What Gets Deleted
- Patch inversion logic
- `computeInverse()` methods
- Complex patch ordering code

---

## CI Enforcement

Add automated guardrails to prevent regression:

```bash
#!/bin/bash
# scripts/check-invariants.sh

set -e

echo "Checking Invariant 1: No coordinate conversion soup..."
if grep -rE "toFrameLocal|toParentSpace|parentLocal" lib/; then
  echo "FAIL: Found forbidden coordinate helpers"
  exit 1
fi

echo "Checking Invariant 2: No namespaced IDs..."
if grep -r "::" lib/ | grep -v "import\|comment\|http\|::/"; then
  echo "FAIL: Found namespaced IDs"
  exit 1
fi

echo "Checking Invariant 3: No deep copyWith chains..."
COPY_COUNT=$(grep -r "copyWith" lib/src/free_design/models/ | wc -l)
if [ "$COPY_COUNT" -gt 10 ]; then
  echo "WARN: $COPY_COUNT copyWith usages in models (target: <10)"
fi

echo "All invariant checks passed"
```

Add to CI pipeline to gate PRs.

---

## Summary: What Each Phase Deletes

| Phase | Deletes |
|-------|---------|
| 0 | Guesswork about performance |
| 1 | Coordinate helpers, space enums, scattered booleans |
| 2 | copyWith chains, recursive cloning, nested mutations |
| 3 | Instance expansion, ID namespacing, ExpandedSceneBuilder |
| 4 | Over-invalidation, rebuild triggers (maybe) |
| 5 | Patch inversion, computeInverse() |

---

## Next Step

**Start with Phase 1.** It's high-leverage, low-risk, and produces immediate benefits (fewer bugs, clearer code) without touching the data model.

The interaction state machine can be introduced alongside existing code and gradually take over.
