import 'dart:ui';

import '../models/node_layout.dart';
import '../render/render_document.dart';
import '../scene/expanded_scene.dart';
import 'drop_preview.dart';

/// Input data for drop preview computation.
///
/// Bundles all the context needed to compute a DropPreview without
/// requiring direct access to CanvasState.
class DropPreviewInput {
  /// The frame being dragged within.
  final String frameId;

  /// World position of the cursor.
  final Offset worldCursorPos;

  /// Document IDs of nodes being dragged.
  final Set<String> draggedDocIds;

  /// Expanded IDs of nodes being dragged (for bounds lookup).
  final Set<String> draggedExpandedIds;

  /// The document node ID of the container hit (from hitTestContainer).
  final String? hitPatchId;

  /// The expanded ID of the container hit (from hitTestContainer).
  final String? hitExpandedId;

  /// Original parent document IDs for dragged nodes (from session.originalParents).
  final Map<String, String> originalParents;

  /// Previous insertion index (for hysteresis).
  final int? lastInsertionIndex;

  /// Previous cursor position (for hysteresis).
  final Offset? lastInsertionCursor;

  /// Current zoom level (for hysteresis threshold).
  final double zoom;

  /// Main-axis size of dragged bundle (for reflow calculation).
  final double draggedMainAxisSize;

  const DropPreviewInput({
    required this.frameId,
    required this.worldCursorPos,
    required this.draggedDocIds,
    required this.draggedExpandedIds,
    required this.hitPatchId,
    required this.hitExpandedId,
    required this.originalParents,
    required this.lastInsertionIndex,
    required this.lastInsertionCursor,
    required this.zoom,
    required this.draggedMainAxisSize,
  });
}

/// Callback type for bounds resolution.
typedef BoundsResolver = Rect? Function(String frameId, String expandedId);

/// Callback type for getting frame position.
typedef FramePositionResolver = Offset Function(String frameId);

/// Callback type for getting document nodes.
typedef NodeResolver = ({
  NodeLayout? layout,
  List<String> childIds,
})? Function(String docId);

/// Engine that computes DropPreview from input data.
///
/// This is the single source of truth for drop target computation.
/// All indicator positioning, reflow calculations, and patch decisions
/// read from the DropPreview this engine produces.
class DropPreviewEngine {
  const DropPreviewEngine();

  /// Compute a DropPreview from the given input.
  ///
  /// Returns a DropPreview with all fields populated, including:
  /// - indicatorWorldRect (already computed, overlay just paints it)
  /// - reflowOffsetsByExpandedId (for sibling animation)
  /// - childrenExpandedIds/childrenDocIds (parallel lists)
  DropPreview compute({
    required DropPreviewInput input,
    required ExpandedScene scene,
    required RenderDocument renderDoc,
    required BoundsResolver getBounds,
    required FramePositionResolver getFramePos,
    required NodeResolver getNode,
  }) {
    // Early exit if no valid hit
    if (input.hitPatchId == null || input.hitExpandedId == null) {
      return const DropPreview.none(invalidReason: 'No container hit');
    }

    final parentDocId = input.hitPatchId!;
    final parentExpandedId = input.hitExpandedId!;

    // Get parent node info
    final parentInfo = getNode(parentDocId);
    if (parentInfo == null) {
      return DropPreview.none(
        invalidReason: 'Parent node $parentDocId not found',
      );
    }

    final parentLayout = parentInfo.layout;
    final parentChildDocIds = parentInfo.childIds;

    // Get parent bounds
    final parentBounds = getBounds(input.frameId, parentExpandedId);
    if (parentBounds == null) {
      return DropPreview.none(
        invalidReason: 'Parent bounds null for $parentExpandedId',
      );
    }

    // Build the critical mapping: childDocId → childExpandedId
    // This uses the render tree structure to get the CORRECT expanded IDs
    final parentRenderNode = renderDoc.nodes[parentExpandedId];
    if (parentRenderNode == null) {
      return DropPreview.none(
        invalidReason: 'Parent render node $parentExpandedId not found',
      );
    }

    // Build docId → expandedId mapping for this parent's children
    final childDocToExpanded = <String, String>{};
    for (final childExpandedId in parentRenderNode.childIds) {
      final childDocId = scene.patchTarget[childExpandedId];
      if (childDocId != null) {
        childDocToExpanded[childDocId] = childExpandedId;
      }
    }

    // Filter children to exclude dragged nodes, maintaining parallel lists
    final childrenExpandedIds = <String>[];
    final childrenDocIds = <String>[];

    for (final childDocId in parentChildDocIds) {
      if (input.draggedDocIds.contains(childDocId)) continue;

      final childExpandedId = childDocToExpanded[childDocId];
      if (childExpandedId != null) {
        childrenExpandedIds.add(childExpandedId);
        childrenDocIds.add(childDocId);
      }
    }

    // Determine drop kind
    final firstDraggedDocId = input.draggedDocIds.firstOrNull;
    final originalParent = firstDraggedDocId != null
        ? input.originalParents[firstDraggedDocId]
        : null;

    DropPreviewKind kind;
    if (originalParent == null) {
      kind = DropPreviewKind.moveOnly;
    } else if (originalParent == parentDocId) {
      kind = DropPreviewKind.reorder;
    } else {
      kind = DropPreviewKind.reparent;
    }

    // Get auto-layout info
    final autoLayout = parentLayout?.autoLayout;
    final direction = autoLayout?.direction;

    // Calculate insertion index (with hysteresis)
    final rawIndex = _calculateInsertionIndex(
      input: input,
      parentBounds: parentBounds,
      childrenExpandedIds: childrenExpandedIds,
      direction: direction,
      getBounds: getBounds,
      getFramePos: getFramePos,
    );

    final finalIndex = _applyHysteresis(
      rawIndex: rawIndex,
      input: input,
    );

    // Calculate indicator rect (only for auto-layout parents)
    Rect? indicatorWorldRect;
    if (autoLayout != null) {
      indicatorWorldRect = _calculateIndicatorRect(
        input: input,
        parentBounds: parentBounds,
        childrenExpandedIds: childrenExpandedIds,
        insertionIndex: finalIndex,
        autoLayout: autoLayout,
        getBounds: getBounds,
        getFramePos: getFramePos,
      );
    }

    // Calculate reflow offsets
    final reflowOffsets = _calculateReflowOffsets(
      childrenExpandedIds: childrenExpandedIds,
      insertionIndex: finalIndex,
      direction: direction,
      spaceNeeded: input.draggedMainAxisSize +
          (autoLayout?.gap?.toDouble() ?? 0),
    );

    // Debug logging
    _logDropPreview(
      input: input,
      parentDocId: parentDocId,
      parentExpandedId: parentExpandedId,
      childrenExpandedIds: childrenExpandedIds,
      childrenDocIds: childrenDocIds,
      insertionIndex: finalIndex,
      indicatorWorldRect: indicatorWorldRect,
      kind: kind,
    );

    return DropPreview(
      kind: kind,
      frameId: input.frameId,
      parentDocId: parentDocId,
      parentExpandedId: parentExpandedId,
      childrenExpandedIds: childrenExpandedIds,
      childrenDocIds: childrenDocIds,
      insertionIndex: finalIndex,
      indicatorWorldRect: indicatorWorldRect,
      direction: direction,
      reflowOffsetsByExpandedId: reflowOffsets,
    );
  }

  /// Calculate raw insertion index based on cursor position.
  int _calculateInsertionIndex({
    required DropPreviewInput input,
    required Rect parentBounds,
    required List<String> childrenExpandedIds,
    required LayoutDirection? direction,
    required BoundsResolver getBounds,
    required FramePositionResolver getFramePos,
  }) {
    if (direction == null) {
      // Non-auto-layout: append to end
      return childrenExpandedIds.length;
    }

    // Convert world cursor to parent-local coordinates
    final framePos = getFramePos(input.frameId);
    final cursorFrameLocal = input.worldCursorPos - framePos;
    final cursorParentLocal = cursorFrameLocal - parentBounds.topLeft;

    // Find insertion point by comparing cursor to child centers
    for (int i = 0; i < childrenExpandedIds.length; i++) {
      final childExpandedId = childrenExpandedIds[i];
      final childBounds = getBounds(input.frameId, childExpandedId);
      if (childBounds == null) continue;

      // Child bounds are frame-local, convert to parent-local
      final childParentLocal = Rect.fromLTWH(
        childBounds.left - parentBounds.left,
        childBounds.top - parentBounds.top,
        childBounds.width,
        childBounds.height,
      );

      // Use center as threshold
      final threshold = direction == LayoutDirection.horizontal
          ? childParentLocal.center.dx
          : childParentLocal.center.dy;

      final cursorValue = direction == LayoutDirection.horizontal
          ? cursorParentLocal.dx
          : cursorParentLocal.dy;

      if (cursorValue < threshold) {
        return i;
      }
    }

    return childrenExpandedIds.length;
  }

  /// Apply hysteresis to prevent flip-flop at child centers.
  int _applyHysteresis({
    required int rawIndex,
    required DropPreviewInput input,
  }) {
    const hysteresisMarginPx = 8.0;
    final threshold = hysteresisMarginPx / input.zoom;

    if (input.lastInsertionIndex != null &&
        rawIndex != input.lastInsertionIndex &&
        input.lastInsertionCursor != null) {
      final distance =
          (input.worldCursorPos - input.lastInsertionCursor!).distance;
      if (distance < threshold) {
        return input.lastInsertionIndex!;
      }
    }

    return rawIndex;
  }

  /// Calculate the world-space rect for the insertion indicator.
  Rect? _calculateIndicatorRect({
    required DropPreviewInput input,
    required Rect parentBounds,
    required List<String> childrenExpandedIds,
    required int insertionIndex,
    required AutoLayout autoLayout,
    required BoundsResolver getBounds,
    required FramePositionResolver getFramePos,
  }) {
    final framePos = getFramePos(input.frameId);
    final direction = autoLayout.direction;
    final padding = autoLayout.padding;
    final gap = autoLayout.gap?.toDouble() ?? 0;

    // Convert parent bounds to world coordinates
    final parentWorld = Rect.fromLTWH(
      framePos.dx + parentBounds.left,
      framePos.dy + parentBounds.top,
      parentBounds.width,
      parentBounds.height,
    );

    // Get padding values
    final padLeft = padding.left.toDouble();
    final padTop = padding.top.toDouble();
    final padRight = padding.right.toDouble();
    final padBottom = padding.bottom.toDouble();

    // Empty container or index 0: draw at start
    if (childrenExpandedIds.isEmpty || insertionIndex == 0) {
      if (direction == LayoutDirection.horizontal) {
        return Rect.fromLTWH(
          parentWorld.left + padLeft,
          parentWorld.top + padTop,
          2,
          parentWorld.height - padTop - padBottom,
        );
      } else {
        return Rect.fromLTWH(
          parentWorld.left + padLeft,
          parentWorld.top + padTop,
          parentWorld.width - padLeft - padRight,
          2,
        );
      }
    }

    // Insert at end: after last child
    if (insertionIndex >= childrenExpandedIds.length) {
      final lastExpandedId = childrenExpandedIds.last;
      final lastBounds = getBounds(input.frameId, lastExpandedId);
      if (lastBounds == null) {
        // Fallback: use padding start position
        return _fallbackIndicatorRect(parentWorld, direction, padding);
      }

      final lastWorld = Rect.fromLTWH(
        framePos.dx + lastBounds.left,
        framePos.dy + lastBounds.top,
        lastBounds.width,
        lastBounds.height,
      );

      if (direction == LayoutDirection.horizontal) {
        return Rect.fromLTWH(
          lastWorld.right + gap,
          parentWorld.top + padTop,
          2,
          parentWorld.height - padTop - padBottom,
        );
      } else {
        return Rect.fromLTWH(
          parentWorld.left + padLeft,
          lastWorld.bottom + gap,
          parentWorld.width - padLeft - padRight,
          2,
        );
      }
    }

    // Insert between children
    final prevExpandedId = childrenExpandedIds[insertionIndex - 1];
    final prevBounds = getBounds(input.frameId, prevExpandedId);
    if (prevBounds == null) {
      return _fallbackIndicatorRect(parentWorld, direction, padding);
    }

    final prevWorld = Rect.fromLTWH(
      framePos.dx + prevBounds.left,
      framePos.dy + prevBounds.top,
      prevBounds.width,
      prevBounds.height,
    );

    if (direction == LayoutDirection.horizontal) {
      return Rect.fromLTWH(
        prevWorld.right + gap / 2,
        parentWorld.top + padTop,
        2,
        parentWorld.height - padTop - padBottom,
      );
    } else {
      return Rect.fromLTWH(
        parentWorld.left + padLeft,
        prevWorld.bottom + gap / 2,
        parentWorld.width - padLeft - padRight,
        2,
      );
    }
  }

  /// Fallback indicator rect when child bounds unavailable.
  Rect _fallbackIndicatorRect(
    Rect parentWorld,
    LayoutDirection direction,
    TokenEdgePadding padding,
  ) {
    final padLeft = padding.left.toDouble();
    final padTop = padding.top.toDouble();
    final padRight = padding.right.toDouble();
    final padBottom = padding.bottom.toDouble();

    if (direction == LayoutDirection.horizontal) {
      return Rect.fromLTWH(
        parentWorld.left + padLeft,
        parentWorld.top + padTop,
        2,
        parentWorld.height - padTop - padBottom,
      );
    } else {
      return Rect.fromLTWH(
        parentWorld.left + padLeft,
        parentWorld.top + padTop,
        parentWorld.width - padLeft - padRight,
        2,
      );
    }
  }

  /// Calculate reflow offsets for sibling animation.
  Map<String, Offset> _calculateReflowOffsets({
    required List<String> childrenExpandedIds,
    required int insertionIndex,
    required LayoutDirection? direction,
    required double spaceNeeded,
  }) {
    if (direction == null) return const {};

    final offsets = <String, Offset>{};

    for (var i = insertionIndex; i < childrenExpandedIds.length; i++) {
      final expandedId = childrenExpandedIds[i];

      if (direction == LayoutDirection.horizontal) {
        offsets[expandedId] = Offset(spaceNeeded, 0);
      } else {
        offsets[expandedId] = Offset(0, spaceNeeded);
      }
    }

    return offsets;
  }

  /// Debug logging for drop preview computation.
  void _logDropPreview({
    required DropPreviewInput input,
    required String parentDocId,
    required String parentExpandedId,
    required List<String> childrenExpandedIds,
    required List<String> childrenDocIds,
    required int insertionIndex,
    required Rect? indicatorWorldRect,
    required DropPreviewKind kind,
  }) {
    print('[DropPreviewEngine] ===== DROP PREVIEW COMPUTED =====');
    print('[DropPreviewEngine] cursor world: ${input.worldCursorPos}');
    print('[DropPreviewEngine] kind: $kind');
    print('[DropPreviewEngine] parentDocId: $parentDocId');
    print('[DropPreviewEngine] parentExpandedId: $parentExpandedId');
    print('[DropPreviewEngine] childrenExpandedIds: $childrenExpandedIds');
    print('[DropPreviewEngine] childrenDocIds: $childrenDocIds');
    print('[DropPreviewEngine] insertionIndex: $insertionIndex');
    print('[DropPreviewEngine] indicatorWorldRect: $indicatorWorldRect');
    print('[DropPreviewEngine] ================================');
  }
}
