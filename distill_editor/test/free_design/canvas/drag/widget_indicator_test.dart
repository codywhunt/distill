import 'dart:ui';

import 'package:flutter/painting.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

/// Widget tests for drag/drop overlays (Layer C).
///
/// These tests verify the visual contract between DropPreview state
/// and expected overlay behavior.
///
/// ## Test Scope
///
/// - DropPreview visual contract (shouldShowIndicator)
/// - DropPreview.none factory
/// - DropIntent enum states
void main() {
  group('Widget Tests: Drop Preview Visual Contract', () {
    group('shouldShowIndicator', () {
      test('true when valid drop with indicator rect and axis', () {
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1,
          intent: DropIntent.reorder,
          indicatorWorldRect: Rect.fromLTWH(10, 50, 100, 2),
          indicatorAxis: Axis.horizontal,
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
          targetChildrenExpandedIds: ['child_1', 'child_2'],
          targetChildrenDocIds: ['child_1', 'child_2'],
          reflowOffsetsByExpandedId: {'child_1': Offset(0, 50)},
        );

        expect(preview.shouldShowIndicator, isTrue);
        expect(preview.indicatorWorldRect, isNotNull);
        expect(preview.indicatorAxis, isNotNull);
      });

      test('true for reparent intent with indicator', () {
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'new_parent',
          targetParentDocId: 'new_parent',
          insertionIndex: 0,
          intent: DropIntent.reparent,
          indicatorWorldRect: Rect.fromLTWH(10, 10, 100, 2),
          indicatorAxis: Axis.horizontal,
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
        );

        expect(preview.shouldShowIndicator, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
      });

      test('false when invalid', () {
        const preview = DropPreview.none(
          frameId: 'f_test',
          invalidReason: 'No valid drop target',
        );

        expect(preview.shouldShowIndicator, isFalse);
        expect(preview.isValid, isFalse);
        expect(preview.indicatorWorldRect, isNull);
      });

      test('false when indicator rect is null', () {
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1,
          intent: DropIntent.reorder,
          indicatorWorldRect: null, // No indicator rect
          indicatorAxis: Axis.horizontal,
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
        );

        expect(preview.shouldShowIndicator, isFalse);
      });

      test('false when indicator axis is null', () {
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1,
          intent: DropIntent.reorder,
          indicatorWorldRect: Rect.fromLTWH(10, 50, 100, 2),
          indicatorAxis: null, // No indicator axis
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
        );

        expect(preview.shouldShowIndicator, isFalse);
      });

      test('false when intent is none', () {
        const preview = DropPreview.none(
          frameId: 'f_test',
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
        );

        expect(preview.shouldShowIndicator, isFalse);
        expect(preview.intent, equals(DropIntent.none));
      });
    });

    group('DropPreview.none factory', () {
      test('creates invalid preview', () {
        const preview = DropPreview.none(
          frameId: 'f_test',
          invalidReason: 'Test reason',
        );

        expect(preview.isValid, isFalse);
        expect(preview.invalidReason, equals('Test reason'));
        expect(preview.intent, equals(DropIntent.none));
        expect(preview.frameId, equals('f_test'));
      });

      test('has correct defaults', () {
        const preview = DropPreview.none(frameId: 'f_test');

        expect(preview.targetParentExpandedId, isNull);
        expect(preview.targetParentDocId, isNull);
        expect(preview.insertionIndex, isNull);
        expect(preview.indicatorWorldRect, isNull);
        expect(preview.indicatorAxis, isNull);
        expect(preview.draggedDocIdsOrdered, isEmpty);
        expect(preview.draggedExpandedIdsOrdered, isEmpty);
        expect(preview.targetChildrenExpandedIds, isEmpty);
        expect(preview.targetChildrenDocIds, isEmpty);
        expect(preview.reflowOffsetsByExpandedId, isEmpty);
      });

      test('accepts dragged IDs', () {
        const preview = DropPreview.none(
          frameId: 'f_test',
          draggedDocIdsOrdered: ['child_0', 'child_1'],
          draggedExpandedIdsOrdered: ['child_0', 'child_1'],
        );

        expect(preview.draggedDocIdsOrdered, equals(['child_0', 'child_1']));
        expect(preview.draggedExpandedIdsOrdered, equals(['child_0', 'child_1']));
      });
    });

    group('DropPreview valid construction', () {
      test('requires both target IDs when valid', () {
        // This should not throw - both IDs provided
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1,
          intent: DropIntent.reorder,
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
        );

        expect(preview.isValid, isTrue);
        expect(preview.targetParentExpandedId, isNotNull);
        expect(preview.targetParentDocId, isNotNull);
      });

      test('reorder intent has reflow offsets', () {
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 2,
          intent: DropIntent.reorder,
          indicatorWorldRect: Rect.fromLTWH(10, 100, 100, 2),
          indicatorAxis: Axis.horizontal,
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
          targetChildrenExpandedIds: ['child_1', 'child_2'],
          targetChildrenDocIds: ['child_1', 'child_2'],
          reflowOffsetsByExpandedId: {
            'child_1': Offset(0, -50),
            'child_2': Offset(0, 0),
          },
        );

        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.reflowOffsetsByExpandedId, isNotEmpty);
      });

      test('reparent intent has empty reflow offsets', () {
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'new_parent',
          targetParentDocId: 'new_parent',
          insertionIndex: 0,
          intent: DropIntent.reparent,
          indicatorWorldRect: Rect.fromLTWH(10, 10, 100, 2),
          indicatorAxis: Axis.horizontal,
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
          reflowOffsetsByExpandedId: {}, // Empty for reparent (INV-9)
        );

        expect(preview.intent, equals(DropIntent.reparent));
        expect(preview.reflowOffsetsByExpandedId, isEmpty);
      });
    });

    group('DropIntent enum', () {
      test('none is default invalid state', () {
        expect(DropIntent.none.name, equals('none'));
        expect(DropIntent.values, contains(DropIntent.none));
      });

      test('reorder indicates same-parent move', () {
        expect(DropIntent.reorder.name, equals('reorder'));
        expect(DropIntent.values, contains(DropIntent.reorder));
      });

      test('reparent indicates cross-parent move', () {
        expect(DropIntent.reparent.name, equals('reparent'));
        expect(DropIntent.values, contains(DropIntent.reparent));
      });

      test('all intents are accounted for', () {
        // Ensure test is updated if new intents are added
        expect(DropIntent.values.length, equals(3));
        expect(DropIntent.values, containsAll([
          DropIntent.none,
          DropIntent.reorder,
          DropIntent.reparent,
        ]));
      });
    });

    group('DropPreview toString', () {
      test('includes key information', () {
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'parent',
          targetParentDocId: 'parent',
          insertionIndex: 1,
          intent: DropIntent.reorder,
          indicatorWorldRect: Rect.fromLTWH(10, 50, 100, 2),
          indicatorAxis: Axis.horizontal,
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
          targetChildrenExpandedIds: ['child_1', 'child_2'],
          targetChildrenDocIds: ['child_1', 'child_2'],
        );

        final str = preview.toString();
        expect(str, contains('DropPreview'));
        expect(str, contains('intent: DropIntent.reorder'));
        expect(str, contains('isValid: true'));
        expect(str, contains('frame: f_test'));
        expect(str, contains('targetDoc: parent'));
        expect(str, contains('index: 1'));
      });

      test('includes invalid reason when present', () {
        const preview = DropPreview.none(
          frameId: 'f_test',
          invalidReason: 'No container hit',
        );

        final str = preview.toString();
        expect(str, contains('reason: No container hit'));
      });
    });

    group('indicator axis semantics', () {
      test('horizontal axis for vertical/column layout', () {
        // In a vertical (column) layout, the insertion indicator is horizontal
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'column',
          targetParentDocId: 'column',
          insertionIndex: 1,
          intent: DropIntent.reorder,
          indicatorWorldRect: Rect.fromLTWH(10, 60, 100, 2), // Wide, thin
          indicatorAxis: Axis.horizontal, // Horizontal line
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
        );

        expect(preview.indicatorAxis, equals(Axis.horizontal));
        // Indicator should be wider than tall for horizontal line
        expect(preview.indicatorWorldRect!.width, greaterThan(preview.indicatorWorldRect!.height));
      });

      test('vertical axis for horizontal/row layout', () {
        // In a horizontal (row) layout, the insertion indicator is vertical
        const preview = DropPreview(
          isValid: true,
          frameId: 'f_test',
          targetParentExpandedId: 'row',
          targetParentDocId: 'row',
          insertionIndex: 1,
          intent: DropIntent.reorder,
          indicatorWorldRect: Rect.fromLTWH(60, 10, 2, 50), // Thin, tall
          indicatorAxis: Axis.vertical, // Vertical line
          draggedDocIdsOrdered: ['child_0'],
          draggedExpandedIdsOrdered: ['child_0'],
        );

        expect(preview.indicatorAxis, equals(Axis.vertical));
        // Indicator should be taller than wide for vertical line
        expect(preview.indicatorWorldRect!.height, greaterThan(preview.indicatorWorldRect!.width));
      });
    });
  });
}
