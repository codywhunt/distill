import 'dart:ui';

import 'package:distill_editor/src/free_design/free_design.dart';
import 'package:distill_editor/src/free_design/store/editor_document_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('executePaste', () {
    late EditorDocumentStore store;
    late String frameId;
    late String rootNodeId;

    setUp(() {
      store = EditorDocumentStore.empty();

      // Create a frame with a root node
      store.createEmptyFrame(
        position: const Offset(0, 0),
        size: const Size(375, 812),
        name: 'Test Frame',
      );

      frameId = store.document.frames.keys.first;
      rootNodeId = store.document.frames[frameId]!.rootNodeId;
    });

    Node createTestNode(String id, {List<String> childIds = const []}) {
      return Node(
        id: id,
        name: 'Test $id',
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          position: const PositionModeAbsolute(x: 100, y: 200),
        ),
        childIds: childIds,
      );
    }

    test('inserts single node into document', () {
      final node = createTestNode('paste_1');

      store.executePaste(
        nodes: [node],
        rootIds: ['paste_1'],
        targetParentId: rootNodeId,
      );

      expect(store.document.nodes.containsKey('paste_1'), isTrue);
      expect(store.document.nodes['paste_1']!.name, 'Test paste_1');
    });

    test('attaches root to target parent', () {
      final node = createTestNode('paste_1');

      store.executePaste(
        nodes: [node],
        rootIds: ['paste_1'],
        targetParentId: rootNodeId,
      );

      final parent = store.document.nodes[rootNodeId]!;
      expect(parent.childIds, contains('paste_1'));
    });

    test('returns new root IDs', () {
      final node1 = createTestNode('paste_1');
      final node2 = createTestNode('paste_2');

      final result = store.executePaste(
        nodes: [node1, node2],
        rootIds: ['paste_1', 'paste_2'],
        targetParentId: rootNodeId,
      );

      expect(result, ['paste_1', 'paste_2']);
    });

    test('inserts all nodes in subtree', () {
      final parent = createTestNode('paste_parent', childIds: ['paste_child']);
      final child = createTestNode('paste_child');

      store.executePaste(
        nodes: [parent, child],
        rootIds: ['paste_parent'],
        targetParentId: rootNodeId,
      );

      expect(store.document.nodes.containsKey('paste_parent'), isTrue);
      expect(store.document.nodes.containsKey('paste_child'), isTrue);
      expect(
        store.document.nodes['paste_parent']!.childIds,
        contains('paste_child'),
      );
    });

    test('attaches multiple roots to parent', () {
      final node1 = createTestNode('paste_1');
      final node2 = createTestNode('paste_2');

      store.executePaste(
        nodes: [node1, node2],
        rootIds: ['paste_1', 'paste_2'],
        targetParentId: rootNodeId,
      );

      final parent = store.document.nodes[rootNodeId]!;
      expect(parent.childIds, contains('paste_1'));
      expect(parent.childIds, contains('paste_2'));
    });

    test('attaches at specific index', () {
      // Add existing child first
      final existing = createTestNode('existing');
      store.addNode(existing, parentId: rootNodeId);

      final newNode = createTestNode('paste_1');

      store.executePaste(
        nodes: [newNode],
        rootIds: ['paste_1'],
        targetParentId: rootNodeId,
        index: 0,
      );

      final parent = store.document.nodes[rootNodeId]!;
      expect(parent.childIds.first, 'paste_1');
      expect(parent.childIds.last, 'existing');
    });

    test('uses default label "Paste"', () {
      final node = createTestNode('paste_1');

      store.executePaste(
        nodes: [node],
        rootIds: ['paste_1'],
        targetParentId: rootNodeId,
      );

      // Undo stack should have entry with default label
      expect(store.canUndo, isTrue);
    });

    test('uses custom label when provided', () {
      final node = createTestNode('paste_1');

      store.executePaste(
        nodes: [node],
        rootIds: ['paste_1'],
        targetParentId: rootNodeId,
        label: 'Duplicate',
      );

      expect(store.canUndo, isTrue);
    });

    group('undo', () {
      test('undo removes pasted nodes', () {
        final node = createTestNode('paste_1');

        store.executePaste(
          nodes: [node],
          rootIds: ['paste_1'],
          targetParentId: rootNodeId,
        );

        expect(store.document.nodes.containsKey('paste_1'), isTrue);

        store.undo();

        expect(store.document.nodes.containsKey('paste_1'), isFalse);
      });

      test('undo detaches from parent', () {
        final node = createTestNode('paste_1');

        store.executePaste(
          nodes: [node],
          rootIds: ['paste_1'],
          targetParentId: rootNodeId,
        );

        store.undo();

        final parent = store.document.nodes[rootNodeId]!;
        expect(parent.childIds, isNot(contains('paste_1')));
      });

      test('undo removes entire subtree', () {
        final parent = createTestNode('paste_parent', childIds: ['paste_child']);
        final child = createTestNode('paste_child');

        store.executePaste(
          nodes: [parent, child],
          rootIds: ['paste_parent'],
          targetParentId: rootNodeId,
        );

        store.undo();

        expect(store.document.nodes.containsKey('paste_parent'), isFalse);
        expect(store.document.nodes.containsKey('paste_child'), isFalse);
      });

      test('redo restores pasted nodes', () {
        final node = createTestNode('paste_1');

        store.executePaste(
          nodes: [node],
          rootIds: ['paste_1'],
          targetParentId: rootNodeId,
        );

        store.undo();
        expect(store.document.nodes.containsKey('paste_1'), isFalse);

        store.redo();
        expect(store.document.nodes.containsKey('paste_1'), isTrue);
      });
    });

    group('parent index', () {
      test('updates parent index after paste', () {
        final node = createTestNode('paste_1');

        store.executePaste(
          nodes: [node],
          rootIds: ['paste_1'],
          targetParentId: rootNodeId,
        );

        expect(store.getParent('paste_1'), rootNodeId);
      });

      test('updates parent index for subtree', () {
        final parent = createTestNode('paste_parent', childIds: ['paste_child']);
        final child = createTestNode('paste_child');

        store.executePaste(
          nodes: [parent, child],
          rootIds: ['paste_parent'],
          targetParentId: rootNodeId,
        );

        expect(store.getParent('paste_parent'), rootNodeId);
        expect(store.getParent('paste_child'), 'paste_parent');
      });
    });

    group('edge cases', () {
      test('empty nodes list does nothing', () {
        final initialNodeCount = store.document.nodes.length;

        store.executePaste(
          nodes: [],
          rootIds: [],
          targetParentId: rootNodeId,
        );

        expect(store.document.nodes.length, initialNodeCount);
      });

      test('nodes without roots are inserted but not attached', () {
        final node = createTestNode('paste_1');

        store.executePaste(
          nodes: [node],
          rootIds: [], // No roots specified
          targetParentId: rootNodeId,
        );

        // Node is inserted
        expect(store.document.nodes.containsKey('paste_1'), isTrue);
        // But not attached to parent
        final parent = store.document.nodes[rootNodeId]!;
        expect(parent.childIds, isNot(contains('paste_1')));
      });

      test('multiple paste operations create separate undo entries', () {
        final node1 = createTestNode('paste_1');
        final node2 = createTestNode('paste_2');

        store.executePaste(
          nodes: [node1],
          rootIds: ['paste_1'],
          targetParentId: rootNodeId,
        );

        // Wait to ensure different group IDs
        store.executePaste(
          nodes: [node2],
          rootIds: ['paste_2'],
          targetParentId: rootNodeId,
        );

        // Both nodes exist
        expect(store.document.nodes.containsKey('paste_1'), isTrue);
        expect(store.document.nodes.containsKey('paste_2'), isTrue);

        // First undo removes second paste
        store.undo();
        expect(store.document.nodes.containsKey('paste_1'), isTrue);
        expect(store.document.nodes.containsKey('paste_2'), isFalse);

        // Second undo removes first paste
        store.undo();
        expect(store.document.nodes.containsKey('paste_1'), isFalse);
      });
    });
  });
}
