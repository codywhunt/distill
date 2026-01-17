import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:distill_canvas/infinite_canvas.dart';

import '../../shared/theme.dart';
import '../../shared/ui.dart';
import 'storyboard_state.dart';

/// Storyboard Example
///
/// Demonstrates page flow viewing with:
/// - Multiple screen nodes
/// - Bezier curve connections
/// - Click to select, double-click to focus
/// - Drag to rearrange
/// - Simple auto-layout
/// - Minimap navigation
class StoryboardExample extends StatelessWidget {
  const StoryboardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StoryboardState()..addInitialScreens(),
      child: const _StoryboardCanvas(),
    );
  }
}

class _StoryboardCanvas extends StatefulWidget {
  const _StoryboardCanvas();

  @override
  State<_StoryboardCanvas> createState() => _StoryboardCanvasState();
}

class _StoryboardCanvasState extends State<_StoryboardCanvas> {
  final _controller = InfiniteCanvasController();
  final _focusNode = FocusNode();

  bool _showMinimap = true;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<StoryboardState>();

    return Column(
      children: [
        // Header
        const ExampleHeader(
          title: 'Storyboard',
          description: 'page flow visualization',
          features: ['connections', 'focusOn', 'minimap'],
        ),

        // Toolbar
        _Toolbar(
          onAutoLayout: state.autoLayout,
          onAddScreen: () {
            final center = _controller.visibleWorldCenter;
            if (center != null) {
              state.addScreenAt(center);
            }
          },
          onFocusAll: () {
            final bounds = state.allScreensBounds;
            if (bounds != null) {
              _controller.focusOn(bounds, padding: const EdgeInsets.all(80));
            }
          },
          showMinimap: _showMinimap,
          onMinimapToggle: () => setState(() => _showMinimap = !_showMinimap),
          onDelete: state.selectedIds.isNotEmpty ? state.deleteSelected : null,
        ),

        // Canvas + Minimap
        Expanded(
          child: Stack(
            children: [
              // Canvas
              KeyboardListener(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: _handleKeyEvent,
                child: InfiniteCanvas(
                  controller: _controller,
                  backgroundColor: AppTheme.background,
                  initialViewport: InitialViewport.fitContent(
                    () => state.allScreensBounds,
                    padding: const EdgeInsets.all(80),
                    maxZoom: 1.0,
                    fallback: const InitialViewport.centerOrigin(),
                  ),
                  physicsConfig: const CanvasPhysicsConfig(
                    minZoom: 0.1,
                    maxZoom: 3.0,
                  ),
                  layers: CanvasLayers(
                    background:
                        (ctx, ctrl) => DotBackground(
                          controller: ctrl,
                          spacing: 40,
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                    content: (ctx, ctrl) => _buildContent(state, ctrl),
                  ),
                  onTapWorld: (pos) => _handleTap(pos, state),
                  onDoubleTapWorld: (pos) => _handleDoubleTap(pos, state),
                  onDragStartWorld: (d) => _handleDragStart(d, state),
                  onDragUpdateWorld: (d) => _handleDragUpdate(d, state),
                  onDragEndWorld: (d) => _handleDragEnd(d, state),
                ),
              ),

              // Minimap
              if (_showMinimap)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: _Minimap(controller: _controller, state: state),
                ),
            ],
          ),
        ),

        // Status bar
        _StatusBar(controller: _controller, state: state),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content Layer
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent(StoryboardState state, InfiniteCanvasController ctrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Connections (render first, behind screens)
        _ConnectionsLayer(state: state),

        // Screen nodes
        for (final screen in state.screens.values)
          CanvasItem(
            key: ValueKey(screen.id),
            position: screen.position,
            child: _ScreenNodeWidget(
              screen: screen,
              isSelected: state.selectedIds.contains(screen.id),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Gesture Handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _handleTap(Offset worldPos, StoryboardState state) {
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

  void _handleDoubleTap(Offset worldPos, StoryboardState state) {
    final hit = state.hitTest(worldPos);

    if (hit != null) {
      // Focus on double-tapped screen
      _controller.focusOn(hit.bounds, padding: const EdgeInsets.all(150));
    } else {
      // Add new screen at tap position
      state.addScreenAt(worldPos);
    }
  }

  void _handleDragStart(CanvasDragStartDetails details, StoryboardState state) {
    final hit = state.hitTest(details.worldPosition);

    if (hit != null) {
      if (!state.selectedIds.contains(hit.id)) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          state.addToSelection(hit.id);
        } else {
          state.select(hit.id);
        }
      }
      state.startDrag();
    }
  }

  void _handleDragUpdate(
    CanvasDragUpdateDetails details,
    StoryboardState state,
  ) {
    if (state.isDragging) {
      state.updateDrag(details.worldDelta);
    }
  }

  void _handleDragEnd(CanvasDragEndDetails details, StoryboardState state) {
    if (state.isDragging) {
      state.endDrag();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final state = context.read<StoryboardState>();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        state.deleteSelected();
        break;
      case LogicalKeyboardKey.escape:
        state.deselectAll();
        break;
      case LogicalKeyboardKey.keyF:
        final bounds = state.allScreensBounds;
        if (bounds != null) {
          _controller.focusOn(bounds, padding: const EdgeInsets.all(80));
        }
        break;
      case LogicalKeyboardKey.keyL:
        state.autoLayout();
        break;
      case LogicalKeyboardKey.keyM:
        setState(() => _showMinimap = !_showMinimap);
        break;
      default:
        break;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onAutoLayout,
    required this.onAddScreen,
    required this.onFocusAll,
    required this.showMinimap,
    required this.onMinimapToggle,
    this.onDelete,
  });

  final VoidCallback onAutoLayout;
  final VoidCallback onAddScreen;
  final VoidCallback onFocusAll;
  final bool showMinimap;
  final VoidCallback onMinimapToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Toolbar(
      children: [
        ToolbarButton(
          icon: Icons.auto_fix_high,
          tooltip: 'Auto Layout (L)',
          onPressed: onAutoLayout,
        ),
        ToolbarButton(
          icon: Icons.add_box_outlined,
          tooltip: 'Add Screen',
          onPressed: onAddScreen,
        ),
        ToolbarButton(
          icon: Icons.fit_screen,
          tooltip: 'Focus All (F)',
          onPressed: onFocusAll,
        ),

        const ToolbarDivider(),

        ToolbarButton(
          icon: Icons.map_outlined,
          tooltip: 'Toggle Minimap (M)',
          isActive: showMinimap,
          onPressed: onMinimapToggle,
        ),

        const ToolbarDivider(),

        ToolbarButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete (⌫)',
          onPressed: onDelete ?? () {},
        ),

        const Spacer(),

        const Text(
          'dbl-click: add/focus  drag: move',
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
// Screen Node Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ScreenNodeWidget extends StatelessWidget {
  const _ScreenNodeWidget({required this.screen, required this.isSelected});

  final ScreenNode screen;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ScreenNode.size.width,
      height: ScreenNode.size.height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? AppTheme.textSecondary : AppTheme.borderSubtle,
          width: isSelected ? 1 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Screen preview area
          Expanded(
            child: Container(
              color: screen.color.withValues(alpha: 0.15),
              child: Center(
                child: Icon(
                  _iconForType(screen.type),
                  size: 24,
                  color: screen.color.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),

          // Screen name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceLight,
              border: Border(
                top: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: screen.color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    screen.name.toLowerCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: AppTheme.fontMono,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(ScreenType type) {
    return switch (type) {
      ScreenType.entry => Icons.login,
      ScreenType.main => Icons.home_outlined,
      ScreenType.detail => Icons.article_outlined,
      ScreenType.modal => Icons.open_in_new,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connections Layer
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionsLayer extends StatelessWidget {
  const _ConnectionsLayer({required this.state});

  final StoryboardState state;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ConnectionsPainter(
        connections: state.connections,
        screens: state.screens,
      ),
    );
  }
}

class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({required this.connections, required this.screens});

  final List<ScreenConnection> connections;
  final Map<String, ScreenNode> screens;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final arrowPaint = Paint()..style = PaintingStyle.fill;

    for (final conn in connections) {
      final from = screens[conn.fromId];
      final to = screens[conn.toId];
      if (from == null || to == null) continue;

      // Determine connection direction
      final fromRight = from.rightEdge;
      final toLeft = to.leftEdge;

      // Choose color based on source screen
      final color = from.color.withValues(alpha: 0.6);
      paint.color = color;
      arrowPaint.color = color;

      // Draw bezier curve
      final path = Path();
      path.moveTo(fromRight.dx, fromRight.dy);

      // Control points for smooth curve
      final dx = (toLeft.dx - fromRight.dx).abs();
      final controlOffset = math.min(dx * 0.5, 100.0);

      path.cubicTo(
        fromRight.dx + controlOffset,
        fromRight.dy,
        toLeft.dx - controlOffset,
        toLeft.dy,
        toLeft.dx,
        toLeft.dy,
      );

      canvas.drawPath(path, paint);

      // Draw arrow head
      _drawArrowHead(canvas, toLeft, arrowPaint);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Paint paint) {
    const arrowSize = 8.0;
    final path = Path();
    path.moveTo(tip.dx, tip.dy);
    path.lineTo(tip.dx - arrowSize, tip.dy - arrowSize / 2);
    path.lineTo(tip.dx - arrowSize, tip.dy + arrowSize / 2);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConnectionsPainter oldDelegate) {
    return connections != oldDelegate.connections ||
        screens != oldDelegate.screens;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimap
// ─────────────────────────────────────────────────────────────────────────────

class _Minimap extends StatelessWidget {
  const _Minimap({required this.controller, required this.state});

  final InfiniteCanvasController controller;
  final StoryboardState state;

  static const mapSize = Size(140, 100);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: mapSize.width,
      height: mapSize.height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final worldBounds = state.allScreensBounds;
          if (worldBounds == null || worldBounds.isEmpty) {
            return const Center(
              child: Text(
                'empty',
                style: TextStyle(
                  fontSize: 9,
                  fontFamily: AppTheme.fontMono,
                  color: AppTheme.textSubtle,
                ),
              ),
            );
          }

          // Add padding to world bounds
          final paddedBounds = worldBounds.inflate(100);

          // Calculate scale to fit world in minimap
          final scaleX = mapSize.width / paddedBounds.width;
          final scaleY = mapSize.height / paddedBounds.height;
          final scale = math.min(scaleX, scaleY);

          return GestureDetector(
            onTapDown: (details) => _onMinimapTap(details, paddedBounds, scale),
            onPanUpdate:
                (details) => _onMinimapPan(details, paddedBounds, scale),
            child: CustomPaint(
              size: mapSize,
              painter: _MinimapPainter(
                screens: state.screens,
                connections: state.connections,
                worldBounds: paddedBounds,
                viewportBounds:
                    controller.viewportSize != null
                        ? controller.getVisibleWorldBounds(
                          controller.viewportSize!,
                        )
                        : null,
                scale: scale,
              ),
            ),
          );
        },
      ),
    );
  }

  void _onMinimapTap(TapDownDetails details, Rect worldBounds, double scale) {
    final localPos = details.localPosition;
    final worldPos = Offset(
      worldBounds.left + localPos.dx / scale,
      worldBounds.top + localPos.dy / scale,
    );
    controller.animateToCenterOn(worldPos);
  }

  void _onMinimapPan(
    DragUpdateDetails details,
    Rect worldBounds,
    double scale,
  ) {
    final worldDelta = Offset(
      details.delta.dx / scale,
      details.delta.dy / scale,
    );
    controller.panBy(-worldDelta * controller.zoom);
  }
}

class _MinimapPainter extends CustomPainter {
  _MinimapPainter({
    required this.screens,
    required this.connections,
    required this.worldBounds,
    required this.viewportBounds,
    required this.scale,
  });

  final Map<String, ScreenNode> screens;
  final List<ScreenConnection> connections;
  final Rect worldBounds;
  final Rect? viewportBounds;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections
    final connPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

    for (final conn in connections) {
      final from = screens[conn.fromId];
      final to = screens[conn.toId];
      if (from == null || to == null) continue;

      final fromPos = _worldToMinimap(from.center);
      final toPos = _worldToMinimap(to.center);
      canvas.drawLine(fromPos, toPos, connPaint);
    }

    // Draw screens
    for (final screen in screens.values) {
      final rect = Rect.fromLTWH(
        (screen.position.dx - worldBounds.left) * scale,
        (screen.position.dy - worldBounds.top) * scale,
        ScreenNode.size.width * scale,
        ScreenNode.size.height * scale,
      );

      final paint = Paint()..color = screen.color.withValues(alpha: 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }

    // Draw viewport indicator
    if (viewportBounds != null) {
      final vpRect = Rect.fromLTWH(
        (viewportBounds!.left - worldBounds.left) * scale,
        (viewportBounds!.top - worldBounds.top) * scale,
        viewportBounds!.width * scale,
        viewportBounds!.height * scale,
      );

      final vpPaint =
          Paint()
            ..color = AppTheme.textMuted.withValues(alpha: 0.15)
            ..style = PaintingStyle.fill;
      canvas.drawRect(vpRect, vpPaint);

      final vpBorderPaint =
          Paint()
            ..color = AppTheme.textMuted
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.5;
      canvas.drawRect(vpRect, vpBorderPaint);
    }
  }

  Offset _worldToMinimap(Offset worldPos) {
    return Offset(
      (worldPos.dx - worldBounds.left) * scale,
      (worldPos.dy - worldBounds.top) * scale,
    );
  }

  @override
  bool shouldRepaint(_MinimapPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.state});

  final InfiniteCanvasController controller;
  final StoryboardState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder:
          (context, _) => StatusBar(
            children: [
              StatusItem(
                icon: Icons.layers,
                label: '${state.screens.length} screens',
              ),
              StatusItem(
                icon: Icons.link,
                label: '${state.connections.length} connections',
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
              const Spacer(),
            ],
          ),
    );
  }
}
