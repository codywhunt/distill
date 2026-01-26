/// Drop System
///
/// Calculates drop targets, insertion indices, and reflow offsets
/// for Figma-style drag and drop in auto-layout containers.

import 'dart:ui';

import '../core/entity.dart';
import '../core/world.dart';
import '../components/components.dart';

/// Result of drop calculation - single source of truth for drop UI
class DropPreview {
  /// Type of drop operation
  final DropIntent intent;

  /// Is this a valid drop?
  final bool isValid;

  /// Target parent entity (null if invalid)
  final Entity? targetParent;

  /// Insertion index in parent's children
  final int? insertionIndex;

  /// World-space rect for insertion indicator
  final Rect? indicatorRect;

  /// Axis of the indicator (for rendering)
  final Axis? indicatorAxis;

  /// Reflow offsets for siblings (entity -> offset to apply)
  final Map<Entity, Offset> reflowOffsets;

  const DropPreview({
    required this.intent,
    required this.isValid,
    this.targetParent,
    this.insertionIndex,
    this.indicatorRect,
    this.indicatorAxis,
    this.reflowOffsets = const {},
  });

  static const invalid = DropPreview(
    intent: DropIntent.none,
    isValid: false,
  );
}

enum DropIntent {
  none,      // No valid drop
  reorder,   // Reordering within same parent
  reparent,  // Moving to different parent
}

/// Calculates drop targets and reflow animations
class DropSystem {
  /// Hysteresis distance to prevent flip-flopping at boundaries
  final double hysteresis;

  /// Previous insertion index (for hysteresis)
  int? _prevInsertionIndex;
  Entity? _prevTargetParent;

  DropSystem({this.hysteresis = 20.0});

  /// Calculate drop preview for current drag position
  DropPreview calculate({
    required World world,
    required List<Entity> draggedEntities,
    required Offset worldPosition,
    required Map<Entity, Offset> startPositions,
  }) {
    if (draggedEntities.isEmpty) return DropPreview.invalid;

    // Find deepest container at position (excluding dragged entities)
    final targetParent = _findDropTarget(
      world,
      worldPosition,
      exclude: draggedEntities.toSet(),
    );

    if (targetParent == null) {
      _resetHysteresis();
      return DropPreview.invalid;
    }

    // Get original parent of first dragged entity
    final originalParent = world.hierarchy.get(draggedEntities.first)?.parent;

    // Determine intent
    final intent = targetParent == originalParent
        ? DropIntent.reorder
        : DropIntent.reparent;

    // Calculate insertion index
    final insertionIndex = _calculateInsertionIndex(
      world,
      targetParent,
      worldPosition,
      draggedEntities,
    );

    // Calculate reflow offsets
    final reflowOffsets = _calculateReflowOffsets(
      world,
      targetParent,
      insertionIndex,
      draggedEntities,
    );

    // Calculate indicator rect
    final indicatorResult = _calculateIndicatorRect(
      world,
      targetParent,
      insertionIndex,
    );

    _prevTargetParent = targetParent;
    _prevInsertionIndex = insertionIndex;

    return DropPreview(
      intent: intent,
      isValid: true,
      targetParent: targetParent,
      insertionIndex: insertionIndex,
      indicatorRect: indicatorResult?.rect,
      indicatorAxis: indicatorResult?.axis,
      reflowOffsets: reflowOffsets,
    );
  }

  Entity? _findDropTarget(World world, Offset position, {required Set<Entity> exclude}) {
    Entity? deepest;
    int deepestDepth = -1;

    void searchRecursive(List<Entity> entities, int depth) {
      for (final entity in entities) {
        if (exclude.contains(entity)) continue;

        final bounds = world.worldBounds.get(entity);
        if (bounds == null || !bounds.contains(position)) continue;

        // Check if this is a valid drop container
        final isContainer = world.autoLayout.has(entity) ||
            world.childrenOf(entity).isNotEmpty ||
            world.frame.has(entity);

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

  int _calculateInsertionIndex(
    World world,
    Entity parent,
    Offset worldPosition,
    List<Entity> dragged,
  ) {
    final children = world.childrenOf(parent)
        .where((c) => !dragged.contains(c))
        .toList();

    if (children.isEmpty) return 0;

    final layout = world.autoLayout.get(parent);
    final isHorizontal = layout?.direction == LayoutDirection.horizontal;

    // Convert world position to parent-local
    final parentTransform = world.worldTransform.get(parent);
    final localPosition = parentTransform != null
        ? Offset(
            worldPosition.dx - parentTransform.translation.dx,
            worldPosition.dy - parentTransform.translation.dy,
          )
        : worldPosition;

    // Find insertion point based on cursor position relative to children
    for (var i = 0; i < children.length; i++) {
      final childPos = world.position.get(children[i]);
      final childSize = world.size.get(children[i]);
      if (childPos == null || childSize == null) continue;

      final childCenter = isHorizontal
          ? childPos.x + childSize.width / 2
          : childPos.y + childSize.height / 2;

      final cursorPos = isHorizontal ? localPosition.dx : localPosition.dy;

      // Apply hysteresis if same parent
      if (parent == _prevTargetParent && _prevInsertionIndex != null) {
        final prevIndex = _prevInsertionIndex!;
        if (i == prevIndex || i == prevIndex - 1) {
          // Near boundary - require larger movement to change
          final threshold = hysteresis;
          if ((cursorPos - childCenter).abs() < threshold) {
            return prevIndex;
          }
        }
      }

      if (cursorPos < childCenter) {
        return i;
      }
    }

    return children.length;
  }

  Map<Entity, Offset> _calculateReflowOffsets(
    World world,
    Entity parent,
    int insertionIndex,
    List<Entity> dragged,
  ) {
    final offsets = <Entity, Offset>{};

    final layout = world.autoLayout.get(parent);
    if (layout == null) return offsets; // No auto-layout, no reflow

    final children = world.childrenOf(parent)
        .where((c) => !dragged.contains(c))
        .toList();

    if (children.isEmpty) return offsets;

    // Calculate space needed for dragged items
    double spaceNeeded = 0;
    for (final entity in dragged) {
      final size = world.size.get(entity);
      if (size != null) {
        spaceNeeded += layout.direction == LayoutDirection.horizontal
            ? size.width
            : size.height;
      }
    }
    spaceNeeded += layout.gap * dragged.length;

    // Apply offset to children at/after insertion index
    final isHorizontal = layout.direction == LayoutDirection.horizontal;
    for (var i = insertionIndex; i < children.length; i++) {
      offsets[children[i]] = isHorizontal
          ? Offset(spaceNeeded, 0)
          : Offset(0, spaceNeeded);
    }

    return offsets;
  }

  ({Rect rect, Axis axis})? _calculateIndicatorRect(
    World world,
    Entity parent,
    int insertionIndex,
  ) {
    final layout = world.autoLayout.get(parent);
    final parentBounds = world.worldBounds.get(parent);
    final parentTransform = world.worldTransform.get(parent);

    if (parentBounds == null || parentTransform == null) return null;

    final children = world.childrenOf(parent);
    final isHorizontal = layout?.direction == LayoutDirection.horizontal;
    final axis = isHorizontal ? Axis.vertical : Axis.horizontal;

    final parentWorldPos = parentTransform.translation;
    final padding = layout?.padding ?? EdgePadding.zero;

    double indicatorPos;
    double crossStart;
    double crossEnd;

    if (children.isEmpty) {
      // Empty container - indicator at start
      indicatorPos = isHorizontal
          ? parentWorldPos.dx + padding.left
          : parentWorldPos.dy + padding.top;
      crossStart = isHorizontal
          ? parentWorldPos.dy + padding.top
          : parentWorldPos.dx + padding.left;
      crossEnd = isHorizontal
          ? parentBounds.rect.bottom - padding.bottom
          : parentBounds.rect.right - padding.right;
    } else if (insertionIndex >= children.length) {
      // After last child
      final lastChild = children.last;
      final lastPos = world.position.get(lastChild);
      final lastSize = world.size.get(lastChild);
      if (lastPos == null || lastSize == null) return null;

      indicatorPos = isHorizontal
          ? parentWorldPos.dx + lastPos.x + lastSize.width + (layout?.gap ?? 0) / 2
          : parentWorldPos.dy + lastPos.y + lastSize.height + (layout?.gap ?? 0) / 2;
      crossStart = isHorizontal
          ? parentWorldPos.dy + padding.top
          : parentWorldPos.dx + padding.left;
      crossEnd = isHorizontal
          ? parentBounds.rect.bottom - padding.bottom
          : parentBounds.rect.right - padding.right;
    } else {
      // Before a specific child
      final child = children[insertionIndex];
      final childPos = world.position.get(child);
      if (childPos == null) return null;

      indicatorPos = isHorizontal
          ? parentWorldPos.dx + childPos.x - (layout?.gap ?? 0) / 2
          : parentWorldPos.dy + childPos.y - (layout?.gap ?? 0) / 2;
      crossStart = isHorizontal
          ? parentWorldPos.dy + padding.top
          : parentWorldPos.dx + padding.left;
      crossEnd = isHorizontal
          ? parentBounds.rect.bottom - padding.bottom
          : parentBounds.rect.right - padding.right;
    }

    final rect = isHorizontal
        ? Rect.fromLTRB(indicatorPos - 1, crossStart, indicatorPos + 1, crossEnd)
        : Rect.fromLTRB(crossStart, indicatorPos - 1, crossEnd, indicatorPos + 1);

    return (rect: rect, axis: axis);
  }

  void _resetHysteresis() {
    _prevInsertionIndex = null;
    _prevTargetParent = null;
  }

  /// Call when drag ends
  void reset() {
    _resetHysteresis();
  }
}
