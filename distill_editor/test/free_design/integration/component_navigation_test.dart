import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('Component Navigation Integration', () {
    late EditorDocumentStore store;
    late DateTime now;

    setUp(() {
      now = DateTime.now();

      // Create a button component
      final compRoot = Node(
        id: 'comp_button::btn_root',
        name: 'Button Root',
        type: NodeType.container,
        props: const ContainerProps(),
        childIds: const ['comp_button::btn_label'],
        sourceComponentId: 'comp_button',
        templateUid: 'btn_root',
        layout: NodeLayout(
          size: SizeMode.fixed(120, 40),
        ),
      );

      const labelNode = Node(
        id: 'comp_button::btn_label',
        name: 'Label',
        type: NodeType.text,
        props: TextProps(text: 'Click me'),
        sourceComponentId: 'comp_button',
        templateUid: 'btn_label',
      );

      final component = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        createdAt: now,
        updatedAt: now,
      );

      // Create a design frame with an instance
      const frameRoot = Node(
        id: 'n_root',
        name: 'Frame Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['inst_btn1'],
      );

      const instanceNode = Node(
        id: 'inst_btn1',
        name: 'Button Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_button'),
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
          .withNode(labelNode)
          .withComponent(component)
          .withNode(frameRoot)
          .withNode(instanceNode)
          .withFrame(frame);

      store = EditorDocumentStore(document: doc);
    });

    group('Frame Kind', () {
      test('design frame has FrameKind.design by default', () {
        final frame = store.document.frames['f_main']!;
        expect(frame.kind, FrameKind.design);
        expect(frame.componentId, isNull);
      });
    });

    group('createComponentFrame', () {
      test('creates frame with FrameKind.component', () {
        final frame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        expect(frame.kind, FrameKind.component);
        expect(frame.componentId, 'comp_button');
      });

      test('frame.rootNodeId matches component.rootNodeId', () {
        final frame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        final component = store.document.components['comp_button']!;
        expect(frame.rootNodeId, component.rootNodeId);
      });

      test('frame name matches component name', () {
        final frame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        expect(frame.name, 'Button');
      });

      test('frame size is derived from component root node', () {
        final frame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        // Component root has fixed size 120x40
        expect(frame.canvas.size, const Size(120, 40));
      });

      test('frame is added to document', () {
        final frame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        expect(store.document.frames[frame.id], isNotNull);
        expect(store.document.frames[frame.id]!.kind, FrameKind.component);
      });

      test('throws ArgumentError for non-existent component', () {
        expect(
          () => store.createComponentFrame(
            componentId: 'non_existent',
            position: Offset.zero,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('findComponentFrame', () {
      test('returns null when no component frame exists', () {
        // Use document directly to check - simulating what CanvasState would do
        String? findComponentFrame(String componentId) {
          for (final frame in store.document.frames.values) {
            if (frame.kind == FrameKind.component &&
                frame.componentId == componentId) {
              return frame.id;
            }
          }
          return null;
        }

        expect(findComponentFrame('comp_button'), isNull);
      });

      test('returns frame ID when component frame exists', () {
        // Create a component frame
        final createdFrame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        // Simulate findComponentFrame
        String? findComponentFrame(String componentId) {
          for (final frame in store.document.frames.values) {
            if (frame.kind == FrameKind.component &&
                frame.componentId == componentId) {
              return frame.id;
            }
          }
          return null;
        }

        expect(findComponentFrame('comp_button'), createdFrame.id);
      });

      test('returns null for design frames even with matching name', () {
        // The design frame exists but it's not a component frame
        String? findComponentFrame(String componentId) {
          for (final frame in store.document.frames.values) {
            if (frame.kind == FrameKind.component &&
                frame.componentId == componentId) {
              return frame.id;
            }
          }
          return null;
        }

        // f_main is a design frame, not a component frame
        expect(findComponentFrame('f_main'), isNull);
      });
    });

    group('Component frame behavior', () {
      test('component frame shares component root node', () {
        final frame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        // The frame's root node is the actual component's root node
        final rootNode = store.document.nodes[frame.rootNodeId];
        expect(rootNode, isNotNull);
        expect(rootNode!.sourceComponentId, 'comp_button');
      });

      test('multiple component frames can exist for different components', () {
        // Create a second component
        final comp2Root = Node(
          id: 'comp_icon::icon_root',
          name: 'Icon Root',
          type: NodeType.container,
          props: const ContainerProps(),
          sourceComponentId: 'comp_icon',
          templateUid: 'icon_root',
          layout: NodeLayout(
            size: SizeMode.fixed(24, 24),
          ),
        );

        final comp2 = ComponentDef(
          id: 'comp_icon',
          name: 'Icon',
          rootNodeId: 'comp_icon::icon_root',
          createdAt: now,
          updatedAt: now,
        );

        // Add node via patch, then add component via withComponent and recreate store
        store.applyPatches([
          InsertNode(comp2Root),
        ], label: 'Add icon node');

        // Add component by recreating store with updated document
        final updatedDoc = store.document.withComponent(comp2);
        store = EditorDocumentStore(document: updatedDoc);

        // Create frames for both components
        final buttonFrame = store.createComponentFrame(
          componentId: 'comp_button',
          position: const Offset(500, 0),
        );

        final iconFrame = store.createComponentFrame(
          componentId: 'comp_icon',
          position: const Offset(700, 0),
        );

        expect(buttonFrame.componentId, 'comp_button');
        expect(iconFrame.componentId, 'comp_icon');
        expect(buttonFrame.id, isNot(iconFrame.id));
      });
    });
  });
}
