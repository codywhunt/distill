/// Infinite Canvas - A pure viewport + gesture surface for Flutter.
///
/// This package provides a high-performance infinite canvas with pan/zoom
/// capabilities. It is deliberately minimal and domain-agnostic: it does not
/// manage objects, selection, or any application state.
///
/// The canvas reports gestures in world coordinates via callbacks. Your
/// application interprets what those gestures mean (selection, movement, etc.)
///
/// ## Quick Start
///
/// ```dart
/// final controller = InfiniteCanvasController();
///
/// InfiniteCanvas(
///   controller: controller,
///   layers: CanvasLayers(
///     background: (ctx, ctrl) => const GridBackground(),
///     content: (ctx, ctrl) => Stack(
///       children: myNodes.map((n) => CanvasItem(
///         position: n.position,
///         child: MyNodeWidget(n),
///       )).toList(),
///     ),
///   ),
///   onTapWorld: (worldPos) => handleTap(worldPos),
///   onDragUpdateWorld: (details) => moveNodes(details.worldDelta),
/// )
/// ```
///
/// ## Architecture
///
/// - **InfiniteCanvasController**: Controls the viewport (pan/zoom).
///   Query visible bounds, convert coordinates, animate camera.
///
/// - **InfiniteCanvas**: The widget. Handles gestures, renders layers,
///   reports world-space events via callbacks.
///
/// - **CanvasLayers**: Configures rendering order:
///   - `background`: Transformed by camera (grid, etc.)
///   - `content`: Transformed by camera (your nodes/shapes)
///   - `overlay`: Screen-space (selection UI, HUD)
///   - `debug`: Optional debugging layer
///
/// ## Design Philosophy
///
/// The canvas is a **viewport + gesture surface**. Nothing more.
///
/// Handles:
/// - Camera/viewport math
/// - Pan/zoom gestures
/// - Layered rendering surfaces
/// - World-coordinate event reporting
///
/// Does NOT handle (your app does this):
/// - Object/node management
/// - Selection state
/// - Hit-testing
library;

export 'src/canvas_gesture_config.dart';
export 'src/canvas_layers.dart';
export 'src/canvas_momentum_config.dart';
export 'src/canvas_physics_config.dart';
export 'src/infinite_canvas.dart';
export 'src/infinite_canvas_controller.dart';
export 'src/initial_viewport.dart';
export 'src/types/canvas_drag_details.dart';
export 'src/widgets/canvas_item.dart';
export 'src/widgets/canvas_overlay_widget.dart';
export 'src/widgets/grid_background.dart';
export 'src/zoom_level.dart';
