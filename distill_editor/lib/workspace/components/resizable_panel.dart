import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// Position of the drag handle
enum DragHandlePosition { left, right }

/// A panel that can be resized by dragging a handle.
///
/// Performance optimized with local drag state to avoid provider spam.
/// Only notifies [onResize] at the end of the drag operation.
class ResizablePanel extends StatefulWidget {
  const ResizablePanel({
    super.key,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.child,
    required this.onResize,
    this.dragHandlePosition = DragHandlePosition.right,
    this.onResizeStart,
    this.onResizeEnd,
    this.defaultWidth,
  });

  final double width;
  final double minWidth;
  final double maxWidth;
  final Widget child;
  final ValueChanged<double> onResize;
  final DragHandlePosition dragHandlePosition;
  final VoidCallback? onResizeStart;
  final VoidCallback? onResizeEnd;
  final double? defaultWidth;

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
  bool _isHovering = false;
  bool _showHoverColor = false;
  bool _isDragging = false;

  /// Local width during drag (prevents provider spam)
  double? _dragWidth;

  /// Cursor X at drag start
  double? _dragStartCursorX;

  /// Width at drag start
  double? _dragStartWidth;

  /// Overlay to maintain resize cursor during drag
  OverlayEntry? _cursorOverlay;

  @override
  void didUpdateWidget(ResizablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear _dragWidth once provider has synchronized
    if (!_isDragging &&
        _dragWidth != null &&
        (widget.width - _dragWidth!).abs() < 0.5) {
      setState(() {
        _dragWidth = null;
      });
    }
  }

  @override
  void dispose() {
    _removeCursorOverlay();
    super.dispose();
  }

  void _showCursorOverlay() {
    _cursorOverlay = OverlayEntry(
      builder: (context) => MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(color: Colors.transparent),
      ),
    );
    Overlay.of(context).insert(_cursorOverlay!);
  }

  void _removeCursorOverlay() {
    _cursorOverlay?.remove();
    _cursorOverlay = null;
  }

  void _handleDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragStartCursorX = details.globalPosition.dx;
      _dragStartWidth = _dragWidth ?? widget.width;
      _dragWidth = _dragWidth ?? widget.width;
    });

    widget.onResizeStart?.call();
    _showCursorOverlay();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_dragStartCursorX == null || _dragStartWidth == null) return;

    // Pure delta calculation from drag start
    final cursorDelta = details.globalPosition.dx - _dragStartCursorX!;

    double newWidth;
    if (widget.dragHandlePosition == DragHandlePosition.right) {
      // Left-anchored: moving right edge
      newWidth = _dragStartWidth! + cursorDelta;
    } else {
      // Right-anchored: moving left edge (negative delta increases width)
      newWidth = _dragStartWidth! - cursorDelta;
    }

    newWidth = newWidth.clamp(widget.minWidth, widget.maxWidth);

    // Only update local state - no provider notification!
    setState(() {
      _dragWidth = newWidth;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _removeCursorOverlay();

    setState(() {
      _isDragging = false;
      _dragStartCursorX = null;
      _dragStartWidth = null;
    });

    // Notify provider only ONCE at end of drag
    if (_dragWidth != null) {
      widget.onResize(_dragWidth!);
    }

    widget.onResizeEnd?.call();
  }

  void _handleDoubleTap() {
    // Reset to default width or middle of min/max range
    final defaultWidth =
        widget.defaultWidth ?? (widget.minWidth + widget.maxWidth) / 2;

    setState(() {
      _dragWidth = defaultWidth;
    });

    widget.onResize(defaultWidth);
    widget.onResizeEnd?.call();
  }

  void _handleMouseEnter() {
    setState(() => _isHovering = true);

    // Delay showing hover color for polish
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _isHovering) {
        setState(() => _showHoverColor = true);
      }
    });
  }

  void _handleMouseExit() {
    setState(() {
      _isHovering = false;
      _showHoverColor = false;
    });
  }

  Widget _buildDragHandle(BuildContext context) {
    final isLeft = widget.dragHandlePosition == DragHandlePosition.left;
    final handleWidth = _isDragging ? 2.0 : 1.0;

    final handleColor = _isDragging
        ? context.colors.accent.purple.primary
        : (_showHoverColor
              ? context.colors.accent.purple.primary.withValues(alpha: 0.6)
              : Colors.transparent);

    return Positioned(
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onPanStart: _handleDragStart,
        onPanUpdate: _handleDragUpdate,
        onPanEnd: _handleDragEnd,
        onDoubleTap: _handleDoubleTap,
        child: MouseRegion(
          onEnter: (_) => _handleMouseEnter(),
          onExit: (_) => _handleMouseExit(),
          cursor: SystemMouseCursors.resizeColumn,
          child: SizedBox(
            width: 8, // Interaction area
            child: Align(
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(width: handleWidth, color: handleColor),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use local drag width during drag, provider width otherwise
    final currentWidth = _dragWidth ?? widget.width;

    return SizedBox(
      width: currentWidth,
      child: Stack(
        children: [
          // Panel content
          Positioned.fill(child: widget.child),

          // Drag handle
          _buildDragHandle(context),
        ],
      ),
    );
  }
}
