/// Flutter Integration: Canvas Widget
///
/// Connects the ECS World to Flutter's rendering system.
/// Uses CustomPainter for efficient rendering without widget rebuilds.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/entity.dart';
import '../core/world.dart';
import '../core/commands.dart';
import '../core/events.dart';
import '../systems/transform_system.dart';
import '../systems/layout_system.dart';
import '../systems/hit_test_system.dart';
import '../systems/render_system.dart';
import '../components/components.dart';
import 'interaction_state.dart';

/// The main canvas widget - entry point for the ECS editor
class EcsCanvas extends StatefulWidget {
  final World world;
  final CommandExecutor commands;

  const EcsCanvas({
    super.key,
    required this.world,
    required this.commands,
  });

  @override
  State<EcsCanvas> createState() => _EcsCanvasState();
}

class _EcsCanvasState extends State<EcsCanvas> {
  // Systems
  final _transformSystem = TransformSystem();
  final _boundsSystem = BoundsSystem();
  final _layoutSystem = LayoutSystem();
  final _hitTestSystem = HitTestSystem();
  final _renderSystem = RenderSystem();

  // Camera state
  Offset _cameraOffset = Offset.zero;
  double _zoom = 1.0;

  // Interaction state machine
  InteractionState _interaction = Idle();

  // Selection
  final Set<Entity> _selection = {};

  @override
  void initState() {
    super.initState();
    widget.commands.addListener(_onWorldChanged);
    _runSystems();
  }

  @override
  void dispose() {
    widget.commands.removeListener(_onWorldChanged);
    super.dispose();
  }

  void _onWorldChanged() {
    _runSystems();
    setState(() {});
  }

  void _runSystems() {
    // Run systems in order
    _layoutSystem.updateAll(widget.world);
    _transformSystem.updateAll(widget.world);
    _boundsSystem.updateAll(widget.world);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Coordinate Conversion
  // ─────────────────────────────────────────────────────────────────────────

  Offset _screenToWorld(Offset screen) {
    return (screen - _cameraOffset) / _zoom;
  }

  Offset _worldToScreen(Offset world) {
    return world * _zoom + _cameraOffset;
  }

  ui.Rect _getViewport(Size screenSize) {
    final topLeft = _screenToWorld(Offset.zero);
    final bottomRight = _screenToWorld(Offset(screenSize.width, screenSize.height));
    return ui.Rect.fromPoints(topLeft, bottomRight);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Input Handling
  // ─────────────────────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    final worldPos = _screenToWorld(event.localPosition);
    final hitResult = _hitTestSystem.hitTest(widget.world, worldPos);

    setState(() {
      _interaction = switch (_interaction) {
        Idle() => _handleIdlePointerDown(event, worldPos, hitResult),
        Hovering() => _handleIdlePointerDown(event, worldPos, hitResult),
        _ => _interaction,
      };
    });
  }

  InteractionState _handleIdlePointerDown(
    PointerDownEvent event,
    Offset worldPos,
    HitTestResult hitResult,
  ) {
    // Middle mouse or space+left = pan
    if (event.buttons == kMiddleMouseButton) {
      return Panning(startScreenPos: event.localPosition, startCamera: _cameraOffset);
    }

    // Left click on entity = select and start drag
    if (hitResult.hit) {
      final entity = hitResult.entity!;

      // Update selection
      if (!HardwareKeyboard.instance.isShiftPressed) {
        _selection.clear();
      }
      _selection.add(entity);

      // Capture start positions for all selected entities
      final startPositions = <Entity, Offset>{};
      for (final e in _selection) {
        final pos = widget.world.position.get(e);
        if (pos != null) {
          startPositions[e] = pos.toOffset();
        }
      }

      return Dragging(
        entities: _selection.toList(),
        startWorldPos: worldPos,
        startPositions: startPositions,
      );
    }

    // Left click on empty = deselect or start marquee
    _selection.clear();
    return MarqueeSelecting(
      startWorldPos: worldPos,
      currentWorldPos: worldPos,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final worldPos = _screenToWorld(event.localPosition);

    setState(() {
      _interaction = switch (_interaction) {
        Panning(startScreenPos: final start, startCamera: final cam) =>
          _handlePanMove(event, start, cam),
        Dragging(
          entities: final entities,
          startWorldPos: final start,
          startPositions: final positions,
        ) =>
          _handleDragMove(worldPos, entities, start, positions),
        MarqueeSelecting(startWorldPos: final start) =>
          MarqueeSelecting(startWorldPos: start, currentWorldPos: worldPos),
        Idle() => _handleHover(worldPos),
        Hovering() => _handleHover(worldPos),
        _ => _interaction,
      };
    });
  }

  InteractionState _handlePanMove(
    PointerMoveEvent event,
    Offset startScreen,
    Offset startCamera,
  ) {
    _cameraOffset = startCamera + (event.localPosition - startScreen);
    return Panning(startScreenPos: startScreen, startCamera: startCamera);
  }

  InteractionState _handleDragMove(
    Offset worldPos,
    List<Entity> entities,
    Offset startWorld,
    Map<Entity, Offset> startPositions,
  ) {
    final delta = worldPos - startWorld;

    // Move all selected entities
    widget.commands.beginGroup('drag-${DateTime.now().millisecondsSinceEpoch}');
    for (final entity in entities) {
      final startPos = startPositions[entity];
      if (startPos != null) {
        widget.commands.setPosition(entity, startPos.dx + delta.dx, startPos.dy + delta.dy);
      }
    }
    widget.commands.endGroup();

    return Dragging(
      entities: entities,
      startWorldPos: startWorld,
      startPositions: startPositions,
    );
  }

  InteractionState _handleHover(Offset worldPos) {
    final hitResult = _hitTestSystem.hitTest(widget.world, worldPos);
    return Hovering(hoveredEntity: hitResult.entity);
  }

  void _onPointerUp(PointerUpEvent event) {
    final worldPos = _screenToWorld(event.localPosition);

    setState(() {
      _interaction = switch (_interaction) {
        MarqueeSelecting(startWorldPos: final start, currentWorldPos: final end) =>
          _handleMarqueeEnd(start, end),
        Dragging() => Idle(),
        Panning() => Idle(),
        _ => _interaction,
      };
    });
  }

  InteractionState _handleMarqueeEnd(Offset start, Offset end) {
    final rect = ui.Rect.fromPoints(start, end);
    final hits = _hitTestSystem.hitTestRect(widget.world, rect);
    _selection.clear();
    _selection.addAll(hits);
    return Idle();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        // Zoom towards cursor
        final cursorWorld = _screenToWorld(event.localPosition);

        // Adjust zoom
        final zoomDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
        _zoom = (_zoom * zoomDelta).clamp(0.1, 10.0);

        // Adjust offset to zoom towards cursor
        final newCursorScreen = _worldToScreen(cursorWorld);
        _cameraOffset += event.localPosition - newCursorScreen;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Keyboard Shortcuts
  // ─────────────────────────────────────────────────────────────────────────

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Undo: Cmd/Ctrl + Z
      if (event.logicalKey == LogicalKeyboardKey.keyZ &&
          HardwareKeyboard.instance.isMetaPressed) {
        if (HardwareKeyboard.instance.isShiftPressed) {
          widget.commands.redo();
        } else {
          widget.commands.undo();
        }
      }

      // Delete selection
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        for (final entity in _selection.toList()) {
          widget.commands.despawn(entity);
        }
        _selection.clear();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerSignal: _onPointerSignal,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final viewport = _getViewport(size);

            return CustomPaint(
              size: size,
              painter: _CanvasPainter(
                world: widget.world,
                renderSystem: _renderSystem,
                viewport: viewport,
                cameraOffset: _cameraOffset,
                zoom: _zoom,
                selection: _selection,
                interaction: _interaction,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// CustomPainter that renders the ECS world
class _CanvasPainter extends CustomPainter {
  final World world;
  final RenderSystem renderSystem;
  final ui.Rect viewport;
  final Offset cameraOffset;
  final double zoom;
  final Set<Entity> selection;
  final InteractionState interaction;

  _CanvasPainter({
    required this.world,
    required this.renderSystem,
    required this.viewport,
    required this.cameraOffset,
    required this.zoom,
    required this.selection,
    required this.interaction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1E1E1E),
    );

    // Apply camera transform
    canvas.save();
    canvas.translate(cameraOffset.dx, cameraOffset.dy);
    canvas.scale(zoom);

    // Render world content
    renderSystem.render(world, canvas, viewport);

    // Render selection highlights
    _renderSelection(canvas);

    // Render interaction feedback
    _renderInteractionFeedback(canvas);

    canvas.restore();
  }

  void _renderSelection(Canvas canvas) {
    final selectionPaint = Paint()
      ..color = const Color(0xFF0066FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / zoom; // Constant screen-space width

    for (final entity in selection) {
      final bounds = world.worldBounds.get(entity);
      if (bounds != null) {
        canvas.drawRect(bounds.rect, selectionPaint);

        // Draw resize handles
        _drawHandles(canvas, bounds.rect);
      }
    }
  }

  void _drawHandles(Canvas canvas, ui.Rect rect) {
    const handleSize = 8.0;
    final adjustedSize = handleSize / zoom;

    final handlePaint = Paint()..color = const Color(0xFFFFFFFF);
    final handleStroke = Paint()
      ..color = const Color(0xFF0066FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / zoom;

    final handles = [
      rect.topLeft,
      rect.topCenter,
      rect.topRight,
      rect.centerLeft,
      rect.centerRight,
      rect.bottomLeft,
      rect.bottomCenter,
      rect.bottomRight,
    ];

    for (final handle in handles) {
      final handleRect = ui.Rect.fromCenter(
        center: handle,
        width: adjustedSize,
        height: adjustedSize,
      );
      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, handleStroke);
    }
  }

  void _renderInteractionFeedback(Canvas canvas) {
    switch (interaction) {
      case MarqueeSelecting(startWorldPos: final start, currentWorldPos: final end):
        final rect = ui.Rect.fromPoints(start, end);
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0x330066FF)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..color = const Color(0xFF0066FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1 / zoom,
        );
      case Hovering(hoveredEntity: final entity):
        if (entity != null && !selection.contains(entity)) {
          final bounds = world.worldBounds.get(entity);
          if (bounds != null) {
            canvas.drawRect(
              bounds.rect,
              Paint()
                ..color = const Color(0x440066FF)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2 / zoom,
            );
          }
        }
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    // Always repaint for now - could be optimized with dirty tracking
    return true;
  }
}
