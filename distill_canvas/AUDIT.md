# Distill Canvas Package Audit Report

**Date:** 2026-01-23
**Auditor:** Claude Opus 4.5
**Package Version:** Current main branch

## Executive Summary

The `distill_canvas` package is a well-architected, focused package (~5,000 lines) that provides a high-performance infinite canvas for Flutter. It demonstrates excellent separation of concerns, proper memory management, and good documentation. However, there are several areas for improvement around performance optimization, API simplification, and test coverage.

**Overall Quality: B+** — Solid foundation with room for improvement in specific areas.

**Key Finding from Editor Integration**: Analysis of `distill_editor` (the primary consumer) reveals several API gaps that required significant workarounds, including custom gesture handling for tap latency, 350+ lines of custom drag/drop infrastructure, and manual viewport culling. See Section 8 for details.

---

## 1. Architecture & Design (Score: 8/10)

### Strengths

- **Clear responsibility boundaries**: The package handles only viewport mechanics and gesture routing, deliberately excluding domain-specific logic
- **Layered rendering system**: 4-layer architecture (background → content → overlay → debug) with appropriate transform behaviors
- **Clean public API**: Two entry points (`infinite_canvas.dart` and `utilities.dart`) with minimal, well-organized exports
- **Zero external dependencies**: Only Flutter SDK and `dart:collection`

### Issues

#### 1.1 God Class: `InfiniteCanvasController` (1,149 lines)

The controller handles too many responsibilities:
- Viewport state management
- Animation/momentum simulation
- Zoom level semantics
- Geometry calculations
- 4+ ValueNotifier management

**Recommendation**: Extract momentum simulation and zoom level management into separate classes.

#### 1.2 Large Widget State: `_InfiniteCanvasState` (~900 lines)

Gesture handling is tightly integrated with widget state:
- 15+ gesture state variables
- 8+ trackpad state variables
- Complex method interactions

**Recommendation**: Extract gesture handling into a dedicated `CanvasGestureHandler` class.

---

## 2. Performance (Score: 7/10)

### Strengths

- Transform matrix properly cached in `lib/src/_internal/viewport.dart:22`
- CustomPainters have correct `shouldRepaint()` implementations
- Grid/dot painters have LOD and safety caps (500 lines max, 10,000 dots max)
- Memory management is excellent (all listeners/subscriptions properly disposed)

### Critical Issues

#### 2.1 Excessive `notifyListeners()` Calls

During continuous pan/zoom gestures (60+ fps), `notifyListeners()` is called on every frame:

| Location | Method | Impact |
|----------|--------|--------|
| `infinite_canvas_controller.dart:437` | `panBy()` | Every pan delta |
| `infinite_canvas_controller.dart:463` | `setZoom()` | Every zoom change |
| `infinite_canvas_controller.dart:707` | Momentum listener | Every animation frame |
| `infinite_canvas_controller.dart:1080` | Animation listener | Every animation frame |

**Impact**: Entire layer stack rebuilds 60+ times per second during gestures.

#### 2.2 Single ListenableBuilder for All Layers

In `infinite_canvas.dart:400-439`, all four layers share one `ListenableBuilder`:

```dart
ListenableBuilder(
  listenable: _controller,
  builder: (context, _) {
    // ALL layers rebuild here
    background(context, _controller);
    content(context, _controller);  // Called every frame during gestures
    overlay(context, _controller);
    debug(context, _controller);
  },
)
```

**Recommendations**:
1. Consider throttling/debouncing viewport notifications during gestures
2. Use separate `ListenableBuilder`s for content vs. overlay layers
3. Document that content layer builders should be efficient (cull aggressively)

---

## 3. API Design & Maintainability (Score: 7/10)

### Strengths

- Consistent naming conventions (`Canvas*` prefix, `viewToWorld`/`worldToView` clarity)
- Strong null safety usage
- Excellent dartdoc coverage with examples
- No circular dependencies, clean layering

### Issues

#### 3.1 Code Duplication in SnapEngine

Near-identical snap candidate classes in `snap_engine.dart:604-638`:

```dart
class _SnapCandidate { ... }
class _ResizeSnapCandidate { ... }  // 95% identical
```

**Recommendation**: Extract common `_BaseSnapCandidate` class.

#### 3.2 Duplicated Motion State Notifiers

Four identical ValueNotifier declarations in `infinite_canvas_controller.dart:90-93`:

```dart
final ValueNotifier<bool> _isPanningNotifier = ValueNotifier(false);
final ValueNotifier<bool> _isZoomingNotifier = ValueNotifier(false);
final ValueNotifier<bool> _isAnimatingNotifier = ValueNotifier(false);
final ValueNotifier<bool> _isDeceleratingNotifier = ValueNotifier(false);
```

**Recommendation**: Use a `Map<MotionState, ValueNotifier<bool>>` or factory method.

#### 3.3 Magic Numbers

Scattered throughout the codebase without named constants:

| Value | Location | Purpose |
|-------|----------|---------|
| `16` | `canvas_gesture_config.dart:92` | Hover throttle ms |
| `0.25` | `infinite_canvas.dart:257` | Velocity alpha filter |
| `0.001` | `infinite_canvas.dart:258` | Velocity epsilon |
| `0.002` | `infinite_canvas.dart:840` | Scroll zoom factor |

**Recommendation**: Extract to named constants with documentation.

#### 3.4 Tight Coupling: State ↔ Controller

The widget state directly manages controller lifecycle (`infinite_canvas.dart:276-312`):
- Complex attach/detach logic
- Controller swapping in `didUpdateWidget`
- TickerProvider passed during attach (not at construction)

**Recommendation**: Consider a factory pattern for controller creation.

#### 3.5 Deprecated API Usage

In `viewport.dart:54`:
```dart
// ignore: deprecated_member_use
..scale(_zoom, _zoom);
```

---

## 4. Test Coverage (Score: 6/10)

### Well-Tested Areas (90%+ coverage)

| Component | Test File | Tests |
|-----------|-----------|-------|
| CanvasViewport | `viewport_test.dart` | 91 tests |
| SnapEngine | `snap_engine_test.dart` | 41 tests |
| QuadTree | `spatial_index_test.dart` | 37 tests |
| ZoomLevel | `zoom_level_test.dart` | 45 tests |
| Config classes | `*_config_test.dart` | ~70 tests |

### Critical Gaps

#### 4.1 Untested: Gesture Handling
No tests for:
- Tap, double-tap, long-press gestures
- Pan mechanics (spacebar, middle mouse, drag)
- Zoom mechanics (scroll, pinch, Cmd+scroll)
- Touch vs mouse vs trackpad differences

#### 4.2 Untested: Momentum Simulation
The entire momentum system (`infinite_canvas_controller.dart:628-793`) has zero tests:
- `startMomentum()`
- `startMomentumWithFloor()`
- Deceleration behavior
- Boundary collision during momentum

#### 4.3 Untested: Animation Interruption
No tests for:
- Pan while animating
- Zoom while panning
- Animation interrupted by user gesture

#### 4.4 Untested: Error Conditions
Missing validation tests for:
- Invalid configurations
- Null viewport size before operations
- Exception handling

#### 4.5 Untested: GridBackground Widget
No test file exists for `grid_background.dart`.

### Coverage Estimates

| Category | Statement | Branch |
|----------|-----------|--------|
| Configuration Classes | 95% | 90% |
| Utilities (Snap, QuadTree) | 90% | 85% |
| Coordinate Conversions | 95% | 95% |
| Controller Operations | 45% | 30% |
| Widget/Gesture Integration | 20% | 15% |
| Animation/Momentum | 30% | 20% |
| Error Handling | 5% | 5% |
| **Overall** | **~50%** | **~30%** |

---

## 5. Scalability Considerations

### Current Limitations

1. **Linear rebuild**: All content rebuilds on every viewport change
2. **No built-in virtualization**: Apps must implement their own culling
3. **Single content callback**: Can't easily have different update strategies for different content types

### Recommendations

1. **Document best practices** for content layer implementation:
   - Use `cullToVisible()` aggressively
   - Memoize expensive computations
   - Consider `RepaintBoundary` for static elements

2. **Consider adding**:
   - Optional render throttling during gestures
   - Built-in virtualization for common cases
   - Separate `ValueListenable<Rect>` for visible bounds changes

---

## 6. Prioritized Recommendations

### High Priority (Fix Now)

1. **Add momentum/animation tests** — Critical for UX, completely untested
2. **Add gesture handling tests** — Core functionality untested
3. **Document content layer performance requirements** — Users need guidance
4. **Document gesture latency tradeoffs** — Editor works around ~300ms tap delay (§8.2.1)
5. **Add `shouldHandleScroll` callback** — Editor needs conditional scroll handling (§8.2.2)

### Medium Priority (Next Sprint)

6. **Extract momentum simulation** from controller (reduce 1149→900 lines)
7. **Extract gesture handler** from widget state (reduce 924→600 lines)
8. **Replace magic numbers** with named constants
9. **Unify snap candidate classes**
10. **Add `isInMotion` ValueListenable** — Enable LOD optimization (§8.3.5)
11. **Provide `CanvasOverlayWidget` base class** — Reduce coordinate conversion boilerplate (§8.5)
12. **Document drag/drop patterns** — Help consumers build custom drop systems (§8.4)

### Low Priority (Technical Debt)

13. **Consider viewport notification throttling** for better performance
14. **Add separate ListenableBuilders** for different layer update frequencies
15. **Fix deprecated Matrix4.scale() usage**
16. **Add GridBackground tests**
17. **Add InitialViewport strategy tests**
18. **Consider structured drag events** — Include target info, hover duration (§8.4)
19. **Consider bounds registration API** — Optional child bounds tracking (§8.3.1)
20. **Document multi-coordinate system patterns** — Help complex consumers (§8.3.3)

---

## 7. Summary

| Area | Score | Key Finding |
|------|-------|-------------|
| Architecture | 8/10 | Clean design, but god classes emerging |
| Performance | 7/10 | Good foundations, excessive rebuilds during gestures |
| API Design | 7/10 | Consistent naming, some duplication and coupling |
| Test Coverage | 6/10 | Config/utility excellent, widget/gesture poor |
| Documentation | 9/10 | Excellent dartdoc and architecture docs |
| Memory Management | 9/10 | Proper disposal throughout |
| Consumer Integration | 6/10 | Significant workarounds needed in editor (see §8) |

The package is production-quality with solid fundamentals. The main areas needing attention are:
1. **Test coverage** for gestures, momentum, and animations
2. **Performance** during continuous gesture interactions
3. **Code organization** to prevent god classes from growing further
4. **API gaps** revealed by editor integration (see Section 8)

---

## 8. Consumer Integration Analysis (distill_editor)

This section examines how `distill_editor` uses `distill_canvas` to identify API gaps and workarounds that indicate improvement opportunities.

### 8.1 Integration Overview

The canvas package is imported in **17 files** across the editor. The editor has built significant custom infrastructure around the canvas:

```
distill_editor/lib/src/free_design/canvas/
├── drag/                     # Custom drag/drop system (7 files, 1000+ lines)
├── widgets/                  # Custom canvas UI (9 files)
└── frame_renderer.dart       # Custom frame rendering
```

### 8.2 Workarounds Implemented

#### 8.2.1 Custom Gesture System (Tap Latency)

**Problem**: Canvas's gesture system has ~300ms delay when both `onTap` and `onDoubleTap` are configured.

**Editor Workaround** (`free_design_canvas.dart:30-31`):
```dart
// Uses Listener pattern to avoid the ~300ms tap delay
// that occurs when both onTap and onDoubleTap are present.
Listener(
  onPointerDown: _handlePointerDown,
  child: InfiniteCanvas(...)
)
```

The editor implements custom double-tap detection with its own timing and distance thresholds.

**Recommendation**: Consider providing a `fastTapMode` option or exposing raw pointer events alongside gesture callbacks.

#### 8.2.2 Conditional Scroll Handling

**Problem**: Canvas doesn't support per-region scroll handling (e.g., letting frame content scroll while canvas pans elsewhere).

**Editor Workaround** (`free_design_canvas.dart:1072-1080`):
```dart
bool _shouldHandleScroll(Offset viewPos) {
  final frameTarget = _controller.hitTestFrame(worldPos);
  if (frameTarget != null &&
      widget.state.isInteractMode(frameTarget.frameId)) {
    return false;  // Let frame content handle scroll
  }
  return true;
}
```

**Recommendation**: Add `shouldHandleScroll` callback to `CanvasGestureConfig`.

#### 8.2.3 Overlay Outside Canvas

**Problem**: Canvas's Listener intercepts pointer events meant for overlays.

**Editor Workaround** (`free_design_canvas.dart:222-223`):
```dart
// PromptBoxOverlay is rendered outside the canvas in CanvasCenterContent
// so that pointer events work correctly (not intercepted by canvas Listener)
```

**Recommendation**: Document pointer event behavior clearly; consider providing passthrough zones.

### 8.3 Missing Capabilities

#### 8.3.1 Bounds Tracking

**Gap**: Canvas doesn't track bounds of child elements within frames.

**Editor Implementation** (`frame_renderer.dart`):
```dart
// Uses GlobalKey + custom RenderEngine to track node bounds
final _frameRootKey = GlobalKey();

RenderEngine(
  frameRootKey: _frameRootKey,
  onBoundsChanged: (nodeId, bounds) {
    widget.state.updateNodeBounds(widget.frameId, nodeId, bounds);
  },
)
```

**Recommendation**: Consider optional bounds reporting callback or integration with spatial index.

#### 8.3.2 Structured Hit Testing

**Gap**: Canvas provides position-only hit testing; editor needs structured hit test results.

**Editor Implementation** (`canvas_state.dart:1471-1483`):
```dart
// Custom QuadTree for O(log n) frame hit testing
final QuadTree<String> _frameSpatialIndex;

void _rebuildSpatialIndex() {
  _frameSpatialIndex.clear();
  for (final frame in document.frames.values) {
    _frameSpatialIndex.insert(frame.id, bounds);
  }
}
```

**Note**: Canvas exports `QuadTree` in utilities, which is good. However, the canvas doesn't use it internally for content hit testing.

**Recommendation**: Document spatial indexing best practices; consider built-in content registration.

#### 8.3.3 Multi-Domain Coordinate Systems

**Gap**: Canvas provides world/view coordinates only; editor needs document, expanded-tree, and rendered coordinates.

**Editor Implementation** (`drop_preview_builder.dart`):
```dart
typedef BoundsResolver = Rect? Function(String frameId, String expandedId);
typedef FramePositionResolver = Offset Function(String frameId);
typedef ContainerHitResolver = ContainerHit? Function(
  String frameId,
  Offset worldPos,
  Set<String> excludeExpandedIds,
);
```

**Recommendation**: This is domain-specific and appropriately handled by the editor. However, documenting coordinate system extension patterns would help other consumers.

#### 8.3.4 Viewport Culling

**Gap**: Canvas renders all children; doesn't provide automatic culling.

**Editor Implementation** (`free_design_canvas.dart:157-164`):
```dart
final viewportSize = MediaQuery.sizeOf(context);
final visible = ctrl.getVisibleWorldBounds(viewportSize);

final visibleFrames = widget.state.document.frames.values.where(
  (f) => visible.overlaps(f.canvas.bounds),
);
```

**Recommendation**: Already noted in Section 5. This confirms the need for built-in virtualization or clearer culling APIs.

#### 8.3.5 Level-of-Detail Callbacks

**Gap**: Canvas doesn't provide LOD callbacks for motion states.

**Editor Implementation** (`frame_renderer.dart:47-50`):
```dart
// Lower fidelity rendering during viewport motion
if (widget.showPlaceholder) {
  return _FramePlaceholder(frame: frame);
}
```

**Recommendation**: Add `onMotionStateChanged` callback or `isInMotion` ValueListenable for LOD optimization.

### 8.4 Custom Drag/Drop System

The editor has built a **350+ line drop preview engine** because canvas provides minimal drag support:

| Canvas Provides | Editor Built |
|-----------------|--------------|
| `onDragStartWorld` callback | Full `DragSession` state machine |
| `onDragUpdateWorld` callback | `DropPreview` model (8+ fields) |
| `onDragEndWorld` callback | `DropPreviewBuilder` computation engine |
| Raw position events | Insertion index calculation with hysteresis |
| — | Reflow animation offset computation |
| — | Drop target validation (8 invariants) |
| — | Multi-domain coordinate bridging |

**Key Invariants** the editor enforces (revealing complexity canvas doesn't address):
- INV-1: Hit test returns expanded ID (rendering domain)
- INV-4: Absolute containers climb to auto-layout ancestor
- INV-7: Multi-select nodes must share same parent
- INV-8: Target must be patchable (not inside instance)

**Recommendation**: This is appropriately domain-specific. However, canvas could provide:
1. More structured drag events (current target, hover duration, etc.)
2. Optional insertion index computation for linear layouts
3. Drop feedback primitives (insertion line, ghost preview)

### 8.5 Custom Overlay Infrastructure

The editor builds **6 custom overlay widgets** instead of using canvas's basic overlay:

```dart
Stack(
  children: [
    DragDebugOverlay(...),
    FreeDesignSnapGuidesOverlay(...),  // Wraps canvas's SnapGuidesOverlay
    MarqueeOverlay(...),
    InsertionIndicatorOverlay(...),
    SelectionOverlay(...),
    ResizeHandles(...),
  ],
)
```

Each overlay duplicates world→view coordinate conversion:
```dart
final viewBounds = controller.worldToViewRect(bounds);
```

**Recommendation**: Consider providing a `CanvasOverlayWidget` base class that handles coordinate transformation automatically.

### 8.6 API Gap Summary

| Capability | Canvas Support | Editor Workaround Complexity |
|------------|----------------|------------------------------|
| Fast tap (no double-tap delay) | ❌ | Medium (custom Listener) |
| Conditional scroll handling | ❌ | Low (callback injection) |
| Bounds tracking | ❌ | High (custom RenderEngine) |
| Structured hit testing | ❌ | Medium (custom QuadTree usage) |
| Viewport culling | ❌ | Low (manual filtering) |
| LOD during motion | ❌ | Low (boolean prop) |
| Drop feedback UI | ❌ | High (350+ line engine) |
| Overlay coordinate helpers | ❌ | Low (repeated conversion) |

### 8.7 Recommendations from Integration Analysis

**Add to High Priority**:
1. **Document gesture latency tradeoffs** — Users need to know about tap/double-tap delay
2. **Add `shouldHandleScroll` callback** — Common need for nested scrollables

**Add to Medium Priority**:
3. **Add `isInMotion` ValueListenable** — Enable LOD optimization
4. **Provide `CanvasOverlayWidget` base class** — Reduce coordinate conversion boilerplate
5. **Document drag/drop patterns** — Help consumers build custom drop systems

**Add to Low Priority**:
6. **Consider structured drag events** — Include target info, hover duration
7. **Consider bounds registration API** — Optional child bounds tracking
8. **Document multi-coordinate system patterns** — Help complex consumers
