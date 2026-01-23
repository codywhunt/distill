/// Canvas-wide numeric constants extracted for maintainability.
///
/// These values were previously magic numbers scattered across the codebase.
/// Centralizing them allows easier tuning and documentation of their purpose.
///
/// These are implementation details, not intended for external configuration.
/// Users configure behavior via [CanvasGestureConfig], [CanvasMomentumConfig], etc.
abstract final class CanvasConstants {
  //───────────────────────────────────────────────────────────────────────────
  // Velocity Filtering (trackpad momentum)
  //───────────────────────────────────────────────────────────────────────────

  /// Low-pass filter alpha for smoothing trackpad velocity.
  ///
  /// The filtered velocity is computed as:
  /// `filtered = alpha * raw + (1 - alpha) * previous`
  ///
  /// Lower values = more smoothing but more lag.
  /// Current: 0.25 (25% new value, 75% previous)
  static const double velocityFilterAlpha = 0.25;

  /// Epsilon threshold below which velocity is considered zero.
  ///
  /// Prevents jitter from tiny floating-point deltas during
  /// trackpad momentum calculations.
  static const double velocityEpsilon = 0.001;

  //───────────────────────────────────────────────────────────────────────────
  // Scroll Wheel Zoom
  //───────────────────────────────────────────────────────────────────────────

  /// Factor to convert scroll delta to zoom factor.
  ///
  /// The zoom factor is computed as: `1.0 - (scrollDelta * scrollZoomFactor)`
  ///
  /// Higher values = faster zoom response to scroll wheel.
  static const double scrollZoomFactor = 0.002;

  //───────────────────────────────────────────────────────────────────────────
  // Snap Guide Rendering
  //───────────────────────────────────────────────────────────────────────────

  /// Dash length for center-aligned snap guide lines.
  ///
  /// Center guides use dashed lines to distinguish them from edge guides.
  static const double snapGuideDashLength = 5.0;

  /// Gap length between dashes for snap guide lines.
  static const double snapGuideGapLength = 3.0;

  /// Margin added to snap guide endpoints beyond the aligned bounds.
  ///
  /// This extends the guide lines slightly past the snapping objects
  /// for better visual clarity.
  static const double snapGuideMargin = 10.0;
}
