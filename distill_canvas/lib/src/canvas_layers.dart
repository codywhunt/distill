import 'package:flutter/material.dart';

import 'infinite_canvas_controller.dart';

/// Builder function for canvas layers.
///
/// Receives the build context and controller. Use the controller for:
/// - Coordinate conversion ([controller.worldToView], etc.)
/// - Querying visible bounds ([controller.getVisibleWorldBounds])
/// - Reading current zoom/pan state
typedef CanvasLayerBuilder =
    Widget Function(BuildContext context, InfiniteCanvasController controller);

/// Defines the rendering layers for an [InfiniteCanvas].
///
/// Layers render in this order (bottom to top):
/// 1. `background` - Grid, canvas color, etc. (transformed by camera)
/// 2. `content` - Your nodes, shapes, etc. (transformed by camera)
/// 3. `overlay` - Selection UI, HUD, tooltips (screen-space, NOT transformed)
/// 4. `debug` - Optional debugging layer
///
/// ## Transform Behavior
///
/// - **background** and **content** are rendered inside a Transform widget
///   that applies the camera matrix. Coordinates are in world-space.
///   Use [CanvasItem] to position children.
///
/// - **overlay** and **debug** are rendered in screen-space (NOT transformed).
///   Use [controller.worldToView] to position elements at world locations.
///
/// ## Example
///
/// ```dart
/// CanvasLayers(
///   background: (ctx, ctrl) => const GridBackground(),
///   content: (ctx, ctrl) {
///     final visible = ctrl.getVisibleWorldBounds(MediaQuery.sizeOf(ctx));
///     return Stack(
///       children: nodes
///         .where((n) => visible.overlaps(n.bounds))
///         .map((n) => CanvasItem(
///           position: n.position,
///           child: NodeWidget(n),
///         ))
///         .toList(),
///     );
///   },
///   overlay: (ctx, ctrl) => SelectionOverlay(controller: ctrl),
/// )
/// ```
class CanvasLayers {
  const CanvasLayers({
    this.background,
    required this.content,
    this.overlay,
    this.debug,
  });

  /// Background layer rendered in world-space (transformed by camera).
  ///
  /// Typically used for grids, canvas color, or decorative patterns.
  /// This layer renders below all content.
  final CanvasLayerBuilder? background;

  /// Main content layer rendered in world-space (transformed by camera).
  ///
  /// This is where your nodes, shapes, and interactive elements go.
  /// Use [CanvasItem] to position widgets at world coordinates.
  ///
  /// ## Performance Requirements
  ///
  /// **This callback is invoked on EVERY viewport change** (60+ fps during
  /// gestures). Implementations MUST be efficient:
  ///
  /// ### DO:
  /// - Use [controller.getVisibleWorldBounds] to cull off-screen items
  /// - Memoize expensive computations outside the builder
  /// - Use [ValueKey] on items for widget identity preservation
  /// - Check motion state for LOD rendering ([controller.isInMotionListenable])
  ///
  /// ### DON'T:
  /// - Rebuild entire item list on each call without culling
  /// - Perform O(n) operations on large collections every frame
  /// - Create new objects/closures unconditionally inside the builder
  ///
  /// ### Example (efficient implementation):
  /// ```dart
  /// content: (context, controller) {
  ///   final visible = controller.getVisibleWorldBounds(
  ///     MediaQuery.sizeOf(context),
  ///   );
  ///
  ///   // Cull items to visible bounds
  ///   final visibleItems = allItems.where(
  ///     (item) => visible.overlaps(item.bounds),
  ///   );
  ///
  ///   return Stack(
  ///     children: [
  ///       for (final item in visibleItems)
  ///         CanvasItem(
  ///           key: ValueKey(item.id),  // Preserve widget identity
  ///           position: item.position,
  ///           child: ItemWidget(item: item),
  ///         ),
  ///     ],
  ///   );
  /// }
  /// ```
  ///
  /// See the [Performance Guide](doc/performance.md) for detailed optimization
  /// patterns including LOD rendering, spatial indexing, and benchmarking.
  final CanvasLayerBuilder content;

  /// Overlay layer rendered in screen-space (NOT transformed).
  ///
  /// Use this for UI that should stay fixed on screen:
  /// - Selection rectangles and resize handles
  /// - Tooltips and labels
  /// - HUD elements
  ///
  /// To position overlay elements at world locations, use
  /// [controller.worldToView] to convert coordinates.
  final CanvasLayerBuilder? overlay;

  /// Debug layer for development visualization.
  ///
  /// Rendered last (on top of everything). Use for:
  /// - Viewport bounds visualization
  /// - Performance metrics
  /// - Coordinate debugging
  final CanvasLayerBuilder? debug;
}
