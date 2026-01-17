import 'package:flutter/painting.dart';

import '../../models/editor_document.dart';
import '../../models/node_layout.dart';
import '../../render/render_document.dart';
import '../../scene/expanded_scene.dart';
import 'container_hit.dart';
import 'drag_debug.dart';
import 'drop_intent.dart';
import 'drop_preview.dart';
import 'frame_lookups.dart';

// =============================================================================
// Constants
// =============================================================================

/// Hysteresis threshold in screen pixels.
///
/// Prevents flip-flop at slot boundaries by requiring cursor to move
/// this distance before changing insertion index.
const double kHysteresisPixels = 8.0;

/// Indicator line thickness in screen pixels.
const double kIndicatorThicknessPx = 2.0;

/// Minimum indicator size after clipping (screen pixels).
///
/// If indicator becomes smaller than this after clipping to content box,
/// we return null (content area too small).
const double kMinIndicatorSizePx = 6.0;

// =============================================================================
// Callback Type Definitions
// =============================================================================

/// Resolves bounds for a node in frame-local coordinates.
///
/// Returns null if bounds are not available.
typedef BoundsResolver = Rect? Function(String frameId, String expandedId);

/// Gets frame position in world coordinates.
typedef FramePositionResolver = Offset Function(String frameId);

/// Hit tests for a container at a world position.
///
/// Returns [ContainerHit] with expandedId as primary (INV-1).
/// Should exclude nodes in [excludeExpandedIds] from hit testing.
typedef ContainerHitResolver = ContainerHit? Function(
  String frameId,
  Offset worldPos,
  Set<String> excludeExpandedIds,
);

// =============================================================================
// DropPreviewBuilder
// =============================================================================

/// Builder that computes [DropPreview] from input state.
///
/// This is the single source of truth for drop preview computation.
/// The builder is a pure function with no side effects - given the same
/// inputs, it always produces the same output.
///
/// ## Algorithm Overview
///
/// 1. **Early validation**: Check INV-7 (same-parent multi-select)
/// 2. **Use locked frame**: INV-5 - frame is fixed at drag start
/// 3. **Hit test container**: INV-1 - expandedId is primary
/// 4. **Climb to auto-layout**: INV-4 - absolute containers climb
/// 5. **Validate patchability**: INV-8 - target must be patchable
/// 6. **Build children list**: INV-2 - from renderDoc.nodes
/// 7. **Compute insertion index**: With hysteresis to prevent flip-flop
/// 8. **Compute indicator rect**: INV-6 - clipped to content box
/// 9. **Compute reflow offsets**: INV-3 - keys exist in renderDoc
/// 10. **Determine intent**: Reorder vs reparent
///
/// ## Usage
///
/// ```dart
/// final builder = DropPreviewBuilder();
/// final preview = builder.compute(
///   lockedFrameId: session.lockedFrameId!,
///   cursorWorld: cursorWorld,
///   // ... other params ...
/// );
/// session.dropPreview = preview;
/// ```
class DropPreviewBuilder {
  const DropPreviewBuilder();

  /// Compute a [DropPreview] from the given input state.
  ///
  /// All parameters are required except hysteresis state which can be null
  /// on first computation.
  ///
  /// ## Parameters
  ///
  /// - [lockedFrameId]: Frame containing dragged nodes (INV-5)
  /// - [cursorWorld]: Current cursor position in world coordinates
  /// - [draggedDocIdsOrdered]: Document IDs being dragged (ordered)
  /// - [draggedExpandedIdsOrdered]: Expanded IDs being dragged (parallel)
  /// - [originalParents]: Map of docId -> original parent docId
  /// - [lastInsertionIndex]: Previous insertion index (for hysteresis)
  /// - [lastInsertionCursor]: Cursor when index last changed (for hysteresis)
  /// - [zoom]: Current zoom level (for threshold calculations)
  ///
  /// ## Dependencies (injected for testability)
  ///
  /// - [document]: Editor document for node access
  /// - [scene]: Expanded scene for patchTarget lookup
  /// - [renderDoc]: Render document for children list
  /// - [lookups]: Pre-computed ID mappings
  /// - [getBounds]: Bounds resolver function
  /// - [getFramePos]: Frame position resolver function
  /// - [hitTestContainer]: Container hit test function
  /// - [originParentExpandedId]: For stickiness - prefer reorder when resolved
  ///   target is origin parent and cursor is inside origin content rect
  /// - [originParentContentWorldRect]: Content bounds for stickiness check
  DropPreview compute({
    required String lockedFrameId,
    required Offset cursorWorld,
    required List<String> draggedDocIdsOrdered,
    required List<String> draggedExpandedIdsOrdered,
    required Map<String, String> originalParents,
    required int? lastInsertionIndex,
    required Offset? lastInsertionCursor,
    required double zoom,
    // Dependencies
    required EditorDocument document,
    required ExpandedScene scene,
    required RenderDocument renderDoc,
    required FrameLookups lookups,
    required BoundsResolver getBounds,
    required FramePositionResolver getFramePos,
    required ContainerHitResolver hitTestContainer,
    // Origin stickiness (optional)
    String? originParentExpandedId,
    Rect? originParentContentWorldRect,
  }) {
    final draggedDocIds = draggedDocIdsOrdered.toSet();
    final draggedExpandedIds = draggedExpandedIdsOrdered.toSet();

    // -------------------------------------------------------------------------
    // Step 0: Early Validation
    // -------------------------------------------------------------------------

    // INV-7: Validate multi-select same origin parent
    final originParent = _getOriginParent(originalParents);
    if (originalParents.isNotEmpty && originParent == null) {
      _debugLog('INV-7 violation: multi-select across different parents');
      return DropPreview.none(
        frameId: lockedFrameId,
        invalidReason: 'multi-select across different parents not supported',
        draggedDocIdsOrdered: draggedDocIdsOrdered,
        draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
      );
    }

    // Validate dragged nodes exist
    for (final docId in draggedDocIdsOrdered) {
      if (document.nodes[docId] == null) {
        _debugLog('Dragged node not found: $docId');
        return DropPreview.none(
          frameId: lockedFrameId,
          invalidReason: 'dragged node $docId not found',
          draggedDocIdsOrdered: draggedDocIdsOrdered,
          draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
        );
      }
    }

    // -------------------------------------------------------------------------
    // Step 1: Use Locked Frame (INV-5)
    // -------------------------------------------------------------------------

    final frameId = lockedFrameId;
    final framePos = getFramePos(frameId);
    final cursorFrameLocal = cursorWorld - framePos;

    _debugLog('Frame: $frameId, cursor: $cursorWorld, frameLocal: $cursorFrameLocal');

    // -------------------------------------------------------------------------
    // Step 1b: Origin-First Targeting (INV-Z)
    // -------------------------------------------------------------------------
    // If cursor is inside origin content rect (+ hysteresis), use origin as
    // target WITHOUT running hit-test. This prevents nested containers from
    // "stealing" the drop target during reorder operations.

    String? targetExpandedId;
    String? targetDocId;
    // Track hovered container for debug logging (may differ from resolved target)
    String? hoveredExpandedId;
    String? hoveredDocId;

    if (originParentExpandedId != null &&
        originParentContentWorldRect != null) {
      // Safety: don't origin-lock if origin parent is being dragged
      if (!draggedExpandedIds.contains(originParentExpandedId)) {
        final stickyRect =
            originParentContentWorldRect.inflate(kHysteresisPixels / zoom);

        if (stickyRect.contains(cursorWorld)) {
          final originDocId = lookups.getDocId(originParentExpandedId);
          // Safety: origin must be patchable
          if (originDocId != null) {
            final originNode = document.nodes[originDocId];
            if (originNode?.layout.autoLayout != null) {
              _debugLog(
                  'Origin-first: cursor inside origin rect, target = origin');
              targetExpandedId = originParentExpandedId;
              targetDocId = originDocId;
              hoveredExpandedId = originParentExpandedId;
              hoveredDocId = originDocId;
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Step 2: Hit Test Container (INV-1) - only if origin-first didn't match
    // -------------------------------------------------------------------------

    if (targetExpandedId == null) {
      final hit = hitTestContainer(frameId, cursorWorld, draggedExpandedIds);
      if (hit == null) {
        _debugLog('No container hit');
        return DropPreview.none(
          frameId: frameId,
          invalidReason: 'no container hit',
          draggedDocIdsOrdered: draggedDocIdsOrdered,
          draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
        );
      }

      _debugLog('Hit: expandedId=${hit.expandedId}, docId=${hit.docId}');
      hoveredExpandedId = hit.expandedId;
      hoveredDocId = hit.docId;

      // -----------------------------------------------------------------------
      // Step 3: Climb to Auto-Layout Ancestor (INV-4)
      // -----------------------------------------------------------------------

      final resolved = _resolveEligibleTarget(
        hit: hit,
        document: document,
        lookups: lookups,
        draggedExpandedIds: draggedExpandedIds,
      );

      if (resolved == null) {
        _debugLog('No auto-layout ancestor found');
        return DropPreview.none(
          frameId: frameId,
          invalidReason: 'no auto-layout ancestor found',
          draggedDocIdsOrdered: draggedDocIdsOrdered,
          draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
        );
      }

      targetExpandedId = resolved.expandedId;
      targetDocId = resolved.docId;
    }

    _debugLog('Resolved target: expandedId=$targetExpandedId, docId=$targetDocId');

    // -------------------------------------------------------------------------
    // Step 4: Validate Patchability & Constraints
    // -------------------------------------------------------------------------

    // INV-8: Target must be patchable
    if (targetDocId == null) {
      _debugLog('Target not patchable');
      return DropPreview.none(
        frameId: frameId,
        invalidReason: 'target container is not patchable',
        draggedDocIdsOrdered: draggedDocIdsOrdered,
        draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
      );
    }

    // Target node must exist
    final targetNode = document.nodes[targetDocId];
    if (targetNode == null) {
      _debugLog('Target node not found: $targetDocId');
      return DropPreview.none(
        frameId: frameId,
        invalidReason: 'target node $targetDocId not found',
        draggedDocIdsOrdered: draggedDocIdsOrdered,
        draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
      );
    }

    // Check for circular reference
    for (final draggedDocId in draggedDocIdsOrdered) {
      if (_isAncestorOrSelf(draggedDocId, targetDocId, document)) {
        _debugLog('Circular reference: cannot drop into own descendant');
        return DropPreview.none(
          frameId: frameId,
          invalidReason: 'cannot drop into own descendant',
          draggedDocIdsOrdered: draggedDocIdsOrdered,
          draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
        );
      }
    }

    // -------------------------------------------------------------------------
    // Step 5: Build Children List from Render Tree (INV-2)
    // -------------------------------------------------------------------------

    final targetRenderNode = renderDoc.nodes[targetExpandedId];
    if (targetRenderNode == null) {
      _debugLog('Target render node not found: $targetExpandedId');
      return DropPreview.none(
        frameId: frameId,
        invalidReason: 'target render node not found',
        draggedDocIdsOrdered: draggedDocIdsOrdered,
        draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
      );
    }

    final childrenExpanded = <String>[];
    final childrenDoc = <String>[];

    for (final childExpandedId in targetRenderNode.childIds) {
      final childDocId = lookups.getDocId(childExpandedId);

      // Skip unpatchable children (v1)
      if (childDocId == null) continue;

      // Skip dragged nodes
      if (draggedDocIds.contains(childDocId)) continue;
      if (draggedExpandedIds.contains(childExpandedId)) continue;

      childrenExpanded.add(childExpandedId);
      childrenDoc.add(childDocId);
    }

    _debugLog('Filtered children: ${childrenExpanded.length}');

    // -------------------------------------------------------------------------
    // Step 6: Compute Insertion Index with Hysteresis
    // -------------------------------------------------------------------------

    final autoLayout = targetNode.layout.autoLayout!;
    final direction = autoLayout.direction;

    final rawIndex = _computeRawInsertionIndex(
      cursorFrameLocal: cursorFrameLocal,
      targetExpandedId: targetExpandedId,
      childrenExpanded: childrenExpanded,
      direction: direction,
      frameId: frameId,
      getBounds: getBounds,
    );

    final insertionIndex = _applyHysteresis(
      rawIndex: rawIndex,
      lastIndex: lastInsertionIndex,
      cursorWorld: cursorWorld,
      lastCursor: lastInsertionCursor,
      zoom: zoom,
    );

    _debugLog('Insertion index: raw=$rawIndex, final=$insertionIndex');

    // -------------------------------------------------------------------------
    // Step 7: Compute Indicator Rect (INV-6)
    // -------------------------------------------------------------------------

    final indicatorResult = _computeIndicatorRect(
      targetExpandedId: targetExpandedId,
      targetDocId: targetDocId,
      childrenExpanded: childrenExpanded,
      insertionIndex: insertionIndex,
      autoLayout: autoLayout,
      frameId: frameId,
      framePos: framePos,
      zoom: zoom,
      getBounds: getBounds,
      document: document,
    );

    _debugLog('Indicator: ${indicatorResult?.rect}');

    // -------------------------------------------------------------------------
    // Step 8: Determine Intent (moved before reflow for INV-9)
    // -------------------------------------------------------------------------

    final intent = _determineIntent(
      originParent: originParent,
      targetDocId: targetDocId,
    );

    _debugLog('Intent: $intent');

    // -------------------------------------------------------------------------
    // Step 9: Compute Reflow Offsets (INV-3, INV-9)
    // -------------------------------------------------------------------------
    // INV-9: Only compute reflow for reorder intent - matches Figma behavior
    // where siblings only move aside during reorder, not reparent.

    final reflowOffsets = (intent == DropIntent.reorder)
        ? _computeReflowOffsets(
            childrenExpanded: childrenExpanded,
            insertionIndex: insertionIndex,
            direction: direction,
            draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
            frameId: frameId,
            autoLayout: autoLayout,
            getBounds: getBounds,
            renderDoc: renderDoc,
            lookups: lookups,
          )
        : const <String, Offset>{};

    // -------------------------------------------------------------------------
    // Step 10: Build and Return DropPreview
    // -------------------------------------------------------------------------

    // INV-Y: Valid drop (intent != none) requires non-null indicator
    if (indicatorResult == null && intent != DropIntent.none) {
      _debugLog('INV-Y: Indicator null for $intent - marking invalid');
      return DropPreview.none(
        frameId: frameId,
        invalidReason: 'could not compute indicator for target',
        draggedDocIdsOrdered: draggedDocIdsOrdered,
        draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
      );
    }

    final preview = DropPreview(
      intent: intent,
      isValid: true,
      frameId: frameId,
      draggedDocIdsOrdered: draggedDocIdsOrdered,
      draggedExpandedIdsOrdered: draggedExpandedIdsOrdered,
      targetParentDocId: targetDocId,
      targetParentExpandedId: targetExpandedId,
      targetChildrenExpandedIds: childrenExpanded,
      targetChildrenDocIds: childrenDoc,
      insertionIndex: insertionIndex,
      indicatorWorldRect: indicatorResult?.rect,
      indicatorAxis: indicatorResult?.axis,
      reflowOffsetsByExpandedId: reflowOffsets,
    );

    // INV-8: Final assertion
    assert(
      !preview.isValid ||
          (preview.targetParentDocId != null &&
              preview.targetParentExpandedId != null),
      'INV-8: isValid implies both target IDs are non-null',
    );

    // Consolidated debug log with all intermediate values per spec Section 12
    DragDebugLogger.logDropPreview(
      preview,
      hoveredExpandedId: hoveredExpandedId,
      hoveredDocId: hoveredDocId,
      isAutoLayout: true, // We only reach here if target is auto-layout
    );

    return preview;
  }

  // ===========================================================================
  // Helper Methods
  // ===========================================================================

  /// Get the single origin parent from originalParents map.
  ///
  /// Returns null if parents are inconsistent (INV-7 violation) or empty.
  String? _getOriginParent(Map<String, String> originalParents) {
    if (originalParents.isEmpty) return null;
    final parents = originalParents.values.toSet();
    if (parents.length != 1) return null;
    return parents.first;
  }

  /// Check if a container is an eligible drop parent (INV-E).
  ///
  /// Eligibility requires ALL of:
  /// - docId is non-null (patchable)
  /// - doc node has autoLayout (v1 restriction)
  /// - not being dragged
  bool _isEligibleDropParent(
    String? docId,
    String expandedId,
    EditorDocument document,
    Set<String> draggedExpandedIds,
  ) {
    if (docId == null) return false;
    if (draggedExpandedIds.contains(expandedId)) return false;
    final docNode = document.nodes[docId];
    return docNode?.layout.autoLayout != null;
  }

  /// Climb parent chain to find eligible drop parent (INV-4, INV-E).
  ///
  /// Returns the first container that is eligible (patchable + auto-layout +
  /// not dragged). Returns null if no eligible ancestor found.
  ContainerHit? _resolveEligibleTarget({
    required ContainerHit hit,
    required EditorDocument document,
    required FrameLookups lookups,
    required Set<String> draggedExpandedIds,
  }) {
    String? currentExpanded = hit.expandedId;
    String? currentDoc = hit.docId;

    while (currentExpanded != null) {
      // Check if current node is eligible
      if (_isEligibleDropParent(
          currentDoc, currentExpanded, document, draggedExpandedIds)) {
        return ContainerHit(
          expandedId: currentExpanded,
          docId: currentDoc,
        );
      }

      // Climb to parent
      final parentExpanded = lookups.getParent(currentExpanded);
      if (parentExpanded == null) {
        // Reached root without finding eligible target
        return null;
      }

      currentExpanded = parentExpanded;
      currentDoc = lookups.getDocId(parentExpanded);
      // Continue even if currentDoc is null (unpatchable) - keep climbing
    }

    return null;
  }

  /// Compute raw insertion index by comparing cursor to child midpoints.
  ///
  /// Returns index in range [0, childrenExpanded.length].
  int _computeRawInsertionIndex({
    required Offset cursorFrameLocal,
    required String targetExpandedId,
    required List<String> childrenExpanded,
    required LayoutDirection direction,
    required String frameId,
    required BoundsResolver getBounds,
  }) {
    if (childrenExpanded.isEmpty) return 0;

    // Compare cursor to child midpoints on main axis
    for (int i = 0; i < childrenExpanded.length; i++) {
      final childBounds = getBounds(frameId, childrenExpanded[i]);
      if (childBounds == null) continue;

      final childMidpoint = direction == LayoutDirection.horizontal
          ? childBounds.center.dx
          : childBounds.center.dy;

      final cursorValue = direction == LayoutDirection.horizontal
          ? cursorFrameLocal.dx
          : cursorFrameLocal.dy;

      if (cursorValue < childMidpoint) {
        return i;
      }
    }

    return childrenExpanded.length;
  }

  /// Apply hysteresis to prevent flip-flop at slot boundaries.
  ///
  /// Only changes index if cursor has moved past threshold from last position.
  int _applyHysteresis({
    required int rawIndex,
    required int? lastIndex,
    required Offset cursorWorld,
    required Offset? lastCursor,
    required double zoom,
  }) {
    if (lastIndex == null || lastCursor == null) {
      return rawIndex;
    }

    if (rawIndex == lastIndex) {
      return rawIndex;
    }

    final threshold = kHysteresisPixels / zoom;
    final distance = (cursorWorld - lastCursor).distance;

    if (distance < threshold) {
      return lastIndex;
    }

    return rawIndex;
  }

  /// Compute indicator rect in world coordinates, clipped to content box (INV-6).
  ///
  /// Returns null if content area is collapsed or indicator too small after clipping.
  ({Rect rect, Axis axis})? _computeIndicatorRect({
    required String targetExpandedId,
    required String targetDocId,
    required List<String> childrenExpanded,
    required int insertionIndex,
    required AutoLayout autoLayout,
    required String frameId,
    required Offset framePos,
    required double zoom,
    required BoundsResolver getBounds,
    required EditorDocument document,
  }) {
    final parentBounds = getBounds(frameId, targetExpandedId);
    if (parentBounds == null) return null;

    final direction = autoLayout.direction;
    final padding = autoLayout.padding;
    final gap = autoLayout.gap?.toDouble() ?? 0;

    // Resolve padding values (handles token references via toDouble fallback)
    final padLeft = padding.left.toDouble();
    final padTop = padding.top.toDouble();
    final padRight = padding.right.toDouble();
    final padBottom = padding.bottom.toDouble();

    // Compute content box (after padding) in frame-local coordinates
    var contentBox = Rect.fromLTRB(
      parentBounds.left + padLeft,
      parentBounds.top + padTop,
      parentBounds.right - padRight,
      parentBounds.bottom - padBottom,
    );

    // INV-6: Collapsed content area → clamp to minimum viable size
    // Fall back to parent bounds with minimal inset to avoid dead zones
    if (contentBox.width <= 0 || contentBox.height <= 0) {
      contentBox = Rect.fromLTRB(
        parentBounds.left + 1,
        parentBounds.top + 1,
        parentBounds.right - 1,
        parentBounds.bottom - 1,
      );
      // Parent itself is too small - truly invalid
      if (contentBox.width <= 0 || contentBox.height <= 0) {
        return null;
      }
    }

    // Convert content box to world coordinates
    final contentWorld = contentBox.shift(framePos);

    // Indicator thickness in world units
    final thickness = kIndicatorThicknessPx / zoom;

    // Compute main axis position based on insertion index
    double mainAxisPos;

    if (childrenExpanded.isEmpty || insertionIndex == 0) {
      // Empty container or index 0: at content start
      mainAxisPos = direction == LayoutDirection.horizontal
          ? contentWorld.left
          : contentWorld.top;
    } else if (insertionIndex >= childrenExpanded.length) {
      // After last child
      final lastBounds = getBounds(frameId, childrenExpanded.last);
      if (lastBounds == null) {
        mainAxisPos = direction == LayoutDirection.horizontal
            ? contentWorld.left
            : contentWorld.top;
      } else {
        final lastWorld = lastBounds.shift(framePos);
        mainAxisPos = direction == LayoutDirection.horizontal
            ? lastWorld.right + gap / 2
            : lastWorld.bottom + gap / 2;
      }
    } else {
      // Between children: after prev child + gap/2
      final prevBounds = getBounds(frameId, childrenExpanded[insertionIndex - 1]);
      if (prevBounds == null) {
        mainAxisPos = direction == LayoutDirection.horizontal
            ? contentWorld.left
            : contentWorld.top;
      } else {
        final prevWorld = prevBounds.shift(framePos);
        mainAxisPos = direction == LayoutDirection.horizontal
            ? prevWorld.right + gap / 2
            : prevWorld.bottom + gap / 2;
      }
    }

    // Build indicator rect based on direction
    Rect indicatorRect;
    Axis axis;

    if (direction == LayoutDirection.horizontal) {
      // Vertical line for horizontal layout (row)
      indicatorRect = Rect.fromLTWH(
        mainAxisPos - thickness / 2,
        contentWorld.top,
        thickness,
        contentWorld.height,
      );
      axis = Axis.vertical;
    } else {
      // Horizontal line for vertical layout (column)
      indicatorRect = Rect.fromLTWH(
        contentWorld.left,
        mainAxisPos - thickness / 2,
        contentWorld.width,
        thickness,
      );
      axis = Axis.horizontal;
    }

    // Clip to content box (INV-6)
    indicatorRect = indicatorRect.intersect(contentWorld);

    // If indicator too small after clipping, expand to minimum size (centered)
    // This avoids dead zones for small/tight containers
    final minSize = kMinIndicatorSizePx / zoom;
    if (indicatorRect.width < minSize && axis == Axis.vertical) {
      indicatorRect = Rect.fromCenter(
        center: indicatorRect.center,
        width: minSize,
        height: indicatorRect.height,
      );
    } else if (indicatorRect.height < minSize && axis == Axis.horizontal) {
      indicatorRect = Rect.fromCenter(
        center: indicatorRect.center,
        width: indicatorRect.width,
        height: minSize,
      );
    }

    // Final clip to content bounds after expansion
    indicatorRect = indicatorRect.intersect(contentWorld);

    // Only return null if both dimensions are truly empty (parent too small)
    if (indicatorRect.isEmpty) {
      return null;
    }

    return (rect: indicatorRect, axis: axis);
  }

  /// Compute reflow offsets for siblings at/after insertion index (INV-3).
  ///
  /// Returns map of expandedId -> offset to apply during drag preview.
  Map<String, Offset> _computeReflowOffsets({
    required List<String> childrenExpanded,
    required int insertionIndex,
    required LayoutDirection direction,
    required List<String> draggedExpandedIdsOrdered,
    required String frameId,
    required AutoLayout autoLayout,
    required BoundsResolver getBounds,
    required RenderDocument renderDoc,
    required FrameLookups lookups,
  }) {
    if (childrenExpanded.isEmpty) return const {};

    final gap = autoLayout.gap?.toDouble() ?? 0;

    // Compute space needed for dragged bundle
    double spaceNeeded = 0;
    for (final expandedId in draggedExpandedIdsOrdered) {
      final bounds = getBounds(frameId, expandedId);
      if (bounds != null) {
        spaceNeeded += direction == LayoutDirection.horizontal
            ? bounds.width
            : bounds.height;
      }
    }

    // Add gap for insertion slot
    if (draggedExpandedIdsOrdered.isNotEmpty) {
      spaceNeeded += gap;
    }

    // Apply offset to siblings at/after insertion index
    final offsets = <String, Offset>{};
    for (int i = insertionIndex; i < childrenExpanded.length; i++) {
      final expandedId = childrenExpanded[i];

      // INV-3: Only include keys that exist in renderDoc
      if (!renderDoc.nodes.containsKey(expandedId)) {
        continue;
      }

      if (direction == LayoutDirection.horizontal) {
        offsets[expandedId] = Offset(spaceNeeded, 0);
      } else {
        offsets[expandedId] = Offset(0, spaceNeeded);
      }
    }

    // INV-3: Debug assert all keys exist in renderDoc
    assert(
      lookups.validateReflowKeys(offsets, renderDoc),
      'INV-3: Reflow keys must exist in renderDoc.nodes',
    );

    return offsets;
  }

  /// Determine drop intent based on origin and target parents.
  DropIntent _determineIntent({
    required String? originParent,
    required String targetDocId,
  }) {
    if (originParent == null) {
      return DropIntent.none;
    }

    if (originParent == targetDocId) {
      return DropIntent.reorder;
    }

    return DropIntent.reparent;
  }

  /// Check if potentialAncestor is an ancestor of (or same as) nodeId.
  ///
  /// Used to prevent circular references (dropping into own descendant).
  bool _isAncestorOrSelf(
    String potentialAncestor,
    String nodeId,
    EditorDocument document,
  ) {
    if (potentialAncestor == nodeId) return true;

    // Walk up from nodeId checking for potentialAncestor
    // Since Node doesn't have parentId, we find parent by searching who has
    // this node as a child
    String? current = nodeId;
    while (current != null) {
      // Find parent by searching who has this node as a child
      String? parentId;
      for (final entry in document.nodes.entries) {
        if (entry.value.childIds.contains(current)) {
          parentId = entry.key;
          break;
        }
      }

      if (parentId == null) break;
      if (parentId == potentialAncestor) return true;
      current = parentId;
    }

    return false;
  }

  /// Debug logging helper.
  ///
  /// Delegates to [DragDebugLogger] which handles throttling and
  /// the global debug flag check.
  void _debugLog(String message) {
    DragDebugLogger.log(message);
  }
}
