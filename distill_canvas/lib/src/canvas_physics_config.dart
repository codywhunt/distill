import 'dart:ui';

/// Configuration for viewport physics (zoom limits, pan bounds).
///
/// The controller automatically clamps all zoom and pan operations to respect
/// these limits. You never need to manually check bounds.
///
/// ```dart
/// InfiniteCanvas(
///   physicsConfig: CanvasPhysicsConfig(
///     minZoom: 0.5,
///     maxZoom: 4.0,
///     panBounds: Rect.fromLTWH(0, 0, 1000, 1000),
///   ),
/// )
/// ```
class CanvasPhysicsConfig {
  const CanvasPhysicsConfig({
    this.minZoom = 0.1,
    this.maxZoom = 10.0,
    this.panBounds,
  }) : assert(minZoom > 0, 'minZoom must be positive'),
       assert(maxZoom >= minZoom, 'maxZoom must be >= minZoom');

  /// Minimum zoom level (e.g., 0.1 = 10%).
  ///
  /// The viewport will not zoom out beyond this level.
  final double minZoom;

  /// Maximum zoom level (e.g., 10.0 = 1000%).
  ///
  /// The viewport will not zoom in beyond this level.
  final double maxZoom;

  /// World-space bounds that the viewport cannot leave.
  ///
  /// When set, the user cannot pan to see areas outside this rectangle.
  /// If the viewport is larger than bounds (at low zoom), content is centered.
  ///
  /// When null (default), the canvas is infinite and can be panned without
  /// limits.
  ///
  /// Note: When zooming near pan boundaries with a focal point, the focal
  /// point may drift as the viewport is constrained to stay within bounds.
  final Rect? panBounds;

  /// Clamp a zoom value to the configured limits.
  double clampZoom(double value) {
    return value.clamp(minZoom, maxZoom);
  }

  /// Clamp a pan offset so the viewport stays within [panBounds].
  ///
  /// If [panBounds] is null, returns [pan] unchanged.
  /// If the viewport is larger than bounds, content is centered.
  Offset clampPan(Offset pan, double zoom, Size viewportSize) {
    if (panBounds == null) return pan;

    // Calculate visible world rect dimensions at this zoom
    final visibleWidth = viewportSize.width / zoom;
    final visibleHeight = viewportSize.height / zoom;

    // Current visible world rect top-left (pan is in view-space)
    final visibleLeft = -pan.dx / zoom;
    final visibleTop = -pan.dy / zoom;

    var newLeft = visibleLeft;
    var newTop = visibleTop;

    // Handle case where viewport is larger than bounds: center content
    if (visibleWidth >= panBounds!.width) {
      newLeft = panBounds!.center.dx - visibleWidth / 2;
    } else {
      newLeft = newLeft.clamp(panBounds!.left, panBounds!.right - visibleWidth);
    }

    if (visibleHeight >= panBounds!.height) {
      newTop = panBounds!.center.dy - visibleHeight / 2;
    } else {
      newTop = newTop.clamp(panBounds!.top, panBounds!.bottom - visibleHeight);
    }

    // Convert back to pan offset (view-space)
    return Offset(-newLeft * zoom, -newTop * zoom);
  }

  /// Default configuration with generous limits.
  static const defaults = CanvasPhysicsConfig();

  /// Configuration for a tightly constrained canvas.
  static const constrained = CanvasPhysicsConfig(minZoom: 0.5, maxZoom: 2.0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasPhysicsConfig &&
          runtimeType == other.runtimeType &&
          minZoom == other.minZoom &&
          maxZoom == other.maxZoom &&
          panBounds == other.panBounds;

  @override
  int get hashCode => Object.hash(minZoom, maxZoom, panBounds);
}
