import 'dart:ui' show Color, Size;

/// Configuration constants for storyboard layout.
class StoryboardConfig {
  StoryboardConfig._();

  // ─────────────────────────────────────────────────────────────────────────
  // Spacing
  // ─────────────────────────────────────────────────────────────────────────

  /// Horizontal gap between layers (columns).
  static const double layerSpacing = 800.0;

  /// Vertical gap between nodes within the same layer.
  static const double nodeSpacing = 600.0;

  /// Gap between main flowchart and orphan section.
  static const double orphanSpacing = 150.0;

  // ─────────────────────────────────────────────────────────────────────────
  // Connection Styling
  // ─────────────────────────────────────────────────────────────────────────

  /// Corner radius for orthogonal connection bends.
  static const double connectionRadius = 22.0;

  /// Stroke width for connection lines.
  static const double connectionStrokeWidth = 2.0;

  /// Default connection color (purple accent).
  static const Color connectionColor = Color(0xFF8B5CF6);

  /// Connection color when highlighted (selected page involved).
  static const Color connectionHighlightColor = Color(0xFFA78BFA);

  /// Arrow head size at connection endpoints.
  static const double arrowHeadSize = 22.0;

  /// Gap between page edge and connection start/end points.
  static const double connectionEdgeGap = 16.0;

  /// Radius of the circle dot at connection start points.
  static const double connectionStartDotRadius = 5.0;

  // ─────────────────────────────────────────────────────────────────────────
  // Node Dimensions
  // ─────────────────────────────────────────────────────────────────────────

  /// Default node size (iPhone dimensions).
  static const Size defaultNodeSize = Size(375, 812);
}
