import 'package:distill_ds/design_system.dart';
import 'package:flutter/material.dart';

import '../../../src/free_design/models/component_def.dart';

/// A single row in the component library panel.
///
/// Displays:
/// - Component icon (purple badge)
/// - Component name
/// - Insert button (visible on hover/select)
/// - Delete button (visible on hover/select)
class ComponentLibraryItem extends StatelessWidget {
  const ComponentLibraryItem({
    required this.component,
    required this.onTap,
    required this.onInsert,
    required this.onDelete,
    super.key,
  });

  final ComponentDef component;
  final VoidCallback onTap;
  final VoidCallback onInsert;
  final VoidCallback onDelete;

  // Purple component color (matches instance badge in NodeTreeItem)
  static const _componentColor = Color(0xFF9333EA);

  @override
  Widget build(BuildContext context) {
    return HoloTappable(
      onTap: onTap,
      cursor: SystemMouseCursors.basic,
      builder: (context, states, _) {
        final isHovered = states.isHovered;
        final isSelected = states.isSelected;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          height: 26,
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.accent.teal.primary
                : (isHovered ? context.colors.overlay.overlay05 : null),
            borderRadius: BorderRadius.circular(context.radius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(
              children: [
                // Component icon (purple badge)
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _componentColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.component200,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Name
                Expanded(
                  child: Text(
                    component.name,
                    style: context.typography.body.medium.copyWith(
                      color: isSelected
                          ? Colors.white
                          : isHovered
                              ? context.colors.foreground.primary
                              : context.colors.foreground.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // Action buttons (visible on hover or selected)
                if (isSelected || isHovered) ...[
                  // Insert instance button
                  Tooltip(
                    message: 'Insert instance in current frame',
                    child: GestureDetector(
                      onTap: onInsert,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          LucideIcons.plus200,
                          size: 13,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.7)
                              : context.colors.foreground.muted,
                        ),
                      ),
                    ),
                  ),
                  // Delete button
                  Tooltip(
                    message: 'Delete component',
                    child: GestureDetector(
                      onTap: onDelete,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          LucideIcons.trash2200,
                          size: 13,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.7)
                              : context.colors.foreground.muted,
                        ),
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
