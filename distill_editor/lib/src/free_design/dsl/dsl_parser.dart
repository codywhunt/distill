import 'dart:ui';

import '../models/frame.dart';
import '../models/node.dart';
import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';
import '../models/node_type.dart';
import '../models/numeric_value.dart';
import 'grammar.dart';

/// Parses DSL text into Frame and Node structures.
///
/// The parser handles:
/// - Frame declarations with canvas dimensions
/// - Node hierarchy via 2-space indentation
/// - Inline properties with shorthand notation
/// - Explicit IDs via #id syntax
/// - Quoted string content for text nodes
class DslParser {
  int _nextId = 1;

  /// Parse full DSL document.
  ///
  /// Returns a [DslParseResult] containing the frame and all nodes.
  /// Throws [DslParseException] on syntax errors.
  DslParseResult parse(String dsl) {
    final lines = dsl.split('\n');
    if (lines.isEmpty) {
      throw DslParseException('Empty DSL input');
    }

    // Check version header
    final firstLine = lines.first.trim();
    if (!firstLine.startsWith('dsl:')) {
      throw DslParseException('Missing version header (expected "dsl:1")');
    }

    final version = firstLine.substring(4).trim();
    if (version != DslGrammar.version) {
      throw DslParseException('Unsupported DSL version: $version');
    }

    // Reset ID counter for this parse
    _nextId = 1;

    final nodes = <String, Node>{};
    Frame? frame;

    var i = 1;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Skip empty lines and comments
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('//')) {
        i++;
        continue;
      }

      final indent = _getIndent(line);

      // Frame declaration at indent 0
      if (indent == 0 && trimmed.startsWith('frame ')) {
        frame = _parseFrame(trimmed);
        i++;
        continue;
      }

      // Node tree
      if (frame != null) {
        final (rootId, parsedNodes, consumedLines) = _parseNodeTree(lines, i);
        nodes.addAll(parsedNodes);

        // Set frame root if not set
        if (frame.rootNodeId.isEmpty) {
          frame = frame.copyWith(rootNodeId: rootId);
        }

        i += consumedLines;
      } else {
        throw DslParseException('Line $i: Node found before frame declaration');
      }
    }

    if (frame == null) {
      throw DslParseException('No frame declaration found');
    }

    return DslParseResult(frame: frame, nodes: nodes);
  }

  /// Parse a frame declaration line.
  Frame _parseFrame(String line) {
    // frame Login - w 375 h 812
    // or: frame "My Frame" - w 375 h 812
    final match = RegExp(r'^frame\s+(?:"([^"]+)"|(\w+))\s*(?:-\s*(.+))?$').firstMatch(line);
    if (match == null) {
      throw DslParseException('Invalid frame declaration: $line');
    }

    final name = match.group(1) ?? match.group(2) ?? 'Untitled';
    final propsStr = match.group(3) ?? '';
    final props = _parseProps(propsStr);

    final width = _parseSizeValue(props['w'] ?? '375');
    final height = _parseSizeValue(props['h'] ?? '812');

    return Frame(
      id: 'f_${_generateId()}',
      name: name,
      rootNodeId: '', // Set later
      canvas: CanvasPlacement(
        position: Offset.zero,
        size: Size(width, height),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Parse a tree of nodes starting at the given line index.
  ///
  /// Returns (rootId, nodes, consumedLineCount).
  (String, Map<String, Node>, int) _parseNodeTree(List<String> lines, int startIdx) {
    final nodes = <String, Node>{};
    final stack = <(int, String)>[]; // (indent, nodeId)

    // Track root indent from first line
    final rootIndent = _getIndent(lines[startIdx]);

    var i = startIdx;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Skip empty lines and comments
      if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith('//')) {
        i++;
        continue;
      }

      final indent = _getIndent(line);

      // Stop if we're back at or before root indent (not first iteration)
      if (i > startIdx && indent <= rootIndent) {
        break;
      }

      // Enforce 2-space indentation multiples
      final relativeIndent = indent - rootIndent;
      if (relativeIndent % 2 != 0) {
        throw DslParseException(
          'Line $i: Invalid indentation. Must use 2-space increments. '
          'Got $relativeIndent extra spaces.',
        );
      }

      // Pop stack to current level
      while (stack.isNotEmpty && stack.last.$1 >= indent) {
        stack.removeLast();
      }

      // Parse node
      final node = _parseNode(trimmed, i);
      nodes[node.id] = node;

      // Attach to parent if any
      if (stack.isNotEmpty) {
        final parentId = stack.last.$2;
        final parent = nodes[parentId]!;
        nodes[parentId] = parent.copyWith(
          childIds: [...parent.childIds, node.id],
        );
      }

      // Push to stack
      stack.add((indent, node.id));
      i++;
    }

    if (nodes.isEmpty) {
      throw DslParseException('No nodes found starting at line $startIdx');
    }

    final rootId = nodes.values.first.id;
    return (rootId, nodes, i - startIdx);
  }

  /// Parse a single node line.
  Node _parseNode(String line, int lineNumber) {
    // Examples:
    // column#n_root - gap 24 pad 24 bg #FFFFFF
    // text "Welcome" - size 24 weight 700
    // container - h 48 bg #007AFF r 8

    var workingLine = line;
    String? explicitId;

    // Extract explicit ID if present: type#id (must be at start, no space before #)
    // This distinguishes from color values like "bg #FFFFFF"
    final idMatch = RegExp(r'^(\w+)#(\w+)').firstMatch(workingLine);
    if (idMatch != null) {
      explicitId = idMatch.group(2);
      // Remove the #id part, keep just the type
      workingLine = idMatch.group(1)! + workingLine.substring(idMatch.end);
    }

    // Parse: type ["content"] [- props...]
    final match = RegExp(r'^(\w+)\s*(?:"([^"]*)"|\(([^)]*)\))?\s*(?:-\s*(.+))?$')
        .firstMatch(workingLine.trim());

    if (match == null) {
      throw DslParseException('Line $lineNumber: Invalid node syntax: $line');
    }

    final typeStr = match.group(1)!;
    final content = match.group(2) ?? match.group(3); // Text or params
    final propsStr = match.group(4) ?? '';

    final props = _parseProps(propsStr);
    final nodeType = _mapNodeType(typeStr);
    final nodeProps = _buildNodeProps(nodeType, typeStr, content, props);
    final layout = _buildLayout(typeStr, props);
    final style = _buildStyle(props);

    final id = explicitId ?? 'n_${_generateId()}';
    final name = content ?? _capitalize(typeStr);

    return Node(
      id: id,
      name: name,
      type: nodeType,
      props: nodeProps,
      layout: layout,
      style: style,
      childIds: const [],
    );
  }

  /// Parse space-separated properties with proper lexer.
  Map<String, String> _parseProps(String propsStr) {
    final props = <String, String>{};
    if (propsStr.trim().isEmpty) return props;

    var i = 0;
    final str = propsStr.trim();

    while (i < str.length) {
      // Skip whitespace
      while (i < str.length && str[i] == ' ') {
        i++;
      }
      if (i >= str.length) break;

      // Read key
      final keyStart = i;
      while (i < str.length && str[i] != ' ' && str[i] != '"') {
        i++;
      }
      final key = str.substring(keyStart, i);
      if (key.isEmpty) break;

      // Skip whitespace
      while (i < str.length && str[i] == ' ') {
        i++;
      }

      // Check if next token starts a new key (is a known property key)
      if (i >= str.length || DslGrammar.isPropertyKey(str.substring(i).split(' ').first)) {
        // Boolean flag (key with no value)
        props[key] = 'true';
        continue;
      }

      // Read value
      String value;
      if (i < str.length && str[i] == '"') {
        // Quoted string - can contain spaces
        i++; // Skip opening quote
        final valueStart = i;
        while (i < str.length && str[i] != '"') {
          i++;
        }
        value = str.substring(valueStart, i);
        if (i < str.length) i++; // Skip closing quote
      } else {
        // Unquoted value - no spaces allowed
        final valueStart = i;
        while (i < str.length && str[i] != ' ') {
          i++;
        }
        value = str.substring(valueStart, i);
      }

      props[key] = value;
    }

    return props;
  }

  /// Map DSL type string to NodeType.
  NodeType _mapNodeType(String typeStr) {
    return switch (typeStr.toLowerCase()) {
      'container' || 'box' => NodeType.container,
      'row' => NodeType.container,
      'column' || 'col' => NodeType.container,
      'text' => NodeType.text,
      'image' || 'img' => NodeType.image,
      'icon' => NodeType.icon,
      'spacer' => NodeType.spacer,
      'use' => NodeType.instance,
      _ => throw DslParseException('Unknown node type: $typeStr'),
    };
  }

  /// Build type-specific node props.
  NodeProps _buildNodeProps(
    NodeType type,
    String typeStr,
    String? content,
    Map<String, String> props,
  ) {
    return switch (type) {
      NodeType.container => ContainerProps(
          clipContent: props['clip'] == 'true',
          scrollDirection: props['scroll'],
        ),
      NodeType.text => TextProps(
          text: content ?? '',
          fontSize: double.tryParse(props['size'] ?? '14') ?? 14,
          fontWeight: int.tryParse(props['weight'] ?? '400') ?? 400,
          color: _parseColorString(props['color'] ?? props['fg']),
          textAlign: _parseTextAlign(props['textAlign']),
          fontFamily: props['family'],
          lineHeight: double.tryParse(props['lh'] ?? ''),
          letterSpacing: double.tryParse(props['ls'] ?? ''),
          decoration: _parseTextDecoration(props['decor']),
        ),
      NodeType.image => ImageProps(
          src: content ?? props['src'] ?? '',
          fit: _parseImageFit(props['fit']),
          alt: props['alt'],
        ),
      NodeType.icon => IconProps(
          icon: content ?? props['icon'] ?? 'help',
          iconSet: props['iconSet'] ?? props['set'] ?? 'material',
          size: double.tryParse(props['size'] ?? '24') ?? 24,
          color: _parseColorString(props['color'] ?? props['fg']),
        ),
      NodeType.spacer => SpacerProps(
          flex: int.tryParse(props['flex'] ?? '1') ?? 1,
        ),
      NodeType.instance => InstanceProps(
          componentId: content ?? '',
          overrides: const {},
        ),
      NodeType.slot => SlotProps(slotName: content ?? ''),
    };
  }

  /// Build node layout from props.
  NodeLayout _buildLayout(String typeStr, Map<String, String> props) {
    // Determine auto-layout from type or properties
    final isRow = typeStr == 'row' ||
        props.containsKey('row') ||
        props['direction'] == 'horizontal';
    final isCol = typeStr == 'column' ||
        typeStr == 'col' ||
        props.containsKey('col') ||
        props.containsKey('column') ||
        props['direction'] == 'vertical';
    final hasGap = props.containsKey('gap');
    final hasPad = props.containsKey('pad');
    final hasAlign = props.containsKey('align');

    AutoLayout? autoLayout;
    if (isRow || isCol || hasGap || hasPad || hasAlign) {
      final direction = isRow ? LayoutDirection.horizontal : LayoutDirection.vertical;
      final gap = _parseNumericValue(props['gap']);
      final padding = _parseTokenPadding(props['pad']);
      final (mainAlign, crossAlign) = _parseAlignment(props['align']);

      autoLayout = AutoLayout(
        direction: direction,
        gap: gap,
        padding: padding,
        mainAlign: mainAlign,
        crossAlign: crossAlign,
      );
    }

    // Parse position
    final posMode = props['pos'] ?? 'auto';
    final position = posMode == 'abs'
        ? PositionModeAbsolute(
            x: double.tryParse(props['x'] ?? '0') ?? 0,
            y: double.tryParse(props['y'] ?? '0') ?? 0,
          )
        : const PositionModeAuto();

    // Parse size
    final size = SizeMode(
      width: _parseAxisSize(props['w']),
      height: _parseAxisSize(props['h']),
    );

    return NodeLayout(
      position: position,
      size: size,
      autoLayout: autoLayout,
    );
  }

  /// Build node style from props.
  NodeStyle _buildStyle(Map<String, String> props) {
    Fill? fill;
    if (props['bg'] != null) {
      final bgValue = props['bg']!;
      if (bgValue.startsWith('linear(')) {
        // Linear gradient: linear(90,#FF0000,#0000FF) or linear(#FF0000,#0000FF)
        fill = _parseLinearGradient(bgValue);
      } else if (bgValue.startsWith('radial(')) {
        // Radial gradient: radial(#FF0000,#0000FF)
        fill = _parseRadialGradient(bgValue);
      } else {
        final tokenPath = _extractTokenPath(bgValue);
        if (tokenPath != null) {
          // Token reference: {color.primary} or $primary
          fill = TokenFill(tokenPath);
        } else if (bgValue.startsWith('#')) {
          // Hex color: #007AFF
          fill = SolidFill(HexColor(bgValue));
        } else {
          // Assume bare token name (backwards compat)
          fill = TokenFill(bgValue);
        }
      }
    }

    CornerRadius? cornerRadius;
    if (props['r'] != null) {
      cornerRadius = _parseRadius(props['r']!);
    }

    Stroke? stroke;
    if (props['border'] != null) {
      stroke = _parseStroke(props['border']!);
    }

    final opacity = double.tryParse(props['opacity'] ?? '1') ?? 1.0;
    final visible = props['visible'] != 'false';

    return NodeStyle(
      fill: fill,
      stroke: stroke,
      cornerRadius: cornerRadius,
      opacity: opacity,
      visible: visible,
    );
  }

  // ===========================================================================
  // Value Parsers
  // ===========================================================================

  /// Check if value is a token reference: {path} or $path
  /// Returns the path without braces/prefix, or null if not a token.
  String? _extractTokenPath(String value) {
    if (value.startsWith('{') && value.endsWith('}')) {
      return value.substring(1, value.length - 1);
    }
    if (value.startsWith('\$')) {
      return value.substring(1);
    }
    return null;
  }

  /// Parse a color string, extracting token path if present.
  /// Returns the token path (e.g., 'color.primary') or the raw value (e.g., '#FF0000').
  String? _parseColorString(String? value) {
    if (value == null) return null;
    final tokenPath = _extractTokenPath(value);
    return tokenPath ?? value;
  }

  /// Parse a value that can be numeric or token reference.
  NumericValue? _parseNumericValue(String? value) {
    if (value == null || value.isEmpty) return null;
    final tokenPath = _extractTokenPath(value);
    if (tokenPath != null) return TokenNumeric(tokenPath);
    final num = double.tryParse(value);
    if (num != null && num > 0) return FixedNumeric(num);
    return null;
  }

  /// Parse padding with token support.
  /// Supports: {spacing.md}, 16, "16,24", "8,16,8,16"
  TokenEdgePadding _parseTokenPadding(String? value) {
    if (value == null || value.isEmpty) return TokenEdgePadding.zero;

    // Single token for all edges
    final tokenPath = _extractTokenPath(value);
    if (tokenPath != null) {
      return TokenEdgePadding.all(TokenNumeric(tokenPath));
    }

    // Numeric values (comma-separated)
    final parts = value.split(',').map((s) => s.trim()).toList();
    if (parts.length == 1) {
      final v = double.tryParse(parts[0]) ?? 0;
      return TokenEdgePadding.all(FixedNumeric(v));
    } else if (parts.length == 2) {
      final vertical = double.tryParse(parts[0]) ?? 0;
      final horizontal = double.tryParse(parts[1]) ?? 0;
      return TokenEdgePadding(
        top: FixedNumeric(vertical),
        right: FixedNumeric(horizontal),
        bottom: FixedNumeric(vertical),
        left: FixedNumeric(horizontal),
      );
    } else if (parts.length == 4) {
      return TokenEdgePadding(
        top: FixedNumeric(double.tryParse(parts[0]) ?? 0),
        right: FixedNumeric(double.tryParse(parts[1]) ?? 0),
        bottom: FixedNumeric(double.tryParse(parts[2]) ?? 0),
        left: FixedNumeric(double.tryParse(parts[3]) ?? 0),
      );
    }

    return TokenEdgePadding.zero;
  }

  AxisSize _parseAxisSize(String? value) {
    if (value == null || value == 'hug') return const AxisSizeHug();
    if (value == 'fill') return const AxisSizeFill();
    final num = double.tryParse(value);
    if (num != null) return AxisSizeFixed(num);
    return const AxisSizeHug();
  }

  double _parseSizeValue(String value) {
    return double.tryParse(value) ?? 375;
  }

  (MainAxisAlignment, CrossAxisAlignment) _parseAlignment(String? value) {
    if (value == null) return (MainAxisAlignment.start, CrossAxisAlignment.start);

    final parts = value.split(',').map((s) => s.trim()).toList();
    final mainStr = parts.isNotEmpty ? parts[0] : 'start';
    final crossStr = parts.length > 1 ? parts[1] : 'start';

    final main = MainAxisAlignment.values.firstWhere(
      (e) => e.name == mainStr,
      orElse: () => MainAxisAlignment.start,
    );

    final cross = CrossAxisAlignment.values.firstWhere(
      (e) => e.name == crossStr,
      orElse: () => CrossAxisAlignment.start,
    );

    return (main, cross);
  }

  TextAlign _parseTextAlign(String? value) {
    if (value == null) return TextAlign.left;
    return TextAlign.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextAlign.left,
    );
  }

  ImageFit _parseImageFit(String? value) {
    if (value == null) return ImageFit.cover;
    return ImageFit.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ImageFit.cover,
    );
  }

  TextDecoration _parseTextDecoration(String? value) {
    if (value == null) return TextDecoration.none;
    return TextDecoration.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TextDecoration.none,
    );
  }

  /// Parse linear gradient: linear(90,#FF0000,#0000FF) or linear(#FF0000,#0000FF)
  GradientFill? _parseLinearGradient(String value) {
    // Extract content inside linear(...)
    if (!value.startsWith('linear(') || !value.endsWith(')')) {
      return null;
    }
    final content = value.substring(7, value.length - 1); // Remove "linear(" and ")"
    final parts = content.split(',').map((s) => s.trim()).toList();

    if (parts.isEmpty) return null;

    // Check if first part is an angle (number) or a color (#...)
    double angle = 180; // Default: top to bottom
    int colorStartIdx = 0;

    final firstPart = parts[0];
    if (!firstPart.startsWith('#') && double.tryParse(firstPart) != null) {
      // First part is an angle
      angle = double.parse(firstPart);
      colorStartIdx = 1;
    }

    // Parse color stops
    final colorParts = parts.sublist(colorStartIdx);
    if (colorParts.length < 2) return null; // Need at least 2 colors

    final stops = <GradientStop>[];
    for (var i = 0; i < colorParts.length; i++) {
      final colorStr = colorParts[i];
      // Distribute positions evenly by default
      final position = i / (colorParts.length - 1);
      if (colorStr.startsWith('#')) {
        stops.add(GradientStop(position: position, color: HexColor(colorStr)));
      } else {
        // Token color reference
        final tokenPath = _extractTokenPath(colorStr);
        if (tokenPath != null) {
          stops.add(GradientStop(position: position, color: TokenColor(tokenPath)));
        }
      }
    }

    if (stops.length < 2) return null;

    return GradientFill(
      gradientType: GradientType.linear,
      stops: stops,
      angle: angle,
    );
  }

  /// Parse radial gradient: radial(#FF0000,#0000FF)
  GradientFill? _parseRadialGradient(String value) {
    // Extract content inside radial(...)
    if (!value.startsWith('radial(') || !value.endsWith(')')) {
      return null;
    }
    final content = value.substring(7, value.length - 1); // Remove "radial(" and ")"
    final parts = content.split(',').map((s) => s.trim()).toList();

    if (parts.length < 2) return null; // Need at least 2 colors

    // Parse color stops
    final stops = <GradientStop>[];
    for (var i = 0; i < parts.length; i++) {
      final colorStr = parts[i];
      // Distribute positions evenly by default
      final position = i / (parts.length - 1);
      if (colorStr.startsWith('#')) {
        stops.add(GradientStop(position: position, color: HexColor(colorStr)));
      } else {
        // Token color reference
        final tokenPath = _extractTokenPath(colorStr);
        if (tokenPath != null) {
          stops.add(GradientStop(position: position, color: TokenColor(tokenPath)));
        }
      }
    }

    if (stops.length < 2) return null;

    return GradientFill(
      gradientType: GradientType.radial,
      stops: stops,
      angle: 0, // Not used for radial gradients
    );
  }

  CornerRadius _parseRadius(String value) {
    // Token reference: {radius.md} or $radius.md
    final tokenPath = _extractTokenPath(value);
    if (tokenPath != null) {
      return CornerRadius.all(TokenNumeric(tokenPath));
    }

    // Fixed numeric
    final num = double.tryParse(value);
    if (num != null) return CornerRadius.circular(num);

    // Per-corner: "8,8,0,0"
    final parts = value.split(',').map((s) => double.tryParse(s.trim()) ?? 0).toList();
    if (parts.length == 4) {
      return CornerRadius(
        topLeft: FixedNumeric(parts[0]),
        topRight: FixedNumeric(parts[1]),
        bottomRight: FixedNumeric(parts[2]),
        bottomLeft: FixedNumeric(parts[3]),
      );
    }

    return const CornerRadius();
  }

  Stroke? _parseStroke(String value) {
    // border 1 #000 | border 2 {color.outline} | border 2 $primary
    final parts = value.split(' ');
    if (parts.isEmpty) return null;

    final width = double.tryParse(parts[0]) ?? 1;
    final colorStr = parts.length > 1 ? parts[1] : '#000000';

    ColorValue color;
    final tokenPath = _extractTokenPath(colorStr);
    if (tokenPath != null) {
      // Token reference: {color.outline} or $primary
      color = TokenColor(tokenPath);
    } else if (colorStr.startsWith('#')) {
      // Hex color: #000000
      color = HexColor(colorStr);
    } else {
      // Assume bare token name (backwards compat)
      color = TokenColor(colorStr);
    }

    return Stroke(color: color, width: width);
  }

  // ===========================================================================
  // Utilities
  // ===========================================================================

  int _getIndent(String line) {
    return line.length - line.trimLeft().length;
  }

  String _generateId() {
    return (_nextId++).toString().padLeft(4, '0');
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// Result of parsing a DSL document.
class DslParseResult {
  /// The parsed frame.
  final Frame frame;

  /// All parsed nodes (keyed by node ID).
  final Map<String, Node> nodes;

  DslParseResult({required this.frame, required this.nodes});
}

/// Exception thrown when DSL parsing fails.
class DslParseException implements Exception {
  final String message;

  DslParseException(this.message);

  @override
  String toString() => 'DslParseException: $message';
}
