import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    with TickerProviderStateMixin {
  // Controller management
  InfiniteCanvasController? _internalController;

  InfiniteCanvasController get _controller =>
      widget.controller ?? _internalController!;

  // Gesture state
  final FocusNode _focusNode = FocusNode();
  bool _isSpacePressed = false;
  bool _isPanning = false;
  Offset? _lastPanPosition;

  // Drag state
  bool _isDragging = false;
  Offset? _dragStartView;
  Offset? _lastDragView;
  VelocityTracker? _velocityTracker;
  PointerDeviceKind? _dragPointerKind;

  // Trackpad pan/zoom state
  double _trackpadLastScale = 1.0;
  bool _isTrackpadZooming = false;

  // Filtered velocity tracking for momentum (more reliable than VelocityTracker
  // for trackpad gestures, which often end with deceleration frames)
  Offset _trackpadAccumulatedPan = Offset.zero;
  Duration _trackpadLastEventTime = Duration.zero;
  Offset _trackpadFilteredVelocity = Offset.zero;
  Offset _trackpadLastNonZeroVelocity = Offset.zero;
  static const double _kVelocityAlpha = 0.25; // Low-pass filter smoothing
  static const double _kVelocityEpsilon = 0.001;

  // Track middle mouse to prevent tap on middle-click
  bool _wasMiddleMouseDown = false;

  // Scroll wheel zoom state (debounced)
  Timer? _scrollZoomTimer;

  // Hover throttling (reduces battery drain on trackpads)
  int? _lastHoverEpochMs;

  // Viewport change batching
  bool _viewportChangePending = false;

  // Track last viewport size for change detection
  Size? _lastViewportSize;

  @override
  void initState() {
    super.initState();
    _maybeCreateController();
  }

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
      _controller.updatePhysics(widget.physicsConfig);
    }

    // Handle momentum config change
    if (oldWidget.momentumConfig != widget.momentumConfig) {
      _controller.updateMomentumConfig(widget.momentumConfig);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollZoomTimer?.cancel();
    _controller.detach();

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
        if (!_controller.isAttached) {
          // Calculate initial viewport state
          final initialState = widget.initialViewport.calculate(
            viewportSize,
            widget.physicsConfig,
          );

          _controller.attach(
            vsync: this,
            physics: widget.physicsConfig,
            viewportSize: viewportSize,
            initialState: initialState,
          );
          _controller.updateMomentumConfig(widget.momentumConfig);

          // Notify controller ready and viewport size
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (widget.controller == null && widget.onControllerReady != null) {
              widget.onControllerReady!(_internalController!);
            }
            _notifyViewportSizeChanged(viewportSize);
          });
        } else {
          _controller.updateViewportSize(viewportSize);
          _notifyViewportSizeChanged(viewportSize);
        }

        return SizedBox.expand(
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: MouseRegion(
              cursor: _getCursor(),
              onHover: _handleHover,
              onExit: _handleHoverExit,
              child: Listener(
                onPointerDown: _handlePointerDown,
                onPointerMove: _handlePointerMove,
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerCancel,
                onPointerPanZoomStart: _handleTrackpadPanZoomStart,
                onPointerPanZoomUpdate: _handleTrackpadPanZoomUpdate,
                onPointerPanZoomEnd: _handleTrackpadPanZoomEnd,
                onPointerSignal: _handlePointerSignal,
                child: GestureDetector(
                  onTapUp: _handleTapUp,
                  onDoubleTapDown: _handleDoubleTapDown,
                  onLongPressStart: _handleLongPressStart,
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
      listenable: _controller,
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
                    transform: _controller.transform,
                    child: widget.layers.background!(context, _controller),
                  ),

                // Content layer (transformed)
                _TransformedLayer(
                  transform: _controller.transform,
                  child: widget.layers.content(context, _controller),
                ),

                // Overlay layer (screen-space, NOT transformed)
                if (widget.layers.overlay != null)
                  Positioned.fill(
                    child: widget.layers.overlay!(context, _controller),
                  ),

                // Debug layer (screen-space)
                if (widget.layers.debug != null)
                  Positioned.fill(
                    child: widget.layers.debug!(context, _controller),
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
    if (_isPanning) return SystemMouseCursors.grabbing;
    if (_isSpacePressed) return SystemMouseCursors.grab;
    if (_isDragging) return SystemMouseCursors.grabbing;
    return SystemMouseCursors.basic;
  }

  //───────────────────────────────────────────────────────────────────────────
  // Keyboard
  //───────────────────────────────────────────────────────────────────────────

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Don't handle space key when a text field has focus
    // This allows text input in overlays (like prompt boxes) to work properly
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus != node) {
      final focusContext = primaryFocus.context;
      if (focusContext != null) {
        final editableText =
            focusContext.findAncestorWidgetOfExactType<EditableText>();
        if (editableText != null) {
          return KeyEventResult.ignored;
        }
      }
    }

    // Track spacebar for pan mode
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent && !_isSpacePressed) {
        setState(() => _isSpacePressed = true);
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        setState(() => _isSpacePressed = false);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  //───────────────────────────────────────────────────────────────────────────
  // Hover (throttled to reduce battery drain on trackpads)
  //───────────────────────────────────────────────────────────────────────────

  void _handleHover(PointerHoverEvent event) {
    if (widget.onHoverWorld == null) return;

    // Throttle hover events (macOS trackpads can fire 120+ events/sec)
    final throttleMs = widget.gestureConfig.hoverThrottleMs;
    if (throttleMs > 0) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_lastHoverEpochMs != null &&
          nowMs - _lastHoverEpochMs! < throttleMs) {
        return;
      }
      _lastHoverEpochMs = nowMs;
    }

    final worldPos = _controller.viewToWorld(event.localPosition);
    widget.onHoverWorld!(worldPos);
  }

  void _handleHoverExit(PointerExitEvent event) {
    _lastHoverEpochMs = null;
    widget.onHoverExitWorld?.call();
  }

  //───────────────────────────────────────────────────────────────────────────
  // Tap / Double-tap / Long-press
  //───────────────────────────────────────────────────────────────────────────

  void _handleTapUp(TapUpDetails details) {
    // Don't fire tap if middle mouse was used (that's for panning)
    if (_wasMiddleMouseDown) return;

    if (widget.onTapWorld == null) return;

    final worldPos = _controller.viewToWorld(details.localPosition);
    widget.onTapWorld!(worldPos);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    if (widget.onDoubleTapWorld == null) return;

    final worldPos = _controller.viewToWorld(details.localPosition);
    widget.onDoubleTapWorld!(worldPos);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (widget.onLongPressWorld == null) return;

    final worldPos = _controller.viewToWorld(details.localPosition);
    widget.onLongPressWorld!(worldPos);
  }

  //───────────────────────────────────────────────────────────────────────────
  // Pointer Events (Pan / Drag)
  //───────────────────────────────────────────────────────────────────────────

  void _handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();

    _wasMiddleMouseDown = event.buttons == kMiddleMouseButton;

    // Check if this is a pan gesture
    final isPanGesture =
        _isSpacePressed ||
        (event.buttons == kMiddleMouseButton &&
            widget.gestureConfig.enableMiddleMousePan);

    if (isPanGesture && widget.gestureConfig.enablePan) {
      setState(() => _isPanning = true);
      _controller.setIsPanning(true);
      _lastPanPosition = event.localPosition;
      _controller.cancelAnimations();
      return;
    }

    // Otherwise, this might be a drag gesture
    if (_hasDragCallbacks) {
      _dragStartView = event.localPosition;
      _lastDragView = event.localPosition;
      _dragPointerKind = event.kind;
      // Initialize velocity tracker for drag end
      _velocityTracker = VelocityTracker.withKind(event.kind);
      _velocityTracker!.addPosition(event.timeStamp, event.localPosition);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Handle pan
    if (_isPanning && _lastPanPosition != null) {
      final delta = event.localPosition - _lastPanPosition!;
      _controller.panBy(delta);
      _lastPanPosition = event.localPosition;
      _notifyViewportChanged();
      return;
    }

    // Handle drag
    if (_dragStartView != null && _hasDragCallbacks) {
      // Track velocity
      _velocityTracker?.addPosition(event.timeStamp, event.localPosition);

      if (!_isDragging) {
        // Check threshold (determined at drag start based on input type)
        final threshold = widget.gestureConfig.getDragThreshold(
          _dragPointerKind,
        );
        final distance = (event.localPosition - _dragStartView!).distance;
        if (distance > threshold) {
          _isDragging = true;
          setState(() {});

          // Fire drag start
          if (widget.onDragStartWorld != null) {
            widget.onDragStartWorld!(
              CanvasDragStartDetails(
                worldPosition: _controller.viewToWorld(_dragStartView!),
                viewPosition: _dragStartView!,
                kind: event.kind,
              ),
            );
          }
        }
      }

      if (_isDragging && widget.onDragUpdateWorld != null) {
        final viewDelta = event.localPosition - _lastDragView!;
        final worldDelta = viewDelta / _controller.zoom;

        widget.onDragUpdateWorld!(
          CanvasDragUpdateDetails(
            worldPosition: _controller.viewToWorld(event.localPosition),
            worldDelta: worldDelta,
            viewPosition: event.localPosition,
            viewDelta: viewDelta,
          ),
        );

        _lastDragView = event.localPosition;
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final wasPanning = _isPanning;
    final wasDragging = _isDragging;

    // End pan
    if (wasPanning) {
      setState(() => _isPanning = false);
      _controller.setIsPanning(false);
      _lastPanPosition = null;
    }

    // End drag
    if (wasDragging && widget.onDragEndWorld != null) {
      // Get velocity from tracker
      final velocity = _velocityTracker?.getVelocity();
      final velocityPixels = velocity?.pixelsPerSecond ?? Offset.zero;

      widget.onDragEndWorld!(
        CanvasDragEndDetails(
          worldPosition: _controller.viewToWorld(event.localPosition),
          viewPosition: event.localPosition,
          velocity: velocityPixels,
        ),
      );
    }

    _resetDragState();
    _wasMiddleMouseDown = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    setState(() {
      _isPanning = false;
      _lastPanPosition = null;
    });
    _controller.setIsPanning(false);
    _resetDragState();
    _wasMiddleMouseDown = false;
  }

  void _resetDragState() {
    if (_isDragging) {
      setState(() => _isDragging = false);
    }
    _dragStartView = null;
    _lastDragView = null;
    _velocityTracker = null;
    _dragPointerKind = null;
  }

  bool get _hasDragCallbacks =>
      widget.onDragStartWorld != null ||
      widget.onDragUpdateWorld != null ||
      widget.onDragEndWorld != null;

  //───────────────────────────────────────────────────────────────────────────
  // Trackpad Pan/Zoom
  //───────────────────────────────────────────────────────────────────────────

  void _handleTrackpadPanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadLastScale = 1.0;
    _controller.cancelAnimations();

    // Initialize filtered velocity tracking for momentum
    if (widget.momentumConfig.enableMomentum) {
      _trackpadAccumulatedPan = Offset.zero;
      _trackpadLastEventTime = event.timeStamp;
      _trackpadFilteredVelocity = Offset.zero;
      _trackpadLastNonZeroVelocity = Offset.zero;
    }
  }

  void _handleTrackpadPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    // Compute scaled delta (this is what the user "feels")
    final sign = widget.gestureConfig.naturalScrolling ? 1.0 : -1.0;
    final sensitivity = widget.momentumConfig.panSensitivity;
    final scaledDelta = event.localPanDelta * sign * sensitivity;

    // Track filtered velocity for momentum using the SCALED delta
    // so momentum matches what the user felt during the gesture
    if (widget.momentumConfig.enableMomentum) {
      final rawDt =
          (event.timeStamp - _trackpadLastEventTime).inMicroseconds / 1e6;
      _trackpadLastEventTime = event.timeStamp;

      _trackpadAccumulatedPan += scaledDelta;

      // Clamp dt to prevent velocity spikes from tiny/identical timestamps
      if (rawDt > 0 && scaledDelta.distance > _kVelocityEpsilon) {
        final safeDt = rawDt.clamp(1 / 240.0, 1 / 30.0);
        final instantVelocity = scaledDelta / safeDt;

        // Apply low-pass filter for smooth velocity
        _trackpadFilteredVelocity = Offset(
          _trackpadFilteredVelocity.dx +
              (instantVelocity.dx - _trackpadFilteredVelocity.dx) *
                  _kVelocityAlpha,
          _trackpadFilteredVelocity.dy +
              (instantVelocity.dy - _trackpadFilteredVelocity.dy) *
                  _kVelocityAlpha,
        );

        // Remember last non-zero velocity for fallback direction
        if (_trackpadFilteredVelocity.distance > _kVelocityEpsilon) {
          _trackpadLastNonZeroVelocity = _trackpadFilteredVelocity;
        }
      }
    }

    // Pan with sensitivity multiplier
    if (event.localPanDelta != Offset.zero && widget.gestureConfig.enablePan) {
      _controller.panBy(scaledDelta);
      // Note: We don't set isPanning for trackpad pan since it's
      // a combined gesture and short-lived
    }

    // Zoom
    if (widget.gestureConfig.enableZoom) {
      final frameFactor = event.scale / _trackpadLastScale;
      if (frameFactor != 1.0) {
        if (!_isTrackpadZooming) {
          _isTrackpadZooming = true;
          _controller.setIsZooming(true);
        }
        _controller.zoomBy(frameFactor, focalPointInView: event.localPosition);
        _trackpadLastScale = event.scale;
      }
    }

    _notifyViewportChanged();
  }

  void _handleTrackpadPanZoomEnd(PointerPanZoomEndEvent event) {
    _trackpadLastScale = 1.0;
    if (_isTrackpadZooming) {
      _isTrackpadZooming = false;
      _controller.setIsZooming(false);
    }

    // Apply momentum if enabled and we panned
    if (widget.momentumConfig.enableMomentum && widget.gestureConfig.enablePan) {
      final hadPan = _trackpadAccumulatedPan.distance > 0.5;

      // Velocity is already scaled (sign * sensitivity baked in during update)
      var velocity = _trackpadFilteredVelocity;

      // If filtered velocity is tiny but we did pan, use last non-zero direction
      if (velocity.distance < _kVelocityEpsilon && hadPan) {
        velocity = _trackpadLastNonZeroVelocity;
      }

      _controller.startMomentumWithFloor(
        velocity,
        hadPan: hadPan,
        fallbackDirection: _trackpadLastNonZeroVelocity,
      );
    }

    // Reset tracking state
    _trackpadAccumulatedPan = Offset.zero;
    _trackpadFilteredVelocity = Offset.zero;
    _trackpadLastNonZeroVelocity = Offset.zero;
  }

  //───────────────────────────────────────────────────────────────────────────
  // Scroll / Pinch Zoom
  //───────────────────────────────────────────────────────────────────────────

  void _handlePointerSignal(PointerSignalEvent event) {
    // Handle browser/web pinch zoom
    if (event is PointerScaleEvent && widget.gestureConfig.enableZoom) {
      // Check if we should handle this scroll position
      if (widget.shouldHandleScroll != null &&
          !widget.shouldHandleScroll!(event.localPosition)) {
        return;
      }

      final factor = event.scale.clamp(0.2, 5.0);
      _controller.zoomBy(factor, focalPointInView: event.localPosition);
      _notifyViewportChanged();
      return;
    }

    if (event is PointerScrollEvent) {
      // Check if we should handle this scroll position
      if (widget.shouldHandleScroll != null &&
          !widget.shouldHandleScroll!(event.localPosition)) {
        return;
      }

      // Use PointerSignalResolver to properly compete for scroll events.
      // This ensures that if a scrollable widget inside the canvas wants
      // to handle the scroll, it wins (since it's deeper in the tree).
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        _handleScrollEvent,
      );
    }
  }

  /// Handle scroll event after winning the pointer signal resolution.
  void _handleScrollEvent(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final keyboard = HardwareKeyboard.instance;

    // Cmd/Ctrl + Scroll = Zoom
    if ((keyboard.isMetaPressed || keyboard.isControlPressed) &&
        widget.gestureConfig.enableZoom) {
      final scrollAmount = event.scrollDelta.dy;
      final zoomFactor = 1.0 - (scrollAmount * 0.002);

      // Set zoom state (debounced clear after scroll stops)
      _controller.setIsZooming(true);
      _scrollZoomTimer?.cancel();
      _scrollZoomTimer = Timer(const Duration(milliseconds: 100), () {
        _controller.setIsZooming(false);
      });

      _controller.zoomBy(zoomFactor, focalPointInView: event.localPosition);
      _notifyViewportChanged();
      return;
    }

    // Regular scroll = Pan (only if scroll-pan is enabled)
    if (widget.gestureConfig.enableScrollPan) {
      // Mouse wheel scrollDelta on macOS uses traditional direction (scroll down = positive dy).
      // Trackpad two-finger scroll uses PointerPanZoomUpdateEvent which respects OS natural scrolling.
      // To make mouse wheel feel consistent with trackpad natural scrolling, we invert it.
      // naturalScrolling=true: mouse wheel inverted (-1), trackpad handled by OS
      // naturalScrolling=false: mouse wheel normal (1), trackpad also uses -1 in its handler
      final sign = widget.gestureConfig.naturalScrolling ? -1.0 : 1.0;
      final sensitivity = widget.momentumConfig.scrollSensitivity;

      // Shift+scroll converts vertical scroll to horizontal pan.
      // macOS may or may not do this automatically depending on Flutter version,
      // so we handle it explicitly.
      var dx = event.scrollDelta.dx;
      var dy = event.scrollDelta.dy;
      if (keyboard.isShiftPressed && dy != 0 && dx == 0) {
        dx = dy;
        dy = 0;
      }

      final panDelta = Offset(
        dx * sign * sensitivity,
        dy * sign * sensitivity,
      );
      _controller.panBy(panDelta);
      _notifyViewportChanged();
    }
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
        widget.onViewportChanged?.call(_controller);
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
