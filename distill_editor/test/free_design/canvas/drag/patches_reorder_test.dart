import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'unit_test_harness.dart';

/// Tests for patch generation during reorder operations.
///
/// Key principle: Assert final child list, not patch op sequence.
/// This makes tests resilient to implementation changes.
void main() {
  group('Reorder Patches', () {
    group('single node reorder', () {
      test('move to index 0 (beginning)', () {
        // Initial: [A, B, C, D]
        // Move C to index 0
        // Expected: [C, A, B, D]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['C'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['C', 'A', 'B', 'D']));

        // Sanity check: correct patch types
        expect(patches.whereType<DetachChild>(), hasLength(1));
        expect(patches.whereType<AttachChild>(), hasLength(1));
      });

      test('move to end', () {
        // Initial: [A, B, C, D]
        // Move A to index 3 (end of filtered list [B, C, D])
        // Expected: [B, C, D, A]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 3, // After B, C, D in filtered list
          draggedDocIdsOrdered: ['A'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['B', 'C', 'D', 'A']));
      });

      test('move forward (index 1 to 3)', () {
        // Initial: [A, B, C, D]
        // Move B to index 2 (after C in filtered list [A, C, D])
        // Expected: [A, C, B, D]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 2, // After A, C in filtered list
          draggedDocIdsOrdered: ['B'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['A', 'C', 'B', 'D']));
      });

      test('move backward (index 3 to 1)', () {
        // Initial: [A, B, C, D]
        // Move D to index 1 (after A in filtered list [A, B, C])
        // Expected: [A, D, B, C]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1, // After A in filtered list
          draggedDocIdsOrdered: ['D'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['A', 'D', 'B', 'C']));
      });

      test('move to same position is no-op', () {
        // Initial: [A, B, C, D]
        // Move B to index 1 (same position in filtered list [A, C, D])
        // This should still work, just results in same order

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1, // After A in filtered list
          draggedDocIdsOrdered: ['B'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D'],
        });
        tester.applyPatches(patches);

        // Result should be same as original order
        expect(tester.childrenOf('parent'), equals(['A', 'B', 'C', 'D']));
      });
    });

    group('multi-select reorder', () {
      test('preserves relative order when moving forward', () {
        // Initial: [A, B, C, D, E]
        // Move [A, B] to index 2 (after C in filtered list [C, D, E])
        // Expected: [C, A, B, D, E]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1, // After C in filtered list [C, D, E]
          draggedDocIdsOrdered: ['A', 'B'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D', 'E'],
        });
        tester.applyPatches(patches);

        // A and B should maintain relative order
        expect(tester.childrenOf('parent'), equals(['C', 'A', 'B', 'D', 'E']));
      });

      test('preserves relative order when moving backward', () {
        // Initial: [A, B, C, D, E]
        // Move [D, E] to index 1 (after A in filtered list [A, B, C])
        // Expected: [A, D, E, B, C]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1, // After A in filtered list
          draggedDocIdsOrdered: ['D', 'E'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D', 'E'],
        });
        tester.applyPatches(patches);

        // D and E should maintain relative order
        expect(tester.childrenOf('parent'), equals(['A', 'D', 'E', 'B', 'C']));
      });

      test('preserves relative order when moving to beginning', () {
        // Initial: [A, B, C, D]
        // Move [C, D] to index 0
        // Expected: [C, D, A, B]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['C', 'D'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['C', 'D', 'A', 'B']));
      });

      test('preserves relative order when moving to end', () {
        // Initial: [A, B, C, D]
        // Move [A, B] to index 2 (end of filtered list [C, D])
        // Expected: [C, D, A, B]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 2, // End of filtered list
          draggedDocIdsOrdered: ['A', 'B'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['C', 'D', 'A', 'B']));
      });

      test('non-contiguous selection maintains order', () {
        // Initial: [A, B, C, D, E]
        // Move [A, C] to index 2 (after B, D in filtered list [B, D, E])
        // Expected: [B, D, A, C, E]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 2, // After B, D in filtered list
          draggedDocIdsOrdered: ['A', 'C'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C', 'D', 'E'],
        });
        tester.applyPatches(patches);

        // A and C should maintain their relative order (A before C)
        expect(tester.childrenOf('parent'), equals(['B', 'D', 'A', 'C', 'E']));
      });
    });

    group('edge cases', () {
      test('single child in parent', () {
        // Initial: [A]
        // Move A to index 0 (same position)
        // Expected: [A]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 0,
          draggedDocIdsOrdered: ['A'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['A']));
      });

      test('canCommit false returns empty patches', () {
        final plan = DropCommitPlan(
          canCommit: false,
          reason: 'Invalid drop',
          originParentDocId: '',
          targetParentDocId: '',
          insertionIndex: 0,
          draggedDocIdsOrdered: [],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        expect(patches, isEmpty);
      });

      test('move all but one child', () {
        // Initial: [A, B, C]
        // Move [A, B] to index 1 (after C in filtered list [C])
        // Expected: [C, A, B]

        final plan = DropCommitPlan(
          canCommit: true,
          originParentDocId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1, // After C
          draggedDocIdsOrdered: ['A', 'B'],
          isReparent: false,
        );

        final patches = generateDropPatches(plan);
        final tester = PatchTreeTester({
          'parent': ['A', 'B', 'C'],
        });
        tester.applyPatches(patches);

        expect(tester.childrenOf('parent'), equals(['C', 'A', 'B']));
      });
    });
  });
}
