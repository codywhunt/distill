import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:distill_canvas/infinite_canvas.dart';
import 'package:distill_canvas/utilities.dart';

import '../../shared/theme.dart';
import '../../shared/ui.dart';
import 'design_state.dart';

/// Free Design Example
///
/// Demonstrates Figma-like visual composition with:
/// - Single and multi-selection
/// - Marquee selection
/// - Move with snap-to-grid
/// - Resize handles (overlay layer)
/// - Layer ordering
class FreeDesignExample extends StatelessWidget {
  const FreeDesignExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DesignState()..addInitialObjects(),
      child: const _FreeDesignCanvas(),
    );
  }
}

class _FreeDesignCanvas extends StatefulWidget {
  const _FreeDesignCanvas();

  @override
  State<_FreeDesignCanvas> createState() => _FreeDesignCanvasState();
}

class _FreeDesignCanvasState extends State<_FreeDesignCanvas> {
  final _controller = InfiniteCanvasController();
  final _focusNode = FocusNode();

  ObjectType _selectedTool = ObjectType.rectangle;
  bool _snapToGrid = true;
  bool _showGrid = true;
  final bool _enableSmartGuides = true;

  // Snap engine for smart guides
  final _snapEngine = const SnapEngine(
    threshold: 8.0,
    enableEdgeSnap: true,
    enableCenterSnap: true,
  );

  // Active snap guides (shown during drag)
  List<SnapGuide> _activeGuides = [];

  // Drag mode tracking - single source of truth
  _DragMode? _dragMode;

  // Marquee selection
  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DesignState>();

    return Column(
      children: [
        // Header
        const ExampleHeader(
          title: 'Free Design',
          description: 'visual composition canvas',
          features: ['selection', 'resize', 'snap'],
        ),

        // Toolbar
        _Toolbar(
          selectedTool: _selectedTool,
          onToolChanged: (tool) => setState(() => _selectedTool = tool),
          snapToGrid: _snapToGrid,
          onSnapToggle: () => setState(() => _snapToGrid = !_snapToGrid),
          showGrid: _showGrid,
          onGridToggle: () => setState(() => _showGrid = !_showGrid),
          onDelete: state.selectedIds.isNotEmpty ? state.deleteSelected : null,
        ),

        // Canvas
        Expanded(
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: InfiniteCanvas(
              controller: _controller,
              backgroundColor: AppTheme.canvasDefault,
              initialViewport: InitialViewport.fitContent(
                () => state.allObjectsBounds,
                padding: const EdgeInsets.all(100),
                maxZoom: 1.0,
                fallback: const InitialViewport.centerOrigin(),
              ),
              physicsConfig: const CanvasPhysicsConfig(
                minZoom: 0.1,
                maxZoom: 4.0,
              ),
              gestureConfig: const CanvasGestureConfig(dragThreshold: 3.0),
              layers: CanvasLayers(
                background:
                    _showGrid
                        ? (ctx, ctrl) => DotBackground(
                          controller: ctrl,
                          spacing: _snapToGrid ? 25 : 20,
                          color: Colors.white.withValues(alpha: 0.04),
                        )
                        : null,
                content: (ctx, ctrl) => _buildContent(state, ctrl),
                overlay: (ctx, ctrl) => _buildOverlay(state, ctrl),
              ),
              onTapWorld: (pos) => _handleTap(pos, state),
              onDoubleTapWorld: (pos) => _handleDoubleTap(pos, state),
              onDragStartWorld: (d) => _handleDragStart(d, state),
              onDragUpdateWorld: (d) => _handleDragUpdate(d, state),
              onDragEndWorld: (d) => _handleDragEnd(d, state),
            ),
          ),
        ),

        // Status bar
        _StatusBar(
          controller: _controller,
          state: state,
          snapToGrid: _snapToGrid,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content Layer (world-space)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent(DesignState state, InfiniteCanvasController ctrl) {
    final viewportSize = ctrl.viewportSize ?? Size.zero;
    final visibleObjects = ctrl.cullToVisible(
      state.objects.values,
      (obj) => obj.bounds.inflate(10),
      viewportSize,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final obj in visibleObjects)
          CanvasItem(
            key: ValueKey(obj.id),
            position: obj.position,
            child: _DesignObjectWidget(
              object: obj,
              isSelected: state.selectedIds.contains(obj.id),
              zoomLevel: ctrl.currentZoomLevel,
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Overlay Layer (screen-space)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverlay(DesignState state, InfiniteCanvasController ctrl) {
    return Stack(
      children: [
        // Selection handles (visual only - gestures handled via canvas callbacks)
        if (state.selectedIds.isNotEmpty && !state.isDragging)
          for (final id in state.selectedIds)
            if (state.objects.containsKey(id))
              _SelectionHandles(object: state.objects[id]!, controller: ctrl),

        // Marquee selection rectangle
        if (_marqueeStart != null && _marqueeEnd != null)
          _MarqueeRect(
            start: ctrl.worldToView(_marqueeStart!),
            end: ctrl.worldToView(_marqueeEnd!),
          ),

        // Snap guides (shown during drag)
        if (_activeGuides.isNotEmpty)
          SnapGuidesOverlay(
            guides: _activeGuides,
            controller: ctrl,
            color: const Color(0xFF6366F1),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Gesture Handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _handleTap(Offset worldPos, DesignState state) {
    final hit = state.hitTest(worldPos);

    if (hit != null) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        state.toggleSelection(hit.id);
      } else {
        state.select(hit.id);
      }
    } else {
      state.deselectAll();
    }
  }

  void _handleDoubleTap(Offset worldPos, DesignState state) {
    final hit = state.hitTest(worldPos);

    if (hit != null) {
      // Focus on double-tapped object
      _controller.focusOn(hit.bounds, padding: const EdgeInsets.all(100));
    } else {
      // Add new object at tap position
      final snappedPos = _snapToGrid ? _snapOffset(worldPos, 25) : worldPos;
      state.addObjectAt(_selectedTool, snappedPos);
    }
  }

  void _handleDragStart(CanvasDragStartDetails details, DesignState state) {
    // Priority 1: Hit test resize handles (screen-space)
    if (state.selectedIds.isNotEmpty) {
      final handle = _hitTestHandle(
        viewPosition: details.viewPosition,
        state: state,
      );
      if (handle != null) {
        _dragMode = _DragMode.resize;
        state.startResize(handle);
        setState(() {});
        return;
      }
    }

    // Priority 2: Hit test objects (world-space)
    final hit = state.hitTest(details.worldPosition);
    if (hit != null) {
      _dragMode = _DragMode.move;
      // Select if not already selected
      if (!state.selectedIds.contains(hit.id)) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          state.addToSelection(hit.id);
        } else {
          state.select(hit.id);
        }
      }
      state.startDrag();
      setState(() {});
      return;
    }

    // Priority 3: Marquee selection (empty space)
    _dragMode = _DragMode.marquee;
    _marqueeStart = details.worldPosition;
    _marqueeEnd = details.worldPosition;
    setState(() {});
  }

  void _handleDragUpdate(CanvasDragUpdateDetails details, DesignState state) {
    switch (_dragMode) {
      case _DragMode.resize:
        final worldDelta = _controller.viewToWorldDelta(details.viewDelta);
        state.updateResize(worldDelta, gridSize: _snapToGrid ? 25 : null);
        break;
      case _DragMode.move:
        if (_enableSmartGuides) {
          _handleMoveWithSmartGuides(details, state);
        } else {
          state.updateDrag(
            details.worldDelta,
            gridSize: _snapToGrid ? 25 : null,
          );
        }
        break;
      case _DragMode.marquee:
        _marqueeEnd = details.worldPosition;
        final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
        state.selectInRect(rect);
        setState(() {});
        break;
      case null:
        break;
    }
  }

  void _handleMoveWithSmartGuides(
    CanvasDragUpdateDetails details,
    DesignState state,
  ) {
    // Get current selected bounds
    final currentBounds = state.selectedObjectsBounds;
    if (currentBounds == null) {
      state.updateDrag(details.worldDelta, gridSize: _snapToGrid ? 25 : null);
      return;
    }

    // Calculate intended bounds after applying delta
    final intendedBounds = currentBounds.shift(details.worldDelta);

    // Query spatial index for nearby objects (O(log n))
    final searchRegion = intendedBounds.inflate(
      _snapEngine.threshold / _controller.zoom * 2,
    );
    final nearbyIds = state.spatialIndex.query(searchRegion);

    // Get bounds of nearby non-selected objects
    final nearbyBounds =
        nearbyIds
            .where((id) => !state.selectedIds.contains(id))
            .map((id) => state.objects[id]?.bounds)
            .whereType<Rect>();

    // Calculate snap
    final snapResult = _snapEngine.calculate(
      movingBounds: intendedBounds,
      otherBounds: nearbyBounds,
      zoom: _controller.zoom,
    );

    // Apply movement: use the delta from current to snapped position
    final snappedDelta =
        snapResult.snappedBounds.topLeft - currentBounds.topLeft;
    state.updateDrag(snappedDelta, gridSize: null); // Don't double-snap to grid

    // Update guides for rendering
    setState(() => _activeGuides = snapResult.guides);
  }

  void _handleDragEnd(CanvasDragEndDetails details, DesignState state) {
    switch (_dragMode) {
      case _DragMode.resize:
      case _DragMode.move:
        state.endDrag();
        break;
      case _DragMode.marquee:
        // Selection already updated in dragUpdate
        break;
      case null:
        break;
    }

    _dragMode = null;
    _marqueeStart = null;
    _marqueeEnd = null;
    _activeGuides = []; // Clear snap guides
    setState(() {});
  }

  /// Hit test resize handles in screen-space.
  /// Returns the handle if hit, null otherwise.
  ResizeHandle? _hitTestHandle({
    required Offset viewPosition,
    required DesignState state,
  }) {
    const handleSize = 8.0;
    const hitPadding = 4.0;
    final hitRadius = (handleSize / 2) + hitPadding;

    for (final id in state.selectedIds) {
      final obj = state.objects[id];
      if (obj == null) continue;

      final viewBounds = _controller.worldToViewRect(obj.bounds);

      // Check all 8 handles
      final handlePositions = {
        ResizeHandle.topLeft: viewBounds.topLeft,
        ResizeHandle.topCenter: Offset(viewBounds.center.dx, viewBounds.top),
        ResizeHandle.topRight: viewBounds.topRight,
        ResizeHandle.middleLeft: Offset(viewBounds.left, viewBounds.center.dy),
        ResizeHandle.middleRight: Offset(
          viewBounds.right,
          viewBounds.center.dy,
        ),
        ResizeHandle.bottomLeft: viewBounds.bottomLeft,
        ResizeHandle.bottomCenter: Offset(
          viewBounds.center.dx,
          viewBounds.bottom,
        ),
        ResizeHandle.bottomRight: viewBounds.bottomRight,
      };

      for (final entry in handlePositions.entries) {
        if ((viewPosition - entry.value).distance <= hitRadius) {
          return entry.key;
        }
      }
    }

    return null;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final state = context.read<DesignState>();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        state.deleteSelected();
        break;
      case LogicalKeyboardKey.keyA:
        if (HardwareKeyboard.instance.isMetaPressed) {
          state.selectAll();
        }
        break;
      case LogicalKeyboardKey.escape:
        state.deselectAll();
        break;
      case LogicalKeyboardKey.bracketRight:
        // Bring to front
        if (state.selectedIds.length == 1) {
          state.bringToFront(state.selectedIds.first);
        }
        break;
      case LogicalKeyboardKey.bracketLeft:
        // Send to back
        if (state.selectedIds.length == 1) {
          state.sendToBack(state.selectedIds.first);
        }
        break;
      case LogicalKeyboardKey.keyG:
        setState(() => _showGrid = !_showGrid);
        break;
      case LogicalKeyboardKey.keyS:
        if (!HardwareKeyboard.instance.isMetaPressed) {
          setState(() => _snapToGrid = !_snapToGrid);
        }
        break;
      default:
        break;
    }
  }

  Offset _snapOffset(Offset offset, double gridSize) {
    return Offset(
      (offset.dx / gridSize).round() * gridSize,
      (offset.dy / gridSize).round() * gridSize,
    );
  }
}

/// Drag mode for the canvas - determines how drag events are processed.
enum _DragMode { resize, move, marquee }

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.selectedTool,
    required this.onToolChanged,
    required this.snapToGrid,
    required this.onSnapToggle,
    required this.showGrid,
    required this.onGridToggle,
    this.onDelete,
  });

  final ObjectType selectedTool;
  final ValueChanged<ObjectType> onToolChanged;
  final bool snapToGrid;
  final VoidCallback onSnapToggle;
  final bool showGrid;
  final VoidCallback onGridToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Toolbar(
      children: [
        // Shape tools
        ToolbarButton(
          icon: Icons.crop_square,
          tooltip: 'Rectangle (R)',
          isActive: selectedTool == ObjectType.rectangle,
          onPressed: () => onToolChanged(ObjectType.rectangle),
        ),
        ToolbarButton(
          icon: Icons.circle_outlined,
          tooltip: 'Ellipse (O)',
          isActive: selectedTool == ObjectType.ellipse,
          onPressed: () => onToolChanged(ObjectType.ellipse),
        ),
        ToolbarButton(
          icon: Icons.text_fields,
          tooltip: 'Text (T)',
          isActive: selectedTool == ObjectType.text,
          onPressed: () => onToolChanged(ObjectType.text),
        ),

        const ToolbarDivider(),

        // Grid & snap
        ToolbarButton(
          icon: Icons.grid_4x4,
          tooltip: 'Toggle Grid (G)',
          isActive: showGrid,
          onPressed: onGridToggle,
        ),
        ToolbarButton(
          icon: Icons.grid_on,
          tooltip: 'Snap to Grid (S)',
          isActive: snapToGrid,
          onPressed: onSnapToggle,
        ),

        const ToolbarDivider(),

        // Delete
        ToolbarButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete (⌫)',
          onPressed: onDelete ?? () {},
        ),

        const Spacer(),

        // Instructions
        const Text(
          'dbl-click: add  shift+click: multi  []: layer',
          style: TextStyle(
            fontSize: 10,
            fontFamily: AppTheme.fontMono,
            color: AppTheme.textSubtle,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Design Object Widget
// ─────────────────────────────────────────────────────────────────────────────

class _DesignObjectWidget extends StatelessWidget {
  const _DesignObjectWidget({
    required this.object,
    required this.isSelected,
    this.zoomLevel = ZoomLevel.normal,
  });

  final DesignObject object;
  final bool isSelected;
  final ZoomLevel zoomLevel;

  @override
  Widget build(BuildContext context) {
    // At overview zoom, show simplified rendering (no labels, reduced shadows)
    final isOverview = zoomLevel == ZoomLevel.overview;

    return Container(
      width: object.size.width,
      height: object.size.height,
      decoration: BoxDecoration(
        color: object.color.withValues(alpha: isOverview ? 0.6 : 0.7),
        borderRadius:
            object.type == ObjectType.ellipse
                ? BorderRadius.circular(object.size.width)
                : BorderRadius.circular(4),
        border: Border.all(
          color:
              isSelected
                  ? AppTheme.textSecondary
                  : object.color.withValues(alpha: 0.4),
          width: isSelected ? 1.5 : 0.5,
        ),
        boxShadow:
            isOverview
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
      ),
      alignment: Alignment.center,
      child:
          isOverview
              ? null
              : Text(
                object.label.toLowerCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: AppTheme.fontMono,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection Handles (Overlay) - Visual Only
// ─────────────────────────────────────────────────────────────────────────────

/// Visual selection handles - NO gesture handling.
/// All gestures are handled via canvas callbacks with hit-testing.
class _SelectionHandles extends StatelessWidget {
  const _SelectionHandles({required this.object, required this.controller});

  final DesignObject object;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final viewBounds = controller.worldToViewRect(object.bounds);

    return Stack(
      children: [
        // Selection border
        Positioned(
          left: viewBounds.left - 1,
          top: viewBounds.top - 1,
          width: viewBounds.width + 2,
          height: viewBounds.height + 2,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.textSecondary, width: 0.5),
              ),
            ),
          ),
        ),

        // Handles - purely visual
        _handle(viewBounds.topLeft, ResizeHandle.topLeft),
        _handle(
          Offset(viewBounds.center.dx, viewBounds.top),
          ResizeHandle.topCenter,
        ),
        _handle(viewBounds.topRight, ResizeHandle.topRight),
        _handle(
          Offset(viewBounds.left, viewBounds.center.dy),
          ResizeHandle.middleLeft,
        ),
        _handle(
          Offset(viewBounds.right, viewBounds.center.dy),
          ResizeHandle.middleRight,
        ),
        _handle(viewBounds.bottomLeft, ResizeHandle.bottomLeft),
        _handle(
          Offset(viewBounds.center.dx, viewBounds.bottom),
          ResizeHandle.bottomCenter,
        ),
        _handle(viewBounds.bottomRight, ResizeHandle.bottomRight),
      ],
    );
  }

  Widget _handle(Offset position, ResizeHandle handle) {
    const size = 6.0;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      // MouseRegion outside for cursor, IgnorePointer inside to let canvas handle gestures
      child: MouseRegion(
        cursor: _cursorForHandle(handle),
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.textPrimary,
              border: Border.all(color: AppTheme.textMuted, width: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }

  MouseCursor _cursorForHandle(ResizeHandle handle) {
    // Check corners FIRST (before edges, since corners also match edge checks)
    if (handle.isTopLeft || handle.isBottomRight) {
      return SystemMouseCursors.resizeUpLeftDownRight;
    }
    if (handle.isTopRight || handle.isBottomLeft) {
      return SystemMouseCursors.resizeUpRightDownLeft;
    }
    // Then check edges
    if (handle.isLeft || handle.isRight) {
      return SystemMouseCursors.resizeLeftRight;
    }
    if (handle.isTop || handle.isBottom) {
      return SystemMouseCursors.resizeUpDown;
    }
    return SystemMouseCursors.basic;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marquee Selection
// ─────────────────────────────────────────────────────────────────────────────

class _MarqueeRect extends StatelessWidget {
  const _MarqueeRect({required this.start, required this.end});

  final Offset start;
  final Offset end;

  @override
  Widget build(BuildContext context) {
    final rect = Rect.fromPoints(start, end);

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.textMuted.withValues(alpha: 0.05),
            border: Border.all(color: AppTheme.textMuted, width: 0.5),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.controller,
    required this.state,
    required this.snapToGrid,
  });

  final InfiniteCanvasController controller;
  final DesignState state;
  final bool snapToGrid;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder:
          (context, _) => StatusBar(
            children: [
              StatusItem(
                icon: Icons.layers,
                label: '${state.objects.length} objects',
              ),
              if (state.selectedIds.isNotEmpty)
                StatusItem(
                  icon: Icons.check_box_outlined,
                  label: '${state.selectedIds.length} selected',
                ),
              StatusItem(
                icon: Icons.zoom_in,
                label: '${(controller.zoom * 100).round()}%',
              ),
              if (snapToGrid)
                const StatusItem(icon: Icons.grid_on, label: 'Snap: 25px'),
              const Spacer(),
            ],
          ),
    );
  }
}
