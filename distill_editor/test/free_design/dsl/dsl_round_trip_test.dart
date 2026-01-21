import 'package:flutter_test/flutter_test.dart';
import 'package:distill_editor/src/free_design/free_design.dart';

void main() {
  late DslParser parser;
  const exporter = DslExporter();

  setUp(() {
    parser = DslParser();
  });

  /// Helper to verify round-trip fidelity.
  ///
  /// Parses DSL, constructs document, exports back to DSL, parses again,
  /// and compares the resulting node trees.
  void verifyRoundTrip(String originalDsl, {String? description}) {
    // Parse original DSL
    final result1 = parser.parse(originalDsl);

    // Construct document from parse result
    final doc = EditorDocument(
      documentId: 'test',
      frames: {result1.frame.id: result1.frame},
      nodes: result1.nodes,
    );

    // Export back to DSL
    final exportedDsl = exporter.exportFrame(doc, result1.frame.id);

    // Parse exported DSL with fresh parser
    final parser2 = DslParser();
    final result2 = parser2.parse(exportedDsl);

    // Verify frame properties
    expect(result2.frame.name, equals(result1.frame.name),
        reason: 'Frame name mismatch');
    expect(result2.frame.canvas.size.width, equals(result1.frame.canvas.size.width),
        reason: 'Frame width mismatch');
    expect(result2.frame.canvas.size.height, equals(result1.frame.canvas.size.height),
        reason: 'Frame height mismatch');

    // Verify all nodes
    expect(result2.nodes.length, equals(result1.nodes.length),
        reason: 'Node count mismatch');

    for (final nodeId in result1.nodes.keys) {
      final node1 = result1.nodes[nodeId]!;
      final node2 = result2.nodes[nodeId];

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
    test('fixed size', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - w 200 h 100
''');
    });

    test('fill size', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - w fill h fill
    container#child - w fill
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

    test('token-based gap', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - gap {spacing.md}
    text#child "Content"
''');
    });

    test('token-based padding', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - pad {spacing.lg}
    text#child "Content"
''');
    });

    test('symmetric padding', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - pad 8,16
    text#child "Content"
''');
    });

    test('per-side padding', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - pad 1,2,3,4
    text#child "Content"
''');
    });

    test('center alignment', () {
      verifyRoundTrip('''
dsl:1
frame Test
  row#root - align center,center
    text#child "Centered"
''');
    });

    test('space between alignment', () {
      verifyRoundTrip('''
dsl:1
frame Test
  row#root - align spaceBetween,stretch
    text#a "A"
    text#b "B"
''');
    });
  });

  group('Style Round-Trips', () {
    test('hex background', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg #FF5500
''');
    });

    test('token background', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg {color.primary}
''');
    });

    test('uniform corner radius', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - r 8
''');
    });

    test('per-corner radius', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - r 8,8,0,0
''');
    });

    test('token radius', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - r {radius.md}
''');
    });

    test('opacity', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - opacity 0.5
''');
    });

    test('visibility false', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - visible false
''');
    });

    test('linear gradient with angle', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg linear(90,#FF0000,#0000FF)
''');
    });

    test('linear gradient with default angle', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg linear(#FF0000,#00FF00,#0000FF)
''');
    });

    test('linear gradient with token colors', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg linear(45,{color.primary},{color.secondary})
''');
    });

    test('radial gradient', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg radial(#FF0000,#0000FF)
''');
    });

    test('radial gradient with multiple stops', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg radial(#FF0000,#00FF00,#0000FF)
''');
    });

    test('radial gradient with token colors', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - bg radial({color.primary},{color.secondary})
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

    test('spacer with default flex', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root
    text#top "Top"
    spacer#flex
    text#bottom "Bottom"
''');
    });

    test('container with clip', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - w 300 h 200 clip
''');
    });

    test('container with scroll', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - scroll vertical
''');
    });

    test('instance', () {
      verifyRoundTrip('''
dsl:1
frame Test
  use#btn "ButtonPrimary"
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
      column#card1 - w 280 pad 16 bg #FFFFFF r 12 gap 8
        img#img1 "https://example.com/1.jpg" - w fill h 180 r 8
        text#title1 "Item One" - size 18 weight 600
        text#price1 "29.99" - size 16 color {color.primary}
      column#card2 - w 280 pad 16 bg #FFFFFF r 12 gap 8
        img#img2 "https://example.com/2.jpg" - w fill h 180 r 8
        text#title2 "Item Two" - size 18 weight 600
        text#price2 "39.99" - size 16 color {color.primary}
''');
    });

    test('deep nesting', () {
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
  });

  group('Edge Cases', () {
    test('empty text content', () {
      verifyRoundTrip('''
dsl:1
frame Test
  text#empty ""
''');
    });

    test('decimal values', () {
      verifyRoundTrip('''
dsl:1
frame Test
  container#root - w 100.5 h 200.75 opacity 0.85
''');
    });

    test('frame with custom dimensions', () {
      verifyRoundTrip('''
dsl:1
frame Test - w 1920 h 1080
  container#root
''');
    });

    test('frame with quoted name', () {
      verifyRoundTrip('''
dsl:1
frame "Login Screen"
  container#root
''');
    });

    test('multiple properties combined', () {
      verifyRoundTrip('''
dsl:1
frame Test
  column#root - w fill h fill pad 24 gap 16 bg #FFFFFF r 8 align center,start
    text#title "Title" - size 24 weight 700 color #000000 textAlign center
''');
    });
  });
}

// ============================================================================
// Comparison Helpers
// ============================================================================

void _compareLayouts(NodeLayout a, NodeLayout b, String nodeId) {
  // Compare size
  expect(b.size.width.runtimeType, equals(a.size.width.runtimeType),
      reason: 'Width type mismatch for $nodeId');
  expect(b.size.height.runtimeType, equals(a.size.height.runtimeType),
      reason: 'Height type mismatch for $nodeId');

  if (a.size.width is AxisSizeFixed) {
    expect((b.size.width as AxisSizeFixed).value,
        equals((a.size.width as AxisSizeFixed).value),
        reason: 'Width value mismatch for $nodeId');
  }

  if (a.size.height is AxisSizeFixed) {
    expect((b.size.height as AxisSizeFixed).value,
        equals((a.size.height as AxisSizeFixed).value),
        reason: 'Height value mismatch for $nodeId');
  }

  // Compare position
  expect(b.position.runtimeType, equals(a.position.runtimeType),
      reason: 'Position type mismatch for $nodeId');

  if (a.position is PositionModeAbsolute) {
    final posA = a.position as PositionModeAbsolute;
    final posB = b.position as PositionModeAbsolute;
    expect(posB.x, equals(posA.x), reason: 'Position X mismatch for $nodeId');
    expect(posB.y, equals(posA.y), reason: 'Position Y mismatch for $nodeId');
  }

  // Compare autoLayout
  if (a.autoLayout != null) {
    expect(b.autoLayout, isNotNull, reason: 'AutoLayout missing for $nodeId');
    expect(b.autoLayout!.direction, equals(a.autoLayout!.direction),
        reason: 'Direction mismatch for $nodeId');
    expect(b.autoLayout!.mainAlign, equals(a.autoLayout!.mainAlign),
        reason: 'MainAlign mismatch for $nodeId');
    expect(b.autoLayout!.crossAlign, equals(a.autoLayout!.crossAlign),
        reason: 'CrossAlign mismatch for $nodeId');

    _compareNumericValues(a.autoLayout!.gap, b.autoLayout!.gap, '$nodeId.gap');
    _comparePadding(a.autoLayout!.padding, b.autoLayout!.padding, nodeId);
  }
}

void _compareStyles(NodeStyle a, NodeStyle b, String nodeId) {
  // Fill comparison
  if (a.fill != null) {
    expect(b.fill, isNotNull, reason: 'Fill missing for $nodeId');
    expect(b.fill.runtimeType, equals(a.fill.runtimeType),
        reason: 'Fill type mismatch for $nodeId');

    if (a.fill is SolidFill) {
      final fillA = a.fill as SolidFill;
      final fillB = b.fill as SolidFill;
      expect(fillB.color.runtimeType, equals(fillA.color.runtimeType));
      if (fillA.color is HexColor) {
        expect((fillB.color as HexColor).hex, equals((fillA.color as HexColor).hex));
      }
    } else if (a.fill is TokenFill) {
      expect((b.fill as TokenFill).tokenRef, equals((a.fill as TokenFill).tokenRef));
    } else if (a.fill is GradientFill) {
      final fillA = a.fill as GradientFill;
      final fillB = b.fill as GradientFill;
      expect(fillB.gradientType, equals(fillA.gradientType),
          reason: 'Gradient type mismatch for $nodeId');
      expect(fillB.stops.length, equals(fillA.stops.length),
          reason: 'Gradient stop count mismatch for $nodeId');
      for (var i = 0; i < fillA.stops.length; i++) {
        expect(fillB.stops[i].position, equals(fillA.stops[i].position),
            reason: 'Gradient stop $i position mismatch for $nodeId');
        _compareColors(fillA.stops[i].color, fillB.stops[i].color, '$nodeId.gradient.stop[$i]');
      }
      if (fillA.gradientType == GradientType.linear) {
        expect(fillB.angle, equals(fillA.angle),
            reason: 'Gradient angle mismatch for $nodeId');
      }
    }
  }

  // Corner radius comparison
  if (a.cornerRadius != null) {
    expect(b.cornerRadius, isNotNull, reason: 'CornerRadius missing for $nodeId');
    _compareNumericValues(a.cornerRadius!.topLeft, b.cornerRadius!.topLeft, '$nodeId.r.tl');
    _compareNumericValues(a.cornerRadius!.topRight, b.cornerRadius!.topRight, '$nodeId.r.tr');
    _compareNumericValues(a.cornerRadius!.bottomRight, b.cornerRadius!.bottomRight, '$nodeId.r.br');
    _compareNumericValues(a.cornerRadius!.bottomLeft, b.cornerRadius!.bottomLeft, '$nodeId.r.bl');
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
      expect(bText.text, equals(a.text), reason: 'Text content mismatch for $nodeId');
      expect(bText.fontSize, equals(a.fontSize), reason: 'FontSize mismatch for $nodeId');
      expect(bText.fontWeight, equals(a.fontWeight), reason: 'FontWeight mismatch for $nodeId');
      expect(bText.color, equals(a.color), reason: 'Color mismatch for $nodeId');
      expect(bText.textAlign, equals(a.textAlign), reason: 'TextAlign mismatch for $nodeId');
      expect(bText.fontFamily, equals(a.fontFamily), reason: 'FontFamily mismatch for $nodeId');

    case IconProps():
      final bIcon = b as IconProps;
      expect(bIcon.icon, equals(a.icon), reason: 'Icon name mismatch for $nodeId');
      expect(bIcon.iconSet, equals(a.iconSet), reason: 'IconSet mismatch for $nodeId');
      expect(bIcon.size, equals(a.size), reason: 'Size mismatch for $nodeId');
      expect(bIcon.color, equals(a.color), reason: 'Color mismatch for $nodeId');

    case ImageProps():
      final bImage = b as ImageProps;
      expect(bImage.src, equals(a.src), reason: 'Src mismatch for $nodeId');
      expect(bImage.fit, equals(a.fit), reason: 'Fit mismatch for $nodeId');
      expect(bImage.alt, equals(a.alt), reason: 'Alt mismatch for $nodeId');

    case ContainerProps():
      final bContainer = b as ContainerProps;
      expect(bContainer.clipContent, equals(a.clipContent), reason: 'ClipContent mismatch for $nodeId');
      expect(bContainer.scrollDirection, equals(a.scrollDirection), reason: 'ScrollDirection mismatch for $nodeId');

    case SpacerProps():
      final bSpacer = b as SpacerProps;
      expect(bSpacer.flex, equals(a.flex), reason: 'Flex mismatch for $nodeId');

    case InstanceProps():
      final bInstance = b as InstanceProps;
      expect(bInstance.componentId, equals(a.componentId), reason: 'ComponentId mismatch for $nodeId');

    case SlotProps():
      final bSlot = b as SlotProps;
      expect(bSlot.slotName, equals(a.slotName), reason: 'SlotName mismatch for $nodeId');
  }
}

void _compareNumericValues(NumericValue? a, NumericValue? b, String context) {
  if (a == null) {
    // Note: Default values may be null in one place and non-null in another,
    // so we check for semantic equivalence
    if (b != null && b is FixedNumeric && b.value == 0) {
      return; // Zero and null are equivalent for these purposes
    }
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

void _compareColors(ColorValue a, ColorValue b, String context) {
  expect(b.runtimeType, equals(a.runtimeType), reason: '$context color type mismatch');
  if (a is HexColor) {
    expect((b as HexColor).hex, equals(a.hex), reason: '$context hex mismatch');
  } else if (a is TokenColor) {
    expect((b as TokenColor).tokenRef, equals(a.tokenRef), reason: '$context token mismatch');
  }
}
