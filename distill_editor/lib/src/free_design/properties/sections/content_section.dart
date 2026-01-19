import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/component_def.dart';
import '../../models/node.dart';
import '../../models/node_props.dart';
import '../../models/node_type.dart';
import '../../patch/patch_op.dart';
import '../../store/editor_document_store.dart';
import '../widgets/property_section_header.dart';
import '../editors/widgets/property_field.dart';
import '../editors/primitives/boolean_editor.dart';
import '../editors/primitives/text_editor.dart';
import '../editors/primitives/number_editor.dart';
import '../editors/primitives/button_editor.dart';
import '../editors/primitives/dropdown_editor.dart';
import '../editors/slots/editor_prefixes.dart';
import '../editors/pickers/color_picker_menu.dart';
import '../../render/token_resolver.dart';

/// Info about a slot in a component definition.
class _SlotInfo {
  final String name;
  final bool hasDefault;

  const _SlotInfo({required this.name, required this.hasDefault});
}

/// Content properties for a node.
class ContentSection extends StatelessWidget {
  const ContentSection({
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
    final props = node.props;

    if (props is ContainerProps) {
      return _buildContainerProps(context, props);
    }

    if (props is TextProps) {
      return _buildTextProps(context, props);
    }

    if (props is IconProps) {
      return _buildIconProps(context, props);
    }

    if (props is ImageProps) {
      return _buildImageProps(context, props);
    }

    if (props is SpacerProps) {
      return _buildSpacerProps(context, props);
    }

    if (props is InstanceProps) {
      return _buildInstanceProps(context, props);
    }

    if (props is SlotProps) {
      return _buildSlotProps(context, props);
    }

    return const SizedBox.shrink();
  }

  Widget _buildContainerProps(BuildContext context, ContainerProps props) {
    final isScrollable = props.scrollDirection != null;

    return Column(
      children: [
        const PropertySectionHeader(title: 'Container', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            children: [
              PropertyField(
                label: 'Clip Content',
                child: BooleanEditor(
                  value: props.clipContent,
                  onChanged: (value) {
                    store.updateNodeProp(
                      nodeId,
                      '/props/clipContent',
                      value ?? false,
                    );
                  },
                ),
              ),
              SizedBox(height: context.spacing.xs),
              PropertyField(
                label: 'Scrollable',
                child: BooleanEditor(
                  value: isScrollable,
                  onChanged: (value) {
                    // When enabling scroll, default to vertical
                    // When disabling, set to null
                    store.updateNodeProp(
                      nodeId,
                      '/props/scrollDirection',
                      value == true ? 'vertical' : null,
                    );
                  },
                ),
              ),
              if (isScrollable) ...[
                SizedBox(height: context.spacing.xs),
                PropertyField(
                  label: 'Direction',
                  child: DropdownEditor<String>(
                    value: props.scrollDirection ?? 'vertical',
                    items: const [
                      DropdownItem(value: 'vertical', label: 'Vertical'),
                      DropdownItem(value: 'horizontal', label: 'Horizontal'),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        store.updateNodeProp(
                          nodeId,
                          '/props/scrollDirection',
                          value,
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

  Widget _buildTextProps(BuildContext context, TextProps props) {
    final textColor = _parseColor(props.color);

    return Column(
      children: [
        const PropertySectionHeader(title: 'Text', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              PropertyField(
                label: 'Content',
                child: TextEditor(
                  value: props.text,
                  maxLines: 3,
                  onChanged: (value) {
                    store.updateNodeProp(nodeId, '/props/text', value);
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Font',
                child: DropdownEditor<String>(
                  value: props.fontFamily ?? 'Roboto',
                  items: const [
                    DropdownItem(value: 'Roboto', label: 'Roboto'),
                    DropdownItem(value: 'Inter', label: 'Inter'),
                    DropdownItem(value: 'Poppins', label: 'Poppins'),
                    DropdownItem(value: 'Open Sans', label: 'Open Sans'),
                    DropdownItem(value: 'Lato', label: 'Lato'),
                    DropdownItem(value: 'Montserrat', label: 'Montserrat'),
                  ],
                  onChanged: (value) {
                    store.updateNodeProp(nodeId, '/props/fontFamily', value);
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Font Size',
                child: NumberEditor(
                  value: props.fontSize,
                  onChanged: (v) {
                    if (v != null && v > 0) {
                      store.updateNodeProp(
                        nodeId,
                        '/props/fontSize',
                        v.toDouble(),
                      );
                    }
                  },
                  min: 1,
                  allowDecimals: false,
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Weight',
                child: DropdownEditor<int>(
                  value: props.fontWeight,
                  items: const [
                    DropdownItem(value: 100, label: 'Thin'),
                    DropdownItem(value: 300, label: 'Light'),
                    DropdownItem(value: 400, label: 'Regular'),
                    DropdownItem(value: 500, label: 'Medium'),
                    DropdownItem(value: 600, label: 'Semi Bold'),
                    DropdownItem(value: 700, label: 'Bold'),
                    DropdownItem(value: 900, label: 'Black'),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateNodeProp(nodeId, '/props/fontWeight', value);
                    }
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Alignment',
                child: DropdownEditor<String>(
                  value: props.textAlign.name,
                  items: const [
                    DropdownItem(value: 'left', label: 'Left'),
                    DropdownItem(value: 'center', label: 'Center'),
                    DropdownItem(value: 'right', label: 'Right'),
                    DropdownItem(value: 'justify', label: 'Justify'),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateNodeProp(nodeId, '/props/textAlign', value);
                    }
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Color',
                child: ColorPickerPopover(
                  initialColor: textColor,
                  onChanged: (color) {
                    store.updateNodeProp(
                      nodeId,
                      '/props/color',
                      _colorToHex(color),
                    );
                  },
                  child: ButtonEditor(
                    displayValue: _formatColorDisplay(props.color),
                    prefix: ColorSwatchPrefix(color: textColor),
                    onClear: props.color != null
                        ? () =>
                              store.updateNodeProp(nodeId, '/props/color', null)
                        : null,
                  ),
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Line Height',
                child: NumberEditor(
                  value: props.lineHeight,
                  placeholder: 'Auto',
                  onChanged: (v) {
                    store.updateNodeProp(
                      nodeId,
                      '/props/lineHeight',
                      v?.toDouble(),
                    );
                  },
                  min: 0.5,
                  max: 3,
                  allowDecimals: true,
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Letter Spacing',
                child: NumberEditor(
                  value: props.letterSpacing,
                  placeholder: '0',
                  onChanged: (v) {
                    store.updateNodeProp(
                      nodeId,
                      '/props/letterSpacing',
                      v?.toDouble(),
                    );
                  },
                  allowDecimals: true,
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Decoration',
                child: DropdownEditor<String>(
                  value: props.decoration.name,
                  items: const [
                    DropdownItem(value: 'none', label: 'None'),
                    DropdownItem(value: 'underline', label: 'Underline'),
                    DropdownItem(value: 'lineThrough', label: 'Strikethrough'),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateNodeProp(nodeId, '/props/decoration', value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconProps(BuildContext context, IconProps props) {
    final iconColor = _parseColor(props.color);

    return Column(
      children: [
        const PropertySectionHeader(title: 'Icon', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              PropertyField(
                label: 'Icon',
                child: TextEditor(
                  value: props.icon,
                  placeholder: 'Icon name (e.g., home, settings)',
                  onChanged: (value) {
                    store.updateNodeProp(nodeId, '/props/icon', value);
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Icon Set',
                child: DropdownEditor<String>(
                  value: props.iconSet,
                  items: const [
                    DropdownItem(value: 'material', label: 'Material Icons'),
                    DropdownItem(value: 'lucide', label: 'Lucide Icons'),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateNodeProp(nodeId, '/props/iconSet', value);
                    }
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Size',
                child: NumberEditor(
                  value: props.size,
                  onChanged: (v) {
                    if (v != null && v > 0) {
                      store.updateNodeProp(nodeId, '/props/size', v.toDouble());
                    }
                  },
                  min: 1,
                  allowDecimals: false,
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Color',
                child: ColorPickerPopover(
                  initialColor: iconColor,
                  onChanged: (color) {
                    store.updateNodeProp(
                      nodeId,
                      '/props/color',
                      _colorToHex(color),
                    );
                  },
                  child: ButtonEditor(
                    displayValue: _formatColorDisplay(props.color),
                    prefix: ColorSwatchPrefix(color: iconColor),
                    onClear: props.color != null
                        ? () =>
                              store.updateNodeProp(nodeId, '/props/color', null)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageProps(BuildContext context, ImageProps props) {
    return Column(
      children: [
        const PropertySectionHeader(title: 'Image', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              PropertyField(
                label: 'Source',
                child: TextEditor(
                  value: props.src,
                  placeholder: 'URL or asset path',
                  onChanged: (value) {
                    store.updateNodeProp(nodeId, '/props/src', value);
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Fit',
                child: DropdownEditor<String>(
                  value: props.fit.name,
                  items: const [
                    DropdownItem(value: 'contain', label: 'Contain'),
                    DropdownItem(value: 'cover', label: 'Cover'),
                    DropdownItem(value: 'fill', label: 'Fill'),
                    DropdownItem(value: 'fitWidth', label: 'Fit Width'),
                    DropdownItem(value: 'fitHeight', label: 'Fit Height'),
                    DropdownItem(value: 'none', label: 'None'),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      store.updateNodeProp(nodeId, '/props/fit', value);
                    }
                  },
                ),
              ),
              SizedBox(height: 6),
              PropertyField(
                label: 'Alt Text',
                child: TextEditor(
                  value: props.alt ?? '',
                  placeholder: 'Image description',
                  onChanged: (value) {
                    store.updateNodeProp(
                      nodeId,
                      '/props/alt',
                      value == null || value.isEmpty ? null : value,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _parseColor(String? colorString) {
    if (colorString == null) return Colors.black;

    // Check if it's a token reference (e.g., 'color.primary' or 'color.text.secondary')
    if (TokenResolver.isTokenRef(colorString)) {
      final resolved = tokenResolver.resolveColor(colorString);
      if (resolved != null) return resolved;
      return Colors.black;
    }

    // Parse as hex color
    try {
      final hex = colorString.replaceFirst('#', '');
      final value = int.parse(hex, radix: 16);
      if (hex.length == 6) {
        return Color(0xFF000000 | value);
      } else if (hex.length == 8) {
        return Color(value);
      }
    } catch (_) {}
    return Colors.black;
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  /// Format color string for display in the editor.
  /// Shows token reference with braces (e.g., '{color.primary}') or hex value.
  String _formatColorDisplay(String? colorString) {
    if (colorString == null) return '#000000';
    if (TokenResolver.isTokenRef(colorString)) {
      return '{$colorString}';
    }
    return colorString;
  }

  Widget _buildSpacerProps(BuildContext context, SpacerProps props) {
    return Column(
      children: [
        const PropertySectionHeader(title: 'Spacer', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: PropertyField(
            label: 'Flex',
            child: NumberEditor(
              value: props.flex.toDouble(),
              onChanged: (v) {
                if (v != null && v >= 1) {
                  store.updateNodeProp(nodeId, '/props/flex', v.toInt());
                }
              },
              min: 1,
              allowDecimals: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstanceProps(BuildContext context, InstanceProps props) {
    final component = store.document.components[props.componentId];
    final slots = _findComponentSlots(component);

    return Column(
      children: [
        const PropertySectionHeader(title: 'Instance', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: PropertyField(
            label: 'Component',
            child: TextEditor(
              value: props.componentId,
              disabled: true,
            ),
          ),
        ),
        if (slots.isNotEmpty) ...[
          const PropertySectionHeader(title: 'Slots'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              children: slots
                  .map((slot) => _buildSlotControl(context, props, slot))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  /// Find all slots in a component by walking its node tree.
  /// Uses visited set to prevent infinite loops on malformed graphs.
  List<_SlotInfo> _findComponentSlots(ComponentDef? component) {
    if (component == null) return [];
    final slots = <_SlotInfo>[];
    final visited = <String>{};

    void walk(String nodeId) {
      if (visited.contains(nodeId)) return; // Cycle protection
      visited.add(nodeId);

      final node = store.document.nodes[nodeId];
      if (node == null) return;

      if (node.type == NodeType.slot) {
        final slotProps = node.props as SlotProps;
        slots.add(_SlotInfo(
          name: slotProps.slotName,
          hasDefault: slotProps.defaultContentId != null,
        ));
      }

      for (final childId in node.childIds) {
        walk(childId);
      }
    }

    walk(component.rootNodeId);
    return slots;
  }

  Widget _buildSlotControl(
    BuildContext context,
    InstanceProps props,
    _SlotInfo slot,
  ) {
    final assignment = props.slots[slot.name];
    final hasContent = assignment?.hasContent == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              slot.name,
              style: context.typography.body.small,
            ),
          ),
          if (hasContent)
            IconButton(
              icon: Icon(LucideIcons.x, size: 14),
              tooltip: 'Clear slot',
              onPressed: () => store.clearSlotContent(nodeId, slot.name),
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              padding: EdgeInsets.zero,
            )
          else
            IconButton(
              icon: Icon(LucideIcons.plus, size: 14),
              tooltip: 'Add content',
              onPressed: () => _addSlotContent(slot.name),
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }

  void _addSlotContent(String slotName) {
    final contentId = 'slot_${slotName}_${DateTime.now().microsecondsSinceEpoch}';
    final contentNode = Node(
      id: contentId,
      name: 'Slot Content',
      type: NodeType.container,
      props: const ContainerProps(),
      ownerInstanceId: nodeId,
    );

    store.applyPatches([
      InsertNode(contentNode),
      SetProp(
        id: nodeId,
        path: '/props/slots/$slotName',
        value: SlotAssignment(rootNodeId: contentId).toJson(),
      ),
    ], label: 'Add slot content');
  }

  Widget _buildSlotProps(BuildContext context, SlotProps props) {
    return Column(
      children: [
        const PropertySectionHeader(title: 'Slot', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: PropertyField(
            label: 'Name',
            child: TextEditor(
              value: props.slotName,
              onChanged: (value) {
                store.updateNodeProp(nodeId, '/props/slotName', value);
              },
            ),
          ),
        ),
      ],
    );
  }
}
