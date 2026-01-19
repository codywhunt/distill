import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';
import 'package:distill_editor/src/free_design/commands/create_component_command.dart';

void main() {
  group('Phase 3 Test Gate: Component Library', () {
    late EditorDocumentStore store;
    late DateTime now;

    setUp(() {
      now = DateTime.now();

      // Create base document with frame
      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['n_child1'],
      );

      const childNode = Node(
        id: 'n_child1',
        name: 'Child',
        type: NodeType.container,
        props: ContainerProps(),
      );

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

      final doc = EditorDocument.empty(documentId: 'doc_test')
          .withNode(rootNode)
          .withNode(childNode)
          .withFrame(frame);

      store = EditorDocumentStore(document: doc);
    });

    tearDown(() {
      store.dispose();
    });

    group('Store helper methods', () {
      test('createComponent inserts nodes then component atomically', () {
        final component = ComponentDef(
          id: 'comp_test',
          name: 'Test Component',
          rootNodeId: 'comp_test::root',
          createdAt: now,
          updatedAt: now,
        );

        final nodes = [
          const Node(
            id: 'comp_test::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            sourceComponentId: 'comp_test',
            templateUid: 'root',
          ),
        ];

        store.createComponent(component: component, nodes: nodes);

        expect(store.document.components.containsKey('comp_test'), true);
        expect(store.document.nodes.containsKey('comp_test::root'), true);
        expect(
          store.document.nodes['comp_test::root']?.sourceComponentId,
          'comp_test',
        );
      });

      test('deleteComponent blocked when instances exist', () {
        // Create component
        final component = ComponentDef(
          id: 'comp_test',
          name: 'Test',
          rootNodeId: 'comp_test::root',
          createdAt: now,
          updatedAt: now,
        );

        final nodes = [
          const Node(
            id: 'comp_test::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            sourceComponentId: 'comp_test',
            templateUid: 'root',
          ),
        ];

        store.createComponent(component: component, nodes: nodes);

        // Add an instance
        store.addNode(
          const Node(
            id: 'inst_1',
            name: 'Instance',
            type: NodeType.instance,
            props: InstanceProps(componentId: 'comp_test'),
          ),
          parentId: 'n_root',
        );

        expect(
          () => store.deleteComponent('comp_test'),
          throwsStateError,
        );
      });

      test('deleteComponent removes component and owned nodes', () {
        // Create component with no instances
        final component = ComponentDef(
          id: 'comp_test',
          name: 'Test',
          rootNodeId: 'comp_test::root',
          createdAt: now,
          updatedAt: now,
        );

        final nodes = [
          const Node(
            id: 'comp_test::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            childIds: ['comp_test::child'],
            sourceComponentId: 'comp_test',
            templateUid: 'root',
          ),
          const Node(
            id: 'comp_test::child',
            name: 'Child',
            type: NodeType.text,
            props: TextProps(text: 'Hello'),
            sourceComponentId: 'comp_test',
            templateUid: 'child',
          ),
        ];

        store.createComponent(component: component, nodes: nodes);

        // Verify created
        expect(store.document.components.containsKey('comp_test'), true);
        expect(store.document.nodes.containsKey('comp_test::root'), true);
        expect(store.document.nodes.containsKey('comp_test::child'), true);

        // Delete
        store.deleteComponent('comp_test');

        // Verify removed
        expect(store.document.components.containsKey('comp_test'), false);
        expect(store.document.nodes.containsKey('comp_test::root'), false);
        expect(store.document.nodes.containsKey('comp_test::child'), false);
      });

      test('instantiateComponent creates valid instance', () {
        // Create component first
        final component = ComponentDef(
          id: 'comp_test',
          name: 'Test',
          rootNodeId: 'comp_test::root',
          createdAt: now,
          updatedAt: now,
        );

        final nodes = [
          const Node(
            id: 'comp_test::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            sourceComponentId: 'comp_test',
            templateUid: 'root',
          ),
        ];

        store.createComponent(component: component, nodes: nodes);

        // Instantiate
        store.instantiateComponent(
          componentId: 'comp_test',
          parentId: 'n_root',
        );

        // Find the instance
        final instance = store.document.nodes.values.firstWhere(
          (n) => n.type == NodeType.instance && n.id.startsWith('inst_'),
        );

        expect((instance.props as InstanceProps).componentId, 'comp_test');
        expect(store.parentIndex[instance.id], 'n_root');
      });

      test('instantiateComponent with custom name', () {
        // Create component
        final component = ComponentDef(
          id: 'comp_test',
          name: 'Test',
          rootNodeId: 'comp_test::root',
          createdAt: now,
          updatedAt: now,
        );

        final nodes = [
          const Node(
            id: 'comp_test::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            sourceComponentId: 'comp_test',
            templateUid: 'root',
          ),
        ];

        store.createComponent(component: component, nodes: nodes);

        // Instantiate with custom name
        store.instantiateComponent(
          componentId: 'comp_test',
          parentId: 'n_root',
          instanceName: 'My Custom Instance',
        );

        final instance = store.document.nodes.values.firstWhere(
          (n) => n.type == NodeType.instance && n.id.startsWith('inst_'),
        );

        expect(instance.name, 'My Custom Instance');
      });

      test('countInstancesOfComponent returns correct count', () {
        // Create component
        final component = ComponentDef(
          id: 'comp_test',
          name: 'Test',
          rootNodeId: 'comp_test::root',
          createdAt: now,
          updatedAt: now,
        );

        final nodes = [
          const Node(
            id: 'comp_test::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            sourceComponentId: 'comp_test',
            templateUid: 'root',
          ),
        ];

        store.createComponent(component: component, nodes: nodes);

        // Initially 0
        expect(store.countInstancesOfComponent('comp_test'), 0);

        // Add instances
        store.instantiateComponent(
          componentId: 'comp_test',
          parentId: 'n_root',
        );
        expect(store.countInstancesOfComponent('comp_test'), 1);

        store.instantiateComponent(
          componentId: 'comp_test',
          parentId: 'n_root',
        );
        expect(store.countInstancesOfComponent('comp_test'), 2);

        // Non-existent returns 0
        expect(store.countInstancesOfComponent('nonexistent'), 0);
      });
    });

    group('CreateComponentCommand', () {
      test('creates component from single selected node', () {
        // Add a container with children to select
        store.applyPatches([
          const InsertNode(Node(
            id: 'n_container',
            name: 'Container',
            type: NodeType.container,
            props: ContainerProps(),
            childIds: ['n_inner'],
          )),
          const InsertNode(Node(
            id: 'n_inner',
            name: 'Inner',
            type: NodeType.text,
            props: TextProps(text: 'Hello'),
          )),
          const AttachChild(parentId: 'n_root', childId: 'n_container'),
        ]);

        final command = CreateComponentCommand(
          store: store,
          selectedDocIds: {'n_container'},
        );

        final componentId = command.execute();

        // Component created
        expect(store.document.components.containsKey(componentId), true);

        // Original node replaced with instance
        expect(store.document.nodes.containsKey('n_container'), false);
        expect(store.document.nodes.containsKey('n_inner'), false);

        // Instance exists in place
        final rootChildren = store.document.nodes['n_root']!.childIds;
        final instanceId = rootChildren.firstWhere((id) => id.startsWith('inst_'));
        final instance = store.document.nodes[instanceId]!;
        expect(instance.type, NodeType.instance);
        expect((instance.props as InstanceProps).componentId, componentId);
      });

      test('generates unique IDs despite duplicate names', () {
        // Add two nodes with same name "Container"
        store.applyPatches([
          const InsertNode(Node(
            id: 'n_container1',
            name: 'Container',
            type: NodeType.container,
            props: ContainerProps(),
            childIds: ['n_container2'],
          )),
          const InsertNode(Node(
            id: 'n_container2',
            name: 'Container', // Same name!
            type: NodeType.container,
            props: ContainerProps(),
          )),
          const AttachChild(parentId: 'n_root', childId: 'n_container1'),
        ]);

        final command = CreateComponentCommand(
          store: store,
          selectedDocIds: {'n_container1'},
        );

        final componentId = command.execute();

        // Verify unique IDs
        final componentNodes = store.document.nodes.entries
            .where((e) => e.value.sourceComponentId == componentId)
            .toList();

        // Should have 2 nodes with different IDs and templateUids
        expect(componentNodes.length, 2);

        final ids = componentNodes.map((e) => e.key).toSet();
        final templateUids =
            componentNodes.map((e) => e.value.templateUid).toSet();

        expect(ids.length, 2); // Unique IDs
        expect(templateUids.length, 2); // Unique templateUids
      });

      test('fails with empty selection', () {
        expect(
          () => CreateComponentCommand(
            store: store,
            selectedDocIds: <String>{},
          ).execute(),
          throwsArgumentError,
        );
      });

      test('fails with multiple selection', () {
        expect(
          () => CreateComponentCommand(
            store: store,
            selectedDocIds: {'n_root', 'n_child1'},
          ).execute(),
          throwsArgumentError,
        );
      });

      test('fails with instance selection', () {
        // Add an instance first
        final component = ComponentDef(
          id: 'comp_test',
          name: 'Test',
          rootNodeId: 'comp_test::root',
          createdAt: now,
          updatedAt: now,
        );

        store.createComponent(
          component: component,
          nodes: [
            const Node(
              id: 'comp_test::root',
              name: 'Root',
              type: NodeType.container,
              props: ContainerProps(),
              sourceComponentId: 'comp_test',
              templateUid: 'root',
            ),
          ],
        );

        store.addNode(
          const Node(
            id: 'inst_1',
            name: 'Instance',
            type: NodeType.instance,
            props: InstanceProps(componentId: 'comp_test'),
          ),
          parentId: 'n_root',
        );

        expect(
          () => CreateComponentCommand(
            store: store,
            selectedDocIds: {'inst_1'},
          ).execute(),
          throwsArgumentError,
        );
      });

      test('fails with root node (no parent)', () {
        expect(
          () => CreateComponentCommand(
            store: store,
            selectedDocIds: {'n_root'},
          ).execute(),
          throwsArgumentError,
        );
      });

      test('preserves custom component name', () {
        store.applyPatches([
          const InsertNode(Node(
            id: 'n_box',
            name: 'Box',
            type: NodeType.container,
            props: ContainerProps(),
          )),
          const AttachChild(parentId: 'n_root', childId: 'n_box'),
        ]);

        final command = CreateComponentCommand(
          store: store,
          selectedDocIds: {'n_box'},
        );

        final componentId = command.execute(componentName: 'My Custom Button');

        expect(
          store.document.components[componentId]?.name,
          'My Custom Button',
        );
      });

      test('uses node name as default component name', () {
        store.applyPatches([
          const InsertNode(Node(
            id: 'n_fancy_button',
            name: 'Fancy Button',
            type: NodeType.container,
            props: ContainerProps(),
          )),
          const AttachChild(parentId: 'n_root', childId: 'n_fancy_button'),
        ]);

        final command = CreateComponentCommand(
          store: store,
          selectedDocIds: {'n_fancy_button'},
        );

        final componentId = command.execute();

        expect(
          store.document.components[componentId]?.name,
          'Fancy Button',
        );
      });

      test('instance replaces original at same position', () {
        // Add multiple children to root
        store.applyPatches([
          const InsertNode(Node(
            id: 'n_first',
            name: 'First',
            type: NodeType.container,
            props: ContainerProps(),
          )),
          const InsertNode(Node(
            id: 'n_second',
            name: 'Second',
            type: NodeType.container,
            props: ContainerProps(),
          )),
          const InsertNode(Node(
            id: 'n_third',
            name: 'Third',
            type: NodeType.container,
            props: ContainerProps(),
          )),
          const AttachChild(parentId: 'n_root', childId: 'n_first'),
          const AttachChild(parentId: 'n_root', childId: 'n_second'),
          const AttachChild(parentId: 'n_root', childId: 'n_third'),
        ]);

        // n_root children: [n_child1, n_first, n_second, n_third]
        // We'll convert n_second (index 2) to component
        final command = CreateComponentCommand(
          store: store,
          selectedDocIds: {'n_second'},
        );

        command.execute();

        // Instance should be at index 2
        final children = store.document.nodes['n_root']!.childIds;
        expect(children[0], 'n_child1');
        expect(children[1], 'n_first');
        expect(children[2], startsWith('inst_')); // Instance
        expect(children[3], 'n_third');
      });
    });

    group('Patch operations', () {
      test('InsertComponent/RemoveComponent round-trip', () {
        final component = ComponentDef(
          id: 'comp_rt',
          name: 'Round Trip',
          rootNodeId: 'comp_rt::root',
          createdAt: now,
          updatedAt: now,
        );

        // First insert the node that rootNodeId references
        store.applyPatch(
          const InsertNode(Node(
            id: 'comp_rt::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            sourceComponentId: 'comp_rt',
            templateUid: 'root',
          )),
        );

        // Then insert component
        store.applyPatch(InsertComponent(component));

        expect(store.document.components.containsKey('comp_rt'), true);

        // Remove
        store.applyPatch(const RemoveComponent('comp_rt'));

        expect(store.document.components.containsKey('comp_rt'), false);
      });

      test('InsertComponent serialization round-trip', () {
        final component = ComponentDef(
          id: 'comp_serial',
          name: 'Serial',
          rootNodeId: 'comp_serial::root',
          createdAt: now,
          updatedAt: now,
        );

        final op = InsertComponent(component);
        final json = op.toJson();
        final restored = PatchOp.fromJson(json);

        expect(restored, isA<InsertComponent>());
        expect((restored as InsertComponent).component.id, 'comp_serial');
        expect(restored.component.name, 'Serial');
      });

      test('RemoveComponent serialization round-trip', () {
        const op = RemoveComponent('comp_test');
        final json = op.toJson();
        final restored = PatchOp.fromJson(json);

        expect(restored, isA<RemoveComponent>());
        expect((restored as RemoveComponent).componentId, 'comp_test');
      });
    });

    group('Search and filter', () {
      test('search filters components by name (case-insensitive)', () {
        // Create multiple components
        store.createComponent(
          component: ComponentDef(
            id: 'comp_button',
            name: 'Button',
            rootNodeId: 'comp_button::root',
            createdAt: now,
            updatedAt: now,
          ),
          nodes: [
            const Node(
              id: 'comp_button::root',
              name: 'Root',
              type: NodeType.container,
              props: ContainerProps(),
              sourceComponentId: 'comp_button',
              templateUid: 'root',
            ),
          ],
        );

        store.createComponent(
          component: ComponentDef(
            id: 'comp_card',
            name: 'Card',
            rootNodeId: 'comp_card::root',
            createdAt: now,
            updatedAt: now,
          ),
          nodes: [
            const Node(
              id: 'comp_card::root',
              name: 'Root',
              type: NodeType.container,
              props: ContainerProps(),
              sourceComponentId: 'comp_card',
              templateUid: 'root',
            ),
          ],
        );

        store.createComponent(
          component: ComponentDef(
            id: 'comp_badge',
            name: 'Badge',
            rootNodeId: 'comp_badge::root',
            createdAt: now,
            updatedAt: now,
          ),
          nodes: [
            const Node(
              id: 'comp_badge::root',
              name: 'Root',
              type: NodeType.container,
              props: ContainerProps(),
              sourceComponentId: 'comp_badge',
              templateUid: 'root',
            ),
          ],
        );

        final allComponents = store.document.components.values.toList();

        // Filter helper (matches panel logic)
        List<ComponentDef> filter(String query) {
          return allComponents
              .where(
                (c) => c.name.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
        }

        // Test filtering
        expect(filter('Ba').map((c) => c.name), contains('Badge'));
        expect(filter('Ba').map((c) => c.name), isNot(contains('Card')));
        expect(filter('BADGE').map((c) => c.name), contains('Badge')); // case-insensitive
        expect(filter('').length, 3); // Empty shows all
        expect(filter('xyz').length, 0); // No match
      });
    });

    group('Component node ID format', () {
      test('componentNodeId generates correct format', () {
        final result = componentNodeId('comp_123', 'n0');
        expect(result, 'comp_123::n0');
      });

      test('component nodes have sourceComponentId set', () {
        final component = ComponentDef(
          id: 'comp_verify',
          name: 'Verify',
          rootNodeId: 'comp_verify::root',
          createdAt: now,
          updatedAt: now,
        );

        final nodes = [
          const Node(
            id: 'comp_verify::root',
            name: 'Root',
            type: NodeType.container,
            props: ContainerProps(),
            childIds: ['comp_verify::child'],
            sourceComponentId: 'comp_verify',
            templateUid: 'root',
          ),
          const Node(
            id: 'comp_verify::child',
            name: 'Child',
            type: NodeType.text,
            props: TextProps(text: 'Hi'),
            sourceComponentId: 'comp_verify',
            templateUid: 'child',
          ),
        ];

        store.createComponent(component: component, nodes: nodes);

        // Verify all component nodes have correct sourceComponentId
        final compNodes = store.document.nodes.values
            .where((n) => n.sourceComponentId == 'comp_verify')
            .toList();

        expect(compNodes.length, 2);
        expect(compNodes.every((n) => n.id.startsWith('comp_verify::')), true);
      });
    });
  });
}
