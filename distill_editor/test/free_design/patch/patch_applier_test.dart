import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('PatchApplier', () {
    late PatchApplier applier;
    late EditorDocument doc;
    late Node rootNode;
    late Node childNode;
    late Frame frame;

    setUp(() {
      applier = const PatchApplier();
      doc = EditorDocument.empty(documentId: 'doc_test');

      rootNode = const Node(
        id: 'n_root',
        name: 'Root Container',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['n_child'],
      );

      childNode = const Node(
        id: 'n_child',
        name: 'Child Text',
        type: NodeType.text,
        props: TextProps(text: 'Hello'),
      );

      final now = DateTime.now();
      frame = Frame(
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

      doc = doc.withNode(rootNode).withNode(childNode).withFrame(frame);
    });

    group('InsertNode', () {
      test('inserts a new node', () {
        const newNode = Node(
          id: 'n_new',
          name: 'New Node',
          type: NodeType.spacer,
          props: SpacerProps(),
        );

        final result = applier.apply(doc, InsertNode(newNode));

        expect(result.nodes.containsKey('n_new'), true);
        expect(result.nodes['n_new']?.name, 'New Node');
      });
    });

    group('DeleteNode', () {
      test('removes a node', () {
        final result = applier.apply(doc, const DeleteNode('n_child'));

        expect(result.nodes.containsKey('n_child'), false);
        expect(result.nodes.containsKey('n_root'), true);
      });
    });

    group('SetProp', () {
      test('updates node name', () {
        final result = applier.apply(
          doc,
          const SetProp(id: 'n_root', path: '/name', value: 'Renamed Root'),
        );

        expect(result.nodes['n_root']?.name, 'Renamed Root');
      });

      test('updates layout position', () {
        final result = applier.apply(
          doc,
          const SetProp(
            id: 'n_root',
            path: '/layout/position',
            value: {'mode': 'absolute', 'x': 50.0, 'y': 100.0},
          ),
        );

        final position = result.nodes['n_root']?.layout.position;
        expect(position, isA<PositionModeAbsolute>());
        expect((position as PositionModeAbsolute).x, 50.0);
        expect(position.y, 100.0);
      });

      test('updates style opacity', () {
        final result = applier.apply(
          doc,
          const SetProp(id: 'n_root', path: '/style/opacity', value: 0.5),
        );

        expect(result.nodes['n_root']?.style.opacity, 0.5);
      });

      test('updates style fill', () {
        final result = applier.apply(
          doc,
          const SetProp(
            id: 'n_root',
            path: '/style/fill',
            value: {
              'type': 'solid',
              'color': {'hex': '#FF0000'},
            },
          ),
        );

        final fill = result.nodes['n_root']?.style.fill;
        expect(fill, isA<SolidFill>());
      });
    });

    group('AttachChild', () {
      test('adds child to parent', () {
        const newNode = Node(
          id: 'n_new',
          type: NodeType.spacer,
          props: SpacerProps(),
        );

        var result = applier.apply(doc, InsertNode(newNode));
        result = applier.apply(
          result,
          const AttachChild(parentId: 'n_root', childId: 'n_new', index: 0),
        );

        expect(result.nodes['n_root']?.childIds, contains('n_new'));
        expect(result.nodes['n_root']?.childIds.first, 'n_new');
      });

      test('appends at end when index out of bounds', () {
        const newNode = Node(
          id: 'n_new',
          type: NodeType.spacer,
          props: SpacerProps(),
        );

        var result = applier.apply(doc, InsertNode(newNode));
        result = applier.apply(
          result,
          const AttachChild(parentId: 'n_root', childId: 'n_new', index: 999),
        );

        expect(result.nodes['n_root']?.childIds.last, 'n_new');
      });
    });

    group('DetachChild', () {
      test('removes child from parent', () {
        final result = applier.apply(
          doc,
          const DetachChild(parentId: 'n_root', childId: 'n_child'),
        );

        expect(result.nodes['n_root']?.childIds, isNot(contains('n_child')));
      });
    });

    group('MoveNode', () {
      test('moves node to new parent', () {
        const newParent = Node(
          id: 'n_parent2',
          name: 'Second Parent',
          type: NodeType.container,
          props: ContainerProps(),
        );

        var result = applier.apply(doc, InsertNode(newParent));
        result = applier.apply(
          result,
          const MoveNode(id: 'n_child', newParentId: 'n_parent2', index: 0),
        );

        expect(result.nodes['n_root']?.childIds, isNot(contains('n_child')));
        expect(result.nodes['n_parent2']?.childIds, contains('n_child'));
      });
    });

    group('ReplaceNode', () {
      test('replaces existing node', () {
        const replacement = Node(
          id: 'n_child',
          name: 'Replaced Child',
          type: NodeType.icon,
          props: IconProps(icon: 'home'),
        );

        final result = applier.apply(
          doc,
          const ReplaceNode(id: 'n_child', node: replacement),
        );

        expect(result.nodes['n_child']?.name, 'Replaced Child');
        expect(result.nodes['n_child']?.type, NodeType.icon);
      });

      test('ignores if node does not exist', () {
        const replacement = Node(
          id: 'n_nonexistent',
          type: NodeType.spacer,
          props: SpacerProps(),
        );

        final result = applier.apply(
          doc,
          const ReplaceNode(id: 'n_nonexistent', node: replacement),
        );

        expect(result.nodes.containsKey('n_nonexistent'), false);
      });
    });

    group('InsertFrame', () {
      test('inserts a new frame', () {
        final now = DateTime.now();
        final newFrame = Frame(
          id: 'f_new',
          name: 'New Frame',
          rootNodeId: 'n_new_root',
          canvas: const CanvasPlacement(
            position: Offset(100, 100),
            size: Size(320, 568),
          ),
          createdAt: now,
          updatedAt: now,
        );

        final result = applier.apply(doc, InsertFrame(newFrame));

        expect(result.frames.containsKey('f_new'), true);
        expect(result.frames['f_new']?.name, 'New Frame');
      });
    });

    group('RemoveFrame', () {
      test('removes a frame', () {
        final result = applier.apply(doc, const RemoveFrame('f_main'));

        expect(result.frames.containsKey('f_main'), false);
      });
    });

    group('SetFrameProp', () {
      test('updates frame name', () {
        final result = applier.apply(
          doc,
          const SetFrameProp(
            frameId: 'f_main',
            path: '/name',
            value: 'Renamed Frame',
          ),
        );

        expect(result.frames['f_main']?.name, 'Renamed Frame');
      });

      test('updates canvas position', () {
        final result = applier.apply(
          doc,
          const SetFrameProp(
            frameId: 'f_main',
            path: '/canvas/position/x',
            value: 200.0,
          ),
        );

        expect(result.frames['f_main']?.canvas.position.dx, 200.0);
      });

      test('updates canvas size', () {
        final result = applier.apply(
          doc,
          const SetFrameProp(
            frameId: 'f_main',
            path: '/canvas/size',
            value: {'width': 400.0, 'height': 800.0},
          ),
        );

        expect(result.frames['f_main']?.canvas.size.width, 400.0);
        expect(result.frames['f_main']?.canvas.size.height, 800.0);
      });
    });

    group('AutoLayout property updates', () {
      test('updates autoLayout direction', () {
        // First add autoLayout to the node
        var result = applier.apply(
          doc,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout',
            value: {
              'direction': 'vertical',
              'mainAlign': 'start',
              'crossAlign': 'start',
              'gap': 0,
              'padding': {'top': 0, 'right': 0, 'bottom': 0, 'left': 0},
            },
          ),
        );

        // Then update just the direction
        result = applier.apply(
          result,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout/direction',
            value: 'horizontal',
          ),
        );

        final autoLayout = result.nodes['n_root']?.layout.autoLayout;
        expect(autoLayout, isNotNull);
        expect(autoLayout!.direction, LayoutDirection.horizontal);
        expect(autoLayout.mainAlign, MainAxisAlignment.start); // Unchanged
      });

      test('updates autoLayout gap', () {
        // First add autoLayout to the node
        var result = applier.apply(
          doc,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout',
            value: {
              'direction': 'vertical',
              'mainAlign': 'start',
              'crossAlign': 'start',
              'gap': 8,
              'padding': {'top': 0, 'right': 0, 'bottom': 0, 'left': 0},
            },
          ),
        );

        // Then update just the gap
        result = applier.apply(
          result,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout/gap',
            value: 16,
          ),
        );

        final autoLayout = result.nodes['n_root']?.layout.autoLayout;
        expect(autoLayout, isNotNull);
        expect(autoLayout!.gap?.toDouble(), 16.0);
        expect(autoLayout.direction, LayoutDirection.vertical); // Unchanged
      });

      test('updates autoLayout mainAlign', () {
        // First add autoLayout to the node
        var result = applier.apply(
          doc,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout',
            value: {
              'direction': 'vertical',
              'mainAlign': 'start',
              'crossAlign': 'start',
              'gap': 0,
              'padding': {'top': 0, 'right': 0, 'bottom': 0, 'left': 0},
            },
          ),
        );

        // Then update just the mainAlign
        result = applier.apply(
          result,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout/mainAlign',
            value: 'center',
          ),
        );

        final autoLayout = result.nodes['n_root']?.layout.autoLayout;
        expect(autoLayout, isNotNull);
        expect(autoLayout!.mainAlign, MainAxisAlignment.center);
      });

      test('updates autoLayout crossAlign', () {
        // First add autoLayout to the node
        var result = applier.apply(
          doc,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout',
            value: {
              'direction': 'vertical',
              'mainAlign': 'start',
              'crossAlign': 'start',
              'gap': 0,
              'padding': {'top': 0, 'right': 0, 'bottom': 0, 'left': 0},
            },
          ),
        );

        // Then update just the crossAlign
        result = applier.apply(
          result,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout/crossAlign',
            value: 'stretch',
          ),
        );

        final autoLayout = result.nodes['n_root']?.layout.autoLayout;
        expect(autoLayout, isNotNull);
        expect(autoLayout!.crossAlign, CrossAxisAlignment.stretch);
      });

      test('updates autoLayout padding', () {
        // First add autoLayout to the node
        var result = applier.apply(
          doc,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout',
            value: {
              'direction': 'vertical',
              'mainAlign': 'start',
              'crossAlign': 'start',
              'gap': 0,
              'padding': {'top': 8, 'right': 8, 'bottom': 8, 'left': 8},
            },
          ),
        );

        // Then update just the padding
        result = applier.apply(
          result,
          const SetProp(
            id: 'n_root',
            path: '/layout/autoLayout/padding',
            value: {'top': 16, 'right': 16, 'bottom': 16, 'left': 16},
          ),
        );

        final autoLayout = result.nodes['n_root']?.layout.autoLayout;
        expect(autoLayout, isNotNull);
        expect(autoLayout!.padding.top.toDouble(), 16.0);
        expect(autoLayout.padding.right.toDouble(), 16.0);
        expect(autoLayout.padding.bottom.toDouble(), 16.0);
        expect(autoLayout.padding.left.toDouble(), 16.0);
      });
    });

    group('applyAll', () {
      test('applies multiple patches in order', () {
        final patches = [
          const InsertNode(
            Node(id: 'n_new1', type: NodeType.spacer, props: SpacerProps()),
          ),
          const InsertNode(
            Node(id: 'n_new2', type: NodeType.spacer, props: SpacerProps()),
          ),
          const AttachChild(parentId: 'n_root', childId: 'n_new1', index: 0),
          const AttachChild(parentId: 'n_root', childId: 'n_new2', index: 1),
        ];

        final result = applier.applyAll(doc, patches);

        expect(result.nodes.containsKey('n_new1'), true);
        expect(result.nodes.containsKey('n_new2'), true);
        expect(result.nodes['n_root']?.childIds.first, 'n_new1');
        expect(result.nodes['n_root']?.childIds[1], 'n_new2');
      });
    });
  });
}
