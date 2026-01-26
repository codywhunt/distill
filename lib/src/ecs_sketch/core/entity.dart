/// ECS Core: Entity
///
/// An Entity is just an identifier - a lightweight handle to a "thing" in the world.
/// Entities have no data or behavior themselves; they gain capabilities through Components.

/// Entity is just an integer ID for maximum performance.
/// Using a typedef keeps the code readable while maintaining efficiency.
typedef Entity = int;

/// Generates unique entity IDs.
/// In production, you might want UUIDs for distributed systems.
class EntityAllocator {
  int _next = 0;
  final Set<Entity> _alive = {};
  final Set<Entity> _recycled = {};

  /// Spawn a new entity
  Entity spawn() {
    final Entity entity;
    if (_recycled.isNotEmpty) {
      entity = _recycled.first;
      _recycled.remove(entity);
    } else {
      entity = _next++;
    }
    _alive.add(entity);
    return entity;
  }

  /// Despawn an entity (marks for recycling)
  void despawn(Entity entity) {
    _alive.remove(entity);
    _recycled.add(entity);
  }

  /// Check if entity is alive
  bool isAlive(Entity entity) => _alive.contains(entity);

  /// All living entities
  Set<Entity> get alive => Set.unmodifiable(_alive);

  /// Count of living entities
  int get count => _alive.length;
}
