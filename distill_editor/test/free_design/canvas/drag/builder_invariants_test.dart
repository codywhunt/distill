import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'unit_test_harness.dart';

/// Tests for the core invariants (INV-1 through INV-9).
///
/// These invariants are critical constraints that must always hold.
/// Some are tested more thoroughly in red_flag_regressions_test.dart.
void main() {
  group('Invariant Tests', () {
    // =========================================================================
    // INV-1: Expanded-First Hit Testing
    // =========================================================================
    group('INV-1: expanded-first hit testing', () {
      test('builder uses expandedId from hit, not random choice', () {
        // When hit test returns a specific expandedId, the builder should
        // use that exact expandedId, not pick randomly from docToExpanded.
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 300, 200),
            'inst_a::row': const Rect.fromLTWH(10, 10, 280, 50),
            'inst_b::row': const Rect.fromLTWH(10, 70, 280, 50),
            'item': const Rect.fromLTWH(10, 130, 100, 30),
          },
          renderChildrenByExpandedId: {
            'root': ['inst_a::row', 'inst_b::row', 'item'],
            'inst_a::row': [],
            'inst_b::row': [],
            'item': [],
          },
          expandedToDoc: {
            'root': 'root',
            'inst_a::row': 'row',
            'inst_b::row': 'row',
            'item': 'item',
          },
          docToExpanded: {
            'root': ['root'],
            'row': ['inst_a::row', 'inst_b::row'], // Same docId for both
            'item': ['item'],
          },
          expandedParent: {
            'root': null,
            'inst_a::row': 'root',
            'inst_b::row': 'root',
            'item': 'root',
          },
          paintOrder: ['root', 'inst_a::row', 'inst_b::row', 'item'],
          autoLayoutByDocId: {
            'root': const AutoLayout(direction: LayoutDirection.vertical),
            'row': const AutoLayout(direction: LayoutDirection.horizontal),
          },
        );

        // Explicitly set hit to inst_a::row
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'inst_a::row',
          docId: 'row',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(150, 35),
          draggedExpandedIds: ['item'],
          draggedDocIds: ['item'],
          originalParents: {'item': 'root'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.targetParentExpandedId, equals('inst_a::row'));
        expect(preview.targetParentDocId, equals('row'));
      });

      test('docId is derived from scene.patchTarget, not computed', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 2);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent', // This should match what's in expandedToDoc
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 50),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isTrue);
        // The docId should come from the harness's expandedToDoc, which is
        // used to build scene.patchTarget
        expect(preview.targetParentDocId, equals('parent'));
      });
    });

    // =========================================================================
    // INV-2: Children from Render Tree
    // =========================================================================
    group('INV-2: children from render tree', () {
      test('targetChildrenExpandedIds comes from renderDoc, not document', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 100),
          draggedExpandedIds: ['child_1'], // Dragging child_1
          draggedDocIds: ['child_1'],
          originalParents: {'child_1': 'parent'},
        );

        expect(preview.isValid, isTrue);
        // Children should be from renderDoc, with dragged node filtered out
        // Original: [child_0, child_1, child_2, child_3]
        // Filtered: [child_0, child_2, child_3]
        expect(preview.targetChildrenExpandedIds, equals(['child_0', 'child_2', 'child_3']));
      });

      test('unpatchable children are filtered out', () {
        // Nodes inside instances (expandedToDoc = null) should be filtered
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'parent': const Rect.fromLTWH(0, 0, 300, 200),
            'child_a': const Rect.fromLTWH(10, 10, 100, 50),
            'inst::internal': const Rect.fromLTWH(10, 70, 100, 50), // Instance internal
            'child_b': const Rect.fromLTWH(10, 130, 100, 50),
          },
          renderChildrenByExpandedId: {
            'parent': ['child_a', 'inst::internal', 'child_b'],
            'child_a': [],
            'inst::internal': [],
            'child_b': [],
          },
          expandedToDoc: {
            'parent': 'parent',
            'child_a': 'child_a',
            'inst::internal': null, // Unpatchable (inside instance)
            'child_b': 'child_b',
          },
          expandedParent: {
            'parent': null,
            'child_a': 'parent',
            'inst::internal': 'parent',
            'child_b': 'parent',
          },
          paintOrder: ['parent', 'child_a', 'inst::internal', 'child_b'],
          autoLayoutByDocId: {
            'parent': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 50),
          draggedExpandedIds: ['child_a'],
          draggedDocIds: ['child_a'],
          originalParents: {'child_a': 'parent'},
        );

        expect(preview.isValid, isTrue);
        // inst::internal should be filtered because it's unpatchable
        // child_a filtered because it's being dragged
        expect(preview.targetChildrenExpandedIds, equals(['child_b']));
      });
    });

    // =========================================================================
    // INV-6: Indicator Clipped to Content Box
    // =========================================================================
    group('INV-6: indicator clipped to content box', () {
      test('indicator rect is within parent content bounds', () {
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          paddingTop: 20,
          paddingBottom: 20,
          paddingLeft: 15,
          paddingRight: 15,
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

        if (preview.indicatorWorldRect != null) {
          // Get parent bounds and compute content box
          final parentBounds = harness.boundsByExpandedId['parent']!;
          final contentBox = Rect.fromLTRB(
            parentBounds.left + 15, // paddingLeft
            parentBounds.top + 20, // paddingTop
            parentBounds.right - 15, // paddingRight
            parentBounds.bottom - 20, // paddingBottom
          );

          final indicator = preview.indicatorWorldRect!;

          // Indicator should be within content box (allowing for thickness)
          expect(indicator.left, greaterThanOrEqualTo(contentBox.left - 1));
          expect(indicator.right, lessThanOrEqualTo(contentBox.right + 1));
          expect(indicator.top, greaterThanOrEqualTo(contentBox.top - 1));
          expect(indicator.bottom, lessThanOrEqualTo(contentBox.bottom + 1));
        }
      });

      test('collapsed content area results in no indicator', () {
        // When padding is so large that content area is collapsed
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'parent': const Rect.fromLTWH(0, 0, 100, 100),
            'child': const Rect.fromLTWH(50, 50, 0, 0), // Zero-size child
          },
          renderChildrenByExpandedId: {
            'parent': ['child'],
            'child': [],
          },
          expandedToDoc: {
            'parent': 'parent',
            'child': 'child',
          },
          expandedParent: {
            'parent': null,
            'child': 'parent',
          },
          paintOrder: ['parent', 'child'],
          autoLayoutByDocId: {
            // Huge padding collapses content area
            'parent': AutoLayout(
              direction: LayoutDirection.vertical,
              padding: TokenEdgePadding.allFixed(60), // 60*2 > 100
            ),
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 50),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent'},
        );

        // INV-Y + indicator hardening: With extreme padding that collapses content,
        // we fall back to parent bounds with 1px inset. Since parent is 100x100,
        // the fallback content box is 98x98 which is valid, so indicator is computed.
        // This avoids dead zones for small containers.
        expect(preview.isValid, isTrue);
        expect(preview.indicatorWorldRect, isNotNull);
      });
    });

    // =========================================================================
    // INV-7: Same-Parent Multi-Select
    // =========================================================================
    group('INV-7: same-parent multi-select', () {
      test('returns invalid when dragged nodes have different parents', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 400, 200),
            'parent_a': const Rect.fromLTWH(10, 10, 180, 180),
            'parent_b': const Rect.fromLTWH(210, 10, 180, 180),
            'child_a': const Rect.fromLTWH(20, 20, 80, 40),
            'child_b': const Rect.fromLTWH(220, 20, 80, 40),
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

        final preview = harness.computePreview(
          cursorWorld: const Offset(200, 100),
          draggedExpandedIds: ['child_a', 'child_b'],
          draggedDocIds: ['child_a', 'child_b'],
          originalParents: {
            'child_a': 'parent_a', // Different parent
            'child_b': 'parent_b', // Different parent
          },
        );

        // INV-7: Should be invalid
        expect(preview.isValid, isFalse);
        expect(preview.invalidReason, contains('different parents'));
      });

      test('valid when dragged nodes have same parent', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 100),
          draggedExpandedIds: ['child_0', 'child_1'],
          draggedDocIds: ['child_0', 'child_1'],
          originalParents: {
            'child_0': 'parent', // Same parent
            'child_1': 'parent', // Same parent
          },
        );

        expect(preview.isValid, isTrue);
      });
    });

    // =========================================================================
    // INV-8: Target IDs Non-Null When Valid
    // =========================================================================
    group('INV-8: target IDs non-null when valid', () {
      test('valid preview has both targetParentDocId and targetParentExpandedId', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 50),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.targetParentDocId, isNotNull);
        expect(preview.targetParentExpandedId, isNotNull);
      });

      test('invalid preview can have null target IDs', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

        // No hit
        harness.hitResultOverride = null;

        final preview = harness.computePreview(
          cursorWorld: const Offset(1000, 1000), // Outside
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(preview.isValid, isFalse);
        // Target IDs may be null for invalid preview
        expect(preview.targetParentExpandedId, isNull);
      });
    });

    // =========================================================================
    // INV-9: Reflow Only on Reorder (tested in red_flag_regressions_test.dart)
    // =========================================================================
    group('INV-9: reflow only on reorder', () {
      test('reorder intent has non-empty reflow', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

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
        expect(preview.reflowOffsetsByExpandedId, isNotEmpty);
      });

      test('reparent intent has empty reflow', () {
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

        // Hit parent_b (different from origin parent_a)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(300, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        expect(preview.reflowOffsetsByExpandedId, isEmpty);
      });
    });

    // =========================================================================
    // Additional Invariant: Circular Reference Prevention
    // =========================================================================
    group('Circular reference prevention', () {
      test('cannot drop into own descendant', () {
        // Trying to drop parent into its own child creates a cycle
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'grandparent': const Rect.fromLTWH(0, 0, 400, 400),
            'parent': const Rect.fromLTWH(20, 20, 360, 360),
            'child': const Rect.fromLTWH(40, 40, 320, 320),
          },
          renderChildrenByExpandedId: {
            'grandparent': ['parent'],
            'parent': ['child'],
            'child': [],
          },
          expandedToDoc: {
            'grandparent': 'grandparent',
            'parent': 'parent',
            'child': 'child',
          },
          expandedParent: {
            'grandparent': null,
            'parent': 'grandparent',
            'child': 'parent',
          },
          paintOrder: ['grandparent', 'parent', 'child'],
          autoLayoutByDocId: {
            'grandparent': const AutoLayout(direction: LayoutDirection.vertical),
            'parent': const AutoLayout(direction: LayoutDirection.vertical),
            'child': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        // Try to drop parent into its child
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'child',
          docId: 'child',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(200, 200),
          draggedExpandedIds: ['parent'],
          draggedDocIds: ['parent'],
          originalParents: {'parent': 'grandparent'},
        );

        expect(preview.isValid, isFalse);
        expect(preview.invalidReason, contains('descendant'));
      });
    });

    // =========================================================================
    // INV-E: Eligibility Contract
    // =========================================================================
    group('INV-E: eligibility contract', () {
      test('cursor over non-eligible container resolves to nearest eligible ancestor', () {
        // When hit test returns a container without auto-layout, we should climb
        // to find the nearest auto-layout ancestor
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 300, 200),
            'non_auto': const Rect.fromLTWH(10, 10, 280, 180),
            'item': const Rect.fromLTWH(20, 20, 100, 50),
          },
          renderChildrenByExpandedId: {
            'root': ['non_auto'],
            'non_auto': ['item'],
            'item': [],
          },
          expandedToDoc: {
            'root': 'root',
            'non_auto': 'non_auto',
            'item': 'item',
          },
          expandedParent: {
            'root': null,
            'non_auto': 'root',
            'item': 'non_auto',
          },
          paintOrder: ['root', 'non_auto', 'item'],
          autoLayoutByDocId: {
            'root': const AutoLayout(direction: LayoutDirection.vertical),
            // 'non_auto' has NO auto-layout
          },
        );

        // Hit test returns non_auto (which is not eligible)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'non_auto',
          docId: 'non_auto',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(70, 45),
          draggedExpandedIds: ['item'],
          draggedDocIds: ['item'],
          originalParents: {'item': 'non_auto'},
        );

        // Should climb to root (the nearest eligible ancestor)
        expect(preview.isValid, isTrue);
        expect(preview.targetParentExpandedId, equals('root'));
      });

      test('cursor over eligible nested container resolves to that container', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 300, 200),
            'nested_auto': const Rect.fromLTWH(10, 10, 280, 180),
            'item': const Rect.fromLTWH(20, 20, 100, 50),
          },
          renderChildrenByExpandedId: {
            'root': ['nested_auto'],
            'nested_auto': ['item'],
            'item': [],
          },
          expandedToDoc: {
            'root': 'root',
            'nested_auto': 'nested_auto',
            'item': 'item',
          },
          expandedParent: {
            'root': null,
            'nested_auto': 'root',
            'item': 'nested_auto',
          },
          paintOrder: ['root', 'nested_auto', 'item'],
          autoLayoutByDocId: {
            'root': const AutoLayout(direction: LayoutDirection.vertical),
            'nested_auto': const AutoLayout(direction: LayoutDirection.horizontal),
          },
        );

        // Hit test returns nested_auto (which IS eligible)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'nested_auto',
          docId: 'nested_auto',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(70, 45),
          draggedExpandedIds: ['item'],
          draggedDocIds: ['item'],
          originalParents: {'item': 'nested_auto'},
        );

        // Should target nested_auto directly (it's eligible)
        expect(preview.isValid, isTrue);
        expect(preview.targetParentExpandedId, equals('nested_auto'));
      });

      test('no eligible ancestor returns invalid preview with reason', () {
        // When there's no auto-layout container in the hierarchy
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'root': const Rect.fromLTWH(0, 0, 300, 200),
            'non_auto': const Rect.fromLTWH(10, 10, 280, 180),
            'item': const Rect.fromLTWH(20, 20, 100, 50),
          },
          renderChildrenByExpandedId: {
            'root': ['non_auto'],
            'non_auto': ['item'],
            'item': [],
          },
          expandedToDoc: {
            'root': 'root',
            'non_auto': 'non_auto',
            'item': 'item',
          },
          expandedParent: {
            'root': null,
            'non_auto': 'root',
            'item': 'non_auto',
          },
          paintOrder: ['root', 'non_auto', 'item'],
          autoLayoutByDocId: {
            // NO auto-layout anywhere!
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'non_auto',
          docId: 'non_auto',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(70, 45),
          draggedExpandedIds: ['item'],
          draggedDocIds: ['item'],
          originalParents: {'item': 'non_auto'},
        );

        expect(preview.isValid, isFalse);
        expect(preview.invalidReason, isNotNull);
      });

      test('dragged container is not eligible as drop target', () {
        // A container being dragged cannot be its own drop target
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'grandparent': const Rect.fromLTWH(0, 0, 400, 400),
            'parent': const Rect.fromLTWH(20, 20, 360, 360),
            'child': const Rect.fromLTWH(40, 40, 100, 50),
          },
          renderChildrenByExpandedId: {
            'grandparent': ['parent'],
            'parent': ['child'],
            'child': [],
          },
          expandedToDoc: {
            'grandparent': 'grandparent',
            'parent': 'parent',
            'child': 'child',
          },
          expandedParent: {
            'grandparent': null,
            'parent': 'grandparent',
            'child': 'parent',
          },
          paintOrder: ['grandparent', 'parent', 'child'],
          autoLayoutByDocId: {
            'grandparent': const AutoLayout(direction: LayoutDirection.vertical),
            'parent': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        // Hit test returns parent, but we're dragging parent
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(100, 100),
          draggedExpandedIds: ['parent'],
          draggedDocIds: ['parent'],
          originalParents: {'parent': 'grandparent'},
        );

        // Should NOT target parent (it's being dragged), should climb to grandparent
        expect(preview.isValid, isTrue);
        expect(preview.targetParentExpandedId, equals('grandparent'));
      });
    });

    // =========================================================================
    // INV-Y: Valid Drop Requires Non-Null Indicator
    // =========================================================================
    group('INV-Y: valid drop requires non-null indicator', () {
      test('valid reorder has non-null indicator', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 3);

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
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.indicatorWorldRect, isNotNull);
      });

      test('valid reparent has non-null indicator', () {
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

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent_b',
          docId: 'parent_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(300, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent_a'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        expect(preview.indicatorWorldRect, isNotNull);
      });

      test('tiny container yields valid indicator (expanded to minimum)', () {
        // Test that indicator hardening expands tiny containers
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'parent': const Rect.fromLTWH(0, 0, 20, 100), // Very narrow
            'child_0': const Rect.fromLTWH(0, 0, 20, 40),
            'child_1': const Rect.fromLTWH(0, 50, 20, 40),
          },
          renderChildrenByExpandedId: {
            'parent': ['child_0', 'child_1'],
            'child_0': [],
            'child_1': [],
          },
          expandedToDoc: {
            'parent': 'parent',
            'child_0': 'child_0',
            'child_1': 'child_1',
          },
          expandedParent: {
            'parent': null,
            'child_0': 'parent',
            'child_1': 'parent',
          },
          paintOrder: ['parent', 'child_0', 'child_1'],
          autoLayoutByDocId: {
            'parent': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(10, 45), // Between children
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        // With indicator hardening, should still get valid indicator
        expect(preview.isValid, isTrue);
        expect(preview.indicatorWorldRect, isNotNull);
      });
    });
  });
}
