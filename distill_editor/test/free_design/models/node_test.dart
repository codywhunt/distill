import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  group('Node', () {
    test('creates with required fields', () {
      final node = Node(
        id: 'n_test',
        type: NodeType.container,
        props: ContainerProps(),
      );

      expect(node.id, 'n_test');
      expect(node.type, NodeType.container);
      expect(node.name, '');
      expect(node.childIds, isEmpty);
    });

    test('JSON round-trip preserves data', () {
      final node = Node(
        id: 'n_button',
        name: 'Submit Button',
        type: NodeType.container,
        props: ContainerProps(clipContent: true),
        layout: NodeLayout(
          position: const PositionModeAbsolute(x: 100, y: 200),
          size: SizeMode.fixed(120, 40),
          autoLayout: const AutoLayout(
            direction: LayoutDirection.horizontal,
            gap: FixedNumeric(8),
          ),
        ),
        style: NodeStyle(
          fill: SolidFill(const HexColor('#007AFF')),
          cornerRadius: CornerRadius.circular(8),
          opacity: 0.9,
        ),
        childIds: ['n_child1', 'n_child2'],
      );

      final json = node.toJson();
      final encoded = jsonEncode(json);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = Node.fromJson(decoded);

      expect(restored.id, node.id);
      expect(restored.name, node.name);
      expect(restored.type, node.type);
      expect(restored.childIds, node.childIds);
      expect(restored.layout.position, isA<PositionModeAbsolute>());
      expect(restored.layout.size, isA<SizeMode>());
      expect(restored.layout.size.width, isA<AxisSizeFixed>());
      expect(restored.layout.size.height, isA<AxisSizeFixed>());
      expect(restored.style.opacity, 0.9);
    });

    test('copyWith creates modified copy', () {
      final node = Node(
        id: 'n_test',
        name: 'Original',
        type: NodeType.text,
        props: TextProps(text: 'Hello'),
      );

      final modified = node.copyWith(name: 'Modified');

      expect(modified.name, 'Modified');
      expect(modified.id, node.id);
      expect(node.name, 'Original'); // Original unchanged
    });
  });

  group('NodeType', () {
    test('all types serialize correctly', () {
      for (final type in NodeType.values) {
        final json = type.toJson();
        final restored = NodeType.fromJson(json);
        expect(restored, type);
      }
    });
  });

  group('NodeLayout', () {
    test('PositionMode serializes with mode field', () {
      const auto = PositionModeAuto();
      expect(auto.toJson(), {'mode': 'auto'});

      const absolute = PositionModeAbsolute(x: 10, y: 20);
      expect(absolute.toJson(), {'mode': 'absolute', 'x': 10.0, 'y': 20.0});
    });

    test('AxisSize variants serialize correctly', () {
      const hug = AxisSizeHug();
      expect(hug.toJson(), {'mode': 'hug'});

      const fill = AxisSizeFill();
      expect(fill.toJson(), {'mode': 'fill'});

      const fixed = AxisSizeFixed(100);
      expect(fixed.toJson(), {'mode': 'fixed', 'value': 100.0});
    });

    test('AxisSize round-trip', () {
      const hug = AxisSizeHug();
      final hugRestored = AxisSize.fromJson(hug.toJson());
      expect(hugRestored, isA<AxisSizeHug>());

      const fill = AxisSizeFill();
      final fillRestored = AxisSize.fromJson(fill.toJson());
      expect(fillRestored, isA<AxisSizeFill>());

      const fixed = AxisSizeFixed(120);
      final fixedRestored = AxisSize.fromJson(fixed.toJson());
      expect(fixedRestored, isA<AxisSizeFixed>());
      expect((fixedRestored as AxisSizeFixed).value, 120.0);
    });

    test('SizeMode with per-axis modes serializes correctly', () {
      // Both hug
      const bothHug = SizeMode.hug();
      expect(bothHug.toJson(), {
        'width': {'mode': 'hug'},
        'height': {'mode': 'hug'},
      });

      // Both fill
      const bothFill = SizeMode.fill();
      expect(bothFill.toJson(), {
        'width': {'mode': 'fill'},
        'height': {'mode': 'fill'},
      });

      // Both fixed
      final bothFixed = SizeMode.fixed(100, 50);
      expect(bothFixed.toJson(), {
        'width': {'mode': 'fixed', 'value': 100.0},
        'height': {'mode': 'fixed', 'value': 50.0},
      });

      // Mixed: fixed width, hug height
      const mixedFixedHug = SizeMode(
        width: AxisSizeFixed(200),
        height: AxisSizeHug(),
      );
      expect(mixedFixedHug.toJson(), {
        'width': {'mode': 'fixed', 'value': 200.0},
        'height': {'mode': 'hug'},
      });

      // Mixed: fill width, fixed height
      const mixedFillFixed = SizeMode(
        width: AxisSizeFill(),
        height: AxisSizeFixed(80),
      );
      expect(mixedFillFixed.toJson(), {
        'width': {'mode': 'fill'},
        'height': {'mode': 'fixed', 'value': 80.0},
      });
    });

    test('SizeMode round-trip preserves per-axis modes', () {
      const size = SizeMode(width: AxisSizeFixed(100), height: AxisSizeHug());

      final json = size.toJson();
      final restored = SizeMode.fromJson(json);

      expect(restored.width, isA<AxisSizeFixed>());
      expect((restored.width as AxisSizeFixed).value, 100.0);
      expect(restored.height, isA<AxisSizeHug>());
    });

    test('SizeMode.fromLegacyJson migrates old format', () {
      // Old hug format
      final legacyHug = SizeMode.fromLegacyJson({'mode': 'hug'});
      expect(legacyHug.width, isA<AxisSizeHug>());
      expect(legacyHug.height, isA<AxisSizeHug>());

      // Old fill format
      final legacyFill = SizeMode.fromLegacyJson({'mode': 'fill'});
      expect(legacyFill.width, isA<AxisSizeFill>());
      expect(legacyFill.height, isA<AxisSizeFill>());

      // Old fixed format
      final legacyFixed = SizeMode.fromLegacyJson({
        'mode': 'fixed',
        'width': 100,
        'height': 50,
      });
      expect(legacyFixed.width, isA<AxisSizeFixed>());
      expect((legacyFixed.width as AxisSizeFixed).value, 100.0);
      expect(legacyFixed.height, isA<AxisSizeFixed>());
      expect((legacyFixed.height as AxisSizeFixed).value, 50.0);

      // New format falls through to regular fromJson
      final newFormat = SizeMode.fromLegacyJson({
        'width': {'mode': 'fixed', 'value': 200},
        'height': {'mode': 'hug'},
      });
      expect(newFormat.width, isA<AxisSizeFixed>());
      expect((newFormat.width as AxisSizeFixed).value, 200.0);
      expect(newFormat.height, isA<AxisSizeHug>());
    });

    test('AutoLayout round-trip', () {
      final layout = AutoLayout(
        direction: LayoutDirection.horizontal,
        mainAlign: MainAxisAlignment.spaceBetween,
        crossAlign: CrossAxisAlignment.center,
        gap: const FixedNumeric(16),
        padding: TokenEdgePadding.allFixed(8),
      );

      final json = layout.toJson();
      final restored = AutoLayout.fromJson(json);

      expect(restored.direction, layout.direction);
      expect(restored.mainAlign, layout.mainAlign);
      expect(restored.crossAlign, layout.crossAlign);
      expect(restored.gap, layout.gap);
      expect(restored.padding.top.toDouble(), 8.0);
    });
  });

  group('NodeStyle', () {
    test('Fill variants serialize correctly', () {
      final solid = SolidFill(const HexColor('#FF0000'));
      expect(solid.toJson()['type'], 'solid');

      const token = TokenFill('colors.primary');
      expect(token.toJson()['type'], 'token');

      final gradient = GradientFill(
        gradientType: GradientType.linear,
        stops: [
          const GradientStop(position: 0, color: HexColor('#FF0000')),
          const GradientStop(position: 1, color: HexColor('#0000FF')),
        ],
        angle: 45,
      );
      expect(gradient.toJson()['type'], 'gradient');
    });

    test('HexColor converts to Color', () {
      const hex = HexColor('#FF5500');
      final color = hex.toColor();
      expect(color, isNotNull);
      expect(color!.red, 255);
      expect(color.green, 85);
      expect(color.blue, 0);
    });

    test('CornerRadius optimizes uniform values', () {
      final uniform = CornerRadius.circular(8);
      expect(uniform.toJson(), {
        'all': {'value': 8.0},
      });

      const mixed = CornerRadius(
        topLeft: FixedNumeric(8),
        topRight: FixedNumeric(4),
        bottomRight: FixedNumeric(4),
        bottomLeft: FixedNumeric(8),
      );
      final json = mixed.toJson();
      expect(json.containsKey('all'), false);
      expect(json['topLeft'], {'value': 8.0});
    });
  });

  group('NodeProps', () {
    test('TextProps round-trip', () {
      const props = TextProps(
        text: 'Hello World',
        fontSize: 16,
        fontWeight: 600,
        textAlign: TextAlign.center,
      );

      final json = props.toJson();
      final restored = TextProps.fromJson(json);

      expect(restored.text, props.text);
      expect(restored.fontSize, props.fontSize);
      expect(restored.fontWeight, props.fontWeight);
      expect(restored.textAlign, props.textAlign);
    });

    test('InstanceProps stores overrides', () {
      const props = InstanceProps(
        componentId: 'comp_button',
        overrides: {'label': 'Click Me'},
      );

      final json = props.toJson();
      final restored = InstanceProps.fromJson(json);

      expect(restored.componentId, props.componentId);
      expect(restored.overrides['label'], 'Click Me');
    });

    test('SpacerProps defaults flex to 1', () {
      const props = SpacerProps();
      expect(props.flex, 1);

      final json = props.toJson();
      final restored = SpacerProps.fromJson(json);
      expect(restored.flex, 1);
    });
  });
}
