/// Distill ECS - Entity Component System Architecture
///
/// A minimal but complete ECS implementation for a design editor.
///
/// ## Core Concepts
///
/// - **Entity**: Just an integer ID - a handle to a "thing"
/// - **Component**: Pure data - Position, Size, Fill, Stroke, etc.
/// - **System**: Behavior that operates on components - Render, Layout, HitTest
/// - **World**: Container for all entities and components
/// - **Events**: All mutations are recorded for undo/redo
/// - **Commands**: High-level API for mutating the world
///
/// ## Usage
///
/// ```dart
/// // Create world and command executor
/// final world = World();
/// final events = EventStore();
/// final commands = CommandExecutor(world, events);
///
/// // Create entities using fluent builder
/// final frame = world.entity()
///   .withName('Frame 1')
///   .withSize(800, 600)
///   .asFrame(canvasX: 100, canvasY: 100)
///   .build();
///
/// final rect = world.entity()
///   .withName('Rectangle')
///   .withPosition(50, 50)
///   .withSize(200, 100)
///   .withFill(Colors.blue)
///   .withCornerRadius(8)
///   .withParent(frame)
///   .build();
///
/// // Mutate through commands (records events for undo)
/// commands.setFillColor(rect, Colors.red);
/// commands.moveBy(rect, 10, 10);
///
/// // Undo/redo
/// commands.undo();
/// commands.redo();
///
/// // Use in Flutter
/// EcsProvider.create(
///   world: world,
///   child: EcsCanvas(world: world, commands: commands),
/// );
/// ```

library ecs;

// Core
export 'core/entity.dart';
export 'core/component.dart';
export 'core/world.dart';
export 'core/events.dart';
export 'core/commands.dart';

// Components
export 'components/components.dart';

// Systems
export 'systems/transform_system.dart';
export 'systems/layout_system.dart';
export 'systems/hit_test_system.dart';
export 'systems/render_system.dart';
export 'systems/snap_system.dart';
export 'systems/drop_system.dart';

// Flutter integration
export 'flutter/canvas_widget.dart';
export 'flutter/interaction_state.dart';
export 'flutter/provider.dart';
