# distill_canvas

A high-performance, infinite pannable/zoomable canvas for Flutter.

## Features

- **High Performance** — Culling helpers, motion state for LOD, 60fps
- **Precise Gestures** — Pan, zoom, tap, drag, hover in world coordinates  
- **Layered Rendering** — Background, content, overlay, debug layers
- **Coordinate Math** — World ↔ View conversion built-in
- **Animated Camera** — Smooth transitions, focus-on-content, center-on
- **Configurable** — Gesture behavior, physics limits, initial viewport

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:distill_canvas/infinite_canvas.dart';

class MyCanvas extends StatefulWidget {
  @override
  State<MyCanvas> createState() => _MyCanvasState();
}

class _MyCanvasState extends State<MyCanvas> {
  final _controller = InfiniteCanvasController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InfiniteCanvas(
      controller: _controller,
      layers: CanvasLayers(
        background: (ctx, ctrl) => DotBackground(controller: ctrl),
        content: (ctx, ctrl) => _buildContent(ctrl),
      ),
      onTapWorld: (worldPos) => print('Tapped at $worldPos'),
      onDragUpdateWorld: (details) => print('Dragged by ${details.worldDelta}'),
    );
  }

  Widget _buildContent(InfiniteCanvasController ctrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CanvasItem(
          position: const Offset(100, 100),
          child: Container(
            width: 200,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('Hello Canvas!')),
          ),
        ),
      ],
    );
  }
}
```

## Documentation

- [Getting Started](doc/getting_started.md) — Installation and basic usage
- [Architecture](doc/architecture.md) — How the canvas works
- [API Reference](https://pub.dev/documentation/distill_canvas/latest/) — Full API docs

## Core Concepts

### Layers

The canvas renders four layers from bottom to top:

| Layer | Transform | Use For |
|-------|-----------|---------|
| `background` | World-space | Grid, dots, canvas texture |
| `content` | World-space | Your nodes, shapes, objects |
| `overlay` | Screen-space | Selection UI, tooltips, handles |
| `debug` | Screen-space | Debug visualization |

### Coordinate Systems

| System | Description |
|--------|-------------|
| **World** | Infinite canvas coordinates (where objects live) |
| **View** | Screen pixel coordinates (where user sees) |

```dart
// Convert between them
final worldPos = controller.viewToWorld(screenTapPosition);
final screenPos = controller.worldToView(nodePosition);
```

### Gesture Callbacks

All gesture callbacks report positions in **world coordinates**:

```dart
InfiniteCanvas(
  onTapWorld: (Offset worldPos) { },
  onDoubleTapWorld: (Offset worldPos) { },
  onLongPressWorld: (Offset worldPos) { },
  onDragStartWorld: (CanvasDragStartDetails details) { },
  onDragUpdateWorld: (CanvasDragUpdateDetails details) { },
  onDragEndWorld: (CanvasDragEndDetails details) { },
  onHoverWorld: (Offset worldPos) { },
  onHoverExitWorld: () { },
)
```

## Philosophy

This package is a **pure viewport + gesture surface**. It does not manage:

- Object/node data models
- Selection state  
- Hit testing logic
- Connection rendering

These belong in your application layer. The canvas reports gestures in world coordinates; your app decides what they mean.

## API Overview

### InfiniteCanvasController

```dart
final controller = InfiniteCanvasController();

// Viewport state
controller.zoom;              // Current zoom level
controller.pan;               // Current pan offset
controller.viewportSize;      // Viewport dimensions

// Coordinate conversion
controller.viewToWorld(screenPos);
controller.worldToView(worldPos);
controller.getVisibleWorldBounds(viewportSize);

// Camera control
controller.setZoom(2.0);
controller.setPan(Offset(100, 100));
controller.panBy(Offset(50, 0));
controller.zoomIn();
controller.zoomOut();
controller.reset();

// Animated camera
await controller.animateTo(zoom: 1.5, pan: Offset.zero);
await controller.focusOn(nodeRect, padding: EdgeInsets.all(50));
await controller.animateToCenterOn(point, zoom: 1.0);

// Motion state (for LOD)
controller.isPanning;
controller.isZooming;
controller.isAnimating;
controller.isInMotion;

// Zoom level (for LOD)
controller.currentZoomLevel;      // ZoomLevel.overview, .normal, or .detail
controller.zoomLevel;             // ValueListenable<ZoomLevel>

// Culling
final visible = controller.cullToVisible(allNodes, (n) => n.bounds, viewportSize);
```

### Configuration

```dart
InfiniteCanvas(
  // Initial viewport positioning
  initialViewport: InitialViewport.fitContent(
    () => editorState.allNodesBounds,
    fallback: InitialViewport.centerOrigin(),
  ),
  
  // Gesture behavior
  gestureConfig: CanvasGestureConfig(
    enablePan: true,
    enableZoom: true,
    enableSpacebarPan: true,
    dragThreshold: 5.0,
    touchDragThreshold: 10.0,  // Higher threshold for touch input
  ),
  
  // Physics limits
  physicsConfig: CanvasPhysicsConfig(
    minZoom: 0.1,
    maxZoom: 5.0,
    panBounds: Rect.fromLTWH(0, 0, 2000, 2000),  // Constrain panning
  ),
)
```

## Utilities (Optional)

For applications with many objects, import the optional utilities:

```dart
import 'package:distill_canvas/utilities.dart';
```

### Spatial Index

O(log n) hit testing and culling with `QuadTree`:

```dart
// Initialize with world bounds
final spatialIndex = QuadTree<String>(
  const Rect.fromLTWH(-10000, -10000, 20000, 20000),
);

// Insert/update objects
spatialIndex.insert(node.id, node.bounds);
spatialIndex.update(node.id, newBounds);
spatialIndex.remove(node.id);

// Query visible region (for culling)
final visibleIds = spatialIndex.query(controller.getVisibleWorldBounds(viewportSize));

// Hit test at point
final candidates = spatialIndex.hitTest(tapPosition);
```

### Snap Engine

Figma-style smart guides and alignment snapping:

```dart
final snapEngine = const SnapEngine(
  threshold: 8.0,          // Snap threshold in screen pixels
  enableEdgeSnap: true,    // Snap to object edges
  enableCenterSnap: true,  // Snap to object centers
  gridSize: 25.0,          // Optional grid snap (fallback)
);

// During drag, calculate snap
final result = snapEngine.calculate(
  movingBounds: draggedObject.bounds,
  otherBounds: nearbyObjects.map((o) => o.bounds),
  zoom: controller.zoom,
);

// Apply snapped position
draggedObject.bounds = result.snappedBounds;

// Render guides in overlay layer
SnapGuidesOverlay(
  guides: result.guides,
  controller: controller,
  color: const Color(0xFFFF00FF),
)
```

Combine spatial index with snap engine for best performance:

```dart
// Query only nearby objects for snapping
final searchRegion = intendedBounds.inflate(snapEngine.threshold / zoom * 2);
final nearbyIds = spatialIndex.query(searchRegion);
final nearbyBounds = nearbyIds.map((id) => objects[id].bounds);

final result = snapEngine.calculate(
  movingBounds: intendedBounds,
  otherBounds: nearbyBounds,  // O(k) where k ≈ 5-10
  zoom: controller.zoom,
);
```

### Zoom Level LOD

Semantic zoom levels for level-of-detail switching with hysteresis to prevent flickering:

```dart
// Configure thresholds (optional - has sensible defaults)
controller.setZoomThresholds(const ZoomThresholds(
  overviewBelow: 0.25,  // Below 25% zoom → overview
  detailAbove: 3.0,     // Above 300% zoom → detail  
  hysteresis: 0.05,     // 5% band to prevent flickering
));

// Simple check in builder (rebuilds with controller)
content: (ctx, ctrl) => switch (ctrl.currentZoomLevel) {
  ZoomLevel.overview => SimplifiedContent(),
  ZoomLevel.normal => NormalContent(),
  ZoomLevel.detail => DetailedContent(),
};

// Isolated rebuilds (only when level changes)
overlay: (ctx, ctrl) => ValueListenableBuilder<ZoomLevel>(
  valueListenable: ctrl.zoomLevel,
  builder: (context, level, _) => level == ZoomLevel.detail
    ? PixelGridOverlay()
    : const SizedBox.shrink(),
);
```

The hysteresis band prevents rapid switching when zoom hovers near a threshold:

```
Zoom:    0.20 ──── 0.25 ──── 0.30 ──── 0.35
                    │         │
         OVERVIEW   │◄──band──►│  NORMAL
                    │         │
         Enter at 0.20        Exit at 0.30 (hysteresis=0.05)
```

Level changes are also deferred during active zoom gestures to avoid jarring switches mid-pinch.

