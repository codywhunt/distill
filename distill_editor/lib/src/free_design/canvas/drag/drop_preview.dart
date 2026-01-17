import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'drop_intent.dart';

/// Single source of truth for drop preview state during drag operations.
///
/// This model is computed once per drag update by [DropPreviewBuilder] and
/// consumed by all UI components (insertion indicator, reflow animation, etc.)
/// and patch generation.
///
/// ## Design Principles
///
/// 1. **Single computation**: All values are computed once per drag frame
/// 2. **Pre-computed visuals**: [indicatorWorldRect] is ready to paint, overlay doesn't derive it
/// 3. **Parallel lists**: [targetChildrenExpandedIds] and [targetChildrenDocIds] are in sync
/// 4. **ID domain separation**: Rendering uses expanded IDs, patching uses doc IDs
///
/// ## Critical Invariants
///
/// - **INV-2**: [targetChildrenExpandedIds] comes from `renderDoc.nodes[targetParentExpandedId].childIds`
/// - **INV-3**: All keys in [reflowOffsetsByExpandedId] exist in renderDoc.nodes
/// - **INV-6**: [indicatorWorldRect] is clipped to parent content bounds
/// - **INV-8**: If [isValid], both [targetParentDocId] and [targetParentExpandedId] are non-null
/// - **INV-9**: [reflowOffsetsByExpandedId] must be empty when [intent] is not [DropIntent.reorder].
///   This matches Figma's behavior where siblings only move aside during reorder (same parent),
///   not when hovering a different parent for reparent.
@immutable
class DropPreview {
  /// The intent of this drop operation.
  final DropIntent intent;

  /// Whether this is a valid drop target.
  ///
  /// If false, no structural change will occur on drop.
  /// The [invalidReason] may explain why.
  final bool isValid;

  /// Debug reason if drop is invalid (for troubleshooting).
  final String? invalidReason;

  /// The frame containing the drop target.
  final String frameId;

  /// Ordered list of document IDs being dragged.
  ///
  /// Order is preserved from the drag start and used for insertion order.
  /// For multi-select, this maintains the visual ordering of the bundle.
  final List<String> draggedDocIdsOrdered;

  /// Ordered list of expanded IDs being dragged (parallel to [draggedDocIdsOrdered]).
  ///
  /// Used for bounds lookup during drag ghost rendering and reflow calculations.
  final List<String> draggedExpandedIdsOrdered;

  /// Document node ID of the target parent container (for patching).
  ///
  /// Null if drop is invalid or target is unpatchable.
  final String? targetParentDocId;

  /// Expanded scene ID of the target parent container (for bounds lookup).
  ///
  /// Null if drop is invalid. This is the PRIMARY target identification.
  /// The specific instance under the cursor, not derived from docId.
  final String? targetParentExpandedId;

  /// Expanded IDs of the target parent's children (filtered, authoritative).
  ///
  /// This list:
  /// - Comes from `renderDoc.nodes[targetParentExpandedId].childIds` (INV-2)
  /// - Excludes dragged nodes
  /// - Excludes unpatchable nodes (in v1)
  /// - Is used for insertion index calculation, indicator positioning, and reflow
  ///
  /// CRITICAL: This is the single source of truth for children ordering.
  /// All calculations (index, indicator, reflow) must use this same list.
  final List<String> targetChildrenExpandedIds;

  /// Document IDs of the target parent's children (parallel to [targetChildrenExpandedIds]).
  ///
  /// Derived via `expandedToDoc[expandedId]` for each child.
  /// Used for patch generation (MoveNode).
  final List<String> targetChildrenDocIds;

  /// Insertion index within [targetChildrenExpandedIds].
  ///
  /// Range: 0 to targetChildrenExpandedIds.length (inclusive).
  /// Hysteresis is already applied to prevent flip-flop.
  /// Null if drop is invalid.
  final int? insertionIndex;

  /// Pre-computed world rect for the insertion indicator.
  ///
  /// Overlay just paints this rect - no further calculation needed.
  /// Clipped to parent content bounds (INV-6).
  /// Null if no indicator should be shown.
  final Rect? indicatorWorldRect;

  /// Axis of the insertion indicator line.
  ///
  /// - [Axis.vertical] for horizontal auto-layout (Row) - draws vertical line
  /// - [Axis.horizontal] for vertical auto-layout (Column) - draws horizontal line
  /// Null if no indicator should be shown.
  final Axis? indicatorAxis;

  /// Reflow offsets by expanded ID (for sibling animation preview).
  ///
  /// Maps expandedId → offset to apply temporarily during drag.
  /// All keys MUST exist in renderDoc.nodes (INV-3).
  ///
  /// Offsets are applied to siblings at/after [insertionIndex] to show
  /// where they will move when the drop completes.
  final Map<String, Offset> reflowOffsetsByExpandedId;

  const DropPreview({
    required this.intent,
    required this.isValid,
    this.invalidReason,
    required this.frameId,
    required this.draggedDocIdsOrdered,
    required this.draggedExpandedIdsOrdered,
    this.targetParentDocId,
    this.targetParentExpandedId,
    this.targetChildrenExpandedIds = const [],
    this.targetChildrenDocIds = const [],
    this.insertionIndex,
    this.indicatorWorldRect,
    this.indicatorAxis,
    this.reflowOffsetsByExpandedId = const {},
  }) : assert(
          !isValid ||
              (targetParentDocId != null && targetParentExpandedId != null),
          'INV-8: isValid implies both target IDs are non-null',
        );

  /// Creates an invalid/empty preview with no drop target.
  const factory DropPreview.none({
    required String frameId,
    String? invalidReason,
    List<String> draggedDocIdsOrdered,
    List<String> draggedExpandedIdsOrdered,
  }) = _NoneDropPreview;

  /// Whether the insertion indicator should be shown.
  ///
  /// True only when:
  /// - Drop is valid
  /// - Indicator rect is computed
  /// - Indicator axis is known
  /// - Intent is reorder or reparent (not none/moveOnly)
  bool get shouldShowIndicator =>
      isValid &&
      indicatorWorldRect != null &&
      indicatorAxis != null &&
      (intent == DropIntent.reorder || intent == DropIntent.reparent);

  @override
  String toString() => 'DropPreview('
      'intent: $intent, '
      'isValid: $isValid, '
      'frame: $frameId, '
      'targetDoc: $targetParentDocId, '
      'targetExp: $targetParentExpandedId, '
      'index: $insertionIndex, '
      'children: ${targetChildrenExpandedIds.length}, '
      'indicator: ${indicatorWorldRect != null ? "yes" : "no"}'
      '${invalidReason != null ? ", reason: $invalidReason" : ""})';
}

/// Implementation of [DropPreview.none].
class _NoneDropPreview extends DropPreview {
  const _NoneDropPreview({
    required super.frameId,
    super.invalidReason,
    super.draggedDocIdsOrdered = const [],
    super.draggedExpandedIdsOrdered = const [],
  }) : super(
          intent: DropIntent.none,
          isValid: false,
        );
}
