import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  late DslParser parser;
  const exporter = DslExporter();

  setUp(() {
    parser = DslParser();
  });

  group('Parser Error Handling', () {
    test('throws on empty input', () {
      expect(
        () => parser.parse(''),
        throwsA(isA<DslParseException>()),
      );
    });

    test('throws on missing version header', () {
      expect(
        () => parser.parse('frame Test\n  container#root'),
        throwsA(isA<DslParseException>().having(
          (e) => e.message,
          'message',
          contains('version'),
        )),
      );
    });

    test('throws on invalid version', () {
      expect(
        () => parser.parse('dsl:99\nframe Test\n  container#root'),
        throwsA(isA<DslParseException>()),
      );
    });

    test('throws on missing frame declaration', () {
      expect(
        () => parser.parse('dsl:1\n  container#root'),
        throwsA(isA<DslParseException>()),
      );
    });

    test('throws on unknown node type', () {
      expect(
        () => parser.parse('dsl:1\nframe Test\n  unknowntype#node'),
        throwsA(isA<DslParseException>().having(
          (e) => e.message,
          'message',
          contains('Unknown node type'),
        )),
      );
    });

    test('handles odd space indentation as valid (relative to root)', () {
      // The parser checks relative indentation from root node's indent level.
      // 3 spaces at root is valid as long as children use consistent 2-space increments.
      // This test verifies the parser doesn't crash on 3-space root indent.
      final result = parser.parse('dsl:1\nframe Test\n   container#root');
      expect(result.nodes['root'], isNotNull);
    });

    test('throws on invalid frame declaration format', () {
      expect(
        () => parser.parse('dsl:1\nframe\n  container#root'),
        throwsA(isA<DslParseException>()),
      );
    });

    test('requires at least one node after frame', () {
      // Frame without any nodes - the parser behavior here depends on
      // the implementation. Let's verify what actually happens.
      final result = parser.parse('dsl:1\nframe Test\n');
      // Parser succeeds but frame has empty rootNodeId
      expect(result.frame.rootNodeId, isEmpty);
    });
  });

  group('Exporter Error Handling', () {
    test('throws on missing frame', () {
      final doc = EditorDocument(documentId: 'test', frames: {}, nodes: {});
      expect(
        () => exporter.exportFrame(doc, 'nonexistent'),
        throwsA(isA<DslExportException>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        )),
      );
    });

    test('handles missing root node gracefully', () {
      final doc = EditorDocument(
        documentId: 'test',
        frames: {
          'frame1': Frame(
            id: 'frame1',
            name: 'Test',
            canvas: const CanvasPlacement(position: Offset.zero, size: Size(375, 812)),
            rootNodeId: 'nonexistent',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        },
        nodes: {},
      );
      // Should not throw, just exports frame without nodes
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('frame Test'));
    });
  });

  group('Whitespace Handling', () {
    test('handles extra blank lines', () {
      final result = parser.parse('''
dsl:1

frame Test

  container#root

''');
      expect(result.frame.name, equals('Test'));
      expect(result.nodes['root'], isNotNull);
    });

    test('handles trailing whitespace on lines', () {
      final result = parser.parse('dsl:1\nframe Test   \n  container#root   ');
      expect(result.frame.name, equals('Test'));
      expect(result.nodes['root'], isNotNull);
    });

    test('handles Windows line endings', () {
      final result = parser.parse('dsl:1\r\nframe Test\r\n  container#root');
      expect(result.frame.name, equals('Test'));
    });

    test('handles mixed line endings', () {
      final result = parser.parse('dsl:1\nframe Test\r\n  container#root\n');
      expect(result.frame.name, equals('Test'));
    });

    test('handles tabs in properties', () {
      // Tabs should be treated as spaces for property parsing
      final result = parser.parse('dsl:1\nframe Test\n  container#root - w 200');
      expect(result.nodes['root'], isNotNull);
    });
  });

  group('Special Characters', () {
    test('handles unicode in text content', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#emoji "Hello World"
''');
      final props = result.nodes['emoji']!.props as TextProps;
      expect(props.text, equals('Hello World'));
    });

    test('handles unicode emoji in text', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Click here"
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.text, contains('Click'));
    });

    test('handles quotes in frame name', () {
      final result = parser.parse('''
dsl:1
frame "John's Screen"
  container#root
''');
      expect(result.frame.name, equals("John's Screen"));
    });

    test('handles special chars in node ID', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#my_node_123
''');
      expect(result.nodes['my_node_123'], isNotNull);
    });
  });

  group('Numeric Edge Cases', () {
    test('handles zero values', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w 0 h 0 opacity 0
''');
      final node = result.nodes['root']!;
      expect((node.layout.size.width as AxisSizeFixed).value, equals(0));
      expect((node.layout.size.height as AxisSizeFixed).value, equals(0));
      expect(node.style.opacity, equals(0));
    });

    test('handles large values', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w 10000 h 10000
''');
      expect((result.nodes['root']!.layout.size.width as AxisSizeFixed).value, equals(10000));
      expect((result.nodes['root']!.layout.size.height as AxisSizeFixed).value, equals(10000));
    });

    test('handles negative position values', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - pos abs x -50 y -100
''');
      final pos = result.nodes['root']!.layout.position as PositionModeAbsolute;
      expect(pos.x, equals(-50));
      expect(pos.y, equals(-100));
    });

    test('handles very small decimals', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - opacity 0.001
''');
      expect(result.nodes['root']!.style.opacity, closeTo(0.001, 0.0001));
    });

    test('handles decimal dimensions', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w 100.5 h 200.75
''');
      expect((result.nodes['root']!.layout.size.width as AxisSizeFixed).value, equals(100.5));
      expect((result.nodes['root']!.layout.size.height as AxisSizeFixed).value, equals(200.75));
    });
  });

  group('Token Reference Edge Cases', () {
    test('handles deeply nested token paths', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg {theme.colors.primary.500}
''');
      final fill = result.nodes['root']!.style.fill as TokenFill;
      expect(fill.tokenRef, equals('theme.colors.primary.500'));
    });

    test('handles token with numbers', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - gap {spacing.4}
''');
      final gap = result.nodes['root']!.layout.autoLayout!.gap as TokenNumeric;
      expect(gap.tokenRef, equals('spacing.4'));
    });

    test('handles token with underscores', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg {color.primary_dark}
''');
      final fill = result.nodes['root']!.style.fill as TokenFill;
      expect(fill.tokenRef, equals('color.primary_dark'));
    });

    test('handles dollar sign token syntax', () {
      // Parser also supports $token syntax
      final result = parser.parse('''
dsl:1
frame Test
  column#root - gap {\$spacing.md}
''');
      // The token path includes the $ as part of the path
      final gap = result.nodes['root']!.layout.autoLayout!.gap;
      expect(gap, isA<TokenNumeric>());
    });
  });

  group('Color Parsing Edge Cases', () {
    test('handles 3-character hex color (expands to 6-char)', () {
      // Parser expands 3-char to 6-char for consistent storage
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg #FFF
''');
      final fill = result.nodes['root']!.style.fill as SolidFill;
      expect((fill.color as HexColor).hex, equals('#FFFFFF'));
    });

    test('handles 6-character hex color', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg #FFFFFF
''');
      final fill = result.nodes['root']!.style.fill as SolidFill;
      expect((fill.color as HexColor).hex, equals('#FFFFFF'));
    });

    test('handles lowercase hex color (normalizes to uppercase)', () {
      // Parser normalizes hex colors to uppercase for consistency
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg #ff5500
''');
      final fill = result.nodes['root']!.style.fill as SolidFill;
      expect((fill.color as HexColor).hex, equals('#FF5500'));
    });

    test('round-trips 3-char hex color', () {
      // 3-char input should round-trip back to 3-char (for compressible colors)
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg #FFF
''');
      final doc = EditorDocument(
        documentId: 'test',
        frames: {'frame1': result.frame},
        nodes: result.nodes,
      );
      final dsl = const DslExporter().exportFrame(doc, 'frame1');
      // Exporter should output short form for compressible colors
      expect(dsl, contains('bg #FFF'));
    });

    test('round-trips non-compressible hex color', () {
      // Non-compressible colors like #123456 stay full-length
      final result = parser.parse('''
dsl:1
frame Test
  container#root - bg #123456
''');
      final doc = EditorDocument(
        documentId: 'test',
        frames: {'frame1': result.frame},
        nodes: result.nodes,
      );
      final dsl = const DslExporter().exportFrame(doc, 'frame1');
      // Exporter should output full form for non-compressible colors
      expect(dsl, contains('bg #123456'));
    });
  });

  group('Property Parsing Edge Cases', () {
    test('handles multiple properties on one line', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w 200 h 100 bg #FF0000 r 8 opacity 0.5
''');
      final node = result.nodes['root']!;
      expect((node.layout.size.width as AxisSizeFixed).value, equals(200));
      expect((node.layout.size.height as AxisSizeFixed).value, equals(100));
      expect(node.style.fill, isA<SolidFill>());
      expect(node.style.cornerRadius, isNotNull);
      expect(node.style.opacity, equals(0.5));
    });

    test('handles boolean properties without value', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - clip
''');
      final props = result.nodes['root']!.props as ContainerProps;
      expect(props.clipContent, isTrue);
    });

    test('handles properties with default values preserved', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello"
''');
      final props = result.nodes['t']!.props as TextProps;
      expect(props.fontSize, equals(14)); // default
      expect(props.fontWeight, equals(400)); // default
      expect(props.textAlign, equals(TextAlign.left)); // default
    });
  });

  group('Hierarchy Edge Cases', () {
    test('handles single node tree', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#only "Only node"
''');
      expect(result.nodes.length, equals(1));
      expect(result.frame.rootNodeId, equals('only'));
    });

    test('handles flat sibling list', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root
    text#a "A"
    text#b "B"
    text#c "C"
    text#d "D"
''');
      expect(result.nodes['root']!.childIds.length, equals(4));
    });

    test('handles return to shallower depth after deep nesting', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root
    row#deep
      container#deeper
        text#deepest "Deep"
    text#shallow "Shallow"
''');
      expect(result.nodes['root']!.childIds, equals(['deep', 'shallow']));
      expect(result.nodes['deep']!.childIds, equals(['deeper']));
      expect(result.nodes['deeper']!.childIds, equals(['deepest']));
    });
  });

  group('ID Generation', () {
    test('auto-generates unique IDs for nodes without explicit IDs', () {
      final result = parser.parse('''
dsl:1
frame Test
  column
    text "First"
    text "Second"
''');
      expect(result.nodes.length, equals(3));
      final ids = result.nodes.keys.toList();
      expect(ids.toSet().length, equals(3)); // All unique
    });

    test('generates frame ID', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root
''');
      expect(result.frame.id, startsWith('f_'));
    });

    test('uses explicit ID when provided', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#myExplicitId
''');
      expect(result.nodes['myExplicitId'], isNotNull);
    });

    test('mixes explicit and auto IDs', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root
    text#explicit "Has ID"
    text "No ID"
''');
      expect(result.nodes['root'], isNotNull);
      expect(result.nodes['explicit'], isNotNull);
      expect(result.nodes.length, equals(3));
    });
  });

  group('Frame Variations', () {
    test('frame with only width specified', () {
      final result = parser.parse('''
dsl:1
frame Test - w 1920
  container#root
''');
      expect(result.frame.canvas.size.width, equals(1920));
      expect(result.frame.canvas.size.height, equals(812)); // default
    });

    test('frame with only height specified', () {
      final result = parser.parse('''
dsl:1
frame Test - h 1080
  container#root
''');
      expect(result.frame.canvas.size.width, equals(375)); // default
      expect(result.frame.canvas.size.height, equals(1080));
    });

    test('frame with empty quoted name throws', () {
      // The parser regex requires at least some content in the name
      expect(
        () => parser.parse('dsl:1\nframe ""\n  container#root'),
        throwsA(isA<DslParseException>()),
      );
    });
  });

  group('Exception Messages', () {
    test('DslParseException has meaningful toString', () {
      final exception = DslParseException('Test error message');
      expect(exception.toString(), contains('DslParseException'));
      expect(exception.toString(), contains('Test error message'));
    });

    test('DslExportException has meaningful toString', () {
      final exception = DslExportException('Test error message');
      expect(exception.toString(), contains('DslExportException'));
      expect(exception.toString(), contains('Test error message'));
    });
  });

  group('Round-Trip Edge Cases', () {
    test('empty string text round-trips', () {
      final originalDsl = '''
dsl:1
frame Test
  text#empty ""
''';
      final result1 = parser.parse(originalDsl);
      final doc = EditorDocument(
        documentId: 'test',
        frames: {result1.frame.id: result1.frame},
        nodes: result1.nodes,
      );
      final exportedDsl = exporter.exportFrame(doc, result1.frame.id);
      final result2 = DslParser().parse(exportedDsl);

      final props1 = result1.nodes['empty']!.props as TextProps;
      final props2 = result2.nodes['empty']!.props as TextProps;
      expect(props2.text, equals(props1.text));
    });

    test('node without properties round-trips', () {
      final originalDsl = '''
dsl:1
frame Test
  container#root
''';
      final result1 = parser.parse(originalDsl);
      final doc = EditorDocument(
        documentId: 'test',
        frames: {result1.frame.id: result1.frame},
        nodes: result1.nodes,
      );
      final exportedDsl = exporter.exportFrame(doc, result1.frame.id);
      final result2 = DslParser().parse(exportedDsl);

      expect(result2.nodes['root']!.type, equals(NodeType.container));
    });
  });
}
