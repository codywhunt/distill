# Performance Guide

This guide covers performance considerations when using InfiniteCanvas, including baseline metrics, optimization patterns, and benchmarking.

## Baseline Metrics

These metrics establish expected behavior. Run `flutter test test/benchmark/` to capture current baselines.

| Metric | Expected Value | Notes |
|--------|----------------|-------|
| Content rebuilds per 2s pan | ~120 | One per frame during gesture |
| Notifications per 1s pan | ~60 | One per pan delta |
| Repaint/rebuild ratio | ~1:1 | Each rebuild triggers repaint |

The baseline tests print these values when run. Update this table after running Phase 1 tests.

## When to Use InfiniteCanvas

InfiniteCanvas is designed for:

- **Large 2D spaces** with pan/zoom (design tools, maps, whiteboards)
- **Many interactive elements** that need hit testing
- **Mixed static and dynamic content** in the same space
- **Custom coordinate systems** with world/view separation

## When NOT to Use InfiniteCanvas

Consider simpler alternatives for these use cases:

| Use Case | Better Alternative |
|----------|-------------------|
| Static images | Standard `Image` widget |
| Single scrollable list | `ListView` or `CustomScrollView` |
| Simple pan/zoom of single child | `InteractiveViewer` |
| < 10 items with basic transforms | Direct `Transform` widget |
| Photo gallery with zoom | `photo_view` package |

## Content Layer Performance

The content layer callback is invoked on **every viewport change** (60+ fps during gestures). This is expected behavior, not a bug.

### The Performance Contract

```dart
// Content layer is called frequently - implementations MUST be efficient
content: (context, controller) {
  // This runs 60+ times per second during gestures!
  return buildMyContent(controller);
}
```

### DO: Use Culling

Only build widgets that are currently visible:

```dart
content: (context, controller) {
  // Get visible world bounds
  final visible = controller.getVisibleWorldBounds(
    MediaQuery.sizeOf(context),
  );

  // Only build items that overlap visible area
  final visibleItems = allItems.where(
    (item) => visible.overlaps(item.bounds),
  );

  return Stack(
    children: [
      for (final item in visibleItems)
        CanvasItem(
          key: ValueKey(item.id),
          position: item.position,
          child: ItemWidget(item: item),
        ),
    ],
  );
}
```

### DO: Use LOD (Level of Detail)

Render simpler versions during motion:

```dart
content: (context, controller) {
  return ListenableBuilder(
    listenable: controller.isInMotionListenable,
    builder: (context, _) {
      final inMotion = controller.isPanning.value ||
          controller.isZooming.value ||
          controller.isAnimating.value ||
          controller.isDecelerating.value;

      if (inMotion) {
        // Simple placeholders during motion
        return SimplePlaceholders(items: visibleItems);
      }

      // Full detail when stationary
      return FullDetailWidgets(items: visibleItems);
    },
  );
}
```

### DO: Use Keys

Preserve widget identity across rebuilds:

```dart
for (final item in visibleItems)
  CanvasItem(
    key: ValueKey(item.id),  // Important!
    position: item.position,
    child: ItemWidget(item: item),
  ),
```

### DON'T: Rebuild Everything

```dart
// BAD: Rebuilds all items every frame
content: (context, controller) {
  return Stack(
    children: [
      for (final item in allItems)  // No culling!
        ExpensiveWidget(item: item),
    ],
  );
}
```

### DON'T: Create Objects in Builder

```dart
// BAD: Creates new list every frame
content: (context, controller) {
  final items = allItems.map((i) => transform(i)).toList();  // Expensive!
  return MyContent(items: items);
}

// GOOD: Precompute or memoize
final transformedItems = allItems.map((i) => transform(i)).toList();

content: (context, controller) {
  return MyContent(items: transformedItems);  // Reuses existing list
}
```

## Spatial Indexing

For large numbers of items, use the exported `QuadTree` for O(log n) hit testing:

```dart
import 'package:distill_canvas/utilities.dart';

final tree = QuadTree<String>(
  bounds: const Rect.fromLTWH(0, 0, 10000, 10000),
);

// Insert items
for (final item in items) {
  tree.insert(item.id, item.bounds);
}

// Query visible items efficiently
final visibleBounds = controller.getVisibleWorldBounds(viewportSize);
final visibleIds = tree.query(visibleBounds);
```

## Measuring Performance

### Content Layer Benchmark

```dart
testWidgets('benchmark my content layer', (tester) async {
  int rebuildCount = 0;

  await tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 800,
        height: 600,
        child: InfiniteCanvas(
          controller: controller,
          layers: CanvasLayers(
            content: (ctx, ctrl) {
              rebuildCount++;
              return MyContentWidget(controller: ctrl);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final startCount = rebuildCount;

  // Simulate 2-second pan
  final gesture = await tester.startGesture(Offset(400, 300));
  for (int i = 0; i < 120; i++) {
    await gesture.moveBy(Offset(5, 3));
    await tester.pump(Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();

  print('Rebuilds during 2s pan: ${rebuildCount - startCount}');
  // Target: ~120 (one per frame is expected)
});
```

### Frame Timing

Use Flutter DevTools Timeline view to measure frame times during gestures. Target: 95th percentile < 16ms for 60fps.

## ListenableBuilder Optimization

The canvas uses a single `ListenableBuilder` for all layers. This is intentional:

1. **All layers share the same transform** - they need to update together
2. **Widget allocation is cheap** - the outer structure is lightweight
3. **Complexity is in content** - consumer code should optimize

If you have expensive static content inside your layer builder, use `ValueListenableBuilder` with the `child` parameter:

```dart
content: (context, controller) {
  return ValueListenableBuilder<Rect>(
    valueListenable: controller.visibleBoundsNotifier,
    // Static expensive widget built once
    child: const ExpensiveStaticDecoration(),
    builder: (context, bounds, staticChild) {
      return Stack(
        children: [
          staticChild!,  // Reused across rebuilds
          for (final item in cullToVisible(items, bounds))
            ItemWidget(item: item),
        ],
      );
    },
  );
}
```

## Summary

| Optimization | When to Use | Impact |
|--------------|-------------|--------|
| Culling | Always, > 10 items | High |
| LOD during motion | Items have expensive rendering | Medium |
| Keys on widgets | Dynamic item lists | Medium |
| Spatial indexing | > 100 items | Medium |
| Static child reuse | Expensive static content | Low |

The most important optimization is **culling**. Start there.
