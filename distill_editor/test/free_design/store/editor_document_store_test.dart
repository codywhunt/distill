import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('EditorDocumentStore', () {
    late EditorDocumentStore store;

    setUp(() {
      store = EditorDocumentStore.empty();
    });

    tearDown(() {
      store.dispose();
    });

    test('empty store has no frames or nodes', () {
      expect(store.document.frames, isEmpty);
      expect(store.document.nodes, isEmpty);
    });

    test('applyPatch modifies document', () {
      const node = Node(
        id: 'n_test',
        type: NodeType.container,
        props: ContainerProps(),
      );

      store.applyPatch(InsertNode(node));

      expect(store.document.nodes.containsKey('n_test'), true);
    });

    test('applyPatch notifies listeners', () {
      var notified = false;
      store.addListener(() => notified = true);

      store.applyPatch(
        const InsertNode(
          Node(id: 'n_test', type: NodeType.container, props: ContainerProps()),
        ),
      );

      expect(notified, true);
    });

    test('applyPatches applies multiple patches', () {
      final patches = [
        const InsertNode(
          Node(id: 'n_1', type: NodeType.container, props: ContainerProps()),
        ),
        const InsertNode(
          Node(
            id: 'n_2',
            type: NodeType.text,
            props: TextProps(text: 'Hello'),
          ),
        ),
      ];

      store.applyPatches(patches);

      expect(store.document.nodes.containsKey('n_1'), true);
      expect(store.document.nodes.containsKey('n_2'), true);
    });

    test('parentIndex is updated after patch', () {
      store.applyPatches([
        const InsertNode(
          Node(id: 'n_root', type: NodeType.container, props: ContainerProps()),
        ),
        const InsertNode(
          Node(
            id: 'n_child',
            type: NodeType.text,
            props: TextProps(text: 'Hello'),
          ),
        ),
        const AttachChild(parentId: 'n_root', childId: 'n_child'),
      ]);

      expect(store.parentIndex['n_child'], 'n_root');
    });

    test('pendingChanges tracks changes', () {
      store.applyPatch(
        const InsertNode(
          Node(id: 'n_test', type: NodeType.container, props: ContainerProps()),
        ),
      );

      expect(store.pendingChanges.compilationDirty, contains('n_test'));
    });

    test('geometry changes are tracked', () {
      store.applyPatch(
        const InsertNode(
          Node(id: 'n_test', type: NodeType.container, props: ContainerProps()),
        ),
      );

      // Clear changes from insert to test geometry tracking separately
      store.clearChanges();

      store.applyPatch(
        const SetProp(id: 'n_test', path: '/layout/position/x', value: 100.0),
      );

      expect(store.pendingChanges.geometryDirty, contains('n_test'));
    });

    test('frame operations work correctly', () {
      final now = DateTime.now();
      final frame = Frame(
        id: 'f_main',
        name: 'Main Frame',
        rootNodeId: 'n_root',
        canvas: const CanvasPlacement(
          position: Offset.zero,
          size: Size(375, 812),
        ),
        createdAt: now,
        updatedAt: now,
      );

      store.applyPatch(InsertFrame(frame));

      expect(store.document.frames.containsKey('f_main'), true);
      expect(store.pendingChanges.frameDirty, contains('f_main'));
    });

    test('setDocument updates entire document', () {
      final newDoc = EditorDocument.empty(documentId: 'new_doc').withNode(
        const Node(
          id: 'n_existing',
          type: NodeType.container,
          props: ContainerProps(),
        ),
      );

      store.setDocument(newDoc);

      expect(store.document.documentId, 'new_doc');
      expect(store.document.nodes.containsKey('n_existing'), true);
    });

    test('setDocument notifies listeners', () {
      var notified = false;
      store.addListener(() => notified = true);

      store.setDocument(EditorDocument.empty(documentId: 'new_doc'));

      expect(notified, true);
    });

    test('multiple consecutive patches accumulate changes', () {
      store.applyPatches([
        const InsertNode(
          Node(id: 'n_root', type: NodeType.container, props: ContainerProps()),
        ),
        const InsertNode(
          Node(
            id: 'n_child',
            type: NodeType.text,
            props: TextProps(text: 'Hello'),
          ),
        ),
        const AttachChild(parentId: 'n_root', childId: 'n_child'),
      ]);

      // Both nodes should be in compilation dirty
      expect(store.pendingChanges.compilationDirty, contains('n_root'));
      expect(store.pendingChanges.compilationDirty, contains('n_child'));
    });

    test('clearChanges resets pending changes', () {
      store.applyPatch(
        const InsertNode(
          Node(id: 'n_test', type: NodeType.container, props: ContainerProps()),
        ),
      );

      expect(store.pendingChanges.isEmpty, false);

      store.clearChanges();

      expect(store.pendingChanges.isEmpty, true);
    });

    test('getParent returns correct parent', () {
      store.applyPatches([
        const InsertNode(
          Node(id: 'n_root', type: NodeType.container, props: ContainerProps()),
        ),
        const InsertNode(
          Node(
            id: 'n_child',
            type: NodeType.text,
            props: TextProps(text: 'Hello'),
          ),
        ),
        const AttachChild(parentId: 'n_root', childId: 'n_child'),
      ]);

      expect(store.getParent('n_child'), 'n_root');
      expect(store.getParent('n_root'), isNull);
    });

    test('getAncestors returns ancestors in order', () {
      store.applyPatches([
        const InsertNode(
          Node(id: 'n_root', type: NodeType.container, props: ContainerProps()),
        ),
        const InsertNode(
          Node(
            id: 'n_middle',
            type: NodeType.container,
            props: ContainerProps(),
          ),
        ),
        const InsertNode(
          Node(
            id: 'n_child',
            type: NodeType.text,
            props: TextProps(text: 'Hello'),
          ),
        ),
        const AttachChild(parentId: 'n_root', childId: 'n_middle'),
        const AttachChild(parentId: 'n_middle', childId: 'n_child'),
      ]);

      final ancestors = store.getAncestors('n_child');

      expect(ancestors, ['n_middle', 'n_root']);
    });

    test('getDescendants returns all descendants', () {
      store.applyPatches([
        const InsertNode(
          Node(id: 'n_root', type: NodeType.container, props: ContainerProps()),
        ),
        const InsertNode(
          Node(
            id: 'n_child1',
            type: NodeType.text,
            props: TextProps(text: 'Child 1'),
          ),
        ),
        const InsertNode(
          Node(
            id: 'n_child2',
            type: NodeType.text,
            props: TextProps(text: 'Child 2'),
          ),
        ),
        const AttachChild(parentId: 'n_root', childId: 'n_child1'),
        const AttachChild(parentId: 'n_root', childId: 'n_child2'),
      ]);

      final descendants = store.getDescendants('n_root');

      expect(descendants, containsAll(['n_child1', 'n_child2']));
      expect(descendants, isNot(contains('n_root')));
    });
  });

  group('EditorDocumentStoreExtensions', () {
    late EditorDocumentStore store;

    setUp(() {
      store = EditorDocumentStore.empty();
      store.applyPatch(
        const InsertNode(
          Node(id: 'n_root', type: NodeType.container, props: ContainerProps()),
        ),
      );
    });

    tearDown(() {
      store.dispose();
    });

    test('addNode inserts and attaches', () {
      const node = Node(
        id: 'n_new',
        type: NodeType.text,
        props: TextProps(text: 'Hello'),
      );

      store.addNode(node, parentId: 'n_root');

      expect(store.document.nodes.containsKey('n_new'), true);
      expect(store.document.nodes['n_root']?.childIds, contains('n_new'));
    });

    test('removeNode detaches and deletes', () {
      store.addNode(
        const Node(
          id: 'n_child',
          type: NodeType.text,
          props: TextProps(text: 'Hello'),
        ),
        parentId: 'n_root',
      );

      store.removeNode('n_child');

      expect(store.document.nodes.containsKey('n_child'), false);
      expect(
        store.document.nodes['n_root']?.childIds,
        isNot(contains('n_child')),
      );
    });

    test('updateNodeProp updates property', () {
      store.updateNodeProp('n_root', '/style/opacity', 0.5);

      expect(store.document.nodes['n_root']?.style.opacity, 0.5);
    });
  });
}
