import '../../patch/patch_op.dart';
import 'drop_commit_plan.dart';

/// Generate patches for moving nodes to a new position.
///
/// This is a pure function with no side effects, making it easy to test.
///
/// ## Algorithm
///
/// 1. **Detach all** dragged nodes from origin parent
/// 2. **Attach all** dragged nodes to target parent at sequential indices
///
/// This two-phase approach ensures the insertion index (computed on the
/// "filtered" children list) maps correctly to the actual child list.
///
/// ## Why Not MoveNode?
///
/// `MoveNode` does detach-then-attach atomically per node. When moving
/// multiple nodes, each move affects subsequent indices, causing incorrect
/// placement. Separating detach and attach phases avoids this issue.
///
/// ## Example
///
/// Moving [A, B] from indices [0, 1] to filtered index 2:
/// ```
/// Initial: [A, B, C, D, E]
/// Filtered (no A,B): [C, D, E]
///
/// DetachChild(A): [B, C, D, E]
/// DetachChild(B): [C, D, E]  ← Matches filtered list
///
/// AttachChild(A, index=2): [C, D, A, E]
/// AttachChild(B, index=3): [C, D, A, B, E] ✓
/// ```
List<PatchOp> generateDropPatches(DropCommitPlan plan) {
  if (!plan.canCommit) return [];

  final patches = <PatchOp>[];
  final draggedIds = plan.draggedDocIdsOrdered;
  final targetParent = plan.targetParentDocId;
  final originParent = plan.originParentDocId;
  final baseIndex = plan.insertionIndex;

  // Step 1: Detach ALL dragged nodes from origin parent
  //
  // This brings the origin parent to the "filtered" state that matches
  // how insertionIndex was computed by DropPreviewBuilder.
  //
  // For reparent: nodes leave origin, target is unaffected yet
  // For reorder: same parent, now in filtered state
  for (final id in draggedIds) {
    patches.add(DetachChild(parentId: originParent, childId: id));
  }

  // Step 2: Attach all dragged nodes to target parent in order
  //
  // Since we've already detached, the target parent (if same as origin)
  // is now in filtered state, so baseIndex maps correctly.
  //
  // We insert at sequential indices: baseIndex, baseIndex+1, etc.
  // This preserves the draggedDocIdsOrdered ordering.
  for (var i = 0; i < draggedIds.length; i++) {
    patches.add(AttachChild(
      parentId: targetParent,
      childId: draggedIds[i],
      index: baseIndex + i,
    ));
  }

  return patches;
}
