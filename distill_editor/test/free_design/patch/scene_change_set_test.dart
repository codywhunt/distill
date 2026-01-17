import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('SceneChangeSet', () {
    // Context for fromPatch calls
    late Map<String, String> parentIndex;
    late Map<String, Node> nodes;

    setUp(() {
      // Simple tree: root -> child
      nodes = {
        'n_root': const Node(
          id: 'n_root',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['n_child'],
        ),
        'n_child': const Node(
          id: 'n_child',
          type: NodeType.text,
          props: TextProps(text: 'Hello'),
        ),
      };
      parentIndex = {'n_child': 'n_root'};
    });

    test('empty change set has no dirty nodes', () {
      const changes = SceneChangeSet();

      expect(changes.geometryDirty, isEmpty);
      expect(changes.compilationDirty, isEmpty);
      expect(changes.frameDirty, isEmpty);
      expect(changes.isEmpty, true);
    });

    test('fromPatch categorizes SetProp position changes as geometry', () {
      const op = SetProp(
        id: 'n_child',
        path: '/layout/position/x',
        value: 100.0,
      );

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.geometryDirty, contains('n_child'));
      expect(changes.compilationDirty, isEmpty);
    });

    test('fromPatch categorizes SetProp size changes as compilation', () {
      const op = SetProp(
        id: 'n_child',
        path: '/layout/size/width',
        value: 200.0,
      );

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      // Size changes need recompilation because they affect auto-layout
      expect(changes.compilationDirty, contains('n_child'));
      expect(changes.geometryDirty, isEmpty);
    });

    test('fromPatch categorizes SetProp style changes as compilation', () {
      const op = SetProp(
        id: 'n_child',
        path: '/style/fill',
        value: {
          'type': 'solid',
          'color': {'hex': '#FF0000'},
        },
      );

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      // Non-geometry paths go to compilation
      expect(changes.compilationDirty, contains('n_child'));
    });

    test('fromPatch categorizes SetProp props changes as compilation', () {
      const op = SetProp(id: 'n_child', path: '/props/text', value: 'New text');

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.compilationDirty, contains('n_child'));
    });

    test('fromPatch includes ancestors for compilation changes', () {
      const op = SetProp(id: 'n_child', path: '/props/text', value: 'New text');

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      // Should include both the node and its parent
      expect(changes.compilationDirty, contains('n_child'));
      expect(changes.compilationDirty, contains('n_root'));
    });

    test('fromPatch categorizes InsertNode as compilation', () {
      const op = InsertNode(
        Node(id: 'n_new', type: NodeType.container, props: ContainerProps()),
      );

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.compilationDirty, contains('n_new'));
    });

    test('fromPatch categorizes DeleteNode as empty', () {
      const op = DeleteNode('n_child');

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      // DeleteNode returns empty change set (already detached)
      expect(changes.isEmpty, true);
    });

    test('fromPatch categorizes AttachChild as compilation', () {
      const op = AttachChild(parentId: 'n_root', childId: 'n_new');

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.compilationDirty, contains('n_root'));
    });

    test('fromPatch categorizes DetachChild as compilation', () {
      const op = DetachChild(parentId: 'n_root', childId: 'n_child');

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.compilationDirty, contains('n_root'));
    });

    test('fromPatch categorizes MoveNode as compilation', () {
      // Add a second container
      nodes['n_container2'] = const Node(
        id: 'n_container2',
        type: NodeType.container,
        props: ContainerProps(),
      );

      const op = MoveNode(id: 'n_child', newParentId: 'n_container2');

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.compilationDirty, contains('n_child'));
      expect(changes.compilationDirty, contains('n_container2'));
    });

    test('fromPatch categorizes ReplaceNode as compilation', () {
      const op = ReplaceNode(
        id: 'n_child',
        node: Node(
          id: 'n_child',
          type: NodeType.icon,
          props: IconProps(icon: 'home'),
        ),
      );

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.compilationDirty, contains('n_child'));
    });

    test('fromPatch categorizes SetFrameProp canvas position as frame', () {
      const op = SetFrameProp(
        frameId: 'f_test',
        path: '/canvas/position/x',
        value: 100.0,
      );

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.frameDirty, contains('f_test'));
    });

    test('fromPatch categorizes InsertFrame as frame', () {
      final now = DateTime.now();
      final op = InsertFrame(
        Frame(
          id: 'f_new',
          name: 'New Frame',
          rootNodeId: 'n_root',
          canvas: const CanvasPlacement(
            position: Offset.zero,
            size: Size(375, 812),
          ),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.frameDirty, contains('f_new'));
    });

    test('fromPatch categorizes RemoveFrame as frame', () {
      const op = RemoveFrame('f_removed');

      final changes = SceneChangeSet.fromPatch(op, parentIndex, nodes);

      expect(changes.frameDirty, contains('f_removed'));
    });

    test('merge combines two change sets', () {
      const changes1 = SceneChangeSet(
        geometryDirty: {'n_a', 'n_b'},
        compilationDirty: {'n_c'},
      );
      const changes2 = SceneChangeSet(
        geometryDirty: {'n_b', 'n_d'},
        frameDirty: {'f_1'},
      );

      final merged = changes1.merge(changes2);

      expect(merged.geometryDirty, containsAll(['n_a', 'n_b', 'n_d']));
      expect(merged.compilationDirty, contains('n_c'));
      expect(merged.frameDirty, contains('f_1'));
    });

    test('isEmpty returns true for empty set', () {
      const changes = SceneChangeSet();
      expect(changes.isEmpty, true);
    });

    test('isEmpty returns false for non-empty set', () {
      const changes = SceneChangeSet(geometryDirty: {'n_a'});
      expect(changes.isEmpty, false);
    });

    test('isNotEmpty returns correct value', () {
      const empty = SceneChangeSet();
      const nonEmpty = SceneChangeSet(geometryDirty: {'n_a'});

      expect(empty.isNotEmpty, false);
      expect(nonEmpty.isNotEmpty, true);
    });
  });
}
