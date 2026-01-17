import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'unit_test_harness.dart';

/// Tests for origin stickiness behavior.
///
/// The failure mode "starting a drag targets parent's parent" often comes from:
/// - Hit test excluding dragged nodes and accidentally hitting parent-of-parent
/// - Cursor starting slightly outside origin content rect due to padding/rounding
///
/// These tests verify correct behavior in edge cases.
void main() {
  group('Origin Stickiness Tests', () {
    group('cursor position edge cases', () {
      test('cursor well inside origin content rect targets origin (reorder)', () {
        // Scenario: Dragging child, cursor is clearly inside origin parent's content area.
        // Should result in reorder (same parent), not reparent.
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          paddingTop: 20,
          paddingBottom: 20,
          paddingLeft: 20,
          paddingRight: 20,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Cursor well inside the content area (not in padding)
        // Parent bounds: 0,0 to parentWidth, parentHeight
        // Content starts at (20, 20)
        final cursorWorld = const Offset(50, 100); // Clearly inside

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          // Stickiness params
          originParentExpandedId: 'parent',
          originParentContentWorldRect: const Rect.fromLTWH(20, 20, 60, 130),
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('parent'));
      });

      test('cursor inside bounds but in padding area still targets origin', () {
        // Scenario: Cursor is inside the parent bounds but in the padding area.
        // The parent is still the auto-layout container, so it should still be targeted.
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          paddingTop: 20,
          paddingBottom: 20,
          paddingLeft: 20,
          paddingRight: 20,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Cursor in padding area (x=10 which is < paddingLeft=20)
        final cursorWorld = const Offset(10, 50);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('parent'));
      });

      test('cursor barely outside (0.5px) handles gracefully', () {
        // Scenario: Due to rounding, cursor might be fractionally outside bounds.
        // Hit test returns null, so the preview should be invalid (not crash).
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

        // Cursor barely outside bounds
        harness.hitResultOverride = null; // Hit test returns nothing

        final cursorWorld = const Offset(-0.5, 50); // Half pixel outside

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        // Should be invalid but not crash
        expect(preview.isValid, isFalse);
        expect(preview.invalidReason, contains('no container hit'));
      });

      test('cursor in nested container within origin allows reparent', () {
        // Scenario: Origin parent contains nested children that are also auto-layout.
        // When cursor is over a nested container, reparent to that container is allowed
        // (stickiness doesn't override explicit hover of different container).
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'parent': const Rect.fromLTWH(0, 0, 300, 200),
            'child_0': const Rect.fromLTWH(10, 10, 280, 80),
            'child_1': const Rect.fromLTWH(10, 100, 280, 80),
            'nested_item': const Rect.fromLTWH(20, 20, 100, 40),
          },
          renderChildrenByExpandedId: {
            'parent': ['child_0', 'child_1'],
            'child_0': ['nested_item'],
            'child_1': [],
            'nested_item': [],
          },
          expandedToDoc: {
            'parent': 'parent',
            'child_0': 'child_0',
            'child_1': 'child_1',
            'nested_item': 'nested_item',
          },
          expandedParent: {
            'parent': null,
            'child_0': 'parent',
            'child_1': 'parent',
            'nested_item': 'child_0',
          },
          paintOrder: ['parent', 'child_0', 'nested_item', 'child_1'],
          autoLayoutByDocId: {
            'parent': const AutoLayout(direction: LayoutDirection.vertical, gap: FixedNumeric(10)),
            'child_0': const AutoLayout(direction: LayoutDirection.horizontal),
            'child_1': null,
          },
        );

        // Hit test returns child_0 (the nested auto-layout container)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'child_0',
          docId: 'child_0',
        );

        // Cursor over child_0, but nested_item's origin parent is child_0
        // Dragging from child_0 to child_0 = reorder
        final preview = harness.computePreview(
          cursorWorld: const Offset(60, 40), // Over child_0
          draggedExpandedIds: ['nested_item'],
          draggedDocIds: ['nested_item'],
          originalParents: {'nested_item': 'child_0'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('child_0'));
      });

      test('cursor leaves origin entirely allows reparent', () {
        // Scenario: Cursor moves completely outside origin parent.
        // Should allow reparent to a different container.
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(210, 10, 180, 180),
            'child': const Rect.fromLTWH(20, 20, 80, 40),
          },
          renderChildrenByExpandedId: {
            'root': ['parent_a', 'parent_b'],
            'parent_a': ['child'],
            'parent_b': [],
          },
          expandedToDoc: {
            'root': 'root',
            'parent_a': 'parent_a',
            'parent_b': 'parent_b',
            'child': 'child',
          },
          expandedParent: {
            'root': null,
            'parent_a': 'root',
            'parent_b': 'root',
            'child': 'parent_a',
          },
          paintOrder: ['root', 'parent_a', 'child', 'parent_b'],
          autoLayoutByDocId: {
            'root': const AutoLayout(direction: LayoutDirection.horizontal),
            'parent_a': const AutoLayout(direction: LayoutDirection.vertical),
            'parent_b': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        // Hit test returns parent_b (cursor moved to different parent)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(300, 100), // Over parent_b
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'}, // Origin is parent_a
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent)); // Different parent
        expect(preview.targetParentExpandedId, equals('parent_b'));
      });
    });

    group('grandparent targeting bug', () {
      test('dragging child does not target grandparent when origin parent hit', () {
        // The specific bug: drag starts on a child, hit test (with exclusion)
        // should return the origin parent, not climb further to grandparent.
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'grandparent': const Rect.fromLTWH(0, 0, 400, 400),
            'parent': const Rect.fromLTWH(20, 20, 360, 360),
            'child_0': const Rect.fromLTWH(30, 30, 100, 50),
            'child_1': const Rect.fromLTWH(30, 90, 100, 50),
          },
          renderChildrenByExpandedId: {
            'grandparent': ['parent'],
            'parent': ['child_0', 'child_1'],
            'child_0': [],
            'child_1': [],
          },
          expandedToDoc: {
            'grandparent': 'grandparent',
            'parent': 'parent',
            'child_0': 'child_0',
            'child_1': 'child_1',
          },
          expandedParent: {
            'grandparent': null,
            'parent': 'grandparent',
            'child_0': 'parent',
            'child_1': 'parent',
          },
          paintOrder: ['grandparent', 'parent', 'child_0', 'child_1'],
          autoLayoutByDocId: {
            'grandparent': const AutoLayout(direction: LayoutDirection.vertical),
            'parent': const AutoLayout(direction: LayoutDirection.vertical, gap: FixedNumeric(10)),
          },
        );

        // Hit test returns parent (correct - child is excluded)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(80, 60), // Over child_0's area, but child excluded
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        // Should target parent, NOT grandparent
        expect(preview.isValid, isTrue);
        expect(preview.targetParentExpandedId, equals('parent'));
        expect(preview.targetParentDocId, equals('parent'));
        expect(preview.intent, equals(DropIntent.reorder));
      });

      test('multi-level nesting targets correct parent', () {
        // Deep nesting: root -> level1 -> level2 -> child
        // Dragging child should target level2
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 500, 500),
            'level1': const Rect.fromLTWH(10, 10, 480, 480),
            'level2': const Rect.fromLTWH(20, 20, 460, 460),
            'child': const Rect.fromLTWH(30, 30, 100, 50),
          },
          renderChildrenByExpandedId: {
            'root': ['level1'],
            'level1': ['level2'],
            'level2': ['child'],
            'child': [],
          },
          expandedToDoc: {
            'root': 'root',
            'level1': 'level1',
            'level2': 'level2',
            'child': 'child',
          },
          expandedParent: {
            'root': null,
            'level1': 'root',
            'level2': 'level1',
            'child': 'level2',
          },
          paintOrder: ['root', 'level1', 'level2', 'child'],
          autoLayoutByDocId: {
            'root': const AutoLayout(direction: LayoutDirection.vertical),
            'level1': const AutoLayout(direction: LayoutDirection.vertical),
            'level2': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        // Hit test returns level2 (immediate parent of child)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'level2',
          docId: 'level2',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(80, 80),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'level2'},
        );

        // Should target level2 (the immediate parent)
        expect(preview.isValid, isTrue);
        expect(preview.targetParentExpandedId, equals('level2'));
        expect(preview.intent, equals(DropIntent.reorder));
      });
    });

    group('stickiness with different parent types', () {
      test('stickiness works with row (horizontal) parent', () {
        final harness = DragDropUnitHarness.horizontalRow(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final cursorWorld = harness.cursorAtSlot('parent', 2);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('parent'));
      });

      test('stickiness with gap and padding', () {
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          gap: 20,
          paddingTop: 15,
          paddingBottom: 15,
          paddingLeft: 10,
          paddingRight: 10,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Cursor in the gap area between children
        final cursorWorld = const Offset(60, 75); // In gap between child_0 and child_1

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('parent'));
      });
    });
  });
}
