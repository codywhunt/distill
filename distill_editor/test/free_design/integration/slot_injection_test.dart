import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('Slot Injection Integration', () {
    late EditorDocumentStore store;
    late DateTime now;

    setUp(() {
      now = DateTime.now();

      // Create a component with a slot
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
          .withNode(compRoot)
          .withNode(slotNode)
          .withComponent(component)
          .withFrame(frame);

      store = EditorDocumentStore(document: doc);
    });

    test('delete instance cleans up slot content', () {
      // Add slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Add instance with slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      // Add root node
      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      // Add nodes to document
      store.applyPatches([
        InsertNode(slotContent),
        InsertNode(instanceNode),
        InsertNode(rootNode),
        AttachChild(parentId: 'n_root', childId: 'inst_card'),
      ]);

      // Verify slot content exists
      expect(store.document.nodes.containsKey('slot_content_1'), true);
      expect(store.document.nodes.containsKey('inst_card'), true);

      // Delete instance
      store.removeNode('inst_card');

      // Verify slot content is also deleted
      expect(store.document.nodes.containsKey('slot_content_1'), false);
      expect(store.document.nodes.containsKey('inst_card'), false);
    });

    test('clear slot deletes old content', () {
      // Add slot content node
      const slotContent = Node(
        id: 'slot_content_1',
        name: 'My Content',
        type: NodeType.text,
        props: TextProps(text: 'Hello Slot!'),
        ownerInstanceId: 'inst_card',
      );

      // Add instance with slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_1')},
        ),
      );

      // Add root node
      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      // Add nodes to document
      store.applyPatches([
        InsertNode(slotContent),
        InsertNode(instanceNode),
        InsertNode(rootNode),
        AttachChild(parentId: 'n_root', childId: 'inst_card'),
      ]);

      // Verify slot content exists
      expect(store.document.nodes.containsKey('slot_content_1'), true);

      // Clear slot
      store.clearSlotContent('inst_card', 'content');

      // Verify slot content is deleted
      expect(store.document.nodes.containsKey('slot_content_1'), false);

      // Verify instance still exists but without slot assignment
      expect(store.document.nodes.containsKey('inst_card'), true);
      final instance = store.document.nodes['inst_card']!;
      final props = instance.props as InstanceProps;
      expect(props.slots.containsKey('content'), false);
    });

    test('delete instance cleans up nested slot content', () {
      // Add nested slot content
      const slotContentChild = Node(
        id: 'slot_content_child',
        name: 'Nested Text',
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

      // Add instance with slot assignment
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_card',
          slots: {'content': SlotAssignment(rootNodeId: 'slot_content_root')},
        ),
      );

      // Add root node
      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      // Add nodes to document
      store.applyPatches([
        InsertNode(slotContentChild),
        InsertNode(slotContentRoot),
        AttachChild(parentId: 'slot_content_root', childId: 'slot_content_child'),
        InsertNode(instanceNode),
        InsertNode(rootNode),
        AttachChild(parentId: 'n_root', childId: 'inst_card'),
      ]);

      // Verify all slot content exists
      expect(store.document.nodes.containsKey('slot_content_root'), true);
      expect(store.document.nodes.containsKey('slot_content_child'), true);

      // Delete instance
      store.removeNode('inst_card');

      // Verify all slot content is deleted
      expect(store.document.nodes.containsKey('slot_content_root'), false);
      expect(store.document.nodes.containsKey('slot_content_child'), false);
    });

    test('collectOwnedSubtrees returns all owned nodes', () {
      // Add nested slot content
      const slotContentChild = Node(
        id: 'slot_content_child',
        name: 'Nested Text',
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

      // Add instance
      const instanceNode = Node(
        id: 'inst_card',
        name: 'Card Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_card'),
      );

      // Add root node
      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_card'],
      );

      // Add nodes to document
      store.applyPatches([
        InsertNode(slotContentChild),
        InsertNode(slotContentRoot),
        AttachChild(parentId: 'slot_content_root', childId: 'slot_content_child'),
        InsertNode(instanceNode),
        InsertNode(rootNode),
        AttachChild(parentId: 'n_root', childId: 'inst_card'),
      ]);

      // Collect owned subtrees
      final owned = store.collectOwnedSubtrees('inst_card');

      // Should include both the root and child
      expect(owned, contains('slot_content_root'));
      expect(owned, contains('slot_content_child'));
      expect(owned.length, 2);
    });
  });
}
