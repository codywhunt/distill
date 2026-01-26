/// ECS Commands
///
/// Commands are the public API for mutating the World.
/// They generate events and apply changes atomically.

import 'dart:ui';

import 'entity.dart';
import 'world.dart';
import 'events.dart';
import '../components/components.dart';

/// Executes commands and records events
class CommandExecutor {
  final World world;
  final EventStore events;
  final List<void Function()> _listeners = [];

  /// Current group ID for batching related commands
  String? _currentGroupId;

  CommandExecutor(this.world, this.events);

  /// Listen for any changes
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notify() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Start a command group (for undo as a single unit)
  void beginGroup(String groupId) {
    _currentGroupId = groupId;
  }

  /// End the current command group
  void endGroup() {
    _currentGroupId = null;
  }

  /// Execute commands within a group
  void grouped(String groupId, void Function() commands) {
    beginGroup(groupId);
    try {
      commands();
    } finally {
      endGroup();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Entity Commands
  // ─────────────────────────────────────────────────────────────────────────

  /// Spawn a new entity
  Entity spawn() {
    final entity = world.spawn();
    events.push(EntitySpawned(entity, groupId: _currentGroupId));
    _notify();
    return entity;
  }

  /// Despawn an entity
  void despawn(Entity entity) {
    // Capture component state for undo
    final snapshot = _captureSnapshot(entity);
    world.despawn(entity);
    events.push(EntityDespawned(entity, snapshot, groupId: _currentGroupId));
    _notify();
  }

  Map<String, dynamic> _captureSnapshot(Entity entity) {
    return {
      'position': world.position.get(entity)?.copy(),
      'size': world.size.get(entity)?.copy(),
      'fill': world.fill.get(entity),
      'stroke': world.stroke.get(entity),
      'text': world.text.get(entity),
      'hierarchy': world.hierarchy.get(entity)?.copy(),
      'name': world.name.get(entity),
      'opacity': world.opacity.get(entity),
      'cornerRadius': world.cornerRadius.get(entity),
      'autoLayout': world.autoLayout.get(entity),
      'frame': world.frame.get(entity),
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Position Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setPosition(Entity entity, double x, double y) {
    final oldValue = world.position.get(entity)?.copy();
    final newValue = Position(x, y);
    world.position.set(entity, newValue);
    events.push(PositionChanged(entity, oldValue, newValue, groupId: _currentGroupId));
    _notify();
  }

  void moveBy(Entity entity, double dx, double dy) {
    final current = world.position.get(entity);
    final x = (current?.x ?? 0) + dx;
    final y = (current?.y ?? 0) + dy;
    setPosition(entity, x, y);
  }

  void moveEntities(List<Entity> entities, double dx, double dy) {
    for (final entity in entities) {
      moveBy(entity, dx, dy);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Size Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setSize(Entity entity, double width, double height) {
    final oldValue = world.size.get(entity)?.copy();
    final newValue = Size(width, height);
    world.size.set(entity, newValue);
    events.push(SizeChanged(entity, oldValue, newValue, groupId: _currentGroupId));
    _notify();
  }

  void resizeBy(Entity entity, double dw, double dh) {
    final current = world.size.get(entity);
    final width = (current?.width ?? 0) + dw;
    final height = (current?.height ?? 0) + dh;
    setSize(entity, width.clamp(1, double.infinity), height.clamp(1, double.infinity));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Style Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setFill(Entity entity, Fill? fill) {
    final oldValue = world.fill.get(entity);
    world.fill.set(entity, fill ?? Fill.none());
    events.push(FillChanged(entity, oldValue, fill, groupId: _currentGroupId));
    _notify();
  }

  void setFillColor(Entity entity, Color color) {
    setFill(entity, Fill.solid(color));
  }

  void setStroke(Entity entity, Stroke? stroke) {
    final oldValue = world.stroke.get(entity);
    if (stroke != null) {
      world.stroke.set(entity, stroke);
    } else {
      world.stroke.remove(entity);
    }
    events.push(StrokeChanged(entity, oldValue, stroke, groupId: _currentGroupId));
    _notify();
  }

  void setOpacity(Entity entity, double opacity) {
    final oldValue = world.opacity.get(entity);
    final newValue = Opacity(opacity.clamp(0, 1));
    world.opacity.set(entity, newValue);
    events.push(OpacityChanged(entity, oldValue, newValue, groupId: _currentGroupId));
    _notify();
  }

  void setCornerRadius(Entity entity, CornerRadius? radius) {
    final oldValue = world.cornerRadius.get(entity);
    if (radius != null) {
      world.cornerRadius.set(entity, radius);
    } else {
      world.cornerRadius.remove(entity);
    }
    events.push(CornerRadiusChanged(entity, oldValue, radius, groupId: _currentGroupId));
    _notify();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setText(Entity entity, String text) {
    final oldValue = world.text.get(entity);
    final newValue = TextContent(
      text: text,
      style: oldValue?.style,
      align: oldValue?.align ?? TextAlign.left,
    );
    world.text.set(entity, newValue);
    events.push(TextChanged(entity, oldValue, newValue, groupId: _currentGroupId));
    _notify();
  }

  void setTextContent(Entity entity, TextContent? content) {
    final oldValue = world.text.get(entity);
    if (content != null) {
      world.text.set(entity, content);
    } else {
      world.text.remove(entity);
    }
    events.push(TextChanged(entity, oldValue, content, groupId: _currentGroupId));
    _notify();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hierarchy Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setParent(Entity entity, Entity? parent, {int? childIndex}) {
    final oldValue = world.hierarchy.get(entity)?.copy();
    final newValue = Hierarchy(
      parent: parent,
      childIndex: childIndex ?? (parent != null ? world.childrenOf(parent).length : 0),
    );
    world.hierarchy.set(entity, newValue);
    events.push(HierarchyChanged(entity, oldValue, newValue, groupId: _currentGroupId));
    _notify();
  }

  void reparent(Entity entity, Entity newParent, int childIndex) {
    setParent(entity, newParent, childIndex: childIndex);
    // Reindex siblings at old and new parent
    _reindexChildren(world.hierarchy.get(entity)?.parent);
    _reindexChildren(newParent);
  }

  void _reindexChildren(Entity? parent) {
    if (parent == null) return;
    final children = world.childrenOf(parent);
    for (var i = 0; i < children.length; i++) {
      final h = world.hierarchy.get(children[i]);
      if (h != null && h.childIndex != i) {
        h.childIndex = i;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Metadata Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setName(Entity entity, String name) {
    final oldValue = world.name.get(entity);
    final newValue = Name(name);
    world.name.set(entity, newValue);
    events.push(NameChanged(entity, oldValue, newValue, groupId: _currentGroupId));
    _notify();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Layout Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setAutoLayout(Entity entity, AutoLayout? layout) {
    final oldValue = world.autoLayout.get(entity);
    if (layout != null) {
      world.autoLayout.set(entity, layout);
    } else {
      world.autoLayout.remove(entity);
    }
    events.push(AutoLayoutChanged(entity, oldValue, layout, groupId: _currentGroupId));
    _notify();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Frame Commands
  // ─────────────────────────────────────────────────────────────────────────

  void setFrameMarker(Entity entity, FrameMarker? marker) {
    final oldValue = world.frame.get(entity);
    if (marker != null) {
      world.frame.set(entity, marker);
    } else {
      world.frame.remove(entity);
    }
    events.push(FrameMarkerChanged(entity, oldValue, marker, groupId: _currentGroupId));
    _notify();
  }

  void moveFrame(Entity frame, double canvasX, double canvasY) {
    final marker = world.frame.get(frame);
    if (marker != null) {
      setFrameMarker(frame, FrameMarker(canvasX: canvasX, canvasY: canvasY));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Undo/Redo
  // ─────────────────────────────────────────────────────────────────────────

  bool get canUndo => events.canUndo;
  bool get canRedo => events.canRedo;

  void undo() {
    final undoneEvents = events.undoGroup();
    for (final event in undoneEvents) {
      _unapplyEvent(event);
    }
    _notify();
  }

  void redo() {
    final redoneEvents = events.redoGroup();
    for (final event in redoneEvents) {
      _reapplyEvent(event);
    }
    _notify();
  }

  void _unapplyEvent(EditorEvent event) {
    switch (event) {
      case EntitySpawned(entity: final e):
        world.despawn(e);
      case EntityDespawned(entity: final e, componentSnapshot: final snapshot):
        _restoreFromSnapshot(e, snapshot);
      case PositionChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.position.set(e, old);
        } else {
          world.position.remove(e);
        }
      case SizeChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.size.set(e, old);
        } else {
          world.size.remove(e);
        }
      case FillChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.fill.set(e, old);
        } else {
          world.fill.remove(e);
        }
      case StrokeChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.stroke.set(e, old);
        } else {
          world.stroke.remove(e);
        }
      case TextChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.text.set(e, old);
        } else {
          world.text.remove(e);
        }
      case HierarchyChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.hierarchy.set(e, old);
        } else {
          world.hierarchy.remove(e);
        }
      case NameChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.name.set(e, old);
        } else {
          world.name.remove(e);
        }
      case OpacityChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.opacity.set(e, old);
        } else {
          world.opacity.remove(e);
        }
      case CornerRadiusChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.cornerRadius.set(e, old);
        } else {
          world.cornerRadius.remove(e);
        }
      case AutoLayoutChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.autoLayout.set(e, old);
        } else {
          world.autoLayout.remove(e);
        }
      case FrameMarkerChanged(entity: final e, oldValue: final old):
        if (old != null) {
          world.frame.set(e, old);
        } else {
          world.frame.remove(e);
        }
    }
  }

  void _reapplyEvent(EditorEvent event) {
    switch (event) {
      case EntitySpawned(entity: final e):
        // Re-spawn would need to reuse the same ID - complex
        // In practice, you'd track "revived" entities
        break;
      case EntityDespawned(entity: final e):
        world.despawn(e);
      case PositionChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.position.set(e, value);
        } else {
          world.position.remove(e);
        }
      case SizeChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.size.set(e, value);
        } else {
          world.size.remove(e);
        }
      case FillChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.fill.set(e, value);
        } else {
          world.fill.remove(e);
        }
      case StrokeChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.stroke.set(e, value);
        } else {
          world.stroke.remove(e);
        }
      case TextChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.text.set(e, value);
        } else {
          world.text.remove(e);
        }
      case HierarchyChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.hierarchy.set(e, value);
        } else {
          world.hierarchy.remove(e);
        }
      case NameChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.name.set(e, value);
        } else {
          world.name.remove(e);
        }
      case OpacityChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.opacity.set(e, value);
        } else {
          world.opacity.remove(e);
        }
      case CornerRadiusChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.cornerRadius.set(e, value);
        } else {
          world.cornerRadius.remove(e);
        }
      case AutoLayoutChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.autoLayout.set(e, value);
        } else {
          world.autoLayout.remove(e);
        }
      case FrameMarkerChanged(entity: final e, newValue: final value):
        if (value != null) {
          world.frame.set(e, value);
        } else {
          world.frame.remove(e);
        }
    }
  }

  void _restoreFromSnapshot(Entity entity, Map<String, dynamic> snapshot) {
    // Would need to re-register entity with allocator
    // Then restore all components
    if (snapshot['position'] != null) world.position.set(entity, snapshot['position']);
    if (snapshot['size'] != null) world.size.set(entity, snapshot['size']);
    if (snapshot['fill'] != null) world.fill.set(entity, snapshot['fill']);
    if (snapshot['stroke'] != null) world.stroke.set(entity, snapshot['stroke']);
    if (snapshot['text'] != null) world.text.set(entity, snapshot['text']);
    if (snapshot['hierarchy'] != null) world.hierarchy.set(entity, snapshot['hierarchy']);
    if (snapshot['name'] != null) world.name.set(entity, snapshot['name']);
    if (snapshot['opacity'] != null) world.opacity.set(entity, snapshot['opacity']);
    if (snapshot['cornerRadius'] != null) world.cornerRadius.set(entity, snapshot['cornerRadius']);
    if (snapshot['autoLayout'] != null) world.autoLayout.set(entity, snapshot['autoLayout']);
    if (snapshot['frame'] != null) world.frame.set(entity, snapshot['frame']);
  }
}
