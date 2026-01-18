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
HoloIconData getNodeTypeIcon(ExpandedNode node) {
  // Special case: container with auto-layout and children
  if (node.type == NodeType.container &&
      node.layout.autoLayout != null &&
      node.childIds.isNotEmpty) {
    // Return directional arrow based on auto-layout direction
    return node.layout.autoLayout!.direction == LayoutDirection.horizontal
        ? HoloIconData.icon(LucideIcons.stretchHorizontal200)
        : HoloIconData.icon(LucideIcons.stretchVertical200);
  }

  // Default icons for other types
  return switch (node.type) {
    NodeType.container => HoloIconData.huge(HugeIconsStrokeRounded.grid),
    NodeType.text => HoloIconData.huge(HugeIconsStrokeRounded.text),
    NodeType.icon => HoloIconData.huge(HugeIconsStrokeRounded.smile),
    NodeType.image => HoloIconData.huge(HugeIconsStrokeRounded.image01),
    NodeType.spacer => HoloIconData.huge(
      HugeIconsStrokeRounded.strokeRoundedArrowExpand,
    ),
    NodeType.instance => HoloIconData.huge(HugeIconsStrokeRounded.diamond),
    NodeType.slot => HoloIconData.huge(HugeIconsStrokeRounded.dashedLine01),
  };
}
