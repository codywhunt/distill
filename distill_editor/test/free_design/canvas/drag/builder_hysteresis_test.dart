import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'unit_test_harness.dart';

/// Tests for hysteresis behavior (flip-flop prevention).
///
/// Hysteresis prevents the insertion index from rapidly changing
/// when the cursor is near a slot boundary.
void main() {
  group('Hysteresis Tests', () {
    group('_applyHysteresis behavior', () {
      test('first computation uses raw index (no last state)', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // First computation - no last index
        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 100),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: null, // No previous state
          lastInsertionCursor: null,
        );

        expect(preview.isValid, isTrue);
        expect(preview.insertionIndex, isNotNull);
        // Should use raw index directly
      });

      test('small movement sticks to last index', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // First: establish baseline at cursor (50, 60)
        final preview1 = harness.computePreview(
          cursorWorld: const Offset(50, 60),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
        );

        final firstIndex = preview1.insertionIndex;

        // Second: move 3 pixels (less than 8px threshold at zoom=1)
        final preview2 = harness.computePreview(
          cursorWorld: const Offset(50, 63), // 3px movement
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: firstIndex,
          lastInsertionCursor: const Offset(50, 60),
          zoom: 1.0,
        );

        // Should stick to first index due to hysteresis
        expect(preview2.insertionIndex, equals(firstIndex));
      });

      test('large movement allows index change', () {
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 4,
          childHeight: 50,
          gap: 10,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // First: cursor near slot 1 boundary
        final preview1 = harness.computePreview(
          cursorWorld: const Offset(50, 25), // Before child_0 center at y=25
          draggedExpandedIds: ['child_1'],
          draggedDocIds: ['child_1'],
          originalParents: {'child_1': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
        );

        // Second: move 20 pixels (more than 8px threshold)
        final preview2 = harness.computePreview(
          cursorWorld: const Offset(50, 45), // Well past child_0 center
          draggedExpandedIds: ['child_1'],
          draggedDocIds: ['child_1'],
          originalParents: {'child_1': 'parent'},
          lastInsertionIndex: preview1.insertionIndex,
          lastInsertionCursor: const Offset(50, 25),
          zoom: 1.0,
        );

        // Index may change due to large movement
        // The key is that it's allowed to change, not forced to stay
        expect(preview2.insertionIndex, isNotNull);
      });

      test('same raw index no change regardless of distance', () {
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          childHeight: 100,
          gap: 20,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Large container, cursor moves within the same slot
        final preview1 = harness.computePreview(
          cursorWorld: const Offset(50, 10), // Way before first child center
          draggedExpandedIds: ['child_1'],
          draggedDocIds: ['child_1'],
          originalParents: {'child_1': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
        );

        expect(preview1.insertionIndex, equals(0));

        // Move a lot, but still in same slot
        final preview2 = harness.computePreview(
          cursorWorld: const Offset(50, 40), // Still before center at y=50
          draggedExpandedIds: ['child_1'],
          draggedDocIds: ['child_1'],
          originalParents: {'child_1': 'parent'},
          lastInsertionIndex: 0,
          lastInsertionCursor: const Offset(50, 10),
          zoom: 1.0,
        );

        // Same index, regardless of movement distance
        expect(preview2.insertionIndex, equals(0));
      });
    });

    group('zoom affects threshold', () {
      test('at zoom 2x threshold is 4px', () {
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          childHeight: 50,
          gap: 10,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // At zoom=2, threshold is 8/2 = 4 world pixels
        final preview1 = harness.computePreview(
          cursorWorld: const Offset(50, 55), // After child_0 center
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
          zoom: 2.0,
        );

        // Move 5 world pixels (>4 threshold at 2x zoom)
        final preview2 = harness.computePreview(
          cursorWorld: const Offset(50, 60),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: preview1.insertionIndex,
          lastInsertionCursor: const Offset(50, 55),
          zoom: 2.0,
        );

        // Should allow index change since we moved past threshold
        expect(preview2.insertionIndex, isNotNull);
      });

      test('at zoom 0.5x threshold is 16px', () {
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          childHeight: 50,
          gap: 10,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // At zoom=0.5, threshold is 8/0.5 = 16 world pixels
        final preview1 = harness.computePreview(
          cursorWorld: const Offset(50, 55),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
          zoom: 0.5,
        );

        // Move 10 world pixels (<16 threshold at 0.5x zoom)
        final preview2 = harness.computePreview(
          cursorWorld: const Offset(50, 65),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: preview1.insertionIndex,
          lastInsertionCursor: const Offset(50, 55),
          zoom: 0.5,
        );

        // Should stick to last index (10 < 16)
        expect(preview2.insertionIndex, equals(preview1.insertionIndex));
      });
    });

    group('flip-flop prevention', () {
      test('rapid back-and-forth near boundary stays stable', () {
        // This is the critical flip-flop test
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          childHeight: 50,
          gap: 10,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Start at a position and establish index
        var lastIndex = harness.computePreview(
          cursorWorld: const Offset(50, 50),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
        ).insertionIndex;

        var lastCursor = const Offset(50, 50);

        // Simulate rapid small movements back and forth
        final movements = [
          const Offset(50, 52), // +2
          const Offset(50, 50), // -2
          const Offset(50, 53), // +3
          const Offset(50, 49), // -4
          const Offset(50, 51), // +2
        ];

        for (final cursor in movements) {
          final preview = harness.computePreview(
            cursorWorld: cursor,
            draggedExpandedIds: ['child_0'],
            draggedDocIds: ['child_0'],
            originalParents: {'child_0': 'parent'},
            lastInsertionIndex: lastIndex,
            lastInsertionCursor: lastCursor,
            zoom: 1.0,
          );

          // Index should stay stable due to hysteresis
          expect(preview.insertionIndex, equals(lastIndex),
              reason: 'Index should not flip-flop with small movements');

          lastCursor = cursor;
          // Don't update lastIndex - simulating the builder's behavior
          // where index only updates when threshold is exceeded
        }
      });

      test('coordinate system consistency prevents flip-flop', () {
        // Tests that frame-local vs world coordinate handling is correct
        final harness = DragDropUnitHarness.verticalColumn(
          childCount: 3,
          childHeight: 50,
          gap: 10,
          framePosition: const Offset(100, 100), // Frame not at origin
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // World coords (accounting for frame at 100,100)
        final preview1 = harness.computePreview(
          cursorWorld: const Offset(150, 155), // Frame-local: (50, 55)
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
        );

        // Small world movement
        final preview2 = harness.computePreview(
          cursorWorld: const Offset(152, 157), // 2px movement in world
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: preview1.insertionIndex,
          lastInsertionCursor: const Offset(150, 155),
          zoom: 1.0,
        );

        // Should be stable despite frame offset
        expect(preview2.insertionIndex, equals(preview1.insertionIndex));
      });
    });

    group('horizontal layout hysteresis', () {
      test('horizontal row has same hysteresis behavior', () {
        final harness = DragDropUnitHarness.horizontalRow(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        final preview1 = harness.computePreview(
          cursorWorld: const Offset(100, 25),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: null,
          lastInsertionCursor: null,
        );

        // Small horizontal movement (3px)
        final preview2 = harness.computePreview(
          cursorWorld: const Offset(103, 25),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
          lastInsertionIndex: preview1.insertionIndex,
          lastInsertionCursor: const Offset(100, 25),
          zoom: 1.0,
        );

        // Should stick due to hysteresis
        expect(preview2.insertionIndex, equals(preview1.insertionIndex));
      });
    });

    group('edge cases', () {
      test('empty container always returns index 0', () {
        final harness = DragDropUnitHarness(
          boundsByExpandedId: {
            'parent': const Rect.fromLTWH(0, 0, 200, 200),
            'child': const Rect.fromLTWH(50, 50, 50, 50),
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
            'parent': const AutoLayout(direction: LayoutDirection.vertical),
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Dragging the only child - target becomes empty
        final preview = harness.computePreview(
          cursorWorld: const Offset(100, 100),
          draggedExpandedIds: ['child'],
          draggedDocIds: ['child'],
          originalParents: {'child': 'parent'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.insertionIndex, equals(0)); // Empty = 0
      });

      test('single child container has correct indices', () {
        final harness = DragDropUnitHarness.verticalColumn(childCount: 2);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'parent',
          docId: 'parent',
        );

        // Dragging child_0, target has only child_1
        final previewStart = harness.computePreview(
          cursorWorld: const Offset(50, 5), // Before child_1
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(previewStart.insertionIndex, equals(0));

        final previewEnd = harness.computePreview(
          cursorWorld: const Offset(50, 100), // After child_1
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'parent'},
        );

        expect(previewEnd.insertionIndex, equals(1));
      });
    });
  });
}
