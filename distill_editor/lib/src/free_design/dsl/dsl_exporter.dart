import '../models/editor_document.dart';
import '../models/frame.dart';
import '../models/node.dart';
import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';
import '../models/node_type.dart';
import '../models/numeric_value.dart';
import 'grammar.dart';

/// Exports EditorDocument frames to DSL format.
///
/// This is the inverse of [DslParser] - it converts the JSON IR to the
/// compact text format for efficient AI generation.
///
/// Key design goals:
/// - Normalized output for consistent round-tripping
/// - Minimal token usage while maintaining readability
/// - Deterministic ordering of properties
class DslExporter {
  const DslExporter();

  /// Export a single frame from a document to DSL format.
  ///
  /// [doc] - The source document
  /// [frameId] - The frame to export
  /// [includeIds] - Whether to include explicit node IDs (default: true)
  String exportFrame(
    EditorDocument doc,
    String frameId, {
    bool includeIds = true,
  }) {
    final frame = doc.frames[frameId];
    if (frame == null) {
      throw DslExportException('Frame not found: $frameId');
    }

    final buffer = StringBuffer();

    // Version header
    buffer.writeln('dsl:${DslGrammar.version}');

    // Frame declaration
    _writeFrame(buffer, frame, doc);

    // Node tree
    final rootNode = doc.nodes[frame.rootNodeId];
    if (rootNode != null) {
      _writeNodeTree(buffer, rootNode, doc, 2, includeIds);
    }

    return buffer.toString();
  }

  /// Export multiple frames from a document.
  String exportFrames(
    EditorDocument doc,
    List<String> frameIds, {
    bool includeIds = true,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('dsl:${DslGrammar.version}');
    buffer.writeln();

    for (var i = 0; i < frameIds.length; i++) {
      final frameId = frameIds[i];
      final frame = doc.frames[frameId];
      if (frame == null) continue;

      _writeFrame(buffer, frame, doc);

      final rootNode = doc.nodes[frame.rootNodeId];
      if (rootNode != null) {
        _writeNodeTree(buffer, rootNode, doc, 2, includeIds);
      }

      if (i < frameIds.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  }

  /// Export entire document (all frames).
  String exportDocument(
    EditorDocument doc, {
    bool includeIds = true,
  }) {
    return exportFrames(doc, doc.frames.keys.toList(), includeIds: includeIds);
  }

  // ===========================================================================
  // Frame Export
  // ===========================================================================

  void _writeFrame(StringBuffer buffer, Frame frame, EditorDocument doc) {
    buffer.write('frame ');

    // Quote name if it contains spaces
    if (frame.name.contains(' ') || frame.name.isEmpty) {
      buffer.write('"${frame.name}"');
    } else {
      buffer.write(frame.name);
    }

    // Frame properties (canvas size)
    final props = <String>[];
    final width = frame.canvas.size.width;
    final height = frame.canvas.size.height;

    if (width != 375) {
      props.add('w ${_formatNumber(width)}');
    }
    if (height != 812) {
      props.add('h ${_formatNumber(height)}');
    }

    if (props.isNotEmpty) {
      buffer.write(' - ${props.join(' ')}');
    }

    buffer.writeln();
  }

  // ===========================================================================
  // Node Tree Export
  // ===========================================================================

  void _writeNodeTree(
    StringBuffer buffer,
    Node node,
    EditorDocument doc,
    int indent,
    bool includeIds,
  ) {
    final indentStr = ' ' * indent;
    buffer.write(indentStr);
    _writeNode(buffer, node, includeIds);
    buffer.writeln();

    // Recursively write children
    for (final childId in node.childIds) {
      final child = doc.nodes[childId];
      if (child != null) {
        _writeNodeTree(buffer, child, doc, indent + 2, includeIds);
      }
    }
  }

  void _writeNode(StringBuffer buffer, Node node, bool includeIds) {
    // Node type (use shorthand when appropriate)
    final typeStr = _mapNodeTypeToString(node.type, node.layout.autoLayout);
    buffer.write(typeStr);

    // Explicit ID (if requested)
    if (includeIds) {
      buffer.write('#${node.id}');
    }

    // Content (for text, icon, image, use nodes)
    final content = _getContent(node);
    if (content != null) {
      buffer.write(' "$content"');
    }

    // Properties
    final props = _buildProps(node, typeStr);
    if (props.isNotEmpty) {
      buffer.write(' - ${props.join(' ')}');
    }
  }

  // ===========================================================================
  // Type Mapping
  // ===========================================================================

  String _mapNodeTypeToString(NodeType type, AutoLayout? autoLayout) {
    return switch (type) {
      NodeType.container => _containerTypeStr(autoLayout),
      NodeType.text => 'text',
      NodeType.image => 'img',
      NodeType.icon => 'icon',
      NodeType.spacer => 'spacer',
      NodeType.instance => 'use',
      NodeType.slot => 'slot',
    };
  }

  String _containerTypeStr(AutoLayout? autoLayout) {
    if (autoLayout == null) return 'container';
    return switch (autoLayout.direction) {
      LayoutDirection.horizontal => 'row',
      LayoutDirection.vertical => 'column',
    };
  }

  // ===========================================================================
  // Content Extraction
  // ===========================================================================

  String? _getContent(Node node) {
    return switch (node.props) {
      TextProps(text: final t) => t.isNotEmpty ? t : null,
      IconProps(icon: final i) => i,
      ImageProps(src: final s) => s.isNotEmpty ? s : null,
      InstanceProps(componentId: final c) => c.isNotEmpty ? c : null,
      SlotProps(slotName: final s) => s.isNotEmpty ? s : null,
      _ => null,
    };
  }

  // ===========================================================================
  // Property Building
  // ===========================================================================

  List<String> _buildProps(Node node, String typeStr) {
    final props = <String>[];

    // Layout properties
    _addLayoutProps(props, node.layout, typeStr);

    // Style properties
    _addStyleProps(props, node.style);

    // Type-specific properties
    _addTypeProps(props, node);

    return props;
  }

  void _addLayoutProps(List<String> props, NodeLayout layout, String typeStr) {
    // Size
    final width = layout.size.width;
    final height = layout.size.height;

    if (width is AxisSizeFixed) {
      props.add('w ${_formatNumber(width.value)}');
    } else if (width is AxisSizeFill) {
      props.add('w fill');
    }
    // Skip 'hug' as it's the default

    if (height is AxisSizeFixed) {
      props.add('h ${_formatNumber(height.value)}');
    } else if (height is AxisSizeFill) {
      props.add('h fill');
    }

    // Position
    if (layout.position is PositionModeAbsolute) {
      final pos = layout.position as PositionModeAbsolute;
      props.add('pos abs');
      props.add('x ${_formatNumber(pos.x)}');
      props.add('y ${_formatNumber(pos.y)}');
    }

    // Auto-layout (skip if type already implies direction)
    final auto = layout.autoLayout;
    if (auto != null) {
      // Gap - now NumericValue?
      if (auto.gap != null) {
        props.add('gap ${_exportNumericValue(auto.gap!)}');
      }

      // Padding - now TokenEdgePadding
      final pad = auto.padding;
      if (pad != TokenEdgePadding.zero) {
        props.add('pad ${_exportTokenPadding(pad)}');
      }

      // Alignment (only if non-default)
      if (auto.mainAlign != MainAxisAlignment.start ||
          auto.crossAlign != CrossAxisAlignment.start) {
        props.add('align ${auto.mainAlign.name},${auto.crossAlign.name}');
      }
    }
  }

  void _addStyleProps(List<String> props, NodeStyle style) {
    // Background fill - use {path} syntax for tokens
    final fill = style.fill;
    if (fill != null) {
      final bgValue = switch (fill) {
        SolidFill(color: HexColor(hex: final h)) => h,
        SolidFill(color: TokenColor(tokenRef: final t)) => '{$t}',
        TokenFill(tokenRef: final t) => '{$t}',
        GradientFill(gradientType: GradientType.linear) =>
          _exportLinearGradient(fill as GradientFill),
        GradientFill(gradientType: GradientType.radial) =>
          _exportRadialGradient(fill as GradientFill),
      };
      if (bgValue != null) {
        props.add('bg $bgValue');
      }
    }

    // Corner radius - now uses NumericValue
    final r = style.cornerRadius;
    if (r != null) {
      if (r.topLeft == r.topRight &&
          r.topRight == r.bottomRight &&
          r.bottomRight == r.bottomLeft) {
        // Uniform radius - only export if non-zero
        if (!_isZeroNumeric(r.topLeft)) {
          props.add('r ${_exportNumericValue(r.topLeft)}');
        }
      } else {
        // Per-corner radius
        props.add('r ${_exportNumericValue(r.topLeft)},${_exportNumericValue(r.topRight)},'
            '${_exportNumericValue(r.bottomRight)},${_exportNumericValue(r.bottomLeft)}');
      }
    }

    // Border - use {path} syntax for token colors
    final stroke = style.stroke;
    if (stroke != null) {
      final colorStr = switch (stroke.color) {
        HexColor(hex: final h) => h,
        TokenColor(tokenRef: final t) => '{$t}',
      };
      props.add('border ${_formatNumber(stroke.width)} $colorStr');
    }

    // Opacity
    if (style.opacity < 1.0) {
      props.add('opacity ${style.opacity}');
    }

    // Visibility
    if (!style.visible) {
      props.add('visible false');
    }
  }

  void _addTypeProps(List<String> props, Node node) {
    switch (node.props) {
      case TextProps(
          fontSize: final size,
          fontWeight: final weight,
          color: final color,
          textAlign: final align,
          fontFamily: final family,
          lineHeight: final lh,
          letterSpacing: final ls,
          decoration: final decor,
        ):
        if (size != 14) {
          props.add('size ${_formatNumber(size)}');
        }
        if (weight != 400) {
          props.add('weight $weight');
        }
        if (color != null) {
          props.add('color $color');
        }
        if (align != TextAlign.left) {
          props.add('textAlign ${align.name}');
        }
        if (family != null) {
          props.add('family "$family"');
        }
        if (lh != null) {
          props.add('lh ${_formatNumber(lh)}');
        }
        if (ls != null) {
          props.add('ls ${_formatNumber(ls)}');
        }
        if (decor != TextDecoration.none) {
          props.add('decor ${decor.name}');
        }

      case IconProps(
          iconSet: final set,
          size: final size,
          color: final color,
        ):
        if (set != 'material') {
          props.add('iconSet $set');
        }
        if (size != 24) {
          props.add('size ${_formatNumber(size)}');
        }
        if (color != null) {
          props.add('color $color');
        }

      case ImageProps(fit: final fit, alt: final alt):
        if (fit != ImageFit.cover) {
          props.add('fit ${fit.name}');
        }
        if (alt != null && alt.isNotEmpty) {
          props.add('alt "$alt"');
        }

      case ContainerProps(
          clipContent: final clip,
          scrollDirection: final scroll,
        ):
        if (clip) {
          props.add('clip');
        }
        if (scroll != null) {
          props.add('scroll $scroll');
        }

      case SpacerProps(flex: final flex):
        if (flex != 1) {
          props.add('flex $flex');
        }

      case InstanceProps():
      case SlotProps():
        break;
    }
  }

  // ===========================================================================
  // Formatting Utilities
  // ===========================================================================

  String _formatNumber(double value) {
    // Output integers without decimal point
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Export linear gradient to DSL format.
  /// linear(angle,#color1,#color2,...) or linear(#color1,#color2,...) if angle is 180
  String _exportLinearGradient(GradientFill gradient) {
    final buffer = StringBuffer('linear(');

    // Include angle if not default (180)
    if (gradient.angle != 180) {
      buffer.write('${_formatNumber(gradient.angle)},');
    }

    // Export color stops (positions are evenly distributed, so we only need colors)
    final colors = gradient.stops.map((stop) {
      return switch (stop.color) {
        HexColor(hex: final h) => h,
        TokenColor(tokenRef: final t) => '{$t}',
      };
    }).join(',');
    buffer.write(colors);
    buffer.write(')');

    return buffer.toString();
  }

  /// Export radial gradient to DSL format.
  /// radial(#color1,#color2,...)
  String _exportRadialGradient(GradientFill gradient) {
    final buffer = StringBuffer('radial(');

    // Export color stops (positions are evenly distributed, so we only need colors)
    final colors = gradient.stops.map((stop) {
      return switch (stop.color) {
        HexColor(hex: final h) => h,
        TokenColor(tokenRef: final t) => '{$t}',
      };
    }).join(',');
    buffer.write(colors);
    buffer.write(')');

    return buffer.toString();
  }

  /// Export NumericValue to DSL format.
  /// FixedNumeric(16) → "16"
  /// TokenNumeric('spacing.md') → "{spacing.md}"
  String _exportNumericValue(NumericValue value) {
    return switch (value) {
      FixedNumeric(:final value) => _formatNumber(value),
      TokenNumeric(:final tokenRef) => '{$tokenRef}',
    };
  }

  /// Check if a NumericValue is zero (only for FixedNumeric).
  bool _isZeroNumeric(NumericValue value) {
    return value is FixedNumeric && value.value == 0;
  }

  /// Export TokenEdgePadding to DSL format.
  String _exportTokenPadding(TokenEdgePadding pad) {
    // All same value
    if (pad.top == pad.right &&
        pad.right == pad.bottom &&
        pad.bottom == pad.left) {
      return _exportNumericValue(pad.top);
    }

    // Symmetric (top/bottom equal, left/right equal)
    if (pad.top == pad.bottom && pad.left == pad.right) {
      return '${_exportNumericValue(pad.top)},${_exportNumericValue(pad.left)}';
    }

    // All four different
    return '${_exportNumericValue(pad.top)},${_exportNumericValue(pad.right)},'
        '${_exportNumericValue(pad.bottom)},${_exportNumericValue(pad.left)}';
  }

}

/// Exception thrown when DSL export fails.
class DslExportException implements Exception {
  final String message;

  DslExportException(this.message);

  @override
  String toString() => 'DslExportException: $message';
}
