/// Semantic zoom levels for LOD (Level of Detail) switching.
///
/// Use these levels to adjust rendering complexity based on zoom:
/// - [overview]: Zoomed out far - show simplified content
/// - [normal]: Standard working zoom - full detail
/// - [detail]: Zoomed in close - show extra detail (pixel grids, etc.)
///
/// Example:
/// ```dart
/// switch (controller.currentZoomLevel) {
///   case ZoomLevel.overview:
///     return SimplifiedView();
///   case ZoomLevel.normal:
///     return NormalView();
///   case ZoomLevel.detail:
///     return DetailedView();
/// }
/// ```
enum ZoomLevel {
  /// Zoomed out far - show simplified/overview content.
  ///
  /// Active when zoom is below [ZoomThresholds.overviewBelow].
  overview,

  /// Normal working zoom - full detail.
  ///
  /// Active when zoom is between [ZoomThresholds.overviewBelow]
  /// and [ZoomThresholds.detailAbove].
  normal,

  /// Zoomed in close - show extra detail.
  ///
  /// Active when zoom is above [ZoomThresholds.detailAbove].
  detail,
}

/// Configuration for zoom level thresholds.
///
/// Defines the zoom values at which [ZoomLevel] transitions occur,
/// plus a hysteresis band to prevent flickering at boundaries.
///
/// Example:
/// ```dart
/// controller.setZoomThresholds(const ZoomThresholds(
///   overviewBelow: 0.25,  // Below 25% zoom → overview
///   detailAbove: 3.0,     // Above 300% zoom → detail
///   hysteresis: 0.05,     // 5% band to prevent flickering
/// ));
/// ```
///
/// ## Hysteresis
///
/// Without hysteresis, rapidly zooming around a threshold causes flickering
/// as the level oscillates. The hysteresis band creates a "dead zone":
///
/// ```
/// Zoom:    0.20 ──── 0.25 ──── 0.30 ──── 0.35
///                     │         │
///          OVERVIEW   │◄──band──►│  NORMAL
///                     │         │
///          Enter at 0.25        Exit at 0.30 (with hysteresis=0.05)
/// ```
///
/// To transition from normal→overview, zoom must go below `overviewBelow - hysteresis`.
/// To transition from overview→normal, zoom must go above `overviewBelow + hysteresis`.
class ZoomThresholds {
  /// Creates zoom level thresholds.
  ///
  /// - [overviewBelow]: Zoom level below which [ZoomLevel.overview] is active.
  /// - [detailAbove]: Zoom level above which [ZoomLevel.detail] is active.
  /// - [hysteresis]: Band width to prevent flickering at thresholds.
  const ZoomThresholds({
    this.overviewBelow = 0.3,
    this.detailAbove = 2.0,
    this.hysteresis = 0.05,
  });

  /// Zoom level below which [ZoomLevel.overview] is active.
  ///
  /// Default: 0.3 (30% zoom)
  final double overviewBelow;

  /// Zoom level above which [ZoomLevel.detail] is active.
  ///
  /// Default: 2.0 (200% zoom)
  final double detailAbove;

  /// Hysteresis band width to prevent flickering at thresholds.
  ///
  /// When transitioning between levels, the zoom must move past the
  /// threshold by this amount before the transition occurs.
  ///
  /// Default: 0.05 (5%)
  final double hysteresis;

  /// Thresholds that effectively disable zoom level switching.
  ///
  /// With these thresholds, [ZoomLevel.normal] is always active.
  static const none = ZoomThresholds(
    overviewBelow: 0,
    detailAbove: double.infinity,
  );
}
