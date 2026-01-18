import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/node.dart';
import '../../models/node_layout.dart' as model;
import '../../store/editor_document_store.dart';
import '../../layout/layout_validation.dart';
import '../widgets/property_section_header.dart';
import '../editors/widgets/property_field.dart';
import '../editors/primitives/number_editor.dart';
import '../editors/primitives/dropdown_editor.dart';
import '../editors/primitives/toggle_editor.dart';
import '../editors/composite/padding_editor.dart';
import '../editors/composite/padding_value.dart';

/// Layout properties section - merged from LayoutSection, PositionSection, and AutoLayoutSection.
///
/// Structure:
/// - Sizing (width/height modes)
/// - Position (auto/absolute + x/y)
/// - Auto Layout (container only: direction, gap, padding, alignment)
/// - Constraints (min/max width/height)
class LayoutSectionV2 extends StatelessWidget {
  const LayoutSectionV2({
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
    final position = layout.position;
    final isAbsolute = position is model.PositionModeAbsolute;
    final autoLayout = layout.autoLayout;
    final hasAutoLayout = autoLayout != null;

    return Column(
      children: [
        const PropertySectionHeader(title: 'Layout'),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === POSITION ===
              PropertyField(
                label: 'Position',
                child: SizedBox(
                  height: 28,
                  child: SegmentedControl<String>(
                    heightOverride: 28,
                    gapOverride: 2,
                    showElevation: false,
                    items: const [
                      SegmentedControlItem<String>(
                        label: 'Auto',
                        value: 'auto',
                      ),
                      SegmentedControlItem<String>(
                        label: 'Absolute',
                        value: 'absolute',
                      ),
                    ],
                    selectedValues: {isAbsolute ? 'absolute' : 'auto'},
                    onChanged: (selectedValues) {
                      final value = selectedValues.firstOrNull;
                      if (value == 'absolute') {
                        store.updateNodeProp(nodeId, '/layout/position', {
                          'mode': 'absolute',
                          'x': 0.0,
                          'y': 0.0,
                        });
                      } else {
                        store.updateNodeProp(nodeId, '/layout/position', {
                          'mode': 'auto',
                        });
                      }
                    },
                  ),
                ),
              ),

              if (isAbsolute) ...[
                SizedBox(height: context.spacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: PropertyField(
                        label: 'X',
                        child: NumberEditor(
                          value: position.x,
                          onChanged: (v) {
                            if (v != null) {
                              store.updateNodeProp(
                                nodeId,
                                '/layout/position/x',
                                v.toDouble(),
                              );
                            }
                          },
                          allowDecimals: true,
                        ),
                      ),
                    ),
                    SizedBox(width: context.spacing.xs),
                    Expanded(
                      child: PropertyField(
                        label: 'Y',
                        child: NumberEditor(
                          value: position.y,
                          onChanged: (v) {
                            if (v != null) {
                              store.updateNodeProp(
                                nodeId,
                                '/layout/position/y',
                                v.toDouble(),
                              );
                            }
                          },
                          allowDecimals: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: context.spacing.xs),

              // === SIZE ===
              // Width mode toggle
              Builder(
                builder: (context) {
                  final fillReason = LayoutValidation.getFillDisabledReason(
                    store: store,
                    nodeId: nodeId,
                    axis: Axis.horizontal,
                  );

                  return PropertyField(
                    label: 'Width',
                    child: SizedBox(
                      height: 28,
                      child: SegmentedControl<String>(
                        heightOverride: 28,
                        gapOverride: 2,
                        showElevation: false,
                        items: [
                          SegmentedControlItem<String>(
                            value: 'hug',
                            label: 'Hug',
                            tooltip: HologramTooltip(
                              message: 'Hug',
                              child: const SizedBox.shrink(),
                            ),
                          ),
                          SegmentedControlItem<String>(
                            value: 'fixed',
                            label: 'Fixed',
                            tooltip: HologramTooltip(
                              message: 'Fixed',
                              child: const SizedBox.shrink(),
                            ),
                          ),
                          SegmentedControlItem<String>(
                            value: 'fill',
                            label: 'Fill',
                            enabled: fillReason == null,
                            tooltip: HologramTooltip(
                              message: fillReason ?? 'Fill',
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        selectedValues: {_getAxisSizeMode(size.width)},
                        onChanged: (selectedValues) {
                          final mode = selectedValues.firstOrNull;
                          if (mode != null) {
                            _updateWidthMode(mode, size);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),

              // Width value (if fixed)
              if (size.width is model.AxisSizeFixed) ...[
                SizedBox(height: context.spacing.xs),
                PropertyField(
                  label: '',
                  child: NumberEditor(
                    value: (size.width as model.AxisSizeFixed).value,
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

              // Height mode toggle
              Builder(
                builder: (context) {
                  final fillReason = LayoutValidation.getFillDisabledReason(
                    store: store,
                    nodeId: nodeId,
                    axis: Axis.vertical,
                  );

                  return PropertyField(
                    label: 'Height',
                    child: SizedBox(
                      height: 28,
                      child: SegmentedControl<String>(
                        heightOverride: 28,
                        gapOverride: 2,
                        showElevation: false,
                        items: [
                          SegmentedControlItem<String>(
                            value: 'hug',
                            label: 'Hug',
                            tooltip: HologramTooltip(
                              message: 'Hug',
                              child: const SizedBox.shrink(),
                            ),
                          ),
                          SegmentedControlItem<String>(
                            value: 'fixed',
                            label: 'Fixed',
                            tooltip: HologramTooltip(
                              message: 'Fixed',
                              child: const SizedBox.shrink(),
                            ),
                          ),
                          SegmentedControlItem<String>(
                            value: 'fill',
                            label: 'Fill',
                            enabled: fillReason == null,
                            tooltip: HologramTooltip(
                              message: fillReason ?? 'Fill',
                              child: const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        selectedValues: {_getAxisSizeMode(size.height)},
                        onChanged: (selectedValues) {
                          final mode = selectedValues.firstOrNull;
                          if (mode != null) {
                            _updateHeightMode(mode, size);
                          }
                        },
                      ),
                    ),
                  );
                },
              ),

              // Height value (if fixed)
              if (size.height is model.AxisSizeFixed) ...[
                SizedBox(height: context.spacing.xs),
                PropertyField(
                  label: '',
                  child: NumberEditor(
                    value: (size.height as model.AxisSizeFixed).value,
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

              // === AUTO LAYOUT (container only) ===
              if (hasAutoLayout) ...[
                SizedBox(height: context.spacing.md),

                // Direction
                PropertyField(
                  label: 'Direction',
                  child: ToggleEditor<model.LayoutDirection>(
                    value: autoLayout.direction,
                    options: {
                      model.LayoutDirection.horizontal:
                          LucideIcons.arrowRight.holo,
                      model.LayoutDirection.vertical:
                          LucideIcons.arrowDown.holo,
                    },
                    onChanged: (value) {
                      if (value != null) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/autoLayout/direction',
                          value.name,
                        );
                      }
                    },
                    required: true,
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Gap
                PropertyField(
                  label: 'Gap',
                  child: NumberEditor(
                    value: autoLayout.gap?.toDouble() ?? 0,
                    onChanged: (v) {
                      store.updateNodeProp(
                        nodeId,
                        '/layout/autoLayout/gap',
                        (v ?? 0).toDouble(),
                      );
                    },
                    min: 0,
                    allowDecimals: true,
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Padding
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
                      store.updateNodeProp(
                        nodeId,
                        '/layout/autoLayout/padding',
                        value.toJson(),
                      );
                    },
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Main axis alignment
                PropertyField(
                  label: 'Main Axis',
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
                    onChanged: (value) {
                      if (value != null) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/autoLayout/mainAlign',
                          value,
                        );
                      }
                    },
                  ),
                ),
                SizedBox(height: context.spacing.xs),

                // Cross axis alignment
                PropertyField(
                  label: 'Cross Axis',
                  child: DropdownEditor<String>(
                    value: autoLayout.crossAlign.name,
                    items: const [
                      DropdownItem(value: 'start', label: 'Start'),
                      DropdownItem(value: 'center', label: 'Center'),
                      DropdownItem(value: 'end', label: 'End'),
                      DropdownItem(value: 'stretch', label: 'Stretch'),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        store.updateNodeProp(
                          nodeId,
                          '/layout/autoLayout/crossAlign',
                          value,
                        );
                      }
                    },
                  ),
                ),
              ],

              // === CONSTRAINTS (Advanced - TODO: Add collapsible) ===
              SizedBox(height: context.spacing.md),

              PropertyField(
                label: 'Min Width',
                child: NumberEditor(
                  value: layout.constraints?.minWidth,
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

              PropertyField(
                label: 'Max Width',
                child: NumberEditor(
                  value: layout.constraints?.maxWidth,
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

              PropertyField(
                label: 'Min Height',
                child: NumberEditor(
                  value: layout.constraints?.minHeight,
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

              PropertyField(
                label: 'Max Height',
                child: NumberEditor(
                  value: layout.constraints?.maxHeight,
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

  String _getAxisSizeMode(model.AxisSize size) {
    return switch (size) {
      model.AxisSizeHug() => 'hug',
      model.AxisSizeFill() => 'fill',
      model.AxisSizeFixed() => 'fixed',
    };
  }

  void _updateWidthMode(String mode, model.SizeMode currentSize) {
    final newWidth = switch (mode) {
      'hug' => const model.AxisSizeHug(),
      'fill' => const model.AxisSizeFill(),
      'fixed' => model.AxisSizeFixed(
        currentSize.width is model.AxisSizeFixed
            ? (currentSize.width as model.AxisSizeFixed).value
            : 100.0,
      ),
      _ => const model.AxisSizeHug(),
    };

    store.updateNodeProp(nodeId, '/layout/size/width', newWidth.toJson());
  }

  void _updateHeightMode(String mode, model.SizeMode currentSize) {
    final newHeight = switch (mode) {
      'hug' => const model.AxisSizeHug(),
      'fill' => const model.AxisSizeFill(),
      'fixed' => model.AxisSizeFixed(
        currentSize.height is model.AxisSizeFixed
            ? (currentSize.height as model.AxisSizeFixed).value
            : 100.0,
      ),
      _ => const model.AxisSizeHug(),
    };

    store.updateNodeProp(nodeId, '/layout/size/height', newHeight.toJson());
  }
}
