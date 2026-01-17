/// Optional utilities for infinite_canvas.
///
/// This library provides performance utilities that are useful for canvas
/// applications but are not part of the core package. Import separately
/// when needed:
///
/// ```dart
/// import 'package:distill_canvas/utilities.dart';
/// ```
///
/// ## Spatial Indexing
///
/// Use [QuadTree] for O(log n) hit testing and culling with large object counts:
///
/// ```dart
/// final index = QuadTree<String>(
///   const Rect.fromLTWH(-10000, -10000, 20000, 20000),
/// );
///
/// // Insert objects
/// index.insert('node-1', node1.bounds);
///
/// // Query visible region (O(log n) instead of O(n))
/// final visible = index.query(controller.getVisibleWorldBounds());
///
/// // Hit test at point
/// final candidates = index.hitTest(tapPosition);
/// ```
///
/// ## Snap Engine
///
/// Use [SnapEngine] for Figma-style smart guides and object alignment:
///
/// ```dart
/// final engine = SnapEngine(threshold: 8.0);
///
/// // During drag, calculate snap
/// final result = engine.calculate(
///   movingBounds: draggedObject.bounds,
///   otherBounds: nearbyObjects.map((o) => o.bounds),
///   zoom: controller.zoom,
/// );
///
/// // Apply snapped position
/// draggedObject.position = result.snappedBounds.topLeft;
///
/// // Render guides in overlay
/// SnapGuidesOverlay(guides: result.guides, controller: controller)
/// ```
library;

export 'src/utilities/snap_engine.dart';
export 'src/utilities/spatial_index.dart';
