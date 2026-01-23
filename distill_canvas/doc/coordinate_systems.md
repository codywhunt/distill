# Coordinate Systems in Canvas Applications

This guide explains the coordinate systems used by InfiniteCanvas and common patterns for complex canvas applications that need additional coordinate domains.

## Canvas-Provided Coordinates

InfiniteCanvas provides two built-in coordinate systems:

### View Coordinates (Screen Space)

- **Origin**: Top-left corner of the canvas widget
- **Units**: Logical pixels (Flutter's coordinate system)
- **Direction**: X increases rightward, Y increases downward
- **Use cases**: Hit testing, overlay positioning, gesture handling

View coordinates are what you get from pointer events and what Flutter widgets use for layout.

### World Coordinates (Canvas Space)

- **Origin**: Configurable via `InitialViewport` (default: top-left at zoom 1.0)
- **Units**: Application-defined (could be pixels, meters, grid units, etc.)
- **Direction**: Same as view (X right, Y down) but transformed by pan/zoom
- **Use cases**: Content positioning, persistent storage, spatial indexing

World coordinates represent the "infinite" canvas that users pan and zoom through.

## Conversion Methods

The `InfiniteCanvasController` provides bidirectional conversion:

```dart
// Point conversions
Offset viewToWorld(Offset viewPoint);
Offset worldToView(Offset worldPoint);

// Rect conversions
Rect viewToWorldRect(Rect viewRect);
Rect worldToViewRect(Rect worldRect);

// Size conversions
Size viewToWorldSize(Size viewSize);
Size worldToViewSize(Size worldSize);
```

### When to Convert

| Scenario | Direction |
|----------|-----------|
| Processing tap/click position | View → World |
| Positioning overlay at world location | World → View |
| Culling items outside viewport | World → World (compare with visible bounds) |
| Drawing selection handles | World → View |

## The Transform Matrix

For advanced use cases, access the combined transform:

```dart
// Combined pan/zoom as Matrix4
Matrix4 transform = controller.transform;

// Apply to Transform widget
Transform(
  transform: controller.transform,
  child: WorldSpaceContent(),
)
```

The transform encodes: `scale(zoom) * translate(pan)`

## Common Consumer Patterns

Complex canvas applications often need additional coordinate domains beyond view/world. Here are patterns from production implementations.

### Document Domain

For editors that persist data, you typically have document IDs and positions:

```dart
class DocumentNode {
  final String id;
  final Offset position;  // In world coordinates
  final Size size;
}

// Convert document position to view for rendering overlay
final viewBounds = controller.worldToViewRect(
  Rect.fromLTWH(
    node.position.dx,
    node.position.dy,
    node.size.width,
    node.size.height,
  ),
);
```

### Expanded Domain

For component/instance systems where one document node expands to multiple rendered nodes:

```dart
// A component instance in the document
class ComponentInstance {
  final String documentId;
  final String componentRef;
}

// Expands to multiple rendered nodes
class ExpandedNode {
  final String expandedId;      // Unique ID for this rendered instance
  final String documentId;      // Back-reference to document
  final Rect bounds;            // Computed bounds in world space
}

// Mapping: documentId -> List<expandedId>
typedef ExpansionMap = Map<String, List<String>>;
```

### Rendered Domain

Computed layout bounds after expansion and layout:

```dart
// Resolver callback pattern
typedef BoundsResolver = Rect? Function(String expandedId);
typedef FramePositionResolver = Offset Function(String frameId);

class CoordinateBridge {
  final InfiniteCanvasController controller;
  final BoundsResolver documentBounds;
  final ExpansionMap expansion;

  /// Convert document ID to view-space bounds.
  Rect? getViewBounds(String documentId) {
    final expandedIds = expansion[documentId];
    if (expandedIds == null || expandedIds.isEmpty) return null;

    // Get world bounds of first expanded node
    final worldBounds = documentBounds(expandedIds.first);
    if (worldBounds == null) return null;

    // Convert to view space for rendering
    return controller.worldToViewRect(worldBounds);
  }

  /// Hit test: find document ID at view position.
  String? hitTest(Offset viewPos) {
    final worldPos = controller.viewToWorld(viewPos);
    // Query spatial index with world position...
  }
}
```

### Multi-Frame Coordinates

For canvas applications with multiple independent coordinate frames (e.g., a design tool with multiple artboards):

```dart
class Frame {
  final String id;
  final Rect worldBounds;        // Position on canvas
  final Size internalSize;       // Internal coordinate space size
}

class FrameCoordinates {
  /// Convert canvas world position to frame-local position.
  Offset canvasToFrame(Frame frame, Offset canvasPos) {
    return canvasPos - frame.worldBounds.topLeft;
  }

  /// Convert frame-local position to canvas world position.
  Offset frameToCanvas(Frame frame, Offset framePos) {
    return framePos + frame.worldBounds.topLeft;
  }

  /// Convert frame-local position to view position.
  Offset frameToView(Frame frame, Offset framePos, InfiniteCanvasController ctrl) {
    final canvasPos = frameToCanvas(frame, framePos);
    return ctrl.worldToView(canvasPos);
  }
}
```

## Best Practices

### 1. Store Positions in World Coordinates

Persistent data should use world coordinates:

```dart
// Good: world coordinates are zoom-independent
final savedPosition = Offset(worldX, worldY);

// Bad: view coordinates change with pan/zoom
final savedPosition = Offset(viewX, viewY);  // Will be wrong after pan!
```

### 2. Convert Late

Convert to view coordinates only when you need them for rendering:

```dart
// Good: defer conversion
Widget build(BuildContext context) {
  final viewBounds = controller.worldToViewRect(worldBounds);
  return Positioned.fromRect(rect: viewBounds, child: overlay);
}

// Bad: convert and store
void onBoundsChanged(Rect worldBounds) {
  _viewBounds = controller.worldToViewRect(worldBounds);  // Stale after pan!
}
```

### 3. Use Appropriate Precision

World coordinates may need higher precision than view coordinates:

```dart
// World: may need sub-pixel precision for accurate snapping
final snappedWorld = Offset(
  (worldPos.dx / gridSize).round() * gridSize,
  (worldPos.dy / gridSize).round() * gridSize,
);

// View: pixel precision is sufficient
final viewPos = controller.worldToView(snappedWorld).round();
```

### 4. Cache Expensive Conversions

For many items, cache the transform or batch conversions:

```dart
// Cache visible bounds once per frame
final visibleWorld = controller.getVisibleWorldBounds(viewportSize);

// Use cached bounds for culling all items
final visibleItems = items.where((item) =>
  visibleWorld.overlaps(item.worldBounds)
);
```

### 5. Document Your Coordinate Domains

For complex applications, document which coordinates each API expects:

```dart
/// Positions an overlay at the given world position.
///
/// [worldPos] is in canvas world coordinates.
/// The overlay will follow the position as the canvas pans/zooms.
void showOverlayAt(Offset worldPos) { ... }

/// Hit tests at the given view position.
///
/// [viewPos] is in canvas view coordinates (from pointer event).
/// Returns the document ID of the hit item, or null.
String? hitTestAt(Offset viewPos) { ... }
```

## Summary

| Coordinate System | Origin | Use For |
|-------------------|--------|---------|
| View (screen) | Canvas widget top-left | Overlays, pointer events |
| World (canvas) | Configurable | Content, persistence |
| Document | Application-defined | Data model IDs |
| Expanded | Application-defined | Instance/component systems |
| Frame-local | Per-frame | Multi-artboard tools |

Start with view and world coordinates from InfiniteCanvas. Add additional domains only as your application complexity requires them, and document the relationships clearly.
