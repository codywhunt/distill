# Phase 4: Overlay & Visual Feedback - Implementation Plan

## Overview

Phase 4 focuses on updating all visual feedback components to:
1. Match the Figma-like styling spec in `dragdropstyle.md`
2. Consume `DropPreview` as the single source of truth (no derived logic)
3. Add proper animations for a polished feel

**Current State:** Phase 3 is complete. The overlays already read from `dropPreview`, but styling doesn't match the spec and drag ghost styling is not implemented.

---

## What Needs to Change

### Current vs Spec Comparison

| Component | Current | Spec |
|-----------|---------|------|
| **Indicator line thickness** | 3px | 2px |
| **Indicator glow blur** | 4.0 (MaskFilter) | 8px |
| **Indicator glow alpha** | 0.30 | 0.25 |
| **Indicator nub radius** | 4px | 4px ✅ |
| **Drop zone stroke** | 2.5px green | 1px accent @ 60% |
| **Drop zone fill** | 8% green | 6% accent (optional) |
| **Drop zone color** | Green (#00C853) | Accent blue (#007AFF) |
| **Drag ghost valid opacity** | 1.0 (unchanged) | 0.90 |
| **Drag ghost invalid opacity** | 1.0 (unchanged) | 0.55 |
| **Drag ghost shadow** | None | Two-layer (y4/blur12 + y1/blur3) |
| **Reflow animation** | Instant | 80-120ms fade |

---

## Implementation Tasks

### Task 4.1: Update InsertionIndicatorOverlay

**File:** `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart`

**Changes:**

1. **Update `InsertionLinePainter` styling:**
   - Line thickness: `3.0` → `2.0`
   - Glow blur: `MaskFilter.blur(BlurStyle.normal, 4.0)` → compute 8px world units
   - Glow alpha: `0.3` → `0.25`
   - Add pixel snapping for crisp lines

2. **Add zoom parameter for constant screen-px dimensions:**
   ```dart
   class InsertionLinePainter extends CustomPainter {
     final Rect bounds;
     final Axis axis;
     final double zoom; // NEW: for screen-px → world conversion

     // In paint():
     final lineThickness = 2.0; // Already in view space, no conversion needed
     final glowBlur = 8.0;      // Already in view space
     final nubRadius = 4.0;     // Already in view space
   }
   ```

3. **Pixel snapping for crisp lines:**
   ```dart
   // Snap to half-pixel for odd-width lines
   Offset snapToHalfPixel(Offset point) {
     return Offset(
       (point.dx.floor() + 0.5),
       (point.dy.floor() + 0.5),
     );
   }
   ```

4. **Paint order (per spec):**
   1. Glow (blurred stroke with blur=8px, alpha=0.25)
   2. Main 2px line (solid accent)
   3. End nubs (4px radius circles)

**Styling tokens:**
```dart
const _accentColor = Color(0xFF007AFF);  // Figma blue
const _lineThickness = 2.0;
const _glowBlur = 8.0;
const _glowAlpha = 0.25;
const _nubRadius = 4.0;
```

---

### Task 4.2: Update Drop Zone Highlight

**File:** `lib/src/free_design/canvas/widgets/selection_overlay.dart`

**Changes to `_DropZoneHighlight` and `_DropZonePainter`:**

1. **Use accent color instead of green:**
   - Old: `Color(0xFF00C853)` (green)
   - New: `Color(0xFF007AFF)` (accent blue)

2. **Update styling to match spec:**
   ```dart
   // Outline
   strokeWidth: 1.0,  // Was 2.5
   strokeAlpha: 0.60, // Was 1.0

   // Fill (optional)
   fillAlpha: 0.06,   // Was 0.08
   ```

3. **Add corner radius:**
   - Use parent node's corner radius if available
   - Default: 6px

4. **Remove glow effect** (spec doesn't mention glow for drop zone):
   - Delete the glowPaint section

5. **Use `targetParentExpandedId` directly** (already available in dropPreview):
   - Current code searches `scene.patchTarget.entries` to find expandedId from nodeId
   - Simplify: Read `dropPreview.targetParentExpandedId` directly

**Updated `_DropZoneHighlight`:**
```dart
class _DropZoneHighlight extends StatelessWidget {
  const _DropZoneHighlight({
    required this.dropPreview,
    required this.controller,
    required this.state,
  });

  final DropPreview dropPreview;
  final InfiniteCanvasController controller;
  final CanvasState state;

  @override
  Widget build(BuildContext context) {
    final expandedId = dropPreview.targetParentExpandedId;
    if (expandedId == null) return const SizedBox.shrink();

    final worldBounds = _getNodeWorldBounds(
      state,
      dropPreview.frameId,
      expandedId,
    );
    if (worldBounds == null) return const SizedBox.shrink();

    final viewBounds = controller.worldToViewRect(worldBounds);

    return CustomPaint(
      painter: _DropZonePainter(bounds: viewBounds),
      size: Size.infinite,
    );
  }
}
```

**Updated `_DropZonePainter`:**
```dart
class _DropZonePainter extends CustomPainter {
  const _DropZonePainter({required this.bounds});

  final Rect bounds;

  static const _accentColor = Color(0xFF007AFF);

  @override
  void paint(Canvas canvas, Size size) {
    // Optional fill (spec: 6% opacity)
    final fillPaint = Paint()
      ..color = _accentColor.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(bounds, const Radius.circular(6));
    canvas.drawRRect(rrect, fillPaint);

    // Outline (spec: 1px @ 60% opacity)
    // Inset 0.5px to draw inside bounds
    final strokePaint = Paint()
      ..color = _accentColor.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final strokeRect = bounds.deflate(0.5);
    final strokeRRect = RRect.fromRectAndRadius(strokeRect, const Radius.circular(6));
    canvas.drawRRect(strokeRRect, strokePaint);
  }

  @override
  bool shouldRepaint(_DropZonePainter oldDelegate) {
    return bounds != oldDelegate.bounds;
  }
}
```

---

### Task 4.3: Add Animated Fade for Drop Zone

**File:** `lib/src/free_design/canvas/widgets/selection_overlay.dart`

**Changes:**

Convert `_DropZoneHighlight` to `StatefulWidget` with fade animation:

```dart
class _DropZoneHighlight extends StatefulWidget {
  const _DropZoneHighlight({
    required this.dropPreview,
    required this.controller,
    required this.state,
  });

  final DropPreview dropPreview;
  final InfiniteCanvasController controller;
  final CanvasState state;

  @override
  State<_DropZoneHighlight> createState() => _DropZoneHighlightState();
}

class _DropZoneHighlightState extends State<_DropZoneHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100), // 80-120ms per spec
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward(); // Fade in on mount
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... same bounds logic ...

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomPaint(
        painter: _DropZonePainter(bounds: viewBounds),
        size: Size.infinite,
      ),
    );
  }
}
```

---

### Task 4.4: Implement Drag Ghost Styling

**Location Decision:**

The drag ghost is currently rendered implicitly via `FrameRenderer` - dragged nodes are rendered at their preview positions by the `RenderEngine`. There's no separate "ghost" widget.

**Approach: Add a `DragGhostOverlay` widget**

This overlay will:
1. Capture the visual appearance of dragged nodes
2. Apply opacity/shadow/desaturation based on `dropPreview.isValid`
3. Render in the overlay layer (above canvas content)

**File:** `lib/src/free_design/canvas/widgets/drag_ghost_overlay.dart` (NEW)

**Implementation Strategy:**

Option A: **RepaintBoundary + Screenshot approach** (complex, performance concern)
- Capture the dragged nodes as an image at drag start
- Apply transforms/effects to the image

Option B: **Opacity wrapper on existing render** (simpler, recommended for v1)
- Instead of rendering dragged nodes in place, hide them in `FrameRenderer`
- Render a separate ghost layer with the dragged content + styling

**Recommended: Option B (simpler)**

Changes needed:
1. `FrameRenderer`: Pass `draggedExpandedIds` to `RenderEngine`, which skips rendering those nodes
2. New `DragGhostOverlay`: Renders dragged nodes with ghost styling

**However**, this is a significant change to the render pipeline. For Phase 4, let's do a **minimal implementation**:

**Minimal Approach: Apply opacity at the CanvasItem level**

In `free_design_canvas.dart`, wrap dragged nodes' `CanvasItem` with opacity:

```dart
// In _buildContent:
Widget content = FrameRenderer(...);

// If this frame contains dragged nodes, apply ghost styling
final session = widget.state.dragSession;
if (session != null && session.mode == DragMode.move) {
  final isValid = session.dropPreview?.isValid ?? true;
  content = Opacity(
    opacity: isValid ? 0.90 : 0.55,
    child: content,
  );
}
```

**Problem:** This applies opacity to the entire frame, not just dragged nodes.

**Better Minimal Approach: Add ghost styling at RenderEngine level**

Add a `draggedExpandedIds` parameter to `RenderEngine` that applies:
- Opacity reduction for dragged nodes
- Shadow effect via `DecoratedBox` or custom paint

**For v1 Phase 4, let's document this as "future enhancement" and focus on what we can do without major render pipeline changes.**

---

### Task 4.5: Add Drop Slot Highlight (Optional Enhancement)

**File:** `lib/src/free_design/canvas/widgets/insertion_indicator_overlay.dart`

**Add subtle slot background behind indicator line:**

```dart
// In InsertionLinePainter.paint():

// 1. Draw slot highlight (subtle band)
final slotPaint = Paint()
  ..color = _accentColor.withValues(alpha: 0.04)
  ..style = PaintingStyle.fill;

Rect slotRect;
if (axis == Axis.horizontal) {
  // Horizontal line (vertical layout) - slot is horizontal band
  slotRect = Rect.fromCenter(
    center: bounds.center,
    width: bounds.width,
    height: 8.0,
  );
} else {
  // Vertical line (horizontal layout) - slot is vertical band
  slotRect = Rect.fromCenter(
    center: bounds.center,
    width: 8.0,
    height: bounds.height,
  );
}
canvas.drawRRect(
  RRect.fromRectAndRadius(slotRect, const Radius.circular(4)),
  slotPaint,
);

// 2. Then draw glow
// 3. Then draw main line
// 4. Then draw nubs
```

---

### Task 4.6: Add Debug Overlay (Optional)

**File:** `lib/src/free_design/canvas/widgets/drag_debug_overlay.dart` (NEW)

Only shown when `kDragDropDebug == true`:

```dart
class DragDebugOverlay extends StatelessWidget {
  const DragDebugOverlay({
    required this.state,
    required this.controller,
    super.key,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    if (!kDragDropDebug) return const SizedBox.shrink();

    final dropPreview = state.dragSession?.dropPreview;
    if (dropPreview == null) return const SizedBox.shrink();

    return CustomPaint(
      painter: _DebugPainter(
        dropPreview: dropPreview,
        controller: controller,
        state: state,
      ),
    );
  }
}

class _DebugPainter extends CustomPainter {
  // Draw:
  // - Parent bounds (outline)
  // - Child midpoints (dots)
  // - Computed insertion line (different color from actual)
  // - Text overlay with: intent, insertionIndex, invalidReason
}
```

---

## Implementation Order

### Step 1: Update InsertionIndicatorOverlay (Task 4.1)
- Line thickness 3→2
- Glow blur 4→8, alpha 0.3→0.25
- Add pixel snapping
- Verify paint order

### Step 2: Update Drop Zone Highlight (Task 4.2)
- Green → accent blue
- Stroke 2.5→1px @ 60%
- Fill 8%→6%
- Add corner radius
- Simplify to use `targetParentExpandedId` directly

### Step 3: Add Drop Zone Fade Animation (Task 4.3)
- Convert to StatefulWidget
- Add 100ms fade in/out

### Step 4: Add Drop Slot Highlight (Task 4.5)
- Subtle 4% opacity band behind indicator

### Step 5 (Optional): Add Debug Overlay (Task 4.6)
- Only if helpful for remaining debugging

### Step 6 (Future): Drag Ghost Styling (Task 4.4)
- Document as future enhancement
- Requires render pipeline changes

---

## Files to Modify

| File | Change Type | Priority |
|------|-------------|----------|
| `insertion_indicator_overlay.dart` | Modify styling | High |
| `selection_overlay.dart` | Modify `_DropZoneHighlight` & `_DropZonePainter` | High |
| `drag_debug_overlay.dart` | Create new (optional) | Low |
| `free_design_canvas.dart` | Add debug overlay to stack (optional) | Low |

---

## Verification Checklist

### Visual Verification

- [ ] Indicator line is 2px (not 3px)
- [ ] Indicator has 8px glow at 25% opacity
- [ ] Indicator has 4px end nubs
- [ ] Indicator appears crisp at all zoom levels
- [ ] Drop zone uses accent blue (not green)
- [ ] Drop zone has 1px stroke at 60% opacity
- [ ] Drop zone has subtle 6% fill
- [ ] Drop zone fades in/out smoothly (100ms)
- [ ] Drop slot highlight is visible but subtle (4% opacity)

### Behavioral Verification

- [ ] Indicator only shows when `dropPreview.shouldShowIndicator` is true
- [ ] Drop zone only shows when `dropPreview.isValid` is true
- [ ] No visual artifacts when crossing container boundaries
- [ ] Reflow animation is smooth (already working from Phase 3)

### Performance Verification

- [ ] No jank during drag (single computation per frame)
- [ ] Overlay repaints efficiently (shouldRepaint checks)
- [ ] Animation controller properly disposed

---

## Deferred to Future Phase

### Drag Ghost Styling (Task 4.4)

Full ghost styling requires render pipeline changes:

**Valid drop ghost:**
- Opacity: 0.90
- Shadow A: y=4px, blur=12px, alpha=0.18
- Shadow B: y=1px, blur=3px, alpha=0.12
- Optional: 1px borderSubtle outline

**Invalid drop ghost:**
- Opacity: 0.55
- Desaturate slightly (saturation 0.0-0.2)
- Shadows reduced: A alpha=0.10, B alpha=0.07

**Multi-select ghost (v1 optional):**
- Stack effect with 2 "behind" cards
- Offset: (2px, 2px) and (4px, 4px)
- Opacity: 0.35 and 0.20

This is deferred because:
1. Requires passing `draggedExpandedIds` to `RenderEngine`
2. Needs mechanism to skip rendering dragged nodes in place
3. Needs separate overlay layer for ghost rendering
4. More complex than other Phase 4 tasks

---

## Summary

Phase 4 is primarily a **styling refinement phase**. The core functionality (drop preview computation, indicator positioning, reflow) is already working from Phase 3.

**Key changes:**
1. Fine-tune indicator styling to match Figma spec
2. Update drop zone from green to accent blue with spec styling
3. Add subtle animations for polish
4. Optionally add debug overlay for development

**Estimated effort:** Medium (mostly paint code changes, one animation addition)

**Risk level:** Low (visual changes only, no logic changes)
