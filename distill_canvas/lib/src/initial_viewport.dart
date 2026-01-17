import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'canvas_physics_config.dart';

/// Strategy for initial viewport positioning when the canvas first loads.
///
/// This determines where the camera is positioned on first layout.
/// After initial positioning, use [InfiniteCanvasController] methods
/// to manipulate the viewport.
///
/// ## Built-in Strategies
///
/// - [InitialViewport.topLeft] — Origin at top-left (default)
/// - [InitialViewport.centerOrigin] — Origin centered in viewport
/// - [InitialViewport.centerOn] — Center on a specific world point
/// - [InitialViewport.fitRect] — Fit known bounds
/// - [InitialViewport.fitContent] — Fit dynamic content with fallback
///
/// ## Custom Strategies
///
/// Extend this class to create custom positioning logic:
///
/// ```dart
/// class RestoreLastViewport extends InitialViewport {
///   const RestoreLastViewport(this.savedPan, this.savedZoom);
///
///   final Offset savedPan;
///   final double savedZoom;
///
///   @override
///   InitialViewportState calculate(Size viewportSize, CanvasPhysicsConfig physics) {
///     return InitialViewportState(
///       pan: savedPan,
///       zoom: physics.clampZoom(savedZoom),
///     );
///   }
/// }
/// ```
///
/// ## Examples
///
/// ```dart
/// // Origin at top-left (default)
/// InfiniteCanvas(
///   initialViewport: InitialViewport.topLeft(),
/// )
///
/// // Origin centered in viewport
/// InfiniteCanvas(
///   initialViewport: InitialViewport.centerOrigin(),
/// )
///
/// // Fit to known bounds
/// InfiniteCanvas(
///   initialViewport: InitialViewport.fitRect(
///     contentBounds,
///     padding: EdgeInsets.all(50),
///   ),
/// )
///
/// // Fit to dynamic content
/// InfiniteCanvas(
///   initialViewport: InitialViewport.fitContent(
///     () => editorState.allNodesBounds,
///     fallback: InitialViewport.centerOrigin(),
///   ),
/// )
/// ```
abstract class InitialViewport {
  const InitialViewport();

  /// Origin (0,0) at top-left of viewport.
  ///
  /// This is the default behavior. World coordinates increase
  /// rightward (x) and downward (y) from the top-left corner.
  const factory InitialViewport.topLeft({double zoom}) = _TopLeftViewport;

  /// Origin (0,0) centered in viewport.
  ///
  /// Useful for canvases where content is positioned around the origin
  /// in all directions (positive and negative coordinates).
  const factory InitialViewport.centerOrigin({double zoom}) =
      _CenterOriginViewport;

  /// Center the viewport on a specific world point.
  ///
  /// The given [worldPoint] will appear at the center of the screen.
  const factory InitialViewport.centerOn(Offset worldPoint, {double zoom}) =
      _CenterOnViewport;

  /// Fit a specific world-space rect in the viewport.
  ///
  /// The camera will zoom and pan so that [rect] is fully visible
  /// with the specified [padding]. Use [minZoom] and [maxZoom] to
  /// constrain the calculated zoom level.
  const factory InitialViewport.fitRect(
    Rect rect, {
    EdgeInsets padding,
    double? minZoom,
    double? maxZoom,
  }) = _FitRectViewport;

  /// Fit content bounds provided by a callback.
  ///
  /// The [getBounds] callback is invoked during first layout to get
  /// the content bounds to fit. If it returns null or an empty rect,
  /// [fallback] is used instead.
  ///
  /// This is the most flexible option for editors where content
  /// may or may not exist at startup:
  ///
  /// ```dart
  /// InitialViewport.fitContent(
  ///   () => editorState.allNodesBounds,
  ///   fallback: InitialViewport.centerOrigin(),
  ///   padding: EdgeInsets.all(50),
  /// )
  /// ```
  const factory InitialViewport.fitContent(
    Rect? Function() getBounds, {
    EdgeInsets padding,
    double? minZoom,
    double? maxZoom,
    InitialViewport fallback,
  }) = _FitContentViewport;

  /// Calculate initial pan/zoom given viewport size and physics constraints.
  ///
  /// This is called once during initial layout. Implementations should
  /// return the desired pan and zoom values.
  InitialViewportState calculate(
    Size viewportSize,
    CanvasPhysicsConfig physics,
  );
}

/// The calculated initial viewport state.
class InitialViewportState {
  const InitialViewportState({required this.pan, required this.zoom});

  /// Initial pan offset (where world origin appears in view space).
  final Offset pan;

  /// Initial zoom level.
  final double zoom;

  @override
  String toString() => 'InitialViewportState(pan: $pan, zoom: $zoom)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Implementations
// ─────────────────────────────────────────────────────────────────────────────

class _TopLeftViewport extends InitialViewport {
  const _TopLeftViewport({this.zoom = 1.0});

  final double zoom;

  @override
  InitialViewportState calculate(
    Size viewportSize,
    CanvasPhysicsConfig physics,
  ) {
    return InitialViewportState(
      pan: Offset.zero,
      zoom: physics.clampZoom(zoom),
    );
  }
}

class _CenterOriginViewport extends InitialViewport {
  const _CenterOriginViewport({this.zoom = 1.0});

  final double zoom;

  @override
  InitialViewportState calculate(
    Size viewportSize,
    CanvasPhysicsConfig physics,
  ) {
    return InitialViewportState(
      pan: Offset(viewportSize.width / 2, viewportSize.height / 2),
      zoom: physics.clampZoom(zoom),
    );
  }
}

class _CenterOnViewport extends InitialViewport {
  const _CenterOnViewport(this.worldPoint, {this.zoom = 1.0});

  final Offset worldPoint;
  final double zoom;

  @override
  InitialViewportState calculate(
    Size viewportSize,
    CanvasPhysicsConfig physics,
  ) {
    final clampedZoom = physics.clampZoom(zoom);
    // Pan so that worldPoint appears at viewport center
    final viewportCenter = Offset(
      viewportSize.width / 2,
      viewportSize.height / 2,
    );
    final pan = viewportCenter - (worldPoint * clampedZoom);

    return InitialViewportState(pan: pan, zoom: clampedZoom);
  }
}

class _FitRectViewport extends InitialViewport {
  const _FitRectViewport(
    this.rect, {
    this.padding = const EdgeInsets.all(50),
    this.minZoom,
    this.maxZoom,
  });

  final Rect rect;
  final EdgeInsets padding;
  final double? minZoom;
  final double? maxZoom;

  @override
  InitialViewportState calculate(
    Size viewportSize,
    CanvasPhysicsConfig physics,
  ) {
    // Handle empty or invalid rect
    if (rect.isEmpty || !rect.isFinite) {
      return const _CenterOriginViewport().calculate(viewportSize, physics);
    }

    // Calculate available space after padding
    final availableWidth = viewportSize.width - padding.horizontal;
    final availableHeight = viewportSize.height - padding.vertical;

    if (availableWidth <= 0 || availableHeight <= 0) {
      return const InitialViewportState(pan: Offset.zero, zoom: 1.0);
    }

    // Calculate zoom to fit
    final scaleX = availableWidth / rect.width;
    final scaleY = availableHeight / rect.height;
    var zoom = math.min(scaleX, scaleY);

    // Apply zoom constraints
    zoom = physics.clampZoom(zoom);
    if (minZoom != null) zoom = math.max(zoom, minZoom!);
    if (maxZoom != null) zoom = math.min(zoom, maxZoom!);
    zoom = physics.clampZoom(zoom); // Re-clamp after our constraints

    // Calculate content size in view space
    final contentViewSize = Size(rect.width * zoom, rect.height * zoom);

    // Center content in available space
    final centerOffset = Offset(
      padding.left + (availableWidth - contentViewSize.width) / 2,
      padding.top + (availableHeight - contentViewSize.height) / 2,
    );

    // Calculate pan to position world rect at center
    final pan = centerOffset - (rect.topLeft * zoom);

    return InitialViewportState(pan: pan, zoom: zoom);
  }
}

class _FitContentViewport extends InitialViewport {
  const _FitContentViewport(
    this.getBounds, {
    this.padding = const EdgeInsets.all(50),
    this.minZoom,
    this.maxZoom,
    this.fallback = const _CenterOriginViewport(),
  });

  final Rect? Function() getBounds;
  final EdgeInsets padding;
  final double? minZoom;
  final double? maxZoom;
  final InitialViewport fallback;

  @override
  InitialViewportState calculate(
    Size viewportSize,
    CanvasPhysicsConfig physics,
  ) {
    final bounds = getBounds();

    if (bounds == null || bounds.isEmpty) {
      return fallback.calculate(viewportSize, physics);
    }

    return _FitRectViewport(
      bounds,
      padding: padding,
      minZoom: minZoom,
      maxZoom: maxZoom,
    ).calculate(viewportSize, physics);
  }
}
