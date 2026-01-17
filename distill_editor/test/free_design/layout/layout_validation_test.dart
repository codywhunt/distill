import 'dart:ui';

import 'package:flutter/rendering.dart' hide CrossAxisAlignment;
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  final now = DateTime.now();

  group('LayoutValidation.canUseFill', () {
    late EditorDocumentStore store;

    setUp(() {
      store = EditorDocumentStore.empty();
    });

    tearDown(() {
      store.dispose();
    });

    test('root node can always Fill (frame provides bounds)', () {
      // Create a frame with a root node
      final frame = Frame(
        id: 'frame_1',
        name: 'Test Frame',
        rootNodeId: 'n_root',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      const rootNode = Node(
        id: 'n_root',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(size: SizeMode.hug()),
      );

      store.applyPatches([InsertFrame(frame), const InsertNode(rootNode)]);

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_root',
          axis: Axis.horizontal,
          store: store,
        ),
        isTrue,
      );

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_root',
          axis: Axis.vertical,
          store: store,
        ),
        isTrue,
      );
    });

    test('child can Fill when parent has Fixed size', () {
      _setupWithParentChild(
        store,
        parentLayout: const NodeLayout(
          size: SizeMode(width: AxisSizeFixed(200), height: AxisSizeFixed(200)),
        ),
      );

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.horizontal,
          store: store,
        ),
        isTrue,
      );

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.vertical,
          store: store,
        ),
        isTrue,
      );
    });

    test('child cannot Fill when parent has Hug size', () {
      _setupWithParentChild(
        store,
        parentLayout: const NodeLayout(size: SizeMode.hug()),
      );

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.horizontal,
          store: store,
        ),
        isFalse,
      );

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.vertical,
          store: store,
        ),
        isFalse,
      );
    });

    test('recursive Fill chain: grandchild can Fill through Fill parent', () {
      final now = DateTime.now();
      // Frame -> grandparent (Fixed) -> parent (Fill) -> child
      final frame = Frame(
        id: 'frame_1',
        name: 'Test Frame',
        rootNodeId: 'n_grandparent',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      const grandparent = Node(
        id: 'n_grandparent',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          size: SizeMode(width: AxisSizeFixed(200), height: AxisSizeFixed(200)),
        ),
        childIds: ['n_parent'],
      );

      const parent = Node(
        id: 'n_parent',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(size: SizeMode.fill()),
        childIds: ['n_child'],
      );

      const child = Node(
        id: 'n_child',
        type: NodeType.container,
        props: ContainerProps(),
      );

      store.applyPatches([
        InsertFrame(frame),
        const InsertNode(grandparent),
        const InsertNode(parent),
        const InsertNode(child),
      ]);

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.horizontal,
          store: store,
        ),
        isTrue,
      );

      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.vertical,
          store: store,
        ),
        isTrue,
      );
    });

    test(
      'cross-axis Fill with stretch: child can Fill width in vertical layout with stretch',
      () {
        final now = DateTime.now();
        final frame = Frame(
          id: 'frame_1',
          name: 'Test Frame',
          rootNodeId: 'n_parent',
          canvas: const CanvasPlacement(
            position: Offset.zero,
            size: Size(375, 812),
          ),
          createdAt: now,
          updatedAt: now,
        );

        const parent = Node(
          id: 'n_parent',
          type: NodeType.container,
          props: ContainerProps(),
          layout: NodeLayout(
            size: SizeMode(
              width: AxisSizeHug(), // Normally would block Fill
              height: AxisSizeFixed(400),
            ),
            autoLayout: AutoLayout(
              direction: LayoutDirection.vertical,
              crossAlign: CrossAxisAlignment.stretch, // But stretch enables it
            ),
          ),
          childIds: ['n_child'],
        );

        const child = Node(
          id: 'n_child',
          type: NodeType.container,
          props: ContainerProps(),
        );

        store.applyPatches([
          InsertFrame(frame),
          const InsertNode(parent),
          const InsertNode(child),
        ]);

        // Width is cross-axis (parent is vertical), stretch enables Fill
        expect(
          LayoutValidation.canUseFill(
            nodeId: 'n_child',
            axis: Axis.horizontal,
            store: store,
          ),
          isTrue,
        );

        // Height is main-axis, parent height is Fixed, so allowed
        expect(
          LayoutValidation.canUseFill(
            nodeId: 'n_child',
            axis: Axis.vertical,
            store: store,
          ),
          isTrue,
        );
      },
    );

    test('cross-axis Fill without stretch: child cannot Fill', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'frame_1',
        name: 'Test Frame',
        rootNodeId: 'n_parent',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      const parent = Node(
        id: 'n_parent',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          size: SizeMode(width: AxisSizeHug(), height: AxisSizeFixed(400)),
          autoLayout: AutoLayout(
            direction: LayoutDirection.vertical,
            crossAlign: CrossAxisAlignment.start, // No stretch
          ),
        ),
        childIds: ['n_child'],
      );

      const child = Node(
        id: 'n_child',
        type: NodeType.container,
        props: ContainerProps(),
      );

      store.applyPatches([
        InsertFrame(frame),
        const InsertNode(parent),
        const InsertNode(child),
      ]);

      // Width is cross-axis but no stretch, so cannot Fill
      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.horizontal,
          store: store,
        ),
        isFalse,
      );
    });

    test('horizontal layout with stretch allows height Fill', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'frame_1',
        name: 'Test Frame',
        rootNodeId: 'n_parent',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      const parent = Node(
        id: 'n_parent',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          size: SizeMode(
            width: AxisSizeFixed(400),
            height: AxisSizeHug(), // Normally would block Fill
          ),
          autoLayout: AutoLayout(
            direction: LayoutDirection.horizontal,
            crossAlign: CrossAxisAlignment.stretch, // But stretch enables it
          ),
        ),
        childIds: ['n_child'],
      );

      const child = Node(
        id: 'n_child',
        type: NodeType.container,
        props: ContainerProps(),
      );

      store.applyPatches([
        InsertFrame(frame),
        const InsertNode(parent),
        const InsertNode(child),
      ]);

      // Height is cross-axis (parent is horizontal), stretch enables Fill
      expect(
        LayoutValidation.canUseFill(
          nodeId: 'n_child',
          axis: Axis.vertical,
          store: store,
        ),
        isTrue,
      );
    });
  });

  group('LayoutValidation.getFillDisabledReason', () {
    late EditorDocumentStore store;

    setUp(() {
      store = EditorDocumentStore.empty();
    });

    tearDown(() {
      store.dispose();
    });

    test('returns null when Fill is allowed', () {
      _setupWithParentChild(
        store,
        parentLayout: const NodeLayout(
          size: SizeMode(width: AxisSizeFixed(200), height: AxisSizeFixed(200)),
        ),
      );

      expect(
        LayoutValidation.getFillDisabledReason(
          nodeId: 'n_child',
          axis: Axis.horizontal,
          store: store,
        ),
        isNull,
      );
    });

    test('returns helpful message for Hug parent', () {
      _setupWithParentChild(
        store,
        parentLayout: const NodeLayout(size: SizeMode.hug()),
      );

      final reason = LayoutValidation.getFillDisabledReason(
        nodeId: 'n_child',
        axis: Axis.horizontal,
        store: store,
      );

      expect(reason, isNotNull);
      expect(reason, contains('Hug'));
    });

    test('suggests stretch for cross-axis Fill', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'frame_1',
        name: 'Test Frame',
        rootNodeId: 'n_parent',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      const parent = Node(
        id: 'n_parent',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          size: SizeMode(width: AxisSizeHug(), height: AxisSizeFixed(400)),
          autoLayout: AutoLayout(
            direction: LayoutDirection.vertical,
            crossAlign: CrossAxisAlignment.start, // No stretch
          ),
        ),
        childIds: ['n_child'],
      );

      const child = Node(
        id: 'n_child',
        type: NodeType.container,
        props: ContainerProps(),
      );

      store.applyPatches([
        InsertFrame(frame),
        const InsertNode(parent),
        const InsertNode(child),
      ]);

      final reason = LayoutValidation.getFillDisabledReason(
        nodeId: 'n_child',
        axis: Axis.horizontal, // Cross-axis
        store: store,
      );

      expect(reason, isNotNull);
      expect(reason, contains('Stretch'));
    });
  });
}

/// Helper to set up a simple parent-child relationship.
void _setupWithParentChild(
  EditorDocumentStore store, {
  required NodeLayout parentLayout,
}) {
  final now = DateTime.now();
  final frame = Frame(
    id: 'frame_1',
    name: 'Test Frame',
    rootNodeId: 'n_parent',
    canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
    createdAt: now,
    updatedAt: now,
  );

  final parent = Node(
    id: 'n_parent',
    type: NodeType.container,
    props: const ContainerProps(),
    layout: parentLayout,
    childIds: const ['n_child'],
  );

  const child = Node(
    id: 'n_child',
    type: NodeType.container,
    props: ContainerProps(),
  );

  store.applyPatches([
    InsertFrame(frame),
    InsertNode(parent),
    const InsertNode(child),
  ]);
}
