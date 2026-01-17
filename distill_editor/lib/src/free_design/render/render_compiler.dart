import 'package:flutter/rendering.dart' hide CrossAxisAlignment;

import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';
import '../models/node_type.dart';
import '../scene/expanded_scene.dart';
import 'render_document.dart';
import 'token_resolver.dart';

/// Compiles an [ExpandedScene] to a [RenderDocument].
///
/// The compiler:
/// - Maps editor node types to render node types
/// - Resolves token references to concrete values
/// - Extracts relevant properties for widget construction
/// - Supports incremental compilation via dirty tracking
class RenderCompiler {
  final TokenResolver _tokens;

  /// Cache of compiled nodes.
  final Map<String, RenderNode> _cache = {};

  /// Set of dirty node IDs that need recompilation.
  final Set<String> _dirty = {};

  RenderCompiler({
    TokenResolver? tokens,
  }) : _tokens = tokens ?? TokenResolver.empty();

  /// Mark nodes as dirty (need recompilation).
  void markDirty(Set<String> expandedIds) {
    _dirty.addAll(expandedIds);
  }

  /// Invalidate all cached nodes.
  void invalidateAll() {
    _cache.clear();
    _dirty.clear();
  }

  /// Compile an expanded scene to a render document.
  ///
  /// Uses cached nodes when available and only recompiles dirty nodes.
  RenderDocument compile(ExpandedScene scene) {
    final nodes = <String, RenderNode>{};

    for (final entry in scene.nodes.entries) {
      final id = entry.key;
      final expandedNode = entry.value;

      // Use cache if available and not dirty
      if (_cache.containsKey(id) && !_dirty.contains(id)) {
        nodes[id] = _cache[id]!;
      } else {
        // Compile and cache
        final renderNode = _compileNode(expandedNode);
        nodes[id] = renderNode;
        _cache[id] = renderNode;
      }
    }

    // Clear dirty set after compilation
    _dirty.clear();

    // Remove stale cache entries
    _cache.removeWhere((id, _) => !scene.nodes.containsKey(id));

    // Validate Fill constraints and warn about issues
    _validateFillConstraints(scene, nodes);

    return RenderDocument(
      rootId: scene.rootId,
      nodes: nodes,
    );
  }

  /// Validate Fill constraints and warn about issues.
  void _validateFillConstraints(
    ExpandedScene scene,
    Map<String, RenderNode> renderNodes,
  ) {
    // Build parent index
    final parentIndex = <String, String>{};
    for (final node in scene.nodes.values) {
      for (final childId in node.childIds) {
        parentIndex[childId] = node.id;
      }
    }

    // Check each node with Fill
    for (final entry in scene.nodes.entries) {
      final expandedId = entry.key;
      final node = entry.value;
      final size = node.layout.size;

      // Check width Fill
      if (size.width is AxisSizeFill) {
        if (!_isParentBounded(
          expandedId,
          Axis.horizontal,
          parentIndex,
          scene,
        )) {
          debugPrint(
            'WARN: Node $expandedId has width:Fill but parent is unbounded. '
            'Will render at intrinsic size.',
          );
        }
      }

      // Check height Fill
      if (size.height is AxisSizeFill) {
        if (!_isParentBounded(
          expandedId,
          Axis.vertical,
          parentIndex,
          scene,
        )) {
          debugPrint(
            'WARN: Node $expandedId has height:Fill but parent is unbounded. '
            'Will render at intrinsic size.',
          );
        }
      }
    }
  }

  bool _isParentBounded(
    String nodeId,
    Axis axis,
    Map<String, String> parentIndex,
    ExpandedScene scene,
  ) {
    final parentId = parentIndex[nodeId];
    if (parentId == null) {
      // Root node - assume frame provides bounds
      return true;
    }

    final parent = scene.nodes[parentId];
    if (parent == null) return false;

    final parentLayout = parent.layout;
    final parentSize = parentLayout.size;
    final parentAutoLayout = parentLayout.autoLayout;

    // Determine parent's axis size for the requested axis
    final parentAxisSize = axis == Axis.horizontal
        ? parentSize.width
        : parentSize.height;

    // Case 1: Parent has Fixed size on this axis - definitely bounded
    if (parentAxisSize is AxisSizeFixed) {
      return true;
    }

    // Case 2: Check if parent's crossAlign: stretch provides bounds
    // This applies when the child's Fill axis is the parent's CROSS axis
    if (parentAutoLayout != null) {
      final parentDirection = parentAutoLayout.direction;
      final isCrossAxis = (parentDirection == LayoutDirection.vertical && axis == Axis.horizontal) ||
                          (parentDirection == LayoutDirection.horizontal && axis == Axis.vertical);

      if (isCrossAxis && parentAutoLayout.crossAlign == CrossAxisAlignment.stretch) {
        // Cross-axis stretch: the child will be stretched to match the parent's cross-axis size
        // So we need to check if the PARENT is bounded on this axis (recursively)
        return _isParentBounded(parentId, axis, parentIndex, scene);
      }
    }

    // Case 3: Parent has Fill on this axis - check if parent's parent is bounded
    if (parentAxisSize is AxisSizeFill) {
      return _isParentBounded(parentId, axis, parentIndex, scene);
    }

    // Case 4: Parent has Hug - not bounded (Hug expands to content size)
    return false;
  }

  /// Compute bounds for nodes with deterministic layout.
  ///
  /// Returns frame-local bounds for absolute-positioned nodes with fixed size.
  /// Returns null for auto-layout nodes that need measurement.
  ///
  /// Compute deterministic bounds for nodes with absolute position and fixed size.
  ///
  /// Bounds are only deterministic when:
  /// 1. Position is absolute (x, y known)
  /// 2. BOTH width AND height are fixed
  Rect? _computeNodeBounds(ExpandedNode node) {
    final layout = node.layout;
    final position = layout.position;
    final size = layout.size;

    // Must have absolute position
    if (position is! PositionModeAbsolute) {
      return null; // Auto-layout or relative positioning
    }

    // Both axes must be fixed for deterministic bounds
    final width = size.width;
    final height = size.height;

    if (width is! AxisSizeFixed || height is! AxisSizeFixed) {
      return null; // Mixed modes (e.g., fixed width + hug height) need measurement
    }

    // Extract bounds from absolute position and fixed sizes
    final bounds = Rect.fromLTWH(
      position.x,
      position.y,
      width.value,
      height.value,
    );

    return bounds;
  }

  /// Compile a single expanded node to a render node.
  RenderNode _compileNode(ExpandedNode node) {
    final type = _mapNodeType(node);
    final props = _compileProps(node, type);

    // NEW: Compute bounds if deterministic
    final compiledBounds = _computeNodeBounds(node);

    return RenderNode(
      id: node.id,
      type: type,
      props: props,
      childIds: node.childIds,
      compiledBounds: compiledBounds,
    );
  }

  /// Map editor node type to render node type.
  RenderNodeType _mapNodeType(ExpandedNode node) {
    return switch (node.type) {
      NodeType.container => _mapContainerType(node),
      NodeType.text => RenderNodeType.text,
      NodeType.image => RenderNodeType.image,
      NodeType.icon => RenderNodeType.icon,
      NodeType.spacer => RenderNodeType.spacer,
      NodeType.instance => RenderNodeType.box, // Should not reach here
      NodeType.slot => RenderNodeType.box, // Slot renders as container
    };
  }

  /// Map container node to box/row/column based on auto-layout.
  RenderNodeType _mapContainerType(ExpandedNode node) {
    final autoLayout = node.layout.autoLayout;
    if (autoLayout == null) {
      return RenderNodeType.box;
    }

    return switch (autoLayout.direction) {
      LayoutDirection.horizontal => RenderNodeType.row,
      LayoutDirection.vertical => RenderNodeType.column,
    };
  }

  /// Compile node properties for widget construction.
  Map<String, dynamic> _compileProps(ExpandedNode node, RenderNodeType type) {
    final props = <String, dynamic>{};

    // Add layout properties
    _compileLayoutProps(node.layout, props);

    // Add style properties
    _compileStyleProps(node.style, props);

    // Add type-specific properties
    _compileNodeTypeProps(node, type, props);

    return props;
  }

  /// Compile layout properties.
  void _compileLayoutProps(NodeLayout layout, Map<String, dynamic> props) {
    // Position
    final position = layout.position;
    switch (position) {
      case PositionModeAbsolute(:final x, :final y):
        props['positionMode'] = 'absolute';
        props['x'] = x;
        props['y'] = y;
      case PositionModeAuto():
        props['positionMode'] = 'auto';
    }

    // Size - per-axis modes
    final size = layout.size;
    final width = size.width;
    final height = size.height;

    // Width mode
    switch (width) {
      case AxisSizeFixed(:final value):
        props['widthMode'] = 'fixed';
        props['width'] = value;
      case AxisSizeHug():
        props['widthMode'] = 'hug';
      case AxisSizeFill():
        props['widthMode'] = 'fill';
    }

    // Height mode
    switch (height) {
      case AxisSizeFixed(:final value):
        props['heightMode'] = 'fixed';
        props['height'] = value;
      case AxisSizeHug():
        props['heightMode'] = 'hug';
      case AxisSizeFill():
        props['heightMode'] = 'fill';
    }

    // Auto-layout
    final autoLayout = layout.autoLayout;
    if (autoLayout != null) {
      props['direction'] = autoLayout.direction.name;
      // Resolve gap (NumericValue?) to concrete double
      if (autoLayout.gap != null) {
        props['gap'] = _tokens.resolveNumeric(autoLayout.gap!);
      } else {
        props['gap'] = 0.0;
      }
      props['mainAxisAlignment'] = autoLayout.mainAlign.name;
      props['crossAxisAlignment'] = autoLayout.crossAlign.name;

      // Resolve padding (TokenEdgePadding with NumericValue) to concrete doubles
      final padding = autoLayout.padding;
      props['paddingLeft'] = _tokens.resolveNumeric(padding.left);
      props['paddingTop'] = _tokens.resolveNumeric(padding.top);
      props['paddingRight'] = _tokens.resolveNumeric(padding.right);
      props['paddingBottom'] = _tokens.resolveNumeric(padding.bottom);
    }

    // Constraints
    final constraints = layout.constraints;
    if (constraints != null) {
      if (constraints.minWidth != null) {
        props['minWidth'] = constraints.minWidth;
      }
      if (constraints.maxWidth != null) {
        props['maxWidth'] = constraints.maxWidth;
      }
      if (constraints.minHeight != null) {
        props['minHeight'] = constraints.minHeight;
      }
      if (constraints.maxHeight != null) {
        props['maxHeight'] = constraints.maxHeight;
      }
    }
  }

  /// Compile style properties with token resolution.
  void _compileStyleProps(NodeStyle style, Map<String, dynamic> props) {
    // Opacity
    props['opacity'] = style.opacity;

    // Visibility
    props['visible'] = style.visible;

    // Fill
    final fill = style.fill;
    if (fill != null) {
      final resolvedFill = _resolveFill(fill);
      if (resolvedFill != null) {
        props['fillColor'] = resolvedFill;
      }
    }

    // Stroke
    final stroke = style.stroke;
    if (stroke != null) {
      final resolvedStroke = _resolveStroke(stroke);
      props.addAll(resolvedStroke);
    }

    // Corner radius - resolve NumericValue to concrete doubles
    final cornerRadius = style.cornerRadius;
    if (cornerRadius != null) {
      props['cornerTopLeft'] = _tokens.resolveNumeric(cornerRadius.topLeft);
      props['cornerTopRight'] = _tokens.resolveNumeric(cornerRadius.topRight);
      props['cornerBottomLeft'] = _tokens.resolveNumeric(cornerRadius.bottomLeft);
      props['cornerBottomRight'] = _tokens.resolveNumeric(cornerRadius.bottomRight);
    }

    // Shadow
    final shadow = style.shadow;
    if (shadow != null) {
      final resolvedShadow = _resolveShadow(shadow);
      props.addAll(resolvedShadow);
    }
  }

  /// Resolve a fill to a concrete color.
  Color? _resolveFill(Fill fill) {
    return switch (fill) {
      SolidFill(:final color) => _resolveColorValue(color),
      GradientFill() => null, // TODO: Support gradients
      TokenFill(:final tokenRef) => _tokens.resolveColor(tokenRef),
    };
  }

  /// Resolve a ColorValue to a concrete Color.
  Color? _resolveColorValue(ColorValue colorValue) {
    return switch (colorValue) {
      HexColor() => colorValue.toColor(),
      TokenColor(:final tokenRef) => _tokens.resolveColor(tokenRef),
    };
  }

  /// Resolve stroke properties.
  Map<String, dynamic> _resolveStroke(Stroke stroke) {
    final result = <String, dynamic>{};
    result['strokeWidth'] = stroke.width;
    result['strokePosition'] = stroke.position.name;

    final color = _resolveColorValue(stroke.color);
    if (color != null) {
      result['strokeColor'] = color;
    }

    return result;
  }

  /// Resolve shadow properties.
  Map<String, dynamic> _resolveShadow(Shadow shadow) {
    final result = <String, dynamic>{};
    result['shadowOffsetX'] = shadow.offsetX;
    result['shadowOffsetY'] = shadow.offsetY;
    result['shadowBlur'] = shadow.blur;
    result['shadowSpread'] = shadow.spread;

    final color = _resolveColorValue(shadow.color);
    if (color != null) {
      result['shadowColor'] = color;
    }

    return result;
  }

  /// Compile type-specific node properties.
  void _compileNodeTypeProps(
    ExpandedNode node,
    RenderNodeType type,
    Map<String, dynamic> props,
  ) {
    switch (node.props) {
      case TextProps(
          :final text,
          :final fontSize,
          :final fontWeight,
          :final textAlign,
          :final color,
          :final fontFamily,
          :final lineHeight,
          :final letterSpacing,
          :final decoration
        ):
        props['text'] = text;
        props['fontSize'] = fontSize;
        props['fontWeight'] = fontWeight;
        props['textAlign'] = textAlign.name;
        props['textDecoration'] = decoration.name;
        if (fontFamily != null) props['fontFamily'] = fontFamily;
        if (lineHeight != null) props['lineHeight'] = lineHeight;
        if (letterSpacing != null) props['letterSpacing'] = letterSpacing;
        if (color != null) {
          // Text color is stored as a string token ref or hex
          final resolvedColor = _resolveTextColor(color);
          if (resolvedColor != null) {
            props['textColor'] = resolvedColor;
          }
        }

      case ImageProps(:final src, :final fit, :final alt):
        props['src'] = src;
        props['fit'] = fit.name;
        if (alt != null) props['alt'] = alt;

      case IconProps(:final icon, :final size, :final color, :final iconSet):
        props['icon'] = icon;
        props['iconSet'] = iconSet;
        props['iconSize'] = size;
        if (color != null) {
          final resolvedColor = _resolveTextColor(color);
          if (resolvedColor != null) {
            props['iconColor'] = resolvedColor;
          }
        }

      case SpacerProps(:final flex):
        props['flex'] = flex;

      case ContainerProps(:final scrollDirection):
        // Pass scroll direction to render node
        if (scrollDirection != null) {
          props['scrollDirection'] = scrollDirection;
        }

      case InstanceProps():
        // Should not reach here - instances are expanded

      case SlotProps():
        // Slots behave like containers
    }
  }

  /// Resolve a text/icon color string to a Color.
  ///
  /// The color string can be:
  /// - A hex color: '#FF0000'
  /// - A token reference: 'colors.primary'
  Color? _resolveTextColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      // Hex color
      final cleanHex = colorStr.replaceFirst('#', '');
      final value = int.tryParse(cleanHex, radix: 16);
      if (value == null) return null;

      if (cleanHex.length == 6) {
        return Color(0xFF000000 | value);
      } else if (cleanHex.length == 8) {
        return Color(value);
      }
      return null;
    } else if (TokenResolver.isTokenRef(colorStr)) {
      // Token reference
      return _tokens.resolveColor(colorStr);
    }
    return null;
  }
}
