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
        // Create a button component with source-namespaced IDs
        const buttonRoot = Node(
          id: 'comp_button::btn_root',
          name: 'Button Container',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['comp_button::btn_label'],
          style: NodeStyle(fill: SolidFill(HexColor('#007AFF'))),
          sourceComponentId: 'comp_button',
          templateUid: 'btn_root',
        );

        const buttonLabel = Node(
          id: 'comp_button::btn_label',
          name: 'Button Label',
          type: NodeType.text,
          props: TextProps(text: 'Click Me'),
          sourceComponentId: 'comp_button',
          templateUid: 'btn_label',
        );

        final now = DateTime.now();
        final component = ComponentDef(
          id: 'comp_button',
          name: 'Button',
          rootNodeId: 'comp_button::btn_root',
          createdAt: now,
          updatedAt: now,
        );

        // Create an instance of the button
        // Note: overrides use local ID 'btn_label' (not namespaced)
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

        // Should have expanded the instance with source-namespaced IDs
        expect(
            scene.nodes.containsKey('inst_btn1::comp_button::btn_root'), true);
        expect(
            scene.nodes.containsKey('inst_btn1::comp_button::btn_label'), true);
      });

      test('applies namespacing to expanded nodes', () {
        final scene = builder.build('f_main', docWithComponent)!;

        final expandedLabel =
            scene.nodes['inst_btn1::comp_button::btn_label']!;
        expect(expandedLabel.id, 'inst_btn1::comp_button::btn_label');
      });

      test('applies overrides to expanded nodes', () {
        final scene = builder.build('f_main', docWithComponent)!;

        final expandedLabel =
            scene.nodes['inst_btn1::comp_button::btn_label']!;
        final props = expandedLabel.props as TextProps;
        expect(props.text, 'Submit'); // Overridden from 'Click Me'
      });

      test('isInsideInstance returns true for namespaced IDs', () {
        final scene = builder.build('f_main', docWithComponent)!;

        expect(
            scene.isInsideInstance('inst_btn1::comp_button::btn_root'), true);
        expect(
            scene.isInsideInstance('inst_btn1::comp_button::btn_label'), true);
        expect(scene.isInsideInstance('n_root'), false);
      });

      test('getOwningInstance returns correct instance ID', () {
        final scene = builder.build('f_main', docWithComponent)!;

        // For 'inst_btn1::comp_button::btn_root', owning instance is 'inst_btn1'
        expect(scene.getOwningInstance('inst_btn1::comp_button::btn_root'),
            'inst_btn1');
        expect(scene.getOwningInstance('inst_btn1::comp_button::btn_label'),
            'inst_btn1');
        expect(scene.getOwningInstance('n_root'), null);
      });

      test('patchTarget is null for instance children (v1 - not editable)', () {
        final scene = builder.build('f_main', docWithComponent)!;

        // Instance children cannot be edited (v1 behavior)
        // patchTarget is null to prevent data corruption
        expect(
            scene.patchTarget['inst_btn1::comp_button::btn_root'], isNull);
        expect(
            scene.patchTarget['inst_btn1::comp_button::btn_label'], isNull);
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

  // ==========================================================================
  // Phase 0: Foundation Hardening Tests
  // ==========================================================================

  group('Cycle Detection', () {
    late ExpandedSceneBuilder builder;
    late Frame frame;

    setUp(() {
      builder = const ExpandedSceneBuilder();
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
    });

    test('direct self-reference creates error placeholder', () {
      // Component A contains an instance of Component A
      const compARoot = Node(
        id: 'comp_a::root',
        name: 'A Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_a::self_inst'],
        sourceComponentId: 'comp_a',
        templateUid: 'root',
      );

      const selfInstance = Node(
        id: 'comp_a::self_inst',
        name: 'Self Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_a'),
        sourceComponentId: 'comp_a',
        templateUid: 'self_inst',
      );

      final now = DateTime.now();
      final componentA = ComponentDef(
        id: 'comp_a',
        name: 'Component A',
        rootNodeId: 'comp_a::root',
        createdAt: now,
        updatedAt: now,
      );

      const instanceOfA = Node(
        id: 'inst_a',
        name: 'Instance of A',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_a'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_a'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compARoot)
          .withNode(selfInstance)
          .withNode(instanceOfA)
          .withNode(rootNode)
          .withComponent(componentA)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // The self-reference should create a placeholder, not infinite loop
      expect(scene.nodes.containsKey('inst_a::comp_a::self_inst'), true);
      final placeholder = scene.nodes['inst_a::comp_a::self_inst']!;
      expect(placeholder.type, NodeType.container);
      expect(placeholder.origin?.kind, OriginKind.errorPlaceholder);
      expect(placeholder.origin?.componentId, 'comp_a');
    });

    test('indirect cycle creates error placeholder', () {
      // Component A → Component B → Component A (cycle)
      const compARoot = Node(
        id: 'comp_a::root',
        name: 'A Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_a::inst_b'],
        sourceComponentId: 'comp_a',
        templateUid: 'root',
      );

      const instBInA = Node(
        id: 'comp_a::inst_b',
        name: 'B Instance in A',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_b'),
        sourceComponentId: 'comp_a',
        templateUid: 'inst_b',
      );

      const compBRoot = Node(
        id: 'comp_b::root',
        name: 'B Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_b::inst_a'],
        sourceComponentId: 'comp_b',
        templateUid: 'root',
      );

      const instAInB = Node(
        id: 'comp_b::inst_a',
        name: 'A Instance in B (cycle!)',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_a'),
        sourceComponentId: 'comp_b',
        templateUid: 'inst_a',
      );

      final now = DateTime.now();
      final componentA = ComponentDef(
        id: 'comp_a',
        name: 'Component A',
        rootNodeId: 'comp_a::root',
        createdAt: now,
        updatedAt: now,
      );

      final componentB = ComponentDef(
        id: 'comp_b',
        name: 'Component B',
        rootNodeId: 'comp_b::root',
        createdAt: now,
        updatedAt: now,
      );

      const instanceOfA = Node(
        id: 'inst_a',
        name: 'Instance of A',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_a'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_a'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compARoot)
          .withNode(instBInA)
          .withNode(compBRoot)
          .withNode(instAInB)
          .withNode(instanceOfA)
          .withNode(rootNode)
          .withComponent(componentA)
          .withComponent(componentB)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // A → B works fine
      expect(scene.nodes
          .containsKey('inst_a::comp_a::inst_b::comp_b::root'), true);

      // B → A should be a placeholder (cycle detected)
      final cycleKey = 'inst_a::comp_a::inst_b::comp_b::inst_a';
      expect(scene.nodes.containsKey(cycleKey), true);
      final placeholder = scene.nodes[cycleKey]!;
      expect(placeholder.origin?.kind, OriginKind.errorPlaceholder);
      expect(placeholder.origin?.componentId, 'comp_a');
    });

    test('same component used twice is NOT a cycle', () {
      // Container has two Button instances - both should expand normally
      const buttonRoot = Node(
        id: 'comp_button::btn_root',
        name: 'Button Root',
        type: NodeType.container,
        props: ContainerProps(),
        sourceComponentId: 'comp_button',
        templateUid: 'btn_root',
      );

      final now = DateTime.now();
      final buttonComponent = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        createdAt: now,
        updatedAt: now,
      );

      const inst1 = Node(
        id: 'inst_btn1',
        name: 'Button 1',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_button'),
      );

      const inst2 = Node(
        id: 'inst_btn2',
        name: 'Button 2',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_button'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_btn1', 'inst_btn2'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(buttonRoot)
          .withNode(inst1)
          .withNode(inst2)
          .withNode(rootNode)
          .withComponent(buttonComponent)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Both instances should expand normally (not cycles)
      expect(scene.nodes.containsKey('inst_btn1::comp_button::btn_root'), true);
      expect(scene.nodes.containsKey('inst_btn2::comp_button::btn_root'), true);

      // Neither should be error placeholders
      final btn1 = scene.nodes['inst_btn1::comp_button::btn_root']!;
      final btn2 = scene.nodes['inst_btn2::comp_button::btn_root']!;
      expect(btn1.origin?.kind, OriginKind.componentChild);
      expect(btn2.origin?.kind, OriginKind.componentChild);
    });
  });

  group('Origin Metadata', () {
    late ExpandedSceneBuilder builder;
    late Frame frame;

    setUp(() {
      builder = const ExpandedSceneBuilder();
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
    });

    test('frameNode origin for regular nodes', () {
      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['n_child'],
      );

      const childNode = Node(
        id: 'n_child',
        name: 'Child',
        type: NodeType.text,
        props: TextProps(text: 'Hello'),
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(rootNode)
          .withNode(childNode)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      expect(scene.nodes['n_root']?.origin?.kind, OriginKind.frameNode);
      expect(scene.nodes['n_child']?.origin?.kind, OriginKind.frameNode);
      expect(scene.nodes['n_root']?.origin?.instancePath, isEmpty);
    });

    test('componentChild origin for expanded component nodes', () {
      const buttonRoot = Node(
        id: 'comp_button::btn_root',
        name: 'Button Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_button::btn_label'],
        sourceComponentId: 'comp_button',
        templateUid: 'btn_root',
      );

      const buttonLabel = Node(
        id: 'comp_button::btn_label',
        name: 'Button Label',
        type: NodeType.text,
        props: TextProps(text: 'Click'),
        sourceComponentId: 'comp_button',
        templateUid: 'btn_label',
      );

      final now = DateTime.now();
      final component = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        createdAt: now,
        updatedAt: now,
      );

      const instanceNode = Node(
        id: 'inst_btn',
        name: 'Button Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_button'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_btn'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(buttonRoot)
          .withNode(buttonLabel)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      final expandedRoot = scene.nodes['inst_btn::comp_button::btn_root']!;
      final expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;

      expect(expandedRoot.origin?.kind, OriginKind.componentChild);
      expect(expandedRoot.origin?.componentId, 'comp_button');
      expect(expandedRoot.origin?.instancePath, ['inst_btn']);

      expect(expandedLabel.origin?.kind, OriginKind.componentChild);
      expect(expandedLabel.origin?.componentId, 'comp_button');
    });

    test('componentChild origin includes isOverridden flag', () {
      const buttonRoot = Node(
        id: 'comp_button::btn_root',
        name: 'Button Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_button::btn_label'],
        sourceComponentId: 'comp_button',
        templateUid: 'btn_root',
      );

      const buttonLabel = Node(
        id: 'comp_button::btn_label',
        name: 'Button Label',
        type: NodeType.text,
        props: TextProps(text: 'Click'),
        sourceComponentId: 'comp_button',
        templateUid: 'btn_label',
      );

      final now = DateTime.now();
      final component = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        createdAt: now,
        updatedAt: now,
      );

      const instanceNode = Node(
        id: 'inst_btn',
        name: 'Button Instance',
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

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_btn'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(buttonRoot)
          .withNode(buttonLabel)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Root has no overrides
      final expandedRoot = scene.nodes['inst_btn::comp_button::btn_root']!;
      expect(expandedRoot.origin?.isOverridden, false);

      // Label has overrides
      final expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect(expandedLabel.origin?.isOverridden, true);
    });

    test('errorPlaceholder origin for missing component', () {
      const instanceNode = Node(
        id: 'inst_missing',
        name: 'Missing Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_nonexistent'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_missing'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(instanceNode)
          .withNode(rootNode)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      final placeholder = scene.nodes['inst_missing']!;
      expect(placeholder.origin?.kind, OriginKind.errorPlaceholder);
      expect(placeholder.origin?.componentId, 'comp_nonexistent');
    });

    test('instancePath tracks nesting depth', () {
      // Create nested components: OuterComp contains InnerComp contains a label
      const innerRoot = Node(
        id: 'comp_inner::root',
        name: 'Inner Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_inner::label'],
        sourceComponentId: 'comp_inner',
        templateUid: 'root',
      );

      const innerLabel = Node(
        id: 'comp_inner::label',
        name: 'Inner Label',
        type: NodeType.text,
        props: TextProps(text: 'Inner'),
        sourceComponentId: 'comp_inner',
        templateUid: 'label',
      );

      const outerRoot = Node(
        id: 'comp_outer::root',
        name: 'Outer Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_outer::inner_inst'],
        sourceComponentId: 'comp_outer',
        templateUid: 'root',
      );

      const innerInstInOuter = Node(
        id: 'comp_outer::inner_inst',
        name: 'Inner Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_inner'),
        sourceComponentId: 'comp_outer',
        templateUid: 'inner_inst',
      );

      final now = DateTime.now();
      final innerComponent = ComponentDef(
        id: 'comp_inner',
        name: 'Inner',
        rootNodeId: 'comp_inner::root',
        createdAt: now,
        updatedAt: now,
      );

      final outerComponent = ComponentDef(
        id: 'comp_outer',
        name: 'Outer',
        rootNodeId: 'comp_outer::root',
        createdAt: now,
        updatedAt: now,
      );

      const outerInstance = Node(
        id: 'inst_outer',
        name: 'Outer Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_outer'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_outer'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(innerRoot)
          .withNode(innerLabel)
          .withNode(outerRoot)
          .withNode(innerInstInOuter)
          .withNode(outerInstance)
          .withNode(rootNode)
          .withComponent(innerComponent)
          .withComponent(outerComponent)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Outer component nodes have instancePath = ['inst_outer']
      final outerRootExpanded =
          scene.nodes['inst_outer::comp_outer::root']!;
      expect(outerRootExpanded.origin?.instancePath, ['inst_outer']);

      // Inner component nodes have instancePath = ['inst_outer', 'inst_outer::comp_outer::inner_inst']
      final innerLabelExpanded = scene.nodes[
          'inst_outer::comp_outer::inner_inst::comp_inner::label']!;
      expect(innerLabelExpanded.origin?.instancePath,
          ['inst_outer', 'inst_outer::comp_outer::inner_inst']);
    });
  });

  group('Override Resolution', () {
    late ExpandedSceneBuilder builder;
    late Frame frame;

    setUp(() {
      builder = const ExpandedSceneBuilder();
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
    });

    test('overrides by local ID still work', () {
      const buttonRoot = Node(
        id: 'comp_button::btn_root',
        name: 'Button Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_button::btn_label'],
        sourceComponentId: 'comp_button',
        templateUid: 'btn_root',
      );

      const buttonLabel = Node(
        id: 'comp_button::btn_label',
        name: 'Button Label',
        type: NodeType.text,
        props: TextProps(text: 'Default'),
        sourceComponentId: 'comp_button',
        templateUid: 'btn_label',
      );

      final now = DateTime.now();
      final component = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        createdAt: now,
        updatedAt: now,
      );

      // Override using local ID (not namespaced)
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'Button Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_button',
          overrides: {
            'btn_label': {
              'props': {'text': 'Overridden'},
            },
          },
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_btn'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(buttonRoot)
          .withNode(buttonLabel)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      final expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      final props = expandedLabel.props as TextProps;
      expect(props.text, 'Overridden');
    });

    test('overrides by namespaced ID also work', () {
      const buttonRoot = Node(
        id: 'comp_button::btn_root',
        name: 'Button Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_button::btn_label'],
        sourceComponentId: 'comp_button',
        templateUid: 'btn_root',
      );

      const buttonLabel = Node(
        id: 'comp_button::btn_label',
        name: 'Button Label',
        type: NodeType.text,
        props: TextProps(text: 'Default'),
        sourceComponentId: 'comp_button',
        templateUid: 'btn_label',
      );

      final now = DateTime.now();
      final component = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        createdAt: now,
        updatedAt: now,
      );

      // Override using full namespaced ID
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'Button Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_button',
          overrides: {
            'comp_button::btn_label': {
              'props': {'text': 'Overridden via namespaced'},
            },
          },
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_btn'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(buttonRoot)
          .withNode(buttonLabel)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      final expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      final props = expandedLabel.props as TextProps;
      expect(props.text, 'Overridden via namespaced');
    });
  });

  group('Component Node ID Helpers', () {
    test('componentNodeId generates correct format', () {
      expect(componentNodeId('comp_button', 'btn_root'),
          'comp_button::btn_root');
      expect(componentNodeId('comp_card', 'card_header'),
          'comp_card::card_header');
    });

    test('localIdFromNodeId extracts correctly', () {
      expect(localIdFromNodeId('comp_button::btn_root'), 'btn_root');
      expect(localIdFromNodeId('comp_card::card_header'), 'card_header');
      expect(localIdFromNodeId('not_namespaced'), isNull);
    });

    test('componentIdFromNodeId extracts correctly', () {
      expect(componentIdFromNodeId('comp_button::btn_root'), 'comp_button');
      expect(componentIdFromNodeId('comp_card::card_header'), 'comp_card');
      expect(componentIdFromNodeId('not_namespaced'), isNull);
    });
  });

  // ===========================================================================
  // Phase 1: Slot Expansion Tests
  // ===========================================================================

  group('Slot Expansion', () {
    late ExpandedSceneBuilder builder;
    late Frame frame;
    late DateTime now;

    setUp(() {
      builder = const ExpandedSceneBuilder();
      now = DateTime.now();
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
    });

    test('slot with no assignment renders as placeholder', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Instance with NO slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_card'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Slot should appear as placeholder
      expect(
          scene.nodes.containsKey('inst_card::comp_card::content_slot'), true);
      final slot = scene.nodes['inst_card::comp_card::content_slot']!;
      expect(slot.type, NodeType.slot);
      expect(slot.patchTargetId, isNull); // Placeholder is not editable
    });

    test('slot with assignment renders injected content', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Injected content should appear in place of slot
      // Check that card root's children include the slot content
      final cardRoot = scene.nodes['inst_card::comp_card::root']!;
      expect(cardRoot.childIds.any((id) => id.contains('slot_content_1')), true);

      // Slot placeholder should NOT be in childIds
      expect(cardRoot.childIds.contains('inst_card::comp_card::content_slot'),
          false);
    });

    test('slot replacement changes parent childIds correctly', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Parent's childIds should contain injected root, NOT slot placeholder
      final cardRoot = scene.nodes['inst_card::comp_card::root']!;

      // Should contain the injected content ID
      expect(cardRoot.childIds.length, 1);
      expect(cardRoot.childIds.first.contains('slot(content)'), true);
      expect(cardRoot.childIds.first.contains('slot_content_1'), true);

      // Should NOT contain the slot placeholder ID
      expect(cardRoot.childIds.any((id) => id.contains('content_slot')), false);
    });

    test('slot with defaultContentId uses default when empty', () {
      // Create component with slot that has default content
      const defaultContent = Node(
        id: 'comp_card::default_content',
        name: 'Default Content',
        type: NodeType.text,
        props: TextProps(text: 'Default Text'),
        sourceComponentId: 'comp_card',
        templateUid: 'default_content',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(
          slotName: 'content',
          defaultContentId: 'comp_card::default_content',
        ),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Instance with NO slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_card'),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(defaultContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Default content should be used
      final cardRoot = scene.nodes['inst_card::comp_card::root']!;
      expect(cardRoot.childIds.any((id) => id.contains('default')), true);

      // Find the default content node and verify it's not editable
      final defaultNode = scene.nodes.values.firstWhere(
        (n) => n.id.contains('default'),
      );
      expect(defaultNode.patchTargetId, isNull); // Default content is NOT editable
    });

    test('injected content is editable (patchTargetId set)', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Find slot content node
      final slotContentNode = scene.nodes.values.firstWhere(
        (n) => n.origin?.kind == OriginKind.slotContent,
      );

      // Slot content should be editable
      expect(slotContentNode.patchTargetId, isNotNull);
      expect(slotContentNode.patchTargetId, 'slot_content_1');
    });

    test('injected content descendants are editable', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content - container with child
      const slotContentChild = Node(
        id: 'slot_content_child',
        name: 'Child Text',
        type: NodeType.text,
        props: TextProps(text: 'Nested content'),
        ownerInstanceId: 'inst_card',
      );

      const slotContentRoot = Node(
        id: 'slot_content_root',
        name: 'Content Container',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['slot_content_child'],
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_root')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContentRoot)
          .withNode(slotContentChild)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Find all slot content nodes
      final slotContentNodes = scene.nodes.values
          .where((n) => n.origin?.kind == OriginKind.slotContent)
          .toList();

      expect(slotContentNodes.length, 2); // Root and child

      // ALL descendants should be editable
      for (final node in slotContentNodes) {
        expect(node.patchTargetId, isNotNull,
            reason: 'Node ${node.id} should be editable');
      }
    });

    test('component children still not editable', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Component children (non-slot) should not be editable
      final compRootExpanded = scene.nodes['inst_card::comp_card::root']!;
      expect(compRootExpanded.patchTargetId, isNull);
    });

    test('slot content has slotContent origin kind', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      final slotContentNode = scene.nodes.values.firstWhere(
        (n) => n.id.contains('slot_content_1'),
      );

      expect(slotContentNode.origin?.kind, OriginKind.slotContent);
    });

    test('slot content has correct slotOrigin', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      final slotContentNode = scene.nodes.values.firstWhere(
        (n) => n.origin?.kind == OriginKind.slotContent,
      );

      expect(slotContentNode.origin?.slotOrigin, isNotNull);
      expect(slotContentNode.origin?.slotOrigin?.slotName, 'content');
      expect(slotContentNode.origin?.slotOrigin?.instanceId, 'inst_card');
    });

    test('slotChildrenByInstance index is populated', () {
      // Create component with slot
      const compRoot = Node(
        id: 'comp_card::root',
        name: 'Card Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_card::content_slot'],
        sourceComponentId: 'comp_card',
        templateUid: 'root',
      );

      const slotNode = Node(
        id: 'comp_card::content_slot',
        name: 'Content Slot',
        type: NodeType.slot,
        props: SlotProps(slotName: 'content'),
        sourceComponentId: 'comp_card',
        templateUid: 'content_slot',
      );

      final component = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'comp_card::root',
        createdAt: now,
        updatedAt: now,
      );

      // Slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Instance WITH slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(compRoot)
          .withNode(slotNode)
          .withNode(slotContent)
          .withNode(instanceNode)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      final scene = builder.build('f_main', doc)!;

      // Index should contain the instance's slot content
      expect(scene.slotChildrenByInstance.containsKey('inst_card'), true);
      expect(scene.slotChildrenByInstance['inst_card']!.length, 1);
      expect(
          scene.slotChildrenByInstance['inst_card']!.first
              .contains('slot_content_1'),
          true);
    });
  });
}
