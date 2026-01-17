import 'package:flutter/material.dart'
    hide CrossAxisAlignment, MainAxisAlignment;
import 'package:distill_ds/design_system.dart';

import '../../layout/layout_validation.dart';
import '../../models/node.dart';
import '../../models/node_layout.dart';
import '../../store/editor_document_store.dart';
import '../widgets/property_section_header.dart';
import '../editors/widgets/property_field.dart';
import '../editors/primitives/number_editor.dart';
import '../editors/primitives/dropdown_editor.dart';

/// Layout properties for a node.
class LayoutSection extends StatelessWidget {
  const LayoutSection({
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
    final layout = node.layout;
    final size = layout.size;

    return Column(
      children: [
        const PropertySectionHeader(title: 'Layout', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            children: [
              // Width mode dropdown
              PropertyField(
                label: 'Width',
                child: DropdownEditor<String>(
                  value: _getAxisSizeMode(size.width),
                  items: _getSizeItems(Axis.horizontal),
                  onChanged: (mode) {
                    if (mode != null) _updateWidthMode(mode, size);
                  },
                ),
              ),

              // Width value (if fixed)
              if (size.width is AxisSizeFixed) ...[
                SizedBox(height: context.spacing.xs),
                PropertyField(
                  label: '',
                  child: NumberEditor(
                    value: (size.width as AxisSizeFixed).value,
                    onChanged: (v) {
                      if (v != null && v > 0) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/size/width/value',
                          v.toDouble(),
                        );
                      }
                    },
                    min: 1,
                    allowDecimals: false,
                  ),
                ),
              ],
              SizedBox(height: context.spacing.xs),

              // Height mode dropdown
              PropertyField(
                label: 'Height',
                child: DropdownEditor<String>(
                  value: _getAxisSizeMode(size.height),
                  items: _getSizeItems(Axis.vertical),
                  onChanged: (mode) {
                    if (mode != null) _updateHeightMode(mode, size);
                  },
                ),
              ),

              // Height value (if fixed)
              if (size.height is AxisSizeFixed) ...[
                SizedBox(height: context.spacing.xs),
                PropertyField(
                  label: '',
                  child: NumberEditor(
                    value: (size.height as AxisSizeFixed).value,
                    onChanged: (v) {
                      if (v != null && v > 0) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/size/height/value',
                          v.toDouble(),
                        );
                      }
                    },
                    min: 1,
                    allowDecimals: false,
                  ),
                ),
              ],

              // Constraints subsection
              const PropertySectionHeader(
                title: 'Constraints',
                showTopDivider: true,
              ),
              SizedBox(height: context.spacing.xs),

              // Min Width
              PropertyField(
                label: 'Min Width',
                child: NumberEditor(
                  value: node.layout.constraints?.minWidth,
                  placeholder: 'None',
                  onChanged: (v) {
                    store.updateNodeProp(
                      nodeId,
                      '/layout/constraints/minWidth',
                      v?.toDouble(),
                    );
                  },
                  min: 0,
                  allowDecimals: true,
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Max Width
              PropertyField(
                label: 'Max Width',
                child: NumberEditor(
                  value: node.layout.constraints?.maxWidth,
                  placeholder: 'None',
                  onChanged: (v) {
                    store.updateNodeProp(
                      nodeId,
                      '/layout/constraints/maxWidth',
                      v?.toDouble(),
                    );
                  },
                  min: 0,
                  allowDecimals: true,
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Min Height
              PropertyField(
                label: 'Min Height',
                child: NumberEditor(
                  value: node.layout.constraints?.minHeight,
                  placeholder: 'None',
                  onChanged: (v) {
                    store.updateNodeProp(
                      nodeId,
                      '/layout/constraints/minHeight',
                      v?.toDouble(),
                    );
                  },
                  min: 0,
                  allowDecimals: true,
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Max Height
              PropertyField(
                label: 'Max Height',
                child: NumberEditor(
                  value: node.layout.constraints?.maxHeight,
                  placeholder: 'None',
                  onChanged: (v) {
                    store.updateNodeProp(
                      nodeId,
                      '/layout/constraints/maxHeight',
                      v?.toDouble(),
                    );
                  },
                  min: 0,
                  allowDecimals: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getAxisSizeMode(AxisSize axis) {
    return switch (axis) {
      AxisSizeHug() => 'hug',
      AxisSizeFill() => 'fill',
      AxisSizeFixed() => 'fixed',
    };
  }

  List<DropdownItem<String>> _getSizeItems(Axis axis) {
    final fillReason = LayoutValidation.getFillDisabledReason(
      nodeId: nodeId,
      axis: axis,
      store: store,
    );

    return [
      const DropdownItem(value: 'hug', label: 'Hug'),
      DropdownItem(
        value: 'fill',
        label: 'Fill',
        description: fillReason,
        isDisabled: fillReason != null,
      ),
      const DropdownItem(value: 'fixed', label: 'Fixed'),
    ];
  }

  void _updateWidthMode(String mode, SizeMode currentSize) {
    // No validation needed - disabled items can't be selected
    final newWidth = switch (mode) {
      'hug' => const AxisSizeHug(),
      'fill' => const AxisSizeFill(),
      'fixed' => AxisSizeFixed(
        currentSize.width is AxisSizeFixed
            ? (currentSize.width as AxisSizeFixed).value
            : 100.0,
      ),
      _ => const AxisSizeHug(),
    };

    store.updateNodeProp(nodeId, '/layout/size/width', newWidth.toJson());
  }

  void _updateHeightMode(String mode, SizeMode currentSize) {
    // No validation needed - disabled items can't be selected
    final newHeight = switch (mode) {
      'hug' => const AxisSizeHug(),
      'fill' => const AxisSizeFill(),
      'fixed' => AxisSizeFixed(
        currentSize.height is AxisSizeFixed
            ? (currentSize.height as AxisSizeFixed).value
            : 100.0,
      ),
      _ => const AxisSizeHug(),
    };

    store.updateNodeProp(nodeId, '/layout/size/height', newHeight.toJson());
  }
}
