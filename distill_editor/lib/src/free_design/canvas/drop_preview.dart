import 'dart:ui';

import '../models/node_layout.dart';

/// The kind of drop operation being previewed.
enum DropPreviewKind {
  /// No structural change - absolute positioned node being moved.
  moveOnly,

  /// Reordering within the same parent (sibling movement).
  reorder,

  /// Reparenting to a different container.
  reparent,
}

/// Single source of truth for drop preview state during drag operations.
///
/// This model is computed once per drag update by [DropPreviewEngine] and
/// consumed by all UI components (insertion indicator, reflow animation, etc.)
/// and patch generation.
///
/// Key design principle: All consumers read from this model.
/// No one-off derived logic in overlays or other components.
class DropPreview {
  /// The kind of drop operation.
  final DropPreviewKind kind;

  /// The frame containing the drop target.
  final String frameId;

  /// Document node ID of the parent container (for patching).
  final String parentDocId;

  /// Expanded scene ID of the parent container (for bounds lookup).
  final String parentExpandedId;

  /// Expanded IDs of the parent's children (filtered to exclude dragged nodes).
  /// Used for bounds lookup during indicator positioning.
  final List<String> childrenExpandedIds;

  /// Document IDs of the parent's children (parallel list to childrenExpandedIds).
  /// Used for patch generation (MoveNode).
  final List<String> childrenDocIds;

  /// Insertion index within the filtered children list.
  /// Hysteresis already applied.
  final int insertionIndex;

  /// Pre-computed world rect for the insertion indicator.
  /// Overlay just paints this - no further calculation needed.
  final Rect? indicatorWorldRect;

  /// Direction of the parent's auto-layout (for indicator orientation).
  final LayoutDirection? direction;

  /// Reflow offsets by expanded ID (for sibling animation preview).
  /// Maps expandedId → offset to apply temporarily during drag.
  final Map<String, Offset> reflowOffsetsByExpandedId;

  /// Debug reason if drop is invalid (for troubleshooting).
  final String? invalidReason;

  const DropPreview({
    required this.kind,
    required this.frameId,
    required this.parentDocId,
    required this.parentExpandedId,
    required this.childrenExpandedIds,
    required this.childrenDocIds,
    required this.insertionIndex,
    required this.indicatorWorldRect,
    required this.direction,
    required this.reflowOffsetsByExpandedId,
    this.invalidReason,
  });

  /// Create an invalid/empty preview.
  const DropPreview.none({this.invalidReason})
      : kind = DropPreviewKind.moveOnly,
        frameId = '',
        parentDocId = '',
        parentExpandedId = '',
        childrenExpandedIds = const [],
        childrenDocIds = const [],
        insertionIndex = 0,
        indicatorWorldRect = null,
        direction = null,
        reflowOffsetsByExpandedId = const {};

  /// Whether this preview has valid drop target information.
  bool get isValid =>
      parentDocId.isNotEmpty && parentExpandedId.isNotEmpty;

  /// Whether the insertion indicator should be shown.
  bool get shouldShowIndicator =>
      isValid &&
      indicatorWorldRect != null &&
      direction != null &&
      (kind == DropPreviewKind.reorder || kind == DropPreviewKind.reparent);

  @override
  String toString() => 'DropPreview('
      'kind: $kind, '
      'parentDocId: $parentDocId, '
      'parentExpandedId: $parentExpandedId, '
      'insertionIndex: $insertionIndex, '
      'childrenExpanded: ${childrenExpandedIds.length}, '
      'indicator: ${indicatorWorldRect != null ? "yes" : "no"})';
}
