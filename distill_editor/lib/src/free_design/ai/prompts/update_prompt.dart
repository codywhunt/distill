import 'dart:convert';

import '../../models/models.dart' hide CrossAxisAlignment, MainAxisAlignment;

/// Prompt builder for AI frame/node updates.
///
/// Builds context-aware prompts that include:
/// - The current frame DSL JSON
/// - The specific node being edited (if any)
/// - Clear instructions for what to modify vs keep
class UpdatePrompt {
  static const irVersion = '1.0';

  /// Builds the system prompt for updating an existing frame.
  ///
  /// When [targetNodeIds] is provided, the AI will focus updates on those
  /// specific nodes and their children.
  static String build({
    required Frame frame,
    required Map<String, Node> nodes,
    List<String>? targetNodeIds,
    required String userPrompt,
  }) {
    final frameJson = _serializeFrame(frame, nodes);
    final targetInstructions = targetNodeIds != null && targetNodeIds.isNotEmpty
        ? '''
Focus on modifying these specific nodes and their children:
${targetNodeIds.map((id) => '- "$id"').join('\n')}

Keep all other nodes unchanged unless necessary for the requested changes.'''
        : 'Modify the frame as needed to fulfill the request.';

    return '''
You are updating an existing UI design in the Free Design Editor IR format (version $irVersion).

## Current Frame Structure

```json
$frameJson
```

## Task

$targetInstructions

**User Request:** $userPrompt

## Output Format

Return ONLY valid JSON inside a ```json code block. No explanations before or after.

Return the COMPLETE updated frame structure in the same format:

```json
{
  "frame": { /* updated frame object */ },
  "nodes": { /* ALL nodes, updated and unchanged */ }
}
```

## Important Rules

1. **Preserve IDs**: Keep the same frame ID and root node ID
2. **Preserve unchanged nodes**: Copy nodes that don't need changes exactly as they are
3. **Maintain structure**: Keep parent-child relationships intact unless explicitly changing them
4. **Return complete data**: Include ALL nodes in the response, not just changed ones
5. **Same format**: Use the exact same JSON format as the input

## Node Schema Reference

Each node has:
```json
{
  "id": "<unique_id>",
  "name": "<semantic_name>",
  "type": "container|text|image|icon|spacer",
  "childIds": ["<child_id>", ...],
  "layout": {
    "position": {"mode": "auto"},
    "size": {
      "width": {"mode": "hug|fill|fixed", "value": 100},
      "height": {"mode": "hug|fill|fixed", "value": 100}
    },
    "autoLayout": {
      "direction": "horizontal|vertical",
      "gap": 8,
      "padding": {"top": 0, "right": 0, "bottom": 0, "left": 0},
      "mainAlign": "start|center|end|spaceBetween|spaceAround|spaceEvenly",
      "crossAlign": "start|center|end|stretch"
    }
  },
  "style": {
    "fill": {"type": "solid", "color": {"hex": "#FFFFFF"}},
    "stroke": {"color": {"hex": "#000000"}, "width": 1},
    "cornerRadius": {"all": 8}
  },
  "props": { /* type-specific properties */ }
}
```

### Props by Type

**container**: `{}` or `{"clipContent": true}`

**text**:
```json
{
  "text": "Hello World",
  "fontSize": 16,
  "fontWeight": 400,
  "color": "#000000",
  "textAlign": "left|center|right"
}
```

**icon**:
```json
{
  "icon": "home",
  "iconSet": "material",
  "size": 24,
  "color": "#000000"
}
```

**image**:
```json
{
  "src": "https://example.com/image.jpg",
  "fit": "cover|contain|fill"
}
```

**spacer**:
```json
{
  "flex": 1
}
```
''';
  }

  /// Serialize a frame and its nodes to JSON for the prompt.
  static String _serializeFrame(Frame frame, Map<String, Node> nodes) {
    final frameJson = {
      'frame': {
        'id': frame.id,
        'name': frame.name,
        'rootNodeId': frame.rootNodeId,
        'canvas': {
          'position': {'x': frame.canvas.position.dx, 'y': frame.canvas.position.dy},
          'size': {'width': frame.canvas.size.width, 'height': frame.canvas.size.height},
        },
      },
      'nodes': {
        for (final entry in nodes.entries)
          entry.key: _serializeNode(entry.value),
      },
    };

    // Pretty print for readability in the prompt
    return const JsonEncoder.withIndent('  ').convert(frameJson);
  }

  /// Serialize a single node to JSON.
  static Map<String, dynamic> _serializeNode(Node node) {
    return {
      'id': node.id,
      'name': node.name,
      'type': node.type.name,
      'childIds': node.childIds,
      'layout': _serializeLayout(node.layout),
      'style': _serializeStyle(node.style),
      'props': _serializeProps(node.props),
    };
  }

  static Map<String, dynamic> _serializeLayout(NodeLayout layout) {
    final result = <String, dynamic>{};

    // Position
    result['position'] = switch (layout.position) {
      PositionModeAbsolute(:final x, :final y) => {
        'mode': 'absolute',
        'x': x,
        'y': y,
      },
      PositionModeAuto() => {'mode': 'auto'},
    };

    // Size
    result['size'] = {
      'width': _serializeAxisSize(layout.size.width),
      'height': _serializeAxisSize(layout.size.height),
    };

    // Auto layout
    if (layout.autoLayout != null) {
      final al = layout.autoLayout!;
      result['autoLayout'] = {
        'direction': al.direction.name,
        'gap': al.gap,
        'padding': {
          'top': al.padding.top,
          'right': al.padding.right,
          'bottom': al.padding.bottom,
          'left': al.padding.left,
        },
        'mainAlign': al.mainAlign.name,
        'crossAlign': al.crossAlign.name,
      };
    }

    return result;
  }

  static Map<String, dynamic> _serializeAxisSize(AxisSize size) {
    return switch (size) {
      AxisSizeHug() => {'mode': 'hug'},
      AxisSizeFill() => {'mode': 'fill'},
      AxisSizeFixed(:final value) => {'mode': 'fixed', 'value': value},
    };
  }

  static Map<String, dynamic> _serializeStyle(NodeStyle style) {
    final result = <String, dynamic>{};

    if (style.fill != null) {
      result['fill'] = _serializeFill(style.fill!);
    }
    if (style.stroke != null) {
      result['stroke'] = {
        'color': style.stroke!.color.toJson(),
        'width': style.stroke!.width,
      };
    }
    if (style.cornerRadius != null) {
      final cr = style.cornerRadius!;
      // Check if all corners are equal (uniform)
      final isUniform = cr.topLeft == cr.topRight &&
          cr.topRight == cr.bottomRight &&
          cr.bottomRight == cr.bottomLeft;
      if (isUniform) {
        result['cornerRadius'] = {'all': cr.topLeft};
      } else {
        result['cornerRadius'] = {
          'topLeft': cr.topLeft,
          'topRight': cr.topRight,
          'bottomRight': cr.bottomRight,
          'bottomLeft': cr.bottomLeft,
        };
      }
    }
    if (style.shadow != null) {
      final s = style.shadow!;
      result['shadow'] = {
        'color': s.color.toJson(),
        'offsetX': s.offsetX,
        'offsetY': s.offsetY,
        'blur': s.blur,
        'spread': s.spread,
      };
    }
    if (style.opacity != 1.0) {
      result['opacity'] = style.opacity;
    }
    if (!style.visible) {
      result['visible'] = style.visible;
    }

    return result;
  }

  static Map<String, dynamic> _serializeFill(Fill fill) {
    return switch (fill) {
      SolidFill(:final color) => {
        'type': 'solid',
        'color': color.toJson(),
      },
      GradientFill(:final gradientType, :final stops, :final angle) => {
        'type': 'gradient',
        'gradientType': gradientType.name,
        'stops': stops
            .map((s) => {'position': s.position, 'color': s.color.toJson()})
            .toList(),
        'angle': angle,
      },
      TokenFill(:final tokenRef) => {
        'type': 'token',
        'tokenRef': tokenRef,
      },
    };
  }

  static Map<String, dynamic> _serializeProps(NodeProps props) {
    return switch (props) {
      ContainerProps(:final clipContent, :final scrollDirection) => {
        if (clipContent) 'clipContent': true,
        if (scrollDirection != null) 'scrollDirection': scrollDirection,
      },
      TextProps(
        :final text,
        :final fontSize,
        :final fontWeight,
        :final color,
        :final textAlign
      ) =>
        {
          'text': text,
          'fontSize': fontSize,
          'fontWeight': fontWeight,
          if (color != null) 'color': color,
          'textAlign': textAlign.name,
        },
      IconProps(:final icon, :final iconSet, :final size, :final color) => {
        'icon': icon,
        'iconSet': iconSet,
        'size': size,
        if (color != null) 'color': color,
      },
      ImageProps(:final src, :final fit, :final alt) => {
        'src': src,
        'fit': fit.name,
        if (alt != null) 'alt': alt,
      },
      SpacerProps(:final flex) => {
        'flex': flex,
      },
      SlotProps(:final slotName, :final defaultContentId) => {
        'slotName': slotName,
        if (defaultContentId != null) 'defaultContentId': defaultContentId,
      },
      InstanceProps(:final componentId, :final overrides) => {
        'componentId': componentId,
        if (overrides.isNotEmpty) 'overrides': overrides,
      },
    };
  }
}
