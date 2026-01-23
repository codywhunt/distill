import 'package:flutter/material.dart';

import '../infinite_canvas_controller.dart';

/// Base class for widgets that render screen-space overlays on the canvas.
///
/// This widget handles the common boilerplate of listening to the controller
/// and providing the view bounds to subclasses. Subclasses implement
/// [buildOverlay] to render their content.
///
/// Example usage:
///
/// ```dart
/// class SelectionOverlay extends CanvasOverlayWidget {
///   const SelectionOverlay({super.key, required super.controller});
///
///   @override
///   Widget buildOverlay(BuildContext context, Rect viewBounds) {
///     final selection = getSelectionBounds();
///     if (selection == null) return const SizedBox.shrink();
///
///     // Convert world bounds to view coordinates
///     final viewRect = Rect.fromPoints(
///       controller.worldToView(selection.topLeft),
///       controller.worldToView(selection.bottomRight),
///     );
///
///     return CustomPaint(
///       painter: SelectionPainter(viewRect),
///       size: Size(viewBounds.width, viewBounds.height),
///     );
///   }
/// }
/// ```
///
/// Use in the overlay layer:
///
/// ```dart
/// InfiniteCanvas(
///   layers: CanvasLayers(
///     content: (ctx, ctrl) => MyContent(),
///     overlay: (ctx, ctrl) => SelectionOverlay(controller: ctrl),
///   ),
/// )
/// ```
abstract class CanvasOverlayWidget extends StatelessWidget {
  /// Creates an overlay widget bound to the given controller.
  const CanvasOverlayWidget({super.key, required this.controller});

  /// The canvas controller this overlay is bound to.
  final InfiniteCanvasController controller;

  /// Build the overlay content.
  ///
  /// Called whenever the controller notifies listeners (pan/zoom changes).
  /// The [viewBounds] parameter provides the current viewport rectangle
  /// in screen coordinates (always starting at origin).
  ///
  /// Return [SizedBox.shrink] if there's nothing to render.
  Widget buildOverlay(BuildContext context, Rect viewBounds);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final size = controller.viewportSize;
        if (size == null) return const SizedBox.shrink();
        return buildOverlay(
          context,
          Rect.fromLTWH(0, 0, size.width, size.height),
        );
      },
    );
  }
}
