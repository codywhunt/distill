/// Transform System
///
/// Computes world-space transforms for all entities.
/// Must run whenever hierarchy or positions change.

import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

import '../core/entity.dart';
import '../core/world.dart';
import '../components/components.dart';

/// Computes WorldTransform for all entities based on hierarchy and position.
class TransformSystem {
  /// Recompute all world transforms
  void updateAll(World world) {
    // Process in topological order (parents before children)
    for (final entity in world.topologicalOrder()) {
      _updateEntity(world, entity);
    }
  }

  /// Update transforms for specific entities and their descendants
  void updateSubtree(World world, Entity root) {
    _updateEntity(world, root);
    for (final descendant in world.descendantsOf(root)) {
      _updateEntity(world, descendant);
    }
  }

  void _updateEntity(World world, Entity entity) {
    final pos = world.position.get(entity);
    final hierarchy = world.hierarchy.get(entity);
    final frame = world.frame.get(entity);

    // Start with identity
    final matrix = Matrix4.identity();

    // If this is a frame, use canvas position
    if (frame != null) {
      matrix.translate(frame.canvasX, frame.canvasY);
    }

    // Apply parent transform if we have a parent
    if (hierarchy?.parent != null) {
      final parentTransform = world.worldTransform.get(hierarchy!.parent!);
      if (parentTransform != null) {
        matrix.multiply(parentTransform.matrix);
      }
    }

    // Apply local position
    if (pos != null) {
      matrix.translate(pos.x, pos.y);
    }

    world.worldTransform.set(entity, WorldTransform(matrix));
  }
}

/// Computes WorldBounds for all entities (requires transforms to be computed first)
class BoundsSystem {
  void updateAll(World world) {
    for (final entity in world.entities) {
      _updateEntity(world, entity);
    }
  }

  void updateSubtree(World world, Entity root) {
    _updateEntity(world, root);
    for (final descendant in world.descendantsOf(root)) {
      _updateEntity(world, descendant);
    }
  }

  void _updateEntity(World world, Entity entity) {
    final transform = world.worldTransform.get(entity);
    final size = world.size.get(entity);

    if (transform == null) return;

    final width = size?.width ?? 0;
    final height = size?.height ?? 0;

    // Get world position from transform
    final worldPos = transform.translation;

    world.worldBounds.set(
      entity,
      WorldBounds(Rect.fromLTWH(worldPos.dx, worldPos.dy, width, height)),
    );
  }
}
