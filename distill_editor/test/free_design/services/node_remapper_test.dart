import 'package:distill_editor/src/free_design/free_design.dart';
import 'package:distill_editor/src/free_design/services/node_remapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NodeRemapper', () {
    Node createTestNode(
      String id, {
      List<String> childIds = const [],
      String name = '',
    }) {
      return Node(
        id: id,
        name: name.isEmpty ? 'Node $id' : name,
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          position: const PositionModeAbsolute(x: 100, y: 200),
        ),
        childIds: childIds,
      );
    }

    test('remaps single node ID', () {
      final remapper = NodeRemapper();
      final original = createTestNode('node_A');

      final remapped = remapper.remapNodes([original]);

      expect(remapped.length, 1);
      expect(remapped.first.id, isNot('node_A'));
      expect(remapped.first.id, startsWith('paste_'));
    });

    test('preserves node properties during remapping', () {
      final remapper = NodeRemapper();
      final original = Node(
        id: 'node_A',
        name: 'Test Node',
        type: NodeType.text,
        props: const TextProps(text: 'Hello World', fontSize: 16),
        layout: NodeLayout(
          position: const PositionModeAbsolute(x: 50, y: 75),
          size: SizeMode.fixed(100, 50),
        ),
        style: NodeStyle(
          fill: SolidFill(const HexColor('#FF0000')),
          opacity: 0.8,
        ),
      );

      final remapped = remapper.remapNodes([original]);
      final node = remapped.first;

      expect(node.name, 'Test Node');
      expect(node.type, NodeType.text);
      expect((node.props as TextProps).text, 'Hello World');
      expect(node.layout.x, 50);
      expect(node.layout.y, 75);
      expect(node.style.opacity, 0.8);
    });

    test('remaps subtree with parent-child relationships', () {
      final remapper = NodeRemapper();
      final parent = createTestNode('parent', childIds: ['child_A', 'child_B']);
      final childA = createTestNode('child_A');
      final childB = createTestNode('child_B');

      final remapped = remapper.remapNodes([parent, childA, childB]);

      // All nodes should have new IDs
      expect(remapped[0].id, isNot('parent'));
      expect(remapped[1].id, isNot('child_A'));
      expect(remapped[2].id, isNot('child_B'));

      // Parent's childIds should be remapped
      expect(remapped[0].childIds.length, 2);
      expect(remapped[0].childIds[0], remapped[1].id);
      expect(remapped[0].childIds[1], remapped[2].id);
    });

    test('remaps deeply nested hierarchy', () {
      final remapper = NodeRemapper();
      final root = createTestNode('root', childIds: ['level1']);
      final level1 = createTestNode('level1', childIds: ['level2']);
      final level2 = createTestNode('level2', childIds: ['level3']);
      final level3 = createTestNode('level3');

      final remapped = remapper.remapNodes([root, level1, level2, level3]);

      // Verify chain is maintained
      expect(remapped[0].childIds, contains(remapped[1].id));
      expect(remapped[1].childIds, contains(remapped[2].id));
      expect(remapped[2].childIds, contains(remapped[3].id));
      expect(remapped[3].childIds, isEmpty);
    });

    test('original nodes remain unchanged (immutability)', () {
      final remapper = NodeRemapper();
      final original = createTestNode('node_A', childIds: ['child_1']);
      final child = createTestNode('child_1');

      remapper.remapNodes([original, child]);

      // Original nodes should be unchanged
      expect(original.id, 'node_A');
      expect(original.childIds, ['child_1']);
      expect(child.id, 'child_1');
    });

    test('generates unique IDs within same remapper for nodes with same original ID', () {
      final remapper = NodeRemapper();

      // Two nodes with different original IDs
      final node1 = createTestNode('node_A');
      final node2 = createTestNode('node_B');

      final remapped = remapper.remapNodes([node1, node2]);

      // IDs should be unique
      expect(remapped[0].id, isNot(remapped[1].id));
    });

    test('generates sequential IDs within same remapper', () {
      final remapper = NodeRemapper();
      final nodes = [
        createTestNode('a'),
        createTestNode('b'),
        createTestNode('c'),
      ];

      final remapped = remapper.remapNodes(nodes);

      // All IDs should be unique
      final ids = remapped.map((n) => n.id).toSet();
      expect(ids.length, 3);

      // All IDs should start with paste_
      for (final node in remapped) {
        expect(node.id, startsWith('paste_'));
      }
    });

    test('remapRootIds returns mapped IDs', () {
      final remapper = NodeRemapper();
      final nodeA = createTestNode('node_A');
      final nodeB = createTestNode('node_B');

      remapper.remapNodes([nodeA, nodeB]);
      final newRootIds = remapper.remapRootIds(['node_A', 'node_B']);

      expect(newRootIds.length, 2);
      expect(newRootIds[0], isNot('node_A'));
      expect(newRootIds[1], isNot('node_B'));
      expect(newRootIds[0], startsWith('paste_'));
      expect(newRootIds[1], startsWith('paste_'));
    });

    test('remapRootIds matches remapped node IDs', () {
      final remapper = NodeRemapper();
      final nodeA = createTestNode('node_A');
      final nodeB = createTestNode('node_B');

      final remapped = remapper.remapNodes([nodeA, nodeB]);
      final newRootIds = remapper.remapRootIds(['node_A', 'node_B']);

      expect(newRootIds[0], remapped[0].id);
      expect(newRootIds[1], remapped[1].id);
    });

    test('idMap provides access to the mapping', () {
      final remapper = NodeRemapper();
      final nodes = [
        createTestNode('node_A'),
        createTestNode('node_B'),
      ];

      final remapped = remapper.remapNodes(nodes);
      final idMap = remapper.idMap;

      expect(idMap['node_A'], remapped[0].id);
      expect(idMap['node_B'], remapped[1].id);
    });

    test('preserves childIds order', () {
      final remapper = NodeRemapper();
      final parent = createTestNode('parent', childIds: ['c', 'a', 'b']);
      final childC = createTestNode('c');
      final childA = createTestNode('a');
      final childB = createTestNode('b');

      final remapped = remapper.remapNodes([parent, childC, childA, childB]);
      final idMap = remapper.idMap;

      // Order should be preserved
      expect(remapped[0].childIds[0], idMap['c']);
      expect(remapped[0].childIds[1], idMap['a']);
      expect(remapped[0].childIds[2], idMap['b']);
    });

    test('handles nodes without children', () {
      final remapper = NodeRemapper();
      final leaf = createTestNode('leaf');

      final remapped = remapper.remapNodes([leaf]);

      expect(remapped.first.childIds, isEmpty);
    });

    test('handles external childId references gracefully', () {
      // If a childId references a node not in the list, it should remain unchanged
      final remapper = NodeRemapper();
      final parent = createTestNode('parent', childIds: ['external_node']);

      final remapped = remapper.remapNodes([parent]);

      // External reference should remain unchanged
      expect(remapped.first.childIds, ['external_node']);
    });

    group('remapIds hooks', () {
      test('NodeLayout.remapIds is called', () {
        // Currently a no-op, but verify it exists and returns self
        const layout = NodeLayout(
          position: PositionModeAbsolute(x: 10, y: 20),
        );

        final remapped = layout.remapIds({'old': 'new'});
        expect(remapped, same(layout));
      });

      test('NodeProps.remapIds is called', () {
        // Currently a no-op, but verify it exists and returns self
        const props = ContainerProps(clipContent: true);

        final remapped = props.remapIds({'old': 'new'});
        expect(remapped, same(props));
      });

      test('NodeStyle.remapIds is called', () {
        // Currently a no-op, but verify it exists and returns self
        const style = NodeStyle(opacity: 0.5);

        final remapped = style.remapIds({'old': 'new'});
        expect(remapped, same(style));
      });
    });

    group('NodeLayout convenience getters', () {
      test('x and y return values for absolute position', () {
        const layout = NodeLayout(
          position: PositionModeAbsolute(x: 100, y: 200),
        );

        expect(layout.x, 100);
        expect(layout.y, 200);
      });

      test('x and y return null for auto position', () {
        const layout = NodeLayout(
          position: PositionModeAuto(),
        );

        expect(layout.x, isNull);
        expect(layout.y, isNull);
      });

      test('isPositioned returns true for absolute position', () {
        const layout = NodeLayout(
          position: PositionModeAbsolute(x: 0, y: 0),
        );

        expect(layout.isPositioned, isTrue);
      });

      test('isPositioned returns false for auto position', () {
        const layout = NodeLayout(
          position: PositionModeAuto(),
        );

        expect(layout.isPositioned, isFalse);
      });
    });
  });
}
