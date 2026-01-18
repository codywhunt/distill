import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/node.dart';
import '../../models/node_layout.dart';
import '../../store/editor_document_store.dart';
import '../widgets/property_section_header.dart';
import '../editors/widgets/property_field.dart';
import '../editors/primitives/number_editor.dart';
import '../editors/primitives/dropdown_editor.dart';
import '../editors/primitives/boolean_editor.dart';
import '../editors/primitives/toggle_editor.dart';
import '../editors/composite/padding_editor.dart';
import '../editors/composite/padding_value.dart';

/// Auto layout properties for a container node.
class AutoLayoutSection extends StatelessWidget {
  const AutoLayoutSection({
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
    final autoLayout = layout.autoLayout;
    final hasAutoLayout = autoLayout != null;

    return Column(
      children: [
        const PropertySectionHeader(title: 'Auto Layout'),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            children: [
              // Enable/Disable Toggle
              PropertyField(
                label: 'Enabled',
                child: BooleanEditor(
                  value: hasAutoLayout,
                  onChanged: (enabled) {
                    if (enabled != null) {
                      _toggleAutoLayout(enabled, autoLayout);
                    }
                  },
                ),
              ),

              if (hasAutoLayout) ...[
                SizedBox(height: context.spacing.xs),

                // Direction
                PropertyField(
                  label: 'Direction',
                  child: ToggleEditor<LayoutDirection>(
                    value: autoLayout.direction,
                    options: {
                      LayoutDirection.horizontal: LucideIcons.arrowRight200.holo,
                      LayoutDirection.vertical: LucideIcons.arrowDown200.holo,
                    },
                    optionLabels: const {
                      LayoutDirection.horizontal: 'Horizontal',
                      LayoutDirection.vertical: 'Vertical',
                    },
                    required: true,
                    onChanged: (dir) {
                      if (dir != null) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/autoLayout/direction',
                          dir.name,
                        );
                      }
                    },
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Gap
                PropertyField(
                  label: 'Gap',
                  child: NumberEditor(
                    value: autoLayout.gap?.toDouble() ?? 0,
                    onChanged: (v) {
                      if (v != null && v >= 0) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/autoLayout/gap',
                          v.toDouble(),
                        );
                      }
                    },
                    min: 0,
                    allowDecimals: false,
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Padding with composite editor
                PropertyField(
                  label: 'Padding',
                  child: PaddingEditor(
                    value: PaddingValue.fromJson({
                      'left': autoLayout.padding.left.toDouble(),
                      'top': autoLayout.padding.top.toDouble(),
                      'right': autoLayout.padding.right.toDouble(),
                      'bottom': autoLayout.padding.bottom.toDouble(),
                    }),
                    onChanged: (value) {
                      // Update the entire padding object, not individual fields
                      store.updateNodeProp(
                        nodeId,
                        '/layout/autoLayout/padding',
                        value.toJson(),
                      );
                    },
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Main Axis Alignment
                PropertyField(
                  label: 'Main Align',
                  child: DropdownEditor<String>(
                    value: autoLayout.mainAlign.name,
                    items: const [
                      DropdownItem(value: 'start', label: 'Start'),
                      DropdownItem(value: 'center', label: 'Center'),
                      DropdownItem(value: 'end', label: 'End'),
                      DropdownItem(
                        value: 'spaceBetween',
                        label: 'Space Between',
                      ),
                      DropdownItem(value: 'spaceAround', label: 'Space Around'),
                      DropdownItem(value: 'spaceEvenly', label: 'Space Evenly'),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/autoLayout/mainAlign',
                          v,
                        );
                      }
                    },
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Cross Axis Alignment
                PropertyField(
                  label: 'Cross Align',
                  child: DropdownEditor<String>(
                    value: autoLayout.crossAlign.name,
                    items: const [
                      DropdownItem(value: 'start', label: 'Start'),
                      DropdownItem(value: 'center', label: 'Center'),
                      DropdownItem(value: 'end', label: 'End'),
                      DropdownItem(value: 'stretch', label: 'Stretch'),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/autoLayout/crossAlign',
                          v,
                        );
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _toggleAutoLayout(bool enable, AutoLayout? current) {
    if (enable && current == null) {
      // Enable with defaults
      store.updateNodeProp(nodeId, '/layout/autoLayout', {
        'direction': 'vertical',
        'mainAlign': 'start',
        'crossAlign': 'start',
        'gap': 0,
        'padding': {'top': 0, 'right': 0, 'bottom': 0, 'left': 0},
      });
    } else if (!enable && current != null) {
      // Disable
      store.updateNodeProp(nodeId, '/layout/autoLayout', null);
    }
  }
}
