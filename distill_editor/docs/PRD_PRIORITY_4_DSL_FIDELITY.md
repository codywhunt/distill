# PRD: Priority 4 - DSL Round-Trip Fidelity

## Overview

The DSL (Domain-Specific Language) is the contract between human editing and AI generation. If `parse(export(document)) != document`, AI-generated content silently loses properties, edits disappear on regeneration, and debugging becomes a nightmare.

**Status:** Partial - Tests exist but no systematic coverage audit
**Dependencies:** None (foundational)
**Estimated Complexity:** Medium

---

## Problem Statement

The DSL serves as the communication layer between:
1. **AI → Editor**: AI generates DSL, editor parses it
2. **Editor → AI**: Editor exports context as DSL for AI prompts
3. **Serialization**: DSL is more compact than JSON for storage/transmission

Currently, there's no systematic verification that all IR properties survive a round-trip through the DSL. Unknown gaps could cause:
- Silent data loss when AI generates frames
- Properties disappearing after AI updates
- Inconsistent behavior between UI editing and AI editing

---

## Goals

1. **Complete property coverage**: Every property in the IR has a DSL representation
2. **Verified round-trip**: `parse(export(doc)) == doc` for all valid documents
3. **Edge case handling**: Special characters, empty values, deep nesting all work
4. **Documented grammar**: Clear specification of DSL syntax
5. **Fuzz testing**: Random valid documents round-trip successfully

---

## Non-Goals (Out of Scope)

- DSL syntax changes (optimize existing grammar, not redesign)
- New DSL features (annotations, comments, etc.)
- Performance optimization (correctness first)
- Backward compatibility with hypothetical old DSL versions

---

## Success Criteria

| Criterion | Metric | Validation Method |
|-----------|--------|-------------------|
| Node property coverage | 100% of Node properties | Audit + test matrix |
| NodeLayout property coverage | 100% of NodeLayout properties | Audit + test matrix |
| NodeStyle property coverage | 100% of NodeStyle properties | Audit + test matrix |
| NodeProps coverage | All 7 node types' props | Audit + test matrix |
| Fuzz test pass rate | 1000 random docs round-trip | Automated fuzz test |
| Empty string text | Preserved | Unit test |
| Unicode text | Preserved | Unit test |
| Token references | `{color.primary}` preserved | Unit test |
| Deep nesting | 10+ levels | Unit test |
| All node types | 7 types covered | Unit test matrix |
| Component overrides | Preserved | Unit test |

---

## Technical Architecture

### 1. Property Coverage Audit

#### Node Base Properties

| Property | DSL Syntax | Current Status | Notes |
|----------|-----------|----------------|-------|
| `id` | `type#id` | ✅ Supported | Required for AI patching |
| `type` | `container\|text\|image\|...` | ✅ Supported | First token |
| `children` | Indentation hierarchy | ✅ Supported | Structural |

#### NodeLayout Properties

| Property | DSL Syntax | Status | Example |
|----------|-----------|--------|---------|
| `position.x` | `x 100` | ⚠️ Audit | Absolute only |
| `position.y` | `y 100` | ⚠️ Audit | Absolute only |
| `size.width.value` | `w 100` | ✅ Supported | |
| `size.width.mode` | `w fill\|hug` | ⚠️ Audit | Fixed implied |
| `size.height.value` | `h 100` | ✅ Supported | |
| `size.height.mode` | `h fill\|hug` | ⚠️ Audit | Fixed implied |
| `rotation` | `rotate 45` | ⚠️ Audit | Degrees |
| `padding.all` | `pad 16` | ✅ Supported | |
| `padding.horizontal` | `padX 16` | ⚠️ Audit | |
| `padding.vertical` | `padY 16` | ⚠️ Audit | |
| `padding.top/right/bottom/left` | `padT 8 padR 12...` | ⚠️ Audit | Individual |
| `autoLayout.direction` | `row\|column` | ✅ Supported | |
| `autoLayout.gap` | `gap 8` | ✅ Supported | |
| `autoLayout.mainAxisAlignment` | `align start\|center\|end\|between\|around` | ⚠️ Audit | |
| `autoLayout.crossAxisAlignment` | `cross start\|center\|end\|stretch` | ⚠️ Audit | |
| `constraints.minWidth` | `minW 100` | ⚠️ Audit | |
| `constraints.maxWidth` | `maxW 400` | ⚠️ Audit | |
| `constraints.minHeight` | `minH 100` | ⚠️ Audit | |
| `constraints.maxHeight` | `maxH 400` | ⚠️ Audit | |

#### NodeStyle Properties

| Property | DSL Syntax | Status | Example |
|----------|-----------|--------|---------|
| `fill.type` | `bg \|none` | ✅ Supported | |
| `fill.color` | `bg #FFFFFF` | ✅ Supported | Solid |
| `fill.gradient` | `bg linear(...)` | ❌ Not supported | TODO |
| `stroke.width` | `border 1` | ✅ Supported | |
| `stroke.color` | `border 1 #CCC` | ✅ Supported | |
| `stroke.position` | `borderPos inside\|outside\|center` | ⚠️ Audit | |
| `cornerRadius.all` | `r 8` | ✅ Supported | |
| `cornerRadius.topLeft/topRight/...` | `rTL 8 rTR 4...` | ⚠️ Audit | Individual |
| `shadow.offsetX` | `shadow 0,2,8,#0001` | ⚠️ Audit | Combined |
| `shadow.offsetY` | (in shadow) | ⚠️ Audit | |
| `shadow.blur` | (in shadow) | ⚠️ Audit | |
| `shadow.color` | (in shadow) | ⚠️ Audit | |
| `opacity` | `opacity 0.5` | ⚠️ Audit | |
| `blendMode` | `blend multiply` | ⚠️ Audit | |
| `overflow` | `clip\|visible` | ⚠️ Audit | |

#### Node Type-Specific Props

**Text Node:**
| Property | DSL Syntax | Status |
|----------|-----------|--------|
| `text` | `"content"` | ✅ Supported |
| `fontSize` | `size 16` | ✅ Supported |
| `fontWeight` | `weight 400\|700` | ✅ Supported |
| `fontFamily` | `font "Roboto"` | ⚠️ Audit |
| `color` | `color #000` | ✅ Supported |
| `textAlign` | `textAlign left\|center\|right` | ⚠️ Audit |
| `lineHeight` | `lineH 1.5` | ⚠️ Audit |
| `letterSpacing` | `tracking 0.5` | ⚠️ Audit |
| `textDecoration` | `underline\|strikethrough` | ⚠️ Audit |
| `maxLines` | `maxLines 2` | ⚠️ Audit |
| `overflow` | `textOverflow ellipsis` | ⚠️ Audit |

**Image Node:**
| Property | DSL Syntax | Status |
|----------|-----------|--------|
| `src` | `src "url"` | ✅ Supported |
| `fit` | `fit cover\|contain\|fill` | ⚠️ Audit |
| `alignment` | `imgAlign center` | ⚠️ Audit |

**Icon Node:**
| Property | DSL Syntax | Status |
|----------|-----------|--------|
| `icon` | `icon "name"` | ✅ Supported |
| `size` | `size 24` | ⚠️ Audit |
| `color` | `color #000` | ⚠️ Audit |

**Instance Node:**
| Property | DSL Syntax | Status |
|----------|-----------|--------|
| `componentId` | `use "ComponentName"` | ✅ Supported |
| `overrides` | Nested syntax | ⚠️ Audit |

**Spacer Node:**
| Property | DSL Syntax | Status |
|----------|-----------|--------|

### 2. Test Matrix Implementation

```dart
/// Comprehensive property coverage test
class DslPropertyCoverageTest {
  /// All NodeLayout properties to test
  static final layoutProperties = [
    PropertyTest(
      name: 'position.x',
      createNode: (value) => createContainer(layout: NodeLayout(
        position: Position(x: value, y: 0),
      )),
      values: [0.0, 100.0, -50.0, 999.5],
      extractValue: (node) => node.layout.position?.x,
    ),
    PropertyTest(
      name: 'position.y',
      createNode: (value) => createContainer(layout: NodeLayout(
        position: Position(x: 0, y: value),
      )),
      values: [0.0, 100.0, -50.0, 999.5],
      extractValue: (node) => node.layout.position?.y,
    ),
    PropertyTest(
      name: 'size.width.fixed',
      createNode: (value) => createContainer(layout: NodeLayout(
        size: SizeDimensions(
          width: SizeDimension(value: value, mode: SizeMode.fixed),
          height: SizeDimension(value: 100, mode: SizeMode.fixed),
        ),
      )),
      values: [100.0, 375.0, 0.0],
      extractValue: (node) => node.layout.size?.width?.value,
    ),
    PropertyTest(
      name: 'size.width.fill',
      createNode: (_) => createContainer(layout: NodeLayout(
        size: SizeDimensions(
          width: SizeDimension(value: null, mode: SizeMode.fill),
          height: SizeDimension(value: 100, mode: SizeMode.fixed),
        ),
      )),
      values: [null],
      extractValue: (node) => node.layout.size?.width?.mode,
      expectedValue: SizeMode.fill,
    ),
    // ... more properties
  ];

  /// All NodeStyle properties to test
  static final styleProperties = [
    PropertyTest(
      name: 'fill.solid',
      createNode: (color) => createContainer(style: NodeStyle(
        fill: Fill(type: FillType.solid, color: color),
      )),
      values: ['#FF0000', '#00FF00', '#FFFFFF', '#000000'],
      extractValue: (node) => node.style?.fill?.color,
    ),
    PropertyTest(
      name: 'cornerRadius.all',
      createNode: (value) => createContainer(style: NodeStyle(
        cornerRadius: CornerRadius.all(value),
      )),
      values: [0.0, 8.0, 16.0, 9999.0],
      extractValue: (node) => node.style?.cornerRadius?.all,
    ),
    // ... more properties
  ];
}

/// Single property test case
class PropertyTest<T> {
  final String name;
  final Node Function(T value) createNode;
  final List<T> values;
  final dynamic Function(Node node) extractValue;
  final dynamic expectedValue;

  PropertyTest({
    required this.name,
    required this.createNode,
    required this.values,
    required this.extractValue,
    this.expectedValue,
  });

  /// Run round-trip test for all values
  void runTest() {
    for (final value in values) {
      final original = createNode(value);
      final dsl = DslExporter.exportNode(original);
      final parsed = DslParser.parseNode(dsl);

      final originalValue = extractValue(original);
      final parsedValue = extractValue(parsed);
      final expected = expectedValue ?? originalValue;

      expect(
        parsedValue,
        equals(expected),
        reason: 'Property $name failed round-trip for value $value\n'
                'DSL: $dsl\n'
                'Original: $originalValue\n'
                'Parsed: $parsedValue',
      );
    }
  }
}
```

### 3. Fuzz Testing

```dart
/// Random document generator for fuzz testing
class DocumentFuzzer {
  final Random _random;
  int _nodeCounter = 0;

  DocumentFuzzer([int? seed]) : _random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  /// Generate random valid EditorDocument
  EditorDocument generateDocument({
    int frameCount = 3,
    int maxDepth = 5,
    int maxChildrenPerNode = 4,
  }) {
    final frames = <String, Frame>{};
    final nodes = <String, Node>{};

    for (var i = 0; i < frameCount; i++) {
      final frameId = 'frame_$i';
      final rootNodeId = 'n_root_$i';

      // Generate node tree
      final rootNode = _generateNodeTree(
        depth: 0,
        maxDepth: maxDepth,
        maxChildren: maxChildrenPerNode,
        nodes: nodes,
      );

      nodes[rootNode.id] = rootNode;

      frames[frameId] = Frame(
        id: frameId,
        name: 'Frame $i',
        rootNodeId: rootNode.id,
        canvas: CanvasPlacement(
          position: Offset(_random.nextDouble() * 1000, _random.nextDouble() * 1000),
          size: Size(375, 812),
        ),
      );
    }

    return EditorDocument(
      irVersion: '1.0',
      documentId: 'fuzz_${DateTime.now().millisecondsSinceEpoch}',
      frames: frames,
      nodes: nodes,
      components: {},
      theme: ThemeDocument.empty(),
    );
  }

  /// Generate random node tree recursively
  Node _generateNodeTree({
    required int depth,
    required int maxDepth,
    required int maxChildren,
    required Map<String, Node> nodes,
  }) {
    final nodeId = 'n_${_nodeCounter++}';
    final nodeType = _randomNodeType(depth, maxDepth);

    final children = <String>[];

    // Generate children for containers (not at max depth)
    if (nodeType == NodeType.container && depth < maxDepth) {
      final childCount = _random.nextInt(maxChildren + 1);
      for (var i = 0; i < childCount; i++) {
        final child = _generateNodeTree(
          depth: depth + 1,
          maxDepth: maxDepth,
          maxChildren: maxChildren,
          nodes: nodes,
        );
        nodes[child.id] = child;
        children.add(child.id);
      }
    }

    return Node(
      id: nodeId,
      type: nodeType,
      children: children,
      layout: _generateRandomLayout(),
      style: _generateRandomStyle(),
      props: _generateRandomProps(nodeType),
    );
  }

  NodeType _randomNodeType(int depth, int maxDepth) {
    // Leaf nodes at max depth
    if (depth >= maxDepth) {
      final leafTypes = [NodeType.text, NodeType.image, NodeType.icon, NodeType.spacer];
      return leafTypes[_random.nextInt(leafTypes.length)];
    }

    // Weighted distribution favoring containers
    final types = [
      NodeType.container, NodeType.container, NodeType.container,
      NodeType.text, NodeType.image, NodeType.icon, NodeType.spacer,
    ];
    return types[_random.nextInt(types.length)];
  }

  NodeLayout _generateRandomLayout() {
    return NodeLayout(
      position: _random.nextBool() ? Position(
        x: _random.nextDouble() * 500,
        y: _random.nextDouble() * 500,
      ) : null,
      size: SizeDimensions(
        width: _randomSizeDimension(),
        height: _randomSizeDimension(),
      ),
      padding: _random.nextBool() ? _randomEdgeInsets() : null,
      autoLayout: _random.nextBool() ? _randomAutoLayout() : null,
      rotation: _random.nextBool() ? _random.nextDouble() * 360 : null,
    );
  }

  SizeDimension _randomSizeDimension() {
    final mode = SizeMode.values[_random.nextInt(SizeMode.values.length)];
    return SizeDimension(
      value: mode == SizeMode.fixed ? _random.nextDouble() * 400 + 50 : null,
      mode: mode,
    );
  }

  EdgeInsets _randomEdgeInsets() {
    if (_random.nextBool()) {
      // Uniform
      return EdgeInsets.all(_random.nextDouble() * 32);
    } else {
      // Individual
      return EdgeInsets.only(
        top: _random.nextDouble() * 32,
        right: _random.nextDouble() * 32,
        bottom: _random.nextDouble() * 32,
        left: _random.nextDouble() * 32,
      );
    }
  }

  AutoLayout _randomAutoLayout() {
    return AutoLayout(
      direction: _random.nextBool() ? LayoutDirection.row : LayoutDirection.column,
      gap: _random.nextDouble() * 24,
      mainAxisAlignment: MainAxisAlignment.values[_random.nextInt(MainAxisAlignment.values.length)],
      crossAxisAlignment: CrossAxisAlignment.values[_random.nextInt(CrossAxisAlignment.values.length)],
    );
  }

  NodeStyle _generateRandomStyle() {
    return NodeStyle(
      fill: _random.nextBool() ? Fill(
        type: FillType.solid,
        color: _randomColor(),
      ) : null,
      stroke: _random.nextBool() ? Stroke(
        width: _random.nextDouble() * 4,
        color: _randomColor(),
      ) : null,
      cornerRadius: _random.nextBool() ? CornerRadius.all(_random.nextDouble() * 20) : null,
      opacity: _random.nextBool() ? _random.nextDouble() : null,
      shadow: _random.nextBool() ? Shadow(
        offsetX: _random.nextDouble() * 10 - 5,
        offsetY: _random.nextDouble() * 10,
        blur: _random.nextDouble() * 20,
        color: _randomColor(withAlpha: true),
      ) : null,
    );
  }

  String _randomColor({bool withAlpha = false}) {
    final r = _random.nextInt(256).toRadixString(16).padLeft(2, '0');
    final g = _random.nextInt(256).toRadixString(16).padLeft(2, '0');
    final b = _random.nextInt(256).toRadixString(16).padLeft(2, '0');

    if (withAlpha) {
      final a = _random.nextInt(256).toRadixString(16).padLeft(2, '0');
      return '#$r$g$b$a'.toUpperCase();
    }
    return '#$r$g$b'.toUpperCase();
  }

  NodeProps _generateRandomProps(NodeType type) {
    switch (type) {
      case NodeType.text:
        return NodeProps(text: _randomText());
      case NodeType.image:
        return NodeProps(src: 'https://example.com/image_${_random.nextInt(100)}.png');
      case NodeType.icon:
        return NodeProps(icon: _randomIcon());
      default:
        return NodeProps();
    }
  }

  String _randomText() {
    final texts = [
      'Hello World',
      'Button',
      'Lorem ipsum dolor sit amet',
      '', // Empty string edge case
      'Special chars: <>&"\'',
      'Unicode: 你好 🎉 émoji',
      'Multi\nline\ntext',
    ];
    return texts[_random.nextInt(texts.length)];
  }

  String _randomIcon() {
    final icons = ['home', 'settings', 'add', 'close', 'menu', 'search'];
    return icons[_random.nextInt(icons.length)];
  }
}

/// Fuzz test runner
class DslFuzzTester {
  final DocumentFuzzer fuzzer;
  final List<FuzzFailure> failures = [];

  DslFuzzTester([int? seed]) : fuzzer = DocumentFuzzer(seed);

  /// Run fuzz test with specified iterations
  FuzzTestResult run({int iterations = 1000}) {
    failures.clear();

    for (var i = 0; i < iterations; i++) {
      final document = fuzzer.generateDocument();

      try {
        _testRoundTrip(document, iteration: i);
      } catch (e, stack) {
        failures.add(FuzzFailure(
          iteration: i,
          document: document,
          error: e,
          stackTrace: stack,
        ));
      }
    }

    return FuzzTestResult(
      iterations: iterations,
      failures: failures,
      passRate: (iterations - failures.length) / iterations,
    );
  }

  void _testRoundTrip(EditorDocument document, {required int iteration}) {
    for (final frame in document.frames.values) {
      // Export to DSL
      final dsl = DslExporter.exportFrame(
        frame: frame,
        nodes: document.nodes,
      );

      // Parse back
      final parseResult = DslParser.parseFrame(dsl);

      // Compare
      final differences = _compareFrames(
        original: frame,
        originalNodes: document.nodes,
        parsed: parseResult.frame,
        parsedNodes: parseResult.nodes,
      );

      if (differences.isNotEmpty) {
        throw DslFidelityException(
          frameId: frame.id,
          dsl: dsl,
          differences: differences,
        );
      }
    }
  }

  List<String> _compareFrames({
    required Frame original,
    required Map<String, Node> originalNodes,
    required Frame parsed,
    required Map<String, Node> parsedNodes,
  }) {
    final differences = <String>[];

    // Compare frame properties
    if (original.name != parsed.name) {
      differences.add('Frame name: "${original.name}" vs "${parsed.name}"');
    }

    // Compare node trees
    _compareNodeTree(
      originalId: original.rootNodeId,
      parsedId: parsed.rootNodeId,
      originalNodes: originalNodes,
      parsedNodes: parsedNodes,
      differences: differences,
      path: 'root',
    );

    return differences;
  }

  void _compareNodeTree({
    required String originalId,
    required String parsedId,
    required Map<String, Node> originalNodes,
    required Map<String, Node> parsedNodes,
    required List<String> differences,
    required String path,
  }) {
    final original = originalNodes[originalId];
    final parsed = parsedNodes[parsedId];

    if (original == null || parsed == null) {
      differences.add('$path: Missing node');
      return;
    }

    // Compare type
    if (original.type != parsed.type) {
      differences.add('$path.type: ${original.type} vs ${parsed.type}');
    }

    // Compare layout
    _compareLayout(original.layout, parsed.layout, differences, path);

    // Compare style
    _compareStyle(original.style, parsed.style, differences, path);

    // Compare props
    _compareProps(original.props, parsed.props, differences, path);

    // Compare children count
    if (original.children.length != parsed.children.length) {
      differences.add('$path.children.length: ${original.children.length} vs ${parsed.children.length}');
    }

    // Recursively compare children
    final minChildren = min(original.children.length, parsed.children.length);
    for (var i = 0; i < minChildren; i++) {
      _compareNodeTree(
        originalId: original.children[i],
        parsedId: parsed.children[i],
        originalNodes: originalNodes,
        parsedNodes: parsedNodes,
        differences: differences,
        path: '$path.children[$i]',
      );
    }
  }

  // Helper comparison methods...
}
```

### 4. Edge Case Tests

```dart
/// Edge case specific tests
group('DSL Edge Cases', () {
  test('empty string text preserved', () {
    final node = Node(
      id: 'n_text',
      type: NodeType.text,
      props: NodeProps(text: ''),
    );

    final dsl = DslExporter.exportNode(node);
    final parsed = DslParser.parseNode(dsl);

    expect(parsed.props.text, equals(''));
  });

  test('unicode text preserved', () {
    final testStrings = [
      '你好世界',
      'émojis 🎉🚀💡',
      'مرحبا بالعالم',
      'Mixed 123 αβγ',
    ];

    for (final text in testStrings) {
      final node = Node(
        id: 'n_text',
        type: NodeType.text,
        props: NodeProps(text: text),
      );

      final dsl = DslExporter.exportNode(node);
      final parsed = DslParser.parseNode(dsl);

      expect(parsed.props.text, equals(text), reason: 'Failed for: $text');
    }
  });

  test('special characters in text escaped', () {
    final testStrings = [
      'Quote: "hello"',
      "Apostrophe: it's",
      'Newline:\nline2',
      'Tab:\there',
      'Backslash: \\path',
    ];

    for (final text in testStrings) {
      final node = Node(
        id: 'n_text',
        type: NodeType.text,
        props: NodeProps(text: text),
      );

      final dsl = DslExporter.exportNode(node);
      final parsed = DslParser.parseNode(dsl);

      expect(parsed.props.text, equals(text), reason: 'Failed for: $text');
    }
  });

  test('token references preserved', () {
    final node = Node(
      id: 'n_container',
      type: NodeType.container,
      style: NodeStyle(
        fill: Fill(
          type: FillType.solid,
          color: '{color.primary}',
        ),
      ),
      layout: NodeLayout(
        padding: EdgeInsets.all('{spacing.md}'),
      ),
    );

    final dsl = DslExporter.exportNode(node);
    final parsed = DslParser.parseNode(dsl);

    expect(parsed.style?.fill?.color, equals('{color.primary}'));
    // Note: Padding with token refs needs special handling
  });

  test('deep nesting preserved', () {
    // Create 15-level deep tree
    Node createDeepTree(int depth, int maxDepth) {
      final nodeId = 'n_$depth';
      if (depth >= maxDepth) {
        return Node(id: nodeId, type: NodeType.text, props: NodeProps(text: 'Leaf $depth'));
      }

      final child = createDeepTree(depth + 1, maxDepth);
      return Node(
        id: nodeId,
        type: NodeType.container,
        children: [child.id],
      );
    }

    final root = createDeepTree(0, 15);
    final nodes = <String, Node>{};
    void collectNodes(Node node) {
      nodes[node.id] = node;
      // Note: This simplified version; real impl would traverse properly
    }

    // Export and parse
    final frame = Frame(id: 'f', name: 'Deep', rootNodeId: root.id, canvas: CanvasPlacement.zero);
    final dsl = DslExporter.exportFrame(frame: frame, nodes: nodes);
    final parsed = DslParser.parseFrame(dsl);

    // Count depth
    int countDepth(String nodeId, Map<String, Node> nodes) {
      final node = nodes[nodeId];
      if (node == null || node.children.isEmpty) return 1;
      return 1 + countDepth(node.children.first, nodes);
    }

    expect(countDepth(parsed.frame.rootNodeId, parsed.nodes), equals(15));
  });

  test('all seven node types round-trip', () {
    final nodes = <Node>[
      Node(id: 'n_1', type: NodeType.container),
      Node(id: 'n_2', type: NodeType.text, props: NodeProps(text: 'Hi')),
      Node(id: 'n_3', type: NodeType.image, props: NodeProps(src: 'url')),
      Node(id: 'n_4', type: NodeType.icon, props: NodeProps(icon: 'home')),
      Node(id: 'n_5', type: NodeType.spacer),
      Node(id: 'n_6', type: NodeType.instance, props: NodeProps(componentId: 'c1')),
      Node(id: 'n_7', type: NodeType.slot, props: NodeProps(slotName: 'content')),
    ];

    for (final node in nodes) {
      final dsl = DslExporter.exportNode(node);
      final parsed = DslParser.parseNode(dsl);

      expect(parsed.type, equals(node.type), reason: 'Failed for type: ${node.type}');
    }
  });

  test('component instance with overrides preserved', () {
    final node = Node(
      id: 'n_instance',
      type: NodeType.instance,
      props: NodeProps(
        componentId: 'Button',
        overrides: {
          'label': NodeProps(text: 'Click Me'),
          'icon': NodeProps(icon: 'arrow_forward'),
        },
      ),
    );

    final dsl = DslExporter.exportNode(node);
    final parsed = DslParser.parseNode(dsl);

    expect(parsed.props.componentId, equals('Button'));
    expect(parsed.props.overrides?['label']?.text, equals('Click Me'));
    expect(parsed.props.overrides?['icon']?.icon, equals('arrow_forward'));
  });

  test('zero values preserved', () {
    final node = Node(
      id: 'n',
      type: NodeType.container,
      layout: NodeLayout(
        position: Position(x: 0, y: 0),
        padding: EdgeInsets.all(0),
      ),
      style: NodeStyle(
        cornerRadius: CornerRadius.all(0),
        opacity: 0,
      ),
    );

    final dsl = DslExporter.exportNode(node);
    final parsed = DslParser.parseNode(dsl);

    expect(parsed.layout.position?.x, equals(0));
    expect(parsed.layout.position?.y, equals(0));
    expect(parsed.style?.cornerRadius?.all, equals(0));
    expect(parsed.style?.opacity, equals(0));
  });

  test('negative values preserved', () {
    final node = Node(
      id: 'n',
      type: NodeType.container,
      layout: NodeLayout(
        position: Position(x: -100, y: -50),
      ),
      style: NodeStyle(
        shadow: Shadow(offsetX: -5, offsetY: -3, blur: 10, color: '#000'),
      ),
    );

    final dsl = DslExporter.exportNode(node);
    final parsed = DslParser.parseNode(dsl);

    expect(parsed.layout.position?.x, equals(-100));
    expect(parsed.layout.position?.y, equals(-50));
    expect(parsed.style?.shadow?.offsetX, equals(-5));
  });

  test('very large values preserved', () {
    final node = Node(
      id: 'n',
      type: NodeType.container,
      layout: NodeLayout(
        position: Position(x: 999999, y: 999999),
        size: SizeDimensions(
          width: SizeDimension(value: 10000, mode: SizeMode.fixed),
          height: SizeDimension(value: 10000, mode: SizeMode.fixed),
        ),
      ),
    );

    final dsl = DslExporter.exportNode(node);
    final parsed = DslParser.parseNode(dsl);

    expect(parsed.layout.position?.x, equals(999999));
    expect(parsed.layout.size?.width?.value, equals(10000));
  });

  test('decimal precision preserved', () {
    final node = Node(
      id: 'n',
      type: NodeType.container,
      layout: NodeLayout(
        position: Position(x: 100.5, y: 200.75),
      ),
      style: NodeStyle(
        opacity: 0.333,
      ),
    );

    final dsl = DslExporter.exportNode(node);
    final parsed = DslParser.parseNode(dsl);

    expect(parsed.layout.position?.x, closeTo(100.5, 0.01));
    expect(parsed.layout.position?.y, closeTo(200.75, 0.01));
    expect(parsed.style?.opacity, closeTo(0.333, 0.001));
  });
});
```

---

## Implementation Order

1. **Phase 1: Property Audit**
   - [ ] Create complete property matrix from IR models
   - [ ] Mark each property's DSL support status
   - [ ] Identify gaps requiring parser/exporter changes

2. **Phase 2: Parser/Exporter Fixes**
   - [ ] Implement missing property exports
   - [ ] Implement missing property parsing
   - [ ] Add gradient fill support (TODO in render_compiler.dart)
   - [ ] Unit test each fixed property

3. **Phase 3: Edge Case Handling**
   - [ ] Implement edge case tests
   - [ ] Fix any failures found
   - [ ] Document escaping rules

4. **Phase 4: Fuzz Testing Infrastructure**
   - [ ] Implement DocumentFuzzer
   - [ ] Implement DslFuzzTester
   - [ ] Create CI job for fuzz testing

5. **Phase 5: Documentation**
   - [ ] Document complete DSL grammar
   - [ ] Create property reference table
   - [ ] Add examples for each property

---

## File Locations

```
lib/src/free_design/
├── dsl/
│   ├── dsl_parser.dart       # Parse DSL to IR
│   ├── dsl_exporter.dart     # Export IR to DSL
│   └── dsl_grammar.md        # NEW: Grammar documentation
└── ...

test/free_design/
├── dsl/
│   ├── dsl_parser_test.dart
│   ├── dsl_exporter_test.dart
│   ├── dsl_roundtrip_test.dart       # NEW: Round-trip tests
│   ├── dsl_edge_cases_test.dart      # NEW: Edge case tests
│   ├── dsl_property_coverage_test.dart # NEW: Property matrix
│   └── dsl_fuzz_test.dart            # NEW: Fuzz testing
└── ...
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Many properties missing support | Medium | High | Audit first, prioritize AI-used properties |
| Grammar changes break existing DSL | Low | Medium | Version DSL format, migration path |
| Fuzz tests too slow for CI | Medium | Low | Run subset in CI, full suite nightly |
| Floating point precision issues | Medium | Low | Define acceptable tolerance |

---

## Dependencies

- `DslParser` - Current parser implementation
- `DslExporter` - Current exporter implementation
- `Node`, `NodeLayout`, `NodeStyle` models - IR definitions

---

## Future Enhancements (Not in Scope)

1. **DSL v2 grammar** - Annotations, comments, includes
2. **Streaming parser** - For very large documents
3. **Partial parsing** - Update only changed sections
4. **Source maps** - Map DSL positions to IR for error reporting
