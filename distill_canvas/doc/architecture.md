# Architecture

This document explains how Infinite Canvas works internally.

## Design Philosophy

The canvas is a **pure viewport + gesture surface**. It handles:

- Camera/viewport math (pan, zoom, transform matrix)
- Gesture recognition and routing
- Layered rendering surfaces
- World-coordinate event reporting

It does NOT handle:

- Object/node data models
- Selection state
- Hit testing logic
- Domain-specific rendering (connections, handles, etc.)

This separation keeps the canvas reusable across different use cases:
- Design tools (Figma-like)
- Node editors (workflow builders)
- Storyboard viewers
- Map/image viewers

---

## Component Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      InfiniteCanvas                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ GestureDetector │  │    Listener     │  │ LayoutBuilder│ │
│  │  (tap, double,  │  │  (pointer,      │  │  (viewport   │ │
│  │   long press)   │  │   pan/zoom)     │  │   size)      │ │
│  └────────┬────────┘  └────────┬────────┘  └──────┬───────┘ │
│           │                    │                   │         │
│           └────────────────────┼───────────────────┘         │
│                                ▼                             │
│                    InfiniteCanvasController                  │
│                    ┌──────────────────────┐                  │
│                    │   CanvasViewport     │                  │
│                    │  - zoom, pan         │                  │
│                    │  - transform matrix  │                  │
│                    │  - coord conversion  │                  │
│                    └──────────────────────┘                  │
│                                │                             │
│                                ▼                             │
│                         Layer Stack                          │
│              ┌────────────────────────────────┐              │
│              │  Transform(matrix)             │              │
│              │    └── background layer        │              │
│              │    └── content layer           │              │
│              │  overlay layer (no transform)  │              │
│              │  debug layer (no transform)    │              │
│              └────────────────────────────────┘              │
└──────────────────────────────────────────────────────────────┘
```

---

## The Viewport Model

The viewport is defined by two values:

| Property | Description |
|----------|-------------|
| `zoom` | Scale factor (1.0 = 100%) |
| `pan` | Offset where world origin appears in view space |

The transform matrix combines these:

```dart
Matrix4.identity()
  ..translate(pan.dx, pan.dy)
  ..scale(zoom, zoom, 1.0)
```

### Coordinate Conversion

```dart
// View → World: "Where in the canvas did they click?"
Offset viewToWorld(Offset viewPoint) => (viewPoint - pan) / zoom;

// World → View: "Where on screen should I draw this?"
Offset worldToView(Offset worldPoint) => (worldPoint * zoom) + pan;
```

### Visible Bounds

```dart
// Get the world-space rectangle currently visible in the viewport
Rect getVisibleWorldBounds(Size viewportSize) {
  return Rect.fromLTWH(
    -pan.dx / zoom,
    -pan.dy / zoom,
    viewportSize.width / zoom,
    viewportSize.height / zoom,
  );
}
```

---

## Layer System

The canvas renders four layers from bottom to top:

```
┌─────────────────────────────────┐
│  debug (screen-space)           │  Optional debugging overlay
├─────────────────────────────────┤
│  overlay (screen-space)         │  Selection UI, tooltips, HUD
├─────────────────────────────────┤
│  content (world-space)          │  Your nodes, shapes, objects
├─────────────────────────────────┤
│  background (world-space)       │  Grid, dots, canvas texture
└─────────────────────────────────┘
```

### World-Space Layers (background, content)

These are wrapped in a `Transform` widget with the camera matrix. Objects stay in place as you pan/zoom — the transform moves the entire layer.

```dart
Transform(
  transform: controller.transform,
  child: backgroundLayer,
)
```

### Screen-Space Layers (overlay, debug)

These are NOT transformed. Use for UI that should stay fixed on screen (selection handles, tooltips, HUD elements).

To position screen-space UI at a world location, convert coordinates:

```dart
// In overlay layer
Positioned(
  left: controller.worldToView(node.position).dx,
  top: controller.worldToView(node.position).dy,
  child: SelectionHandle(),
)
```

---

## Gesture Flow

```
User Input
    │
    ▼
┌─────────────────────────────────────────┐
│  Is this a viewport gesture?            │
│  (spacebar+drag, middle mouse, scroll)  │
└─────────────────┬───────────────────────┘
                  │
         ┌───────┴───────┐
         │               │
        YES              NO
         │               │
         ▼               ▼
┌─────────────────┐  ┌─────────────────────┐
│  Update         │  │  Convert to world   │
│  pan/zoom       │  │  coordinates        │
│                 │  │                     │
│  Notify         │  │  Fire callback:     │
│  listeners      │  │  onTapWorld, etc.   │
└─────────────────┘  └─────────────────────┘
```

### Viewport Gestures (handled internally)

| Gesture | Trigger |
|---------|---------|
| Pan | Drag on empty area, spacebar+drag, middle mouse |
| Zoom | Scroll wheel, trackpad pinch, Cmd/Ctrl+scroll |

### Domain Gestures (reported via callbacks)

| Callback | When |
|----------|------|
| `onTapWorld` | Single tap |
| `onDoubleTapWorld` | Double tap |
| `onLongPressWorld` | Long press |
| `onDragStartWorld` | Drag begins |
| `onDragUpdateWorld` | Drag continues |
| `onDragEndWorld` | Drag ends |
| `onHoverWorld` | Pointer moves (desktop) |
| `onHoverExitWorld` | Pointer leaves canvas |

---

## Motion State

The controller tracks motion state for performance optimization:

```dart
controller.isPanning    // User is dragging to pan
controller.isZooming    // User is zooming (scroll, pinch)
controller.isAnimating  // Programmatic animation in progress
controller.isInMotion   // Any of the above
```

### LOD (Level of Detail) Switching

Use motion state to simplify rendering during interaction:

```dart
ListenableBuilder(
  listenable: controller.isInMotionListenable,
  builder: (context, _) {
    return controller.isInMotion
      ? SimplifiedPreview()    // Fast, low-detail rendering
      : FullDetailContent();   // Complete rendering
  },
)
```

Common patterns:
- Hide text labels during pan/zoom
- Use placeholder rectangles instead of complex widgets
- Reduce connection line quality
- Skip expensive shadows/effects

---

## Initial Viewport

The `InitialViewport` system positions the camera on first layout:

```dart
InfiniteCanvas(
  initialViewport: InitialViewport.fitContent(
    () => editorState.allNodesBounds,
    padding: EdgeInsets.all(50),
    fallback: InitialViewport.centerOrigin(),
  ),
)
```

| Strategy | Behavior |
|----------|----------|
| `topLeft()` | Origin at top-left (default) |
| `centerOrigin()` | Origin centered in viewport |
| `centerOn(point)` | Center on specific world point |
| `fitRect(rect)` | Fit bounds with padding |
| `fitContent(callback)` | Fit dynamic content with fallback |

This is calculated **once** during first layout. After that, use controller methods.

### Custom Strategies

`InitialViewport` is an abstract class — you can create custom strategies:

```dart
class RestoreLastViewport extends InitialViewport {
  const RestoreLastViewport(this.savedPan, this.savedZoom);
  
  final Offset savedPan;
  final double savedZoom;

  @override
  InitialViewportState calculate(Size viewportSize, CanvasPhysicsConfig physics) {
    return InitialViewportState(
      pan: savedPan,
      zoom: physics.clampZoom(savedZoom),
    );
  }
}

// Usage: restore from persisted state
InfiniteCanvas(
  initialViewport: RestoreLastViewport(
    prefs.getOffset('lastPan') ?? Offset.zero,
    prefs.getDouble('lastZoom') ?? 1.0,
  ),
)
```

---

## Bounded Panning

The `CanvasPhysicsConfig.panBounds` option constrains panning to keep the viewport within specified world-space bounds.

```dart
InfiniteCanvas(
  physicsConfig: CanvasPhysicsConfig(
    panBounds: Rect.fromLTWH(0, 0, 2000, 1500),
  ),
)
```

### Behavior

- Pan gestures, animations, and programmatic calls all respect bounds
- When the viewport is larger than the bounds (zoomed out), content is centered
- Zoom operations with focal points automatically clamp the resulting pan

### Implementation

The controller applies `_clampPan()` to all pan-modifying operations:

```dart
Offset _clampPan(Offset pan) {
  final size = _lastKnownViewportSize;
  if (size == null) return pan;
  return _physics.clampPan(pan, _viewport.zoom, size);
}
```

This ensures consistent bounds enforcement across:
- `panBy()`, `setPan()`
- `setZoom()` with focal point
- `centerOn()`, `fitToRect()`
- `animateTo()`, `animateToCenterOn()`

---

## Background Patterns

The package includes two built-in background patterns:

| Pattern | Description |
|---------|-------------|
| `GridBackground` | Line grid with adaptive LOD |
| `DotBackground` | Figma-style dot grid |

Both adapt to zoom level automatically (spacing doubles when lines/dots would be too dense).

```dart
// Simple usage
background: (ctx, ctrl) => DotBackground(controller: ctrl),

// Zoom-dependent switching
background: (ctx, ctrl) => ctrl.zoom < 0.5
  ? GridBackground(controller: ctrl, spacing: 100)
  : DotBackground(controller: ctrl, spacing: 20),
```

---

## Performance Considerations

### Culling

Only render objects that are visible:

```dart
Widget _buildContent(InfiniteCanvasController ctrl) {
  final viewportSize = ctrl.viewportSize ?? Size.zero;
  
  final visibleNodes = ctrl.cullToVisible(
    allNodes,
    (node) => node.bounds,
    viewportSize,
  );
  
  return Stack(
    clipBehavior: Clip.none,
    children: visibleNodes.map((node) => CanvasItem(
      key: ValueKey(node.id),
      position: node.position,
      child: NodeWidget(node),
    )).toList(),
  );
}
```

### Widget Keys

Use stable keys for canvas items to help Flutter diff efficiently:

```dart
CanvasItem(
  key: ValueKey(node.id),  // Stable identity
  position: node.position,
  child: NodeWidget(node),
)
```

### Transform Caching

The controller caches the transform matrix and only rebuilds it when pan/zoom changes. Don't access `transform` in tight loops during paint — it's already cached.

### Hover Throttling

Hover events are throttled by default (configurable via `hoverThrottleMs`) to prevent excessive rebuilds on desktop platforms with high-frequency pointer events.

---

## Optional Utilities

The package includes optional utilities for common performance optimizations. Import separately:

```dart
import 'package:distill_canvas/utilities.dart';
```

### Spatial Index

`QuadTree` enables O(log n) operations for hit testing and visibility culling:

```
┌─────────────────────────────────────────────────┐
│  Without Spatial Index (O(n))                   │
│  ─────────────────────────────────────────────  │
│  for (final obj in objects) {                   │
│    if (obj.bounds.contains(point)) return obj;  │
│  }                                              │
│  At 1000 objects: ~1ms per hit test             │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  With QuadTree (O(log n))                       │
│  ─────────────────────────────────────────────  │
│  candidates = spatialIndex.hitTest(point);      │
│  At 1000 objects: ~0.05ms per hit test          │
└─────────────────────────────────────────────────┘
```

**Note:** Items outside the QuadTree's initial bounds won't be indexed. Use generous bounds like `Rect.fromLTWH(-10000, -10000, 20000, 20000)`.

### Snap Engine

`SnapEngine` calculates Figma-style alignment snapping:

```
┌─────────────────────────────────────────────────┐
│  SnapEngine Modes                               │
│  ─────────────────────────────────────────────  │
│  • Edge snap: align left/right/top/bottom edges │
│  • Center snap: align center points             │
│  • Grid snap: fallback to grid alignment        │
│                                                 │
│  Priority: Object snap > Grid snap              │
└─────────────────────────────────────────────────┘
```

**Best practice:** Combine with spatial index for performance:

```dart
// Query nearby objects only (not all objects)
final searchRegion = bounds.inflate(threshold / zoom * 2);
final nearbyIds = spatialIndex.query(searchRegion);

// Snap against k nearby objects (k ≈ 5-10) instead of n total
final result = snapEngine.calculate(
  movingBounds: bounds,
  otherBounds: nearbyIds.map((id) => objects[id].bounds),
  zoom: zoom,
);
```

---

## Ownership Boundary

### Canvas Package Owns

```
┌─────────────────────────────────────────────────┐
│  CANVAS PACKAGE                                 │
│  ─────────────────────────────────────────────  │
│  • Viewport math (pan, zoom, transform)         │
│  • Gesture handling (pan/zoom/tap/drag/hover)   │
│  • Coordinate conversion                        │
│  • Rendering surfaces (4 layers)                │
│  • Camera animation                             │
│  • Initial positioning                          │
│  • Culling/visibility helpers                   │
│  • Motion state                                 │
│  • Background patterns (grid, dots)             │
│  • Spatial index (optional utility)             │
│  • Snap engine (optional utility)               │
└─────────────────────────────────────────────────┘
```

### App Layer Owns

```
┌─────────────────────────────────────────────────┐
│  YOUR APPLICATION                               │
│  ─────────────────────────────────────────────  │
│  • Object/node data model                       │
│  • Selection state                              │
│  • Hit testing ("what did they click?")         │
│  • Connections (model + rendering)              │
│  • Resize handles                               │
│  • Layout algorithms                            │
│  • Keyboard shortcuts                           │
│  • Undo/redo                                    │
│  • Persistence                                  │
└─────────────────────────────────────────────────┘
```

This separation keeps the canvas package focused and reusable. Your app provides the domain-specific logic; the canvas provides the viewport surface.

