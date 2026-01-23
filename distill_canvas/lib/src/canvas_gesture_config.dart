import 'dart:ui';

/// Configuration for viewport gesture behavior.
///
/// This configures which gestures the canvas responds to for viewport
/// manipulation (pan/zoom). It does NOT configure domain gestures like
/// tap/drag/hover — those are enabled by providing callbacks to [InfiniteCanvas].
///
/// ```dart
/// InfiniteCanvas(
///   gestureConfig: CanvasGestureConfig(
///     enablePan: true,
///     enableZoom: true,
///     enableSpacebarPan: true,
///   ),
///   // Domain gestures are enabled by providing callbacks:
///   onTapWorld: (pos) => handleTap(pos),
///   onDragUpdateWorld: (details) => moveNodes(details.worldDelta),
/// )
/// ```
///
/// ## Tap vs Double-Tap Latency
///
/// When both `onTapWorld` and `onDoubleTapWorld` are configured on the canvas,
/// there is an inherent **~300ms delay** before `onTapWorld` fires. This is
/// because Flutter's gesture system must wait to determine if a second tap
/// will follow.
///
/// ### Workarounds:
///
/// 1. **Use only onTapWorld**: If double-tap isn't needed, omit `onDoubleTapWorld`.
///    Taps will fire immediately.
///
/// 2. **Use raw pointer events**: Wrap canvas in [Listener] and handle
///    `onPointerDown` directly. Implement your own double-tap detection:
///    ```dart
///    Listener(
///      onPointerDown: (event) {
///        // Immediate response - implement custom double-tap timing
///      },
///      child: InfiniteCanvas(...),
///    )
///    ```
///
/// 3. **Accept the latency**: For many use cases, 300ms is acceptable.
///
/// See the [Gesture Guide](doc/gestures.md) for detailed workaround examples.
class CanvasGestureConfig {
  const CanvasGestureConfig({
    this.enablePan = true,
    this.enableZoom = true,
    this.enableSpacebarPan = true,
    this.enableMiddleMousePan = true,
    this.enableScrollPan = true,
    this.naturalScrolling = true,
    this.dragThreshold = 5.0,
    this.touchDragThreshold,
    this.hoverThrottleMs = 16,
  });

  /// Default multiplier applied to [dragThreshold] for touch/stylus input
  /// when [touchDragThreshold] is not explicitly set.
  static const double defaultTouchThresholdMultiplier = 1.5;

  /// Enable panning via drag on empty canvas or trackpad gestures.
  final bool enablePan;

  /// Enable zooming via scroll wheel, trackpad pinch, or Cmd/Ctrl+scroll.
  final bool enableZoom;

  /// Enable spacebar + drag to pan (Figma-style).
  ///
  /// When enabled, holding spacebar switches to pan mode regardless
  /// of what's under the cursor.
  final bool enableSpacebarPan;

  /// Enable middle mouse button drag to pan.
  final bool enableMiddleMousePan;

  /// Enable scroll wheel / trackpad scroll to pan the canvas.
  ///
  /// When true (default), scroll events pan the canvas.
  /// When false, scroll events are not consumed, allowing scrollable
  /// widgets inside [CanvasItem]s to work normally.
  ///
  /// Note: Cmd/Ctrl+scroll for zoom is controlled separately by [enableZoom].
  final bool enableScrollPan;

  /// Use natural (reversed) scroll direction for panning.
  ///
  /// When true (default), scrolling follows "natural" direction where content
  /// moves in the same direction as your fingers (like touching paper).
  /// This matches macOS default trackpad behavior.
  ///
  /// When false, uses traditional scroll direction where scrolling down
  /// moves content up (like a scroll bar).
  final bool naturalScrolling;

  /// Minimum distance in pixels before a pointer down becomes a drag (mouse).
  ///
  /// This prevents accidental drags when the user intends to tap.
  /// For touch and stylus input, see [touchDragThreshold].
  final double dragThreshold;

  /// Minimum distance in pixels before a pointer down becomes a drag (touch/stylus).
  ///
  /// Touch input is less precise than mouse, so a higher threshold helps
  /// prevent accidental drags. If null, defaults to
  /// `dragThreshold * defaultTouchThresholdMultiplier`.
  final double? touchDragThreshold;

  /// Minimum milliseconds between hover events.
  ///
  /// Throttling hover events reduces CPU/battery usage, especially
  /// on macOS trackpads which can fire 120+ events per second.
  /// Set to 0 to disable throttling.
  ///
  /// Default is 16ms (~60fps max).
  final int hoverThrottleMs;

  /// Get the drag threshold for a specific input type.
  ///
  /// Touch and stylus use [touchDragThreshold] (or [dragThreshold] *
  /// [defaultTouchThresholdMultiplier] if not set).
  /// Mouse and other inputs use [dragThreshold].
  double getDragThreshold(PointerDeviceKind? kind) {
    if (kind == PointerDeviceKind.touch || kind == PointerDeviceKind.stylus) {
      return touchDragThreshold ??
          dragThreshold * defaultTouchThresholdMultiplier;
    }
    return dragThreshold;
  }

  /// Preset: all viewport gestures enabled with default thresholds.
  static const all = CanvasGestureConfig();

  /// Preset: no viewport gestures (fully locked camera).
  ///
  /// The camera can still be manipulated programmatically via the controller.
  static const none = CanvasGestureConfig(
    enablePan: false,
    enableZoom: false,
    enableSpacebarPan: false,
    enableMiddleMousePan: false,
    enableScrollPan: false,
    naturalScrolling: true,
  );

  /// Preset: zoom only (no manual panning).
  static const zoomOnly = CanvasGestureConfig(
    enablePan: false,
    enableSpacebarPan: false,
    enableMiddleMousePan: false,
    enableScrollPan: false,
  );

  /// Preset: pan only (no zooming).
  static const panOnly = CanvasGestureConfig(
    enableZoom: false,
  );

  /// Create a copy with modified values.
  CanvasGestureConfig copyWith({
    bool? enablePan,
    bool? enableZoom,
    bool? enableSpacebarPan,
    bool? enableMiddleMousePan,
    bool? enableScrollPan,
    bool? naturalScrolling,
    double? dragThreshold,
    double? touchDragThreshold,
    int? hoverThrottleMs,
  }) {
    return CanvasGestureConfig(
      enablePan: enablePan ?? this.enablePan,
      enableZoom: enableZoom ?? this.enableZoom,
      enableSpacebarPan: enableSpacebarPan ?? this.enableSpacebarPan,
      enableMiddleMousePan: enableMiddleMousePan ?? this.enableMiddleMousePan,
      enableScrollPan: enableScrollPan ?? this.enableScrollPan,
      naturalScrolling: naturalScrolling ?? this.naturalScrolling,
      dragThreshold: dragThreshold ?? this.dragThreshold,
      touchDragThreshold: touchDragThreshold ?? this.touchDragThreshold,
      hoverThrottleMs: hoverThrottleMs ?? this.hoverThrottleMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasGestureConfig &&
          runtimeType == other.runtimeType &&
          enablePan == other.enablePan &&
          enableZoom == other.enableZoom &&
          enableSpacebarPan == other.enableSpacebarPan &&
          enableMiddleMousePan == other.enableMiddleMousePan &&
          enableScrollPan == other.enableScrollPan &&
          naturalScrolling == other.naturalScrolling &&
          dragThreshold == other.dragThreshold &&
          touchDragThreshold == other.touchDragThreshold &&
          hoverThrottleMs == other.hoverThrottleMs;

  @override
  int get hashCode => Object.hash(
    enablePan,
    enableZoom,
    enableSpacebarPan,
    enableMiddleMousePan,
    enableScrollPan,
    naturalScrolling,
    dragThreshold,
    touchDragThreshold,
    hoverThrottleMs,
  );
}
