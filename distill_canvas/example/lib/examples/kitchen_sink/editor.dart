import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:distill_canvas/infinite_canvas.dart';

/// Kitchen Sink example - demonstrates ALL canvas features.
///
/// This is the comprehensive demo showing everything the canvas can do.
/// For focused examples, see the other examples in the examples/ folder.
class KitchenSinkExample extends StatelessWidget {
  const KitchenSinkExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorState()..addInitialNodes(),
      child: const EditorScreen(),
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Editor Mode (demonstrates gesture config switching)
//─────────────────────────────────────────────────────────────────────────────

enum EditorMode {
  design('Design', Icons.edit, CanvasGestureConfig.all),
  presentation('Present', Icons.play_arrow, CanvasGestureConfig.none),
  zoomOnly('Zoom Only', Icons.zoom_in, CanvasGestureConfig.zoomOnly);

  const EditorMode(this.label, this.icon, this.gestureConfig);

  final String label;
  final IconData icon;
  final CanvasGestureConfig gestureConfig;
}

//─────────────────────────────────────────────────────────────────────────────
// Editor Screen
//─────────────────────────────────────────────────────────────────────────────

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _controller = InfiniteCanvasController();
  bool _showDebugLayer = false;
  bool _showMiniMap = true;
  bool _snapToGrid = false;
  EditorMode _mode = EditorMode.design;

  // Marquee selection state
  Offset? _marqueeStart;
  Offset? _marqueeEnd;

  // Keyboard focus
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<EditorState>();

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // The canvas
            Positioned.fill(
              child: InfiniteCanvas(
                controller: _controller,
                backgroundColor: const Color(0xFF1a1a2e),
                // Center on content on startup, or center origin if empty
                initialViewport: InitialViewport.fitContent(
                  () => context.read<EditorState>().allNodesBounds,
                  padding: const EdgeInsets.all(80),
                  maxZoom: 1.0, // Don't zoom in past 100% on small content
                  fallback: const InitialViewport.centerOrigin(),
                ),
                layers: CanvasLayers(
                  // Dots when zoomed in (≤200%), grid when zoomed out
                  background:
                      (ctx, ctrl) =>
                          ctrl.zoom <= 2.0
                              ? DotBackground(
                                controller: ctrl,
                                spacing: _snapToGrid ? 25 : 20,
                                color: Colors.white.withValues(alpha: 0.1),
                              )
                              : GridBackground(
                                controller: ctrl,
                                spacing: _snapToGrid ? 25 : 50,
                                color: Colors.white.withValues(
                                  alpha: _snapToGrid ? 0.08 : 0.05,
                                ),
                                axisColor: Colors.white.withValues(alpha: 0.1),
                              ),
                  content: (ctx, ctrl) => _buildContent(ctx, ctrl),
                  overlay: (ctx, ctrl) => _buildOverlay(ctx, ctrl),
                  debug:
                      _showDebugLayer
                          ? (ctx, ctrl) => _buildDebugLayer(ctx, ctrl)
                          : null,
                ),
                physicsConfig: const CanvasPhysicsConfig(
                  minZoom: 0.1,
                  maxZoom: 5.0,
                ),
                // Use mode-specific gesture config
                gestureConfig: _mode.gestureConfig.copyWith(
                  dragThreshold: 5.0,
                  hoverThrottleMs: 16,
                ),
                onTapWorld: _handleTap,
                onDoubleTapWorld: _handleDoubleTap,
                onLongPressWorld: _handleLongPress,
                onDragStartWorld: _handleDragStart,
                onDragUpdateWorld: _handleDragUpdate,
                onDragEndWorld: _handleDragEnd,
                onHoverWorld: _handleHover,
                onHoverExitWorld: _handleHoverExit,
              ),
            ),

            // Mini-map
            if (_showMiniMap)
              Positioned(
                bottom: 80,
                right: 16,
                child: _MiniMap(
                  controller: _controller,
                  onNavigate: (worldPos) {
                    // Animate to tapped position on mini-map
                    _controller.animateTo(
                      pan:
                          -worldPos * _controller.zoom +
                          Offset(
                            _controller.viewportSize!.width / 2,
                            _controller.viewportSize!.height / 2,
                          ),
                    );
                  },
                ),
              ),

            // Mode switcher
            Positioned(
              top: 16,
              left: 16,
              child: _ModeSwitcher(
                currentMode: _mode,
                onModeChanged: (mode) => setState(() => _mode = mode),
              ),
            ),

            // Motion indicator
            Positioned(
              top: 70,
              left: 16,
              child: _MotionIndicator(controller: _controller),
            ),

            // Control panel
            Positioned(
              top: 16,
              right: 16,
              child: _ControlPanel(
                controller: _controller,
                showDebugLayer: _showDebugLayer,
                showMiniMap: _showMiniMap,
                snapToGrid: _snapToGrid,
                onToggleDebug:
                    () => setState(() => _showDebugLayer = !_showDebugLayer),
                onToggleMiniMap:
                    () => setState(() => _showMiniMap = !_showMiniMap),
                onToggleSnap: () => setState(() => _snapToGrid = !_snapToGrid),
              ),
            ),

            // Zoom slider
            Positioned(
              right: 16,
              top: 200,
              bottom: 200,
              child: _ZoomSlider(controller: _controller),
            ),

            // Info panel
            Positioned(
              bottom: 16,
              left: 16,
              child: _InfoPanel(controller: _controller),
            ),

            // Instructions
            const Positioned(bottom: 16, right: 200, child: _Instructions()),
          ],
        ),
      ),
    );
  }

  //───────────────────────────────────────────────────────────────────────────
  // Keyboard Shortcuts
  //───────────────────────────────────────────────────────────────────────────

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final state = context.read<EditorState>();

    switch (event.logicalKey) {
      // Zoom
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.add:
        _controller.zoomIn();
        break;
      case LogicalKeyboardKey.minus:
        _controller.zoomOut();
        break;
      case LogicalKeyboardKey.digit0:
        _controller.resetZoom(); // Reset to 100%
        break;
      case LogicalKeyboardKey.digit1:
        if (HardwareKeyboard.instance.isMetaPressed) {
          _controller.setZoom(1.0); // Cmd+1 = 100%
        }
        break;

      // Pan with arrow keys
      case LogicalKeyboardKey.arrowLeft:
        _controller.panBy(const Offset(50, 0));
        break;
      case LogicalKeyboardKey.arrowRight:
        _controller.panBy(const Offset(-50, 0));
        break;
      case LogicalKeyboardKey.arrowUp:
        _controller.panBy(const Offset(0, 50));
        break;
      case LogicalKeyboardKey.arrowDown:
        _controller.panBy(const Offset(0, -50));
        break;

      // Delete selected
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        for (final id in state.selectedIds.toList()) {
          state.deleteNode(id);
        }
        break;

      // Select all
      case LogicalKeyboardKey.keyA:
        if (HardwareKeyboard.instance.isMetaPressed) {
          state.selectAll();
        }
        break;

      // Escape to deselect
      case LogicalKeyboardKey.escape:
        state.deselectAll();
        _marqueeStart = null;
        _marqueeEnd = null;
        break;

      // Focus on selection
      case LogicalKeyboardKey.keyF:
        if (state.selectedIds.isNotEmpty) {
          final bounds = state.selectedNodesBounds;
          if (bounds != null) {
            _controller.focusOn(bounds);
          }
        } else {
          final allBounds = state.allNodesBounds;
          if (allBounds != null) {
            _controller.focusOn(allBounds);
          }
        }
        break;
    }
  }

  //───────────────────────────────────────────────────────────────────────────
  // Content Layer
  //───────────────────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, InfiniteCanvasController ctrl) {
    final state = context.watch<EditorState>();
    final viewportSize = MediaQuery.sizeOf(context);

    final visibleNodes =
        ctrl
            .cullToVisible(
              state.nodes.values,
              (node) => node.bounds,
              viewportSize,
            )
            .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Connection lines (drawn first, behind nodes)
        _buildConnections(state, ctrl),

        // Nodes
        ...visibleNodes.map((node) {
          final isSelected = state.selectedIds.contains(node.id);
          final isHovered = state.hoveredId == node.id;

          return CanvasItem(
            key: ValueKey(node.id),
            position: node.position,
            size: node.size,
            child: _NodeWidget(
              node: node,
              isSelected: isSelected,
              isHovered: isHovered,
            ),
          );
        }),
      ],
    );
  }

  /// Build connection lines between nodes
  Widget _buildConnections(EditorState state, InfiniteCanvasController ctrl) {
    // Collect visible connections
    final visibleConnections = <_ConnectionData>[];

    for (final conn in state.connections) {
      final fromNode = state.nodes[conn.fromId];
      final toNode = state.nodes[conn.toId];
      if (fromNode == null || toNode == null) continue;

      // Check if either endpoint is visible (cull connections too)
      if (!ctrl.isWorldRectVisible(fromNode.bounds) &&
          !ctrl.isWorldRectVisible(toNode.bounds)) {
        continue;
      }

      visibleConnections.add(
        _ConnectionData(
          from: fromNode.bounds.center,
          to: toNode.bounds.center,
          color: conn.color,
        ),
      );
    }

    if (visibleConnections.isEmpty) {
      return const SizedBox.shrink();
    }

    // Draw all connections in a single painter using SizedBox.expand
    return SizedBox.expand(
      child: CustomPaint(
        painter: _ConnectionsPainter(connections: visibleConnections),
      ),
    );
  }

  //───────────────────────────────────────────────────────────────────────────
  // Overlay Layer (screen-space)
  //───────────────────────────────────────────────────────────────────────────

  Widget _buildOverlay(BuildContext context, InfiniteCanvasController ctrl) {
    final state = context.watch<EditorState>();

    return ListenableBuilder(
      listenable: ctrl.isInMotionListenable,
      builder: (context, _) {
        if (ctrl.isInMotion) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Marquee selection rectangle
            if (_marqueeStart != null && _marqueeEnd != null)
              _MarqueeRect(
                start: ctrl.worldToView(_marqueeStart!),
                end: ctrl.worldToView(_marqueeEnd!),
              ),

            // Selection indicators with zoom-independent handles
            for (final id in state.selectedIds)
              if (state.nodes.containsKey(id))
                _SelectionIndicator(node: state.nodes[id]!, controller: ctrl),
          ],
        );
      },
    );
  }

  //───────────────────────────────────────────────────────────────────────────
  // Debug Layer
  //───────────────────────────────────────────────────────────────────────────

  Widget _buildDebugLayer(BuildContext context, InfiniteCanvasController ctrl) {
    final viewportSize = MediaQuery.sizeOf(context);

    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final visibleBounds = ctrl.getVisibleWorldBounds(viewportSize);
        final center = ctrl.visibleWorldCenter ?? Offset.zero;
        final centerScreen = ctrl.worldToView(center);

        // Show coordinate at cursor (if hovering)
        final state = context.read<EditorState>();
        final hoveredNode =
            state.hoveredId != null ? state.nodes[state.hoveredId] : null;

        return Stack(
          children: [
            // Center crosshair
            Positioned(
              left: centerScreen.dx - 10,
              top: centerScreen.dy - 1,
              child: Container(
                width: 20,
                height: 2,
                color: Colors.red.withValues(alpha: 0.5),
              ),
            ),
            Positioned(
              left: centerScreen.dx - 1,
              top: centerScreen.dy - 10,
              child: Container(
                width: 2,
                height: 20,
                color: Colors.red.withValues(alpha: 0.5),
              ),
            ),

            // Visible bounds info
            Positioned(
              top: 130,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Visible World:\n'
                  '  (${visibleBounds.left.toStringAsFixed(0)}, ${visibleBounds.top.toStringAsFixed(0)}) →\n'
                  '  (${visibleBounds.right.toStringAsFixed(0)}, ${visibleBounds.bottom.toStringAsFixed(0)})\n'
                  'Center: (${center.dx.toStringAsFixed(0)}, ${center.dy.toStringAsFixed(0)})\n'
                  'Transform: scale=${ctrl.zoom.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Colors.red,
                  ),
                ),
              ),
            ),

            // Hovered node coordinate debug
            if (hoveredNode != null)
              Builder(
                builder: (context) {
                  final screenPos = ctrl.worldToView(hoveredNode.position);
                  final screenSize = ctrl.worldToViewSize(hoveredNode.size);
                  return Positioned(
                    left: screenPos.dx,
                    top: screenPos.dy - 60,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'World: (${hoveredNode.position.dx.toInt()}, ${hoveredNode.position.dy.toInt()})\n'
                        'Screen: (${screenPos.dx.toInt()}, ${screenPos.dy.toInt()})\n'
                        'Size W: ${hoveredNode.size.width.toInt()}×${hoveredNode.size.height.toInt()}\n'
                        'Size S: ${screenSize.width.toInt()}×${screenSize.height.toInt()}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  //───────────────────────────────────────────────────────────────────────────
  // Gesture Handlers
  //───────────────────────────────────────────────────────────────────────────

  void _handleTap(Offset worldPos) {
    final state = context.read<EditorState>();
    final hitNode = state.hitTest(worldPos);

    if (hitNode != null) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        // Shift+click: toggle selection
        state.toggleSelection(hitNode.id);
      } else {
        state.select(hitNode.id);
      }
    } else {
      state.deselectAll();
    }
  }

  void _handleDoubleTap(Offset worldPos) {
    final state = context.read<EditorState>();
    final hitNode = state.hitTest(worldPos);

    if (hitNode != null) {
      _controller.focusOn(hitNode.bounds, padding: const EdgeInsets.all(100));
    } else {
      final snapped = _snapToGrid ? _snapOffset(worldPos, 25) : worldPos;
      state.addNodeAt(snapped);
    }
  }

  void _handleLongPress(Offset worldPos) {
    final state = context.read<EditorState>();
    final hitNode = state.hitTest(worldPos);

    if (hitNode != null) {
      // Show context menu (simplified: just delete)
      state.deleteNode(hitNode.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted ${hitNode.label}'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _handleDragStart(CanvasDragStartDetails details) {
    final state = context.read<EditorState>();
    final hitNode = state.hitTest(details.worldPosition);

    if (hitNode != null) {
      // Dragging a node
      if (!state.selectedIds.contains(hitNode.id)) {
        state.select(hitNode.id);
      }
      state.startDrag();
    } else {
      // Start marquee selection
      _marqueeStart = details.worldPosition;
      _marqueeEnd = details.worldPosition;
      setState(() {});
    }
  }

  void _handleDragUpdate(CanvasDragUpdateDetails details) {
    final state = context.read<EditorState>();

    if (state.isDragging) {
      // Moving nodes with proper snap-to-grid
      state.updateDrag(
        details.worldDelta,
        gridSize: _snapToGrid ? 25.0 : null,
        // Use absolute snapping for single selection, relative for multi
        snapToAbsolute: _snapToGrid && state.selectedIds.length == 1,
      );
    } else if (_marqueeStart != null) {
      // Updating marquee
      _marqueeEnd = details.worldPosition;

      // Select nodes within marquee
      final rect = Rect.fromPoints(_marqueeStart!, _marqueeEnd!);
      state.selectInRect(rect);

      setState(() {});
    }
  }

  void _handleDragEnd(CanvasDragEndDetails details) {
    final state = context.read<EditorState>();

    if (state.isDragging) {
      state.endDrag();

      // Log velocity for demo
      if (details.velocity.distance > 500) {
        debugPrint(
          'Fast drag! Velocity: ${details.velocity.distance.toStringAsFixed(0)} px/s',
        );
      }
    }

    // Clear marquee
    _marqueeStart = null;
    _marqueeEnd = null;
    setState(() {});
  }

  void _handleHover(Offset worldPos) {
    final state = context.read<EditorState>();
    final hitNode = state.hitTest(worldPos);
    state.setHovered(hitNode?.id);
  }

  void _handleHoverExit() {
    context.read<EditorState>().setHovered(null);
  }

  Offset _snapOffset(Offset offset, double gridSize) {
    return Offset(
      (offset.dx / gridSize).round() * gridSize,
      (offset.dy / gridSize).round() * gridSize,
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Mode Switcher
//─────────────────────────────────────────────────────────────────────────────

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.currentMode, required this.onModeChanged});

  final EditorMode currentMode;
  final ValueChanged<EditorMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            EditorMode.values.map((mode) {
              final isActive = mode == currentMode;
              return Tooltip(
                message: mode.label,
                child: Material(
                  color:
                      isActive
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: () => onModeChanged(mode),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        mode.icon,
                        size: 18,
                        color: isActive ? Colors.blue : Colors.white54,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Zoom Slider
//─────────────────────────────────────────────────────────────────────────────

class _ZoomSlider extends StatelessWidget {
  const _ZoomSlider({required this.controller});

  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Convert zoom to slider value (logarithmic scale for better UX)
        final zoomLog = math.log(controller.zoom) / math.log(10);
        final minLog = math.log(0.1) / math.log(10);
        final maxLog = math.log(5.0) / math.log(10);
        final sliderValue = (zoomLog - minLog) / (maxLog - minLog);

        return Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: () => controller.zoomIn(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.white70,
              ),
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Slider(
                    value: sliderValue.clamp(0.0, 1.0),
                    onChanged: (value) {
                      // Convert back from slider to zoom
                      final newZoomLog = minLog + value * (maxLog - minLog);
                      final newZoom = math.pow(10, newZoomLog).toDouble();
                      controller.setZoom(newZoom);
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: () => controller.zoomOut(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                '${(controller.zoom * 100).toInt()}%',
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Mini-Map
//─────────────────────────────────────────────────────────────────────────────

class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.controller, required this.onNavigate});

  final InfiniteCanvasController controller;
  final ValueChanged<Offset> onNavigate;

  static const double mapSize = 150;
  static const double worldRange = 2000; // -1000 to 1000

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: (details) {
            // Convert mini-map tap to world position
            final localPos = details.localPosition;
            final worldX = (localPos.dx / mapSize - 0.5) * worldRange;
            final worldY = (localPos.dy / mapSize - 0.5) * worldRange;
            onNavigate(Offset(worldX, worldY));
          },
          child: Container(
            width: mapSize,
            height: mapSize,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CustomPaint(
                painter: _MiniMapPainter(
                  controller: controller,
                  nodes: state.nodes.values.toList(),
                  worldRange: worldRange,
                ),
                size: const Size(mapSize, mapSize),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.controller,
    required this.nodes,
    required this.worldRange,
  });

  final InfiniteCanvasController controller;
  final List<EditorNode> nodes;
  final double worldRange;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / worldRange;
    final offset = Offset(size.width / 2, size.height / 2);

    // Draw grid
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..strokeWidth = 0.5;

    for (var i = -1000; i <= 1000; i += 200) {
      final x = i * scale + offset.dx;
      final y = i * scale + offset.dy;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw origin
    final originPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(offset.dx, 0),
      Offset(offset.dx, size.height),
      originPaint,
    );
    canvas.drawLine(
      Offset(0, offset.dy),
      Offset(size.width, offset.dy),
      originPaint,
    );

    // Draw nodes
    final nodePaint = Paint();
    for (final node in nodes) {
      nodePaint.color = node.color.withValues(alpha: 0.8);
      final rect = Rect.fromLTWH(
        node.position.dx * scale + offset.dx,
        node.position.dy * scale + offset.dy,
        node.size.width * scale,
        node.size.height * scale,
      );
      canvas.drawRect(rect, nodePaint);
    }

    // Draw viewport rectangle
    if (controller.viewportSize != null) {
      final viewportWorld = controller.getVisibleWorldBounds(
        controller.viewportSize!,
      );
      final viewportPaint =
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;

      final viewportRect = Rect.fromLTWH(
        viewportWorld.left * scale + offset.dx,
        viewportWorld.top * scale + offset.dy,
        viewportWorld.width * scale,
        viewportWorld.height * scale,
      );
      canvas.drawRect(viewportRect, viewportPaint);
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => true;
}

//─────────────────────────────────────────────────────────────────────────────
// Marquee Selection Rectangle
//─────────────────────────────────────────────────────────────────────────────

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
            color: Colors.blue.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Connection Line Painter
//─────────────────────────────────────────────────────────────────────────────

/// Data for a single connection line
class _ConnectionData {
  const _ConnectionData({
    required this.from,
    required this.to,
    required this.color,
  });

  final Offset from;
  final Offset to;
  final Color color;
}

/// Paints all connection lines in a single CustomPainter
class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({required this.connections});

  final List<_ConnectionData> connections;

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      _paintConnection(canvas, conn);
    }
  }

  void _paintConnection(Canvas canvas, _ConnectionData conn) {
    final paint =
        Paint()
          ..color = conn.color.withValues(alpha: 0.6)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    // Draw curved line
    final midX = (conn.from.dx + conn.to.dx) / 2;
    final path =
        Path()
          ..moveTo(conn.from.dx, conn.from.dy)
          ..cubicTo(
            midX,
            conn.from.dy,
            midX,
            conn.to.dy,
            conn.to.dx,
            conn.to.dy,
          );

    canvas.drawPath(path, paint);

    // Draw arrow head
    final arrowPaint =
        Paint()
          ..color = conn.color.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill;

    final direction = (conn.to - Offset(midX, conn.to.dy)).direction;
    const arrowSize = 8.0;
    final arrowPath =
        Path()
          ..moveTo(conn.to.dx, conn.to.dy)
          ..lineTo(
            conn.to.dx - arrowSize * math.cos(direction - 0.4),
            conn.to.dy - arrowSize * math.sin(direction - 0.4),
          )
          ..lineTo(
            conn.to.dx - arrowSize * math.cos(direction + 0.4),
            conn.to.dy - arrowSize * math.sin(direction + 0.4),
          )
          ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(_ConnectionsPainter old) {
    if (connections.length != old.connections.length) return true;
    for (int i = 0; i < connections.length; i++) {
      final a = connections[i];
      final b = old.connections[i];
      if (a.from != b.from || a.to != b.to || a.color != b.color) return true;
    }
    return false;
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Selection Indicator (using zoom-independent handle sizing)
//─────────────────────────────────────────────────────────────────────────────

class _SelectionIndicator extends StatelessWidget {
  const _SelectionIndicator({required this.node, required this.controller});

  final EditorNode node;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final screenRect = controller.worldToViewRect(node.bounds);

    // Use viewToWorldSize to get zoom-independent handle size
    // Handles are always 8x8 screen pixels regardless of zoom
    const handleScreenSize = 8.0;

    return Stack(
      children: [
        // Selection border
        Positioned(
          left: screenRect.left - 4,
          top: screenRect.top - 4,
          width: screenRect.width + 8,
          height: screenRect.height + 8,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade400, width: 2),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        // Corner handles
        _Handle(x: screenRect.left, y: screenRect.top, size: handleScreenSize),
        _Handle(x: screenRect.right, y: screenRect.top, size: handleScreenSize),
        _Handle(
          x: screenRect.left,
          y: screenRect.bottom,
          size: handleScreenSize,
        ),
        _Handle(
          x: screenRect.right,
          y: screenRect.bottom,
          size: handleScreenSize,
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.x, required this.y, required this.size});

  final double x;
  final double y;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade400, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Rest of widgets (Motion Indicator, Node Widget, Control Panel, etc.)
// ... [Keep existing implementations from original]
//─────────────────────────────────────────────────────────────────────────────

class _MotionIndicator extends StatelessWidget {
  const _MotionIndicator({required this.controller});
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.isInMotionListenable,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MotionDot(
                label: 'PAN',
                listenable: controller.isPanning,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _MotionDot(
                label: 'ZOOM',
                listenable: controller.isZooming,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _MotionDot(
                label: 'ANIM',
                listenable: controller.isAnimating,
                color: Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MotionDot extends StatelessWidget {
  const _MotionDot({
    required this.label,
    required this.listenable,
    required this.color,
  });
  final String label;
  final ValueListenable<bool> listenable;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, active, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? color : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: active ? color : Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({
    required this.node,
    required this.isSelected,
    required this.isHovered,
  });
  final EditorNode node;
  final bool isSelected;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: node.color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSelected
                  ? Colors.white
                  : isHovered
                  ? Colors.white54
                  : Colors.white24,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              node.icon,
              size: 32,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 8),
            Text(
              node.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.controller,
    required this.showDebugLayer,
    required this.showMiniMap,
    required this.snapToGrid,
    required this.onToggleDebug,
    required this.onToggleMiniMap,
    required this.onToggleSnap,
  });

  final InfiniteCanvasController controller;
  final bool showDebugLayer;
  final bool showMiniMap;
  final bool snapToGrid;
  final VoidCallback onToggleDebug;
  final VoidCallback onToggleMiniMap;
  final VoidCallback onToggleSnap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToggleButton(
                icon: Icons.grid_on,
                isActive: snapToGrid,
                onPressed: onToggleSnap,
                tooltip: 'Snap to Grid',
              ),
              const SizedBox(width: 8),
              _ToggleButton(
                icon: Icons.map,
                isActive: showMiniMap,
                onPressed: onToggleMiniMap,
                tooltip: 'Mini-map',
              ),
              const SizedBox(width: 8),
              _ToggleButton(
                icon: Icons.bug_report,
                isActive: showDebugLayer,
                onPressed: onToggleDebug,
                tooltip: 'Debug',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: Icons.center_focus_strong,
                onPressed: () {
                  final state = context.read<EditorState>();
                  final bounds = state.allNodesBounds;
                  if (bounds != null) controller.focusOn(bounds);
                },
                tooltip: 'Focus All (F)',
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.restart_alt,
                onPressed: () {
                  final state = context.read<EditorState>();
                  final bounds = state.allNodesBounds;
                  if (bounds != null) {
                    // Center on content at 100% zoom
                    controller.animateToCenterOn(bounds.center, zoom: 1.0);
                  } else {
                    controller.reset(); // No content, go to origin
                  }
                },
                tooltip: 'Reset View',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.tooltip,
  });
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color:
            isActive
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? Colors.blue : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: Colors.white70),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.controller});
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.white70,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Zoom: ${(controller.zoom * 100).toStringAsFixed(0)}%'),
                Text(
                  'Pan: (${controller.pan.dx.toInt()}, ${controller.pan.dy.toInt()})',
                ),
                Text(
                  'Nodes: ${state.nodes.length} | Selected: ${state.selectedIds.length}',
                ),
                Text('Connections: ${state.connections.length}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const DefaultTextStyle(
        style: TextStyle(fontSize: 10, color: Colors.white60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Scroll/Trackpad → Pan | Cmd+Scroll → Zoom'),
            Text('Space+Drag → Pan | +/- → Zoom | 0 → 100%'),
            Text('Click → Select | Shift+Click → Multi-select'),
            Text('Drag empty → Marquee select'),
            Text('F → Focus | Delete → Remove | Cmd+A → All'),
          ],
        ),
      ),
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Editor State (Enhanced with connections and multi-select)
//─────────────────────────────────────────────────────────────────────────────

class Connection {
  final String fromId;
  final String toId;
  final Color color;

  const Connection({
    required this.fromId,
    required this.toId,
    required this.color,
  });
}

class EditorNode {
  final String id;
  final Offset position;
  final Size size;
  final Color color;
  final IconData icon;
  final String label;

  const EditorNode({
    required this.id,
    required this.position,
    required this.size,
    required this.color,
    required this.icon,
    required this.label,
  });

  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

  EditorNode copyWith({Offset? position, Size? size}) {
    return EditorNode(
      id: id,
      position: position ?? this.position,
      size: size ?? this.size,
      color: color,
      icon: icon,
      label: label,
    );
  }
}

class EditorState extends ChangeNotifier {
  final Map<String, EditorNode> nodes = {};
  final Set<String> selectedIds = {};
  final List<Connection> connections = [];
  String? hoveredId;
  bool isDragging = false;

  // Drag state for proper snap-to-grid
  Map<String, Offset> _dragStartPositions = {};
  Offset _dragAccumulator = Offset.zero;

  void addInitialNodes() {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
    ];
    final icons = [
      Icons.widgets,
      Icons.dashboard,
      Icons.grid_view,
      Icons.apps,
      Icons.view_module,
    ];
    final labels = ['Widget A', 'Widget B', 'Widget C', 'Widget D', 'Widget E'];

    for (int i = 0; i < 5; i++) {
      final node = EditorNode(
        id: 'node-$i',
        position: Offset(i * 200.0, (i % 2) * 150.0),
        size: const Size(150, 120),
        color: colors[i],
        icon: icons[i],
        label: labels[i],
      );
      nodes[node.id] = node;
    }

    // Add some connections
    connections.addAll([
      Connection(fromId: 'node-0', toId: 'node-1', color: Colors.blue),
      Connection(fromId: 'node-1', toId: 'node-2', color: Colors.purple),
      Connection(fromId: 'node-2', toId: 'node-3', color: Colors.teal),
      Connection(fromId: 'node-3', toId: 'node-4', color: Colors.orange),
    ]);

    notifyListeners();
  }

  void addNodeAt(Offset position) {
    final random = math.Random();
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.green,
    ];
    final icons = [
      Icons.star,
      Icons.favorite,
      Icons.bolt,
      Icons.rocket_launch,
      Icons.auto_awesome,
    ];

    final id = 'node-${DateTime.now().millisecondsSinceEpoch}';
    final size = Size(
      120 + random.nextDouble() * 60,
      100 + random.nextDouble() * 40,
    );
    final node = EditorNode(
      id: id,
      position: Offset(
        position.dx - size.width / 2,
        position.dy - size.height / 2,
      ),
      size: size,
      color: colors[random.nextInt(colors.length)],
      icon: icons[random.nextInt(icons.length)],
      label: 'Node ${nodes.length + 1}',
    );
    nodes[node.id] = node;
    select(id);
    notifyListeners();
  }

  void deleteNode(String id) {
    nodes.remove(id);
    selectedIds.remove(id);
    connections.removeWhere((c) => c.fromId == id || c.toId == id);
    if (hoveredId == id) hoveredId = null;
    notifyListeners();
  }

  EditorNode? hitTest(Offset worldPos) {
    for (final node in nodes.values.toList().reversed) {
      if (node.bounds.contains(worldPos)) return node;
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

  void selectAll() {
    selectedIds.clear();
    selectedIds.addAll(nodes.keys);
    notifyListeners();
  }

  void selectInRect(Rect rect) {
    selectedIds.clear();
    for (final node in nodes.values) {
      if (rect.overlaps(node.bounds)) {
        selectedIds.add(node.id);
      }
    }
    notifyListeners();
  }

  void deselectAll() {
    selectedIds.clear();
    notifyListeners();
  }

  void setHovered(String? id) {
    if (hoveredId != id) {
      hoveredId = id;
      notifyListeners();
    }
  }

  void startDrag() {
    isDragging = true;
    _dragAccumulator = Offset.zero;

    // Snapshot starting positions for all selected nodes
    _dragStartPositions = {
      for (final id in selectedIds)
        if (nodes.containsKey(id)) id: nodes[id]!.position,
    };
  }

  void endDrag() {
    isDragging = false;
    _dragStartPositions.clear();
    _dragAccumulator = Offset.zero;
  }

  /// Update drag with proper snap-to-grid support.
  ///
  /// If [gridSize] is provided, snaps the TOTAL movement to grid increments,
  /// not the per-frame delta. This ensures nodes land on grid positions.
  ///
  /// If [snapToAbsolute] is true, each node snaps to the nearest absolute
  /// grid position (like Figma). If false (default), nodes move together
  /// in grid increments, preserving their relative positions.
  void updateDrag(
    Offset worldDelta, {
    double? gridSize,
    bool snapToAbsolute = false,
  }) {
    if (!isDragging || _dragStartPositions.isEmpty) return;

    // Accumulate total movement since drag started
    _dragAccumulator += worldDelta;

    for (final entry in _dragStartPositions.entries) {
      final node = nodes[entry.key];
      if (node == null) continue;

      var newPosition = entry.value + _dragAccumulator;

      if (gridSize != null && gridSize > 0) {
        if (snapToAbsolute) {
          // Snap to absolute grid positions
          newPosition = Offset(
            (newPosition.dx / gridSize).round() * gridSize,
            (newPosition.dy / gridSize).round() * gridSize,
          );
        } else {
          // Snap movement to grid increments (preserves relative positions)
          final snappedMovement = Offset(
            (_dragAccumulator.dx / gridSize).round() * gridSize,
            (_dragAccumulator.dy / gridSize).round() * gridSize,
          );
          newPosition = entry.value + snappedMovement;
        }
      }

      nodes[entry.key] = node.copyWith(position: newPosition);
    }

    notifyListeners();
  }

  /// Move selected nodes by delta (no snapping, for backwards compat).
  void moveSelectedBy(Offset delta) {
    for (final id in selectedIds) {
      final node = nodes[id];
      if (node != null) {
        nodes[id] = node.copyWith(position: node.position + delta);
      }
    }
    notifyListeners();
  }

  Rect? get allNodesBounds {
    if (nodes.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final node in nodes.values) {
      minX = math.min(minX, node.bounds.left);
      minY = math.min(minY, node.bounds.top);
      maxX = math.max(maxX, node.bounds.right);
      maxY = math.max(maxY, node.bounds.bottom);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect? get selectedNodesBounds {
    if (selectedIds.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final id in selectedIds) {
      final node = nodes[id];
      if (node != null) {
        minX = math.min(minX, node.bounds.left);
        minY = math.min(minY, node.bounds.top);
        maxX = math.max(maxX, node.bounds.right);
        maxY = math.max(maxY, node.bounds.bottom);
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
