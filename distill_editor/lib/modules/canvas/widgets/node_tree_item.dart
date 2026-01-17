import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../../src/free_design/scene/expanded_scene.dart';
import 'node_type_icon.dart';

/// A single tree row representing a node in the widget tree.
///
/// Displays:
/// - Indentation based on depth
/// - Optional expand/collapse chevron
/// - Node type icon
/// - Node name
/// - Optional instance badge
///
/// Supports selection, hover, and expand/collapse interactions.
class NodeTreeItem extends StatelessWidget {
  const NodeTreeItem({
    required this.expandedId,
    required this.expandedNode,
    required this.nodeName,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.isHovered,
    this.onTap,
    this.onHoverEnter,
    this.onHoverExit,
    this.onToggleExpand,
    super.key,
  });

  /// The expanded ID of this node (may be namespaced like "inst::child").
  final String expandedId;

  /// The expanded node data.
  final ExpandedNode expandedNode;

  /// The node's display name.
  final String nodeName;

  /// The depth level in the tree (0 = root).
  final int depth;

  /// Whether this node is expanded (null if not expandable).
  final bool? isExpanded;

  /// Whether this node is selected.
  final bool isSelected;

  /// Whether this node is hovered.
  final bool isHovered;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Called when the mouse enters the row.
  final VoidCallback? onHoverEnter;

  /// Called when the mouse exits the row.
  final VoidCallback? onHoverExit;

  /// Called when the expand/collapse chevron is tapped.
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final isInstance = expandedNode.patchTargetId == null;
    final showChevron = isExpanded != null;

    // Calculate indentation: 8px base + 12px per level
    final indent = 6.0 + (depth * 12.0);

    return HoloTappable(
      onTap: onTap,
      cursor: SystemMouseCursors.basic,
      onHoverChange: (hovered) {
        if (hovered) {
          onHoverEnter?.call();
        } else {
          onHoverExit?.call();
        }
      },
      selected: isSelected,
      builder: (context, states, _) {
        // Combine external hover state with internal hover state
        final effectiveHovered = states.isHovered || isHovered;
        final effectiveSelected = states.isSelected || isSelected;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          height: 26,
          decoration: BoxDecoration(
            color: effectiveSelected
                ? context.colors.accent.purple.primary
                : (effectiveHovered ? context.colors.overlay.overlay05 : null),
            borderRadius: BorderRadius.circular(context.radius.sm),
          ),
          child: Padding(
            padding: EdgeInsets.only(left: indent, right: 8),
            child: Row(
              children: [
                // Chevron for expandable nodes
                if (showChevron)
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: AnimatedRotation(
                      turns: isExpanded! ? 0.25 : 0, // 90° when expanded
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronRight200,
                        size: 12,
                        color: effectiveSelected
                            ? context.colors.foreground.disabled
                            : effectiveHovered
                            ? context.colors.foreground.muted
                            : context.colors.foreground.weak,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 12.5), // Spacer when no chevron

                const SizedBox(width: 8),

                // Node type icon
                Icon(
                  getNodeTypeIcon(expandedNode),
                  size: 13,
                  color: effectiveSelected
                      ? Colors.white
                      : effectiveHovered
                      ? context.colors.foreground.primary
                      : context.colors.foreground.muted,
                ),

                const SizedBox(width: 6),

                // Node name
                Expanded(
                  child: Text(
                    nodeName,
                    style: context.typography.body.medium.copyWith(
                      color: effectiveSelected
                          ? Colors.white
                          : effectiveHovered
                          ? context.colors.foreground.primary
                          : context.colors.foreground.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),

                // Instance badge
                if (isInstance) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Component instance (children hidden)',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9333EA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        LucideIcons.component200,
                        size: 12,
                        color: Color(0xFF9333EA),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
