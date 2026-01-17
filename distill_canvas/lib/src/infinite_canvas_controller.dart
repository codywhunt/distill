import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '_internal/viewport.dart';
import 'canvas_physics_config.dart';
import 'initial_viewport.dart';
import 'zoom_level.dart';

/// Controls the viewport (pan/zoom) of an [InfiniteCanvas].
///
/// Create a controller and pass it to [InfiniteCanvas]. Use the controller
/// to programmatically pan, zoom, query visible bounds, and animate.
///
/// ```dart
/// final controller = InfiniteCanvasController();
///
/// // Query visible area for culling
/// final visible = controller.getVisibleWorldBounds(viewportSize);
/// final nodesToRender = allNodes.where((n) => visible.overlaps(n.bounds));
///
/// // Animate to fit content
/// await controller.animateToFit(contentBounds, padding: EdgeInsets.all(50));
/// ```
///
/// ## Motion State
///
/// Use [isPanning], [isZooming], and [isAnimating] to react to viewport motion:
///
/// ```dart
/// ValueListenableBuilder(
///   valueListenable: controller.isPanning,
///   builder: (_, panning, child) => panning
///     ? const SizedBox.shrink()  // Hide during pan
///     : child!,
///   child: ExpensiveOverlay(),
/// )
/// ```
///
/// Or use [isInMotionListenable] to react to any motion:
///
/// ```dart
/// ListenableBuilder(
///   listenable: controller.isInMotionListenable,
///   builder: (_, __) => controller.isInMotion
///     ? LowFidelity()
///     : HighFidelity(),
/// )
/// ```
///
/// ## Lifecycle
///
/// The controller can be used before being attached to a canvas. Once attached,
/// it will respect the physics configuration from the canvas. Call [dispose]
/// when done.
class InfiniteCanvasController extends ChangeNotifier {
  InfiniteCanvasController({
    double initialZoom = 1.0,
    Offset initialPan = Offset.zero,
  }) : _viewport = CanvasViewport(zoom: initialZoom, pan: initialPan) {
    // Listen for zoom gesture end to update zoom level
    _isZoomingNotifier.addListener(_onZoomingChanged);
  }

  final CanvasViewport _viewport;

  // Physics configuration (set when attached to canvas)
  CanvasPhysicsConfig _physics = CanvasPhysicsConfig.defaults;

  // Animation state
  TickerProvider? _vsync;
  AnimationController? _animationController;
  Completer<void>? _animationCompleter;

  // Attachment state
  bool _isAttached = false;

  //─────────────────────────────────────────────────────────────────────────────
  // Motion State (for LOD switching)
  //─────────────────────────────────────────────────────────────────────────────

  final ValueNotifier<bool> _isPanningNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isZoomingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isAnimatingNotifier = ValueNotifier(false);

  /// Whether the viewport is currently being panned by user gesture.
  ///
  /// Use this to switch to lightweight rendering during pan gestures:
  ///
  /// ```dart
  /// ValueListenableBuilder(
  ///   valueListenable: controller.isPanning,
  ///   builder: (_, panning, child) => panning
  ///     ? LightweightPreview()
  ///     : FullFidelityContent(),
  /// )
  /// ```
  ValueListenable<bool> get isPanning => _isPanningNotifier;

  /// Whether the viewport is currently being zoomed by user gesture.
  ///
  /// This reflects both trackpad pinch zoom and Cmd/Ctrl+scroll wheel zoom.
  ValueListenable<bool> get isZooming => _isZoomingNotifier;

  /// Whether the viewport is currently animating programmatically.
  ValueListenable<bool> get isAnimating => _isAnimatingNotifier;

  /// Combined listenable that notifies when any motion state changes.
  ///
  /// Use this to react to any viewport motion without managing three
  /// separate listeners:
  ///
  /// ```dart
  /// ListenableBuilder(
  ///   listenable: controller.isInMotionListenable,
  ///   builder: (_, __) => controller.isInMotion
  ///     ? LowFidelity()
  ///     : HighFidelity(),
  /// )
  /// ```
  late final Listenable isInMotionListenable = Listenable.merge([
    _isPanningNotifier,
    _isZoomingNotifier,
    _isAnimatingNotifier,
  ]);

  /// Whether the viewport is in motion (any of pan/zoom/animate).
  ///
  /// Convenience getter that combines all motion states.
  bool get isInMotion =>
      _isPanningNotifier.value ||
      _isZoomingNotifier.value ||
      _isAnimatingNotifier.value;

  //─────────────────────────────────────────────────────────────────────────────
  // Zoom Level (for LOD switching)
  //─────────────────────────────────────────────────────────────────────────────

  ZoomThresholds _zoomThresholds = const ZoomThresholds();
  final ValueNotifier<ZoomLevel> _zoomLevelNotifier = ValueNotifier(
    ZoomLevel.normal,
  );

  /// Current semantic zoom level for LOD switching.
  ///
  /// Only changes when crossing configured thresholds, with hysteresis
  /// to prevent flickering. Level changes are deferred during zoom gestures.
  ///
  /// Use with [ValueListenableBuilder] for efficient isolated rebuilds:
  ///
  /// ```dart
  /// ValueListenableBuilder<ZoomLevel>(
  ///   valueListenable: controller.zoomLevel,
  ///   builder: (context, level, _) => switch (level) {
  ///     ZoomLevel.overview => SimplifiedView(),
  ///     ZoomLevel.normal => NormalView(),
  ///     ZoomLevel.detail => DetailedView(),
  ///   },
  /// )
  /// ```
  ValueListenable<ZoomLevel> get zoomLevel => _zoomLevelNotifier;

  /// Current zoom level (convenience getter).
  ///
  /// For simple checks in builders that already rebuild with the controller:
  ///
  /// ```dart
  /// content: (ctx, ctrl) => ctrl.currentZoomLevel == ZoomLevel.detail
  ///   ? DetailedContent()
  ///   : NormalContent();
  /// ```
  ZoomLevel get currentZoomLevel => _zoomLevelNotifier.value;

  /// Configure zoom level thresholds.
  ///
  /// Call this to customize when zoom levels change:
  ///
  /// ```dart
  /// controller.setZoomThresholds(const ZoomThresholds(
  ///   overviewBelow: 0.25,  // Below 25% → overview
  ///   detailAbove: 3.0,     // Above 300% → detail
  ///   hysteresis: 0.05,     // 5% band to prevent flickering
  /// ));
  /// ```
  void setZoomThresholds(ZoomThresholds thresholds) {
    _zoomThresholds = thresholds;
    // Force recalculation with new thresholds (skip hysteresis)
    _zoomLevelNotifier.value = _calculateZoomLevel(zoom);
  }

  void _onZoomingChanged() {
    if (!_isZoomingNotifier.value) {
      // Zoom gesture ended - now evaluate level change
      _updateZoomLevel();
    }
  }

  void _updateZoomLevel({bool force = false}) {
    // Defer during gesture unless forced
    if (_isZoomingNotifier.value && !force) return;

    final newLevel = _calculateZoomLevel(zoom);
    if (newLevel != _zoomLevelNotifier.value && _shouldTransition(newLevel)) {
      _zoomLevelNotifier.value = newLevel;
    }
  }

  ZoomLevel _calculateZoomLevel(double zoom) {
    if (zoom < _zoomThresholds.overviewBelow) return ZoomLevel.overview;
    if (zoom > _zoomThresholds.detailAbove) return ZoomLevel.detail;
    return ZoomLevel.normal;
  }

  bool _shouldTransition(ZoomLevel newLevel) {
    final current = _zoomLevelNotifier.value;
    final h = _zoomThresholds.hysteresis;

    // Skip hysteresis for multi-level jumps (overview↔detail)
    if ((current == ZoomLevel.overview && newLevel == ZoomLevel.detail) ||
        (current == ZoomLevel.detail && newLevel == ZoomLevel.overview)) {
      return true;
    }

    return switch ((current, newLevel)) {
      // Must go below threshold - hysteresis to enter overview
      (ZoomLevel.normal, ZoomLevel.overview) =>
        zoom < _zoomThresholds.overviewBelow - h,
      // Must go above threshold + hysteresis to exit overview
      (ZoomLevel.overview, ZoomLevel.normal) =>
        zoom > _zoomThresholds.overviewBelow + h,
      // Must go above threshold + hysteresis to enter detail
      (ZoomLevel.normal, ZoomLevel.detail) =>
        zoom > _zoomThresholds.detailAbove + h,
      // Must go below threshold - hysteresis to exit detail
      (ZoomLevel.detail, ZoomLevel.normal) =>
        zoom < _zoomThresholds.detailAbove - h,
      // Same level - no transition needed
      _ => true,
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // Internal API (called by InfiniteCanvas widget - do not call directly)
  // ────────────────────────────────────────────────────────────────────────

  /// @nodoc
  void setIsPanning(bool value) {
    if (_isPanningNotifier.value != value) {
      _isPanningNotifier.value = value;
    }
  }

  /// @nodoc
  void setIsZooming(bool value) {
    if (_isZoomingNotifier.value != value) {
      _isZoomingNotifier.value = value;
    }
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Viewport State (read-only)
  //─────────────────────────────────────────────────────────────────────────────

  /// Current zoom level (1.0 = 100%).
  double get zoom => _viewport.zoom;

  /// Current pan offset in view-space pixels.
  Offset get pan => _viewport.pan;

  /// Combined transform matrix for rendering.
  ///
  /// Apply this to a Transform widget to render content in world space.
  Matrix4 get transform => _viewport.transform;

  /// Whether this controller is currently attached to a canvas.
  bool get isAttached => _isAttached;

  /// The current viewport size (set by the canvas on layout).
  ///
  /// Returns null if not yet attached or no layout has occurred.
  Size? get viewportSize => _lastKnownViewportSize;

  //─────────────────────────────────────────────────────────────────────────────
  // Coordinate Conversion
  //─────────────────────────────────────────────────────────────────────────────

  /// Convert a point from view-space (screen) to world-space (canvas).
  ///
  /// Use this to interpret where a tap/click occurred in world coordinates.
  Offset viewToWorld(Offset viewPoint) => _viewport.viewToWorld(viewPoint);

  /// Convert a point from world-space (canvas) to view-space (screen).
  ///
  /// Use this to position screen-space UI at a world location.
  Offset worldToView(Offset worldPoint) => _viewport.worldToView(worldPoint);

  /// Convert a rect from view-space to world-space.
  Rect viewToWorldRect(Rect viewRect) => _viewport.viewToWorldRect(viewRect);

  /// Convert a rect from world-space to view-space.
  Rect worldToViewRect(Rect worldRect) => _viewport.worldToViewRect(worldRect);

  /// Convert a delta/direction from world-space to view-space.
  ///
  /// Unlike [worldToView], this only applies scale, not translation.
  /// Use for sizing elements that should be zoom-independent.
  Offset worldToViewDelta(Offset worldDelta) => worldDelta * _viewport.zoom;

  /// Convert a delta/direction from view-space to world-space.
  ///
  /// Unlike [viewToWorld], this only applies scale, not translation.
  Offset viewToWorldDelta(Offset viewDelta) => viewDelta / _viewport.zoom;

  /// Convert a size from world-space to view-space.
  ///
  /// ```dart
  /// // A 100x100 world rect at 2x zoom = 200x200 screen pixels
  /// final screenSize = controller.worldToViewSize(Size(100, 100));
  /// ```
  Size worldToViewSize(Size worldSize) => _viewport.worldToViewSize(worldSize);

  /// Convert a size from view-space to world-space.
  ///
  /// ```dart
  /// // A resize handle that's always 8x8 screen pixels
  /// final handleWorldSize = controller.viewToWorldSize(Size(8, 8));
  /// ```
  Size viewToWorldSize(Size viewSize) => _viewport.viewToWorldSize(viewSize);

  //─────────────────────────────────────────────────────────────────────────────
  // Viewport Queries
  //─────────────────────────────────────────────────────────────────────────────

  /// Get the world-space rect currently visible in the viewport.
  ///
  /// Use this for culling: only render objects that overlap this rect.
  ///
  /// ```dart
  /// final visible = controller.getVisibleWorldBounds(viewportSize);
  /// final nodesToRender = allNodes.where((n) => visible.overlaps(n.bounds));
  /// ```
  Rect getVisibleWorldBounds(Size viewportSize) {
    return _viewport.viewToWorldRect(
      Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
    );
  }

  /// Filter items to only those visible in the current viewport.
  ///
  /// This is a convenience method that combines [getVisibleWorldBounds]
  /// with filtering. Use this for viewport culling:
  ///
  /// ```dart
  /// final visibleNodes = controller.cullToVisible(
  ///   allNodes,
  ///   (node) => node.bounds,
  ///   viewportSize,
  /// );
  /// ```
  ///
  /// For more control (e.g., adding margin or using spatial indices),
  /// use [getVisibleWorldBounds] directly.
  Iterable<T> cullToVisible<T>(
    Iterable<T> items,
    Rect Function(T item) getBounds,
    Size viewportSize,
  ) {
    final visible = getVisibleWorldBounds(viewportSize);
    return items.where((item) => visible.overlaps(getBounds(item)));
  }

  /// The center point of the visible viewport in world coordinates.
  ///
  /// Returns null if no viewport size is known yet (before first layout).
  /// Useful for centering operations or getting a reference point.
  Offset? get visibleWorldCenter {
    final size = _lastKnownViewportSize;
    if (size == null) return null;
    return viewToWorld(Offset(size.width / 2, size.height / 2));
  }

  /// Check if a world-space rect is at least partially visible.
  ///
  /// Returns true if unknown (no viewport size yet).
  bool isWorldRectVisible(Rect worldRect, {Size? viewportSize}) {
    final size = viewportSize ?? _lastKnownViewportSize;
    if (size == null) return true; // Assume visible if unknown
    return getVisibleWorldBounds(size).overlaps(worldRect);
  }

  /// Check if a world-space point is visible.
  ///
  /// Returns true if unknown (no viewport size yet).
  bool isWorldPointVisible(Offset worldPoint, {Size? viewportSize}) {
    final size = viewportSize ?? _lastKnownViewportSize;
    if (size == null) return true;
    return getVisibleWorldBounds(size).contains(worldPoint);
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Viewport Manipulation (Instant)
  //─────────────────────────────────────────────────────────────────────────────

  /// Pan the viewport by a delta in view-space pixels.
  void panBy(Offset viewDelta) {
    if (!viewDelta.isFinite || viewDelta == Offset.zero) return;

    final newPan = _clampPan(_viewport.pan + viewDelta);
    if (newPan == _viewport.pan) return; // At bounds - no change
    _viewport.pan = newPan;
    notifyListeners();
  }

  /// Set the pan offset directly.
  void setPan(Offset pan) {
    if (!pan.isFinite) return;

    final newPan = _clampPan(pan);
    if (newPan == _viewport.pan) return; // No change
    _viewport.pan = newPan;
    notifyListeners();
  }

  /// Zoom to a specific level, optionally anchored at a view-space point.
  ///
  /// If [focalPointInView] is provided, that point will remain stationary
  /// during the zoom (like zooming at the cursor position).
  void setZoom(double zoom, {Offset? focalPointInView}) {
    if (!zoom.isFinite || zoom <= 0) return;

    final clampedZoom = _physics.clampZoom(zoom);
    final oldZoom = _viewport.zoom;
    final oldPan = _viewport.pan;
    _applyZoom(clampedZoom, focalPointInView);
    // Check if anything actually changed
    if (_viewport.zoom == oldZoom && _viewport.pan == oldPan) return;
    notifyListeners();
    _updateZoomLevel();
  }

  /// Zoom by a factor (e.g., 1.2 = zoom in 20%), anchored at a point.
  ///
  /// If [focalPointInView] is provided, that point will remain stationary
  /// during the zoom.
  void zoomBy(double factor, {Offset? focalPointInView}) {
    if (!factor.isFinite || factor <= 0) return;

    final newZoom = _physics.clampZoom(_viewport.zoom * factor);
    final oldZoom = _viewport.zoom;
    final oldPan = _viewport.pan;
    _applyZoom(newZoom, focalPointInView);
    // Check if anything actually changed
    if (_viewport.zoom == oldZoom && _viewport.pan == oldPan) return;
    notifyListeners();
  }

  /// Reset zoom to 1.0 and pan to origin.
  void reset() {
    if (_viewport.zoom == 1.0 && _viewport.pan == Offset.zero)
      return; // Already at default
    _viewport.zoom = 1.0;
    _viewport.pan = Offset.zero;
    notifyListeners();
  }

  /// Zoom in by a factor (default 1.25 = 25% increase).
  ///
  /// Convenience wrapper around [zoomBy].
  void zoomIn({double factor = 1.25, Offset? focalPointInView}) {
    zoomBy(factor, focalPointInView: focalPointInView);
  }

  /// Zoom out by a factor (default 0.8 = 20% decrease).
  ///
  /// Convenience wrapper around [zoomBy].
  void zoomOut({double factor = 0.8, Offset? focalPointInView}) {
    zoomBy(factor, focalPointInView: focalPointInView);
  }

  /// Reset zoom to 100% (1.0) without changing pan.
  void resetZoom() {
    setZoom(1.0);
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Viewport Manipulation (Animated)
  //─────────────────────────────────────────────────────────────────────────────

  /// Animate to a specific pan and/or zoom.
  ///
  /// Returns a Future that completes when the animation finishes or is
  /// cancelled. If another animation is started, this one is cancelled.
  ///
  /// If the target pan would violate [CanvasPhysicsConfig.panBounds],
  /// the animation targets the closest valid pan position. The target is
  /// clamped once upfront, ensuring a smooth animation path.
  Future<void> animateTo({
    Offset? pan,
    double? zoom,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) async {
    final targetZoom = zoom != null ? _physics.clampZoom(zoom) : _viewport.zoom;

    // Clamp target pan at target zoom level (upfront, not per-frame)
    final size = _lastKnownViewportSize;
    final clampedPan =
        size != null
            ? _physics.clampPan(pan ?? _viewport.pan, targetZoom, size)
            : (pan ?? _viewport.pan);

    // Check if we're already at target
    final panDiff = (clampedPan - _viewport.pan).distance;
    final zoomDiff = (targetZoom - _viewport.zoom).abs();
    if (panDiff < 0.5 && zoomDiff < 0.001) {
      return; // Already there
    }

    // Can't animate without vsync
    if (_vsync == null) {
      _viewport.pan = clampedPan;
      _viewport.zoom = targetZoom;
      notifyListeners();
      return;
    }

    return _runAnimation(
      targetPan: clampedPan,
      targetZoom: targetZoom,
      duration: duration,
      curve: curve,
    );
  }

  /// Animate to fit a world-space rect in the viewport.
  ///
  /// The camera will zoom and pan so that [worldRect] is fully visible
  /// with the specified [padding].
  Future<void> animateToFit(
    Rect worldRect, {
    EdgeInsets padding = EdgeInsets.zero,
    Size? viewportSize,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) async {
    if (worldRect.isEmpty) return;

    // We need viewport size to calculate fit
    final size = viewportSize ?? _lastKnownViewportSize;
    if (size == null || size.isEmpty) return;

    final solution = _solveViewportFit(
      worldRect: worldRect,
      viewportSize: size,
      padding: padding,
    );

    return animateTo(
      pan: solution.pan,
      zoom: solution.zoom,
      duration: duration,
      curve: curve,
    );
  }

  /// Fit a world-space rect in the viewport immediately (no animation).
  ///
  /// If the calculated pan would violate [CanvasPhysicsConfig.panBounds],
  /// the viewport pans as close as possible while respecting bounds.
  void fitToRect(
    Rect worldRect, {
    EdgeInsets padding = EdgeInsets.zero,
    Size? viewportSize,
  }) {
    if (worldRect.isEmpty) return;

    final size = viewportSize ?? _lastKnownViewportSize;
    if (size == null || size.isEmpty) return;

    final solution = _solveViewportFit(
      worldRect: worldRect,
      viewportSize: size,
      padding: padding,
    );

    _viewport.zoom = solution.zoom;
    _viewport.pan = _clampPan(solution.pan);
    notifyListeners();
  }

  /// Cancel any in-progress animation.
  void cancelAnimations() {
    _animationController?.stop();
    _animationController?.dispose();
    _animationController = null;
    _animationCompleter?.complete();
    _animationCompleter = null;
    _isAnimatingNotifier.value = false;
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Semantic / High-Level API
  //─────────────────────────────────────────────────────────────────────────────

  /// Focus on a world-space rect, animating to fit it in view.
  ///
  /// This is a semantic alias for [animateToFit] that expresses intent:
  /// "I want to focus on this area of the canvas."
  ///
  /// ```dart
  /// // Focus on a node
  /// controller.focusOn(node.bounds);
  ///
  /// // Focus on all content
  /// controller.focusOn(allContentBounds, padding: EdgeInsets.all(50));
  /// ```
  Future<void> focusOn(
    Rect worldRect, {
    EdgeInsets padding = const EdgeInsets.all(50),
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return animateToFit(
      worldRect,
      padding: padding,
      duration: duration,
      curve: curve,
    );
  }

  /// Center the viewport on a world point without changing zoom.
  ///
  /// The [worldPoint] will appear at the center of the viewport.
  /// Optionally set a specific [zoom] level.
  ///
  /// If the requested center would violate [CanvasPhysicsConfig.panBounds],
  /// the viewport pans as close as possible while respecting bounds.
  ///
  /// ```dart
  /// // Center on a node
  /// controller.centerOn(node.bounds.center);
  ///
  /// // Center on origin at 100% zoom
  /// controller.centerOn(Offset.zero, zoom: 1.0);
  /// ```
  void centerOn(Offset worldPoint, {double? zoom}) {
    final size = _lastKnownViewportSize;
    if (size == null) return;

    final targetZoom = zoom != null ? _physics.clampZoom(zoom) : this.zoom;
    if (zoom != null) _viewport.zoom = targetZoom;

    final viewportCenter = Offset(size.width / 2, size.height / 2);
    final newPan = viewportCenter - (worldPoint * targetZoom);

    _viewport.pan = _clampPan(newPan);
    notifyListeners();
  }

  /// Animated version of [centerOn].
  ///
  /// Smoothly centers the viewport on [worldPoint].
  ///
  /// If the requested center would violate [CanvasPhysicsConfig.panBounds],
  /// the viewport animates as close as possible while respecting bounds.
  ///
  /// ```dart
  /// // Animate to center on content
  /// await controller.animateToCenterOn(allNodes.bounds.center);
  ///
  /// // Animate to center at 100% zoom
  /// await controller.animateToCenterOn(node.position, zoom: 1.0);
  /// ```
  Future<void> animateToCenterOn(
    Offset worldPoint, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    final size = _lastKnownViewportSize;
    if (size == null) return Future.value();

    final targetZoom = zoom != null ? _physics.clampZoom(zoom) : this.zoom;
    final viewportCenter = Offset(size.width / 2, size.height / 2);
    final newPan = viewportCenter - (worldPoint * targetZoom);

    // Clamp pan at target zoom level
    final clampedPan = _physics.clampPan(newPan, targetZoom, size);

    return animateTo(
      pan: clampedPan,
      zoom: zoom != null ? targetZoom : null,
      duration: duration,
      curve: curve,
    );
  }

  /// Pan the viewport (if needed) so that [worldRect] is visible.
  ///
  /// Unlike [focusOn] or [fitToRect], this does NOT change zoom—it only
  /// pans the minimum amount needed to bring the rect into view.
  ///
  /// Use this for:
  /// - Revealing a selected node without jarring zoom changes
  /// - Auto-scrolling during drag operations
  /// - Keyboard navigation between items
  ///
  /// ```dart
  /// void onWidgetTreeNodeSelected(WidgetNode node) {
  ///   setState(() => selectedNode = node);
  ///   controller.ensureVisible(node.bounds);
  /// }
  /// ```
  void ensureVisible(
    Rect worldRect, {
    EdgeInsets margin = const EdgeInsets.all(50),
  }) {
    final delta = _calculateEnsureVisibleDelta(worldRect, margin);
    if (delta != null) panBy(delta);
  }

  /// Animated version of [ensureVisible].
  ///
  /// Smoothly pans the viewport to reveal [worldRect] without changing zoom.
  Future<void> animateToEnsureVisible(
    Rect worldRect, {
    EdgeInsets margin = const EdgeInsets.all(50),
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeOut,
  }) async {
    final delta = _calculateEnsureVisibleDelta(worldRect, margin);
    if (delta != null) {
      return animateTo(pan: pan + delta, duration: duration, curve: curve);
    }
  }

  /// Calculate the pan delta needed to make [worldRect] visible.
  /// Returns null if already visible.
  Offset? _calculateEnsureVisibleDelta(Rect worldRect, EdgeInsets margin) {
    final size = _lastKnownViewportSize;
    if (size == null || worldRect.isEmpty) return null;

    final visibleWorld = getVisibleWorldBounds(size);

    // Apply margin (convert view-space margin to world-space)
    final marginWorld = EdgeInsets.fromLTRB(
      margin.left / zoom,
      margin.top / zoom,
      margin.right / zoom,
      margin.bottom / zoom,
    );

    final safeZone = Rect.fromLTRB(
      visibleWorld.left + marginWorld.left,
      visibleWorld.top + marginWorld.top,
      visibleWorld.right - marginWorld.right,
      visibleWorld.bottom - marginWorld.bottom,
    );

    // Already fully visible?
    if (safeZone.width > 0 &&
        safeZone.height > 0 &&
        safeZone.left <= worldRect.left &&
        safeZone.top <= worldRect.top &&
        safeZone.right >= worldRect.right &&
        safeZone.bottom >= worldRect.bottom) {
      return null;
    }

    // Calculate minimum pan delta in world space
    var dx = 0.0;
    var dy = 0.0;

    if (worldRect.left < safeZone.left) {
      dx = worldRect.left - safeZone.left;
    } else if (worldRect.right > safeZone.right) {
      dx = worldRect.right - safeZone.right;
    }

    if (worldRect.top < safeZone.top) {
      dy = worldRect.top - safeZone.top;
    } else if (worldRect.bottom > safeZone.bottom) {
      dy = worldRect.bottom - safeZone.bottom;
    }

    // Convert world delta to view delta
    return Offset(-dx * zoom, -dy * zoom);
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Internal: Attachment (called by InfiniteCanvas)
  //─────────────────────────────────────────────────────────────────────────────

  Size? _lastKnownViewportSize;

  /// @nodoc
  void attach({
    required TickerProvider vsync,
    required CanvasPhysicsConfig physics,
    required Size viewportSize,
    InitialViewportState? initialState,
  }) {
    cancelAnimations();
    _vsync = vsync;
    _physics = physics;
    _lastKnownViewportSize = viewportSize;
    _isAttached = true;

    // Apply initial viewport state if provided (first attach only)
    if (initialState != null) {
      _viewport.zoom = _physics.clampZoom(initialState.zoom);
      _viewport.pan = _clampPan(initialState.pan);
    } else {
      // Just apply physics constraints to current state
      _viewport.zoom = _physics.clampZoom(_viewport.zoom);
      _viewport.pan = _clampPan(_viewport.pan);
    }
  }

  /// @nodoc
  void detach() {
    cancelAnimations();
    _vsync = null;
    _isAttached = false;
    // Reset motion state
    _isPanningNotifier.value = false;
    _isZoomingNotifier.value = false;
    _isAnimatingNotifier.value = false;
  }

  /// @nodoc
  void updateViewportSize(Size size) {
    _lastKnownViewportSize = size;
    // Re-clamp pan in case viewport size change affects bounds constraint
    _viewport.pan = _clampPan(_viewport.pan);
  }

  /// @nodoc
  void updatePhysics(CanvasPhysicsConfig physics) {
    _physics = physics;
    _viewport.zoom = _physics.clampZoom(_viewport.zoom);
    _viewport.pan = _clampPan(_viewport.pan);
    notifyListeners();
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Internal: Helpers
  //─────────────────────────────────────────────────────────────────────────────

  /// Clamp pan to respect [CanvasPhysicsConfig.panBounds].
  Offset _clampPan(Offset pan) {
    final size = _lastKnownViewportSize;
    if (size == null) return pan;
    return _physics.clampPan(pan, _viewport.zoom, size);
  }

  /// Apply zoom while keeping a focal point stationary.
  void _applyZoom(double newZoom, Offset? focalPointInView) {
    if (focalPointInView != null) {
      // Keep the world point under the focal point stationary
      final worldPoint = _viewport.viewToWorld(focalPointInView);
      _viewport.zoom = newZoom;
      final newViewPoint = _viewport.worldToView(worldPoint);
      _viewport.pan = _clampPan(
        _viewport.pan + (focalPointInView - newViewPoint),
      );
    } else {
      _viewport.zoom = newZoom;
    }
  }

  /// Run an animation to target pan/zoom.
  Future<void> _runAnimation({
    required Offset targetPan,
    required double targetZoom,
    required Duration duration,
    required Curve curve,
  }) async {
    cancelAnimations();

    final startPan = _viewport.pan;
    final startZoom = _viewport.zoom;

    _animationController = AnimationController(
      duration: duration,
      vsync: _vsync!,
    );

    final animation = CurvedAnimation(
      parent: _animationController!,
      curve: curve,
    );

    _animationCompleter = Completer<void>();
    _isAnimatingNotifier.value = true;

    animation.addListener(() {
      final t = animation.value;
      _viewport.pan = Offset.lerp(startPan, targetPan, t)!;
      _viewport.zoom = startZoom + (targetZoom - startZoom) * t;
      notifyListeners();
    });

    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _isAnimatingNotifier.value = false;
        _animationCompleter?.complete();
        _animationCompleter = null;
        _updateZoomLevel(); // Update zoom level after animation completes
      }
    });

    unawaited(_animationController!.forward());
    await _animationCompleter?.future;
  }

  /// Solve for camera pan/zoom to fit a world rect in the viewport.
  ({Offset pan, double zoom}) _solveViewportFit({
    required Rect worldRect,
    required Size viewportSize,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    // Calculate available space after padding
    final availableWidth = viewportSize.width - padding.horizontal;
    final availableHeight = viewportSize.height - padding.vertical;

    if (availableWidth <= 0 || availableHeight <= 0) {
      return (pan: _viewport.pan, zoom: _viewport.zoom);
    }

    // Calculate zoom to fit
    final scaleX = availableWidth / worldRect.width;
    final scaleY = availableHeight / worldRect.height;
    final zoom = _physics.clampZoom(math.min(scaleX, scaleY));

    // Calculate content size in view space
    final contentViewSize = Size(
      worldRect.width * zoom,
      worldRect.height * zoom,
    );

    // Center content in available space
    final centerOffset = Offset(
      padding.left + (availableWidth - contentViewSize.width) / 2,
      padding.top + (availableHeight - contentViewSize.height) / 2,
    );

    // Calculate pan to position world rect at center
    final pan = centerOffset - (worldRect.topLeft * zoom);

    return (pan: pan, zoom: zoom);
  }

  //─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  //─────────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    cancelAnimations();
    _isZoomingNotifier.removeListener(_onZoomingChanged);
    _isPanningNotifier.dispose();
    _isZoomingNotifier.dispose();
    _isAnimatingNotifier.dispose();
    _zoomLevelNotifier.dispose();
    super.dispose();
  }
}
