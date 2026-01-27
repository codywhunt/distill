import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../canvas_constants.dart';
import '../canvas_gesture_config.dart';
import '../canvas_momentum_config.dart';
import '../infinite_canvas_controller.dart';
import '../types/canvas_drag_details.dart';

/// Interface for the widget state to provide data to the gesture handler.
///
/// This interface decouples gesture handling from the widget implementation,
/// allowing the handler to request state updates and access configuration
/// without knowing widget internals.
abstract interface class CanvasGestureDelegate {
  /// The canvas controller.
  InfiniteCanvasController get controller;

  /// Gesture configuration (pan/zoom options).
  CanvasGestureConfig get gestureConfig;

  /// Momentum configuration (sensitivity, friction).
  CanvasMomentumConfig get momentumConfig;

  /// Whether the widget is still mounted.
  bool get mounted;

  //─────────────────────────────────────────────────────────────────────────────
  // Domain Gesture Callbacks
  //─────────────────────────────────────────────────────────────────────────────

  void Function(Offset worldPos)? get onTapWorld;
  void Function(Offset worldPos)? get onDoubleTapWorld;
  void Function(Offset worldPos)? get onLongPressWorld;
  void Function(CanvasDragStartDetails details)? get onDragStartWorld;
  void Function(CanvasDragUpdateDetails details)? get onDragUpdateWorld;
  void Function(CanvasDragEndDetails details)? get onDragEndWorld;
  void Function(Offset worldPos)? get onHoverWorld;
  VoidCallback? get onHoverExitWorld;
  bool Function(Offset viewPosition)? get shouldHandleScroll;

  //─────────────────────────────────────────────────────────────────────────────
  // Widget State Updates
  //─────────────────────────────────────────────────────────────────────────────

  /// Request a state update (for cursor changes, etc.).
  void setState(VoidCallback fn);

  /// Notify that the viewport has changed (for callbacks).
  void notifyViewportChanged();
}

/// Handles all gesture input for the canvas widget.
///
/// This class encapsulates the complexity of input handling, including:
/// - Keyboard events (spacebar for pan mode)
/// - Mouse/touch pointer events (pan, drag)
/// - Trackpad gestures (pan/zoom with momentum)
/// - Scroll wheel (pan, zoom with Cmd/Ctrl)
/// - Tap/double-tap/long-press
/// - Hover (throttled)
///
/// The handler communicates with the widget through [CanvasGestureDelegate],
/// which allows the widget to remain simple while all gesture logic is
/// concentrated here.
class CanvasGestureHandler {
  CanvasGestureHandler({
    required CanvasGestureDelegate delegate,
    required FocusNode focusNode,
  }) : _delegate = delegate,
       _focusNode = focusNode;

  final CanvasGestureDelegate _delegate;
  final FocusNode _focusNode;

  //─────────────────────────────────────────────────────────────────────────────
  // Gesture State
  //─────────────────────────────────────────────────────────────────────────────

  // Keyboard state
  bool _isSpacePressed = false;

  // Pan state
  bool _isPanning = false;
  Offset? _lastPanPosition;

  // Drag state
  bool _isDragging = false;
  Offset? _lastDragView;
  VelocityTracker? _velocityTracker;

  // Potential drag state (before threshold exceeded)
  // This allows tap gestures to complete without interference
  Offset? _potentialDragStart;
  PointerDeviceKind? _potentialDragKind;
  Duration? _potentialDragTimestamp;

  // Trackpad pan/zoom state
  double _trackpadLastScale = 1.0;
  bool _isTrackpadZooming = false;

  // Filtered velocity tracking for momentum
  Offset _trackpadAccumulatedPan = Offset.zero;
  Duration _trackpadLastEventTime = Duration.zero;
  Offset _trackpadFilteredVelocity = Offset.zero;
  Offset _trackpadLastNonZeroVelocity = Offset.zero;

  // Track middle mouse to prevent tap on middle-click
  bool _wasMiddleMouseDown = false;

  // Scroll wheel zoom state (debounced)
  Timer? _scrollZoomTimer;

  // Hover throttling
  int? _lastHoverEpochMs;

  //─────────────────────────────────────────────────────────────────────────────
  // Public State (for cursor)
  //─────────────────────────────────────────────────────────────────────────────

  /// Whether spacebar is currently pressed (pan mode).
  bool get isSpacePressed => _isSpacePressed;

  /// Whether actively panning with mouse/touch.
  bool get isPanning => _isPanning;

  /// Whether actively dragging objects.
  bool get isDragging => _isDragging;

  //─────────────────────────────────────────────────────────────────────────────
  // Helpers
  //─────────────────────────────────────────────────────────────────────────────

  InfiniteCanvasController get _controller => _delegate.controller;
  CanvasGestureConfig get _gestureConfig => _delegate.gestureConfig;
  CanvasMomentumConfig get _momentumConfig => _delegate.momentumConfig;

  bool get _hasDragCallbacks =>
      _delegate.onDragStartWorld != null ||
      _delegate.onDragUpdateWorld != null ||
      _delegate.onDragEndWorld != null;

  //─────────────────────────────────────────────────────────────────────────────
  // Keyboard
  //─────────────────────────────────────────────────────────────────────────────

  /// Handle keyboard events for pan mode (spacebar).
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    // Don't handle space key when a text field has focus
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
        _isSpacePressed = true;
        _delegate.setState(() {});
        return KeyEventResult.handled;
      } else if (event is KeyUpEvent) {
        _isSpacePressed = false;
        _delegate.setState(() {});
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Hover (throttled)
  //─────────────────────────────────────────────────────────────────────────────

  /// Handle hover events (throttled to reduce battery drain).
  void handleHover(PointerHoverEvent event) {
    if (_delegate.onHoverWorld == null) return;

    // Throttle hover events (macOS trackpads can fire 120+ events/sec)
    final throttleMs = _gestureConfig.hoverThrottleMs;
    if (throttleMs > 0) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (_lastHoverEpochMs != null &&
          nowMs - _lastHoverEpochMs! < throttleMs) {
        return;
      }
      _lastHoverEpochMs = nowMs;
    }

    final worldPos = _controller.viewToWorld(event.localPosition);
    _delegate.onHoverWorld!(worldPos);
  }

  /// Handle hover exit.
  void handleHoverExit(PointerExitEvent event) {
    _lastHoverEpochMs = null;
    _delegate.onHoverExitWorld?.call();
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Tap / Double-tap / Long-press
  //─────────────────────────────────────────────────────────────────────────────

  /// Handle tap up.
  void handleTapUp(TapUpDetails details) {
    // Don't fire tap if middle mouse was used (that's for panning)
    if (_wasMiddleMouseDown) return;
    if (_delegate.onTapWorld == null) return;

    final worldPos = _controller.viewToWorld(details.localPosition);
    _delegate.onTapWorld!(worldPos);
  }

  /// Handle double tap.
  void handleDoubleTapDown(TapDownDetails details) {
    if (_delegate.onDoubleTapWorld == null) return;

    final worldPos = _controller.viewToWorld(details.localPosition);
    _delegate.onDoubleTapWorld!(worldPos);
  }

  /// Handle long press.
  void handleLongPressStart(LongPressStartDetails details) {
    if (_delegate.onLongPressWorld == null) return;

    final worldPos = _controller.viewToWorld(details.localPosition);
    _delegate.onLongPressWorld!(worldPos);
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Pointer Events (Pan / Drag)
  //─────────────────────────────────────────────────────────────────────────────

  /// Handle pointer down (start of pan or drag).
  void handlePointerDown(PointerDownEvent event) {
    _focusNode.requestFocus();

    _wasMiddleMouseDown = event.buttons == kMiddleMouseButton;

    // Check if this is a pan gesture
    final isPanGesture =
        _isSpacePressed ||
        (event.buttons == kMiddleMouseButton &&
            _gestureConfig.enableMiddleMousePan);

    if (isPanGesture && _gestureConfig.enablePan) {
      _isPanning = true;
      _delegate.setState(() {});
      _controller.setIsPanning(true);
      _lastPanPosition = event.localPosition;
      _controller.cancelAnimations();
      return;
    }

    // Store potential drag start (actual drag tracking begins on movement)
    // This allows tap gestures to complete without interference from early
    // drag state initialization.
    if (_hasDragCallbacks) {
      _potentialDragStart = event.localPosition;
      _potentialDragKind = event.kind;
      _potentialDragTimestamp = event.timeStamp;
    }
  }

  /// Handle pointer move (pan or drag update).
  void handlePointerMove(PointerMoveEvent event) {
    // Handle pan
    if (_isPanning && _lastPanPosition != null) {
      final delta = event.localPosition - _lastPanPosition!;
      _controller.panBy(delta);
      _lastPanPosition = event.localPosition;
      _delegate.notifyViewportChanged();
      return;
    }

    // Handle drag (lazily initialized when threshold exceeded)
    if (_potentialDragStart != null && _hasDragCallbacks) {
      if (!_isDragging) {
        // Check threshold before starting drag
        final threshold = _gestureConfig.getDragThreshold(_potentialDragKind);
        final distance = (event.localPosition - _potentialDragStart!).distance;
        if (distance > threshold) {
          // NOW initialize full drag tracking
          _isDragging = true;
          _lastDragView = _potentialDragStart;
          _velocityTracker = VelocityTracker.withKind(_potentialDragKind!);
          if (_potentialDragTimestamp != null) {
            _velocityTracker!.addPosition(
              _potentialDragTimestamp!,
              _potentialDragStart!,
            );
          }
          _delegate.setState(() {});

          // Fire drag start
          if (_delegate.onDragStartWorld != null) {
            _delegate.onDragStartWorld!(
              CanvasDragStartDetails(
                worldPosition: _controller.viewToWorld(_potentialDragStart!),
                viewPosition: _potentialDragStart!,
                kind: event.kind,
              ),
            );
          }
        }
      }

      if (_isDragging) {
        // Track velocity
        _velocityTracker?.addPosition(event.timeStamp, event.localPosition);

        if (_delegate.onDragUpdateWorld != null) {
          final viewDelta = event.localPosition - _lastDragView!;
          final worldDelta = viewDelta / _controller.zoom;

          _delegate.onDragUpdateWorld!(
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
  }

  /// Handle pointer up (end of pan or drag).
  void handlePointerUp(PointerUpEvent event) {
    final wasPanning = _isPanning;
    final wasDragging = _isDragging;

    // End pan
    if (wasPanning) {
      _isPanning = false;
      _delegate.setState(() {});
      _controller.setIsPanning(false);
      _lastPanPosition = null;
    }

    // End drag
    if (wasDragging && _delegate.onDragEndWorld != null) {
      // Get velocity from tracker
      final velocity = _velocityTracker?.getVelocity();
      final velocityPixels = velocity?.pixelsPerSecond ?? Offset.zero;

      _delegate.onDragEndWorld!(
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

  /// Handle pointer cancel.
  void handlePointerCancel(PointerCancelEvent event) {
    _isPanning = false;
    _lastPanPosition = null;
    _delegate.setState(() {});
    _controller.setIsPanning(false);
    _resetDragState();
    _wasMiddleMouseDown = false;
  }

  void _resetDragState() {
    if (_isDragging) {
      _isDragging = false;
      _delegate.setState(() {});
    }
    _lastDragView = null;
    _velocityTracker = null;

    // Clear potential drag state (allows tap gestures to complete)
    _potentialDragStart = null;
    _potentialDragKind = null;
    _potentialDragTimestamp = null;
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Trackpad Pan/Zoom
  //─────────────────────────────────────────────────────────────────────────────

  /// Handle trackpad pan/zoom start.
  void handleTrackpadPanZoomStart(PointerPanZoomStartEvent event) {
    _trackpadLastScale = 1.0;
    _controller.cancelAnimations();

    // Initialize filtered velocity tracking for momentum
    if (_momentumConfig.enableMomentum) {
      _trackpadAccumulatedPan = Offset.zero;
      _trackpadLastEventTime = event.timeStamp;
      _trackpadFilteredVelocity = Offset.zero;
      _trackpadLastNonZeroVelocity = Offset.zero;
    }
  }

  /// Handle trackpad pan/zoom update.
  void handleTrackpadPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    // Compute scaled delta (this is what the user "feels")
    final sign = _gestureConfig.naturalScrolling ? 1.0 : -1.0;
    final sensitivity = _momentumConfig.panSensitivity;
    final scaledDelta = event.localPanDelta * sign * sensitivity;

    // Track filtered velocity for momentum using the SCALED delta
    if (_momentumConfig.enableMomentum) {
      final rawDt =
          (event.timeStamp - _trackpadLastEventTime).inMicroseconds / 1e6;
      _trackpadLastEventTime = event.timeStamp;

      _trackpadAccumulatedPan += scaledDelta;

      // Clamp dt to prevent velocity spikes from tiny/identical timestamps
      if (rawDt > 0 && scaledDelta.distance > CanvasConstants.velocityEpsilon) {
        final safeDt = rawDt.clamp(1 / 240.0, 1 / 30.0);
        final instantVelocity = scaledDelta / safeDt;

        // Apply low-pass filter for smooth velocity
        _trackpadFilteredVelocity = Offset(
          _trackpadFilteredVelocity.dx +
              (instantVelocity.dx - _trackpadFilteredVelocity.dx) *
                  CanvasConstants.velocityFilterAlpha,
          _trackpadFilteredVelocity.dy +
              (instantVelocity.dy - _trackpadFilteredVelocity.dy) *
                  CanvasConstants.velocityFilterAlpha,
        );

        // Remember last non-zero velocity for fallback direction
        if (_trackpadFilteredVelocity.distance >
            CanvasConstants.velocityEpsilon) {
          _trackpadLastNonZeroVelocity = _trackpadFilteredVelocity;
        }
      }
    }

    // Pan with sensitivity multiplier
    if (event.localPanDelta != Offset.zero && _gestureConfig.enablePan) {
      _controller.panBy(scaledDelta);
    }

    // Zoom
    if (_gestureConfig.enableZoom) {
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

    _delegate.notifyViewportChanged();
  }

  /// Handle trackpad pan/zoom end.
  void handleTrackpadPanZoomEnd(PointerPanZoomEndEvent event) {
    _trackpadLastScale = 1.0;
    if (_isTrackpadZooming) {
      _isTrackpadZooming = false;
      _controller.setIsZooming(false);
    }

    // Apply momentum if enabled and we panned
    if (_momentumConfig.enableMomentum && _gestureConfig.enablePan) {
      final hadPan = _trackpadAccumulatedPan.distance > 0.5;

      // Velocity is already scaled (sign * sensitivity baked in during update)
      var velocity = _trackpadFilteredVelocity;

      // If filtered velocity is tiny but we did pan, use last non-zero direction
      if (velocity.distance < CanvasConstants.velocityEpsilon && hadPan) {
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

  //─────────────────────────────────────────────────────────────────────────────
  // Scroll / Pinch Zoom
  //─────────────────────────────────────────────────────────────────────────────

  /// Handle pointer signal events (scroll wheel, pinch).
  void handlePointerSignal(PointerSignalEvent event) {
    // Handle browser/web pinch zoom
    if (event is PointerScaleEvent && _gestureConfig.enableZoom) {
      // Check if we should handle this scroll position
      if (_delegate.shouldHandleScroll != null &&
          !_delegate.shouldHandleScroll!(event.localPosition)) {
        return;
      }

      final factor = event.scale.clamp(0.2, 5.0);
      _controller.zoomBy(factor, focalPointInView: event.localPosition);
      _delegate.notifyViewportChanged();
      return;
    }

    if (event is PointerScrollEvent) {
      // Check if we should handle this scroll position
      if (_delegate.shouldHandleScroll != null &&
          !_delegate.shouldHandleScroll!(event.localPosition)) {
        return;
      }

      // Use PointerSignalResolver to properly compete for scroll events
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
        _gestureConfig.enableZoom) {
      final scrollAmount = event.scrollDelta.dy;
      final zoomFactor =
          1.0 - (scrollAmount * CanvasConstants.scrollZoomFactor);

      // Set zoom state (debounced clear after scroll stops)
      _controller.setIsZooming(true);
      _scrollZoomTimer?.cancel();
      _scrollZoomTimer = Timer(const Duration(milliseconds: 100), () {
        _controller.setIsZooming(false);
      });

      _controller.zoomBy(zoomFactor, focalPointInView: event.localPosition);
      _delegate.notifyViewportChanged();
      return;
    }

    // Regular scroll = Pan (only if scroll-pan is enabled)
    if (_gestureConfig.enableScrollPan) {
      final sign = _gestureConfig.naturalScrolling ? -1.0 : 1.0;
      final sensitivity = _momentumConfig.scrollSensitivity;

      // Shift+scroll converts vertical scroll to horizontal pan
      var dx = event.scrollDelta.dx;
      var dy = event.scrollDelta.dy;
      if (keyboard.isShiftPressed && dy != 0 && dx == 0) {
        dx = dy;
        dy = 0;
      }

      final panDelta = Offset(dx * sign * sensitivity, dy * sign * sensitivity);
      _controller.panBy(panDelta);
      _delegate.notifyViewportChanged();
    }
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  //─────────────────────────────────────────────────────────────────────────────

  /// Dispose resources.
  void dispose() {
    _scrollZoomTimer?.cancel();
  }
}
