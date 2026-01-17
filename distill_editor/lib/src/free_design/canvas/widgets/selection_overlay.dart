import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../drag_session.dart';
import '../drag_target.dart' as canvas;
import '../../../../modules/canvas/canvas_state.dart';

/// Renders selection rectangles and hover feedback in screen-space.
///
/// This widget renders:
/// - Hover outline (dashed, blue) for hovered target
/// - Selection outlines (solid, blue) for selected targets
/// - Frame labels (name + dimensions) for frames that are hovered, selected,
///   or have a node within them selected
class SelectionOverlay extends StatelessWidget {
  const SelectionOverlay({
    required this.state,
    required this.controller,
    required this.onFrameLabelTap,
    super.key,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;
  final void Function(String frameId) onFrameLabelTap;

  @override
  Widget build(BuildContext context) {
    // Show labels for ALL frames at all times
    final labelFrameIds = state.document.frames.keys.toSet();

    // Determine which frames are "in focus" (hovered or selected)
    final focusFrameIds = <String>{};

    // Add hovered frame
    final hovered = state.hovered;
    if (hovered is canvas.FrameTarget) {
      focusFrameIds.add(hovered.frameId);
    }

    // Add selected frames
    focusFrameIds.addAll(state.selectedFrameIds);

    // Add frames with selected nodes
    for (final node in state.selectedNodes) {
      focusFrameIds.add(node.frameId);
    }

    return Stack(
      children: [
        // Non-interactive overlays (outlines)
        IgnorePointer(
          child: Stack(
            children: [
              // Drop zone highlight (green, dashed) during drag
              if (state.dragSession != null &&
                  state.dragSession!.dropTarget != null &&
                  state.dragSession!.dropFrameId != null)
                _DropZoneHighlight(
                  frameId: state.dragSession!.dropFrameId!,
                  nodeId: state.dragSession!.dropTarget!,
                  controller: controller,
                  state: state,
                ),

              // Animated border for frames being updated by AI
              for (final frameId in state.updatingFrameIds)
                _UpdatingFrameOverlay(
                  frameId: frameId,
                  controller: controller,
                  state: state,
                ),

              // Hover outline (dashed, blue)
              if (state.hovered != null)
                _HoverOutline(
                  target: state.hovered!,
                  controller: controller,
                  state: state,
                ),

              // Selection outlines (solid, blue)
              for (final target in state.selection)
                _SelectionOutline(
                  target: target,
                  controller: controller,
                  state: state,
                ),
            ],
          ),
        ),

        // Interactive frame labels and interact mode buttons
        for (final frameId in labelFrameIds) ...[
          _FrameLabel(
            frameId: frameId,
            controller: controller,
            state: state,
            onTap: () => onFrameLabelTap(frameId),
            isFocused: focusFrameIds.contains(frameId),
          ),
          _InteractModeButton(
            frameId: frameId,
            controller: controller,
            state: state,
          ),
        ],
      ],
    );
  }
}

/// Dashed blue outline for hovered target.
class _HoverOutline extends StatelessWidget {
  const _HoverOutline({
    required this.target,
    required this.controller,
    required this.state,
  });

  final canvas.DragTarget target;
  final InfiniteCanvasController controller;
  final CanvasState state;

  @override
  Widget build(BuildContext context) {
    final bounds = _getBounds(target, state);
    if (bounds == null) return const SizedBox.shrink();

    final viewBounds = controller.worldToViewRect(bounds);

    return CustomPaint(
      painter: _OutlinePainter(
        rect: viewBounds,
        color: const Color(0xFF007AFF),
        strokeWidth: 1.0,
        dashed: true,
      ),
      size: Size.infinite,
    );
  }
}

/// Solid blue outline for selected target.
class _SelectionOutline extends StatelessWidget {
  const _SelectionOutline({
    required this.target,
    required this.controller,
    required this.state,
  });

  final canvas.DragTarget target;
  final InfiniteCanvasController controller;
  final CanvasState state;

  @override
  Widget build(BuildContext context) {
    final bounds = _getBounds(target, state);
    if (bounds == null) return const SizedBox.shrink();

    final viewBounds = controller.worldToViewRect(bounds);

    return CustomPaint(
      painter: _OutlinePainter(
        rect: viewBounds,
        color: const Color(0xFF007AFF),
        strokeWidth: 2.0,
        dashed: false,
      ),
      size: Size.infinite,
    );
  }
}

/// Frame label showing name and dimensions.
///
/// Clickable to select the frame. Shows for all frames at all times.
class _FrameLabel extends StatefulWidget {
  const _FrameLabel({
    required this.frameId,
    required this.controller,
    required this.state,
    required this.onTap,
    required this.isFocused,
  });

  final String frameId;
  final InfiniteCanvasController controller;
  final CanvasState state;
  final VoidCallback onTap;
  final bool isFocused;

  @override
  State<_FrameLabel> createState() => _FrameLabelState();
}

class _FrameLabelState extends State<_FrameLabel> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final frame = widget.state.document.frames[widget.frameId];
    if (frame == null) return const SizedBox.shrink();

    // Use preview bounds during drag/resize
    final target = canvas.FrameTarget(widget.frameId);
    final worldBounds = _getBounds(target, widget.state) ?? frame.canvas.bounds;
    final viewBounds = widget.controller.worldToViewRect(worldBounds);

    // Position label above frame with some padding
    final labelLeft = viewBounds.left;
    final labelTop = viewBounds.top - 24;

    // Determine if this label should be highlighted
    final isActive = widget.isFocused || _isHovered;

    // Check if this frame is actively being resized
    final session = widget.state.dragSession;
    final isResizing =
        session != null &&
        session.mode == DragMode.resize &&
        session.targets.contains(target);

    // Build label text - only show dimensions during resize
    final labelText = isResizing
        ? '${frame.name} – ${worldBounds.width.toInt()}×${worldBounds.height.toInt()}'
        : frame.name;

    // Color scheme:
    // - Active (focused or hovered): purple background, white text
    // - Inactive: transparent background, muted text
    final textColor = isActive
        ? context.colors.accent.purple.primary
        : context.colors.foreground.muted;

    return Positioned(
      left: labelLeft,
      top: labelTop,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        // IgnorePointer: gestures handled by canvas hit testing for instant response
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
            child: Text(
              labelText,
              style: TextStyle(
                color: textColor,
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Button to toggle interact mode for a frame.
///
/// Positioned at top-right of frame, aligned with frame label.
/// Hand icon = design mode (nodes selectable), Mouse pointer = interact mode.
class _InteractModeButton extends StatefulWidget {
  const _InteractModeButton({
    required this.frameId,
    required this.controller,
    required this.state,
  });

  final String frameId;
  final InfiniteCanvasController controller;
  final CanvasState state;

  @override
  State<_InteractModeButton> createState() => _InteractModeButtonState();
}

class _InteractModeButtonState extends State<_InteractModeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final frame = widget.state.document.frames[widget.frameId];
    if (frame == null) return const SizedBox.shrink();

    // Use preview bounds during drag/resize
    final target = canvas.FrameTarget(widget.frameId);
    final worldBounds = _getBounds(target, widget.state) ?? frame.canvas.bounds;
    final viewBounds = widget.controller.worldToViewRect(worldBounds);

    // Position at top-right of frame, aligned with label row
    final buttonLeft = viewBounds.right - 18;
    final buttonTop = viewBounds.top - 22;

    final isActive = widget.state.isInteractMode(widget.frameId);
    final showHighlight = isActive || _isHovered;

    return Positioned(
      left: buttonLeft,
      top: buttonTop,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () => widget.state.toggleInteractMode(widget.frameId),
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: showHighlight
                  ? context.colors.accent.purple.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              isActive ? LucideIcons.mousePointer200 : LucideIcons.hand200,
              size: 12,
              color: showHighlight
                  ? context.colors.accent.purple.primary
                  : context.colors.foreground.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for selection/hover outlines.
class _OutlinePainter extends CustomPainter {
  const _OutlinePainter({
    required this.rect,
    required this.color,
    required this.strokeWidth,
    required this.dashed,
  });

  final Rect rect;
  final Color color;
  final double strokeWidth;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (dashed) {
      _drawDashedRect(canvas, rect, paint);
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;

    // Top edge
    _drawDashedLine(
      canvas,
      rect.topLeft,
      rect.topRight,
      paint,
      dashWidth,
      dashSpace,
    );

    // Right edge
    _drawDashedLine(
      canvas,
      rect.topRight,
      rect.bottomRight,
      paint,
      dashWidth,
      dashSpace,
    );

    // Bottom edge
    _drawDashedLine(
      canvas,
      rect.bottomRight,
      rect.bottomLeft,
      paint,
      dashWidth,
      dashSpace,
    );

    // Left edge
    _drawDashedLine(
      canvas,
      rect.bottomLeft,
      rect.topLeft,
      paint,
      dashWidth,
      dashSpace,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final length = (end - start).distance;
    final dx = (end.dx - start.dx) / length;
    final dy = (end.dy - start.dy) / length;

    var distance = 0.0;
    while (distance < length) {
      final dashEnd = distance + dashWidth;
      canvas.drawLine(
        Offset(start.dx + dx * distance, start.dy + dy * distance),
        Offset(
          start.dx + dx * dashEnd.clamp(0, length),
          start.dy + dy * dashEnd.clamp(0, length),
        ),
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter oldDelegate) {
    return oldDelegate.rect != rect ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashed != dashed;
  }
}

/// Get world-space bounds for a drag target, accounting for active drag sessions.
Rect? _getBounds(canvas.DragTarget target, CanvasState state) {
  // Check if this target is being dragged/resized
  final session = state.dragSession;
  if (session != null) {
    final previewBounds = session.getCurrentBounds(target);
    if (previewBounds != null) {
      return previewBounds;
    }
  }

  // Fall back to stored bounds
  return switch (target) {
    canvas.FrameTarget(:final frameId) =>
      state.document.frames[frameId]?.canvas.bounds,
    canvas.NodeTarget(:final frameId, :final expandedId) => _getNodeWorldBounds(
      state,
      frameId,
      expandedId,
    ),
  };
}

/// Get world-space bounds for a node.
///
/// Uses cached bounds from [CanvasState.getNodeBounds] which are in
/// frame-local coordinates, then converts to world coordinates by adding
/// the frame's position.
Rect? _getNodeWorldBounds(
  CanvasState state,
  String frameId,
  String expandedId,
) {
  final frame = state.document.frames[frameId];
  if (frame == null) return null;

  // Get frame-local bounds from cache (populated by RenderEngine._BoundsTracker)
  final localBounds = state.getNodeBounds(frameId, expandedId);
  if (localBounds == null) return null;

  // Convert to world coordinates by adding frame position
  return localBounds.shift(frame.canvas.position);
}

/// Animated border overlay for frames being updated by AI.
class _UpdatingFrameOverlay extends StatefulWidget {
  const _UpdatingFrameOverlay({
    required this.frameId,
    required this.controller,
    required this.state,
  });

  final String frameId;
  final InfiniteCanvasController controller;
  final CanvasState state;

  @override
  State<_UpdatingFrameOverlay> createState() => _UpdatingFrameOverlayState();
}

class _UpdatingFrameOverlayState extends State<_UpdatingFrameOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Gentle opacity pulse between 0.3 and 0.7
    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.state.document.frames[widget.frameId];
    if (frame == null) return const SizedBox.shrink();

    final worldBounds = frame.canvas.bounds;
    final viewBounds = widget.controller.worldToViewRect(worldBounds);

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: _UpdatingBorderPainter(
            rect: viewBounds,
            opacity: _opacityAnimation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Subtle animated border painter for frames being updated.
/// Creates a gentle pulsing border effect.
class _UpdatingBorderPainter extends CustomPainter {
  const _UpdatingBorderPainter({required this.rect, required this.opacity});

  final Rect rect;
  final double opacity;

  // Muted purple color
  static const _baseColor = Color(0xFF8B5CF6);

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    final borderRect = rect.deflate(strokeWidth / 2);
    final rrect = RRect.fromRectAndRadius(borderRect, const Radius.circular(4));

    // Single solid border with pulsing opacity
    final paint = Paint()
      ..color = _baseColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_UpdatingBorderPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.opacity != opacity;
  }
}

/// Green dashed outline for valid drop target during drag.
class _DropZoneHighlight extends StatelessWidget {
  const _DropZoneHighlight({
    required this.frameId,
    required this.nodeId,
    required this.controller,
    required this.state,
  });

  final String frameId;
  final String nodeId;
  final InfiniteCanvasController controller;
  final CanvasState state;

  @override
  Widget build(BuildContext context) {
    // Find the expanded ID for this node
    final scene = state.getExpandedScene(frameId);
    if (scene == null) return const SizedBox.shrink();

    String? expandedId;
    for (final entry in scene.patchTarget.entries) {
      if (entry.value == nodeId) {
        expandedId = entry.key;
        break;
      }
    }

    if (expandedId == null) return const SizedBox.shrink();

    final worldBounds = _getNodeWorldBounds(state, frameId, expandedId);
    if (worldBounds == null) return const SizedBox.shrink();

    final viewBounds = controller.worldToViewRect(worldBounds);

    return CustomPaint(painter: _DropZonePainter(bounds: viewBounds));
  }
}

/// Painter for drop zone highlighting (green dashed outline).
class _DropZonePainter extends CustomPainter {
  const _DropZonePainter({required this.bounds});

  final Rect bounds;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw filled background with transparency for better visibility
    final fillPaint = Paint()
      ..color = const Color(0xFF00C853).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRect(bounds, fillPaint);

    // Draw glowing border for prominence
    final glowPaint = Paint()
      ..color = const Color(0xFF00C853).withValues(alpha: 0.4)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds, glowPaint);

    // Draw solid border
    final borderPaint = Paint()
      ..color =
          const Color(0xFF00C853) // Green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds, borderPaint);
  }

  @override
  bool shouldRepaint(_DropZonePainter oldDelegate) {
    return bounds != oldDelegate.bounds;
  }
}
