import '../models/editor_document.dart';
import '../models/frame.dart';
import '../models/node.dart';
import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';

/// Generates compact outline view for AI context.
///
/// The outline provides a tree-structured view of the document that:
/// - Uses ~70-90% fewer tokens than full JSON
/// - Preserves structure and relationships
/// - Highlights focus nodes for editing
/// - Omits unchanged nodes beyond a depth limit
///
/// Example output:
/// ```
/// // outline:1
///
/// Frame: Login (375×812)
/// ├─ n_root: container col gap=24 pad=24,24,24,24 w=fill h=fill bg=#FFFFFF
/// │  ├─ n_header: container col gap=8
/// │  │  ├─ n_title: text "Welcome Back" size=24 weight=700 ← EDITING
/// │  │  └─ n_subtitle: text "Sign in to continue"
/// │  └─ ... (3 children)
/// ```
class OutlineCompiler {
  const OutlineCompiler();

  /// Compile outline focused on specific nodes.
  ///
  /// [focusNodeIds] - Nodes being edited (marked with ← EDITING)
  /// [maxDepth] - Maximum tree depth to expand (default 2)
  /// [frameId] - Specific frame to compile (null = auto-detect from focus nodes)
  String compile(
    EditorDocument doc, {
    required List<String> focusNodeIds,
    int maxDepth = 2,
    String? frameId,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('// outline:1'); // Version header
    buffer.writeln();

    // PERFORMANCE: Build parent map once (O(n) not O(n²))
    final parentMap = _buildParentMap(doc);

    // Get relevant frames
    final frames = frameId != null
        ? [doc.frames[frameId]].whereType<Frame>()
        : _getFramesContaining(doc, focusNodeIds, parentMap);

    for (final frame in frames) {
      _writeFrame(
        buffer,
        doc,
        frame,
        focusNodeIds,
        maxDepth,
        parentMap,
      );
    }

    return buffer.toString();
  }

  /// Build parent map (child → parent) in O(n) time.
  Map<String, String> _buildParentMap(EditorDocument doc) {
    final parentMap = <String, String>{};
    for (final node in doc.nodes.values) {
      for (final childId in node.childIds) {
        parentMap[childId] = node.id;
      }
    }
    return parentMap;
  }

  void _writeFrame(
    StringBuffer buffer,
    EditorDocument doc,
    Frame frame,
    List<String> focusNodeIds,
    int maxDepth,
    Map<String, String> parentMap,
  ) {
    final size = frame.canvas.size;
    buffer.writeln(
      'Frame: ${frame.name} (${size.width.toInt()}×${size.height.toInt()})',
    );

    // Write node tree
    _writeNode(
      buffer,
      doc,
      frame.rootNodeId,
      focusNodeIds: focusNodeIds,
      depth: 0,
      maxDepth: maxDepth,
      parentMap: parentMap,
    );

    buffer.writeln();
  }

  void _writeNode(
    StringBuffer buffer,
    EditorDocument doc,
    String nodeId, {
    required List<String> focusNodeIds,
    required int depth,
    required int maxDepth,
    required Map<String, String> parentMap,
  }) {
    final node = doc.nodes[nodeId];
    if (node == null) return;

    // Skip invisible nodes
    if (!node.style.visible) return;

    final indent = '│  ' * depth;
    final isFocus = focusNodeIds.contains(nodeId);
    final marker = isFocus ? ' ← EDITING' : '';

    // Compact description
    buffer.write('$indent├─ $nodeId: ');
    buffer.write(_compactDesc(node));
    buffer.writeln(marker);

    // Decide whether to expand children
    final shouldExpand = depth < maxDepth ||
        _isAncestorOfFocus(doc, node, focusNodeIds, parentMap);

    if (shouldExpand && node.childIds.isNotEmpty) {
      for (final childId in node.childIds) {
        _writeNode(
          buffer,
          doc,
          childId,
          focusNodeIds: focusNodeIds,
          depth: depth + 1,
          maxDepth: maxDepth,
          parentMap: parentMap,
        );
      }
    } else if (node.childIds.isNotEmpty) {
      // Show count but don't expand
      buffer.writeln('$indent│  └─ ... (${node.childIds.length} children)');
    }
  }

  /// Create compact description of a node.
  String _compactDesc(Node node) {
    final parts = <String>[node.type.name];

    // Add identifying content based on type
    switch (node.props) {
      case TextProps(:final text):
        final preview = text.length > 30 ? '${text.substring(0, 30)}...' : text;
        parts.add('"$preview"');

      case ImageProps(:final src):
        parts.add('src=${_shortUrl(src)}');

      case IconProps(:final icon):
        parts.add('icon=$icon');

      case InstanceProps(:final componentId):
        parts.add('component=$componentId');

      default:
        break;
    }

    // Add layout info
    final layout = node.layout;

    // Auto-layout direction
    if (layout.autoLayout != null) {
      final al = layout.autoLayout!;
      parts.add(al.direction == LayoutDirection.horizontal ? 'row' : 'col');
      final gapValue = al.gap?.toDouble() ?? 0;
      if (gapValue > 0) parts.add('gap=${gapValue.toInt()}');

      final p = al.padding;
      final padSum = p.top.toDouble() + p.right.toDouble() + p.bottom.toDouble() + p.left.toDouble();
      if (padSum > 0) {
        parts.add(
          'pad=${p.top.toDouble().toInt()},${p.right.toDouble().toInt()},${p.bottom.toDouble().toInt()},${p.left.toDouble().toInt()}',
        );
      }
    }

    // Size info
    final size = layout.size;
    parts.add(_sizeStr('w', size.width));
    parts.add(_sizeStr('h', size.height));

    // Style info
    if (node.style.fill != null) {
      parts.add('bg=${_fillStr(node.style.fill!)}');
    }

    if (node.style.cornerRadius != null) {
      final r = node.style.cornerRadius!;
      final tl = r.topLeft.toDouble();
      if (tl > 0 &&
          r.topLeft == r.topRight &&
          r.topRight == r.bottomRight &&
          r.bottomRight == r.bottomLeft) {
        parts.add('r=${tl.toInt()}');
      }
    }

    // Text-specific
    if (node.props case TextProps(:final fontSize, :final fontWeight)) {
      if (fontSize != 14) parts.add('size=${fontSize.toInt()}');
      if (fontWeight != 400) parts.add('weight=$fontWeight');
    }

    return parts.join(' ');
  }

  String _sizeStr(String axis, AxisSize size) {
    return switch (size) {
      AxisSizeHug() => '$axis=hug',
      AxisSizeFill() => '$axis=fill',
      AxisSizeFixed(:final value) => '$axis=${value.toInt()}',
    };
  }

  String _fillStr(Fill fill) {
    return switch (fill) {
      SolidFill(:final color) => _colorStr(color),
      GradientFill() => 'gradient',
      TokenFill(:final tokenRef) => '\$$tokenRef',
    };
  }

  String _colorStr(ColorValue color) {
    return switch (color) {
      HexColor(:final hex) => _shortColor(hex),
      TokenColor(:final tokenRef) => '\$$tokenRef',
    };
  }

  String _shortColor(String hex) {
    // Return color name if common, else hex
    final upper = hex.toUpperCase();
    return switch (upper) {
      '#FFFFFF' => 'white',
      '#000000' => 'black',
      '#FF0000' => 'red',
      '#00FF00' => 'green',
      '#0000FF' => 'blue',
      _ => hex.length > 7 ? hex.substring(0, 7) : hex, // Remove alpha
    };
  }

  String _shortUrl(String url) {
    if (url.length <= 40) return url;
    return '...${url.substring(url.length - 37)}';
  }

  /// Check if any focus node is a descendant of this node.
  bool _isAncestorOfFocus(
    EditorDocument doc,
    Node node,
    List<String> focusIds,
    Map<String, String> parentMap,
  ) {
    for (final focusId in focusIds) {
      if (_isDescendant(node.id, focusId, parentMap)) {
        return true;
      }
    }
    return false;
  }

  /// Check if nodeId is a descendant of ancestorId.
  bool _isDescendant(
    String ancestorId,
    String nodeId,
    Map<String, String> parentMap,
  ) {
    var current = nodeId;
    while (current != ancestorId) {
      final parent = parentMap[current];
      if (parent == null) return false;
      current = parent;
    }
    return true;
  }

  /// Find frames that contain any of the given nodes.
  List<Frame> _getFramesContaining(
    EditorDocument doc,
    List<String> nodeIds,
    Map<String, String> parentMap,
  ) {
    final result = <Frame>[];

    for (final frame in doc.frames.values) {
      if (_frameContainsAny(doc, frame, nodeIds)) {
        result.add(frame);
      }
    }

    return result;
  }

  /// Check if a frame contains any of the given nodes using BFS.
  bool _frameContainsAny(
    EditorDocument doc,
    Frame frame,
    List<String> nodeIds,
  ) {
    final nodeIdSet = nodeIds.toSet();
    final queue = [frame.rootNodeId];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (visited.contains(current)) continue;
      visited.add(current);

      if (nodeIdSet.contains(current)) return true;

      final node = doc.nodes[current];
      if (node != null) {
        queue.addAll(node.childIds);
      }
    }

    return false;
  }
}
