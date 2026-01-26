/// Layout System
///
/// Computes positions and sizes for entities with AutoLayout.
/// Similar to CSS Flexbox.

import 'dart:math' as math;

import '../core/entity.dart';
import '../core/world.dart';
import '../components/components.dart';

/// Computes layout for auto-layout containers
class LayoutSystem {
  /// Run layout for all auto-layout containers
  void updateAll(World world) {
    // Process in topological order so children are sized before parents
    // that might depend on them (for hug contents)
    for (final entity in world.topologicalOrder()) {
      final autoLayout = world.autoLayout.get(entity);
      if (autoLayout != null) {
        _layoutContainer(world, entity, autoLayout);
      }
    }
  }

  /// Layout a single container and its children
  void _layoutContainer(World world, Entity container, AutoLayout layout) {
    final children = world.childrenOf(container);
    if (children.isEmpty) return;

    final containerSize = world.size.get(container);
    if (containerSize == null) return;

    final isHorizontal = layout.direction == LayoutDirection.horizontal;

    // Available space after padding
    final availableMain = isHorizontal
        ? containerSize.width - layout.padding.horizontal
        : containerSize.height - layout.padding.vertical;
    final availableCross = isHorizontal
        ? containerSize.height - layout.padding.vertical
        : containerSize.width - layout.padding.horizontal;

    // Measure children
    final childSizes = <Entity, Size>{};
    double totalMain = 0;

    for (final child in children) {
      final size = world.size.get(child);
      if (size != null) {
        childSizes[child] = size;
        totalMain += isHorizontal ? size.width : size.height;
      }
    }

    // Total gap space
    final totalGap = layout.gap * (children.length - 1);
    final remainingSpace = availableMain - totalMain - totalGap;

    // Calculate starting position and spacing based on alignment
    double mainStart;
    double spacing;

    switch (layout.mainAxisAlignment) {
      case MainAxisAlignment.start:
        mainStart = isHorizontal ? layout.padding.left : layout.padding.top;
        spacing = layout.gap;
      case MainAxisAlignment.center:
        mainStart = (isHorizontal ? layout.padding.left : layout.padding.top) +
            remainingSpace / 2;
        spacing = layout.gap;
      case MainAxisAlignment.end:
        mainStart = (isHorizontal ? layout.padding.left : layout.padding.top) +
            remainingSpace;
        spacing = layout.gap;
      case MainAxisAlignment.spaceBetween:
        mainStart = isHorizontal ? layout.padding.left : layout.padding.top;
        spacing = children.length > 1
            ? (remainingSpace + totalGap) / (children.length - 1)
            : 0;
      case MainAxisAlignment.spaceAround:
        final space = (remainingSpace + totalGap) / children.length;
        mainStart = (isHorizontal ? layout.padding.left : layout.padding.top) +
            space / 2;
        spacing = space;
      case MainAxisAlignment.spaceEvenly:
        final space = (remainingSpace + totalGap) / (children.length + 1);
        mainStart =
            (isHorizontal ? layout.padding.left : layout.padding.top) + space;
        spacing = space;
    }

    // Position each child
    double currentMain = mainStart;

    for (final child in children) {
      final childSize = childSizes[child];
      if (childSize == null) continue;

      final childMain = isHorizontal ? childSize.width : childSize.height;
      final childCross = isHorizontal ? childSize.height : childSize.width;

      // Calculate cross-axis position
      double crossPos;
      switch (layout.crossAxisAlignment) {
        case CrossAxisAlignment.start:
          crossPos = isHorizontal ? layout.padding.top : layout.padding.left;
        case CrossAxisAlignment.center:
          crossPos =
              (isHorizontal ? layout.padding.top : layout.padding.left) +
                  (availableCross - childCross) / 2;
        case CrossAxisAlignment.end:
          crossPos =
              (isHorizontal ? layout.padding.top : layout.padding.left) +
                  (availableCross - childCross);
        case CrossAxisAlignment.stretch:
          crossPos = isHorizontal ? layout.padding.top : layout.padding.left;
          // Also update child size to stretch
          if (isHorizontal) {
            world.size.set(child, Size(childSize.width, availableCross));
          } else {
            world.size.set(child, Size(availableCross, childSize.height));
          }
      }

      // Set child position
      final newPos = isHorizontal
          ? Position(currentMain, crossPos)
          : Position(crossPos, currentMain);

      world.position.set(child, newPos);

      currentMain += childMain + spacing;
    }
  }
}

/// Calculates "hug contents" size for containers
class HugContentsSystem {
  void updateAll(World world) {
    // Process leaves first, then up to roots (reverse topological order)
    final entities = world.topologicalOrder().toList().reversed;

    for (final entity in entities) {
      final autoLayout = world.autoLayout.get(entity);
      // Only process auto-layout containers (they might hug contents)
      if (autoLayout == null) continue;

      final children = world.childrenOf(entity);
      if (children.isEmpty) continue;

      // Calculate bounds of children
      double maxRight = 0;
      double maxBottom = 0;

      for (final child in children) {
        final pos = world.position.get(child);
        final size = world.size.get(child);
        if (pos != null && size != null) {
          maxRight = math.max(maxRight, pos.x + size.width);
          maxBottom = math.max(maxBottom, pos.y + size.height);
        }
      }

      // Update container size to hug children (plus padding)
      final currentSize = world.size.get(entity);
      if (currentSize != null) {
        // Only update if configured to hug (would need a flag for this)
        // For now, this just shows how it would work
      }
    }
  }
}
