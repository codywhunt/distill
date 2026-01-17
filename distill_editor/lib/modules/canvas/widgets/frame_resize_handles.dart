import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distill_ds/design_system.dart';

/// Handle position on the frame.
enum ResizeHandlePosition {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Extension to get cursor and resize behavior for each handle.
extension ResizeHandlePositionX on ResizeHandlePosition {
  /// The cursor to show when hovering this handle.
  SystemMouseCursor get cursor => switch (this) {
    ResizeHandlePosition.topLeft => SystemMouseCursors.resizeUpLeft,
    ResizeHandlePosition.topCenter => SystemMouseCursors.resizeUp,
    ResizeHandlePosition.topRight => SystemMouseCursors.resizeUpRight,
    ResizeHandlePosition.middleLeft => SystemMouseCursors.resizeLeft,
    ResizeHandlePosition.middleRight => SystemMouseCursors.resizeRight,
    ResizeHandlePosition.bottomLeft => SystemMouseCursors.resizeDownLeft,
    ResizeHandlePosition.bottomCenter => SystemMouseCursors.resizeDown,
    ResizeHandlePosition.bottomRight => SystemMouseCursors.resizeDownRight,
  };

  /// Whether this handle affects the width.
  bool get affectsWidth => switch (this) {
    ResizeHandlePosition.topCenter ||
    ResizeHandlePosition.bottomCenter => false,
    _ => true,
  };

  /// Whether this handle affects the height.
  bool get affectsHeight => switch (this) {
    ResizeHandlePosition.middleLeft ||
    ResizeHandlePosition.middleRight => false,
    _ => true,
  };

  /// Whether dragging right increases width (vs left handles decrease).
  int get widthDirection => switch (this) {
    ResizeHandlePosition.topLeft ||
    ResizeHandlePosition.middleLeft ||
    ResizeHandlePosition.bottomLeft => -1,
    _ => 1,
  };

  /// Whether dragging down increases height (vs top handles decrease).
  int get heightDirection => switch (this) {
    ResizeHandlePosition.topLeft ||
    ResizeHandlePosition.topCenter ||
    ResizeHandlePosition.topRight => -1,
    _ => 1,
  };
}

/// Resize handles displayed around a frame when in resize mode.
///
/// Shows 8 handles (corners + edge midpoints) that can be dragged to resize.
/// The frame maintains aspect ratio when shift is held during drag.
class FrameResizeHandles extends StatelessWidget {
  const FrameResizeHandles({
    super.key,
    required this.frameSize,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    this.minSize = const Size(100, 100),
    this.maxSize = const Size(5000, 5000),
    this.handleSize = 8.0,
    this.hitAreaSize = 16.0,
  });

  /// Current size of the frame.
  final Size frameSize;

  /// Called when a resize drag starts.
  final void Function(ResizeHandlePosition handle) onResizeStart;

  /// Called during resize drag with the new size.
  final void Function(Size newSize) onResizeUpdate;

  /// Called when resize drag ends.
  final VoidCallback onResizeEnd;

  /// Minimum allowed size.
  final Size minSize;

  /// Maximum allowed size.
  final Size maxSize;

  /// Visual size of the handle.
  final double handleSize;

  /// Hit area size for easier grabbing.
  final double hitAreaSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Frame outline
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.accent.purple.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // Resize handles
        for (final position in ResizeHandlePosition.values)
          _buildHandle(context, position),
      ],
    );
  }

  Widget _buildHandle(BuildContext context, ResizeHandlePosition position) {
    final colors = context.colors;

    // Calculate handle position
    final offset = _getHandleOffset(position);

    return Positioned(
      left: offset.dx - hitAreaSize / 2,
      top: offset.dy - hitAreaSize / 2,
      child: _ResizeHandle(
        position: position,
        frameSize: frameSize,
        minSize: minSize,
        maxSize: maxSize,
        handleSize: handleSize,
        hitAreaSize: hitAreaSize,
        handleColor: colors.accent.purple.primary,
        onResizeStart: () => onResizeStart(position),
        onResizeUpdate: onResizeUpdate,
        onResizeEnd: onResizeEnd,
      ),
    );
  }

  Offset _getHandleOffset(ResizeHandlePosition position) {
    return switch (position) {
      ResizeHandlePosition.topLeft => Offset.zero,
      ResizeHandlePosition.topCenter => Offset(frameSize.width / 2, 0),
      ResizeHandlePosition.topRight => Offset(frameSize.width, 0),
      ResizeHandlePosition.middleLeft => Offset(0, frameSize.height / 2),
      ResizeHandlePosition.middleRight => Offset(
        frameSize.width,
        frameSize.height / 2,
      ),
      ResizeHandlePosition.bottomLeft => Offset(0, frameSize.height),
      ResizeHandlePosition.bottomCenter => Offset(
        frameSize.width / 2,
        frameSize.height,
      ),
      ResizeHandlePosition.bottomRight => Offset(
        frameSize.width,
        frameSize.height,
      ),
    };
  }
}

/// Individual resize handle with drag behavior.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.position,
    required this.frameSize,
    required this.minSize,
    required this.maxSize,
    required this.handleSize,
    required this.hitAreaSize,
    required this.handleColor,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final ResizeHandlePosition position;
  final Size frameSize;
  final Size minSize;
  final Size maxSize;
  final double handleSize;
  final double hitAreaSize;
  final Color handleColor;
  final VoidCallback onResizeStart;
  final void Function(Size newSize) onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _isHovered = false;
  bool _isDragging = false;
  Offset? _dragStart;
  Size? _initialSize;

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStart = details.globalPosition;
      _initialSize = widget.frameSize;
    });
    widget.onResizeStart();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragStart == null || _initialSize == null) return;

    final delta = details.globalPosition - _dragStart!;
    final pos = widget.position;

    // Calculate new size based on handle position and drag delta
    var newWidth = _initialSize!.width;
    var newHeight = _initialSize!.height;

    if (pos.affectsWidth) {
      newWidth = _initialSize!.width + (delta.dx * pos.widthDirection);
    }
    if (pos.affectsHeight) {
      newHeight = _initialSize!.height + (delta.dy * pos.heightDirection);
    }

    // Clamp to min/max
    newWidth = newWidth.clamp(widget.minSize.width, widget.maxSize.width);
    newHeight = newHeight.clamp(widget.minSize.height, widget.maxSize.height);

    // Round to integers for clean pixel values
    newWidth = newWidth.roundToDouble();
    newHeight = newHeight.roundToDouble();

    widget.onResizeUpdate(Size(newWidth, newHeight));
  }

  void _handleDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _dragStart = null;
      _initialSize = null;
    });
    widget.onResizeEnd();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _isHovered || _isDragging;

    return MouseRegion(
      cursor: widget.position.cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onPanStart: _handleDragStart,
        onPanUpdate: _handleDragUpdate,
        onPanEnd: _handleDragEnd,
        child: SizedBox(
          width: widget.hitAreaSize,
          height: widget.hitAreaSize,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: isActive ? widget.handleSize + 2 : widget.handleSize,
              height: isActive ? widget.handleSize + 2 : widget.handleSize,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: widget.handleColor,
                  width: isActive ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A visual-only frame label displayed above the frame in edit mode.
///
/// Shows the device icon and name, styled like Figma's frame labels.
/// Click handling is done at the canvas level via hit-testing for instant response.
class FrameLabel extends StatefulWidget {
  const FrameLabel({
    super.key,
    required this.name,
    required this.icon,
    required this.isResizeMode,
    this.dimensionsLabel,
  });

  /// The frame/page name.
  final String name;

  /// The device icon.
  final IconData icon;

  /// Whether currently in resize mode.
  final bool isResizeMode;

  /// Optional dimensions label (e.g., "440×956").
  final String? dimensionsLabel;

  @override
  State<FrameLabel> createState() => _FrameLabelState();
}

class _FrameLabelState extends State<FrameLabel> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isHighlighted = _isHovered || widget.isResizeMode;
    final labelColor = isHighlighted
        ? colors.accent.purple.primary
        : colors.foreground.muted;

    // MouseRegion for hover feedback and cursor, IgnorePointer lets canvas handle taps
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: IgnorePointer(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 11, color: labelColor),
            const SizedBox(width: 4),
            Text(
              widget.name,
              style: context.typography.body.small.copyWith(
                color: labelColor,
                fontSize: 11,
              ),
            ),
            if (widget.dimensionsLabel != null && widget.isResizeMode) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.overlay.overlay05,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  widget.dimensionsLabel!,
                  style: context.typography.body.small.copyWith(
                    color: colors.foreground.muted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
