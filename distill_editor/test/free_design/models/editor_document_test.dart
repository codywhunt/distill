import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('EditorDocument', () {
    late EditorDocument emptyDoc;
    late Node rootNode;
    late Node childNode;
    late Frame frame;

    setUp(() {
      emptyDoc = EditorDocument.empty(documentId: 'doc_test');

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
    });

    test('empty document has no frames or nodes', () {
      expect(emptyDoc.frames, isEmpty);
      expect(emptyDoc.nodes, isEmpty);
      expect(emptyDoc.components, isEmpty);
    });

    test('withNode adds node to document', () {
      final doc = emptyDoc.withNode(rootNode);

      expect(doc.nodes.length, 1);
      expect(doc.nodes['n_root'], rootNode);
      expect(emptyDoc.nodes, isEmpty); // Original unchanged
    });

    test('withoutNode removes node from document', () {
      final doc = emptyDoc.withNode(rootNode).withNode(childNode);
      final updated = doc.withoutNode('n_child');

      expect(updated.nodes.length, 1);
      expect(updated.nodes.containsKey('n_child'), false);
    });

    test('withFrame adds frame to document', () {
      final doc = emptyDoc.withFrame(frame);

      expect(doc.frames.length, 1);
      expect(doc.frames['f_main'], frame);
    });

    test('withoutFrame removes frame from document', () {
      final doc = emptyDoc.withFrame(frame);
      final updated = doc.withoutFrame('f_main');

      expect(updated.frames, isEmpty);
    });

    test('buildParentIndex returns correct mappings', () {
      final doc = emptyDoc.withNode(rootNode).withNode(childNode);
      final index = doc.buildParentIndex();

      expect(index['n_child'], 'n_root');
      expect(index.containsKey('n_root'), false); // Root has no parent
    });

    test('JSON round-trip preserves document', () {
      final now = DateTime.now();
      final doc = emptyDoc
          .withNode(rootNode)
          .withNode(childNode)
          .withFrame(frame)
          .withComponent(
            ComponentDef(
              id: 'comp_button',
              name: 'Button',
              rootNodeId: 'n_button_root',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final json = doc.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = EditorDocument.fromJson(decoded);

      expect(restored.nodes.length, doc.nodes.length);
      expect(restored.frames.length, doc.frames.length);
      expect(restored.components.length, doc.components.length);
      expect(restored.nodes['n_root']?.name, 'Root Container');
      expect(restored.frames['f_main']?.name, 'Main Frame');
    });

    test('copyWith creates modified copy', () {
      final doc = emptyDoc.withNode(rootNode).withFrame(frame);

      final newNodes = Map<String, Node>.from(doc.nodes);
      newNodes['n_new'] = const Node(
        id: 'n_new',
        type: NodeType.spacer,
        props: SpacerProps(),
      );

      final modified = doc.copyWith(nodes: newNodes);

      expect(modified.nodes.length, 2);
      expect(doc.nodes.length, 1); // Original unchanged
    });

    test('getSubtree returns all descendants', () {
      final doc = emptyDoc.withNode(rootNode).withNode(childNode);
      final subtree = doc.getSubtree('n_root');

      expect(subtree, contains('n_root'));
      expect(subtree, contains('n_child'));
      expect(subtree.length, 2);
    });
  });

  group('ComponentDef', () {
    test('creates with required fields', () {
      final now = DateTime.now();
      final comp = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'n_card_root',
        createdAt: now,
        updatedAt: now,
      );

      expect(comp.id, 'comp_card');
      expect(comp.name, 'Card');
      expect(comp.rootNodeId, 'n_card_root');
      expect(comp.description, isNull);
      expect(comp.exposedProps, isEmpty);
    });

    test('JSON round-trip preserves data', () {
      final createdAt = DateTime(2024, 1, 15, 10, 30);
      final updatedAt = DateTime(2024, 1, 15, 14, 45);
      final comp = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'n_button_root',
        description: 'A reusable button component',
        exposedProps: {'label': 'Click Me', 'variant': 'primary'},
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final json = comp.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = ComponentDef.fromJson(decoded);

      expect(restored.id, comp.id);
      expect(restored.name, comp.name);
      expect(restored.rootNodeId, comp.rootNodeId);
      expect(restored.description, comp.description);
      expect(restored.exposedProps['label'], 'Click Me');
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, updatedAt);
    });

    test('copyWith creates modified copy', () {
      final now = DateTime.now();
      final comp = ComponentDef(
        id: 'comp_card',
        name: 'Card',
        rootNodeId: 'n_card_root',
        createdAt: now,
        updatedAt: now,
      );

      final modified = comp.copyWith(name: 'Updated Card');

      expect(modified.name, 'Updated Card');
      expect(modified.id, comp.id);
      expect(comp.name, 'Card'); // Original unchanged
    });
  });
}
