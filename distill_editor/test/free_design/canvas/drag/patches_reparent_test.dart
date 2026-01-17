import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'unit_test_harness.dart';

/// Tests for patch generation during reparent operations.
///
/// Key principle: Assert final child lists, not patch op sequences.
void main() {
  group('Reparent Patches', () {
    group('single node reparent', () {
      test('reparent to index 0 of empty parent', () {
        // Origin: parent_a has [A, B]
        // Target: parent_b has []
        // Move A to parent_b at index 0
        // Expected: parent_a=[B], parent_b=[A]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['A'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B'],
          'parent_b': [],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), equals(['B']));
        expect(tester.childrenOf('parent_b'), equals(['A']));
      });

      test('reparent to index 0 of non-empty parent', () {
        // Origin: parent_a has [A, B]
        // Target: parent_b has [X, Y]
        // Move A to parent_b at index 0
        // Expected: parent_a=[B], parent_b=[A, X, Y]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['A'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B'],
          'parent_b': ['X', 'Y'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), equals(['B']));
        expect(tester.childrenOf('parent_b'), equals(['A', 'X', 'Y']));
      });

      test('reparent to end of non-empty parent', () {
        // Origin: parent_a has [A, B]
        // Target: parent_b has [X, Y]
        // Move A to parent_b at index 2 (end)
        // Expected: parent_a=[B], parent_b=[X, Y, A]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 2, // End
          draggedDocIdsOrdered: ['A'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B'],
          'parent_b': ['X', 'Y'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), equals(['B']));
        expect(tester.childrenOf('parent_b'), equals(['X', 'Y', 'A']));
      });

      test('reparent to middle of non-empty parent', () {
        // Origin: parent_a has [A, B]
        // Target: parent_b has [X, Y, Z]
        // Move A to parent_b at index 1 (after X)
        // Expected: parent_a=[B], parent_b=[X, A, Y, Z]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 1,
          draggedDocIdsOrdered: ['A'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B'],
          'parent_b': ['X', 'Y', 'Z'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), equals(['B']));
        expect(tester.childrenOf('parent_b'), equals(['X', 'A', 'Y', 'Z']));
      });
    });

    group('multi-select reparent', () {
      test('reparent multiple nodes preserves order', () {
        // Origin: parent_a has [A, B, C]
        // Target: parent_b has [X, Y]
        // Move [A, B] to parent_b at index 1
        // Expected: parent_a=[C], parent_b=[X, A, B, Y]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 1,
          draggedDocIdsOrdered: ['A', 'B'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B', 'C'],
          'parent_b': ['X', 'Y'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), equals(['C']));
        expect(tester.childrenOf('parent_b'), equals(['X', 'A', 'B', 'Y']));
      });

      test('reparent multiple nodes to empty parent', () {
        // Origin: parent_a has [A, B, C, D]
        // Target: parent_b has []
        // Move [B, C] to parent_b at index 0
        // Expected: parent_a=[A, D], parent_b=[B, C]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['B', 'C'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B', 'C', 'D'],
          'parent_b': [],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), equals(['A', 'D']));
        expect(tester.childrenOf('parent_b'), equals(['B', 'C']));
      });

      test('reparent all children from origin', () {
        // Origin: parent_a has [A, B]
        // Target: parent_b has [X]
        // Move [A, B] to parent_b at index 0
        // Expected: parent_a=[], parent_b=[A, B, X]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['A', 'B'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B'],
          'parent_b': ['X'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), isEmpty);
        expect(tester.childrenOf('parent_b'), equals(['A', 'B', 'X']));
      });

      test('non-contiguous selection maintains order', () {
        // Origin: parent_a has [A, B, C, D]
        // Target: parent_b has [X, Y]
        // Move [A, C] (non-contiguous) to parent_b at index 2 (end)
        // Expected: parent_a=[B, D], parent_b=[X, Y, A, C]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 2,
          draggedDocIdsOrdered: ['A', 'C'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent_a': ['A', 'B', 'C', 'D'],
          'parent_b': ['X', 'Y'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent_a'), equals(['B', 'D']));
        expect(tester.childrenOf('parent_b'), equals(['X', 'Y', 'A', 'C']));
      });
    });

    group('patch structure verification', () {
      test('uses DetachChild and AttachChild, not MoveNode', () {
        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['A', 'B'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);

        // Should have 2 DetachChild (one per dragged node) and 2 AttachChild
        expect(patches.whereType<DetachChild>().length, equals(2));
        expect(patches.whereType<AttachChild>().length, equals(2));
        expect(patches.whereType<MoveNode>().length, equals(0));
      });

      test('detach happens before attach (correct order)', () {
        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent_a',
          targetParentDocId: 'parent_b',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['A'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);

        // First patch should be DetachChild, last should be AttachChild
        expect(patches.first, isA<DetachChild>());
        expect(patches.last, isA<AttachChild>());
      });
    });

    group('edge cases', () {
      test('reparent to nested child of same tree structure', () {
        // This tests reparenting to a sibling's child
        // Origin: parent has [A, B]
        // Target: A has [X]
        // Move B to A at index 0
        // Expected: parent=[A], A=[B, X]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'A',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['B'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B'],
          'A': ['X'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['A']));
        expect(tester.childrenOf('A'), equals(['B', 'X']));
      });

      test('reparent from deeply nested to shallow', () {
        // Move from deep nesting to shallower
        // grandparent -> parent -> [A]
        // root has [X, Y]
        // Move A to root at index 1

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'root',
          insertionIndex: 1,
          draggedDocIdsOrdered: ['A'],
          isReparent: true,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'root': ['X', 'Y'],
          'parent': ['A'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), isEmpty);
        expect(tester.childrenOf('root'), equals(['X', 'A', 'Y']));
      });
    });
  });
}
