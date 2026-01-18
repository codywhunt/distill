# PRD: DSL Round-Trip Fidelity & Testing

**Priority:** 4
**Status:** Implementation Complete, Tests Missing
**Owner:** Engineering
**Last Updated:** 2026-01-18

---

## Executive Summary

The DSL (Domain Specific Language) is the compact text representation used for AI-assisted UI generation. While the implementation is complete (`dsl_parser.dart`, `dsl_exporter.dart`), there is **zero test coverage**. This PRD defines a comprehensive testing strategy to ensure round-trip fidelity: `parse(export(doc)) == doc`.

---

## 1. DSL Purpose & Vision

### 1.1 What is the DSL?

The DSL is a **compact, human-readable text format** for representing UI designs. It serves as the bridge between AI language models and the Distill editor's internal representation.

**Example DSL:**
```
dsl:1
frame LoginScreen - w 390 h 844
  column#root - w fill h fill pad 24 gap 16 bg #FFFFFF
    text#title "Welcome Back" - size 28 weight 700 color #1A1A1A
    column#form - w fill gap 12
      row#email-field - w fill h 48 pad 12 bg {color.surface} r 8
        icon#email-icon "mail" - size 20 color {color.muted}
        text#email-input "Email address" - size 14 color {color.muted}
      row#password-field - w fill h 48 pad 12 bg {color.surface} r 8
        icon#lock-icon "lock" - size 20 color {color.muted}
        text#password-input "Password" - size 14 color {color.muted}
    spacer#flex - flex 1
    row#login-btn - w fill h 52 bg {color.primary} r 12 align center,center
      text#login-text "Sign In" - size 16 weight 600 color #FFFFFF
```

### 1.2 Why DSL Over JSON?

| Aspect | JSON IR | DSL |
|--------|---------|-----|
| Token count | ~400 tokens | ~100 tokens |
| Readability | Verbose | Scannable |
| AI generation | Error-prone | Reliable |
| Edit distance | High | Low |

**Key benefit:** ~75% fewer tokens means faster AI responses, lower costs, and more reliable generation.

### 1.3 Strategic Goals

1. **Round-trip fidelity** - `parse(export(doc)) == doc` for all supported properties
2. **Deterministic output** - Same input always produces identical DSL
3. **Graceful degradation** - Unsupported properties are preserved in IR, just not exported
4. **Extensibility** - Clean path to DSL v2 with additional features

### 1.4 Future Vision (DSL v2)

Properties planned for future DSL versions:
- **Shadows** - `shadow 0,4,12,#00000020` (x, y, blur, color)
- **Gradients** - `bg linear(0deg, #FFF, #000)`
- **Text decoration** - `decoration underline`
- **Line height** - `lineHeight 1.5`
- **Letter spacing** - `tracking 0.5`
- **Instance overrides** - `use "Button" { text: "Submit" }`

---

## 2. Property Coverage Matrix

### 2.1 Fully Supported Properties

| Category | Property | DSL Syntax | Example |
|----------|----------|------------|---------|
| **Layout** | Fixed width | `w <num>` | `w 200` |
| | Fixed height | `h <num>` | `h 48` |
| | Fill width | `w fill` | `w fill` |
| | Fill height | `h fill` | `h fill` |
| | Absolute position | `pos abs x <n> y <n>` | `pos abs x 10 y 20` |
| | Gap | `gap <num\|token>` | `gap 16` or `gap {spacing.md}` |
| | Padding (uniform) | `pad <num\|token>` | `pad 16` or `pad {spacing.lg}` |
| | Padding (symmetric) | `pad <v>,<h>` | `pad 16,24` |
| | Padding (per-side) | `pad <t>,<r>,<b>,<l>` | `pad 8,16,8,16` |
| | Alignment | `align <main>,<cross>` | `align center,center` |
| **Style** | Background (hex) | `bg <hex>` | `bg #FF5500` |
| | Background (token) | `bg {<path>}` | `bg {color.primary}` |
| | Corner radius (uniform) | `r <num\|token>` | `r 8` or `r {radius.md}` |
| | Corner radius (per-corner) | `r <tl>,<tr>,<br>,<bl>` | `r 8,8,0,0` |
| | Border | `border <w> <color>` | `border 1 #CCCCCC` |
| | Opacity | `opacity <0-1>` | `opacity 0.5` |
| | Visibility | `visible false` | `visible false` |
| **Text** | Content | `"<text>"` | `text "Hello"` |
| | Font size | `size <num>` | `size 16` |
| | Font weight | `weight <num>` | `weight 700` |
| | Color | `color <hex\|token>` | `color #333` |
| | Alignment | `textAlign <align>` | `textAlign center` |
| | Font family | `family "<name>"` | `family "Inter"` |
| **Icon** | Icon name | `"<name>"` | `icon "home"` |
| | Icon set | `iconSet <set>` | `iconSet lucide` |
| | Size | `size <num>` | `size 24` |
| | Color | `color <hex>` | `color #666` |
| **Image** | Source | `"<url>"` | `img "https://..."` |
| | Fit | `fit <mode>` | `fit contain` |
| | Alt text | `alt "<text>"` | `alt "Profile"` |
| **Container** | Clip content | `clip` | `clip` |
| | Scroll | `scroll <dir>` | `scroll vertical` |
| **Spacer** | Flex | `flex <num>` | `flex 2` |
| **Instance** | Component ID | `"<id>"` | `use "ButtonPrimary"` |
| **Slot** | Slot name | `"<name>"` | `slot "content"` |

### 2.2 Node Type Shorthands

| Full Type | Shorthand | When Used |
|-----------|-----------|-----------|
| `container` | `row` | AutoLayout direction = horizontal |
| `container` | `column` / `col` | AutoLayout direction = vertical |
| `container` | `container` | No AutoLayout |
| `image` | `img` | Always |
| `instance` | `use` | Always |

### 2.3 NOT Supported in DSL v1

These properties exist in the IR but are **intentionally excluded** from DSL v1:

| Property | IR Location | Reason for Exclusion |
|----------|-------------|---------------------|
| Shadows | `NodeStyle.shadow` | Complex syntax needed |
| Gradients | `GradientFill` | Complex syntax needed |
| Line height | `TextProps.lineHeight` | Rarely AI-generated |
| Letter spacing | `TextProps.letterSpacing` | Rarely AI-generated |
| Text decoration | `TextProps.decoration` | Future enhancement |
| Instance overrides | `InstanceProps.overrides` | Complex nested syntax |

**Important:** These properties are preserved in the IR during round-trip. They are simply not exported to DSL.

---

## 3. Test Implementation Plan

### 3.1 Test File Structure

```
distill_editor/
└── test/
    └── free_design/
        └── dsl/
            ├── dsl_parser_test.dart        # Parser unit tests
            ├── dsl_exporter_test.dart      # Exporter unit tests
            ├── dsl_round_trip_test.dart    # Integration tests
            ├── dsl_edge_cases_test.dart    # Edge cases & errors
            └── fixtures/
                ├── simple_container.dsl
                ├── nested_layout.dsl
                ├── all_properties.dsl
                └── token_references.dsl
```

### 3.2 Phase 1: Parser Unit Tests

**File:** `test/free_design/dsl/dsl_parser_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/dsl/dsl_parser.dart';
import 'package:distill_editor/src/free_design/models/node_type.dart';
import 'package:distill_editor/src/free_design/models/node_layout.dart';
import 'package:distill_editor/src/free_design/models/node_style.dart';

void main() {
  late DslParser parser;

  setUp(() {
    parser = const DslParser();
  });

  group('Version Header', () {
    test('parses valid version header', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root
''');
      expect(result.frames, hasLength(1));
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
      expect(result.frames.first.name, equals('HomePage'));
    });

    test('parses quoted frame name with spaces', () {
      final result = parser.parse('''
dsl:1
frame "Login Screen"
  container#root
''');
      expect(result.frames.first.name, equals('Login Screen'));
    });

    test('parses frame with custom dimensions', () {
      final result = parser.parse('''
dsl:1
frame Test - w 1920 h 1080
  container#root
''');
      final frame = result.frames.first;
      expect(frame.canvas.size.width, equals(1920));
      expect(frame.canvas.size.height, equals(1080));
    });

    test('uses default dimensions when not specified', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root
''');
      final frame = result.frames.first;
      expect(frame.canvas.size.width, equals(375));
      expect(frame.canvas.size.height, equals(812));
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
      expect((node.props as TextProps).text, equals('Hello World'));
    });

    test('parses img as image node', () {
      final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/image.png"
''');
      final node = result.nodes['photo']!;
      expect(node.type, equals(NodeType.image));
      expect((node.props as ImageProps).src, equals('https://example.com/image.png'));
    });

    test('parses icon node', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#home "home"
''');
      final node = result.nodes['home']!;
      expect(node.type, equals(NodeType.icon));
      expect((node.props as IconProps).icon, equals('home'));
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
      expect((node.props as InstanceProps).componentId, equals('ButtonPrimary'));
    });

    test('parses slot node', () {
      final result = parser.parse('''
dsl:1
frame Test
  slot#content "main"
''');
      final node = result.nodes['content']!;
      expect(node.type, equals(NodeType.slot));
      expect((node.props as SlotProps).slotName, equals('main'));
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
      expect((pad?.top as FixedNumeric).value, equals(16));
      expect((pad?.right as FixedNumeric).value, equals(16));
      expect((pad?.bottom as FixedNumeric).value, equals(16));
      expect((pad?.left as FixedNumeric).value, equals(16));
    });

    test('parses symmetric padding', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - pad 8,16
''');
      final pad = result.nodes['root']!.layout.autoLayout?.padding;
      expect((pad?.top as FixedNumeric).value, equals(8));
      expect((pad?.right as FixedNumeric).value, equals(16));
      expect((pad?.bottom as FixedNumeric).value, equals(8));
      expect((pad?.left as FixedNumeric).value, equals(16));
    });

    test('parses per-side padding', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - pad 1,2,3,4
''');
      final pad = result.nodes['root']!.layout.autoLayout?.padding;
      expect((pad?.top as FixedNumeric).value, equals(1));
      expect((pad?.right as FixedNumeric).value, equals(2));
      expect((pad?.bottom as FixedNumeric).value, equals(3));
      expect((pad?.left as FixedNumeric).value, equals(4));
    });

    test('parses padding with token references', () {
      final result = parser.parse('''
dsl:1
frame Test
  column#root - pad {spacing.lg}
''');
      final pad = result.nodes['root']!.layout.autoLayout?.padding;
      expect(pad?.top, isA<TokenNumeric>());
      expect((pad?.top as TokenNumeric).tokenRef, equals('spacing.lg'));
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
      expect((r.topLeft as FixedNumeric).value, equals(8));
      expect((r.topRight as FixedNumeric).value, equals(8));
      expect((r.bottomRight as FixedNumeric).value, equals(8));
      expect((r.bottomLeft as FixedNumeric).value, equals(8));
    });

    test('parses per-corner radius', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - r 8,8,0,0
''');
      final r = result.nodes['root']!.style.cornerRadius!;
      expect((r.topLeft as FixedNumeric).value, equals(8));
      expect((r.topRight as FixedNumeric).value, equals(8));
      expect((r.bottomRight as FixedNumeric).value, equals(0));
      expect((r.bottomLeft as FixedNumeric).value, equals(0));
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

    test('parses border', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - border 1 #CCCCCC
''');
      final stroke = result.nodes['root']!.style.stroke!;
      expect(stroke.width, equals(1));
      expect((stroke.color as HexColor).hex, equals('#CCCCCC'));
    });

    test('parses border with token color', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - border 2 {color.border}
''');
      final stroke = result.nodes['root']!.style.stroke!;
      expect(stroke.width, equals(2));
      expect((stroke.color as TokenColor).tokenRef, equals('color.border'));
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
      expect((result.nodes['t']!.props as TextProps).fontSize, equals(24));
    });

    test('parses font weight', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - weight 700
''');
      expect((result.nodes['t']!.props as TextProps).fontWeight, equals(700));
    });

    test('parses text color', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - color #333333
''');
      expect((result.nodes['t']!.props as TextProps).color, equals('#333333'));
    });

    test('parses text alignment', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - textAlign center
''');
      expect((result.nodes['t']!.props as TextProps).textAlign, equals(TextAlign.center));
    });

    test('parses font family', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Hello" - family "Inter"
''');
      expect((result.nodes['t']!.props as TextProps).fontFamily, equals('Inter'));
    });
  });

  group('Icon Properties', () {
    test('parses icon set', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home" - iconSet lucide
''');
      expect((result.nodes['i']!.props as IconProps).iconSet, equals('lucide'));
    });

    test('parses icon size', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home" - size 32
''');
      expect((result.nodes['i']!.props as IconProps).size, equals(32));
    });

    test('parses icon color', () {
      final result = parser.parse('''
dsl:1
frame Test
  icon#i "home" - color #666666
''');
      expect((result.nodes['i']!.props as IconProps).color, equals('#666666'));
    });
  });

  group('Image Properties', () {
    test('parses image fit', () {
      final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/img.png" - fit contain
''');
      expect((result.nodes['photo']!.props as ImageProps).fit, equals(ImageFit.contain));
    });

    test('parses image alt text', () {
      final result = parser.parse('''
dsl:1
frame Test
  img#photo "https://example.com/img.png" - alt "Profile picture"
''');
      expect((result.nodes['photo']!.props as ImageProps).alt, equals('Profile picture'));
    });
  });

  group('Container Properties', () {
    test('parses clip', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - clip
''');
      expect((result.nodes['root']!.props as ContainerProps).clipContent, isTrue);
    });

    test('parses scroll direction', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - scroll vertical
''');
      expect((result.nodes['root']!.props as ContainerProps).scrollDirection, equals('vertical'));
    });
  });

  group('Spacer Properties', () {
    test('parses flex value', () {
      final result = parser.parse('''
dsl:1
frame Test
  spacer#s - flex 2
''');
      expect((result.nodes['s']!.props as SpacerProps).flex, equals(2));
    });

    test('defaults to flex 1', () {
      final result = parser.parse('''
dsl:1
frame Test
  spacer#s
''');
      expect((result.nodes['s']!.props as SpacerProps).flex, equals(1));
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
  });
}
```

### 3.3 Phase 2: Exporter Unit Tests

**File:** `test/free_design/dsl/dsl_exporter_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/dsl/dsl_exporter.dart';
import 'package:distill_editor/src/free_design/models/editor_document.dart';
import 'package:distill_editor/src/free_design/models/frame.dart';
import 'package:distill_editor/src/free_design/models/node.dart';
import 'package:distill_editor/src/free_design/models/node_type.dart';
import 'package:distill_editor/src/free_design/models/node_layout.dart';
import 'package:distill_editor/src/free_design/models/node_style.dart';
import 'package:distill_editor/src/free_design/models/node_props.dart';

void main() {
  late DslExporter exporter;

  setUp(() {
    exporter = const DslExporter();
  });

  group('Version Header', () {
    test('exports version header', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, startsWith('dsl:1\n'));
    });
  });

  group('Frame Declaration', () {
    test('exports simple frame name', () {
      final doc = _createDocWithFrame('HomePage');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('frame HomePage'));
    });

    test('quotes frame name with spaces', () {
      final doc = _createDocWithFrame('Login Screen');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('frame "Login Screen"'));
    });

    test('exports custom dimensions', () {
      final doc = _createDocWithDimensions(1920, 1080);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 1920'));
      expect(dsl, contains('h 1080'));
    });

    test('omits default dimensions', () {
      final doc = _createDocWithDimensions(375, 812);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('w 375')));
      expect(dsl, isNot(contains('h 812')));
    });
  });

  group('Node Type Export', () {
    test('exports horizontal container as row', () {
      final doc = _createDocWithAutoLayout(LayoutDirection.horizontal);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('row#'));
    });

    test('exports vertical container as column', () {
      final doc = _createDocWithAutoLayout(LayoutDirection.vertical);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('column#'));
    });

    test('exports container without autoLayout as container', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('container#'));
    });

    test('exports text with content', () {
      final doc = _createDocWithText('Hello World');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('text#'));
      expect(dsl, contains('"Hello World"'));
    });

    test('exports image as img', () {
      final doc = _createDocWithImage('https://example.com/img.png');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('img#'));
    });

    test('exports instance as use', () {
      final doc = _createDocWithInstance('ButtonPrimary');
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('use#'));
      expect(dsl, contains('"ButtonPrimary"'));
    });
  });

  group('Layout Property Export', () {
    test('exports fixed width', () {
      final doc = _createDocWithSize(AxisSizeFixed(200), AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 200'));
    });

    test('exports fill width', () {
      final doc = _createDocWithSize(AxisSizeFill(), AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w fill'));
    });

    test('omits hug width (default)', () {
      final doc = _createDocWithSize(AxisSizeHug(), AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('w hug')));
    });

    test('exports absolute position', () {
      final doc = _createDocWithAbsolutePosition(10, 20);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pos abs'));
      expect(dsl, contains('x 10'));
      expect(dsl, contains('y 20'));
    });

    test('exports gap with fixed value', () {
      final doc = _createDocWithGap(FixedNumeric(16));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('gap 16'));
    });

    test('exports gap with token reference', () {
      final doc = _createDocWithGap(TokenNumeric('spacing.md'));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('gap {spacing.md}'));
    });

    test('exports uniform padding', () {
      final doc = _createDocWithPadding(TokenEdgePadding.all(FixedNumeric(16)));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pad 16'));
    });

    test('exports symmetric padding', () {
      final doc = _createDocWithPadding(TokenEdgePadding.symmetric(
        vertical: FixedNumeric(8),
        horizontal: FixedNumeric(16),
      ));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pad 8,16'));
    });

    test('exports per-side padding', () {
      final doc = _createDocWithPadding(TokenEdgePadding(
        top: FixedNumeric(1),
        right: FixedNumeric(2),
        bottom: FixedNumeric(3),
        left: FixedNumeric(4),
      ));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('pad 1,2,3,4'));
    });

    test('exports alignment when non-default', () {
      final doc = _createDocWithAlignment(MainAxisAlignment.center, CrossAxisAlignment.center);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('align center,center'));
    });

    test('omits default alignment', () {
      final doc = _createDocWithAlignment(MainAxisAlignment.start, CrossAxisAlignment.start);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('align')));
    });
  });

  group('Style Property Export', () {
    test('exports hex background', () {
      final doc = _createDocWithFill(SolidFill(color: HexColor('#FF5500')));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('bg #FF5500'));
    });

    test('exports token background', () {
      final doc = _createDocWithFill(TokenFill(tokenRef: 'color.primary'));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('bg {color.primary}'));
    });

    test('exports uniform radius', () {
      final doc = _createDocWithRadius(CornerRadius.all(FixedNumeric(8)));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('r 8'));
    });

    test('exports per-corner radius', () {
      final doc = _createDocWithRadius(CornerRadius(
        topLeft: FixedNumeric(8),
        topRight: FixedNumeric(8),
        bottomRight: FixedNumeric(0),
        bottomLeft: FixedNumeric(0),
      ));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('r 8,8,0,0'));
    });

    test('exports border', () {
      final doc = _createDocWithStroke(Stroke(width: 1, color: HexColor('#CCCCCC')));
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('border 1 #CCCCCC'));
    });

    test('exports opacity when less than 1', () {
      final doc = _createDocWithOpacity(0.5);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('opacity 0.5'));
    });

    test('omits default opacity', () {
      final doc = _createDocWithOpacity(1.0);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('opacity')));
    });

    test('exports visible false', () {
      final doc = _createDocWithVisibility(false);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('visible false'));
    });

    test('omits visible true (default)', () {
      final doc = _createDocWithVisibility(true);
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, isNot(contains('visible')));
    });
  });

  group('Number Formatting', () {
    test('formats integers without decimal', () {
      final doc = _createDocWithSize(AxisSizeFixed(100), AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 100'));
      expect(dsl, isNot(contains('w 100.0')));
    });

    test('preserves decimal when needed', () {
      final doc = _createDocWithSize(AxisSizeFixed(100.5), AxisSizeHug());
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('w 100.5'));
    });
  });

  group('ID Export', () {
    test('includes IDs by default', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1');
      expect(dsl, contains('#root'));
    });

    test('excludes IDs when disabled', () {
      final doc = _createSimpleDoc();
      final dsl = exporter.exportFrame(doc, 'frame1', includeIds: false);
      expect(dsl, isNot(contains('#root')));
    });
  });

  group('Hierarchy Export', () {
    test('exports children with proper indentation', () {
      final doc = _createDocWithChildren();
      final dsl = exporter.exportFrame(doc, 'frame1');
      final lines = dsl.split('\n');
      // Root at indent 2
      expect(lines.any((l) => l.startsWith('  column#root')), isTrue);
      // Children at indent 4
      expect(lines.any((l) => l.startsWith('    text#child')), isTrue);
    });
  });
}

// ============================================================================
// Test Helpers - Document Builders
// ============================================================================

EditorDocument _createSimpleDoc() {
  return EditorDocument(
    frames: {
      'frame1': Frame(
        id: 'frame1',
        name: 'Test',
        canvas: FrameCanvas(size: Size(375, 812)),
        rootNodeId: 'root',
      ),
    },
    nodes: {
      'root': Node(
        id: 'root',
        type: NodeType.container,
        layout: NodeLayout(),
        style: NodeStyle(),
        props: ContainerProps(),
        childIds: [],
      ),
    },
  );
}

// Additional helper functions would be implemented here...
```

### 3.4 Phase 3: Round-Trip Integration Tests

**File:** `test/free_design/dsl/dsl_round_trip_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/dsl/dsl_parser.dart';
import 'package:distill_editor/src/free_design/dsl/dsl_exporter.dart';

void main() {
  late DslParser parser;
  late DslExporter exporter;

  setUp(() {
    parser = const DslParser();
    exporter = const DslExporter();
  });

  /// Helper to verify round-trip fidelity
  void verifyRoundTrip(String originalDsl, {String? description}) {
    final result1 = parser.parse(originalDsl);
    final doc = result1.toDocument();
    final exportedDsl = exporter.exportFrame(doc, result1.frames.first.id);
    final result2 = parser.parse(exportedDsl);
    final doc2 = result2.toDocument();

    // Compare node trees
    for (final nodeId in doc.nodes.keys) {
      final node1 = doc.nodes[nodeId]!;
      final node2 = doc2.nodes[nodeId];

      expect(node2, isNotNull, reason: 'Node $nodeId missing after round-trip');
      expect(node2!.type, equals(node1.type), reason: 'Type mismatch for $nodeId');
      expect(node2.childIds, equals(node1.childIds), reason: 'Children mismatch for $nodeId');

      // Layout comparison
      _compareLayouts(node1.layout, node2.layout, nodeId);

      // Style comparison
      _compareStyles(node1.style, node2.style, nodeId);

      // Props comparison
      _compareProps(node1.props, node2.props, nodeId);
    }
  }

  group('Simple Round-Trips', () {
    test('empty container', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root
''');
    });

    test('row with children', () {
      verifyRoundTrip('''
dsl:1
frame Test
  row#root - gap 16
    text#a "Hello"
    text#b "World"
''');
    });

    test('column with padding', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - pad 24 gap 16
    text#title "Title" - size 24 weight 700
    text#body "Body text"
''');
    });
  });

  group('Layout Round-Trips', () {
    test('all size modes', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - w fill h fill
    container#fixed - w 200 h 100
    container#fillW - w fill
    container#fillH - h fill
''');
    });

    test('absolute positioning', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root
    container#abs - pos abs x 50 y 100 w 200 h 150
''');
    });

    test('token-based gap and padding', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - gap {spacing.md} pad {spacing.lg}
    text#child "Content"
''');
    });

    test('all alignment combinations', () {
      verifyRoundTrip('''
dsl:1
frame Test
  row#r1 - align start,start
    text#t1 "A"
  row#r2 - align center,center
    text#t2 "B"
  row#r3 - align end,end
    text#t3 "C"
  row#r4 - align spaceBetween,stretch
    text#t4 "D"
''');
    });
  });

  group('Style Round-Trips', () {
    test('hex colors', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg #FF5500 border 1 #CCCCCC
''');
    });

    test('token colors', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg {color.primary} border 2 {color.border}
''');
    });

    test('corner radius variations', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#uniform - r 8
  container#perCorner - r 8,8,0,0
  container#token - r {radius.md}
''');
    });

    test('opacity and visibility', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#half - opacity 0.5
  container#hidden - visible false
''');
    });
  });

  group('Node Type Round-Trips', () {
    test('text with all properties', () {
      verifyRoundTrip('''
dsl:1
frame Test
  text#styled "Hello" - size 24 weight 700 color #333333 textAlign center family "Inter"
''');
    });

    test('icon with all properties', () {
      verifyRoundTrip('''
dsl:1
frame Test
  icon#i "home" - iconSet lucide size 32 color #666666
''');
    });

    test('image with all properties', () {
      verifyRoundTrip('''
dsl:1
frame Test
  img#photo "https://example.com/img.png" - w 200 h 150 fit contain alt "Profile"
''');
    });

    test('spacer with flex', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root
    text#top "Top"
    spacer#flex - flex 2
    text#bottom "Bottom"
''');
    });

    test('container with clip and scroll', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#clipped - w 300 h 200 clip scroll vertical
''');
    });

    test('instance and slot', () {
      verifyRoundTrip('''
dsl:1
frame Test
  use#btn "ButtonPrimary"
  slot#content "main"
''');
    });
  });

  group('Complex Hierarchies', () {
    test('realistic form layout', () {
      verifyRoundTrip('''
dsl:1
frame LoginForm - w 390 h 844
  column#root - w fill h fill pad 24 gap 16 bg #FFFFFF
    text#title "Welcome Back" - size 28 weight 700 color #1A1A1A
    column#form - w fill gap 12
      row#email - w fill h 48 pad 12 bg {color.surface} r 8
        icon#emailIcon "mail" - size 20 color {color.muted}
        text#emailPlaceholder "Email" - color {color.muted}
      row#password - w fill h 48 pad 12 bg {color.surface} r 8
        icon#lockIcon "lock" - size 20 color {color.muted}
        text#passwordPlaceholder "Password" - color {color.muted}
    spacer#flex
    row#loginBtn - w fill h 52 bg {color.primary} r 12 align center,center
      text#loginText "Sign In" - size 16 weight 600 color #FFFFFF
''');
    });

    test('card grid layout', () {
      verifyRoundTrip('''
dsl:1
frame CardGrid - w 1200 h 800
  column#root - w fill h fill pad 32 gap 24 bg #F5F5F5
    text#heading "Featured Items" - size 32 weight 700
    row#grid - w fill gap 16
      column#card1 - w 280 pad 16 bg #FFFFFF r 12
        img#img1 "https://example.com/1.jpg" - w fill h 180 r 8
        text#title1 "Item One" - size 18 weight 600
        text#price1 "$29.99" - size 16 color {color.primary}
      column#card2 - w 280 pad 16 bg #FFFFFF r 12
        img#img2 "https://example.com/2.jpg" - w fill h 180 r 8
        text#title2 "Item Two" - size 18 weight 600
        text#price2 "$39.99" - size 16 color {color.primary}
''');
    });
  });

  group('Edge Cases', () {
    test('empty text content', () {
      // Empty text should still round-trip
      verifyRoundTrip('''
dsl:1
frame Test
  text#empty ""
''');
    });

    test('text with special characters', () {
      verifyRoundTrip('''
dsl:1
frame Test
  text#special "Hello \"World\" & 'Friends'"
''');
    });

    test('very deep nesting', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#l1
    row#l2
      column#l3
        row#l4
          column#l5
            row#l6
              text#deep "Very deep"
''');
    });

    test('many siblings', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - gap 8
    text#t1 "One"
    text#t2 "Two"
    text#t3 "Three"
    text#t4 "Four"
    text#t5 "Five"
    text#t6 "Six"
    text#t7 "Seven"
    text#t8 "Eight"
    text#t9 "Nine"
    text#t10 "Ten"
''');
    });

    test('decimal values', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - w 100.5 h 200.75 opacity 0.85
''');
    });

    test('zero values', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - gap 0 pad 0
    container#child - r 0
''');
    });
  });
}

// ============================================================================
// Comparison Helpers
// ============================================================================

void _compareLayouts(NodeLayout a, NodeLayout b, String nodeId) {
  expect(b.size.width.runtimeType, equals(a.size.width.runtimeType),
      reason: 'Width type mismatch for $nodeId');
  expect(b.size.height.runtimeType, equals(a.size.height.runtimeType),
      reason: 'Height type mismatch for $nodeId');

  if (a.size.width is AxisSizeFixed) {
    expect((b.size.width as AxisSizeFixed).value,
           equals((a.size.width as AxisSizeFixed).value),
           reason: 'Width value mismatch for $nodeId');
  }

  // Compare autoLayout
  if (a.autoLayout != null) {
    expect(b.autoLayout, isNotNull, reason: 'AutoLayout missing for $nodeId');
    expect(b.autoLayout!.direction, equals(a.autoLayout!.direction));
    _compareNumericValues(a.autoLayout!.gap, b.autoLayout!.gap, '$nodeId.gap');
    _comparePadding(a.autoLayout!.padding, b.autoLayout!.padding, nodeId);
  }
}

void _compareStyles(NodeStyle a, NodeStyle b, String nodeId) {
  // Fill comparison
  if (a.fill != null) {
    expect(b.fill, isNotNull, reason: 'Fill missing for $nodeId');
    expect(b.fill.runtimeType, equals(a.fill.runtimeType));
  }

  // Opacity
  expect(b.opacity, equals(a.opacity), reason: 'Opacity mismatch for $nodeId');

  // Visibility
  expect(b.visible, equals(a.visible), reason: 'Visibility mismatch for $nodeId');
}

void _compareProps(NodeProps a, NodeProps b, String nodeId) {
  expect(b.runtimeType, equals(a.runtimeType), reason: 'Props type mismatch for $nodeId');

  switch (a) {
    case TextProps():
      final bText = b as TextProps;
      expect(bText.text, equals(a.text));
      expect(bText.fontSize, equals(a.fontSize));
      expect(bText.fontWeight, equals(a.fontWeight));
    case IconProps():
      final bIcon = b as IconProps;
      expect(bIcon.icon, equals(a.icon));
      expect(bIcon.size, equals(a.size));
    // ... other prop types
  }
}

void _compareNumericValues(NumericValue? a, NumericValue? b, String context) {
  if (a == null) {
    expect(b, isNull, reason: '$context should be null');
    return;
  }
  expect(b, isNotNull, reason: '$context missing');
  expect(b.runtimeType, equals(a.runtimeType), reason: '$context type mismatch');

  if (a is FixedNumeric) {
    expect((b as FixedNumeric).value, equals(a.value), reason: '$context value mismatch');
  } else if (a is TokenNumeric) {
    expect((b as TokenNumeric).tokenRef, equals(a.tokenRef), reason: '$context token mismatch');
  }
}

void _comparePadding(TokenEdgePadding a, TokenEdgePadding b, String nodeId) {
  _compareNumericValues(a.top, b.top, '$nodeId.padding.top');
  _compareNumericValues(a.right, b.right, '$nodeId.padding.right');
  _compareNumericValues(a.bottom, b.bottom, '$nodeId.padding.bottom');
  _compareNumericValues(a.left, b.left, '$nodeId.padding.left');
}
```

### 3.5 Phase 4: Edge Case & Error Tests

**File:** `test/free_design/dsl/dsl_edge_cases_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/dsl/dsl_parser.dart';
import 'package:distill_editor/src/free_design/dsl/dsl_exporter.dart';

void main() {
  late DslParser parser;
  late DslExporter exporter;

  setUp(() {
    parser = const DslParser();
    exporter = const DslExporter();
  });

  group('Parser Error Handling', () {
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
          contains('unknown'),
        )),
      );
    });

    test('throws on invalid indentation', () {
      expect(
        () => parser.parse('dsl:1\nframe Test\n container#root'), // 1 space instead of 2
        throwsA(isA<DslParseException>()),
      );
    });

    test('throws on missing node ID', () {
      expect(
        () => parser.parse('dsl:1\nframe Test\n  container'),
        throwsA(isA<DslParseException>()),
      );
    });

    test('throws on duplicate node ID', () {
      expect(
        () => parser.parse('''
dsl:1
frame Test
  column#root
    text#dup "A"
    text#dup "B"
'''),
        throwsA(isA<DslParseException>().having(
          (e) => e.message,
          'message',
          contains('duplicate'),
        )),
      );
    });

    test('throws on unclosed quote', () {
      expect(
        () => parser.parse('dsl:1\nframe Test\n  text#t "unclosed'),
        throwsA(isA<DslParseException>()),
      );
    });

    test('throws on invalid property value', () {
      expect(
        () => parser.parse('dsl:1\nframe Test\n  container#root - w notanumber'),
        throwsA(isA<DslParseException>()),
      );
    });
  });

  group('Exporter Error Handling', () {
    test('throws on missing frame', () {
      final doc = EditorDocument(frames: {}, nodes: {});
      expect(
        () => exporter.exportFrame(doc, 'nonexistent'),
        throwsA(isA<DslExportException>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        )),
      );
    });
  });

  group('Whitespace Handling', () {
    test('handles extra blank lines', () {
      final result = parser.parse('''
dsl:1

frame Test

  container#root
''');
      expect(result.frames, hasLength(1));
    });

    test('handles trailing whitespace', () {
      final result = parser.parse('dsl:1\nframe Test   \n  container#root   ');
      expect(result.frames, hasLength(1));
    });

    test('handles Windows line endings', () {
      final result = parser.parse('dsl:1\r\nframe Test\r\n  container#root');
      expect(result.frames, hasLength(1));
    });
  });

  group('Special Characters', () {
    test('handles escaped quotes in text', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#t "Say \\"Hello\\""
''');
      expect((result.nodes['t']!.props as TextProps).text, equals('Say "Hello"'));
    });

    test('handles unicode in text', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#emoji "Hello 👋 World 🌍"
''');
      expect((result.nodes['emoji']!.props as TextProps).text, contains('👋'));
    });

    test('handles newlines in quoted text', () {
      final result = parser.parse('''
dsl:1
frame Test
  text#multi "Line 1\\nLine 2"
''');
      expect((result.nodes['multi']!.props as TextProps).text, contains('\n'));
    });
  });

  group('Numeric Edge Cases', () {
    test('handles zero values', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w 0 h 0 r 0 opacity 0
''');
      final node = result.nodes['root']!;
      expect((node.layout.size.width as AxisSizeFixed).value, equals(0));
      expect(node.style.opacity, equals(0));
    });

    test('handles large values', () {
      final result = parser.parse('''
dsl:1
frame Test
  container#root - w 10000 h 10000
''');
      expect((result.nodes['root']!.layout.size.width as AxisSizeFixed).value, equals(10000));
    });

    test('handles negative values', () {
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
  });

  group('Multiple Frames', () {
    test('parses multiple frames in one document', () {
      final result = parser.parse('''
dsl:1
frame Screen1
  container#root1

frame Screen2
  container#root2

frame Screen3
  container#root3
''');
      expect(result.frames, hasLength(3));
    });

    test('exports multiple frames', () {
      final doc = _createMultiFrameDoc();
      final dsl = exporter.exportFrames(doc, ['frame1', 'frame2']);
      expect(dsl, contains('frame Frame1'));
      expect(dsl, contains('frame Frame2'));
    });
  });
}
```

---

## 4. Implementation Schedule

### Phase 1: Parser Tests (Days 1-2)
- [ ] Create test file structure
- [ ] Implement version header tests
- [ ] Implement frame declaration tests
- [ ] Implement node type tests
- [ ] Implement layout property tests
- [ ] Implement style property tests
- [ ] Implement type-specific property tests
- [ ] Implement hierarchy tests

### Phase 2: Exporter Tests (Days 3-4)
- [ ] Implement version/frame export tests
- [ ] Implement node type export tests
- [ ] Implement layout export tests
- [ ] Implement style export tests
- [ ] Implement number formatting tests
- [ ] Implement ID inclusion tests
- [ ] Create helper factory functions

### Phase 3: Round-Trip Tests (Days 5-6)
- [ ] Implement simple round-trip tests
- [ ] Implement layout round-trip tests
- [ ] Implement style round-trip tests
- [ ] Implement node-type round-trip tests
- [ ] Implement complex hierarchy tests
- [ ] Create comparison helper functions

### Phase 4: Edge Cases (Day 7)
- [ ] Implement error handling tests
- [ ] Implement whitespace handling tests
- [ ] Implement special character tests
- [ ] Implement numeric edge case tests
- [ ] Implement multi-frame tests

### Phase 5: CI Integration (Day 8)
- [ ] Add DSL tests to test suite
- [ ] Configure test coverage thresholds
- [ ] Document test patterns

---

## 5. Success Criteria

| Metric | Target |
|--------|--------|
| Parser test coverage | >95% |
| Exporter test coverage | >95% |
| Round-trip tests passing | 100% |
| Edge case coverage | All documented cases |
| CI integration | Tests run on every PR |

---

## 6. Test Running Commands

```bash
# Run all DSL tests
flutter test test/free_design/dsl/ --reporter json 2>&1 | jq -s '{
  total: [.[] | select(.type == "testDone")] | length,
  passed: [.[] | select(.type == "testDone" and .result == "success")] | length,
  failed: [.[] | select(.type == "testDone" and .result == "failure")] | length,
  success: .[-1].success
}'

# Run specific test file
flutter test test/free_design/dsl/dsl_parser_test.dart

# Run with coverage
flutter test test/free_design/dsl/ --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## 7. Appendix: DSL Grammar Reference

```ebnf
document      = version_header newline+ frame+
version_header = "dsl:" version
version       = "1"

frame         = "frame" ws name [frame_props] newline node_tree
name          = identifier | quoted_string
frame_props   = ws "-" ws property+

node_tree     = node (newline node_tree)?
node          = indent node_decl [content] [node_props]
node_decl     = node_type "#" identifier
node_type     = "container" | "row" | "column" | "col" | "text" | "img"
              | "icon" | "spacer" | "use" | "slot"
content       = ws quoted_string
node_props    = ws "-" ws property+

property      = prop_name [ws prop_value]
prop_name     = "w" | "h" | "pos" | "x" | "y" | "gap" | "pad" | "align"
              | "bg" | "r" | "border" | "opacity" | "visible"
              | "size" | "weight" | "color" | "textAlign" | "family"
              | "iconSet" | "fit" | "alt" | "clip" | "scroll" | "flex"
prop_value    = number | "fill" | "abs" | hex_color | token_ref
              | identifier | quoted_string | value_list
value_list    = value ("," value)*
token_ref     = "{" token_path "}" | "$" token_path
token_path    = identifier ("." identifier)*

identifier    = [a-zA-Z_][a-zA-Z0-9_-]*
quoted_string = '"' (escaped_char | [^"])* '"'
hex_color     = "#" [0-9a-fA-F]{3,8}
number        = "-"? [0-9]+ ("." [0-9]+)?
ws            = " "+
indent        = "  "+  (* 2 spaces per level *)
newline       = "\n" | "\r\n"
```

---

## 8. References

- `distill_editor/lib/src/free_design/dsl/dsl_parser.dart` - Parser implementation
- `distill_editor/lib/src/free_design/dsl/dsl_exporter.dart` - Exporter implementation
- `distill_editor/lib/src/free_design/dsl/grammar.dart` - Grammar constants
- `distill_editor/lib/src/free_design/models/` - IR model definitions
