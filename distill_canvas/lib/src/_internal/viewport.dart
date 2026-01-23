import 'package:flutter/material.dart';

/// Internal viewport state and coordinate math.
///
/// This is the core coordinate transformation engine. It handles:
/// - Pan/zoom state
/// - World ↔ View coordinate conversion
/// - Transform matrix generation (cached for performance)
///
/// This class is internal to the package. External code interacts
/// with [InfiniteCanvasController] which wraps this.
///
/// Named `CanvasViewport` to avoid conflict with Flutter's [Viewport] widget.
class CanvasViewport {
  CanvasViewport({double zoom = 1.0, Offset pan = Offset.zero})
    : _zoom = zoom,
      _pan = pan;

  // Internal state with cache invalidation
  double _zoom;
  Offset _pan;
  Matrix4? _cachedTransform;

  /// Current zoom level (1.0 = 100%)
  double get zoom => _zoom;
  set zoom(double value) {
    if (_zoom != value) {
      _zoom = value;
      _cachedTransform = null;
    }
  }

  /// Current pan offset in view-space pixels.
  ///
  /// This represents where the world origin (0, 0) appears in view space.
  Offset get pan => _pan;
  set pan(Offset value) {
    if (_pan != value) {
      _pan = value;
      _cachedTransform = null;
    }
  }

  /// Combined transform matrix for rendering world-space content.
  ///
  /// Apply this to a Transform widget to render content in world space.
  ///
  /// The matrix is cached and only rebuilt when [zoom] or [pan] changes.
  Matrix4 get transform => _cachedTransform ??= _buildTransform();

  Matrix4 _buildTransform() {
    return Matrix4.identity()
      ..setTranslationRaw(_pan.dx, _pan.dy, 0)
      ..scaleByDouble(_zoom, _zoom, 1.0, 1.0);
  }

  /// Convert a point from view-space (screen) to world-space (canvas).
  ///
  /// Use this to interpret where a tap/click occurred in world coordinates.
  Offset viewToWorld(Offset viewPoint) {
    return (viewPoint - _pan) / _zoom;
  }

  /// Convert a point from world-space (canvas) to view-space (screen).
  ///
  /// Use this to position screen-space UI at a world location.
  Offset worldToView(Offset worldPoint) {
    return (worldPoint * _zoom) + _pan;
  }

  /// Convert a rect from view-space to world-space.
  Rect viewToWorldRect(Rect viewRect) {
    return Rect.fromLTWH(
      (viewRect.left - _pan.dx) / _zoom,
      (viewRect.top - _pan.dy) / _zoom,
      viewRect.width / _zoom,
      viewRect.height / _zoom,
    );
  }

  /// Convert a rect from world-space to view-space.
  Rect worldToViewRect(Rect worldRect) {
    return Rect.fromLTWH(
      worldRect.left * _zoom + _pan.dx,
      worldRect.top * _zoom + _pan.dy,
      worldRect.width * _zoom,
      worldRect.height * _zoom,
    );
  }

  /// Convert a size from world-space to view-space.
  Size worldToViewSize(Size worldSize) {
    return worldSize * _zoom;
  }

  /// Convert a size from view-space to world-space.
  Size viewToWorldSize(Size viewSize) {
    return viewSize / _zoom;
  }

  /// Create a copy with optional overrides.
  CanvasViewport copyWith({double? zoom, Offset? pan}) {
    return CanvasViewport(zoom: zoom ?? _zoom, pan: pan ?? _pan);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasViewport &&
          runtimeType == other.runtimeType &&
          _zoom == other._zoom &&
          _pan == other._pan;

  @override
  int get hashCode => Object.hash(_zoom, _pan);

  @override
  String toString() =>
      'CanvasViewport(zoom: ${_zoom.toStringAsFixed(2)}, pan: $_pan)';
}
