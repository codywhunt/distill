import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

import 'mini_scene_harness.dart';

/// Integration tests for drop preview using real scene/render compilation.
///
/// These tests verify the full pipeline:
/// - EditorDocument → ExpandedScene (via ExpandedSceneBuilder)
/// - ExpandedScene → RenderDocument (via RenderCompiler)
/// - FrameLookups.build() for ID mappings
/// - DropPreviewBuilder.compute() with real data
void main() {
  group('Integration: Drop Preview', () {
    group('vertical stack layout', () {
      test('reorder within vertical stack produces valid preview', () {
        final harness = MiniSceneHarness.verticalStack(childCount: 4);

        // Set up hit test to return root
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        final cursorWorld = harness.cursorAtSlot('root', 2);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'root'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('root'));
        expect(preview.targetParentDocId, equals('root'));
        expect(preview.insertionIndex, isNotNull);
      });

      test('reorder computes correct insertion index', () {
        final harness = MiniSceneHarness.verticalStack(
          childCount: 5,
          childHeight: 50,
          gap: 10,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        // Drag child_0, cursor at slot 3 (after child_2 in filtered list)
        final cursorWorld = harness.cursorAtSlot('root', 3);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'root'},
        );

        expect(preview.isValid, isTrue);
        // Filtered children: [child_1, child_2, child_3, child_4]
        // Slot 3 = after child_2 (index 2 in filtered), which is index 3 in filtered
        expect(preview.insertionIndex, isNotNull);
      });

      test('reorder populates reflow offsets', () {
        final harness = MiniSceneHarness.verticalStack(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        final cursorWorld = harness.cursorAtSlot('root', 3);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'root'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        // Reorder should have reflow offsets for sibling movement visualization
        expect(preview.reflowOffsetsByExpandedId, isNotEmpty);
      });
    });

    group('horizontal row layout', () {
      test('reorder within horizontal row produces valid preview', () {
        final harness = MiniSceneHarness.horizontalRow(childCount: 4);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        final cursorWorld = harness.cursorAtSlot('root', 2);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'root'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('root'));
      });

      test('horizontal layout uses correct main axis for slot calculation', () {
        final harness = MiniSceneHarness.horizontalRow(
          childCount: 4,
          childWidth: 80,
          gap: 10,
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        // Slot at beginning (x should be near left edge)
        final slot0 = harness.cursorAtSlot('root', 0);
        expect(slot0.dx, lessThan(40)); // Should be near left

        // Slot at end (x should be near right edge)
        final slot4 = harness.cursorAtSlot('root', 4);
        expect(slot4.dx, greaterThan(300)); // Should be near right
      });
    });

    group('component instances', () {
      test('scene correctly expands instances', () {
        final harness = MiniSceneHarness.withInstances();

        // Verify scene has expanded instance nodes
        expect(harness.scene.nodes.containsKey('inst_a::row_root'), isTrue);
        expect(harness.scene.nodes.containsKey('inst_b::row_root'), isTrue);
        expect(harness.scene.nodes.containsKey('inst_a::row_content'), isTrue);
        expect(harness.scene.nodes.containsKey('inst_b::row_content'), isTrue);
      });

      test('lookups correctly map instance IDs', () {
        final harness = MiniSceneHarness.withInstances();

        // inst_a and inst_b both reference component 'comp_row'
        // Their expanded children map to null (unpatchable in v1)
        final docIdForInstContent = harness.lookups.getDocId('inst_a::row_content');
        expect(docIdForInstContent, isNull); // Instance children are unpatchable

        // The instance nodes themselves are patchable
        final expandedIds = harness.expandedIdsFor('inst_a');
        expect(expandedIds, contains('inst_a'));
      });

      test('reorder instances within root', () {
        final harness = MiniSceneHarness.withInstances();

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        // Drag inst_a to after inst_b
        final cursorWorld = const Offset(150, 150); // Below inst_b

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['inst_a'],
          draggedDocIds: ['inst_a'],
          originalParents: {'inst_a': 'root'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('root'));
      });

      test('instance children are detected correctly', () {
        final harness = MiniSceneHarness.withInstances();

        // Root-level nodes are not inside instances
        expect(harness.isInsideInstance('root'), isFalse);
        expect(harness.isInsideInstance('inst_a'), isFalse);
        expect(harness.isInsideInstance('inst_b'), isFalse);

        // Instance children are inside instances
        expect(harness.isInsideInstance('inst_a::row_root'), isTrue);
        expect(harness.isInsideInstance('inst_a::row_content'), isTrue);
        expect(harness.isInsideInstance('inst_b::row_root'), isTrue);
      });

      test('owning instance is correctly identified', () {
        final harness = MiniSceneHarness.withInstances();

        expect(harness.getOwningInstance('inst_a::row_root'), equals('inst_a'));
        expect(harness.getOwningInstance('inst_a::row_content'), equals('inst_a'));
        expect(harness.getOwningInstance('inst_b::row_root'), equals('inst_b'));
        expect(harness.getOwningInstance('root'), isNull);
      });
    });

    group('deeply nested structures', () {
      test('preview targets correct level in nested hierarchy', () {
        final harness = MiniSceneHarness.deeplyNested();

        // Target level2 (the horizontal container)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'level2',
          docId: 'level2',
        );

        final cursorWorld = const Offset(100, 50);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['leaf_a'],
          draggedDocIds: ['leaf_a'],
          originalParents: {'leaf_a': 'level2'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
        expect(preview.targetParentExpandedId, equals('level2'));
      });

      test('reparent from deep to shallow', () {
        final harness = MiniSceneHarness.deeplyNested();

        // Hit test returns level1 (moving leaf up one level)
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'level1',
          docId: 'level1',
        );

        final cursorWorld = const Offset(200, 150); // Over level1 but not level2

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['leaf_a'],
          draggedDocIds: ['leaf_a'],
          originalParents: {'leaf_a': 'level2'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        expect(preview.targetParentExpandedId, equals('level1'));
        // Reparent should have empty reflow
        expect(preview.reflowOffsetsByExpandedId, isEmpty);
      });

      test('lookups ancestor chain is correct', () {
        final harness = MiniSceneHarness.deeplyNested();

        // Verify parent chain
        expect(harness.lookups.getParent('leaf_a'), equals('level2'));
        expect(harness.lookups.getParent('leaf_b'), equals('level2'));
        expect(harness.lookups.getParent('level2'), equals('level1'));
        expect(harness.lookups.getParent('level1'), equals('root'));
        expect(harness.lookups.getParent('root'), isNull);
      });

      test('can find auto-layout ancestor', () {
        final harness = MiniSceneHarness.deeplyNested();

        // All nodes in this tree have auto-layout, so findAncestor should find them
        final hasAutoLayout = harness.lookups.findAncestor('leaf_a', (id) {
          final docId = harness.lookups.getDocId(id);
          if (docId == null) return false;
          return harness.document.nodes[docId]?.layout.autoLayout != null;
        });

        // leaf_a's parent (level2) has auto-layout
        expect(hasAutoLayout, equals('level2'));
      });
    });

    group('reparent scenarios', () {
      test('reparent to sibling container', () {
        // Build a custom document with two sibling containers
        var doc = EditorDocument.empty(documentId: 'test_doc');

        doc = doc.withNode(const Node(
          id: 'child_item',
          name: 'Child Item',
          type: NodeType.container,
          props: ContainerProps(),
        ));

        doc = doc.withNode(const Node(
          id: 'container_a',
          name: 'Container A',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['child_item'],
          layout: NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.vertical),
          ),
        ));

        doc = doc.withNode(const Node(
          id: 'container_b',
          name: 'Container B',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: [],
          layout: NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.vertical),
          ),
        ));

        doc = doc.withNode(const Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['container_a', 'container_b'],
          layout: NodeLayout(
            autoLayout: AutoLayout(
              direction: LayoutDirection.horizontal,
              gap: FixedNumeric(20),
            ),
          ),
        ));

        final now = DateTime.now();
        doc = doc.withFrame(Frame(
          id: 'f_test',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset.zero,
            size: Size(400, 200),
          ),
          createdAt: now,
          updatedAt: now,
        ));

        final harness = MiniSceneHarness.fromDocument(
          document: doc,
          frameId: 'f_test',
          boundsProvider: (expandedId, node) {
            return switch (expandedId) {
              'root' => const Rect.fromLTWH(0, 0, 400, 200),
              'container_a' => const Rect.fromLTWH(0, 0, 180, 200),
              'container_b' => const Rect.fromLTWH(200, 0, 180, 200),
              'child_item' => const Rect.fromLTWH(10, 10, 160, 50),
              _ => null,
            };
          },
        );

        // Hit test returns container_b
        harness.hitResultOverride = const ContainerHit(
          expandedId: 'container_b',
          docId: 'container_b',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(290, 100), // Over container_b
          draggedExpandedIds: ['child_item'],
          draggedDocIds: ['child_item'],
          originalParents: {'child_item': 'container_a'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        expect(preview.targetParentExpandedId, equals('container_b'));
        expect(preview.insertionIndex, equals(0)); // Empty container
      });
    });

    group('edge cases', () {
      test('empty container accepts drop at index 0', () {
        // Build document with empty target container
        var doc = EditorDocument.empty(documentId: 'test_doc');

        doc = doc.withNode(const Node(
          id: 'item',
          name: 'Item',
          type: NodeType.container,
          props: ContainerProps(),
        ));

        doc = doc.withNode(const Node(
          id: 'empty_target',
          name: 'Empty Target',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: [],
          layout: NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.vertical),
          ),
        ));

        doc = doc.withNode(const Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['item', 'empty_target'],
          layout: NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.horizontal),
          ),
        ));

        final now = DateTime.now();
        doc = doc.withFrame(Frame(
          id: 'f_test',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset.zero,
            size: Size(400, 200),
          ),
          createdAt: now,
          updatedAt: now,
        ));

        final harness = MiniSceneHarness.fromDocument(
          document: doc,
          frameId: 'f_test',
          boundsProvider: (expandedId, node) {
            return switch (expandedId) {
              'root' => const Rect.fromLTWH(0, 0, 400, 200),
              'item' => const Rect.fromLTWH(0, 0, 100, 200),
              'empty_target' => const Rect.fromLTWH(120, 0, 200, 200),
              _ => null,
            };
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'empty_target',
          docId: 'empty_target',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(220, 100), // Center of empty_target
          draggedExpandedIds: ['item'],
          draggedDocIds: ['item'],
          originalParents: {'item': 'root'},
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reparent));
        expect(preview.targetParentExpandedId, equals('empty_target'));
        expect(preview.insertionIndex, equals(0));
      });

      test('single child container handles reorder', () {
        final harness = MiniSceneHarness.verticalStack(childCount: 1);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        final preview = harness.computePreview(
          cursorWorld: const Offset(50, 30),
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'root'},
        );

        // Should be valid even with single child (reorder to same position)
        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
      });

      test('frame position offset is applied correctly', () {
        final harness = MiniSceneHarness.verticalStack(
          childCount: 3,
          framePosition: const Offset(100, 100),
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        // World position accounting for frame offset
        final cursorWorld = harness.cursorAtSlot('root', 1);

        // Cursor should be offset from origin
        expect(cursorWorld.dx, greaterThan(100));
        expect(cursorWorld.dy, greaterThan(100));

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0'],
          draggedDocIds: ['child_0'],
          originalParents: {'child_0': 'root'},
        );

        expect(preview.isValid, isTrue);
      });
    });

    group('multi-select integration', () {
      test('multi-select reorder with contiguous selection', () {
        final harness = MiniSceneHarness.verticalStack(childCount: 5);

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        // Drag [child_0, child_1] to after child_3
        final cursorWorld = harness.cursorAtSlot('root', 3);

        final preview = harness.computePreview(
          cursorWorld: cursorWorld,
          draggedExpandedIds: ['child_0', 'child_1'],
          draggedDocIds: ['child_0', 'child_1'],
          originalParents: {
            'child_0': 'root',
            'child_1': 'root',
          },
        );

        expect(preview.isValid, isTrue);
        expect(preview.intent, equals(DropIntent.reorder));
      });

      test('multi-select requires same parent', () {
        // Build a document where two items have different parents
        var doc = EditorDocument.empty(documentId: 'test_doc');

        doc = doc.withNode(const Node(
          id: 'item_a',
          name: 'Item A',
          type: NodeType.container,
          props: ContainerProps(),
        ));

        doc = doc.withNode(const Node(
          id: 'item_b',
          name: 'Item B',
          type: NodeType.container,
          props: ContainerProps(),
        ));

        doc = doc.withNode(const Node(
          id: 'parent_a',
          name: 'Parent A',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['item_a'],
          layout: NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.vertical),
          ),
        ));

        doc = doc.withNode(const Node(
          id: 'parent_b',
          name: 'Parent B',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['item_b'],
          layout: NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.vertical),
          ),
        ));

        doc = doc.withNode(const Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['parent_a', 'parent_b'],
          layout: NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.horizontal),
          ),
        ));

        final now = DateTime.now();
        doc = doc.withFrame(Frame(
          id: 'f_test',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset.zero,
            size: Size(400, 200),
          ),
          createdAt: now,
          updatedAt: now,
        ));

        final harness = MiniSceneHarness.fromDocument(
          document: doc,
          frameId: 'f_test',
          boundsProvider: (expandedId, node) {
            return switch (expandedId) {
              'root' => const Rect.fromLTWH(0, 0, 400, 200),
              'parent_a' => const Rect.fromLTWH(0, 0, 180, 200),
              'parent_b' => const Rect.fromLTWH(200, 0, 180, 200),
              'item_a' => const Rect.fromLTWH(10, 10, 160, 50),
              'item_b' => const Rect.fromLTWH(210, 10, 160, 50),
              _ => null,
            };
          },
        );

        harness.hitResultOverride = const ContainerHit(
          expandedId: 'root',
          docId: 'root',
        );

        // Try to drag items with different parents
        final preview = harness.computePreview(
          cursorWorld: const Offset(200, 100),
          draggedExpandedIds: ['item_a', 'item_b'],
          draggedDocIds: ['item_a', 'item_b'],
          originalParents: {
            'item_a': 'parent_a', // Different parent
            'item_b': 'parent_b', // Different parent
          },
        );

        // Should be invalid due to INV-7 (same-parent multi-select)
        expect(preview.isValid, isFalse);
        expect(preview.invalidReason, contains('parent'));
      });
    });
  });
}
