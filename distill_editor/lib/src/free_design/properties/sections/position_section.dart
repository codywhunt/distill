import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/node.dart';
import '../../models/node_layout.dart';
import '../../store/editor_document_store.dart';
import '../widgets/property_section_header.dart';
import '../editors/widgets/property_field.dart';
import '../editors/primitives/number_editor.dart';
import '../editors/primitives/dropdown_editor.dart';

/// Position properties for a node (auto vs absolute positioning).
class PositionSection extends StatelessWidget {
  const PositionSection({
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
    final position = node.layout.position;
    final isAbsolute = position is PositionModeAbsolute;

    return Column(
      children: [
        const PropertySectionHeader(title: 'Position'),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            children: [
              PropertyField(
                label: 'Mode',
                child: DropdownEditor<String>(
                  value: isAbsolute ? 'absolute' : 'auto',
                  items: const [
                    DropdownItem(
                      value: 'auto',
                      label: 'Auto',
                      description: 'Position via auto-layout',
                    ),
                    DropdownItem(
                      value: 'absolute',
                      label: 'Absolute',
                      description: 'Free positioning via X/Y coordinates',
                    ),
                  ],
                  onChanged: (value) {
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
              if (isAbsolute) ...[
                SizedBox(height: context.spacing.xs),
                PropertyField(
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
                SizedBox(height: context.spacing.xs),
                PropertyField(
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
              ],
            ],
          ),
        ),
      ],
    );
  }
}
