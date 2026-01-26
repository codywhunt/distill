/// Hit Test System
///
/// Determines which entity is under a given point.

import 'dart:ui';

import '../core/entity.dart';
import '../core/world.dart';
import '../components/components.dart';

/// Result of a hit test
class HitTestResult {
  /// The entity that was hit (null if nothing hit)
  final Entity? entity;

  /// All entities under the point, from front to back
  final List<Entity> all;

  /// The frame containing the hit, if any
  final Entity? frame;

  const HitTestResult({
    this.entity,
    this.all = const [],
    this.frame,
  });

  bool get hit => entity != null;
}

/// Performs hit testing against world entities
class HitTestSystem {
  /// Find the topmost entity at a world-space point
  HitTestResult hitTest(World world, Offset worldPoint) {
    final hits = <(Entity, int)>[]; // entity, depth
    Entity? hitFrame;

    // First, find which frame we're in (if any)
    for (final (entity, frame) in world.frame.entries) {
      final bounds = world.worldBounds.get(entity);
      if (bounds != null && bounds.contains(worldPoint)) {
        hitFrame = entity;
        break;
      }
    }

    // Then find all entities under the point
    _hitTestRecursive(world, worldPoint, world.roots.toList(), 0, hits);

    if (hits.isEmpty) {
      return HitTestResult(frame: hitFrame);
    }

    // Sort by depth (deepest first = highest z-order wins)
    hits.sort((a, b) => b.$2.compareTo(a.$2));

    return HitTestResult(
      entity: hits.first.$1,
      all: hits.map((h) => h.$1).toList(),
      frame: hitFrame,
    );
  }

  void _hitTestRecursive(
    World world,
    Offset point,
    List<Entity> entities,
    int depth,
    List<(Entity, int)> hits,
  ) {
    for (final entity in entities) {
      // Skip invisible entities
      final visibility = world.visibility.get(entity);
      if (visibility != null && !visibility.isVisible) continue;

      final bounds = world.worldBounds.get(entity);
      if (bounds != null && bounds.contains(point)) {
        hits.add((entity, depth));
      }

      // Recurse into children
      final children = world.childrenOf(entity);
      if (children.isNotEmpty) {
        _hitTestRecursive(world, point, children, depth + 1, hits);
      }
    }
  }

  /// Find the deepest container at a point (for drop targeting)
  Entity? findDeepestContainer(World world, Offset point, {Set<Entity>? exclude}) {
    Entity? deepest;
    int deepestDepth = -1;

    void searchRecursive(List<Entity> entities, int depth) {
      for (final entity in entities) {
        if (exclude?.contains(entity) ?? false) continue;

        final bounds = world.worldBounds.get(entity);
        if (bounds == null || !bounds.contains(point)) continue;

        // Check if this is a container (has auto-layout or has children)
        final isContainer = world.autoLayout.has(entity) ||
            world.childrenOf(entity).isNotEmpty;

        if (isContainer && depth > deepestDepth) {
          deepest = entity;
          deepestDepth = depth;
        }

        searchRecursive(world.childrenOf(entity), depth + 1);
      }
    }

    searchRecursive(world.roots.toList(), 0);
    return deepest;
  }

  /// Find all entities within a selection rectangle
  List<Entity> hitTestRect(World world, Rect rect) {
    final hits = <Entity>[];

    for (final (entity, bounds) in world.worldBounds.entries) {
      // Skip frames - we're selecting content, not frames
      if (world.frame.has(entity)) continue;

      if (rect.overlaps(bounds.rect)) {
        hits.add(entity);
      }
    }

    return hits;
  }
}
