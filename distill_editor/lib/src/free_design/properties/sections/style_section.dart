import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/node.dart';
import '../../models/node_style.dart';
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

/// Style properties for a node.
class StyleSection extends StatelessWidget {
  const StyleSection({
    required this.nodeId,
    required this.node,
    required this.store,
    super.key,
  });

  final String nodeId;
  final Node node;
  final EditorDocumentStore store;

  @override
  Widget build(BuildContext context) {
    final style = node.style;
    final hasFill = style.fill != null;
    final fillColor = hasFill && style.fill is SolidFill
        ? _parseColor((style.fill as SolidFill).color)
        : null;

    return Column(
      children: [
        const PropertySectionHeader(title: 'Style'),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            children: [
              // Fill color
              PropertyField(
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
                    displayValue: fillColor != null
                        ? _colorToHex(fillColor)
                        : null,
                    placeholder: 'None',
                    prefix: ColorSwatchPrefix(color: fillColor),
                    onClear: hasFill
                        ? () =>
                              store.updateNodeProp(nodeId, '/style/fill', null)
                        : null,
                  ),
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Stroke
              PropertyField(
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
              ),
              SizedBox(height: context.spacing.xs),

              // Corner radius with composite editor
              PropertyField(
                label: 'Corner Radius',
                child: BorderRadiusEditor(
                  value: BorderRadiusValue.fromJson(
                    style.cornerRadius?.toJson() ?? {},
                  ),
                  onChanged: (value) {
                    // Update the entire cornerRadius object
                    store.updateNodeProp(
                      nodeId,
                      '/style/cornerRadius',
                      value.toJson(),
                    );
                  },
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Shadow
              PropertyField(
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
              ),
              SizedBox(height: context.spacing.xs),

              // Opacity
              PropertyField(
                label: 'Opacity',
                child: NumberEditor(
                  value: style.opacity,
                  onChanged: (v) {
                    if (v != null) {
                      store.updateNodeProp(
                        nodeId,
                        '/style/opacity',
                        v.toDouble(),
                      );
                    }
                  },
                  min: 0,
                  max: 1,
                  allowDecimals: true,
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Visibility
              PropertyField(
                label: 'Visible',
                child: BooleanEditor(
                  value: style.visible,
                  onChanged: (v) {
                    store.updateNodeProp(nodeId, '/style/visible', v ?? true);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _parseColor(ColorValue colorValue) {
    if (colorValue is HexColor) {
      return colorValue.toColor() ?? Colors.black;
    }
    return Colors.black;
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }
}
