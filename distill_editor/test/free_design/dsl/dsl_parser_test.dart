import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  late DslParser parser;

  setUp(() {
    parser = DslParser();
  });

  group('Version Header', () {
    test('parses valid version header', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root
''');
      expect(result.frame, isNotNull);
      expect(result.frame.name, 'Test');
    });

    test('rejects missing version header', () {
      expect(
        () => parser.parse('frame Test\n  container#root'),
        throwsA(isA<DslParseException>()),
      );
    });

    test('rejects unsupported version', () {
      expect(
        () => parser.parse('dsl:99\nframe Test\n  container#root'),
        throwsA(isA<DslParseException>()),
      );
    });
  });

  group('Frame Declaration', () {
    test('parses simple frame name', () {
      final result = parser.parse('''
dsl:1
frame HomePage
  container#root
''');
      expect(result.frame.name, equals('HomePage'));
    });

    test('parses quoted frame name with spaces', () {
      final result = parser.parse('''
dsl:1
frame "Login Screen"
  container#root
''');
      expect(result.frame.name, equals('Login Screen'));
    });

    test('parses frame with custom dimensions', () {
      final result = parser.parse('''
dsl:1
frame Test - w 1920 h 1080
  container#root
''');
      expect(result.frame.canvas.size.width, equals(1920));
      expect(result.frame.canvas.size.height, equals(1080));
    });

    test('uses default dimensions when not specified', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root
''');
      expect(result.frame.canvas.size.width, equals(375));
      expect(result.frame.canvas.size.height, equals(812));
    });
  });

  group('Node Types', () {
    test('parses container node', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root
''');
      expect(result.nodes['root']?.type, equals(NodeType.container));
    });

    test('parses row as horizontal container', () {
      final result = parser.parse('''
dsl:1
frame Test
  row#root
''');
      final node = result.nodes['root']!;
      expect(node.type, equals(NodeType.container));
      expect(node.layout.autoLayout?.direction, equals(LayoutDirection.horizontal));
    });

    test('parses column as vertical container', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root
''');
      final node = result.nodes['root']!;
      expect(node.type, equals(NodeType.container));
      expect(node.layout.autoLayout?.direction, equals(LayoutDirection.vertical));
    });

    test('parses col as alias for column', () {
      final result = parser.parse('''
dsl:1
frame Test
  col#root
''');
      final node = result.nodes['root']!;
      expect(node.layout.autoLayout?.direction, equals(LayoutDirection.vertical));
    });

    test('parses text node with content', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#title "Hello World"
''');
      final node = result.nodes['title']!;
      expect(node.type, equals(NodeType.text));
      final props = node.props as TextProps;
      expect(props.text, equals('Hello World'));
    });

    test('parses img as image node', () {
      final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/image.png"
''');
      final node = result.nodes['photo']!;
      expect(node.type, equals(NodeType.image));
      final props = node.props as ImageProps;
      expect(props.src, equals('https://example.com/image.png'));
    });

    test('parses icon node', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#home "home"
''');
      final node = result.nodes['home']!;
      expect(node.type, equals(NodeType.icon));
      final props = node.props as IconProps;
      expect(props.icon, equals('home'));
    });

    test('parses spacer node', () {
      final result = parser.parse('''
dsl:1
frame Test
  spacer#flex
''');
      expect(result.nodes['flex']?.type, equals(NodeType.spacer));
    });

    test('parses use as instance node', () {
      final result = parser.parse('''
dsl:1
frame Test
  use#btn "ButtonPrimary"
''');
      final node = result.nodes['btn']!;
      expect(node.type, equals(NodeType.instance));
      final props = node.props as InstanceProps;
      expect(props.componentId, equals('ButtonPrimary'));
    });
  });

  group('Layout Properties', () {
    test('parses fixed width', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w 200
''');
      final size = result.nodes['root']!.layout.size.width;
      expect(size, isA<AxisSizeFixed>());
      expect((size as AxisSizeFixed).value, equals(200));
    });

    test('parses fixed height', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - h 100
''');
      final size = result.nodes['root']!.layout.size.height;
      expect(size, isA<AxisSizeFixed>());
      expect((size as AxisSizeFixed).value, equals(100));
    });

    test('parses fill width', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w fill
''');
      expect(result.nodes['root']!.layout.size.width, isA<AxisSizeFill>());
    });

    test('parses fill height', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - h fill
''');
      expect(result.nodes['root']!.layout.size.height, isA<AxisSizeFill>());
    });

    test('parses absolute position', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - pos abs x 10 y 20
''');
      final pos = result.nodes['root']!.layout.position;
      expect(pos, isA<PositionModeAbsolute>());
      expect((pos as PositionModeAbsolute).x, equals(10));
      expect(pos.y, equals(20));
    });

    test('parses gap with fixed value', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - gap 16
''');
      final gap = result.nodes['root']!.layout.autoLayout?.gap;
      expect(gap, isA<FixedNumeric>());
      expect((gap as FixedNumeric).value, equals(16));
    });

    test('parses gap with token reference', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - gap {spacing.md}
''');
      final gap = result.nodes['root']!.layout.autoLayout?.gap;
      expect(gap, isA<TokenNumeric>());
      expect((gap as TokenNumeric).tokenRef, equals('spacing.md'));
    });

    test('parses uniform padding', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - pad 16
''');
      final pad = result.nodes['root']!.layout.autoLayout?.padding;
      expect(pad, isNotNull);
      expect(pad!.top.toDouble(), equals(16));
      expect(pad.right.toDouble(), equals(16));
      expect(pad.bottom.toDouble(), equals(16));
      expect(pad.left.toDouble(), equals(16));
    });

    test('parses symmetric padding', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - pad 8,16
''');
      final pad = result.nodes['root']!.layout.autoLayout?.padding;
      expect(pad, isNotNull);
      expect(pad!.top.toDouble(), equals(8));
      expect(pad.right.toDouble(), equals(16));
      expect(pad.bottom.toDouble(), equals(8));
      expect(pad.left.toDouble(), equals(16));
    });

    test('parses per-side padding', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - pad 1,2,3,4
''');
      final pad = result.nodes['root']!.layout.autoLayout?.padding;
      expect(pad, isNotNull);
      expect(pad!.top.toDouble(), equals(1));
      expect(pad.right.toDouble(), equals(2));
      expect(pad.bottom.toDouble(), equals(3));
      expect(pad.left.toDouble(), equals(4));
    });

    test('parses padding with token reference', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - pad {spacing.lg}
''');
      final pad = result.nodes['root']!.layout.autoLayout?.padding;
      expect(pad, isNotNull);
      expect(pad!.top, isA<TokenNumeric>());
      expect((pad.top as TokenNumeric).tokenRef, equals('spacing.lg'));
    });

    test('parses alignment', () {
      final result = parser.parse('''
dsl:1
frame Test
  row#root - align center,center
''');
      final auto = result.nodes['root']!.layout.autoLayout;
      expect(auto?.mainAlign, equals(MainAxisAlignment.center));
      expect(auto?.crossAlign, equals(CrossAxisAlignment.center));
    });

    test('parses all alignment values', () {
      // Test mainAlign values
      for (final main in ['start', 'center', 'end', 'spaceBetween', 'spaceAround', 'spaceEvenly']) {
        final result = parser.parse('''
dsl:1
frame Test
  row#root - align $main,center
''');
        expect(result.nodes['root']!.layout.autoLayout?.mainAlign.name, equals(main));
      }

      // Test crossAlign values
      for (final cross in ['start', 'center', 'end', 'stretch']) {
        final result = parser.parse('''
dsl:1
frame Test
  row#root - align center,$cross
''');
        expect(result.nodes['root']!.layout.autoLayout?.crossAlign.name, equals(cross));
      }
    });
  });

  group('Style Properties', () {
    test('parses hex background', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg #FF5500
''');
      final fill = result.nodes['root']!.style.fill;
      expect(fill, isA<SolidFill>());
      expect(((fill as SolidFill).color as HexColor).hex, equals('#FF5500'));
    });

    test('parses token background', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg {color.primary}
''');
      final fill = result.nodes['root']!.style.fill;
      expect(fill, isA<TokenFill>());
      expect((fill as TokenFill).tokenRef, equals('color.primary'));
    });

    test('parses uniform corner radius', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - r 8
''');
      final r = result.nodes['root']!.style.cornerRadius!;
      expect(r.topLeft.toDouble(), equals(8));
      expect(r.topRight.toDouble(), equals(8));
      expect(r.bottomRight.toDouble(), equals(8));
      expect(r.bottomLeft.toDouble(), equals(8));
    });

    test('parses per-corner radius', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - r 8,8,0,0
''');
      final r = result.nodes['root']!.style.cornerRadius!;
      expect(r.topLeft.toDouble(), equals(8));
      expect(r.topRight.toDouble(), equals(8));
      expect(r.bottomRight.toDouble(), equals(0));
      expect(r.bottomLeft.toDouble(), equals(0));
    });

    test('parses radius with token', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - r {radius.md}
''');
      final r = result.nodes['root']!.style.cornerRadius!;
      expect(r.topLeft, isA<TokenNumeric>());
      expect((r.topLeft as TokenNumeric).tokenRef, equals('radius.md'));
    });

    test('parses border with width only uses default color', () {
      // Note: The parser currently only reads the first space-separated token
      // as the border value, so "border 1 #CCCCCC" parses as border="1"
      // and defaults to #000000 for color. This is a known limitation.
      final result = parser.parse('''
dsl:1
frame Test
  container#root - border 1
''');
      final stroke = result.nodes['root']!.style.stroke!;
      expect(stroke.width, equals(1));
      expect((stroke.color as HexColor).hex, equals('#000000'));
    });

    test('parses opacity', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - opacity 0.5
''');
      expect(result.nodes['root']!.style.opacity, equals(0.5));
    });

    test('parses visibility false', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - visible false
''');
      expect(result.nodes['root']!.style.visible, isFalse);
    });
  });

  group('Text Properties', () {
    test('parses font size', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - size 24
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.fontSize, equals(24));
    });

    test('parses font weight', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - weight 700
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.fontWeight, equals(700));
    });

    test('parses text color', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - color #333333
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.color, equals('#333333'));
    });

    test('parses text alignment', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - textAlign center
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.textAlign, equals(TextAlign.center));
    });

    test('parses font family', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - family "Inter"
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.fontFamily, equals('Inter'));
    });

    test('parses all text properties combined', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - size 24 weight 700 color #333 textAlign center family "Inter"
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.text, equals('Hello'));
      expect(props.fontSize, equals(24));
      expect(props.fontWeight, equals(700));
      expect(props.color, equals('#333'));
      expect(props.textAlign, equals(TextAlign.center));
      expect(props.fontFamily, equals('Inter'));
    });
  });

  group('Icon Properties', () {
    test('parses icon set', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home" - iconSet lucide
''');
      final props = result.nodes['i']!.props as IconProps;
      expect(props.iconSet, equals('lucide'));
    });

    test('parses icon size', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home" - size 32
''');
      final props = result.nodes['i']!.props as IconProps;
      expect(props.size, equals(32));
    });

    test('parses icon color', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home" - color #666666
''');
      final props = result.nodes['i']!.props as IconProps;
      expect(props.color, equals('#666666'));
    });

    test('uses default icon set', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home"
''');
      final props = result.nodes['i']!.props as IconProps;
      expect(props.iconSet, equals('material'));
    });

    test('uses default icon size', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home"
''');
      final props = result.nodes['i']!.props as IconProps;
      expect(props.size, equals(24));
    });
  });

  group('Image Properties', () {
    test('parses image fit', () {
      final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/img.png" - fit contain
''');
      final props = result.nodes['photo']!.props as ImageProps;
      expect(props.fit, equals(ImageFit.contain));
    });

    test('parses image alt text', () {
      final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/img.png" - alt "Profile picture"
''');
      final props = result.nodes['photo']!.props as ImageProps;
      expect(props.alt, equals('Profile picture'));
    });

    test('uses default image fit', () {
      final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/img.png"
''');
      final props = result.nodes['photo']!.props as ImageProps;
      expect(props.fit, equals(ImageFit.cover));
    });

    test('parses all image fit values', () {
      for (final fit in ['cover', 'contain', 'fill', 'fitWidth', 'fitHeight', 'none', 'scaleDown']) {
        final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/img.png" - fit $fit
''');
        final props = result.nodes['photo']!.props as ImageProps;
        expect(props.fit.name, equals(fit));
      }
    });
  });

  group('Container Properties', () {
    test('parses clip', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - clip
''');
      final props = result.nodes['root']!.props as ContainerProps;
      expect(props.clipContent, isTrue);
    });

    test('parses scroll direction', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - scroll vertical
''');
      final props = result.nodes['root']!.props as ContainerProps;
      expect(props.scrollDirection, equals('vertical'));
    });

    test('parses horizontal scroll', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - scroll horizontal
''');
      final props = result.nodes['root']!.props as ContainerProps;
      expect(props.scrollDirection, equals('horizontal'));
    });
  });

  group('Spacer Properties', () {
    test('parses flex value', () {
      final result = parser.parse('''
dsl:1
frame Test
  spacer#s - flex 2
''');
      final props = result.nodes['s']!.props as SpacerProps;
      expect(props.flex, equals(2));
    });

    test('defaults to flex 1', () {
      final result = parser.parse('''
dsl:1
frame Test
  spacer#s
''');
      final props = result.nodes['s']!.props as SpacerProps;
      expect(props.flex, equals(1));
    });
  });

  group('Hierarchy & Indentation', () {
    test('parses nested children correctly', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root
    text#child1 "First"
    text#child2 "Second"
''');
      final root = result.nodes['root']!;
      expect(root.childIds, equals(['child1', 'child2']));
    });

    test('parses deep nesting', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#level1
    row#level2
      container#level3
        text#level4 "Deep"
''');
      expect(result.nodes['level1']!.childIds, equals(['level2']));
      expect(result.nodes['level2']!.childIds, equals(['level3']));
      expect(result.nodes['level3']!.childIds, equals(['level4']));
      expect(result.nodes['level4']!.childIds, isEmpty);
    });

    test('handles siblings at different depths', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root
    row#row1
      text#text1 "A"
    row#row2
      text#text2 "B"
''');
      expect(result.nodes['root']!.childIds, equals(['row1', 'row2']));
      expect(result.nodes['row1']!.childIds, equals(['text1']));
      expect(result.nodes['row2']!.childIds, equals(['text2']));
    });

    test('sets frame root node correctly', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#myroot
    text#child "Hello"
''');
      expect(result.frame.rootNodeId, equals('myroot'));
    });
  });

  group('Comments and Empty Lines', () {
    test('skips empty lines', () {
      final result = parser.parse('''
dsl:1

frame Test

  container#root

''');
      expect(result.frame.name, equals('Test'));
      expect(result.nodes['root'], isNotNull);
    });

    test('skips comment lines starting with #', () {
      final result = parser.parse('''
dsl:1
frame Test
  # This is a comment
  container#root
''');
      expect(result.nodes['root'], isNotNull);
    });

    test('skips comment lines starting with //', () {
      final result = parser.parse('''
dsl:1
frame Test
  // This is a comment
  container#root
''');
      expect(result.nodes['root'], isNotNull);
    });
  });

  group('Auto-generated IDs', () {
    test('generates IDs when not specified', () {
      final result = parser.parse('''
dsl:1
frame Test
  container
''');
      // Should have a node with auto-generated ID
      expect(result.nodes.length, equals(1));
      final node = result.nodes.values.first;
      expect(node.id, startsWith('n_'));
    });

    test('uses explicit IDs when specified', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#myId
''');
      expect(result.nodes['myId'], isNotNull);
    });
  });
}
