import 'dart:ui';

/// Abstract interface for spatial indexing.
///
/// Spatial indexes enable efficient region queries and hit testing,
/// reducing complexity from O(n) to O(log n) for large object counts.
///
/// Example usage:
/// ```dart
/// final index = QuadTree<String>(
///   const Rect.fromLTWH(-10000, -10000, 20000, 20000),
/// );
///
/// index.insert('node-1', const Rect.fromLTWH(0, 0, 100, 100));
/// index.insert('node-2', const Rect.fromLTWH(200, 200, 50, 50));
///
/// // Query visible region
/// final visible = index.query(viewportBounds);
///
/// // Hit test at point
/// final candidates = index.hitTest(tapPosition);
/// ```
abstract class SpatialIndex<T> {
  /// Insert an item with its bounding box.
  void insert(T item, Rect bounds);

  /// Remove an item from the index.
  void remove(T item);

  /// Update an item's bounds (typically remove + re-insert).
  void update(T item, Rect newBounds);

  /// Find all items whose bounds overlap the query region.
  ///
  /// Use this for viewport culling to only render visible objects.
  Iterable<T> query(Rect region);

  /// Find all items whose bounds contain the given point.
  ///
  /// Returns items in unspecified order. The caller is responsible for
  /// determining z-order (typically by checking items in reverse
  /// insertion order or using a separate z-index).
  ///
  /// Example:
  /// ```dart
  /// final candidates = spatialIndex.hitTest(point);
  /// // Check in reverse z-order (topmost first)
  /// for (final id in candidates.toList().reversed) {
  ///   final obj = objects[id];
  ///   if (obj != null && obj.bounds.contains(point)) return obj;
  /// }
  /// ```
  Iterable<T> hitTest(Offset point);

  /// Clear all items from the index.
  void clear();

  /// Number of items in the index.
  int get length;
}

/// QuadTree implementation of [SpatialIndex].
///
/// QuadTrees are efficient for uniformly distributed objects. They recursively
/// subdivide space into four quadrants, allowing O(log n) queries.
///
/// **Important:** Items outside [bounds] will not be indexed correctly.
/// Choose bounds large enough for your use case. For infinite canvas
/// applications, use generous bounds like `Rect.fromLTWH(-10000, -10000, 20000, 20000)`.
///
/// ## Usage Patterns
///
/// **When to update:** Rebuild or update the index once per frame or when
/// your object topology changes (add/remove/resize). Do NOT rebuild during
/// paint callbacks—this defeats the performance benefit.
///
/// **Querying visible objects:** Use with [InfiniteCanvasController.getVisibleWorldBounds]
/// for efficient viewport culling:
///
/// ```dart
/// final visibleBounds = controller.getVisibleWorldBounds(viewportSize);
/// final visibleIds = spatialIndex.query(visibleBounds);
/// ```
///
/// **Hit testing:** Query at a point to get candidates, then verify:
///
/// ```dart
/// final candidates = spatialIndex.hitTest(tapPosition);
/// for (final id in candidates.toList().reversed) {  // Check top-to-bottom
///   if (objects[id].bounds.contains(tapPosition)) return objects[id];
/// }
/// ```
///
/// ## Implementation Notes
///
/// Items that span multiple quadrants are inserted into all overlapping
/// children. This is intentional—it ensures correct results for region
/// queries, though it means large items may appear in multiple nodes.
///
/// ## Example
///
/// ```dart
/// final tree = QuadTree<String>(
///   const Rect.fromLTWH(-10000, -10000, 20000, 20000),
///   maxObjects: 10,  // subdivide when exceeding this count
///   maxDepth: 8,     // maximum subdivision depth
/// );
/// ```
class QuadTree<T> implements SpatialIndex<T> {
  /// Creates a QuadTree with the given bounds.
  ///
  /// - [bounds]: The spatial region this tree covers. Items outside this
  ///   region will not be indexed correctly.
  /// - [maxObjects]: Maximum items per node before subdivision (default: 10).
  /// - [maxDepth]: Maximum tree depth to prevent infinite subdivision (default: 8).
  QuadTree(this.bounds, {this.maxObjects = 10, this.maxDepth = 8});

  /// The spatial region this tree covers.
  final Rect bounds;

  /// Maximum items per node before subdivision.
  final int maxObjects;

  /// Maximum tree depth.
  final int maxDepth;

  final List<_Entry<T>> _objects = [];
  List<QuadTree<T>>? _children;
  int _depth = 0;
  int _totalCount = 0;

  @override
  void insert(T item, Rect itemBounds) {
    // If we have children, insert into appropriate child(ren)
    if (_children != null) {
      for (final child in _children!) {
        if (child.bounds.overlaps(itemBounds)) {
          child.insert(item, itemBounds);
        }
      }
      _totalCount++;
      return;
    }

    _objects.add(_Entry(item, itemBounds));
    _totalCount++;

    // Subdivide if we've exceeded capacity and haven't hit max depth
    if (_objects.length > maxObjects && _depth < maxDepth) {
      _subdivide();
    }
  }

  @override
  Iterable<T> query(Rect region) sync* {
    // Quick rejection if region doesn't overlap this node
    if (!bounds.overlaps(region)) return;

    // Check objects at this level
    for (final entry in _objects) {
      if (region.overlaps(entry.bounds)) {
        yield entry.item;
      }
    }

    // Recurse into children that overlap the query region
    if (_children != null) {
      for (final child in _children!) {
        if (child.bounds.overlaps(region)) {
          yield* child.query(region);
        }
      }
    }
  }

  @override
  Iterable<T> hitTest(Offset point) sync* {
    if (!bounds.contains(point)) return;

    for (final entry in _objects) {
      if (entry.bounds.contains(point)) {
        yield entry.item;
      }
    }

    if (_children != null) {
      for (final child in _children!) {
        if (child.bounds.contains(point)) {
          yield* child.hitTest(point);
        }
      }
    }
  }

  @override
  void remove(T item) {
    _objects.removeWhere((e) => e.item == item);
    if (_children != null) {
      for (final child in _children!) {
        child.remove(item);
      }
    }
    _recalculateCount();
  }

  @override
  void update(T item, Rect newBounds) {
    remove(item);
    insert(item, newBounds);
  }

  @override
  void clear() {
    _objects.clear();
    _children = null;
    _totalCount = 0;
  }

  @override
  int get length => _totalCount;

  void _subdivide() {
    final halfW = bounds.width / 2;
    final halfH = bounds.height / 2;
    final x = bounds.left;
    final y = bounds.top;

    _children = [
      // Top-left
      QuadTree(
        Rect.fromLTWH(x, y, halfW, halfH),
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ).._depth = _depth + 1,
      // Top-right
      QuadTree(
        Rect.fromLTWH(x + halfW, y, halfW, halfH),
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ).._depth = _depth + 1,
      // Bottom-left
      QuadTree(
        Rect.fromLTWH(x, y + halfH, halfW, halfH),
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ).._depth = _depth + 1,
      // Bottom-right
      QuadTree(
        Rect.fromLTWH(x + halfW, y + halfH, halfW, halfH),
        maxObjects: maxObjects,
        maxDepth: maxDepth,
      ).._depth = _depth + 1,
    ];

    // Reinsert existing objects into children
    final existing = List.of(_objects);
    _objects.clear();
    _totalCount = 0;

    for (final entry in existing) {
      insert(entry.item, entry.bounds);
    }
  }

  void _recalculateCount() {
    _totalCount = _objects.length;
    if (_children != null) {
      for (final child in _children!) {
        _totalCount += child.length;
      }
    }
  }
}

class _Entry<T> {
  _Entry(this.item, this.bounds);
  final T item;
  final Rect bounds;
}
