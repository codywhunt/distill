import 'package:flutter/gestures.dart';

/// Details for drag start events in world coordinates.
///
/// Provided to [InfiniteCanvas.onDragStartWorld] when a drag gesture begins.
class CanvasDragStartDetails {
  const CanvasDragStartDetails({
    required this.worldPosition,
    required this.viewPosition,
    this.kind,
  });

  /// Drag start position in world-space (canvas coordinates).
  ///
  /// Use this for hit-testing against your domain objects.
  final Offset worldPosition;

  /// Drag start position in view-space (screen pixels).
  final Offset viewPosition;

  /// The kind of pointer that initiated the drag (mouse, touch, stylus, etc.)
  final PointerDeviceKind? kind;

  @override
  String toString() =>
      'CanvasDragStartDetails(world: $worldPosition, view: $viewPosition)';
}

/// Details for drag update events in world coordinates.
///
/// Provided to [InfiniteCanvas.onDragUpdateWorld] during a drag gesture.
class CanvasDragUpdateDetails {
  const CanvasDragUpdateDetails({
    required this.worldPosition,
    required this.worldDelta,
    required this.viewPosition,
    required this.viewDelta,
  });

  /// Current position in world-space (canvas coordinates).
  final Offset worldPosition;

  /// Movement since last update in world-space.
  ///
  /// This is the key value for moving objects: apply this delta to your
  /// selected objects' positions.
  final Offset worldDelta;

  /// Current position in view-space (screen pixels).
  final Offset viewPosition;

  /// Movement since last update in view-space.
  final Offset viewDelta;

  @override
  String toString() =>
      'CanvasDragUpdateDetails(world: $worldPosition, delta: $worldDelta)';
}

/// Details for drag end events.
///
/// Provided to [InfiniteCanvas.onDragEndWorld] when a drag gesture ends.
class CanvasDragEndDetails {
  const CanvasDragEndDetails({
    required this.worldPosition,
    required this.viewPosition,
    this.velocity = Offset.zero,
  });

  /// Final position in world-space (canvas coordinates).
  final Offset worldPosition;

  /// Final position in view-space (screen pixels).
  final Offset viewPosition;

  /// Velocity at end of drag in view-space pixels per second.
  ///
  /// Can be used to implement inertia/momentum effects.
  final Offset velocity;

  @override
  String toString() =>
      'CanvasDragEndDetails(world: $worldPosition, velocity: $velocity)';
}
