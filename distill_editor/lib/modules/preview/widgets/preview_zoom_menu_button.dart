import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// A simplified zoom menu for the preview canvas.
///
/// Shows preset zoom levels and a "Fit to Screen" option that focuses
/// on the device bounds.
class PreviewZoomMenuButton extends StatefulWidget {
  const PreviewZoomMenuButton({
    super.key,
    required this.controller,
    required this.deviceBounds,
  });

  final InfiniteCanvasController controller;

  /// The bounds of the device frame to focus on for "Fit to Screen".
  final Rect deviceBounds;

  @override
  State<PreviewZoomMenuButton> createState() => _PreviewZoomMenuButtonState();
}

class _PreviewZoomMenuButtonState extends State<PreviewZoomMenuButton> {
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
    widget.controller.focusOn(
      widget.deviceBounds,
      padding: const EdgeInsets.all(80),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    _popoverController.hide();
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
      width: 180,
      children: [
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
        HoloMenuItem(
          label: 'Fit to Screen',
          shortcut: '⇧1',
          onTap: _fitToScreen,
        ),
      ],
    );
  }
}
