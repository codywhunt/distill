import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../drag_session.dart';
import '../drag_target.dart' as canvas;
import '../../../../modules/canvas/canvas_state.dart';

/// Constants for resize handle appearance and hit testing.
const double kHandleSize = 8.0;
const double kHandleHitRadius = 12.0;

/// 8-point resize handles for selected frames/nodes.
///
/// Only visible when a single target is selected. Handles are rendered
/// in screen-space and positioned around the selection bounds.
class ResizeHandles extends StatelessWidget {
  const ResizeHandles({
    required this.state,
    required this.controller,
    super.key,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    // Only show for single selection and not during drag
    if (state.selection.length != 1 || state.isDragging) {
      return const SizedBox.shrink();
    }

    final target = state.selection.first;

    // Don't show resize handles for nodes - only for frames
    if (target is canvas.NodeTarget) {
      return const SizedBox.shrink();
    }

    final bounds = _getTargetBounds(target, state);
    if (bounds == null) return const SizedBox.shrink();

    final viewBounds = controller.worldToViewRect(bounds);

    return Stack(
      children: ResizeHandle.values.map((handle) {
        final handlePos = _getHandlePosition(viewBounds, handle);
        return Positioned(
          left: handlePos.dx - kHandleSize / 2,
          top: handlePos.dy - kHandleSize / 2,
          child: _ResizeHandle(handle: handle),
        );
      }).toList(),
    );
  }
}

/// Individual resize handle widget.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({required this.handle});

  final ResizeHandle handle;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _getCursor(widget.handle),
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: IgnorePointer(
        child: Container(
          width: kHandleSize,
          height: kHandleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: _hovering
                  ? const Color(0xFF007AFF)
                  : const Color(0xFF007AFF),
              width: _hovering ? 2.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SystemMouseCursor _getCursor(ResizeHandle handle) {
    return switch (handle) {
      ResizeHandle.topLeft => SystemMouseCursors.resizeUpLeft,
      ResizeHandle.topCenter => SystemMouseCursors.resizeUp,
      ResizeHandle.topRight => SystemMouseCursors.resizeUpRight,
      ResizeHandle.middleLeft => SystemMouseCursors.resizeLeft,
      ResizeHandle.middleRight => SystemMouseCursors.resizeRight,
      ResizeHandle.bottomLeft => SystemMouseCursors.resizeDownLeft,
      ResizeHandle.bottomCenter => SystemMouseCursors.resizeDown,
      ResizeHandle.bottomRight => SystemMouseCursors.resizeDownRight,
    };
  }
}

/// Get the screen-space position for a resize handle.
Offset _getHandlePosition(Rect viewBounds, ResizeHandle handle) {
  return switch (handle) {
    ResizeHandle.topLeft => viewBounds.topLeft,
    ResizeHandle.topCenter => Offset(viewBounds.center.dx, viewBounds.top),
    ResizeHandle.topRight => viewBounds.topRight,
    ResizeHandle.middleLeft => Offset(viewBounds.left, viewBounds.center.dy),
    ResizeHandle.middleRight => Offset(viewBounds.right, viewBounds.center.dy),
    ResizeHandle.bottomLeft => viewBounds.bottomLeft,
    ResizeHandle.bottomCenter => Offset(
      viewBounds.center.dx,
      viewBounds.bottom,
    ),
    ResizeHandle.bottomRight => viewBounds.bottomRight,
  };
}

/// Get world-space bounds for a drag target.
Rect? _getTargetBounds(canvas.DragTarget target, CanvasState state) {
  return switch (target) {
    canvas.FrameTarget(:final frameId) =>
      state.document.frames[frameId]?.canvas.bounds,
    canvas.NodeTarget(:final frameId, :final expandedId) => () {
      final scene = state.getExpandedScene(frameId);
      if (scene == null) return null;

      final node = scene.nodes[expandedId];
      if (node == null) return null;

      final frame = state.document.frames[frameId];
      if (frame == null) return null;

      final nodeLocalBounds = node.bounds;
      if (nodeLocalBounds == null) return null;

      // Convert from frame-relative to world coordinates
      return Rect.fromLTWH(
        frame.canvas.position.dx + nodeLocalBounds.left,
        frame.canvas.position.dy + nodeLocalBounds.top,
        nodeLocalBounds.width,
        nodeLocalBounds.height,
      );
    }(),
  };
}
