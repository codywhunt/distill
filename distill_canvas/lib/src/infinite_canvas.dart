import 'package:flutter/material.dart';

import '_internal/canvas_gesture_handler.dart';
import 'canvas_gesture_config.dart';
import 'canvas_layers.dart';
import 'canvas_momentum_config.dart';
import 'canvas_physics_config.dart';
import 'infinite_canvas_controller.dart';
import 'initial_viewport.dart';
import 'types/canvas_drag_details.dart';

/// An infinite pannable/zoomable canvas with layered rendering.
///
/// The canvas is a pure viewport — it does not manage objects, selection,
/// or any domain state. Use callbacks to handle gestures and implement
/// your own object management.
///
/// ## Basic Usage
///
/// ```dart
/// final controller = InfiniteCanvasController();
///
/// InfiniteCanvas(
///   controller: controller,
///   layers: CanvasLayers(
///     background: (ctx, ctrl) => const GridBackground(),
///     content: (ctx, ctrl) => MyNodesLayer(),
///   ),
///   onTapWorld: (worldPos) => handleTap(worldPos),
///   onDragUpdateWorld: (details) => moveSelectedNodes(details.worldDelta),
/// )
/// ```
///
/// ## Gestures
///
/// The canvas handles two categories of gestures:
///
/// **Viewport gestures** (configured via [gestureConfig]):
/// - Pan: drag on empty canvas, spacebar+drag, middle mouse drag
/// - Zoom: scroll wheel, trackpad pinch, Cmd/Ctrl+scroll
///
/// **Domain gestures** (enabled by providing callbacks):
/// - Tap, double-tap, long-press: reported in world coordinates
/// - Drag: start/update/end reported in world coordinates
/// - Hover: position reported in world coordinates
///
/// The canvas does NOT interpret what domain gestures mean — your app
/// decides (selection, movement, etc.)
class InfiniteCanvas extends StatefulWidget {
  const InfiniteCanvas({
    super.key,
    this.controller,
    required this.layers,
    this.gestureConfig = const CanvasGestureConfig(),
    this.physicsConfig = const CanvasPhysicsConfig(),
    this.momentumConfig = const CanvasMomentumConfig(),
    this.initialViewport = const InitialViewport.centerOrigin(),
    this.backgroundColor,
    this.onControllerReady,
    this.onViewportChanged,
    this.onViewportSizeChanged,
    // Domain gesture callbacks
    this.onTapWorld,
    this.onDoubleTapWorld,
    this.onLongPressWorld,
    this.onDragStartWorld,
    this.onDragUpdateWorld,
    this.onDragEndWorld,
    this.onHoverWorld,
    this.onHoverExitWorld,
    this.shouldHandleScroll,
  });

  //───────────────────────────────────────────────────────────────────────────
  // Core
  //───────────────────────────────────────────────────────────────────────────

  /// Controller for programmatic viewport manipulation.
  ///
  /// If null, an internal controller is created and exposed via
  /// [onControllerReady].
  final InfiniteCanvasController? controller;

  /// Layer configuration for rendering.
  final CanvasLayers layers;

  /// Configuration for viewport gesture behavior (pan/zoom).
  final CanvasGestureConfig gestureConfig;

  /// Configuration for viewport physics (zoom limits, bounds).
  final CanvasPhysicsConfig physicsConfig;

  /// Configuration for pan momentum and sensitivity.
  ///
  /// Controls trackpad pan sensitivity and momentum/inertia behavior.
  /// Use presets like [CanvasMomentumConfig.figmaLike] for common feels.
  ///
  /// ```dart
  /// InfiniteCanvas(
  ///   momentumConfig: CanvasMomentumConfig.figmaLike,
  ///   // ...
  /// )
  /// ```
  final CanvasMomentumConfig momentumConfig;

  /// How to position the viewport on first layout.
  ///
  /// This is applied once when the canvas first attaches. After that,
  /// use [controller] methods to manipulate the viewport.
  ///
  /// Common options:
  /// - [InitialViewport.topLeft] — Origin at top-left (default)
  /// - [InitialViewport.centerOrigin] — Origin centered
  /// - [InitialViewport.fitRect] — Fit specific bounds
  /// - [InitialViewport.fitContent] — Fit dynamic content
  /// - [InitialViewport.centerOn] — Center on a world point
  ///
  /// ```dart
  /// InfiniteCanvas(
  ///   initialViewport: InitialViewport.fitContent(
  ///     () => editorState.allNodesBounds,
  ///     fallback: InitialViewport.centerOrigin(),
  ///   ),
  ///   // ...
  /// )
  /// ```
  final InitialViewport initialViewport;

  /// Background color.
  ///
  /// If null, uses a transparent background.
  final Color? backgroundColor;

  //───────────────────────────────────────────────────────────────────────────
  // Lifecycle Callbacks
  //───────────────────────────────────────────────────────────────────────────

  /// Called when the controller is ready.
  ///
  /// Useful when using an internal controller (no [controller] provided).
  final void Function(InfiniteCanvasController controller)? onControllerReady;

  /// Called when the viewport changes due to user gestures (pan/zoom).
  ///
  /// This fires during mouse drag, scroll wheel, and trackpad gestures.
  /// It is batched via post-frame callback to avoid excessive rebuilds.
  ///
  /// **Note:** This does NOT fire for programmatic viewport changes via
  /// controller methods like [InfiniteCanvasController.animateTo] or
  /// [InfiniteCanvasController.centerOn]. To track all viewport changes
  /// (including programmatic ones), use `controller.addListener()` instead.
  final void Function(InfiniteCanvasController controller)? onViewportChanged;

  /// Called when the viewport size changes (e.g., window resize).
  ///
  /// Useful for recalculating hit-test regions or updating spatial indices.
  final void Function(Size viewportSize)? onViewportSizeChanged;

  //───────────────────────────────────────────────────────────────────────────
  // Domain Gesture Callbacks
  //
  // These report gestures in world coordinates. The canvas does NOT interpret
  // what these gestures mean — your app decides.
  //───────────────────────────────────────────────────────────────────────────

  /// Called when user taps on the canvas.
  ///
  /// Position is in world coordinates. Use for selection, context menus, etc.
  final void Function(Offset worldPosition)? onTapWorld;

  /// Called when user double-taps on the canvas.
  final void Function(Offset worldPosition)? onDoubleTapWorld;

  /// Called when user long-presses on the canvas.
  final void Function(Offset worldPosition)? onLongPressWorld;

  /// Called when a drag gesture starts.
  ///
  /// Use [details.worldPosition] for hit-testing to determine what's
  /// being dragged.
  final void Function(CanvasDragStartDetails details)? onDragStartWorld;

  /// Called when a drag gesture updates.
  ///
  /// Use [details.worldDelta] to move your selected objects.
  final void Function(CanvasDragUpdateDetails details)? onDragUpdateWorld;

  /// Called when a drag gesture ends.
  final void Function(CanvasDragEndDetails details)? onDragEndWorld;

  /// Called when pointer hovers over the canvas.
  ///
  /// Position is in world coordinates. Use for hover effects.
  final void Function(Offset worldPosition)? onHoverWorld;

  /// Called when pointer exits the canvas.
  final VoidCallback? onHoverExitWorld;

  /// Called to determine if the canvas should handle scroll events at a position.
  ///
  /// When provided, this callback is invoked before the canvas handles scroll
  /// events (for panning or zooming). If the callback returns `false`, the
  /// canvas will not register for the scroll event, allowing other widgets
  /// (like scrollable content inside canvas items) to handle it instead.
  ///
  /// The position is in view (screen) coordinates.
  ///
  /// Example: Allow scrolling inside interactive frames:
  /// ```dart
  /// InfiniteCanvas(
  ///   shouldHandleScroll: (viewPosition) {
  ///     final worldPos = controller.viewToWorld(viewPosition);
  ///     return !isOverInteractiveContent(worldPos);
  ///   },
  /// )
  /// ```
  final bool Function(Offset viewPosition)? shouldHandleScroll;

  @override
  State<InfiniteCanvas> createState() => _InfiniteCanvasState();
}

class _InfiniteCanvasState extends State<InfiniteCanvas>
    with TickerProviderStateMixin
    implements CanvasGestureDelegate {
  // Controller management
  InfiniteCanvasController? _internalController;

  @override
  InfiniteCanvasController get controller =>
      widget.controller ?? _internalController!;

  // Gesture handling (extracted)
  final FocusNode _focusNode = FocusNode();
  late final CanvasGestureHandler _gestureHandler;

  // Viewport change batching
  bool _viewportChangePending = false;

  // Track last viewport size for change detection
  Size? _lastViewportSize;

  @override
  void initState() {
    super.initState();
    _gestureHandler = CanvasGestureHandler(delegate: this, focusNode: _focusNode);
    _maybeCreateController();
  }

  //─────────────────────────────────────────────────────────────────────────────
  // CanvasGestureDelegate Implementation
  //─────────────────────────────────────────────────────────────────────────────

  @override
  CanvasGestureConfig get gestureConfig => widget.gestureConfig;

  @override
  CanvasMomentumConfig get momentumConfig => widget.momentumConfig;

  @override
  void Function(Offset worldPos)? get onTapWorld => widget.onTapWorld;

  @override
  void Function(Offset worldPos)? get onDoubleTapWorld => widget.onDoubleTapWorld;

  @override
  void Function(Offset worldPos)? get onLongPressWorld => widget.onLongPressWorld;

  @override
  void Function(CanvasDragStartDetails details)? get onDragStartWorld =>
      widget.onDragStartWorld;

  @override
  void Function(CanvasDragUpdateDetails details)? get onDragUpdateWorld =>
      widget.onDragUpdateWorld;

  @override
  void Function(CanvasDragEndDetails details)? get onDragEndWorld =>
      widget.onDragEndWorld;

  @override
  void Function(Offset worldPos)? get onHoverWorld => widget.onHoverWorld;

  @override
  VoidCallback? get onHoverExitWorld => widget.onHoverExitWorld;

  @override
  bool Function(Offset viewPosition)? get shouldHandleScroll =>
      widget.shouldHandleScroll;

  @override
  void notifyViewportChanged() => _notifyViewportChanged();

  void _maybeCreateController() {
    if (widget.controller == null && _internalController == null) {
      _internalController = InfiniteCanvasController();
    }
  }

  @override
  void didUpdateWidget(InfiniteCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle controller swap
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();

      if (oldWidget.controller == null) {
        _internalController?.dispose();
        _internalController = null;
      }

      _maybeCreateController();
    }

    // Handle physics config change
    if (oldWidget.physicsConfig != widget.physicsConfig) {
      controller.updatePhysics(widget.physicsConfig);
    }

    // Handle momentum config change
    if (oldWidget.momentumConfig != widget.momentumConfig) {
      controller.updateMomentumConfig(widget.momentumConfig);
    }
  }

  @override
  void dispose() {
    _gestureHandler.dispose();
    _focusNode.dispose();
    controller.detach();

    if (widget.controller == null) {
      _internalController?.dispose();
    }

    super.dispose();
  }

  //───────────────────────────────────────────────────────────────────────────
  // Build
  //───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        // Attach controller on first build
        if (!controller.isAttached) {
          // Calculate initial viewport state
          final initialState = widget.initialViewport.calculate(
            viewportSize,
            widget.physicsConfig,
          );

          controller.attach(
            vsync: this,
            physics: widget.physicsConfig,
            viewportSize: viewportSize,
            initialState: initialState,
          );
          controller.updateMomentumConfig(widget.momentumConfig);

          // Notify controller ready and viewport size
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (widget.controller == null && widget.onControllerReady != null) {
              widget.onControllerReady!(_internalController!);
            }
            _notifyViewportSizeChanged(viewportSize);
          });
        } else {
          controller.updateViewportSize(viewportSize);
          _notifyViewportSizeChanged(viewportSize);
        }

        return SizedBox.expand(
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _gestureHandler.handleKeyEvent,
            child: MouseRegion(
              cursor: _getCursor(),
              onHover: _gestureHandler.handleHover,
              onExit: _gestureHandler.handleHoverExit,
              child: Listener(
                onPointerDown: _gestureHandler.handlePointerDown,
                onPointerMove: _gestureHandler.handlePointerMove,
                onPointerUp: _gestureHandler.handlePointerUp,
                onPointerCancel: _gestureHandler.handlePointerCancel,
                onPointerPanZoomStart: _gestureHandler.handleTrackpadPanZoomStart,
                onPointerPanZoomUpdate: _gestureHandler.handleTrackpadPanZoomUpdate,
                onPointerPanZoomEnd: _gestureHandler.handleTrackpadPanZoomEnd,
                onPointerSignal: _gestureHandler.handlePointerSignal,
                child: GestureDetector(
                  onTapUp: _gestureHandler.handleTapUp,
                  onDoubleTapDown: _gestureHandler.handleDoubleTapDown,
                  onLongPressStart: _gestureHandler.handleLongPressStart,
                  behavior: HitTestBehavior.opaque,
                  child: _buildLayers(viewportSize),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayers(Size viewportSize) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ClipRect(
          child: Container(
            color: widget.backgroundColor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background layer (transformed)
                if (widget.layers.background != null)
                  _TransformedLayer(
                    transform: controller.transform,
                    child: widget.layers.background!(context, controller),
                  ),

                // Content layer (transformed)
                _TransformedLayer(
                  transform: controller.transform,
                  child: widget.layers.content(context, controller),
                ),

                // Overlay layer (screen-space, NOT transformed)
                if (widget.layers.overlay != null)
                  Positioned.fill(
                    child: widget.layers.overlay!(context, controller),
                  ),

                // Debug layer (screen-space)
                if (widget.layers.debug != null)
                  Positioned.fill(
                    child: widget.layers.debug!(context, controller),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  //───────────────────────────────────────────────────────────────────────────
  // Cursor
  //───────────────────────────────────────────────────────────────────────────

  MouseCursor _getCursor() {
    if (_gestureHandler.isPanning) return SystemMouseCursors.grabbing;
    if (_gestureHandler.isSpacePressed) return SystemMouseCursors.grab;
    if (_gestureHandler.isDragging) return SystemMouseCursors.grabbing;
    return SystemMouseCursors.basic;
  }

  //───────────────────────────────────────────────────────────────────────────
  // Viewport Change Notification (batched via post-frame callback)
  //───────────────────────────────────────────────────────────────────────────

  void _notifyViewportChanged() {
    if (widget.onViewportChanged == null) return;

    // Batch viewport change notifications to reduce rebuild jitter
    if (!_viewportChangePending) {
      _viewportChangePending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _viewportChangePending = false;
        widget.onViewportChanged?.call(controller);
      });
    }
  }

  void _notifyViewportSizeChanged(Size newSize) {
    if (_lastViewportSize != newSize) {
      _lastViewportSize = newSize;
      widget.onViewportSizeChanged?.call(newSize);
    }
  }
}

/// Internal widget that applies transform to world-space layers.
class _TransformedLayer extends StatelessWidget {
  const _TransformedLayer({required this.transform, required this.child});

  final Matrix4 transform;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform(
      transform: transform,
      transformHitTests: true,
      child: child,
    );
  }
}
