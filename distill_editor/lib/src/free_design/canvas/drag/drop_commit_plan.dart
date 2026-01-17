import 'package:flutter/foundation.dart';

import 'drop_preview.dart';

/// Plan for committing a drop operation to the document.
///
/// This contains all the information needed to generate patches
/// for a drop operation, extracted from a [DropPreview].
///
/// The separation of concerns:
/// - [DropPreview] is computed during drag (every frame update)
/// - [DropCommitPlan] is created once at drop time (pointer up)
/// - Patch generation is a pure function that takes [DropCommitPlan]
@immutable
class DropCommitPlan {
  /// Whether this drop can be committed.
  ///
  /// False if the original [DropPreview] was invalid.
  final bool canCommit;

  /// Reason if commit is not possible.
  final String? reason;

  /// Document ID of the origin parent (where nodes came from).
  final String originParentDocId;

  /// Document ID of the target parent (where nodes are going).
  final String targetParentDocId;

  /// Insertion index within the target parent's children.
  ///
  /// This index is in "filtered list" coordinates:
  /// - Excludes dragged nodes from the count
  /// - Ready for use in patch generation
  final int insertionIndex;

  /// Ordered list of document IDs being moved.
  ///
  /// Order is preserved and used for insertion order.
  final List<String> draggedDocIdsOrdered;

  /// Whether this is a reparent operation (origin != target).
  ///
  /// - true: Moving to a different parent container
  /// - false: Reordering within the same parent
  final bool isReparent;

  const DropCommitPlan({
    required this.canCommit,
    this.reason,
    required this.originParentDocId,
    required this.targetParentDocId,
    required this.insertionIndex,
    required this.draggedDocIdsOrdered,
    required this.isReparent,
  });

  /// Creates a commit plan from a [DropPreview] and original parent mapping.
  ///
  /// [preview] - The drop preview at the time of drop (pointer up)
  /// [originalParents] - Map of docId → original parent docId (from drag start)
  ///
  /// Returns a plan that can be used for patch generation.
  /// If the preview is invalid, returns a plan with [canCommit] = false.
  factory DropCommitPlan.fromPreview(
    DropPreview preview,
    Map<String, String> originalParents,
  ) {
    if (!preview.isValid ||
        preview.targetParentDocId == null ||
        preview.insertionIndex == null) {
      return DropCommitPlan(
        canCommit: false,
        reason: preview.invalidReason ?? 'Invalid drop preview',
        originParentDocId: '',
        targetParentDocId: '',
        insertionIndex: 0,
        draggedDocIdsOrdered: preview.draggedDocIdsOrdered,
        isReparent: false,
      );
    }

    // Get origin parent from first dragged node
    // In v1, all dragged nodes must have the same origin parent (INV-7)
    final firstDraggedDocId = preview.draggedDocIdsOrdered.firstOrNull;
    final originParentDocId =
        firstDraggedDocId != null ? originalParents[firstDraggedDocId] : null;

    if (originParentDocId == null) {
      return DropCommitPlan(
        canCommit: false,
        reason: 'Could not determine origin parent',
        originParentDocId: '',
        targetParentDocId: preview.targetParentDocId!,
        insertionIndex: preview.insertionIndex!,
        draggedDocIdsOrdered: preview.draggedDocIdsOrdered,
        isReparent: false,
      );
    }

    final isReparent = originParentDocId != preview.targetParentDocId;

    return DropCommitPlan(
      canCommit: true,
      originParentDocId: originParentDocId,
      targetParentDocId: preview.targetParentDocId!,
      insertionIndex: preview.insertionIndex!,
      draggedDocIdsOrdered: preview.draggedDocIdsOrdered,
      isReparent: isReparent,
    );
  }

  /// Creates a plan indicating no commit should happen.
  const factory DropCommitPlan.none({String? reason}) = _NoneCommitPlan;

  @override
  String toString() => 'DropCommitPlan('
      'canCommit: $canCommit, '
      'origin: $originParentDocId, '
      'target: $targetParentDocId, '
      'index: $insertionIndex, '
      'nodes: ${draggedDocIdsOrdered.length}, '
      'reparent: $isReparent'
      '${reason != null ? ", reason: $reason" : ""})';
}

/// Implementation of [DropCommitPlan.none].
class _NoneCommitPlan extends DropCommitPlan {
  const _NoneCommitPlan({super.reason})
      : super(
          canCommit: false,
          originParentDocId: '',
          targetParentDocId: '',
          insertionIndex: 0,
          draggedDocIdsOrdered: const [],
          isReparent: false,
        );
}
