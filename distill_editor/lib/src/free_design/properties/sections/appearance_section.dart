import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/node.dart';
import '../../models/node_style.dart';
import '../../models/node_type.dart';
import '../../store/editor_document_store.dart';
import '../widgets/property_section_header.dart';
import '../editors/widgets/property_field.dart';
import '../editors/primitives/number_editor.dart';
import '../editors/primitives/button_editor.dart';
import '../editors/primitives/boolean_editor.dart';
import '../editors/composite/border_radius_editor.dart';
import '../editors/composite/border_radius_value.dart';
import '../editors/composite/stroke_editor.dart';
import '../editors/composite/stroke_value.dart';
import '../editors/composite/shadow_editor.dart';
import '../editors/composite/shadow_value.dart';
import '../editors/slots/editor_prefixes.dart';
import '../editors/pickers/color_picker_menu.dart';
import '../../render/token_resolver.dart';

/// Appearance properties section with conditional visibility based on node type.
///
/// Property applicability:
/// - Fill: container, image
/// - Stroke: container, image, text, icon
/// - Corner Radius: container, image
/// - Shadow: container, image, text, icon
/// - Opacity: ALL nodes
/// - Visibility: ALL nodes
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({
    required this.nodeId,
    required this.node,
    required this.store,
    required this.tokenResolver,
    super.key,
  });

  final String nodeId;
  final Node node;
  final EditorDocumentStore store;
  final TokenResolver tokenResolver;

  @override
  Widget build(BuildContext context) {
    final style = node.style;
    final nodeType = node.type;

    // Determine which properties apply to this node type
    final showFill = _shouldShowFill(nodeType);
    final showStroke = _shouldShowStroke(nodeType);
    final showCornerRadius = _shouldShowCornerRadius(nodeType);
    final showShadow = _shouldShowShadow(nodeType);

    return Column(
      children: [
        const PropertySectionHeader(title: 'Styling'),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            children: [
              // Fill (container, image)
              if (showFill) ...[
                _buildFillEditor(context, style),
                SizedBox(height: context.spacing.xs),
              ],

              // Stroke (container, image, text, icon)
              if (showStroke) ...[
                _buildStrokeEditor(context, style),
                SizedBox(height: context.spacing.xs),
              ],

              // Corner Radius (container, image)
              if (showCornerRadius) ...[
                _buildCornerRadiusEditor(context, style),
                SizedBox(height: context.spacing.xs),
              ],

              // Shadow (container, image, text, icon)
              if (showShadow) ...[
                _buildShadowEditor(context, style),
                SizedBox(height: context.spacing.xs),
              ],

              // Opacity (all nodes)
              _buildOpacityEditor(context, style),
              SizedBox(height: context.spacing.xs),

              // Visibility (all nodes)
              _buildVisibilityEditor(context, style),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowFill(NodeType type) {
    return type == NodeType.container || type == NodeType.image;
  }

  bool _shouldShowStroke(NodeType type) {
    return type == NodeType.container ||
        type == NodeType.image ||
        type == NodeType.text ||
        type == NodeType.icon;
  }

  bool _shouldShowCornerRadius(NodeType type) {
    return type == NodeType.container || type == NodeType.image;
  }

  bool _shouldShowShadow(NodeType type) {
    return type == NodeType.container ||
        type == NodeType.image ||
        type == NodeType.text ||
        type == NodeType.icon;
  }

  Widget _buildFillEditor(BuildContext context, NodeStyle style) {
    final hasFill = style.fill != null;
    Color? fillColor;
    String? displayValue;

    if (hasFill) {
      final fill = style.fill!;
      if (fill is SolidFill) {
        fillColor = _parseColor(fill.color);
        // Show token name if it's a token color, otherwise hex
        if (fill.color is TokenColor) {
          displayValue = '{${(fill.color as TokenColor).tokenRef}}';
        } else {
          displayValue = _colorToHex(fillColor);
        }
      } else if (fill is TokenFill) {
        // Resolve token reference to actual color for swatch preview
        fillColor = tokenResolver.resolveColor(fill.tokenRef);
        // Show token name in display
        displayValue = '{${fill.tokenRef}}';
      }
    }

    return PropertyField(
      label: 'Fill',
      child: ColorPickerPopover(
        initialColor: fillColor ?? Colors.white,
        onChanged: (color) {
          store.updateNodeProp(nodeId, '/style/fill', {
            'type': 'solid',
            'color': {'hex': _colorToHex(color)},
          });
        },
        child: ButtonEditor(
          displayValue: displayValue,
          placeholder: 'None',
          prefix: ColorSwatchPrefix(color: fillColor),
          onClear: hasFill
              ? () => store.updateNodeProp(nodeId, '/style/fill', null)
              : null,
        ),
      ),
    );
  }

  Widget _buildStrokeEditor(BuildContext context, NodeStyle style) {
    return PropertyField(
      label: 'Stroke',
      child: StrokeEditor(
        value: StrokeValue.fromJson(style.stroke?.toJson() ?? {}),
        onChanged: (value) {
          store.updateNodeProp(
            nodeId,
            '/style/stroke',
            value.isEmpty ? null : value.toJson(),
          );
        },
      ),
    );
  }

  Widget _buildCornerRadiusEditor(BuildContext context, NodeStyle style) {
    final cr = style.cornerRadius;
    return PropertyField(
      label: 'Corner Radius',
      child: BorderRadiusEditor(
        value: BorderRadiusValue.fromJson(
          cr != null
              ? {
                  'topLeft': cr.topLeft.toDouble(),
                  'topRight': cr.topRight.toDouble(),
                  'bottomLeft': cr.bottomLeft.toDouble(),
                  'bottomRight': cr.bottomRight.toDouble(),
                }
              : <String, dynamic>{},
        ),
        onChanged: (value) {
          store.updateNodeProp(nodeId, '/style/cornerRadius', value.toJson());
        },
      ),
    );
  }

  Widget _buildShadowEditor(BuildContext context, NodeStyle style) {
    return PropertyField(
      label: 'Shadow',
      child: ShadowEditor(
        value: ShadowValue.fromJson(style.shadow?.toJson() ?? {}),
        onChanged: (value) {
          store.updateNodeProp(
            nodeId,
            '/style/shadow',
            value.isEmpty ? null : value.toJson(),
          );
        },
      ),
    );
  }

  Widget _buildOpacityEditor(BuildContext context, NodeStyle style) {
    return PropertyField(
      label: 'Opacity',
      child: NumberEditor(
        value: style.opacity,
        onChanged: (v) {
          if (v != null) {
            store.updateNodeProp(nodeId, '/style/opacity', v.toDouble());
          }
        },
        min: 0,
        max: 1,
        allowDecimals: true,
      ),
    );
  }

  Widget _buildVisibilityEditor(BuildContext context, NodeStyle style) {
    return PropertyField(
      label: 'Visible',
      child: BooleanEditor(
        value: style.visible,
        onChanged: (v) {
          store.updateNodeProp(nodeId, '/style/visible', v ?? true);
        },
      ),
    );
  }

  Color _parseColor(ColorValue colorValue) {
    if (colorValue is HexColor) {
      return colorValue.toColor() ?? Colors.black;
    } else if (colorValue is TokenColor) {
      // Resolve token reference to actual color
      final resolved = tokenResolver.resolveColor(colorValue.tokenRef);
      return resolved ?? Colors.black;
    }
    return Colors.black;
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
