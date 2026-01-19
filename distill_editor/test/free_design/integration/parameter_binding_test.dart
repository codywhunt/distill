import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('Parameter Binding Integration', () {
    late EditorDocumentStore store;
    late DateTime now;

    setUp(() {
      now = DateTime.now();

      // Create a button component with a label parameter
      const buttonRoot = Node(
        id: 'comp_button::btn_root',
        name: 'Button Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_button::btn_label'],
        sourceComponentId: 'comp_button',
        templateUid: 'btn_root',
        style: NodeStyle(fill: SolidFill(HexColor('#007AFF'))),
      );

      const buttonLabel = Node(
        id: 'comp_button::btn_label',
        name: 'Button Label',
        type: NodeType.text,
        props: TextProps(text: 'Default Button'),
        sourceComponentId: 'comp_button',
        templateUid: 'btn_label',
      );

      final component = ComponentDef(
        id: 'comp_button',
        name: 'Button',
        rootNodeId: 'comp_button::btn_root',
        createdAt: now,
        updatedAt: now,
        params: const [
          ComponentParamDef(
            key: 'label',
            type: ParamType.string,
            defaultValue: 'Click Me',
            group: 'Content',
            binding: ParamBinding(
              targetTemplateUid: 'btn_label',
              bucket: OverrideBucket.props,
              field: ParamField.text,
            ),
          ),
          ComponentParamDef(
            key: 'bgColor',
            type: ParamType.color,
            defaultValue: '#007AFF',
            group: 'Style',
            binding: ParamBinding(
              targetTemplateUid: 'btn_root',
              bucket: OverrideBucket.style,
              field: ParamField.fillColor,
            ),
          ),
        ],
      );

      // Root node
      const rootNode = Node(
        id: 'n_root',
        name: 'Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: [],
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
          .withNode(buttonRoot)
          .withNode(buttonLabel)
          .withNode(rootNode)
          .withComponent(component)
          .withFrame(frame);

      store = EditorDocumentStore(document: doc);
    });

    test('param override via SetProp updates expanded scene', () {
      // Add instance node
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'My Button',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_button'),
      );

      store.applyPatches([
        InsertNode(instanceNode),
        AttachChild(parentId: 'n_root', childId: 'inst_btn'),
      ]);

      // Build initial scene
      const builder = ExpandedSceneBuilder();
      var scene = builder.build('f_main', store.document)!;

      // Verify default is applied
      var expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect((expandedLabel.props as TextProps).text, 'Click Me');
      expect(expandedLabel.origin?.isOverridden, false);

      // Apply param override via SetProp
      store.applyPatches([
        SetProp(
          id: 'inst_btn',
          path: '/props/paramOverrides/label',
          value: 'Submit',
        ),
      ]);

      // Rebuild scene
      scene = builder.build('f_main', store.document)!;

      // Verify override is applied
      expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect((expandedLabel.props as TextProps).text, 'Submit');
      expect(expandedLabel.origin?.isOverridden, true);
    });

    test('reset param by replacing entire paramOverrides map', () {
      // Add instance with param override
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'My Button',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_button',
          paramOverrides: {'label': 'Custom Label'},
        ),
      );

      store.applyPatches([
        InsertNode(instanceNode),
        AttachChild(parentId: 'n_root', childId: 'inst_btn'),
      ]);

      // Build initial scene
      const builder = ExpandedSceneBuilder();
      var scene = builder.build('f_main', store.document)!;

      // Verify override is initially applied
      var expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect((expandedLabel.props as TextProps).text, 'Custom Label');
      expect(expandedLabel.origin?.isOverridden, true);

      // Reset param by replacing the entire paramOverrides map with empty
      store.applyPatches([
        SetProp(
          id: 'inst_btn',
          path: '/props/paramOverrides',
          value: <String, dynamic>{},
        ),
      ]);

      // Rebuild scene
      scene = builder.build('f_main', store.document)!;

      // Verify reverted to default
      expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect((expandedLabel.props as TextProps).text, 'Click Me');
      expect(expandedLabel.origin?.isOverridden, false);
    });

    test('param change updates expanded scene with color', () {
      // Add instance node
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'My Button',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_button'),
      );

      store.applyPatches([
        InsertNode(instanceNode),
        AttachChild(parentId: 'n_root', childId: 'inst_btn'),
      ]);

      // Build initial scene
      const builder = ExpandedSceneBuilder();
      var scene = builder.build('f_main', store.document)!;

      // Verify default color is applied
      var expandedRoot = scene.nodes['inst_btn::comp_button::btn_root']!;
      var fill = expandedRoot.style.fill as SolidFill;
      expect((fill.color as HexColor).hex, '#007AFF');

      // Apply color param override
      store.applyPatches([
        SetProp(
          id: 'inst_btn',
          path: '/props/paramOverrides/bgColor',
          value: '#FF0000',
        ),
      ]);

      // Rebuild scene
      scene = builder.build('f_main', store.document)!;

      // Verify color override is applied
      expandedRoot = scene.nodes['inst_btn::comp_button::btn_root']!;
      fill = expandedRoot.style.fill as SolidFill;
      expect((fill.color as HexColor).hex, '#FF0000');
    });

    test('multiple params can be set independently', () {
      // Add instance node
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'My Button',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_button'),
      );

      store.applyPatches([
        InsertNode(instanceNode),
        AttachChild(parentId: 'n_root', childId: 'inst_btn'),
      ]);

      const builder = ExpandedSceneBuilder();

      // Set label only
      store.applyPatches([
        SetProp(
          id: 'inst_btn',
          path: '/props/paramOverrides/label',
          value: 'Custom Label',
        ),
      ]);

      var scene = builder.build('f_main', store.document)!;
      var expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      var expandedRoot = scene.nodes['inst_btn::comp_button::btn_root']!;

      // Label overridden, color uses default
      expect((expandedLabel.props as TextProps).text, 'Custom Label');
      expect(expandedLabel.origin?.isOverridden, true);
      expect(((expandedRoot.style.fill as SolidFill).color as HexColor).hex, '#007AFF');
      expect(expandedRoot.origin?.isOverridden, false);

      // Now also set color
      store.applyPatches([
        SetProp(
          id: 'inst_btn',
          path: '/props/paramOverrides/bgColor',
          value: '#00FF00',
        ),
      ]);

      scene = builder.build('f_main', store.document)!;
      expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expandedRoot = scene.nodes['inst_btn::comp_button::btn_root']!;

      // Both overridden
      expect((expandedLabel.props as TextProps).text, 'Custom Label');
      expect(expandedLabel.origin?.isOverridden, true);
      expect(((expandedRoot.style.fill as SolidFill).color as HexColor).hex, '#00FF00');
      expect(expandedRoot.origin?.isOverridden, true);
    });

    test('undo restores previous param value', () {
      // Add instance with initial param override
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'My Button',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_button',
          paramOverrides: {'label': 'Initial'},
        ),
      );

      store.applyPatches([
        InsertNode(instanceNode),
        AttachChild(parentId: 'n_root', childId: 'inst_btn'),
      ], label: 'Add button instance');

      const builder = ExpandedSceneBuilder();

      // Change the param by replacing the entire map
      store.applyPatches([
        SetProp(
          id: 'inst_btn',
          path: '/props/paramOverrides',
          value: <String, dynamic>{'label': 'Changed'},
        ),
      ], label: 'Change label param');

      var scene = builder.build('f_main', store.document)!;
      var expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect((expandedLabel.props as TextProps).text, 'Changed');

      // Undo the change
      store.undo();

      scene = builder.build('f_main', store.document)!;
      expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect((expandedLabel.props as TextProps).text, 'Initial');
    });

    test('param override persists through document round-trip', () {
      // Add instance with param override
      const instanceNode = Node(
        id: 'inst_btn',
        name: 'My Button',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_button',
          paramOverrides: {'label': 'Persisted Label'},
        ),
      );

      store.applyPatches([
        InsertNode(instanceNode),
        AttachChild(parentId: 'n_root', childId: 'inst_btn'),
      ]);

      // Serialize and deserialize
      final json = store.document.toJson();
      final restoredDoc = EditorDocument.fromJson(json);
      final restoredStore = EditorDocumentStore(document: restoredDoc);

      // Build scene from restored document
      const builder = ExpandedSceneBuilder();
      final scene = builder.build('f_main', restoredStore.document)!;

      final expandedLabel = scene.nodes['inst_btn::comp_button::btn_label']!;
      expect((expandedLabel.props as TextProps).text, 'Persisted Label');
    });

    test('nested instances with params work correctly', () {
      // Create an outer component that contains a button instance
      const outerRoot = Node(
        id: 'comp_outer::root',
        name: 'Outer Root',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['comp_outer::inner_btn'],
        sourceComponentId: 'comp_outer',
        templateUid: 'root',
      );

      const innerBtnInOuter = Node(
        id: 'comp_outer::inner_btn',
        name: 'Inner Button',
        type: NodeType.instance,
        props: InstanceProps(
          componentId: 'comp_button',
          paramOverrides: {'label': 'Inner Default'},
        ),
        sourceComponentId: 'comp_outer',
        templateUid: 'inner_btn',
      );

      final outerComponent = ComponentDef(
        id: 'comp_outer',
        name: 'Outer',
        rootNodeId: 'comp_outer::root',
        createdAt: now,
        updatedAt: now,
      );

      // Add outer component
      store.applyPatches([
        InsertNode(outerRoot),
        InsertNode(innerBtnInOuter),
      ]);

      // Manually add component since there's no InsertComponent patch
      final updatedDoc = store.document.withComponent(outerComponent);
      store = EditorDocumentStore(document: updatedDoc);

      // Create instance of outer component
      const outerInstance = Node(
        id: 'inst_outer',
        name: 'Outer Instance',
        type: NodeType.instance,
        props: InstanceProps(componentId: 'comp_outer'),
      );

      store.applyPatches([
        InsertNode(outerInstance),
        AttachChild(parentId: 'n_root', childId: 'inst_outer'),
      ]);

      const builder = ExpandedSceneBuilder();
      final scene = builder.build('f_main', store.document)!;

      // The nested button should have its param applied
      // ID format: inst_outer::comp_outer::inner_btn::comp_button::btn_label
      final nestedLabelKey = scene.nodes.keys.firstWhere(
        (k) => k.contains('inst_outer') && k.contains('btn_label'),
      );
      final nestedLabel = scene.nodes[nestedLabelKey]!;
      expect((nestedLabel.props as TextProps).text, 'Inner Default');
    });
  });
}
