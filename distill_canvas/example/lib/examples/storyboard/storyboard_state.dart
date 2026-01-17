import 'package:flutter/material.dart';

/// State management for the Storyboard example.
class StoryboardState extends ChangeNotifier {
  final Map<String, ScreenNode> screens = {};
  final List<ScreenConnection> connections = [];
  final Set<String> selectedIds = {};

  // Drag state
  bool isDragging = false;
  Map<String, Offset> _dragStartPositions = {};
  Offset _dragAccumulator = Offset.zero;

  int _nextId = 0;

  /// Add initial demo screens.
  void addInitialScreens() {
    // Login flow
    _addScreen('Login', ScreenType.entry, const Offset(0, 100), Colors.blue);
    _addScreen('Home', ScreenType.main, const Offset(300, 100), Colors.indigo);
    _addScreen('Profile', ScreenType.main, const Offset(600, 0), Colors.purple);
    _addScreen(
      'Settings',
      ScreenType.main,
      const Offset(600, 200),
      Colors.teal,
    );
    _addScreen(
      'Search',
      ScreenType.main,
      const Offset(300, 300),
      Colors.orange,
    );
    _addScreen(
      'Detail',
      ScreenType.detail,
      const Offset(600, 400),
      Colors.pink,
    );

    // Connections
    _addConnection('screen-0', 'screen-1'); // Login -> Home
    _addConnection('screen-1', 'screen-2'); // Home -> Profile
    _addConnection('screen-1', 'screen-3'); // Home -> Settings
    _addConnection('screen-1', 'screen-4'); // Home -> Search
    _addConnection('screen-4', 'screen-5'); // Search -> Detail

    notifyListeners();
  }

  void _addScreen(String name, ScreenType type, Offset position, Color color) {
    final id = 'screen-${_nextId++}';
    screens[id] = ScreenNode(
      id: id,
      name: name,
      type: type,
      position: position,
      color: color,
    );
  }

  void _addConnection(String fromId, String toId) {
    connections.add(ScreenConnection(fromId: fromId, toId: toId));
  }

  void addScreenAt(Offset position) {
    final id = 'screen-${_nextId++}';
    final screen = ScreenNode(
      id: id,
      name: 'Screen $_nextId',
      type: ScreenType.main,
      position: position - const Offset(75, 60), // Center on tap
      color: _nextColor(),
    );
    screens[id] = screen;
    selectedIds.clear();
    selectedIds.add(id);
    notifyListeners();
  }

  Color _nextColor() {
    const colors = [
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.green,
    ];
    return colors[_nextId % colors.length];
  }

  void deleteSelected() {
    for (final id in selectedIds) {
      screens.remove(id);
      connections.removeWhere((c) => c.fromId == id || c.toId == id);
    }
    selectedIds.clear();
    notifyListeners();
  }

  ScreenNode? hitTest(Offset worldPos) {
    for (final screen in screens.values.toList().reversed) {
      if (screen.bounds.contains(worldPos)) {
        return screen;
      }
    }
    return null;
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

    _dragStartPositions = {
      for (final id in selectedIds)
        if (screens.containsKey(id)) id: screens[id]!.position,
    };
  }

  void updateDrag(Offset worldDelta) {
    if (!isDragging || _dragStartPositions.isEmpty) return;

    _dragAccumulator += worldDelta;

    for (final entry in _dragStartPositions.entries) {
      final screen = screens[entry.key];
      if (screen == null) continue;

      final newPos = entry.value + _dragAccumulator;
      screens[entry.key] = screen.copyWith(position: newPos);
    }

    notifyListeners();
  }

  void endDrag() {
    isDragging = false;
    _dragStartPositions.clear();
    _dragAccumulator = Offset.zero;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Auto Layout
  // ─────────────────────────────────────────────────────────────────────────

  void autoLayout() {
    if (screens.isEmpty) return;

    const spacing = 250.0;
    const rowHeight = 200.0;

    // Simple horizontal layout
    var x = 0.0;
    var y = 0.0;
    var col = 0;
    const maxCols = 4;

    for (final id in screens.keys) {
      screens[id] = screens[id]!.copyWith(position: Offset(x, y));

      col++;
      if (col >= maxCols) {
        col = 0;
        x = 0;
        y += rowHeight;
      } else {
        x += spacing;
      }
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Connections
  // ─────────────────────────────────────────────────────────────────────────

  void addConnection(String fromId, String toId) {
    // Don't add duplicate or self connections
    if (fromId == toId) return;
    if (connections.any((c) => c.fromId == fromId && c.toId == toId)) return;

    connections.add(ScreenConnection(fromId: fromId, toId: toId));
    notifyListeners();
  }

  void removeConnection(String fromId, String toId) {
    connections.removeWhere((c) => c.fromId == fromId && c.toId == toId);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bounds
  // ─────────────────────────────────────────────────────────────────────────

  Rect? get allScreensBounds {
    if (screens.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final screen in screens.values) {
      minX = minX < screen.bounds.left ? minX : screen.bounds.left;
      minY = minY < screen.bounds.top ? minY : screen.bounds.top;
      maxX = maxX > screen.bounds.right ? maxX : screen.bounds.right;
      maxY = maxY > screen.bounds.bottom ? maxY : screen.bounds.bottom;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum ScreenType {
  entry, // Login, splash
  main, // Main screens
  detail, // Detail views
  modal, // Modal/overlay
}

class ScreenNode {
  const ScreenNode({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.color,
  });

  final String id;
  final String name;
  final ScreenType type;
  final Offset position;
  final Color color;

  static const size = Size(150, 120);

  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  Offset get center => bounds.center;

  // Connection points
  Offset get rightEdge => Offset(bounds.right, bounds.center.dy);
  Offset get leftEdge => Offset(bounds.left, bounds.center.dy);

  ScreenNode copyWith({Offset? position, String? name, Color? color}) {
    return ScreenNode(
      id: id,
      name: name ?? this.name,
      type: type,
      position: position ?? this.position,
      color: color ?? this.color,
    );
  }
}

class ScreenConnection {
  const ScreenConnection({required this.fromId, required this.toId});

  final String fromId;
  final String toId;
}
