import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('Drag & Drop Fixes', () {
    group('calculateInsertionIndex', () {
      late EditorDocumentStore store;
      late CanvasState state;

      setUp(() {
        final now = DateTime.now();

        // Create a frame with auto-layout container
        final frame = Frame(
          id: 'frame_1',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset(0, 0),
            size: Size(400, 600),
          ),
          createdAt: now,
          updatedAt: now,
        );

        // Root container with vertical auto-layout
        final root = Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['child_a', 'child_b', 'child_c'],
          layout: NodeLayout(
            size: SizeMode.fixed(400, 600),
            autoLayout: const AutoLayout(
              direction: LayoutDirection.vertical,
              gap: FixedNumeric(10),
            ),
          ),
        );

        // Three children in a vertical column
        final childA = Node(
          id: 'child_a',
          name: 'Child A',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final childB = Node(
          id: 'child_b',
          name: 'Child B',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final childC = Node(
          id: 'child_c',
          name: 'Child C',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final doc = EditorDocument.empty(documentId: 'test_doc')
            .withNode(root)
            .withNode(childA)
            .withNode(childB)
            .withNode(childC)
            .withFrame(frame);

        store = EditorDocumentStore(document: doc);
        state = CanvasState(store: store);

        // Manually populate bounds cache for testing
        // Child A: y = 0..50
        state.updateNodeBounds('frame_1', 'child_a', const Rect.fromLTWH(0, 0, 100, 50));
        // Child B: y = 60..110 (50 + 10 gap)
        state.updateNodeBounds('frame_1', 'child_b', const Rect.fromLTWH(0, 60, 100, 50));
        // Child C: y = 120..170 (110 + 10 gap)
        state.updateNodeBounds('frame_1', 'child_c', const Rect.fromLTWH(0, 120, 100, 50));
        // Root container bounds
        state.updateNodeBounds('frame_1', 'root', const Rect.fromLTWH(0, 0, 400, 600));
      });

      tearDown(() {
        state.dispose();
      });

      test('returns 0 when cursor is before first child', () {
        // Cursor at y=10 (within child A, but before its center at y=25)
        final index = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 10), // world coordinates (frame at 0,0)
        );

        expect(index, equals(0));
      });

      test('returns 1 when cursor is between first and second child', () {
        // Cursor at y=50 (between A center at 25 and B center at 85)
        final index = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 50),
        );

        expect(index, equals(1));
      });

      test('returns 2 when cursor is between second and third child', () {
        // Cursor at y=100 (between B center at 85 and C center at 145)
        final index = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 100),
        );

        expect(index, equals(2));
      });

      test('returns child count when cursor is after last child', () {
        // Cursor at y=200 (after C center at 145)
        final index = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 200),
        );

        expect(index, equals(3));
      });

      test('excludes dragged node from calculation', () {
        // When dragging child_a past child_b, without exclusion the index
        // would be wrong because child_a is still counted

        // Cursor at y=100 (after B center at 85, before C center at 145)
        // Without exclusion: children are [A, B, C] with centers at 25, 85, 145
        //   cursor at 100 > 25 (past A), > 85 (past B), < 145 (before C)
        //   returns 2 (insert before C)
        // With exclusion of A: children are [B, C] with centers at 85, 145
        //   cursor at 100 > 85 (past B), < 145 (before C)
        //   returns 1 (insert before C in the filtered list)

        final indexWithoutExclusion = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 100),
        );

        final indexWithExclusion = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 100),
          draggedNodeIds: {'child_a'},
        );

        // Without exclusion, index is among 3 children
        expect(indexWithoutExclusion, equals(2));
        // With exclusion, index is among 2 children (B and C only)
        // Returns 1 because cursor is between B and C in the filtered list
        expect(indexWithExclusion, equals(1));
      });

      test('exclusion produces correct index when reordering', () {
        // Drag child_a (index 0) to after child_c
        // Cursor at y=200 (past all children)

        final indexWithExclusion = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 200),
          draggedNodeIds: {'child_a'},
        );

        // With A excluded, only B and C remain (count=2)
        // Cursor past all = insert at end = index 2
        expect(indexWithExclusion, equals(2));
      });

      test('exclusion handles multiple dragged nodes', () {
        // Drag both child_a and child_b
        // Cursor at y=200 (past all children)

        final indexWithExclusion = state.calculateInsertionIndex(
          'frame_1',
          'root',
          const Offset(50, 200),
          draggedNodeIds: {'child_a', 'child_b'},
        );

        // With A and B excluded, only C remains (count=1)
        // Cursor past all = insert at end = index 1
        expect(indexWithExclusion, equals(1));
      });

      test('returns child count for non-auto-layout containers', () {
        // Create a container without auto-layout
        final manualContainer = Node(
          id: 'manual',
          name: 'Manual',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['manual_child'],
          layout: NodeLayout(size: SizeMode.fixed(200, 200)),
        );

        final manualChild = Node(
          id: 'manual_child',
          name: 'Manual Child',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(
            position: const PositionModeAbsolute(x: 10, y: 10),
            size: SizeMode.fixed(50, 50),
          ),
        );

        store.applyPatches([
          InsertNode(manualContainer),
          InsertNode(manualChild),
        ]);

        final index = state.calculateInsertionIndex(
          'frame_1',
          'manual',
          const Offset(50, 50),
        );

        // Non-auto-layout always appends to end
        expect(index, equals(1));
      });
    });

    group('coordinate transformation', () {
      late EditorDocumentStore store;
      late CanvasState state;

      setUp(() {
        final now = DateTime.now();

        final frame = Frame(
          id: 'frame_1',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset(100, 100), // Frame at (100, 100)
            size: Size(400, 600),
          ),
          createdAt: now,
          updatedAt: now,
        );

        // Root container at frame origin
        final root = Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['parent_a', 'parent_b'],
          layout: NodeLayout(size: SizeMode.fixed(400, 600)),
        );

        // Parent A at (50, 50) relative to root
        final parentA = Node(
          id: 'parent_a',
          name: 'Parent A',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['child'],
          layout: NodeLayout(
            position: const PositionModeAbsolute(x: 50, y: 50),
            size: SizeMode.fixed(150, 200),
          ),
        );

        // Parent B at (250, 50) relative to root
        final parentB = Node(
          id: 'parent_b',
          name: 'Parent B',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(
            position: const PositionModeAbsolute(x: 250, y: 50),
            size: SizeMode.fixed(100, 200),
          ),
        );

        // Child at (20, 20) relative to parent A
        // In frame-local coords: (50 + 20, 50 + 20) = (70, 70)
        final child = Node(
          id: 'child',
          name: 'Child',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(
            position: const PositionModeAbsolute(x: 20, y: 20),
            size: SizeMode.fixed(50, 50),
          ),
        );

        final doc = EditorDocument.empty(documentId: 'test_doc')
            .withNode(root)
            .withNode(parentA)
            .withNode(parentB)
            .withNode(child)
            .withFrame(frame);

        store = EditorDocumentStore(document: doc);
        state = CanvasState(store: store);

        // Set up bounds cache
        state.updateNodeBounds('frame_1', 'root', const Rect.fromLTWH(0, 0, 400, 600));
        state.updateNodeBounds('frame_1', 'parent_a', const Rect.fromLTWH(50, 50, 150, 200));
        state.updateNodeBounds('frame_1', 'parent_b', const Rect.fromLTWH(250, 50, 100, 200));
        state.updateNodeBounds('frame_1', 'child', const Rect.fromLTWH(70, 70, 50, 50));
      });

      tearDown(() {
        state.dispose();
      });

      test('frameLocalToParentLocal converts correctly', () {
        // Frame-local position (70, 70) should become (20, 20) relative to parent_a
        // because parent_a is at (50, 50)
        final parentLocal = state.frameLocalToParentLocal(
          const Offset(70, 70),
          'parent_a',
          'frame_1',
        );

        expect(parentLocal.dx, closeTo(20, 0.01));
        expect(parentLocal.dy, closeTo(20, 0.01));
      });

      test('frameLocalToParentLocal handles different parent', () {
        // Frame-local position (270, 70) relative to parent_b at (250, 50)
        // Should become (20, 20) relative to parent_b
        final parentLocal = state.frameLocalToParentLocal(
          const Offset(270, 70),
          'parent_b',
          'frame_1',
        );

        expect(parentLocal.dx, closeTo(20, 0.01));
        expect(parentLocal.dy, closeTo(20, 0.01));
      });

      test('frameLocalToParentLocal returns input when parent not found', () {
        final input = const Offset(100, 100);
        final result = state.frameLocalToParentLocal(
          input,
          'nonexistent_parent',
          'frame_1',
        );

        expect(result, equals(input));
      });
    });

    group('canReparent validation', () {
      late EditorDocumentStore store;
      late CanvasState state;

      setUp(() {
        final now = DateTime.now();

        final frame = Frame(
          id: 'frame_1',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset(0, 0),
            size: Size(400, 600),
          ),
          createdAt: now,
          updatedAt: now,
        );

        // Hierarchy: root -> parent -> child -> grandchild
        final root = Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['parent'],
          layout: NodeLayout(size: SizeMode.fixed(400, 600)),
        );

        final parent = Node(
          id: 'parent',
          name: 'Parent',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['child'],
          layout: NodeLayout(size: SizeMode.fixed(200, 200)),
        );

        final child = Node(
          id: 'child',
          name: 'Child',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['grandchild'],
          layout: NodeLayout(size: SizeMode.fixed(100, 100)),
        );

        final grandchild = Node(
          id: 'grandchild',
          name: 'Grandchild',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(50, 50)),
        );

        // A text node (non-container)
        final textNode = Node(
          id: 'text_node',
          name: 'Text',
          type: NodeType.text,
          props: const TextProps(text: 'Hello'),
          layout: NodeLayout(size: SizeMode.fixed(100, 30)),
        );

        final doc = EditorDocument.empty(documentId: 'test_doc')
            .withNode(root)
            .withNode(parent)
            .withNode(child)
            .withNode(grandchild)
            .withNode(textNode)
            .withFrame(frame);

        store = EditorDocumentStore(document: doc);
        state = CanvasState(store: store);
      });

      tearDown(() {
        state.dispose();
      });

      test('allows reparenting to valid container', () {
        expect(state.canReparent('grandchild', 'parent'), isTrue);
        expect(state.canReparent('grandchild', 'root'), isTrue);
      });

      test('prevents circular reparenting (parent into its own child)', () {
        // Can't move parent into child (child is descendant of parent)
        expect(state.canReparent('parent', 'child'), isFalse);
        expect(state.canReparent('parent', 'grandchild'), isFalse);
      });

      test('prevents reparenting into non-container', () {
        // Text nodes can't have children
        expect(state.canReparent('grandchild', 'text_node'), isFalse);
      });

      test('prevents reparenting to nonexistent node', () {
        expect(state.canReparent('grandchild', 'nonexistent'), isFalse);
      });

      test('allows same-level reparenting', () {
        // Siblings can be moved between each other (if they're containers)
        // grandchild moving to root is allowed
        expect(state.canReparent('grandchild', 'root'), isTrue);
      });
    });

    // Note: hitTestContainer requires a fully compiled render document to work
    // properly. The excludeNodeIds parameter was added to fix same-parent
    // sibling reordering. This is tested via integration tests in the app.
    // The implementation is straightforward:
    // - hitTestContainer now accepts Set<String>? excludeNodeIds
    // - Nodes in excludeNodeIds are skipped during hit testing
    // - This allows "seeing through" dragged nodes to find the actual parent

    group('adjustDropTargetForSiblings', () {
      late EditorDocumentStore store;
      late CanvasState state;

      setUp(() {
        final now = DateTime.now();

        final frame = Frame(
          id: 'frame_1',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset(0, 0),
            size: Size(400, 600),
          ),
          createdAt: now,
          updatedAt: now,
        );

        // Root container with three sibling containers
        final root = Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['sibling_a', 'sibling_b', 'sibling_c'],
          layout: NodeLayout(size: SizeMode.fixed(400, 600)),
        );

        final siblingA = Node(
          id: 'sibling_a',
          name: 'Sibling A',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final siblingB = Node(
          id: 'sibling_b',
          name: 'Sibling B',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final siblingC = Node(
          id: 'sibling_c',
          name: 'Sibling C',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['nested_child'],
          layout: NodeLayout(size: SizeMode.fixed(100, 100)),
        );

        // A nested child inside sibling_c
        final nestedChild = Node(
          id: 'nested_child',
          name: 'Nested Child',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(50, 50)),
        );

        final doc = EditorDocument.empty(documentId: 'test_doc')
            .withNode(root)
            .withNode(siblingA)
            .withNode(siblingB)
            .withNode(siblingC)
            .withNode(nestedChild)
            .withFrame(frame);

        store = EditorDocumentStore(document: doc);
        state = CanvasState(store: store);
      });

      tearDown(() {
        state.dispose();
      });

      test('returns parent when drop target is a sibling', () {
        // When dragging sibling_a and cursor lands on sibling_b,
        // should return 'root' (the parent) instead of 'sibling_b'
        final result = state.adjustDropTargetForSiblings(
          const ContainerHit('sibling_b', 'sibling_b'),
          {'sibling_a'},
          'frame_1',
        );

        expect(result?.patchId, equals('root'));
      });

      test('returns original target when not a sibling', () {
        // When dragging sibling_a into sibling_c (a valid nested drop),
        // the result depends on whether sibling_c is sibling of sibling_a
        // It IS a sibling, so should return parent
        final siblingResult = state.adjustDropTargetForSiblings(
          const ContainerHit('sibling_c', 'sibling_c'),
          {'sibling_a'},
          'frame_1',
        );
        expect(siblingResult?.patchId, equals('root'));

        // But when dragging sibling_a and drop target is nested_child
        // (which is NOT a sibling - it's in sibling_c), keep the target
        final nestedResult = state.adjustDropTargetForSiblings(
          const ContainerHit('nested_child', 'nested_child'),
          {'sibling_a'},
          'frame_1',
        );
        expect(nestedResult?.patchId, equals('nested_child'));
      });

      test('returns original target when dropping into a different subtree', () {
        // When dragging nested_child out to root, root is not a sibling
        // (nested_child's parent is sibling_c, root's parent is null)
        final result = state.adjustDropTargetForSiblings(
          const ContainerHit('root', 'root'),
          {'nested_child'},
          'frame_1',
        );

        expect(result?.patchId, equals('root'));
      });

      test('handles null drop target', () {
        final result = state.adjustDropTargetForSiblings(
          null,
          {'sibling_a'},
          'frame_1',
        );

        expect(result, isNull);
      });

      test('handles empty dragged nodes', () {
        final result = state.adjustDropTargetForSiblings(
          const ContainerHit('sibling_b', 'sibling_b'),
          {},
          'frame_1',
        );

        expect(result?.patchId, equals('sibling_b'));
      });
    });

    group('move patches generation', () {
      late EditorDocumentStore store;
      late CanvasState state;

      setUp(() {
        final now = DateTime.now();

        final frame = Frame(
          id: 'frame_1',
          name: 'Test Frame',
          rootNodeId: 'root',
          canvas: const CanvasPlacement(
            position: Offset(0, 0),
            size: Size(400, 600),
          ),
          createdAt: now,
          updatedAt: now,
        );

        // Root with auto-layout
        final root = Node(
          id: 'root',
          name: 'Root',
          type: NodeType.container,
          props: const ContainerProps(),
          childIds: const ['child_a', 'child_b', 'child_c'],
          layout: NodeLayout(
            size: SizeMode.fixed(400, 600),
            autoLayout: const AutoLayout(
              direction: LayoutDirection.vertical,
              gap: FixedNumeric(10),
            ),
          ),
        );

        final childA = Node(
          id: 'child_a',
          name: 'Child A',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final childB = Node(
          id: 'child_b',
          name: 'Child B',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final childC = Node(
          id: 'child_c',
          name: 'Child C',
          type: NodeType.container,
          props: const ContainerProps(),
          layout: NodeLayout(size: SizeMode.fixed(100, 50)),
        );

        final doc = EditorDocument.empty(documentId: 'test_doc')
            .withNode(root)
            .withNode(childA)
            .withNode(childB)
            .withNode(childC)
            .withFrame(frame);

        store = EditorDocumentStore(document: doc);
        state = CanvasState(store: store);

        // Set up bounds
        state.updateNodeBounds('frame_1', 'root', const Rect.fromLTWH(0, 0, 400, 600));
        state.updateNodeBounds('frame_1', 'child_a', const Rect.fromLTWH(0, 0, 100, 50));
        state.updateNodeBounds('frame_1', 'child_b', const Rect.fromLTWH(0, 60, 100, 50));
        state.updateNodeBounds('frame_1', 'child_c', const Rect.fromLTWH(0, 120, 100, 50));
      });

      tearDown(() {
        state.dispose();
      });

      test('reordering within same parent adjusts index correctly', () {
        // Select child_a (index 0)
        state.selectNode('frame_1', 'child_a');
        state.startDrag();

        // Set up drag session for reordering to after child_c
        final session = state.dragSession!;
        session.dropTarget = 'root';
        session.dropFrameId = 'frame_1';
        session.insertionIndex = 2; // After B and C (but A is excluded in calculation)

        // Apply a small drag offset
        state.updateDrag(const Offset(0, 150), useSmartGuides: false);
        state.endDrag();

        // Check that child_a is now at the end
        final root = state.document.nodes['root']!;
        expect(root.childIds, equals(['child_b', 'child_c', 'child_a']));
      });

      test('reordering to same position produces no patch', () {
        // Select child_a (index 0)
        state.selectNode('frame_1', 'child_a');
        state.startDrag();

        // Set up drag session for staying at index 0
        final session = state.dragSession!;
        session.dropTarget = 'root';
        session.dropFrameId = 'frame_1';
        session.insertionIndex = 0; // Stay at beginning

        state.updateDrag(const Offset(0, 10), useSmartGuides: false);

        final originalChildIds = List.from(state.document.nodes['root']!.childIds);
        state.endDrag();

        // Order should be unchanged
        final root = state.document.nodes['root']!;
        expect(root.childIds, equals(originalChildIds));
      });

      test('moving from index 0 to index 1 works', () {
        // Select child_a (index 0)
        state.selectNode('frame_1', 'child_a');
        state.startDrag();

        // Set up drag session for moving to index 1 (after B)
        final session = state.dragSession!;
        session.dropTarget = 'root';
        session.dropFrameId = 'frame_1';
        session.insertionIndex = 1; // After B in the filtered list

        state.updateDrag(const Offset(0, 80), useSmartGuides: false);
        state.endDrag();

        // Child A should now be between B and C
        final root = state.document.nodes['root']!;
        expect(root.childIds, equals(['child_b', 'child_a', 'child_c']));
      });
    });
  });
}
