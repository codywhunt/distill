import 'package:distill_ds/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../src/free_design/models/frame.dart';
import '../../../src/free_design/store/editor_document_store.dart';
import '../../../workspace/components/confirm_dialog.dart';
import '../canvas_state.dart';
import 'frame_list_item.dart';

/// Padding around frame when navigating to it.
const kFrameNavigationPadding = EdgeInsets.all(50.0);

/// Collapsible section displaying all frames in the document.
///
/// Features:
/// - Collapsible header with frame count
/// - List of all frames sorted by creation time
/// - Click to select and navigate
/// - Double-click name to rename inline
/// - Delete button with confirmation
/// - "+" button to create new frame at viewport center
class FrameListPanel extends StatefulWidget {
  const FrameListPanel({super.key});

  @override
  State<FrameListPanel> createState() => _FrameListPanelState();
}

class _FrameListPanelState extends State<FrameListPanel> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final canvasState = context.watch<CanvasState>();
    final frames =
        canvasState.document.frames.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: context.spacing.xxs),
        // Collapsible header
        _FrameSectionHeader(
          frameCount: frames.length,
          isExpanded: _isExpanded,
          onToggle: () => setState(() => _isExpanded = !_isExpanded),
          onAddFrame: () => _createFrame(context),
        ),

        // Frame list (when expanded)
        if (_isExpanded)
          frames.isEmpty
              ? _buildEmptyState(context)
              : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: context.spacing.xxs),
                  for (final frame in frames)
                    FrameListItem(
                      frame: frame,
                      isSelected: canvasState.selectedFrameIds.contains(
                        frame.id,
                      ),
                      onTap: () => _selectAndNavigate(context, frame),
                      onDelete: () => _confirmDelete(context, frame),
                    ),
                  SizedBox(height: context.spacing.xxs),
                ],
              ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        'No frames yet',
        style: context.typography.body.medium.copyWith(
          color: context.colors.foreground.muted,
        ),
      ),
    );
  }

  void _selectAndNavigate(BuildContext context, Frame frame) {
    final canvasState = context.read<CanvasState>();
    final controller = canvasState.canvasController;

    // Select the frame
    canvasState.selectFrame(frame.id);

    // Animate to frame if we have a controller
    if (controller != null) {
      // Check if frame is already mostly visible
      final viewSize = MediaQuery.sizeOf(context);
      final visibleBounds = controller.getVisibleWorldBounds(viewSize);

      if (!visibleBounds.contains(frame.canvas.bounds.center)) {
        controller.animateToFit(
          frame.canvas.bounds,
          padding: kFrameNavigationPadding,
        );
      }
    }
  }

  void _createFrame(BuildContext context) {
    final canvasState = context.read<CanvasState>();
    final controller = canvasState.canvasController;
    if (controller == null) return;

    // Get viewport center in world coordinates
    final viewSize = MediaQuery.sizeOf(context);
    final viewCenter = Offset(viewSize.width / 2, viewSize.height / 2);
    final worldCenter = controller.viewToWorld(viewCenter);

    // Create frame centered at viewport
    const frameSize = Size(375, 812);
    final position =
        worldCenter - Offset(frameSize.width / 2, frameSize.height / 2);

    canvasState.store.createEmptyFrame(position: position, size: frameSize);
  }

  Future<void> _confirmDelete(BuildContext context, Frame frame) async {
    final confirmed = await showConfirmDialog(
      context,
      title: "Delete '${frame.name}'?",
      message: 'This will remove the frame and all layers inside it.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<CanvasState>().store.deleteFrameAndSubtree(frame.id);
    }
  }
}

/// Collapsible section header for frames.
class _FrameSectionHeader extends StatelessWidget {
  const _FrameSectionHeader({
    required this.frameCount,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddFrame,
  });

  final int frameCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onAddFrame;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Expand/collapse chevron
            Icon(
              isExpanded
                  ? LucideIcons.chevronDown200
                  : LucideIcons.chevronRight200,
              size: 12,
              color: context.colors.foreground.muted,
            ),
            const SizedBox(width: 4),
            // Title with count
            Text(
              'Frames',
              style: context.typography.body.medium.copyWith(
                color: context.colors.foreground.muted,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($frameCount)',
              style: context.typography.body.medium.copyWith(
                color: context.colors.foreground.weak,
              ),
            ),
            const Spacer(),
            // Add button
            GestureDetector(
              onTap: onAddFrame,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.plus200,
                  size: 14,
                  color: context.colors.foreground.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
