import 'dart:ui';

import 'package:distill_editor/src/free_design/free_design.dart';
import 'package:distill_editor/src/free_design/services/selection_roots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getTopLevelRoots', () {
    Node createNode(String id, {double x = 0, double y = 0, List<String> childIds = const []}) {
      return Node(
        id: id,
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          position: PositionModeAbsolute(x: x, y: y),
        ),
        childIds: childIds,
      );
    }

    Frame createFrame(String id, String rootNodeId) {
      return Frame(
        id: id,
        name: 'Frame $id',
        rootNodeId: rootNodeId,
        canvas: const CanvasPlacement(
          position: Offset(0, 0),
          size: Size(400, 300),
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('single node returns single root', () {
      final nodes = {'node_A': createNode('node_A')};
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_1', expandedId: 'node_A', patchTarget: 'node_A'),
      };

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: {},
        frames: {},
        nodes: nodes,
      );

      expect(roots, ['node_A']);
    });

    test('parent and child selected returns only parent', () {
      final nodes = {
        'parent': createNode('parent', childIds: ['child']),
        'child': createNode('child'),
      };
      final parentIndex = {'child': 'parent'};
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'parent', patchTarget: 'parent'),
        const NodeTarget(frameId: 'f1', expandedId: 'child', patchTarget: 'child'),
      };

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: parentIndex,
        frames: {},
        nodes: nodes,
      );

      expect(roots, ['parent']);
    });

    test('multiple siblings all returned', () {
      final nodes = {
        'parent': createNode('parent', childIds: ['child_A', 'child_B', 'child_C']),
        'child_A': createNode('child_A', y: 0),
        'child_B': createNode('child_B', y: 10),
        'child_C': createNode('child_C', y: 20),
      };
      final parentIndex = {
        'child_A': 'parent',
        'child_B': 'parent',
        'child_C': 'parent',
      };
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'child_A', patchTarget: 'child_A'),
        const NodeTarget(frameId: 'f1', expandedId: 'child_B', patchTarget: 'child_B'),
        const NodeTarget(frameId: 'f1', expandedId: 'child_C', patchTarget: 'child_C'),
      };

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: parentIndex,
        frames: {},
        nodes: nodes,
      );

      expect(roots.length, 3);
      expect(roots, containsAll(['child_A', 'child_B', 'child_C']));
    });

    test('deep nesting A->B->C with A and B selected returns only A', () {
      // When both A and B are selected, but B's parent (A) is also selected,
      // only A should be returned as a root
      final nodes = {
        'A': createNode('A', childIds: ['B']),
        'B': createNode('B', childIds: ['C']),
        'C': createNode('C'),
      };
      final parentIndex = {'B': 'A', 'C': 'B'};
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'A', patchTarget: 'A'),
        const NodeTarget(frameId: 'f1', expandedId: 'B', patchTarget: 'B'),
      };

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: parentIndex,
        frames: {},
        nodes: nodes,
      );

      expect(roots, ['A']);
    });

    test('deep nesting A->B->C with A and C selected returns both (C parent not selected)', () {
      // When A and C are selected but B is not, both are roots because
      // C's immediate parent (B) is not in the selection
      final nodes = {
        'A': createNode('A', childIds: ['B']),
        'B': createNode('B', childIds: ['C']),
        'C': createNode('C'),
      };
      final parentIndex = {'B': 'A', 'C': 'B'};
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'A', patchTarget: 'A'),
        const NodeTarget(frameId: 'f1', expandedId: 'C', patchTarget: 'C'),
      };

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: parentIndex,
        frames: {},
        nodes: nodes,
      );

      // Both A and C are roots - C's parent (B) is not selected
      expect(roots.length, 2);
      expect(roots, containsAll(['A', 'C']));
    });

    test('FrameTarget returns frame rootNodeId', () {
      final nodes = {'root_node': createNode('root_node')};
      final frames = {'frame_1': createFrame('frame_1', 'root_node')};
      final selection = <DragTarget>{const FrameTarget('frame_1')};

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: {},
        frames: frames,
        nodes: nodes,
      );

      expect(roots, ['root_node']);
    });

    test('mixed FrameTarget and NodeTarget', () {
      final nodes = {
        'frame_root': createNode('frame_root', y: 100),
        'other_node': createNode('other_node', y: 0),
      };
      final frames = {'frame_1': createFrame('frame_1', 'frame_root')};
      final selection = <DragTarget>{
        const FrameTarget('frame_1'),
        const NodeTarget(frameId: 'f2', expandedId: 'other_node', patchTarget: 'other_node'),
      };

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: {},
        frames: frames,
        nodes: nodes,
      );

      // Both should be returned, sorted by y position
      expect(roots, ['other_node', 'frame_root']);
    });

    test('ignores nodes with null patchTarget', () {
      final nodes = {'node_A': createNode('node_A')};
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'inst::node_A', patchTarget: null),
      };

      final roots = getTopLevelRoots(
        selection: selection,
        parentIndex: {},
        frames: {},
        nodes: nodes,
      );

      expect(roots, isEmpty);
    });

    group('deterministic ordering', () {
      test('sorts by y position first', () {
        final nodes = {
          'top': createNode('top', x: 100, y: 0),
          'middle': createNode('middle', x: 0, y: 50),
          'bottom': createNode('bottom', x: 50, y: 100),
        };
        final selection = <DragTarget>{
          const NodeTarget(frameId: 'f1', expandedId: 'bottom', patchTarget: 'bottom'),
          const NodeTarget(frameId: 'f1', expandedId: 'top', patchTarget: 'top'),
          const NodeTarget(frameId: 'f1', expandedId: 'middle', patchTarget: 'middle'),
        };

        final roots = getTopLevelRoots(
          selection: selection,
          parentIndex: {},
          frames: {},
          nodes: nodes,
        );

        expect(roots, ['top', 'middle', 'bottom']);
      });

      test('sorts by x position when y is equal', () {
        final nodes = {
          'left': createNode('left', x: 0, y: 50),
          'right': createNode('right', x: 100, y: 50),
          'center': createNode('center', x: 50, y: 50),
        };
        final selection = <DragTarget>{
          const NodeTarget(frameId: 'f1', expandedId: 'right', patchTarget: 'right'),
          const NodeTarget(frameId: 'f1', expandedId: 'left', patchTarget: 'left'),
          const NodeTarget(frameId: 'f1', expandedId: 'center', patchTarget: 'center'),
        };

        final roots = getTopLevelRoots(
          selection: selection,
          parentIndex: {},
          frames: {},
          nodes: nodes,
        );

        expect(roots, ['left', 'center', 'right']);
      });

      test('falls back to id when positions are equal', () {
        final nodes = {
          'z_node': createNode('z_node', x: 50, y: 50),
          'a_node': createNode('a_node', x: 50, y: 50),
          'm_node': createNode('m_node', x: 50, y: 50),
        };
        final selection = <DragTarget>{
          const NodeTarget(frameId: 'f1', expandedId: 'z_node', patchTarget: 'z_node'),
          const NodeTarget(frameId: 'f1', expandedId: 'a_node', patchTarget: 'a_node'),
          const NodeTarget(frameId: 'f1', expandedId: 'm_node', patchTarget: 'm_node'),
        };

        final roots = getTopLevelRoots(
          selection: selection,
          parentIndex: {},
          frames: {},
          nodes: nodes,
        );

        expect(roots, ['a_node', 'm_node', 'z_node']);
      });
    });
  });

  group('computeAnchor', () {
    Node createNode(String id, {double x = 0, double y = 0}) {
      return Node(
        id: id,
        type: NodeType.container,
        props: ContainerProps(),
        layout: NodeLayout(
          position: PositionModeAbsolute(x: x, y: y),
        ),
      );
    }

    test('returns single node position', () {
      final nodes = {'node_A': createNode('node_A', x: 100, y: 200)};

      final anchor = computeAnchor(['node_A'], nodes);

      expect(anchor, const Offset(100, 200));
    });

    test('returns min x and y for multiple nodes', () {
      final nodes = {
        'node_A': createNode('node_A', x: 100, y: 200),
        'node_B': createNode('node_B', x: 50, y: 300),
        'node_C': createNode('node_C', x: 150, y: 100),
      };

      final anchor = computeAnchor(['node_A', 'node_B', 'node_C'], nodes);

      expect(anchor, const Offset(50, 100));
    });

    test('returns zero for empty rootIds', () {
      final anchor = computeAnchor([], {});

      expect(anchor, Offset.zero);
    });

    test('handles nodes with auto position (null x/y)', () {
      final nodes = {
        'auto_node': Node(
          id: 'auto_node',
          type: NodeType.container,
          props: ContainerProps(),
          layout: const NodeLayout(position: PositionModeAuto()),
        ),
      };

      final anchor = computeAnchor(['auto_node'], nodes);

      // Auto position defaults to 0,0
      expect(anchor, Offset.zero);
    });
  });

  group('collectSubtree', () {
    Node createNode(String id, {List<String> childIds = const []}) {
      return Node(
        id: id,
        type: NodeType.container,
        props: ContainerProps(),
        childIds: childIds,
      );
    }

    test('collects single node', () {
      final nodes = {'node_A': createNode('node_A')};

      final subtree = collectSubtree(['node_A'], nodes);

      expect(subtree.length, 1);
      expect(subtree.first.id, 'node_A');
    });

    test('collects node with children in parent-first order', () {
      final nodes = {
        'parent': createNode('parent', childIds: ['child_A', 'child_B']),
        'child_A': createNode('child_A'),
        'child_B': createNode('child_B'),
      };

      final subtree = collectSubtree(['parent'], nodes);

      expect(subtree.length, 3);
      expect(subtree[0].id, 'parent');
      expect(subtree[1].id, 'child_A');
      expect(subtree[2].id, 'child_B');
    });

    test('collects deeply nested hierarchy', () {
      final nodes = {
        'root': createNode('root', childIds: ['level1']),
        'level1': createNode('level1', childIds: ['level2']),
        'level2': createNode('level2', childIds: ['level3']),
        'level3': createNode('level3'),
      };

      final subtree = collectSubtree(['root'], nodes);

      expect(subtree.length, 4);
      expect(subtree.map((n) => n.id).toList(), ['root', 'level1', 'level2', 'level3']);
    });

    test('collects multiple roots', () {
      final nodes = {
        'root_A': createNode('root_A', childIds: ['child_A']),
        'child_A': createNode('child_A'),
        'root_B': createNode('root_B'),
      };

      final subtree = collectSubtree(['root_A', 'root_B'], nodes);

      expect(subtree.length, 3);
      expect(subtree.map((n) => n.id).toSet(), {'root_A', 'child_A', 'root_B'});
    });

    test('handles missing nodes gracefully', () {
      final nodes = {'node_A': createNode('node_A', childIds: ['missing_child'])};

      final subtree = collectSubtree(['node_A'], nodes);

      // Should only include existing nodes
      expect(subtree.length, 1);
      expect(subtree.first.id, 'node_A');
    });

    test('avoids duplicate collection', () {
      // Diamond pattern: root -> [A, B], A -> C, B -> C
      final nodes = {
        'root': createNode('root', childIds: ['A', 'B']),
        'A': createNode('A', childIds: ['C']),
        'B': createNode('B', childIds: ['C']),
        'C': createNode('C'),
      };

      final subtree = collectSubtree(['root'], nodes);

      // C should only appear once
      expect(subtree.where((n) => n.id == 'C').length, 1);
    });
  });

  group('canCopy', () {
    test('returns true for node with patchTarget', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'node_A', patchTarget: 'node_A'),
      };

      expect(canCopy(selection), isTrue);
    });

    test('returns false for node without patchTarget', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'inst::node_A', patchTarget: null),
      };

      expect(canCopy(selection), isFalse);
    });

    test('returns true for FrameTarget', () {
      final selection = <DragTarget>{const FrameTarget('frame_1')};

      expect(canCopy(selection), isTrue);
    });

    test('returns true for mixed selection with at least one copyable', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'f1', expandedId: 'inst::node_A', patchTarget: null),
        const NodeTarget(frameId: 'f1', expandedId: 'node_B', patchTarget: 'node_B'),
      };

      expect(canCopy(selection), isTrue);
    });

    test('returns false for empty selection', () {
      expect(canCopy({}), isFalse);
    });
  });

  group('determineTargetFrame', () {
    test('returns single selected node frame', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_1', patchTarget: 'node_1'),
      };

      final target = determineTargetFrame(
        selection: selection,
        focusedFrameId: 'frame_B',
      );

      expect(target, 'frame_A');
    });

    test('returns single selected frame', () {
      final selection = <DragTarget>{const FrameTarget('frame_A')};

      final target = determineTargetFrame(
        selection: selection,
        focusedFrameId: 'frame_B',
      );

      expect(target, 'frame_A');
    });

    test('returns focusedFrameId for multiple nodes', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_1', patchTarget: 'node_1'),
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_2', patchTarget: 'node_2'),
      };

      final target = determineTargetFrame(
        selection: selection,
        focusedFrameId: 'frame_B',
      );

      expect(target, 'frame_B');
    });

    test('returns focusedFrameId for empty selection', () {
      final target = determineTargetFrame(
        selection: {},
        focusedFrameId: 'frame_B',
      );

      expect(target, 'frame_B');
    });

    test('returns null when no focusedFrameId and multiple selection', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_1', patchTarget: 'node_1'),
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_2', patchTarget: 'node_2'),
      };

      final target = determineTargetFrame(
        selection: selection,
        focusedFrameId: null,
      );

      expect(target, isNull);
    });
  });

  group('determineTargetParent', () {
    Frame createFrame(String id, String rootNodeId) {
      return Frame(
        id: id,
        name: 'Frame $id',
        rootNodeId: rootNodeId,
        canvas: const CanvasPlacement(
          position: Offset(0, 0),
          size: Size(400, 300),
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('returns single selected node as parent', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_1', patchTarget: 'node_1'),
      };
      final frames = {'frame_A': createFrame('frame_A', 'root_node')};

      final parent = determineTargetParent(
        selection: selection,
        targetFrameId: 'frame_A',
        frames: frames,
      );

      expect(parent, 'node_1');
    });

    test('returns frame root for multiple nodes', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_1', patchTarget: 'node_1'),
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_2', patchTarget: 'node_2'),
      };
      final frames = {'frame_A': createFrame('frame_A', 'root_node')};

      final parent = determineTargetParent(
        selection: selection,
        targetFrameId: 'frame_A',
        frames: frames,
      );

      expect(parent, 'root_node');
    });

    test('returns frame root for frame selection', () {
      final selection = <DragTarget>{const FrameTarget('frame_A')};
      final frames = {'frame_A': createFrame('frame_A', 'root_node')};

      final parent = determineTargetParent(
        selection: selection,
        targetFrameId: 'frame_A',
        frames: frames,
      );

      expect(parent, 'root_node');
    });

    test('returns null when targetFrameId is null', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_A', expandedId: 'node_1', patchTarget: 'node_1'),
      };

      final parent = determineTargetParent(
        selection: selection,
        targetFrameId: null,
        frames: {},
      );

      expect(parent, isNull);
    });

    test('ignores nodes from different frames', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_B', expandedId: 'node_1', patchTarget: 'node_1'),
      };
      final frames = {'frame_A': createFrame('frame_A', 'root_node')};

      final parent = determineTargetParent(
        selection: selection,
        targetFrameId: 'frame_A',
        frames: frames,
      );

      // No matching node in target frame, use frame root
      expect(parent, 'root_node');
    });

    test('ignores nodes with null patchTarget', () {
      final selection = <DragTarget>{
        const NodeTarget(frameId: 'frame_A', expandedId: 'inst::node_1', patchTarget: null),
      };
      final frames = {'frame_A': createFrame('frame_A', 'root_node')};

      final parent = determineTargetParent(
        selection: selection,
        targetFrameId: 'frame_A',
        frames: frames,
      );

      // Instance children can't be paste targets, use frame root
      expect(parent, 'root_node');
    });
  });
}
