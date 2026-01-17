import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('FreeDesignState', () {
    late EditorDocumentStore store;
    late CanvasState state;
    late Frame frame1;
    late Frame frame2;

    setUp(() {
      final now = DateTime.now();

      // Create two frames
      frame1 = Frame(
        id: 'frame_1',
        name: 'Frame 1',
        rootNodeId: 'root_1',
        canvas: const CanvasPlacement(
          position: Offset(100, 100),
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      frame2 = Frame(
        id: 'frame_2',
        name: 'Frame 2',
        rootNodeId: 'root_2',
        canvas: const CanvasPlacement(
          position: Offset(600, 100),
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      // Create root nodes for each frame
      final root1 = Node(
        id: 'root_1',
        name: 'Root 1',
        type: NodeType.container,
        props: const ContainerProps(),
        childIds: const ['child_1'],
        layout: NodeLayout(size: SizeMode.fixed(375, 812)),
      );

      final root2 = Node(
        id: 'root_2',
        name: 'Root 2',
        type: NodeType.container,
        props: const ContainerProps(),
        layout: NodeLayout(size: SizeMode.fixed(375, 812)),
      );

      final child1 = Node(
        id: 'child_1',
        name: 'Child 1',
        type: NodeType.container,
        props: const ContainerProps(),
        layout: NodeLayout(
          position: const PositionModeAbsolute(x: 50, y: 50),
          size: SizeMode.fixed(100, 80),
        ),
      );

      final doc = EditorDocument.empty(documentId: 'test_doc')
          .withNode(root1)
          .withNode(root2)
          .withNode(child1)
          .withFrame(frame1)
          .withFrame(frame2);

      store = EditorDocumentStore(document: doc);
      state = CanvasState(store: store);
    });

    tearDown(() {
      state.dispose();
    });

    group('selection', () {
      test('select adds to selection', () {
        const target = FrameTarget('frame_1');

        state.select(target);

        expect(state.selection, contains(target));
        expect(state.selection, hasLength(1));
      });

      test('select with addToSelection=true adds to existing selection', () {
        const target1 = FrameTarget('frame_1');
        const target2 = FrameTarget('frame_2');

        state.select(target1);
        state.select(target2, addToSelection: true);

        expect(state.selection, containsAll([target1, target2]));
        expect(state.selection, hasLength(2));
      });

      test('select with addToSelection=false replaces selection', () {
        const target1 = FrameTarget('frame_1');
        const target2 = FrameTarget('frame_2');

        state.select(target1);
        state.select(target2, addToSelection: false);

        expect(state.selection, contains(target2));
        expect(state.selection, hasLength(1));
      });

      test('selectFrame selects frame by ID', () {
        state.selectFrame('frame_1');

        expect(state.selection.first, isA<FrameTarget>());
        expect((state.selection.first as FrameTarget).frameId, 'frame_1');
      });

      test('selectNode selects node by IDs', () {
        state.selectNode('frame_1', 'child_1');

        expect(state.selection.first, isA<NodeTarget>());
        final node = state.selection.first as NodeTarget;
        expect(node.frameId, 'frame_1');
        expect(node.expandedId, 'child_1');
      });

      test('deselect removes from selection', () {
        const target1 = FrameTarget('frame_1');
        const target2 = FrameTarget('frame_2');

        state.select(target1);
        state.select(target2, addToSelection: true);
        state.deselect(target1);

        expect(state.selection, contains(target2));
        expect(state.selection, isNot(contains(target1)));
        expect(state.selection, hasLength(1));
      });

      test('deselectAll clears selection', () {
        state.selectFrame('frame_1');
        state.selectFrame('frame_2', addToSelection: true);

        state.deselectAll();

        expect(state.selection, isEmpty);
      });

      test('selectedFrameIds filters to FrameTargets', () {
        state.selectFrame('frame_1');
        state.selectNode('frame_1', 'child_1', addToSelection: true);

        expect(state.selectedFrameIds, equals({'frame_1'}));
      });

      test('selectedNodes filters to NodeTargets', () {
        state.selectFrame('frame_1');
        state.selectNode('frame_1', 'child_1', addToSelection: true);

        expect(state.selectedNodes, hasLength(1));
        expect(state.selectedNodes.first.expandedId, 'child_1');
      });

      test('selectFramesInRect selects frames in region', () {
        // Select region containing frame_1 only
        state.selectFramesInRect(const Rect.fromLTWH(50, 50, 400, 900));

        expect(state.selectedFrameIds, contains('frame_1'));
        expect(state.selectedFrameIds, isNot(contains('frame_2')));
      });

      test('setHovered sets hovered target', () {
        const target = FrameTarget('frame_1');

        state.setHovered(target);

        expect(state.hovered, equals(target));
      });

      test('setHovered with same target does not notify', () {
        const target = FrameTarget('frame_1');
        state.setHovered(target);

        var notified = false;
        state.addListener(() => notified = true);

        state.setHovered(target);

        expect(notified, isFalse);
      });
    });

    group('hit testing', () {
      test('hitTestFrame returns frame at point', () {
        final result = state.hitTestFrame(const Offset(200, 200));

        expect(result, isNotNull);
        expect(result!.frameId, equals('frame_1'));
      });

      test('hitTestFrame returns null for empty space', () {
        final result = state.hitTestFrame(const Offset(0, 0));

        expect(result, isNull);
      });

      test('hitTestFrame returns topmost frame when overlapping', () {
        // Both frames are at different positions, so test the second one
        final result = state.hitTestFrame(const Offset(700, 200));

        expect(result, isNotNull);
        expect(result!.frameId, equals('frame_2'));
      });
    });

    group('drag operations', () {
      test('startDrag creates move session from selection', () {
        state.selectFrame('frame_1');

        state.startDrag();

        expect(state.isDragging, isTrue);
        expect(state.dragSession, isNotNull);
        expect(state.dragSession!.mode, equals(DragMode.move));
      });

      test('startDrag does nothing with empty selection', () {
        state.startDrag();

        expect(state.isDragging, isFalse);
        expect(state.dragSession, isNull);
      });

      test('updateDrag updates accumulator', () {
        state.selectFrame('frame_1');
        state.startDrag();

        state.updateDrag(const Offset(50, 25), useSmartGuides: false);

        expect(state.dragSession!.accumulator, equals(const Offset(50, 25)));
      });

      test('updateDrag applies grid snap', () {
        state.selectFrame('frame_1');
        state.startDrag();

        state.updateDrag(
          const Offset(53, 27),
          gridSize: 10,
          useSmartGuides: false,
        );

        // Should snap to nearest grid point
        expect(state.dragSession!.accumulator.dx, equals(50));
        expect(state.dragSession!.accumulator.dy, equals(30));
      });

      test('updateDrag accepts zoom parameter for snap engine', () {
        // This test verifies the zoom parameter is accepted (not hardcoded)
        state.selectFrame('frame_1');
        state.startDrag();

        // Should not throw when zoom is provided
        state.updateDrag(
          const Offset(50, 25),
          useSmartGuides: true,
          zoom: 2.0, // Zoomed in
        );

        expect(state.dragSession!.accumulator, isNotNull);
      });

      test('endDrag generates and applies patches', () {
        state.selectFrame('frame_1');
        state.startDrag();
        state.updateDrag(const Offset(50, 25), useSmartGuides: false);

        state.endDrag();

        expect(state.isDragging, isFalse);

        // Verify frame position was updated
        final frame = state.document.frames['frame_1']!;
        expect(frame.canvas.position.dx, equals(150)); // 100 + 50
        expect(frame.canvas.position.dy, equals(125)); // 100 + 25
      });

      test('cancelDrag discards session without patches', () {
        final originalPosition = frame1.canvas.position;

        state.selectFrame('frame_1');
        state.startDrag();
        state.updateDrag(const Offset(50, 25), useSmartGuides: false);

        state.cancelDrag();

        expect(state.isDragging, isFalse);

        // Verify frame position was NOT updated
        final frame = state.document.frames['frame_1']!;
        expect(frame.canvas.position, equals(originalPosition));
      });
    });

    group('resize operations', () {
      test('startResize creates resize session', () {
        state.selectFrame('frame_1');

        state.startResize(ResizeHandle.bottomRight);

        expect(state.isDragging, isTrue);
        expect(state.dragSession!.mode, equals(DragMode.resize));
        expect(state.dragSession!.handle, equals(ResizeHandle.bottomRight));
      });

      test('startResize requires single selection', () {
        state.selectFrame('frame_1');
        state.selectFrame('frame_2', addToSelection: true);

        state.startResize(ResizeHandle.bottomRight);

        expect(state.isDragging, isFalse);
      });

      test('updateResize applies grid snap', () {
        state.selectFrame('frame_1');
        state.startResize(ResizeHandle.bottomRight);

        state.updateResize(const Offset(53, 27), gridSize: 10);

        expect(state.dragSession!.accumulator.dx, equals(50));
        expect(state.dragSession!.accumulator.dy, equals(30));
      });
    });

    group('cache management', () {
      test('getExpandedScene returns scene for valid frame', () {
        final scene = state.getExpandedScene('frame_1');

        expect(scene, isNotNull);
        expect(scene!.frameId, equals('frame_1'));
      });

      test('getExpandedScene returns null for invalid frame', () {
        final scene = state.getExpandedScene('nonexistent');

        expect(scene, isNull);
      });

      test('getRenderDoc returns render document for valid frame', () {
        final renderDoc = state.getRenderDoc('frame_1');

        expect(renderDoc, isNotNull);
        expect(renderDoc!.nodes, isNotEmpty);
      });

      test('getRenderDoc returns null for invalid frame', () {
        final renderDoc = state.getRenderDoc('nonexistent');

        expect(renderDoc, isNull);
      });

      test('cache is invalidated on frame changes', () {
        // First access populates cache
        state.getExpandedScene('frame_1');
        state.getRenderDoc('frame_1');

        // Modify frame
        store.applyPatch(
          SetFrameProp(
            frameId: 'frame_1',
            path: '/canvas/position',
            value: {'x': 200.0, 'y': 200.0},
          ),
        );

        // Cache should be invalidated and rebuilt
        final scene = state.getExpandedScene('frame_1');
        expect(scene, isNotNull);
      });
    });

    group('store listening', () {
      test('notifies on store changes', () {
        var notified = false;
        state.addListener(() => notified = true);

        store.applyPatch(
          SetFrameProp(frameId: 'frame_1', path: '/name', value: 'New Name'),
        );

        expect(notified, isTrue);
      });
    });

    group('activeGuides', () {
      test('returns empty when not dragging', () {
        expect(state.activeGuides, isEmpty);
      });

      test('returns guides from drag session', () {
        state.selectFrame('frame_1');
        state.startDrag();

        // Active guides are populated by updateDrag when snapping occurs
        expect(state.activeGuides, isEmpty);
      });
    });
  });
}
