import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';
import 'package:provider/provider.dart';

import '../canvas_state.dart';

/// A dropdown button that shows the current zoom level and provides zoom actions.
///
/// Menu includes:
/// - Preset zoom levels (25%, 50%, 100%, 200%)
/// - Fit to Screen (zoom to fit content)
/// - Re-Center (center content at current zoom)
/// - Reset View (re-center at 100%)
class ZoomMenuButton extends StatefulWidget {
  const ZoomMenuButton({super.key, required this.controller});

  /// The canvas controller to control zoom/pan.
  final InfiniteCanvasController controller;

  @override
  State<ZoomMenuButton> createState() => _ZoomMenuButtonState();
}

class _ZoomMenuButtonState extends State<ZoomMenuButton> {
  final _popoverController = HoloPopoverController();

  @override
  void dispose() {
    _popoverController.dispose();
    super.dispose();
  }

  bool _isZoomLevel(double target, double current) {
    return (current - target).abs() < 0.01;
  }

  void _setZoom(double zoom) {
    // Get the viewport center to zoom around it
    final viewportSize = widget.controller.viewportSize;
    if (viewportSize != null) {
      final center = Offset(viewportSize.width / 2, viewportSize.height / 2);
      widget.controller.setZoom(zoom, focalPointInView: center);
    } else {
      widget.controller.setZoom(zoom);
    }
    _popoverController.hide();
  }

  void _fitToScreen() {
    final canvasState = context.read<CanvasState>();
    // Get bounds of all frames
    final bounds = _getAllFramesBounds(canvasState);
    if (bounds != Rect.zero) {
      widget.controller.focusOn(
        bounds,
        padding: const EdgeInsets.all(100),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _popoverController.hide();
  }

  void _reCenter() {
    final canvasState = context.read<CanvasState>();
    // Center content at current zoom level
    final bounds = _getAllFramesBounds(canvasState);
    if (bounds != Rect.zero) {
      widget.controller.animateToCenterOn(
        bounds.center,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _popoverController.hide();
  }

  void _resetView() {
    final canvasState = context.read<CanvasState>();
    // Re-center content at 100% zoom
    final bounds = _getAllFramesBounds(canvasState);
    if (bounds != Rect.zero) {
      widget.controller.animateToCenterOn(
        bounds.center,
        zoom: 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    _popoverController.hide();
  }

  /// Get combined bounds of all frames in the canvas.
  Rect _getAllFramesBounds(CanvasState state) {
    if (state.document.frames.isEmpty) {
      return Rect.zero;
    }

    Rect? bounds;
    for (final frame in state.document.frames.values) {
      final frameBounds = frame.canvas.bounds;
      bounds = bounds?.expandToInclude(frameBounds) ?? frameBounds;
    }
    return bounds ?? Rect.zero;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, _popoverController]),
      builder: (context, _) {
        final zoomPercent = (widget.controller.zoom * 100).round();

        return HoloPopover(
          controller: _popoverController,
          anchor: HoloPopoverAnchor.bottomRight,
          offset: const Offset(0, 4),
          popoverBuilder: (context) => _buildMenu(context),
          child: HoloSelectTrigger(
            label: '$zoomPercent%',
            isOpen: _popoverController.isOpen,
            onTap: _popoverController.toggle,
          ),
        );
      },
    );
  }

  Widget _buildMenu(BuildContext context) {
    final currentZoom = widget.controller.zoom;

    return HoloMenu(
      width: 200,
      children: [
        // Zoom percentages
        HoloMenuItem(
          label: '25%',
          isSelected: _isZoomLevel(0.25, currentZoom),
          onTap: () => _setZoom(0.25),
        ),
        HoloMenuItem(
          label: '50%',
          isSelected: _isZoomLevel(0.5, currentZoom),
          onTap: () => _setZoom(0.5),
        ),
        HoloMenuItem(
          label: '100%',
          shortcut: '⌘0',
          isSelected: _isZoomLevel(1.0, currentZoom),
          onTap: () => _setZoom(1.0),
        ),
        HoloMenuItem(
          label: '200%',
          isSelected: _isZoomLevel(2.0, currentZoom),
          onTap: () => _setZoom(2.0),
        ),

        const HoloMenuDivider(),

        // Actions
        HoloMenuItem(
          label: 'Fit to Screen',
          shortcut: '⇧1',
          onTap: _fitToScreen,
        ),
        HoloMenuItem(label: 'Re-Center', onTap: _reCenter),
        HoloMenuItem(label: 'Reset View', shortcut: '⇧0', onTap: _resetView),
      ],
    );
  }
}
