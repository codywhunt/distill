import 'package:flutter/widgets.dart';
import 'package:distill_ds/design_system.dart';

import '../../../src/free_design/models/node_layout.dart';
import '../../../src/free_design/models/node_type.dart';
import '../../../src/free_design/scene/expanded_scene.dart';

/// Get the appropriate icon for a node.
///
/// For containers with auto-layout and children:
/// - Horizontal auto-layout: arrow pointing right
/// - Vertical auto-layout: arrow pointing down
///
/// For other node types: returns standard icon for the node type.
IconData getNodeTypeIcon(ExpandedNode node) {
  // Special case: container with auto-layout and children
  if (node.type == NodeType.container &&
      node.layout.autoLayout != null &&
      node.childIds.isNotEmpty) {
    // Return directional arrow based on auto-layout direction
    return node.layout.autoLayout!.direction == LayoutDirection.horizontal
        ? LucideIcons.stretchVertical200
        : LucideIcons.stretchHorizontal200;
  }

  // Default icons for other types
  return switch (node.type) {
    NodeType.container => LucideIcons.frame200,
    NodeType.text => LucideIcons.type200,
    NodeType.icon => LucideIcons.smile200,
    NodeType.image => LucideIcons.image200,
    NodeType.spacer => LucideIcons.maximize200,
    NodeType.instance => LucideIcons.component200,
    NodeType.slot => LucideIcons.squareDashed200,
  };
}
