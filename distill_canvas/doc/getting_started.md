# Getting Started

This guide walks you through setting up your first infinite canvas.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  canvas: ^0.1.0
```

## Minimal Example

```dart
import 'package:flutter/material.dart';
import 'package:distill_canvas/infinite_canvas.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CanvasDemo());
  }
}

class CanvasDemo extends StatefulWidget {
  const CanvasDemo({super.key});

  @override
  State<CanvasDemo> createState() => _CanvasDemoState();
}

class _CanvasDemoState extends State<CanvasDemo> {
  final _controller = InfiniteCanvasController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InfiniteCanvas(
        controller: _controller,
        layers: CanvasLayers(
          background: (ctx, ctrl) => DotBackground(controller: ctrl),
          content: (ctx, ctrl) => const Center(
            child: Text('Hello, Canvas!', style: TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}
```

This creates a pannable, zoomable canvas with the following interactions:

- **Pan**: Drag anywhere, or hold spacebar + drag
- **Zoom**: Scroll wheel, or trackpad pinch

---

## Understanding Layers

The canvas renders four layers from bottom to top:

```
┌─────────────────────────────────┐
│  debug (screen-space)           │  Optional debugging overlay
├─────────────────────────────────┤
│  overlay (screen-space)         │  Selection UI, tooltips, HUD
├─────────────────────────────────┤
│  content (world-space)          │  Your nodes, shapes, objects
├─────────────────────────────────┤
│  background (world-space)       │  Grid, dots, canvas color
└─────────────────────────────────┘
```

**World-space layers** (background, content) are transformed by the camera. Objects stay in place as you pan/zoom.

**Screen-space layers** (overlay, debug) are NOT transformed. Use these for UI that should stay fixed on screen.

```dart
CanvasLayers(
  background: (ctx, ctrl) => DotBackground(controller: ctrl),
  content: (ctx, ctrl) => MyNodesWidget(),
  overlay: (ctx, ctrl) => SelectionOverlay(),  // Optional
  debug: (ctx, ctrl) => DebugInfo(),           // Optional
)
```

---

## Placing Objects

Use `CanvasItem` to position widgets in world coordinates:

```dart
Widget _buildContent(InfiniteCanvasController ctrl) {
  return Stack(
    clipBehavior: Clip.none,  // Important! Allow objects outside viewport
    children: [
      CanvasItem(
        position: const Offset(0, 0),
        child: _buildNode('Node A', Colors.blue),
      ),
      CanvasItem(
        position: const Offset(250, 100),
        child: _buildNode('Node B', Colors.green),
      ),
    ],
  );
}

Widget _buildNode(String label, Color color) {
  return Container(
    width: 150,
    height: 100,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(child: Text(label)),
  );
}
```

---

## Handling Gestures

All gesture callbacks report positions in **world coordinates**:

```dart
InfiniteCanvas(
  controller: _controller,
  layers: CanvasLayers(...),
  
  // Tap
  onTapWorld: (Offset worldPos) {
    print('Tapped at world position: $worldPos');
    // Your hit-testing logic here
  },
  
  // Drag
  onDragStartWorld: (CanvasDragStartDetails details) {
    print('Drag started at: ${details.worldPosition}');
  },
  onDragUpdateWorld: (CanvasDragUpdateDetails details) {
    print('Dragged by: ${details.worldDelta}');
    // Move your selected objects by details.worldDelta
  },
  onDragEndWorld: (CanvasDragEndDetails details) {
    print('Drag ended with velocity: ${details.velocity}');
  },
  
  // Hover (desktop)
  onHoverWorld: (Offset worldPos) {
    // Update hover state
  },
)
```

### Hit Testing

The canvas doesn't do hit testing — that's your app's job:

```dart
onTapWorld: (worldPos) {
  // Find which node was tapped
  final tappedNode = nodes.firstWhere(
    (node) => node.bounds.contains(worldPos),
    orElse: () => null,
  );
  
  if (tappedNode != null) {
    setState(() => selectedNode = tappedNode);
  } else {
    setState(() => selectedNode = null);
  }
},
```

---

## Camera Control

### Programmatic Navigation

```dart
// Instant changes
_controller.setZoom(2.0);                    // Set zoom to 200%
_controller.setPan(const Offset(100, 100));  // Set pan position
_controller.panBy(const Offset(50, 0));      // Pan by delta

// Convenience methods
_controller.zoomIn();   // Zoom in by 25%
_controller.zoomOut();  // Zoom out by 20%
_controller.reset();    // Reset to origin at 100%

// Animated transitions
await _controller.animateTo(
  zoom: 1.5,
  pan: const Offset(200, 200),
  duration: const Duration(milliseconds: 300),
);

// Focus on content
await _controller.focusOn(
  nodeRect,
  padding: const EdgeInsets.all(50),
);

// Center on a point at specific zoom
await _controller.animateToCenterOn(
  node.bounds.center,
  zoom: 1.0,
);
```

### Initial Viewport

Control where the camera starts:

```dart
InfiniteCanvas(
  // Center origin (good for symmetrical content)
  initialViewport: const InitialViewport.centerOrigin(),
  
  // Or fit to content
  initialViewport: InitialViewport.fitContent(
    () => calculateAllNodesBounds(),
    padding: const EdgeInsets.all(50),
    fallback: const InitialViewport.centerOrigin(),
  ),
)
```

---

## Coordinate Conversion

Convert between world and screen coordinates:

```dart
// Where did the user tap in world coordinates?
final worldPos = _controller.viewToWorld(screenTapPosition);

// Where on screen should I draw this overlay?
final screenPos = _controller.worldToView(nodePosition);

// Get visible world area (for culling)
final visibleBounds = _controller.getVisibleWorldBounds(viewportSize);
```

---

## Performance: Culling

Only render objects that are visible:

```dart
Widget _buildContent(InfiniteCanvasController ctrl) {
  final viewportSize = ctrl.viewportSize ?? Size.zero;
  
  // Only render visible nodes
  final visibleNodes = ctrl.cullToVisible(
    allNodes,
    (node) => node.bounds,  // Function to get bounds
    viewportSize,
  );
  
  return Stack(
    clipBehavior: Clip.none,
    children: visibleNodes.map((node) => CanvasItem(
      key: ValueKey(node.id),  // Stable keys for efficiency
      position: node.position,
      child: NodeWidget(node),
    )).toList(),
  );
}
```

---

## Performance: Motion State

Use motion state for LOD (Level of Detail) switching:

```dart
Widget _buildContent(InfiniteCanvasController ctrl) {
  return ListenableBuilder(
    listenable: ctrl.isInMotionListenable,
    builder: (context, _) {
      if (ctrl.isInMotion) {
        // Simplified rendering during pan/zoom
        return _buildSimplifiedView();
      } else {
        // Full detail when stationary
        return _buildFullDetailView();
      }
    },
  );
}
```

---

## Configuration

### Gesture Config

```dart
InfiniteCanvas(
  gestureConfig: const CanvasGestureConfig(
    enablePan: true,           // Allow panning
    enableZoom: true,          // Allow zooming
    enableSpacebarPan: true,   // Spacebar + drag to pan
    enableMiddleMousePan: true, // Middle mouse to pan
    enableScrollPan: true,     // Scroll to pan (false if nested in scrollable)
    dragThreshold: 5.0,        // Pixels before drag starts (mouse)
    touchDragThreshold: 10.0,  // Pixels before drag starts (touch/stylus)
    hoverThrottleMs: 16,       // Throttle hover events
  ),
)
```

The `touchDragThreshold` provides a separate threshold for touch and stylus input, which typically benefits from a higher value than mouse input. If not specified, it defaults to 1.5× the `dragThreshold`.

### Physics Config

```dart
InfiniteCanvas(
  physicsConfig: CanvasPhysicsConfig(
    minZoom: 0.1,   // Minimum zoom (10%)
    maxZoom: 10.0,  // Maximum zoom (1000%)
    panBounds: Rect.fromLTWH(0, 0, 2000, 2000),  // Optional: constrain panning
  ),
)
```

The `panBounds` option constrains panning so the viewport stays within specified world-space bounds. When the viewport is larger than the bounds at a given zoom level, content is centered.

---

## Next Steps

- See the [Architecture Guide](architecture.md) for deeper understanding
- Check the [example app](../example/) for complete demos
- Browse the [API Reference](https://pub.dev/documentation/distill_canvas/latest/)

## Common Patterns

### Selection State

Keep selection in your app state, not the canvas:

```dart
class EditorState extends ChangeNotifier {
  final Set<String> selectedIds = {};
  
  void select(String id) {
    selectedIds.clear();
    selectedIds.add(id);
    notifyListeners();
  }
  
  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    notifyListeners();
  }
}
```

### Moving Objects

Accumulate drag delta and apply to selected objects:

```dart
onDragUpdateWorld: (details) {
  for (final id in state.selectedIds) {
    final node = nodes[id];
    if (node != null) {
      nodes[id] = node.copyWith(
        position: node.position + details.worldDelta,
      );
    }
  }
  notifyListeners();
},
```

### Snap to Grid

Snap positions, not deltas:

```dart
void updateDrag(Offset worldDelta, {double? gridSize}) {
  _dragAccumulator += worldDelta;
  
  for (final id in selectedIds) {
    final startPos = _dragStartPositions[id]!;
    var newPos = startPos + _dragAccumulator;
    
    if (gridSize != null) {
      newPos = Offset(
        (newPos.dx / gridSize).round() * gridSize,
        (newPos.dy / gridSize).round() * gridSize,
      );
    }
    
    nodes[id] = nodes[id]!.copyWith(position: newPos);
  }
}
```

### Marquee Selection

```dart
Offset? _marqueeStart;
Offset? _marqueeEnd;

onDragStartWorld: (details) {
  final hit = hitTest(details.worldPosition);
  if (hit == null) {
    // Start marquee on empty canvas
    _marqueeStart = details.worldPosition;
    _marqueeEnd = details.worldPosition;
  }
},

onDragUpdateWorld: (details) {
  if (_marqueeStart != null) {
    _marqueeEnd = details.worldPosition;
    // Select nodes within marquee
    final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
    state.selectInRect(rect);
  }
},

onDragEndWorld: (details) {
  _marqueeStart = null;
  _marqueeEnd = null;
},
```

---

## Troubleshooting

### Objects not visible

- Ensure `Stack` has `clipBehavior: Clip.none`
- Check that objects are within visible bounds (use debug layer)
- Verify `CanvasItem` positions are in world coordinates, not screen

### Gestures not firing

- Verify callbacks are provided (gestures only fire if callback exists)
- Check `gestureConfig` isn't disabling the gesture type
- Ensure the canvas widget has focus

### Performance issues

- Use `cullToVisible()` to limit rendered objects
- React to `isInMotion` for LOD switching
- Use stable `Key`s on `CanvasItem` widgets
- Throttle expensive operations during pan/zoom

### Snap-to-grid feels broken

- Snap the **final position**, not the per-frame delta
- Accumulate total drag movement since drag start
- See "Snap to Grid" pattern above

