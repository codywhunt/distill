/// Interaction State Machine
///
/// All possible interaction states for the canvas.
/// Using sealed classes makes state transitions explicit and type-safe.

import 'dart:ui';

import '../core/entity.dart';

/// Base class for all interaction states
sealed class InteractionState {
  const InteractionState();
}

/// Idle - no active interaction
class Idle extends InteractionState {
  const Idle();
}

/// Hovering over content (shows highlight)
class Hovering extends InteractionState {
  final Entity? hoveredEntity;
  final HandleType? hoveredHandle;

  const Hovering({
    this.hoveredEntity,
    this.hoveredHandle,
  });
}

/// Panning the camera
class Panning extends InteractionState {
  final Offset startScreenPos;
  final Offset startCamera;

  const Panning({
    required this.startScreenPos,
    required this.startCamera,
  });
}

/// Dragging selected entities
class Dragging extends InteractionState {
  final List<Entity> entities;
  final Offset startWorldPos;
  final Map<Entity, Offset> startPositions;

  const Dragging({
    required this.entities,
    required this.startWorldPos,
    required this.startPositions,
  });
}

/// Resizing selected entities
class Resizing extends InteractionState {
  final List<Entity> entities;
  final HandleType handle;
  final Offset startWorldPos;
  final Map<Entity, Rect> startBounds;

  const Resizing({
    required this.entities,
    required this.handle,
    required this.startWorldPos,
    required this.startBounds,
  });
}

/// Marquee selection (drag to select multiple)
class MarqueeSelecting extends InteractionState {
  final Offset startWorldPos;
  final Offset currentWorldPos;

  const MarqueeSelecting({
    required this.startWorldPos,
    required this.currentWorldPos,
  });

  Rect get rect => Rect.fromPoints(startWorldPos, currentWorldPos);
}

/// Editing text content
class TextEditing extends InteractionState {
  final Entity entity;

  const TextEditing({required this.entity});
}

/// Drawing a new shape
class Drawing extends InteractionState {
  final ShapeType shapeType;
  final Offset startWorldPos;
  final Offset currentWorldPos;

  const Drawing({
    required this.shapeType,
    required this.startWorldPos,
    required this.currentWorldPos,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting Types
// ─────────────────────────────────────────────────────────────────────────────

/// Resize handle positions
enum HandleType {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Shape types for drawing tool
enum ShapeType {
  rectangle,
  ellipse,
  line,
  text,
}

// ─────────────────────────────────────────────────────────────────────────────
// State Transition Helpers
// ─────────────────────────────────────────────────────────────────────────────

extension InteractionStateHelpers on InteractionState {
  /// Is user actively interacting (not idle/hovering)?
  bool get isActive => switch (this) {
        Idle() => false,
        Hovering() => false,
        _ => true,
      };

  /// Is this a drag operation?
  bool get isDragging => this is Dragging || this is Resizing;

  /// Can user start a new interaction?
  bool get canStartInteraction => !isActive;

  /// Get cursor for this state
  String get cursor => switch (this) {
        Idle() => 'default',
        Hovering(hoveredHandle: final h) when h != null => _handleCursor(h),
        Hovering() => 'pointer',
        Panning() => 'grabbing',
        Dragging() => 'move',
        Resizing(handle: final h) => _handleCursor(h),
        MarqueeSelecting() => 'crosshair',
        TextEditing() => 'text',
        Drawing() => 'crosshair',
      };

  String _handleCursor(HandleType handle) => switch (handle) {
        HandleType.topLeft || HandleType.bottomRight => 'nwse-resize',
        HandleType.topRight || HandleType.bottomLeft => 'nesw-resize',
        HandleType.topCenter || HandleType.bottomCenter => 'ns-resize',
        HandleType.centerLeft || HandleType.centerRight => 'ew-resize',
      };
}
