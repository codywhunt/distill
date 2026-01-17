import 'package:flutter/material.dart';
import 'package:distill_canvas/utilities.dart';

/// State management for the Free Design example.
class DesignState extends ChangeNotifier {
  final Map<String, DesignObject> objects = {};
  final Set<String> selectedIds = {};

  /// Spatial index for O(log n) hit testing and culling.
  final QuadTree<String> _spatialIndex = QuadTree(
    const Rect.fromLTWH(-10000, -10000, 20000, 20000),
  );

  /// Expose spatial index for snap engine queries.
  SpatialIndex<String> get spatialIndex => _spatialIndex;

  // Drag state for proper snap-to-grid
  bool isDragging = false;
  Map<String, Offset> _dragStartPositions = {};
  Map<String, Size> _resizeStartSizes = {};
  Offset _dragAccumulator = Offset.zero;
  ResizeHandle? _activeHandle;

  int _nextId = 0;

  /// Add initial demo objects.
  void addInitialObjects() {
    // Header rectangle
    addObject(
      DesignObject(
        id: 'obj-${_nextId++}',
        type: ObjectType.rectangle,
        position: const Offset(50, 50),
        size: const Size(300, 60),
        color: const Color(0xFF6366F1),
        label: 'Header',
      ),
    );

    // Content box
    addObject(
      DesignObject(
        id: 'obj-${_nextId++}',
        type: ObjectType.rectangle,
        position: const Offset(50, 130),
        size: const Size(200, 150),
        color: const Color(0xFF3B82F6),
        label: 'Content',
      ),
    );

    // Sidebar
    addObject(
      DesignObject(
        id: 'obj-${_nextId++}',
        type: ObjectType.rectangle,
        position: const Offset(270, 130),
        size: const Size(80, 150),
        color: const Color(0xFF8B5CF6),
        label: 'Sidebar',
      ),
    );

    // Circle button
    addObject(
      DesignObject(
        id: 'obj-${_nextId++}',
        type: ObjectType.ellipse,
        position: const Offset(100, 310),
        size: const Size(50, 50),
        color: const Color(0xFF22C55E),
        label: 'Button',
      ),
    );

    // Text label
    addObject(
      DesignObject(
        id: 'obj-${_nextId++}',
        type: ObjectType.text,
        position: const Offset(170, 320),
        size: const Size(120, 30),
        color: const Color(0xFFF59E0B),
        label: 'Label Text',
      ),
    );

    notifyListeners();
  }

  void addObject(DesignObject obj) {
    objects[obj.id] = obj;
    _spatialIndex.insert(obj.id, obj.bounds);
    notifyListeners();
  }

  void addObjectAt(
    ObjectType type,
    Offset position, {
    Size? size,
    Color? color,
  }) {
    final id = 'obj-${_nextId++}';
    final defaultSize = switch (type) {
      ObjectType.rectangle => const Size(120, 80),
      ObjectType.ellipse => const Size(60, 60),
      ObjectType.text => const Size(100, 30),
    };

    final obj = DesignObject(
      id: id,
      type: type,
      position:
          position - Offset(defaultSize.width / 2, defaultSize.height / 2),
      size: size ?? defaultSize,
      color: color ?? _nextColor(),
      label: '${type.name} $_nextId',
    );

    objects[id] = obj;
    _spatialIndex.insert(id, obj.bounds);
    selectedIds.clear();
    selectedIds.add(id);
    notifyListeners();
  }

  Color _nextColor() {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFF22C55E),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
    ];
    return colors[_nextId % colors.length];
  }

  void deleteSelected() {
    for (final id in selectedIds) {
      objects.remove(id);
      _spatialIndex.remove(id);
    }
    selectedIds.clear();
    notifyListeners();
  }

  void deleteObject(String id) {
    objects.remove(id);
    _spatialIndex.remove(id);
    selectedIds.remove(id);
    notifyListeners();
  }

  DesignObject? hitTest(Offset worldPos) {
    // Use spatial index for O(log n) lookup
    final candidates = _spatialIndex.hitTest(worldPos).toList();

    // Check in reverse z-order (topmost first)
    // Objects map maintains insertion order, so we check against that
    final orderedIds = objects.keys.toList();
    candidates.sort(
      (a, b) => orderedIds.indexOf(b).compareTo(orderedIds.indexOf(a)),
    );

    for (final id in candidates) {
      final obj = objects[id];
      if (obj != null && obj.bounds.contains(worldPos)) {
        return obj;
      }
    }
    return null;
  }

  /// Get objects visible within the given bounds (for culling).
  Iterable<DesignObject> getVisibleObjects(Rect visibleBounds) {
    return _spatialIndex
        .query(visibleBounds)
        .map((id) => objects[id])
        .whereType<DesignObject>();
  }

  void select(String id) {
    selectedIds.clear();
    selectedIds.add(id);
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    notifyListeners();
  }

  void addToSelection(String id) {
    selectedIds.add(id);
    notifyListeners();
  }

  void selectAll() {
    selectedIds.clear();
    selectedIds.addAll(objects.keys);
    notifyListeners();
  }

  void selectInRect(Rect rect) {
    selectedIds.clear();
    for (final obj in objects.values) {
      if (rect.overlaps(obj.bounds)) {
        selectedIds.add(obj.id);
      }
    }
    notifyListeners();
  }

  void deselectAll() {
    selectedIds.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Drag / Move
  // ─────────────────────────────────────────────────────────────────────────

  void startDrag() {
    isDragging = true;
    _dragAccumulator = Offset.zero;
    _activeHandle = null;

    _dragStartPositions = {
      for (final id in selectedIds)
        if (objects.containsKey(id)) id: objects[id]!.position,
    };
  }

  void updateDrag(Offset worldDelta, {double? gridSize}) {
    if (!isDragging || _dragStartPositions.isEmpty) return;

    _dragAccumulator += worldDelta;

    for (final entry in _dragStartPositions.entries) {
      final obj = objects[entry.key];
      if (obj == null) continue;

      var newPos = entry.value + _dragAccumulator;

      if (gridSize != null && gridSize > 0) {
        // Snap to absolute grid for single selection
        if (selectedIds.length == 1) {
          newPos = Offset(
            (newPos.dx / gridSize).round() * gridSize,
            (newPos.dy / gridSize).round() * gridSize,
          );
        } else {
          // Snap movement for multi-selection
          final snappedMovement = Offset(
            (_dragAccumulator.dx / gridSize).round() * gridSize,
            (_dragAccumulator.dy / gridSize).round() * gridSize,
          );
          newPos = entry.value + snappedMovement;
        }
      }

      final updated = obj.copyWith(position: newPos);
      objects[entry.key] = updated;
      _spatialIndex.update(entry.key, updated.bounds);
    }

    notifyListeners();
  }

  void endDrag() {
    isDragging = false;
    _dragStartPositions.clear();
    _dragAccumulator = Offset.zero;
    _activeHandle = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Resize
  // ─────────────────────────────────────────────────────────────────────────

  void startResize(ResizeHandle handle) {
    isDragging = true;
    _dragAccumulator = Offset.zero;
    _activeHandle = handle;

    _dragStartPositions = {
      for (final id in selectedIds)
        if (objects.containsKey(id)) id: objects[id]!.position,
    };
    _resizeStartSizes = {
      for (final id in selectedIds)
        if (objects.containsKey(id)) id: objects[id]!.size,
    };
  }

  void updateResize(Offset worldDelta, {double? gridSize}) {
    if (!isDragging || _activeHandle == null) return;

    _dragAccumulator += worldDelta;

    for (final id in selectedIds) {
      final obj = objects[id];
      final startPos = _dragStartPositions[id];
      final startSize = _resizeStartSizes[id];
      if (obj == null || startPos == null || startSize == null) continue;

      var newPos = startPos;
      var newSize = startSize;
      var delta = _dragAccumulator;

      // Snap delta to grid
      if (gridSize != null && gridSize > 0) {
        delta = Offset(
          (delta.dx / gridSize).round() * gridSize,
          (delta.dy / gridSize).round() * gridSize,
        );
      }

      switch (_activeHandle!) {
        case ResizeHandle.topLeft:
          newPos = Offset(startPos.dx + delta.dx, startPos.dy + delta.dy);
          newSize = Size(
            startSize.width - delta.dx,
            startSize.height - delta.dy,
          );
        case ResizeHandle.topCenter:
          newPos = Offset(startPos.dx, startPos.dy + delta.dy);
          newSize = Size(startSize.width, startSize.height - delta.dy);
        case ResizeHandle.topRight:
          newPos = Offset(startPos.dx, startPos.dy + delta.dy);
          newSize = Size(
            startSize.width + delta.dx,
            startSize.height - delta.dy,
          );
        case ResizeHandle.middleLeft:
          newPos = Offset(startPos.dx + delta.dx, startPos.dy);
          newSize = Size(startSize.width - delta.dx, startSize.height);
        case ResizeHandle.middleRight:
          newSize = Size(startSize.width + delta.dx, startSize.height);
        case ResizeHandle.bottomLeft:
          newPos = Offset(startPos.dx + delta.dx, startPos.dy);
          newSize = Size(
            startSize.width - delta.dx,
            startSize.height + delta.dy,
          );
        case ResizeHandle.bottomCenter:
          newSize = Size(startSize.width, startSize.height + delta.dy);
        case ResizeHandle.bottomRight:
          newSize = Size(
            startSize.width + delta.dx,
            startSize.height + delta.dy,
          );
      }

      // Enforce minimum size
      const minSize = 20.0;
      if (newSize.width < minSize) {
        newSize = Size(minSize, newSize.height);
        if (_activeHandle!.isLeft) {
          newPos = Offset(startPos.dx + startSize.width - minSize, newPos.dy);
        }
      }
      if (newSize.height < minSize) {
        newSize = Size(newSize.width, minSize);
        if (_activeHandle!.isTop) {
          newPos = Offset(newPos.dx, startPos.dy + startSize.height - minSize);
        }
      }

      final updated = obj.copyWith(position: newPos, size: newSize);
      objects[id] = updated;
      _spatialIndex.update(id, updated.bounds);
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Layer ordering
  // ─────────────────────────────────────────────────────────────────────────

  void bringToFront(String id) {
    final obj = objects.remove(id);
    if (obj != null) {
      objects[id] = obj;
      notifyListeners();
    }
  }

  void sendToBack(String id) {
    final obj = objects.remove(id);
    if (obj != null) {
      final newMap = {id: obj, ...objects};
      objects.clear();
      objects.addAll(newMap);
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bounds
  // ─────────────────────────────────────────────────────────────────────────

  Rect? get allObjectsBounds {
    if (objects.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final obj in objects.values) {
      minX = minX < obj.bounds.left ? minX : obj.bounds.left;
      minY = minY < obj.bounds.top ? minY : obj.bounds.top;
      maxX = maxX > obj.bounds.right ? maxX : obj.bounds.right;
      maxY = maxY > obj.bounds.bottom ? maxY : obj.bounds.bottom;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect? get selectedObjectsBounds {
    if (selectedIds.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final id in selectedIds) {
      final obj = objects[id];
      if (obj != null) {
        minX = minX < obj.bounds.left ? minX : obj.bounds.left;
        minY = minY < obj.bounds.top ? minY : obj.bounds.top;
        maxX = maxX > obj.bounds.right ? maxX : obj.bounds.right;
        maxY = maxY > obj.bounds.bottom ? maxY : obj.bounds.bottom;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum ObjectType { rectangle, ellipse, text }

class DesignObject {
  const DesignObject({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    required this.color,
    required this.label,
  });

  final String id;
  final ObjectType type;
  final Offset position;
  final Size size;
  final Color color;
  final String label;

  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

  DesignObject copyWith({
    Offset? position,
    Size? size,
    Color? color,
    String? label,
  }) {
    return DesignObject(
      id: id,
      type: type,
      position: position ?? this.position,
      size: size ?? this.size,
      color: color ?? this.color,
      label: label ?? this.label,
    );
  }
}

enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  bool get isLeft =>
      this == topLeft || this == middleLeft || this == bottomLeft;
  bool get isRight =>
      this == topRight || this == middleRight || this == bottomRight;
  bool get isTop => this == topLeft || this == topCenter || this == topRight;
  bool get isBottom =>
      this == bottomLeft || this == bottomCenter || this == bottomRight;
  bool get isTopLeft => this == topLeft;
  bool get isTopRight => this == topRight;
  bool get isBottomLeft => this == bottomLeft;
  bool get isBottomRight => this == bottomRight;
}
