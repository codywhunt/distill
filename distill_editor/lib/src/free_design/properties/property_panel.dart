import 'package:flutter/widgets.dart' hide DragTarget;
import 'package:distill_ds/design_system.dart';

import '../canvas/drag_target.dart';
import '../../../modules/canvas/canvas_state.dart';
import '../store/editor_document_store.dart';
import 'sections/frame_section.dart';
import 'sections/layout_section_v2.dart';
import 'sections/appearance_section.dart';
import 'sections/content_section.dart';

/// Property panel for the free design canvas.
class FreeDesignPropertyPanel extends StatelessWidget {
  const FreeDesignPropertyPanel({
    required this.state,
    required this.store,
    super.key,
  });

  final CanvasState state;
  final EditorDocumentStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([state, store]),
      builder: (context, _) {
        final selection = state.selection;

        if (selection.isEmpty) {
          return _buildEmptyState(context);
        }

        if (selection.length == 1) {
          final target = selection.first;
          return switch (target) {
            FrameTarget() => _buildFrameProperties(context, target),
            NodeTarget() => _buildNodeProperties(context, target),
          };
        }

        return _buildMultiSelection(context);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        'No selection',
        style: context.typography.body.medium.copyWith(
          color: context.colors.foreground.muted,
        ),
      ),
    );
  }

  Widget _buildFrameProperties(BuildContext context, FrameTarget target) {
    final frame = store.document.frames[target.frameId];
    if (frame == null) return _buildEmptyState(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(context, frame.name),
          FrameSection(frameId: target.frameId, frame: frame, store: store),
        ],
      ),
    );
  }

  Widget _buildNodeProperties(BuildContext context, NodeTarget target) {
    final nodeId = target.patchTarget;
    if (nodeId == null) {
      return Center(
        child: Text(
          'Cannot edit nodes inside instances',
          style: context.typography.body.small.copyWith(
            color: context.colors.foreground.muted,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final node = store.document.nodes[nodeId];
    if (node == null) return _buildEmptyState(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          ContentSection(
            nodeId: nodeId,
            node: node,
            store: store,
            tokenResolver: state.tokenResolver,
          ),
          LayoutSectionV2(nodeId: nodeId, node: node, store: store),
          AppearanceSection(
            nodeId: nodeId,
            node: node,
            store: store,
            tokenResolver: state.tokenResolver,
          ),
          const SizedBox(height: 200),
        ],
      ),
    );
  }

  Widget _buildMultiSelection(BuildContext context) {
    return Center(
      child: Text(
        '${state.selection.length} items selected',
        style: context.typography.body.medium.copyWith(
          color: context.colors.foreground.muted,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    final colors = context.colors;
    final typography = context.typography;
    final spacing = context.spacing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(color: colors.background.alternate),
      child: Text(
        title,
        style: typography.body.mediumStrong.copyWith(
          color: colors.foreground.primary,
        ),
      ),
    );
  }
}
