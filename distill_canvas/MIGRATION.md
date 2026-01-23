# Migration Guide

This document covers changes between versions and how to migrate your code.

## Phase 2 Changes (Internal Refactoring)

**No breaking changes** - This release focused on internal architecture improvements.

### New Public APIs

#### `isInMotionValue` on `InfiniteCanvasController`

A new `ValueListenable<bool>` API that provides isolated rebuilds for motion state:

```dart
// Before (still works):
ListenableBuilder(
  listenable: controller.isInMotionListenable,
  builder: (_, __) => controller.isInMotion
    ? LowFidelityView()
    : HighFidelityView(),
)

// New alternative (more efficient):
ValueListenableBuilder<bool>(
  valueListenable: controller.isInMotionValue,
  builder: (_, isMoving, __) => isMoving
    ? LowFidelityView()
    : HighFidelityView(),
)
```

The `isInMotionValue` notifier fires only when the combined motion state changes, making it more efficient than listening to individual motion notifiers.

#### `CanvasOverlayWidget` Base Class

A new base class for building screen-space overlays:

```dart
class SelectionOverlay extends CanvasOverlayWidget {
  const SelectionOverlay({super.key, required super.controller});

  @override
  Widget buildOverlay(BuildContext context, Rect viewBounds) {
    // viewBounds is the viewport rectangle (0, 0, width, height)
    return CustomPaint(
      size: Size(viewBounds.width, viewBounds.height),
      painter: SelectionPainter(controller),
    );
  }
}

// Usage in overlay layer:
InfiniteCanvas(
  layers: CanvasLayers(
    content: (ctx, ctrl) => MyContent(),
    overlay: (ctx, ctrl) => SelectionOverlay(controller: ctrl),
  ),
)
```

Benefits:
- Handles `ListenableBuilder` boilerplate automatically
- Provides `viewBounds` for sizing overlays
- Returns `SizedBox.shrink()` when viewport size is unavailable

### Internal Architecture Changes

These changes are **internal implementation details** and should not affect normal usage. However, if you were accessing private APIs or internal classes, be aware of:

#### Extracted Classes

1. **`MomentumSimulator`** (`lib/src/_internal/momentum_simulator.dart`)
   - Momentum/friction simulation logic extracted from controller
   - Internal class - not exported

2. **`CanvasGestureHandler`** (`lib/src/_internal/canvas_gesture_handler.dart`)
   - Gesture handling logic extracted from widget state
   - Internal class - not exported

#### Centralized Constants

Magic numbers are now centralized in `CanvasConstants` (`lib/src/canvas_constants.dart`):

- `velocityFilterAlpha` (0.25)
- `velocityEpsilon` (0.001)
- `scrollZoomFactor` (0.002)
- `snapGuideDashLength` (5.0)
- `snapGuideGapLength` (3.0)
- `snapGuideMargin` (10.0)

This is an internal class - use the public configuration APIs (`CanvasGestureConfig`, `CanvasMomentumConfig`, `CanvasPhysicsConfig`) for customization.

#### Unified Snap Candidates

The internal snap candidate classes were unified using a sealed class pattern:

```dart
// Internal implementation detail
sealed class _SnapCandidateBase { ... }
final class _MoveSnapCandidate extends _SnapCandidateBase { ... }
final class _ResizeSnapCandidate extends _SnapCandidateBase { ... }
```

This change has no public API impact.

### Documentation

New documentation added:
- `doc/drag_drop_patterns.md` - Common drag and drop patterns

### Metrics

Line count changes (internal quality metric):
- Widget state: ~900 → 506 lines (-44%)
- Controller: 1149 → 1097 lines (-5%)

## Future Deprecations

None planned.
