# ECS Architecture Sketch for Distill

A minimal but complete Entity Component System implementation for a design editor.

## Overview

This is a **proof-of-concept** showing how Distill could be rebuilt using ECS patterns. It demonstrates the core concepts with working code, but is not production-ready.

## File Structure

```
ecs_sketch/
├── core/
│   ├── entity.dart      # Entity = just an integer ID
│   ├── component.dart   # ComponentTable<T> for typed storage
│   ├── world.dart       # World container + EntityBuilder
│   ├── events.dart      # Event definitions + EventStore for undo/redo
│   └── commands.dart    # CommandExecutor - high-level mutation API
│
├── components/
│   └── components.dart  # All component definitions:
│                        # Position, Size, Fill, Stroke, Text,
│                        # Hierarchy, AutoLayout, FrameMarker, etc.
│
├── systems/
│   ├── transform_system.dart  # Computes world transforms
│   ├── layout_system.dart     # Auto-layout (flexbox-like)
│   ├── hit_test_system.dart   # Point/rect queries
│   └── render_system.dart     # Paints to Canvas
│
├── flutter/
│   ├── canvas_widget.dart     # Main EcsCanvas widget
│   ├── interaction_state.dart # State machine for input
│   └── provider.dart          # Dependency injection
│
├── example/
│   └── main.dart              # Working example app
│
├── ecs.dart                   # Barrel export
└── README.md                  # This file
```

## Key Concepts

### 1. Entities are Just IDs

```dart
typedef Entity = int;

final entity = world.spawn();  // Returns 0, 1, 2, ...
```

No inheritance, no mixins, no object overhead.

### 2. Components are Pure Data

```dart
class Position implements Component {
  double x, y;
  Position(this.x, this.y);
}

class Fill implements Component {
  final Color color;
  Fill.solid(this.color);
}
```

Components have no behavior - just fields.

### 3. ComponentTables Store Data

```dart
final table = ComponentTable<Position>();

table.set(entity, Position(100, 200));
final pos = table.get(entity);  // Position(100, 200)
table.has(entity);              // true
table.remove(entity);
```

Each component type gets its own table. Queries are table joins.

### 4. World Contains Everything

```dart
final world = World();

// Component tables
world.position.set(entity, Position(0, 0));
world.fill.set(entity, Fill.solid(Colors.blue));
world.hierarchy.set(entity, Hierarchy(parent: parentEntity));

// Queries
world.childrenOf(parent);
world.descendantsOf(root);
world.visibleIn(viewport);
```

### 5. Systems Implement Behavior

```dart
class TransformSystem {
  void updateAll(World world) {
    for (final entity in world.topologicalOrder()) {
      // Compute world transform from hierarchy + position
    }
  }
}

class RenderSystem {
  void render(World world, Canvas canvas, Rect viewport) {
    for (final entity in world.visibleIn(viewport)) {
      // Paint based on Fill, Stroke, Text components
    }
  }
}
```

Systems are pure functions over the World.

### 6. Events Enable Undo/Redo

```dart
// All mutations are events
class PositionChanged extends EditorEvent {
  final Entity entity;
  final Position? oldValue;
  final Position? newValue;
}

// Events stored in EventStore
eventStore.push(event);
eventStore.undo();  // Move pointer back
eventStore.redo();  // Move pointer forward
```

No patch inversion needed - events store both old and new values.

### 7. Commands are the Public API

```dart
final commands = CommandExecutor(world, events);

commands.setPosition(entity, 100, 200);  // Creates PositionChanged event
commands.setFillColor(entity, Colors.red);
commands.moveBy(entity, 10, 10);

// Grouped commands undo as one unit
commands.grouped('drag', () {
  commands.moveBy(entity1, dx, dy);
  commands.moveBy(entity2, dx, dy);
});

commands.undo();  // Undoes entire group
```

## Comparison with Current Architecture

| Current Distill | ECS Sketch |
|-----------------|------------|
| Nested `Node` objects with `copyWith` | Flat `ComponentTable<T>` with O(1) updates |
| `EditorDocument.nodes` map | `World.position`, `World.fill`, etc. |
| `PatchOp` + inverse computation | `EditorEvent` stores old+new values |
| `ExpandedScene` for instance expansion | `Instance` component + prototype lookup |
| Three-stage render pipeline | Single `RenderSystem.render()` |
| Four coordinate spaces | World space + transform stack |
| Complex `DragSession` state | `InteractionState` sealed class |

## What This Proves

1. **Simpler state management**: Flat tables are easier to reason about than nested trees
2. **Natural undo/redo**: Events with old/new values need no inverse computation
3. **Efficient queries**: Table joins are explicit and can be indexed
4. **Clear separation**: Data (components) vs behavior (systems) vs mutation (commands)
5. **Type-safe interactions**: Sealed class state machine prevents impossible states

## What's Missing (For Production)

- [ ] Spatial indexing (R-tree for visibility queries)
- [ ] Component archetypes for cache-optimal iteration
- [ ] Component instance expansion (prototype chain)
- [ ] Serialization to/from JSON
- [ ] Incremental system updates (dirty tracking)
- [ ] Snap guides during drag
- [ ] Text editing integration
- [ ] Property panel bindings
- [ ] Tests

## Running the Example

```bash
cd distill
flutter run -t lib/src/ecs_sketch/example/main.dart
```

Note: This requires the `vector_math` package and may have import issues since it's a sketch within an existing project.
