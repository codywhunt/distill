# Drag & Drop Patterns

This guide covers common drag and drop patterns when using `InfiniteCanvas`.

## Coordinate Domains

The canvas works with two coordinate systems:

- **World coordinates**: The infinite canvas coordinate space. Objects are positioned in world coordinates.
- **View coordinates**: Screen/pixel coordinates relative to the canvas widget.

Use these controller methods to convert between domains:

```dart
// World → View (for rendering overlays)
final viewPos = controller.worldToView(worldPos);

// View → World (for hit testing, positioning)
final worldPos = controller.viewToWorld(viewPos);
```

## Basic Object Dragging

The simplest pattern: drag to move objects in world space.

```dart
InfiniteCanvas(
  controller: controller,
  layers: CanvasLayers(
    content: (ctx, ctrl) => Stack(
      children: nodes.map((n) => CanvasItem(
        position: n.position,
        child: NodeWidget(n),
      )).toList(),
    ),
  ),
  onDragStartWorld: (details) {
    // Find node under drag start
    final hitNode = findNodeAt(details.worldPosition);
    if (hitNode != null) {
      selectedNode = hitNode;
      dragStartOffset = hitNode.position - details.worldPosition;
    }
  },
  onDragUpdateWorld: (details) {
    if (selectedNode != null) {
      // Move node by world delta
      selectedNode.position += details.worldDelta;
      setState(() {});
    }
  },
  onDragEndWorld: (details) {
    selectedNode = null;
    dragStartOffset = null;
  },
)
```

### Key Points

- `onDragStartWorld` receives the initial touch/click position
- `onDragUpdateWorld.worldDelta` is the movement since last update, already scaled for zoom
- Store an offset at drag start if you want precise positioning relative to where the user grabbed

## Drop Preview System

For drop-to-insert scenarios (like dragging into a list), show a preview indicator.

```dart
class DropPreviewOverlay extends CanvasOverlayWidget {
  const DropPreviewOverlay({
    super.key,
    required super.controller,
    required this.dropTarget,
    required this.insertIndex,
  });

  final Rect? dropTarget;
  final int? insertIndex;

  @override
  Widget buildOverlay(BuildContext context, Rect viewBounds) {
    if (dropTarget == null) return const SizedBox.shrink();

    // Convert world rect to view coordinates
    final viewRect = Rect.fromPoints(
      controller.worldToView(dropTarget!.topLeft),
      controller.worldToView(dropTarget!.bottomRight),
    );

    return CustomPaint(
      size: Size(viewBounds.width, viewBounds.height),
      painter: DropIndicatorPainter(viewRect, insertIndex),
    );
  }
}
```

## Insertion Index Calculation

When dragging over a list or grid, calculate where the item would be inserted:

```dart
int? calculateInsertIndex(Offset worldPos, List<Rect> itemBounds) {
  // Find insertion point based on Y position (for vertical list)
  for (int i = 0; i < itemBounds.length; i++) {
    final bounds = itemBounds[i];
    final midY = bounds.center.dy;

    if (worldPos.dy < midY) {
      return i; // Insert before this item
    }
  }
  return itemBounds.length; // Insert at end
}

// In drag update:
onDragUpdateWorld: (details) {
  if (isDraggingExternal) {
    final container = findContainerAt(details.worldPosition);
    if (container != null) {
      dropTarget = container.bounds;
      insertIndex = calculateInsertIndex(
        details.worldPosition,
        container.itemBounds,
      );
    } else {
      dropTarget = null;
      insertIndex = null;
    }
    setState(() {});
  }
}
```

## Snap Integration During Drag

Combine dragging with the snap system for alignment guides:

```dart
final snapEngine = SnapEngine(
  threshold: 8.0,
  enableEdgeSnap: true,
  enableCenterSnap: true,
);

onDragUpdateWorld: (details) {
  if (selectedNode != null) {
    // Calculate proposed new position
    final proposedBounds = selectedNode.bounds.shift(details.worldDelta);

    // Get other nodes for snap reference
    final otherBounds = nodes
        .where((n) => n != selectedNode)
        .map((n) => n.bounds)
        .toList();

    // Calculate snap
    final result = snapEngine.calculateSnapMove(
      movingBounds: proposedBounds,
      otherBounds: otherBounds,
    );

    // Apply snapped position
    selectedNode.position = result.snappedBounds.topLeft;

    // Show snap guides in overlay
    activeSnapGuides = result.guides;

    setState(() {});
  }
}
```

## External Drag (from outside canvas)

Handle dragging items from outside the canvas widget:

```dart
Widget build(BuildContext context) {
  return DragTarget<MyItem>(
    onWillAcceptWithDetails: (details) => true,
    onAcceptWithDetails: (details) {
      // Get drop position relative to canvas
      final renderBox = canvasKey.currentContext!.findRenderObject() as RenderBox;
      final localPos = renderBox.globalToLocal(details.offset);
      final worldPos = controller.viewToWorld(localPos);

      // Create new node at world position
      addNode(MyNode(
        position: worldPos,
        data: details.data,
      ));
    },
    builder: (context, candidates, rejected) {
      return InfiniteCanvas(
        key: canvasKey,
        controller: controller,
        // ...
      );
    },
  );
}
```

## Velocity-Based Effects

Use drag end velocity for momentum or throw effects:

```dart
onDragEndWorld: (details) {
  if (selectedNode != null) {
    // Apply momentum based on drag velocity
    final velocity = details.velocity;
    if (velocity.distance > 100) {
      // Scale velocity to world units
      final worldVelocity = velocity / controller.zoom;
      startNodeMomentum(selectedNode, worldVelocity);
    }

    selectedNode = null;
  }
}
```

## Multi-Select Drag

Dragging multiple selected objects together:

```dart
Set<Node> selectedNodes = {};
Map<Node, Offset> dragOffsets = {};

onDragStartWorld: (details) {
  final hitNode = findNodeAt(details.worldPosition);

  if (hitNode != null && selectedNodes.contains(hitNode)) {
    // Dragging a selected node - move all selected
    for (final node in selectedNodes) {
      dragOffsets[node] = node.position - details.worldPosition;
    }
  } else if (hitNode != null) {
    // Single selection
    selectedNodes = {hitNode};
    dragOffsets = {hitNode: hitNode.position - details.worldPosition};
  }
}

onDragUpdateWorld: (details) {
  for (final node in selectedNodes) {
    final offset = dragOffsets[node] ?? Offset.zero;
    node.position = details.worldPosition + offset + details.worldDelta;
  }
  setState(() {});
}
```

## Performance Tips

1. **Avoid rebuilds during drag**: Use `CanvasOverlayWidget` for transient UI like selection boxes and snap guides instead of rebuilding the content layer.

2. **Batch state updates**: If updating multiple objects, update all positions before calling `setState()`.

3. **Use worldDelta**: The `worldDelta` is pre-scaled for zoom level, so you don't need to manually divide by zoom.

4. **Throttle hit testing**: For complex scenes, consider throttling hit testing during fast drags or using spatial indexing (R-tree, grid).

5. **Cancel momentum on drag start**: When the user starts dragging, cancel any in-progress momentum animations on the canvas to prevent interference.
