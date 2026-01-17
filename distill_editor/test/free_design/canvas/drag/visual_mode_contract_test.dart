import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'unit_test_harness.dart';

/// Tests for the visual mode contract.
///
/// The drop preview system derives visual states from DropPreview fields.
/// These tests verify the contract between preview state and expected visuals.
///
/// ## Visual Modes
///
/// | Mode    | Conditions              | Expected Visuals                                |
/// |---------|-------------------------|-------------------------------------------------|
/// | Reorder | intent == reorder       | Insertion line, reflow offsets, target outline  |
/// | Reparent| intent == reparent      | Insertion line, target outline, no reflow       |
/// | Invalid | !isValid                | No indicator, no outline, no reflow             |
///
/// ## Key Derived Properties
///
/// - `indicatorWorldRect`: Non-null when valid drop location exists
/// - `reflowOffsetsByExpandedId`: Non-empty only for reorder
/// - `targetParentExpandedId`: Non-null for target outline display
void main() {
  group('Visual Mode Contract Tests', () {
    group('reorder mode visuals', () {
      test('reorder has non-null insertion indicator', () {
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 4,
          paddingTop: 10,
          paddingBottom: 10,
          paddingLeft: 10,
          paddingRight: 10,
        );

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
        // Insertion indicator should be present
        expect(preview.insertionIndex, isNotNull);
      });

      test('reorder has non-empty reflow offsets', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final cursorWorld = harness.cursorAtSlot('parent', 3);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        // Reflow offsets should be present for siblings to animate
        expect(preview.reflowOffsetsByExpandedId, isNotEmpty);
      });

      test('reorder has target parent for outline', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: harness.cursorAtSlot('parent', 1),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        // Target parent should be available for outline rendering
        expect(preview.targetParentExpandedId, isNotNull);
        expect(preview.targetParentDocId, isNotNull);
      });

      test('reorder reflow offsets are keyed by expandedId', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 5);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Drag child_2 to slot 0
        final preview = harness.computePreview(
          cursorWorld: harness.cursorAtSlot('parent', 0),
          draggedExpandedIds: ['child_2'],
          draggedDocIds: ['child_2'],
          originalParents: {'child_2': 'parent'},
        );

        expect(preview.isValid, isTrue);

        // Reflow keys should be valid expanded IDs
        for (final key in preview.reflowOffsetsByExpandedId.keys) {
          expect(harness.boundsByExpandedId.containsKey(key), isTrue,
              reason: 'Reflow key "$key" should be a valid expandedId');
        }
      });
    });

    group('reparent mode visuals', () {
      test('reparent has non-null insertion indicator', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(200, 10, 180, 180),
            'child': const Rect.fromLTWH(20, 20, 80, 40),
          },
          renderChildrenByExpandedId: {
            'root': ['parent_a', 'parent_b'],
            'parent_a': ['child'],
            'parent_b': [],
            'child': [],
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

        // Target parent_b (empty, different from origin)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(290, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        // Insertion indicator should still be present
        expect(preview.insertionIndex, isNotNull);
        expect(preview.insertionIndex, equals(0)); // Empty container
      });

      test('reparent has EMPTY reflow offsets', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(200, 10, 180, 180),
            'child': const Rect.fromLTWH(20, 20, 80, 40),
          },
          renderChildrenByExpandedId: {
            'root': ['parent_a', 'parent_b'],
            'parent_a': ['child'],
            'parent_b': [],
            'child': [],
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

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(290, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        // Reparent should NOT have reflow offsets (no sibling animation)
        expect(preview.reflowOffsetsByExpandedId, isEmpty);
      });

      test('reparent has target parent for outline', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(200, 10, 180, 180),
            'child': const Rect.fromLTWH(20, 20, 80, 40),
          },
          renderChildrenByExpandedId: {
            'root': ['parent_a', 'parent_b'],
            'parent_a': ['child'],
            'parent_b': [],
            'child': [],
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

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(290, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        // Target parent should be the NEW parent (for highlighting)
        expect(preview.targetParentExpandedId, equals('parent_b'));
        expect(preview.targetParentDocId, equals('parent_b'));
      });
    });

    group('invalid mode visuals', () {
      test('invalid preview has no reflow offsets', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

        // No hit result - invalid drop
        harness.hitResultOverride = null;

        final preview = harness.computePreview(
          cursorWorld: const Offset(-100, -100), // Outside all bounds
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isFalse);
        // Invalid should have no reflow
        expect(preview.reflowOffsetsByExpandedId, isEmpty);
      });

      test('invalid preview has null insertion index', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

        harness.hitResultOverride = null;

        final preview = harness.computePreview(
          cursorWorld: const Offset(-100, -100),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isFalse);
        // Invalid should have null insertion index
        expect(preview.insertionIndex, isNull);
      });

      test('invalid preview may have null target IDs', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

        harness.hitResultOverride = null;

        final preview = harness.computePreview(
          cursorWorld: const Offset(-100, -100),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isFalse);
        // Target IDs can be null when invalid
        // (they're not meaningful without a valid drop)
      });

      test('invalid due to multi-parent selection has reason', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(200, 10, 180, 180),
            'child_a': const Rect.fromLTWH(20, 20, 80, 40),
            'child_b': const Rect.fromLTWH(210, 20, 80, 40),
          },
          renderChildrenByExpandedId: {
            'root': ['parent_a', 'parent_b'],
            'parent_a': ['child_a'],
            'parent_b': ['child_b'],
            'child_a': [],
            'child_b': [],
          },
          expandedToDoc: {
            'root': 'root',
            'parent_a': 'parent_a',
            'parent_b': 'parent_b',
            'child_a': 'child_a',
            'child_b': 'child_b',
          },
          expandedParent: {
            'root': null,
            'parent_a': 'root',
            'parent_b': 'root',
            'child_a': 'parent_a',
            'child_b': 'parent_b',
          },
          paintOrder: ['root', 'parent_a', 'child_a', 'parent_b', 'child_b'],
          autoLayoutByDocId: {
            'root': const AutoLayout(direction: LayoutDirection.horizontal),
            'parent_a': const AutoLayout(direction: LayoutDirection.vertical),
            'parent_b': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        // Try to drag children from different parents
        final preview = harness.computePreview(
          cursorWorld: const Offset(200, 100),
          draggedExpandedIds: ['child_a', 'child_b'],
          draggedDocIds: ['child_a', 'child_b'],
          originalParents: {
            'child_a': 'parent_a',
            'child_b': 'parent_b',
          },
        );

        expect(preview.isValid, isFalse);
        expect(preview.invalidReason, isNotNull);
        expect(preview.invalidReason, contains('parent'));
      });
    });

    group('intent determination', () {
      test('same target parent as origin means reorder', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: harness.cursorAtSlot('parent', 3),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'}, // Same as target
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
      });

      test('different target parent means reparent', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(200, 10, 180, 180),
            'child': const Rect.fromLTWH(20, 20, 80, 40),
          },
          renderChildrenByExpandedId: {
            'root': ['parent_a', 'parent_b'],
            'parent_a': ['child'],
            'parent_b': [],
            'child': [],
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

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(290, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'}, // Different from target
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
      });
    });

    group('visual state consistency', () {
      test('reflow offsets only when reorder', () {
        // This test verifies the visual contract:
        // reflow offsets should ONLY be present for reorder, never for reparent
        //
        // Use the factory which sets up bounds correctly for reflow
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

        // Test reorder - drag child_0 to after child_2 (slot 3)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final reorderPreview = harness.computePreview(
          cursorWorld: harness.cursorAtSlot('parent', 3),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(reorderPreview.intent, equals(DropIntent.reorder));
        expect(reorderPreview.reflowOffsetsByExpandedId, isNotEmpty,
            reason: 'Reorder should have reflow offsets');
      });

      test('reparent has empty reflow offsets', () {
        // Reparent case - separate harness to avoid state leakage
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(200, 10, 180, 180),
            'child': const Rect.fromLTWH(20, 20, 80, 40),
          },
          renderChildrenByExpandedId: {
            'root': ['parent_a', 'parent_b'],
            'parent_a': ['child'],
            'parent_b': [],
            'child': [],
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

        // Test reparent
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final reparentPreview = harness.computePreview(
          cursorWorld: const Offset(290, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'},
        );

        expect(reparentPreview.intent, equals(DropIntent.reparent));
        expect(reparentPreview.reflowOffsetsByExpandedId, isEmpty,
            reason: 'Reparent should NOT have reflow offsets');
      });

      test('indicator direction matches container layout direction', () {
        // Vertical container
        final vertHarness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          paddingTop: 10,
          paddingBottom: 10,
          paddingLeft: 10,
          paddingRight: 10,
        );

        vertHarness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final vertPreview = vertHarness.computePreview(
          cursorWorld: vertHarness.cursorAtSlot('parent', 1),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(vertPreview.isValid, isTrue);
        // Indicator rect for vertical layout should be wider than tall (horizontal line)
        if (vertPreview.indicatorWorldRect != null) {
          final rect = vertPreview.indicatorWorldRect!;
          expect(rect.width, greaterThan(rect.height),
              reason: 'Vertical container should have horizontal indicator');
        }

        // Horizontal container
        final horizHarness = DragDropUnitHarness.horizontalRow(childCount: 3);

        horizHarness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final horizPreview = horizHarness.computePreview(
          cursorWorld: horizHarness.cursorAtSlot('parent', 1),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(horizPreview.isValid, isTrue);
        // Indicator rect for horizontal layout should be taller than wide (vertical line)
        if (horizPreview.indicatorWorldRect != null) {
          final rect = horizPreview.indicatorWorldRect!;
          expect(rect.height, greaterThan(rect.width),
              reason: 'Horizontal container should have vertical indicator');
        }
      });
    });
  });
}
