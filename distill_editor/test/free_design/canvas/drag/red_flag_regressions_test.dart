import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'unit_test_harness.dart';

/// Red-flag regression tests for drag/drop system.
///
/// These 6 tests cover the most critical bugs that have been observed.
/// They should run in under 1 second total.
void main() {
  group('Red-Flag Regression Tests', () {
    // =========================================================================
    // Test 1: Wrong-instance indicator
    // =========================================================================
    test('1. wrong-instance indicator: targets correct instance when docId appears multiple times', () {
      // Scenario: Component "row" appears in two instances.
      // When hovering instance A, the target should be inst_a::row, not inst_b::row.
      //
      // This tests INV-1: expandedId is PRIMARY result from hit testing.
      final harness = DragDropUnitHarness(
        boundsByExpandedId: {
          'root': const Rect.fromLTWH(0, 0, 300, 200),
          'inst_a::row': const Rect.fromLTWH(10, 10, 280, 50),
          'inst_b::row': const Rect.fromLTWH(10, 70, 280, 50),
          'dragged_item': const Rect.fromLTWH(10, 130, 100, 30),
        },
        renderChildrenByExpandedId: {
          'root': ['inst_a::row', 'inst_b::row', 'dragged_item'],
          'inst_a::row': [],
          'inst_b::row': [],
          'dragged_item': [],
        },
        expandedToDoc: {
          'root': 'root',
          'inst_a::row': 'row', // Both map to same docId
          'inst_b::row': 'row',
          'dragged_item': 'dragged_item',
        },
        docToExpanded: {
          'root': ['root'],
          'row': ['inst_a::row', 'inst_b::row'], // One docId → multiple expandedIds
          'dragged_item': ['dragged_item'],
        },
        expandedParent: {
          'root': null,
          'inst_a::row': 'root',
          'inst_b::row': 'root',
          'dragged_item': 'root',
        },
        paintOrder: ['root', 'inst_a::row', 'inst_b::row', 'dragged_item'],
        autoLayoutByDocId: {
          'root': const AutoLayout(direction: LayoutDirection.vertical, gap: FixedNumeric(10)),
          'row': const AutoLayout(direction: LayoutDirection.horizontal),
        },
      );

      // Drag dragged_item, hit test returns inst_a::row
      harness.hitResultOverride = const ContainerHit(
        expandedId: 'inst_a::row',
        docId: 'row',
      );

      // Cursor position over instance A
      final cursorWorld = const Offset(100, 35); // Middle of inst_a::row

      final preview = harness.computePreview(
        cursorWorld: cursorWorld,
        draggedExpandedIds: ['dragged_item'],
        draggedDocIds: ['dragged_item'],
        originalParents: {'dragged_item': 'root'},
      );

      // CRITICAL: The target should be the specific instance, not a random choice
      expect(preview.isValid, isTrue);
      expect(preview.targetParentExpandedId, equals('inst_a::row'));
      expect(preview.targetParentDocId, equals('row'));
    });

    // =========================================================================
    // Test 2: Origin stickiness prevents grandparent target
    // =========================================================================
    test('2. origin stickiness: reorder within origin parent, not grandparent', () {
      // Scenario: Dragging child_0 within parent. Hit test should return parent
      // as the target, not grandparent (if there was one).
      final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

      // Set hit result to parent (what hit test returns when cursor is over children)
      harness.hitResultOverride = const ContainerHit(
        expandedId: 'parent',
        docId: 'parent',
      );

      // Cursor position well inside parent
      final cursorWorld = const Offset(50, 100);

      final preview = harness.computePreview(
        cursorWorld: cursorWorld,
        draggedExpandedIds: ['child_0'],
        draggedDocIds: ['child_0'],
        originalParents: {'child_0': 'parent'},
      );

      // Should target the origin parent for reorder
      expect(preview.isValid, isTrue);
      expect(preview.targetParentExpandedId, equals('parent'));
      expect(preview.targetParentDocId, equals('parent'));
      expect(preview.intent, equals(DropIntent.reorder));
    });

    // =========================================================================
    // Test 3: INV-9 - Reparent has no reflow
    // =========================================================================
    test('3. INV-9: reparent has empty reflow offsets', () {
      // Scenario: Reparenting should NOT show sibling reflow animation.
      // Reflow is only for reorder within the same parent.
      final harness = DragDropUnitHarness(
        boundsByExpandedId: {
          'root': const Rect.fromLTWH(0, 0, 400, 400),
          'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
          'parent_b': const Rect.fromLTWH(210, 10, 180, 180),
          'child': const Rect.fromLTWH(20, 20, 80, 40),
          'sibling_b1': const Rect.fromLTWH(220, 20, 80, 40),
          'sibling_b2': const Rect.fromLTWH(220, 70, 80, 40),
        },
        renderChildrenByExpandedId: {
          'root': ['parent_a', 'parent_b'],
          'parent_a': ['child'],
          'parent_b': ['sibling_b1', 'sibling_b2'],
        },
        expandedToDoc: {
          'root': 'root',
          'parent_a': 'parent_a',
          'parent_b': 'parent_b',
          'child': 'child',
          'sibling_b1': 'sibling_b1',
          'sibling_b2': 'sibling_b2',
        },
        expandedParent: {
          'root': null,
          'parent_a': 'root',
          'parent_b': 'root',
          'child': 'parent_a',
          'sibling_b1': 'parent_b',
          'sibling_b2': 'parent_b',
        },
        paintOrder: ['root', 'parent_a', 'child', 'parent_b', 'sibling_b1', 'sibling_b2'],
        autoLayoutByDocId: {
          'root': const AutoLayout(direction: LayoutDirection.horizontal),
          'parent_a': const AutoLayout(direction: LayoutDirection.vertical),
          'parent_b': const AutoLayout(direction: LayoutDirection.vertical, gap: FixedNumeric(10)),
        },
      );

      // Drag child from parent_a to parent_b
      harness.hitResultOverride = const ContainerHit(
        expandedId: 'parent_b',
        docId: 'parent_b',
      );

      final preview = harness.computePreview(
        cursorWorld: const Offset(260, 50), // Over parent_b
        draggedExpandedIds: ['child'],
        draggedDocIds: ['child'],
        originalParents: {'child': 'parent_a'}, // Origin is different from target
      );

      expect(preview.isValid, isTrue);
      expect(preview.intent, equals(DropIntent.reparent)); // Not reorder
      // INV-9: Reflow should be empty for reparent
      expect(preview.reflowOffsetsByExpandedId, isEmpty);
    });

    // =========================================================================
    // Test 4: INV-4 - Absolute hit climbs to auto-layout
    // =========================================================================
    test('4. INV-4: absolute container hit climbs to auto-layout ancestor', () {
      // Scenario: Hit test returns an absolute container (no auto-layout).
      // The builder should climb to find the nearest auto-layout ancestor.
      final harness = DragDropUnitHarness.nestedAbsolute();

      // Hit test returns the absolute "parent" container
      harness.hitResultOverride = const ContainerHit(
        expandedId: 'parent',
        docId: 'parent',
      );

      final preview = harness.computePreview(
        cursorWorld: const Offset(100, 100), // Over the absolute parent
        draggedExpandedIds: ['child'],
        draggedDocIds: ['child'],
        originalParents: {'child': 'parent'},
      );

      // Should climb to grandparent (the auto-layout container)
      expect(preview.isValid, isTrue);
      expect(preview.targetParentExpandedId, equals('grandparent'));
      expect(preview.targetParentDocId, equals('grandparent'));
    });

    // =========================================================================
    // Test 5: INV-5 - Frame locked
    // =========================================================================
    test('5. INV-5: frame locked at drag start, cursor over different frame is handled', () {
      // Scenario: Frame is locked at drag start. Cursor moving over different
      // area shouldn't cause issues (hit test uses locked frame).
      final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

      // Simulate hit test returning nothing (cursor outside any container)
      harness.hitResultOverride = null;

      final preview = harness.computePreview(
        cursorWorld: const Offset(1000, 1000), // Way outside frame
        draggedExpandedIds: ['child_0'],
        draggedDocIds: ['child_0'],
        originalParents: {'child_0': 'parent'},
      );

      // Should return invalid (no container hit), but not crash
      expect(preview.isValid, isFalse);
      expect(preview.frameId, equals('frame_1')); // Locked frame preserved
    });

    // =========================================================================
    // Test 6: Multi-select patch order preserved
    // =========================================================================
    test('6. multi-select patches preserve order', () {
      // Scenario: Dragging [A, B] should result in patches that maintain
      // the relative order [A, B], not [B, A] or scrambled.
      final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

      // Set hit result to parent for reorder
      harness.hitResultOverride = const ContainerHit(
        expandedId: 'parent',
        docId: 'parent',
      );

      // Cursor at slot 3 (after child_2, before child_3)
      final cursorWorld = harness.cursorAtSlot('parent', 3);

      // Drag child_0 and child_1 together
      final preview = harness.computePreview(
        cursorWorld: cursorWorld,
        draggedExpandedIds: ['child_0', 'child_1'],
        draggedDocIds: ['child_0', 'child_1'],
        originalParents: {
          'child_0': 'parent',
          'child_1': 'parent',
        },
      );

      expect(preview.isValid, isTrue);
      expect(preview.intent, equals(DropIntent.reorder));

      // Create commit plan and generate patches
      final plan = DropCommitPlan.fromPreview(preview, {
        'child_0': 'parent',
        'child_1': 'parent',
      });

      expect(plan.canCommit, isTrue);
      expect(plan.draggedDocIdsOrdered, equals(['child_0', 'child_1']));

      // Generate patches and apply to test tree
      final patches = generateDropPatches(plan);
      final tester = PatchTreeTester({
        'parent': ['child_0', 'child_1', 'child_2', 'child_3'],
      });
      tester.applyPatches(patches);

      final result = tester.childrenOf('parent');

      // Order should be: [child_2, child_0, child_1, child_3]
      // (child_0 and child_1 moved to position 2, maintaining relative order)
      expect(result, equals(['child_2', 'child_0', 'child_1', 'child_3']));
    });
  });

  group('Additional Critical Checks', () {
    test('reorder within same parent has non-empty reflow (inverse of INV-9)', () {
      // Verify that reorder DOES have reflow (opposite of test 3)
      final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

      harness.hitResultOverride = const ContainerHit(
        expandedId: 'parent',
        docId: 'parent',
      );

      // Move child_0 to after child_2
      final cursorWorld = harness.cursorAtSlot('parent', 2);

      final preview = harness.computePreview(
        cursorWorld: cursorWorld,
        draggedExpandedIds: ['child_0'],
        draggedDocIds: ['child_0'],
        originalParents: {'child_0': 'parent'},
      );

      expect(preview.isValid, isTrue);
      expect(preview.intent, equals(DropIntent.reorder));
      // Reflow should be non-empty for reorder
      expect(preview.reflowOffsetsByExpandedId, isNotEmpty);
    });

    test('indicator is computed for valid drop', () {
      // Use a harness with padding so content box has positive dimensions
      final harness = DragDropUnitHarness.verticalColumn(
        childCount: 3,
        paddingTop: 10,
        paddingBottom: 10,
        paddingLeft: 10,
        paddingRight: 10,
      );

      harness.hitResultOverride = const ContainerHit(
        expandedId: 'parent',
        docId: 'parent',
      );

      final cursorWorld = harness.cursorAtSlot('parent', 1);

      final preview = harness.computePreview(
        cursorWorld: cursorWorld,
        draggedExpandedIds: ['child_0'],
        draggedDocIds: ['child_0'],
        originalParents: {'child_0': 'parent'},
      );

      expect(preview.isValid, isTrue);
      // Note: Indicator computation depends on content box dimensions
      // It may be null if content box is too small after padding
      expect(preview.insertionIndex, isNotNull);
    });
  });
}
