/// ECS Events & Event Sourcing
///
/// All mutations to the World happen through Events.
/// Events are stored in a log, enabling undo/redo and collaboration.

import 'dart:ui';

import 'entity.dart';
import 'world.dart';
import '../components/components.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENT DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════

/// Base class for all events
sealed class EditorEvent {
  final DateTime timestamp;
  final String? groupId; // For grouping related events (drag operations, etc.)

  EditorEvent({
    DateTime? timestamp,
    this.groupId,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// Entity Lifecycle Events
// ─────────────────────────────────────────────────────────────────────────────

class EntitySpawned extends EditorEvent {
  final Entity entity;

  EntitySpawned(this.entity, {super.groupId});
}

class EntityDespawned extends EditorEvent {
  final Entity entity;
  // Store all component data for undo
  final Map<String, dynamic> componentSnapshot;

  EntityDespawned(this.entity, this.componentSnapshot, {super.groupId});
}

// ─────────────────────────────────────────────────────────────────────────────
// Component Events
// ─────────────────────────────────────────────────────────────────────────────

class PositionChanged extends EditorEvent {
  final Entity entity;
  final Position? oldValue;
  final Position? newValue;

  PositionChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class SizeChanged extends EditorEvent {
  final Entity entity;
  final Size? oldValue;
  final Size? newValue;

  SizeChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class FillChanged extends EditorEvent {
  final Entity entity;
  final Fill? oldValue;
  final Fill? newValue;

  FillChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class StrokeChanged extends EditorEvent {
  final Entity entity;
  final Stroke? oldValue;
  final Stroke? newValue;

  StrokeChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class TextChanged extends EditorEvent {
  final Entity entity;
  final TextContent? oldValue;
  final TextContent? newValue;

  TextChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class HierarchyChanged extends EditorEvent {
  final Entity entity;
  final Hierarchy? oldValue;
  final Hierarchy? newValue;

  HierarchyChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class NameChanged extends EditorEvent {
  final Entity entity;
  final Name? oldValue;
  final Name? newValue;

  NameChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class OpacityChanged extends EditorEvent {
  final Entity entity;
  final Opacity? oldValue;
  final Opacity? newValue;

  OpacityChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class CornerRadiusChanged extends EditorEvent {
  final Entity entity;
  final CornerRadius? oldValue;
  final CornerRadius? newValue;

  CornerRadiusChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class AutoLayoutChanged extends EditorEvent {
  final Entity entity;
  final AutoLayout? oldValue;
  final AutoLayout? newValue;

  AutoLayoutChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

class FrameMarkerChanged extends EditorEvent {
  final Entity entity;
  final FrameMarker? oldValue;
  final FrameMarker? newValue;

  FrameMarkerChanged(this.entity, this.oldValue, this.newValue, {super.groupId});
}

// ═══════════════════════════════════════════════════════════════════════════
// EVENT STORE
// ═══════════════════════════════════════════════════════════════════════════

/// Stores events and manages undo/redo
class EventStore {
  final List<EditorEvent> _events = [];
  final Map<int, World> _snapshots = {}; // Periodic snapshots for fast replay
  int _currentIndex = 0;

  /// Snapshot interval - take a snapshot every N events
  static const int snapshotInterval = 50;

  /// Maximum events to keep (older events are compacted)
  static const int maxEvents = 1000;

  /// Add an event to the store
  void push(EditorEvent event) {
    // If we're not at the end, truncate future events
    if (_currentIndex < _events.length) {
      _events.removeRange(_currentIndex, _events.length);
      // Remove invalidated snapshots
      _snapshots.removeWhere((index, _) => index >= _currentIndex);
    }

    _events.add(event);
    _currentIndex = _events.length;

    // Take snapshot if needed
    if (_currentIndex % snapshotInterval == 0) {
      // Snapshot would be taken here - requires access to World
      // In practice, you'd pass the current world state
    }

    // Compact old events if needed
    if (_events.length > maxEvents) {
      _compact();
    }
  }

  /// Push multiple events as a batch
  void pushAll(List<EditorEvent> events) {
    for (final event in events) {
      push(event);
    }
  }

  /// Can undo?
  bool get canUndo => _currentIndex > 0;

  /// Can redo?
  bool get canRedo => _currentIndex < _events.length;

  /// Move back one event (returns events to unapply)
  EditorEvent? undo() {
    if (!canUndo) return null;
    _currentIndex--;
    return _events[_currentIndex];
  }

  /// Move forward one event (returns event to reapply)
  EditorEvent? redo() {
    if (!canRedo) return null;
    final event = _events[_currentIndex];
    _currentIndex++;
    return event;
  }

  /// Undo a group of events (e.g., all events from a drag operation)
  List<EditorEvent> undoGroup() {
    if (!canUndo) return [];

    final events = <EditorEvent>[];
    final groupId = _events[_currentIndex - 1].groupId;

    // If no group, just undo single event
    if (groupId == null) {
      final event = undo();
      if (event != null) events.add(event);
      return events;
    }

    // Undo all events in the group
    while (canUndo && _events[_currentIndex - 1].groupId == groupId) {
      events.add(_events[_currentIndex - 1]);
      _currentIndex--;
    }

    return events;
  }

  /// Redo a group of events
  List<EditorEvent> redoGroup() {
    if (!canRedo) return [];

    final events = <EditorEvent>[];
    final groupId = _events[_currentIndex].groupId;

    // If no group, just redo single event
    if (groupId == null) {
      final event = redo();
      if (event != null) events.add(event);
      return events;
    }

    // Redo all events in the group
    while (canRedo && _events[_currentIndex].groupId == groupId) {
      events.add(_events[_currentIndex]);
      _currentIndex++;
    }

    return events;
  }

  /// Get all events up to current index (for replay)
  List<EditorEvent> get activeEvents => _events.sublist(0, _currentIndex);

  /// Get events since a specific index
  List<EditorEvent> eventsSince(int index) {
    if (index >= _currentIndex) return [];
    return _events.sublist(index, _currentIndex);
  }

  /// Current position in event log
  int get currentIndex => _currentIndex;

  /// Total events in log
  int get length => _events.length;

  void _compact() {
    // Remove oldest events, keeping snapshots valid
    final removeCount = _events.length - maxEvents;
    _events.removeRange(0, removeCount);
    _currentIndex -= removeCount;

    // Adjust snapshot indices
    final newSnapshots = <int, World>{};
    for (final entry in _snapshots.entries) {
      final newIndex = entry.key - removeCount;
      if (newIndex >= 0) {
        newSnapshots[newIndex] = entry.value;
      }
    }
    _snapshots.clear();
    _snapshots.addAll(newSnapshots);
  }

  /// Store a snapshot at current index
  void takeSnapshot(World world) {
    // Would need to deep-copy the world state
    // _snapshots[_currentIndex] = world.deepCopy();
  }

  /// Find nearest snapshot before an index
  int? nearestSnapshotBefore(int index) {
    int? nearest;
    for (final snapshotIndex in _snapshots.keys) {
      if (snapshotIndex <= index && (nearest == null || snapshotIndex > nearest)) {
        nearest = snapshotIndex;
      }
    }
    return nearest;
  }
}
