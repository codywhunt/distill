import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('ExpandedSceneBuilder', () {
    late EditorDocument doc;
    late Frame frame;
    late ExpandedSceneBuilder builder;

    setUp(() {
      builder = const ExpandedSceneBuilder();

      // Create a simple document with a root container and text child
      final rootNode = const Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['n_text'],
      );

      final textNode = const Node(
        id: 'n_text',
        name: 'Hello Text',
        type: NodeType.text,
        props: TextProps(text: 'Hello World'),
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

      doc = EditorDocument.empty(
        documentId: 'doc_test',
      ).withNode(rootNode).withNode(textNode).withFrame(frame);
    });

    test('builds scene for valid frame', () {
      final scene = builder.build('f_main', doc);

      expect(scene, isNotNull);
      expect(scene!.frameId, 'f_main');
      expect(scene.rootId, 'n_root');
      expect(scene.nodes.length, 2);
    });

    test('returns null for missing frame', () {
      final scene = builder.build('f_nonexistent', doc);

      expect(scene, isNull);
    });

    test('includes all nodes in expanded scene', () {
      final scene = builder.build('f_main', doc)!;

      expect(scene.nodes.containsKey('n_root'), true);
      expect(scene.nodes.containsKey('n_text'), true);
    });

    test('preserves node properties', () {
      final scene = builder.build('f_main', doc)!;

      final textNode = scene.nodes['n_text']!;
      expect(textNode.type, NodeType.text);
      expect((textNode.props as TextProps).text, 'Hello World');
    });

    test('sets correct patchTarget for regular nodes', () {
      final scene = builder.build('f_main', doc)!;

      expect(scene.patchTarget['n_root'], 'n_root');
      expect(scene.patchTarget['n_text'], 'n_text');
    });

    test('isInsideInstance returns false for regular nodes', () {
      final scene = builder.build('f_main', doc)!;

      expect(scene.isInsideInstance('n_root'), false);
      expect(scene.isInsideInstance('n_text'), false);
    });

    group('with component instances', () {
      late EditorDocument docWithComponent;

      setUp(() {
        // Create a button component
        const buttonRoot = Node(
          id: 'btn_root',
          name: 'Button Container',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['btn_label'],
          style: NodeStyle(fill: SolidFill(HexColor('#007AFF'))),
        );

        const buttonLabel = Node(
          id: 'btn_label',
          name: 'Button Label',
          type: NodeType.text,
          props: TextProps(text: 'Click Me'),
        );

        final now = DateTime.now();
        final component = ComponentDef(
          id: 'comp_button',
          name: 'Button',
          rootNodeId: 'btn_root',
          createdAt: now,
          updatedAt: now,
        );

        // Create an instance of the button
        const instanceNode = Node(
          id: 'inst_btn1',
          name: 'My Button',
          type: NodeType.instance,
          props: InstanceProps(
            componentId: 'comp_button',
            overrides: {
              'btn_label': {
                'props': {'text': 'Submit'},
              },
            },
          ),
        );

        // Root that contains the instance
        const rootWithInstance = Node(
          id: 'n_root',
          name: 'Root',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['inst_btn1'],
        );

        docWithComponent = EditorDocument.empty(documentId: 'doc_test')
            .withNode(buttonRoot)
            .withNode(buttonLabel)
            .withNode(instanceNode)
            .withNode(rootWithInstance)
            .withComponent(component)
            .withFrame(frame);
      });

      test('expands instance nodes', () {
        final scene = builder.build('f_main', docWithComponent)!;

        // Should have expanded the instance
        expect(scene.nodes.containsKey('inst_btn1::btn_root'), true);
        expect(scene.nodes.containsKey('inst_btn1::btn_label'), true);
      });

      test('applies namespacing to expanded nodes', () {
        final scene = builder.build('f_main', docWithComponent)!;

        final expandedLabel = scene.nodes['inst_btn1::btn_label']!;
        expect(expandedLabel.id, 'inst_btn1::btn_label');
      });

      test('applies overrides to expanded nodes', () {
        final scene = builder.build('f_main', docWithComponent)!;

        final expandedLabel = scene.nodes['inst_btn1::btn_label']!;
        final props = expandedLabel.props as TextProps;
        expect(props.text, 'Submit'); // Overridden from 'Click Me'
      });

      test('isInsideInstance returns true for namespaced IDs', () {
        final scene = builder.build('f_main', docWithComponent)!;

        expect(scene.isInsideInstance('inst_btn1::btn_root'), true);
        expect(scene.isInsideInstance('inst_btn1::btn_label'), true);
        expect(scene.isInsideInstance('n_root'), false);
      });

      test('getOwningInstance returns correct instance ID', () {
        final scene = builder.build('f_main', docWithComponent)!;

        expect(scene.getOwningInstance('inst_btn1::btn_root'), 'inst_btn1');
        expect(scene.getOwningInstance('inst_btn1::btn_label'), 'inst_btn1');
        expect(scene.getOwningInstance('n_root'), null);
      });

      test('patchTarget maps instance children to instance node', () {
        final scene = builder.build('f_main', docWithComponent)!;

        // Instance children should patch to the instance node itself
        expect(scene.patchTarget['inst_btn1::btn_root'], 'inst_btn1');
        expect(scene.patchTarget['inst_btn1::btn_label'], 'inst_btn1');
      });

      test('instanceIds returns all root-level instances', () {
        final scene = builder.build('f_main', docWithComponent)!;

        expect(scene.instanceIds, contains('inst_btn1'));
      });
    });

    group('with missing component', () {
      test('creates placeholder for missing component', () {
        const instanceNode = Node(
          id: 'inst_missing',
          name: 'Missing Instance',
          type: NodeType.instance,
          props: InstanceProps(componentId: 'comp_nonexistent'),
        );

        const rootWithInstance = Node(
          id: 'n_root',
          name: 'Root',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['inst_missing'],
        );

        final docWithMissing = EditorDocument.empty(
          documentId: 'doc_test',
        ).withNode(instanceNode).withNode(rootWithInstance).withFrame(frame);

        final scene = builder.build('f_main', docWithMissing)!;

        // Should create a placeholder container
        expect(scene.nodes.containsKey('inst_missing'), true);
        expect(scene.nodes['inst_missing']!.type, NodeType.container);
      });
    });
  });

  group('ExpandedNode', () {
    test('fromNode creates node with correct properties', () {
      const node = Node(
        id: 'n_test',
        name: 'Test Node',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['child1', 'child2'],
      );

      final expanded = ExpandedNode.fromNode(node);

      expect(expanded.id, 'n_test');
      expect(expanded.patchTargetId, 'n_test');
      expect(expanded.type, NodeType.container);
      expect(expanded.childIds, ['child1', 'child2']);
    });

    test('fromNode allows ID override', () {
      const node = Node(
        id: 'n_test',
        type: NodeType.container,
        props: ContainerProps(),
      );

      final expanded = ExpandedNode.fromNode(
        node,
        expandedId: 'inst1::n_test',
        patchTargetId: 'inst1',
      );

      expect(expanded.id, 'inst1::n_test');
      expect(expanded.patchTargetId, 'inst1');
    });

    test('isInsideInstance detects namespaced IDs', () {
      final regular = ExpandedNode(
        id: 'n_test',
        patchTargetId: 'n_test',
        type: NodeType.container,
        childIds: const [],
        layout: const NodeLayout(),
        style: const NodeStyle(),
        props: const ContainerProps(),
      );

      final namespaced = ExpandedNode(
        id: 'inst1::n_test',
        patchTargetId: 'inst1',
        type: NodeType.container,
        childIds: const [],
        layout: const NodeLayout(),
        style: const NodeStyle(),
        props: const ContainerProps(),
      );

      expect(regular.isInsideInstance, false);
      expect(namespaced.isInsideInstance, true);
    });

    test('owningInstance returns first segment of namespaced ID', () {
      final namespaced = ExpandedNode(
        id: 'inst1::nested::n_test',
        patchTargetId: 'inst1',
        type: NodeType.container,
        childIds: const [],
        layout: const NodeLayout(),
        style: const NodeStyle(),
        props: const ContainerProps(),
      );

      expect(namespaced.owningInstance, 'inst1');
    });
  });

  group('ExpandedScene', () {
    test('getNode returns node by ID', () {
      final node = ExpandedNode(
        id: 'n_test',
        patchTargetId: 'n_test',
        type: NodeType.container,
        childIds: const [],
        layout: const NodeLayout(),
        style: const NodeStyle(),
        props: const ContainerProps(),
      );

      final scene = ExpandedScene(
        frameId: 'f_main',
        rootId: 'n_test',
        nodes: {'n_test': node},
        patchTarget: {'n_test': 'n_test'},
      );

      expect(scene.getNode('n_test'), node);
      expect(scene.getNode('n_nonexistent'), null);
    });
  });
}
