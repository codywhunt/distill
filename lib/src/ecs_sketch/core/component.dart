/// ECS Core: Component Storage
///
/// Components are pure data containers - no behavior, just fields.
/// ComponentTable provides typed storage for each component type.

import 'entity.dart';

/// Marker interface for components (optional, for type safety)
abstract class Component {}

/// Storage for a single component type.
/// Uses a sparse map internally - efficient for most game/editor use cases.
/// For cache-optimal iteration, you'd use dense arrays (archetypes).
class ComponentTable<T> {
  final Map<Entity, T> _data = {};

  /// Get component for entity, or null if not present
  T? get(Entity entity) => _data[entity];

  /// Get component for entity, throwing if not present
  T require(Entity entity) {
    final value = _data[entity];
    if (value == null) {
      throw StateError('Entity $entity missing required component ${T.runtimeType}');
    }
    return value;
  }

  /// Set component for entity
  void set(Entity entity, T value) => _data[entity] = value;

  /// Remove component from entity
  T? remove(Entity entity) => _data.remove(entity);

  /// Check if entity has this component
  bool has(Entity entity) => _data.containsKey(entity);

  /// Iterate all (entity, component) pairs
  Iterable<(Entity, T)> get entries =>
      _data.entries.map((e) => (e.key, e.value));

  /// Iterate just the entities that have this component
  Iterable<Entity> get entities => _data.keys;

  /// Count of entities with this component
  int get length => _data.length;

  /// Clear all data
  void clear() => _data.clear();

  /// Bulk remove for entity cleanup
  void removeAll(Iterable<Entity> entities) {
    for (final e in entities) {
      _data.remove(e);
    }
  }
}

/// Extension for joining multiple tables (query building)
extension ComponentTableJoin<A> on ComponentTable<A> {
  /// Inner join with another table
  Iterable<(Entity, A, B)> join<B>(ComponentTable<B> other) sync* {
    for (final (entity, a) in entries) {
      final b = other.get(entity);
      if (b != null) {
        yield (entity, a, b);
      }
    }
  }

  /// Inner join with two other tables
  Iterable<(Entity, A, B, C)> join2<B, C>(
    ComponentTable<B> b,
    ComponentTable<C> c,
  ) sync* {
    for (final (entity, aVal) in entries) {
      final bVal = b.get(entity);
      final cVal = c.get(entity);
      if (bVal != null && cVal != null) {
        yield (entity, aVal, bVal, cVal);
      }
    }
  }

  /// Left join - include entities even if they don't have the other component
  Iterable<(Entity, A, B?)> leftJoin<B>(ComponentTable<B> other) sync* {
    for (final (entity, a) in entries) {
      yield (entity, a, other.get(entity));
    }
  }

  /// Filter to entities that DON'T have another component
  Iterable<(Entity, A)> without<B>(ComponentTable<B> excluded) sync* {
    for (final (entity, a) in entries) {
      if (!excluded.has(entity)) {
        yield (entity, a);
      }
    }
  }
}
