import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('RenderCompiler', () {
    late RenderCompiler compiler;
    late TokenResolver tokens;

    setUp(() {
      tokens = TokenResolver.defaults();
      compiler = RenderCompiler(tokens: tokens);
    });

    ExpandedScene createScene(List<ExpandedNode> nodes, String rootId) {
      return ExpandedScene(
        frameId: 'f_main',
        rootId: rootId,
        nodes: {for (final n in nodes) n.id: n},
        patchTarget: {for (final n in nodes) n.id: n.patchTargetId},
      );
    }

    group('node type mapping', () {
      test('maps container without auto-layout to box', () {
        final node = ExpandedNode(
          id: 'n_box',
          patchTargetId: 'n_box',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_box');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_box']!.type, RenderNodeType.box);
      });

      test('maps container with horizontal auto-layout to row', () {
        final node = ExpandedNode(
          id: 'n_row',
          patchTargetId: 'n_row',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.horizontal),
          ),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_row');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_row']!.type, RenderNodeType.row);
      });

      test('maps container with vertical auto-layout to column', () {
        final node = ExpandedNode(
          id: 'n_col',
          patchTargetId: 'n_col',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(
            autoLayout: AutoLayout(direction: LayoutDirection.vertical),
          ),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_col');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_col']!.type, RenderNodeType.column);
      });

      test('maps text node to text', () {
        final node = ExpandedNode(
          id: 'n_text',
          patchTargetId: 'n_text',
          type: NodeType.text,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const TextProps(text: 'Hello'),
        );

        final scene = createScene([node], 'n_text');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_text']!.type, RenderNodeType.text);
      });

      test('maps image node to image', () {
        final node = ExpandedNode(
          id: 'n_img',
          patchTargetId: 'n_img',
          type: NodeType.image,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const ImageProps(src: 'https://example.com/image.png'),
        );

        final scene = createScene([node], 'n_img');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_img']!.type, RenderNodeType.image);
      });

      test('maps icon node to icon', () {
        final node = ExpandedNode(
          id: 'n_icon',
          patchTargetId: 'n_icon',
          type: NodeType.icon,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const IconProps(icon: 'home'),
        );

        final scene = createScene([node], 'n_icon');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_icon']!.type, RenderNodeType.icon);
      });

      test('maps spacer node to spacer', () {
        final node = ExpandedNode(
          id: 'n_spacer',
          patchTargetId: 'n_spacer',
          type: NodeType.spacer,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const SpacerProps(flex: 2),
        );

        final scene = createScene([node], 'n_spacer');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_spacer']!.type, RenderNodeType.spacer);
      });
    });

    group('layout properties', () {
      test('compiles absolute position', () {
        final node = ExpandedNode(
          id: 'n_abs',
          patchTargetId: 'n_abs',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(
            position: PositionModeAbsolute(x: 100, y: 200),
          ),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_abs');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_abs']!.props['positionMode'], 'absolute');
        expect(doc.nodes['n_abs']!.props['x'], 100.0);
        expect(doc.nodes['n_abs']!.props['y'], 200.0);
      });

      test('compiles fixed size', () {
        final node = ExpandedNode(
          id: 'n_fixed',
          patchTargetId: 'n_fixed',
          type: NodeType.container,
          childIds: const [],
          layout: NodeLayout(size: SizeMode.fixed(120, 40)),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_fixed');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_fixed']!.props['widthMode'], 'fixed');
        expect(doc.nodes['n_fixed']!.props['width'], 120.0);
        expect(doc.nodes['n_fixed']!.props['heightMode'], 'fixed');
        expect(doc.nodes['n_fixed']!.props['height'], 40.0);
      });

      test('compiles per-axis sizing: fixed width with hug height', () {
        final node = ExpandedNode(
          id: 'n_mixed',
          patchTargetId: 'n_mixed',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(
            size: SizeMode(width: AxisSizeFixed(200), height: AxisSizeHug()),
          ),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_mixed');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_mixed']!.props['widthMode'], 'fixed');
        expect(doc.nodes['n_mixed']!.props['width'], 200.0);
        expect(doc.nodes['n_mixed']!.props['heightMode'], 'hug');
        expect(doc.nodes['n_mixed']!.props['height'], isNull);
      });

      test('compiles per-axis sizing: fill width with fixed height', () {
        final node = ExpandedNode(
          id: 'n_fill_fixed',
          patchTargetId: 'n_fill_fixed',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(
            size: SizeMode(width: AxisSizeFill(), height: AxisSizeFixed(80)),
          ),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_fill_fixed');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_fill_fixed']!.props['widthMode'], 'fill');
        expect(doc.nodes['n_fill_fixed']!.props['width'], isNull);
        expect(doc.nodes['n_fill_fixed']!.props['heightMode'], 'fixed');
        expect(doc.nodes['n_fill_fixed']!.props['height'], 80.0);
      });

      test('compiles auto-layout properties', () {
        final node = ExpandedNode(
          id: 'n_auto',
          patchTargetId: 'n_auto',
          type: NodeType.container,
          childIds: const [],
          layout: NodeLayout(
            autoLayout: AutoLayout(
              direction: LayoutDirection.horizontal,
              gap: const FixedNumeric(8),
              mainAlign: MainAxisAlignment.center,
              crossAlign: CrossAxisAlignment.stretch,
              padding: TokenEdgePadding.allFixed(16),
            ),
          ),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_auto');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_auto']!.props['direction'], 'horizontal');
        expect(doc.nodes['n_auto']!.props['gap'], 8.0);
        expect(doc.nodes['n_auto']!.props['mainAxisAlignment'], 'center');
        expect(doc.nodes['n_auto']!.props['crossAxisAlignment'], 'stretch');
        expect(doc.nodes['n_auto']!.props['paddingLeft'], 16.0);
        expect(doc.nodes['n_auto']!.props['paddingTop'], 16.0);
      });
    });

    group('style properties', () {
      test('compiles opacity', () {
        final node = ExpandedNode(
          id: 'n_opacity',
          patchTargetId: 'n_opacity',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(opacity: 0.5),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_opacity');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_opacity']!.props['opacity'], 0.5);
      });

      test('compiles solid fill to color', () {
        final node = ExpandedNode(
          id: 'n_fill',
          patchTargetId: 'n_fill',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(fill: SolidFill(HexColor('#FF0000'))),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_fill');
        final doc = compiler.compile(scene);

        final fillColor = doc.nodes['n_fill']!.props['fillColor'] as Color;
        expect(fillColor.value, 0xFFFF0000);
      });

      test('compiles corner radius', () {
        final node = ExpandedNode(
          id: 'n_radius',
          patchTargetId: 'n_radius',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(
            cornerRadius: CornerRadius(
              topLeft: FixedNumeric(4),
              topRight: FixedNumeric(8),
              bottomLeft: FixedNumeric(12),
              bottomRight: FixedNumeric(16),
            ),
          ),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_radius');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_radius']!.props['cornerTopLeft'], 4.0);
        expect(doc.nodes['n_radius']!.props['cornerTopRight'], 8.0);
        expect(doc.nodes['n_radius']!.props['cornerBottomLeft'], 12.0);
        expect(doc.nodes['n_radius']!.props['cornerBottomRight'], 16.0);
      });

      test('compiles stroke properties', () {
        final node = ExpandedNode(
          id: 'n_stroke',
          patchTargetId: 'n_stroke',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(
            stroke: Stroke(
              color: HexColor('#0000FF'),
              width: 2,
              position: StrokePosition.center,
            ),
          ),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_stroke');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_stroke']!.props['strokeWidth'], 2.0);
        expect(doc.nodes['n_stroke']!.props['strokePosition'], 'center');
        final strokeColor =
            doc.nodes['n_stroke']!.props['strokeColor'] as Color;
        expect(strokeColor.value, 0xFF0000FF);
      });

      test('compiles shadow properties', () {
        final node = ExpandedNode(
          id: 'n_shadow',
          patchTargetId: 'n_shadow',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(
            shadow: Shadow(
              color: HexColor('#00000040'),
              offsetX: 0,
              offsetY: 4,
              blur: 8,
              spread: 0,
            ),
          ),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_shadow');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_shadow']!.props['shadowOffsetX'], 0.0);
        expect(doc.nodes['n_shadow']!.props['shadowOffsetY'], 4.0);
        expect(doc.nodes['n_shadow']!.props['shadowBlur'], 8.0);
        expect(doc.nodes['n_shadow']!.props['shadowSpread'], 0.0);
        expect(doc.nodes['n_shadow']!.props['shadowColor'], isA<Color>());
      });
    });

    group('token resolution', () {
      test('resolves token fill to concrete color', () {
        final node = ExpandedNode(
          id: 'n_token',
          patchTargetId: 'n_token',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(fill: TokenFill('color.primary')),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_token');
        final doc = compiler.compile(scene);

        // Should resolve to the default primary color (#007AFF)
        final fillColor = doc.nodes['n_token']!.props['fillColor'] as Color?;
        expect(fillColor, isNotNull);
        expect(fillColor!.value, 0xFF007AFF);
      });

      test('resolves text color token', () {
        final node = ExpandedNode(
          id: 'n_text',
          patchTargetId: 'n_text',
          type: NodeType.text,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const TextProps(text: 'Hello', color: 'color.primary'),
        );

        final scene = createScene([node], 'n_text');
        final doc = compiler.compile(scene);

        final textColor = doc.nodes['n_text']!.props['textColor'] as Color?;
        expect(textColor, isNotNull);
      });
    });

    group('type-specific properties', () {
      test('compiles text properties', () {
        final node = ExpandedNode(
          id: 'n_text',
          patchTargetId: 'n_text',
          type: NodeType.text,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const TextProps(
            text: 'Hello World',
            fontSize: 18,
            fontWeight: 600,
            textAlign: TextAlign.center,
          ),
        );

        final scene = createScene([node], 'n_text');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_text']!.props['text'], 'Hello World');
        expect(doc.nodes['n_text']!.props['fontSize'], 18.0);
        expect(doc.nodes['n_text']!.props['fontWeight'], 600);
        expect(doc.nodes['n_text']!.props['textAlign'], 'center');
      });

      test('compiles image properties', () {
        final node = ExpandedNode(
          id: 'n_img',
          patchTargetId: 'n_img',
          type: NodeType.image,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const ImageProps(
            src: 'https://example.com/image.png',
            fit: ImageFit.contain,
            alt: 'Test image',
          ),
        );

        final scene = createScene([node], 'n_img');
        final doc = compiler.compile(scene);

        expect(
          doc.nodes['n_img']!.props['src'],
          'https://example.com/image.png',
        );
        expect(doc.nodes['n_img']!.props['fit'], 'contain');
        expect(doc.nodes['n_img']!.props['alt'], 'Test image');
      });

      test('compiles icon properties', () {
        final node = ExpandedNode(
          id: 'n_icon',
          patchTargetId: 'n_icon',
          type: NodeType.icon,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const IconProps(icon: 'home', iconSet: 'material', size: 32),
        );

        final scene = createScene([node], 'n_icon');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_icon']!.props['icon'], 'home');
        expect(doc.nodes['n_icon']!.props['iconSet'], 'material');
        expect(doc.nodes['n_icon']!.props['iconSize'], 32.0);
      });

      test('compiles spacer properties', () {
        final node = ExpandedNode(
          id: 'n_spacer',
          patchTargetId: 'n_spacer',
          type: NodeType.spacer,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const SpacerProps(flex: 2),
        );

        final scene = createScene([node], 'n_spacer');
        final doc = compiler.compile(scene);

        expect(doc.nodes['n_spacer']!.props['flex'], 2);
      });
    });

    group('caching', () {
      test('caches compiled nodes', () {
        final node = ExpandedNode(
          id: 'n_cache',
          patchTargetId: 'n_cache',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_cache');

        // Compile twice
        final doc1 = compiler.compile(scene);
        final doc2 = compiler.compile(scene);

        // Should be the same cached node
        expect(identical(doc1.nodes['n_cache'], doc2.nodes['n_cache']), true);
      });

      test('dirty tracking invalidates cache', () {
        final node = ExpandedNode(
          id: 'n_dirty',
          patchTargetId: 'n_dirty',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_dirty');

        final doc1 = compiler.compile(scene);
        compiler.markDirty({'n_dirty'});
        final doc2 = compiler.compile(scene);

        // Should be recompiled (different instance)
        expect(identical(doc1.nodes['n_dirty'], doc2.nodes['n_dirty']), false);
      });

      test('invalidateAll clears all cache', () {
        final node = ExpandedNode(
          id: 'n_all',
          patchTargetId: 'n_all',
          type: NodeType.container,
          childIds: const [],
          layout: const NodeLayout(),
          style: const NodeStyle(),
          props: const ContainerProps(),
        );

        final scene = createScene([node], 'n_all');

        final doc1 = compiler.compile(scene);
        compiler.invalidateAll();
        final doc2 = compiler.compile(scene);

        expect(identical(doc1.nodes['n_all'], doc2.nodes['n_all']), false);
      });
    });
  });

  group('RenderDocument', () {
    test('getNode returns node by ID', () {
      final node = RenderNode(
        id: 'n_test',
        type: RenderNodeType.box,
        props: const {},
        childIds: const [],
      );

      final doc = RenderDocument(rootId: 'n_test', nodes: {'n_test': node});

      expect(doc.getNode('n_test'), node);
      expect(doc.getNode('nonexistent'), null);
    });

    test('isEmpty returns correct value', () {
      final emptyDoc = const RenderDocument(rootId: 'root', nodes: {});
      final nonEmptyDoc = RenderDocument(
        rootId: 'root',
        nodes: {
          'root': RenderNode(
            id: 'root',
            type: RenderNodeType.box,
            props: const {},
            childIds: const [],
          ),
        },
      );

      expect(emptyDoc.isEmpty, true);
      expect(nonEmptyDoc.isEmpty, false);
    });
  });

  group('RenderNode', () {
    test('prop returns typed value', () {
      final node = RenderNode(
        id: 'n_test',
        type: RenderNodeType.box,
        props: {'width': 100.0, 'text': 'Hello', 'visible': true},
        childIds: const [],
      );

      expect(node.prop<double>('width'), 100.0);
      expect(node.prop<String>('text'), 'Hello');
      expect(node.prop<bool>('visible'), true);
      expect(node.prop<int>('missing'), null);
    });

    test('propOr returns default for missing', () {
      final node = RenderNode(
        id: 'n_test',
        type: RenderNodeType.box,
        props: const {},
        childIds: const [],
      );

      expect(node.propOr<double>('width', 50.0), 50.0);
      expect(node.propOr<String>('text', 'default'), 'default');
    });
  });
}
