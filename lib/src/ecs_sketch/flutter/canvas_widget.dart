/// Flutter Integration: Canvas Widget
///
/// Connects the ECS World to Flutter's rendering system.
/// Implements full Figma-like editing experience.

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/entity.dart';
import '../core/world.dart';
import '../core/commands.dart';
import '../systems/transform_system.dart';
import '../systems/layout_system.dart';
import '../systems/hit_test_system.dart';
import '../systems/render_system.dart';
import '../systems/snap_system.dart';
import '../systems/drop_system.dart';
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

class _EcsCanvasState extends State<EcsCanvas> with SingleTickerProviderStateMixin {
  // ─────────────────────────────────────────────────────────────────────────
  // Systems
  // ─────────────────────────────────────────────────────────────────────────
  final _transformSystem = TransformSystem();
  final _boundsSystem = BoundsSystem();
  final _layoutSystem = LayoutSystem();
  final _hitTestSystem = HitTestSystem();
  final _renderSystem = RenderSystem();
  final _snapSystem = SnapSystem();
  final _dropSystem = DropSystem();

  // ─────────────────────────────────────────────────────────────────────────
  // Viewport State (camera)
  // ─────────────────────────────────────────────────────────────────────────
  Offset _pan = Offset.zero;
  double _zoom = 1.0;

  // ─────────────────────────────────────────────────────────────────────────
  // Interaction State
  // ─────────────────────────────────────────────────────────────────────────
  InteractionState _interaction = const Idle();
  final Set<Entity> _selection = {};

  // ─────────────────────────────────────────────────────────────────────────
  // Drag State (Figma-like feedback)
  // ─────────────────────────────────────────────────────────────────────────
  SnapResult _snapResult = SnapResult.none;
  DropPreview _dropPreview = DropPreview.invalid;

  // For drag accumulator (raw input before snapping)
  Offset _dragAccumulator = Offset.zero;
  Map<Entity, Offset> _dragStartPositions = {};

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
    _layoutSystem.updateAll(widget.world);
    _transformSystem.updateAll(widget.world);
    _boundsSystem.updateAll(widget.world);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Coordinate Conversion
  // ─────────────────────────────────────────────────────────────────────────

  Offset _viewToWorld(Offset view) => (view - _pan) / _zoom;
  Offset _worldToView(Offset world) => world * _zoom + _pan;

  ui.Rect _getViewport(Size screenSize) {
    final topLeft = _viewToWorld(Offset.zero);
    final bottomRight = _viewToWorld(Offset(screenSize.width, screenSize.height));
    return ui.Rect.fromPoints(topLeft, bottomRight);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Input Handling
  // ─────────────────────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    final worldPos = _viewToWorld(event.localPosition);
    final hitResult = _hitTestSystem.hitTest(widget.world, worldPos);

    setState(() {
      _interaction = switch (_interaction) {
        Idle() || Hovering() => _handlePointerDown(event, worldPos, hitResult),
        _ => _interaction,
      };
    });
  }

  InteractionState _handlePointerDown(
    PointerDownEvent event,
    Offset worldPos,
    HitTestResult hitResult,
  ) {
    // Middle mouse or Alt+click = pan
    if (event.buttons == kMiddleMouseButton ||
        (event.buttons == kPrimaryButton && HardwareKeyboard.instance.isAltPressed)) {
      return Panning(startScreenPos: event.localPosition, startCamera: _pan);
    }

    // Left click on entity = select and prepare drag
    if (hitResult.hit) {
      final entity = hitResult.entity!;

      // Update selection
      if (!HardwareKeyboard.instance.isShiftPressed) {
        _selection.clear();
      }
      _selection.add(entity);

      // Capture start positions
      _dragStartPositions = {};
      for (final e in _selection) {
        final pos = widget.world.position.get(e);
        if (pos != null) {
          _dragStartPositions[e] = pos.toOffset();
        }
      }
      _dragAccumulator = Offset.zero;

      return Dragging(
        entities: _selection.toList(),
        startWorldPos: worldPos,
        startPositions: _dragStartPositions,
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
    final worldPos = _viewToWorld(event.localPosition);
    final worldDelta = Offset(event.delta.dx / _zoom, event.delta.dy / _zoom);

    setState(() {
      _interaction = switch (_interaction) {
        Panning(:final startScreenPos, :final startCamera) =>
          _handlePanMove(event, startScreenPos, startCamera),
        Dragging(:final entities, :final startWorldPos, :final startPositions) =>
          _handleDragMove(worldPos, worldDelta, entities, startWorldPos, startPositions),
        MarqueeSelecting(:final startWorldPos) =>
          MarqueeSelecting(startWorldPos: startWorldPos, currentWorldPos: worldPos),
        Idle() || Hovering() => _handleHover(worldPos),
        _ => _interaction,
      };
    });
  }

  InteractionState _handlePanMove(
    PointerMoveEvent event,
    Offset startScreen,
    Offset startCamera,
  ) {
    _pan = startCamera + (event.localPosition - startScreen);
    return Panning(startScreenPos: startScreen, startCamera: startCamera);
  }

  InteractionState _handleDragMove(
    Offset worldPos,
    Offset worldDelta,
    List<Entity> entities,
    Offset startWorld,
    Map<Entity, Offset> startPositions,
  ) {
    // Accumulate raw movement
    _dragAccumulator += worldDelta;

    // Calculate current bounds of dragged entities
    final draggedBounds = _calculateDraggedBounds(entities, _dragAccumulator);

    // Get nearby bounds for snapping (exclude dragged entities)
    final nearbyBounds = _snapSystem.getNearbyBounds(
      widget.world,
      draggedBounds.inflate(200),
      exclude: entities.toSet(),
    );

    // Calculate snap
    _snapResult = _snapSystem.calculate(
      movingBounds: draggedBounds,
      targetBounds: nearbyBounds,
      zoom: _zoom,
    );

    // Calculate drop preview
    _dropPreview = _dropSystem.calculate(
      world: widget.world,
      draggedEntities: entities,
      worldPosition: worldPos,
      startPositions: startPositions,
    );

    // Apply positions (accumulator + snap offset)
    final groupId = 'drag-${DateTime.now().millisecondsSinceEpoch}';
    widget.commands.beginGroup(groupId);

    for (final entity in entities) {
      final startPos = startPositions[entity];
      if (startPos != null) {
        final newPos = startPos + _dragAccumulator + _snapResult.snapOffset;
        widget.commands.setPosition(entity, newPos.dx, newPos.dy);
      }
    }

    widget.commands.endGroup();

    return Dragging(
      entities: entities,
      startWorldPos: startWorld,
      startPositions: startPositions,
    );
  }

  Rect _calculateDraggedBounds(List<Entity> entities, Offset delta) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final entity in entities) {
      final startPos = _dragStartPositions[entity];
      final size = widget.world.size.get(entity);
      if (startPos == null || size == null) continue;

      final pos = startPos + delta;
      minX = minX < pos.dx ? minX : pos.dx;
      minY = minY < pos.dy ? minY : pos.dy;
      maxX = maxX > pos.dx + size.width ? maxX : pos.dx + size.width;
      maxY = maxY > pos.dy + size.height ? maxY : pos.dy + size.height;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  InteractionState _handleHover(Offset worldPos) {
    final hitResult = _hitTestSystem.hitTest(widget.world, worldPos);
    return Hovering(hoveredEntity: hitResult.entity);
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() {
      _interaction = switch (_interaction) {
        MarqueeSelecting(:final startWorldPos, :final currentWorldPos) =>
          _handleMarqueeEnd(startWorldPos, currentWorldPos),
        Dragging() => _handleDragEnd(),
        Panning() => const Idle(),
        _ => _interaction,
      };
    });
  }

  InteractionState _handleMarqueeEnd(Offset start, Offset end) {
    final rect = ui.Rect.fromPoints(start, end);
    final hits = _hitTestSystem.hitTestRect(widget.world, rect);
    _selection.clear();
    _selection.addAll(hits);
    return const Idle();
  }

  InteractionState _handleDragEnd() {
    // Apply final reparenting if needed
    if (_dropPreview.isValid && _dropPreview.intent == DropIntent.reparent) {
      final targetParent = _dropPreview.targetParent!;
      final insertionIndex = _dropPreview.insertionIndex ?? 0;

      widget.commands.grouped('reparent', () {
        for (final entity in _selection) {
          widget.commands.reparent(entity, targetParent, insertionIndex);
        }
      });
    }

    // Clear drag state
    _snapResult = SnapResult.none;
    _dropPreview = DropPreview.invalid;
    _dragAccumulator = Offset.zero;
    _dragStartPositions = {};
    _dropSystem.reset();

    return const Idle();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      setState(() {
        // Zoom towards cursor
        final cursorWorld = _viewToWorld(event.localPosition);

        // Calculate zoom change
        final zoomDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
        final newZoom = (_zoom * zoomDelta).clamp(0.1, 10.0);

        // Adjust pan to keep cursor position fixed
        _pan = event.localPosition - cursorWorld * newZoom;
        _zoom = newZoom;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Keyboard Shortcuts
  // ─────────────────────────────────────────────────────────────────────────

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Undo: Cmd/Ctrl + Z
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            widget.commands.redo();
          } else {
            widget.commands.undo();
          }
          setState(() {});
        }
      }

      // Delete selection
      if (event.logicalKey == LogicalKeyboardKey.delete ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_selection.isNotEmpty) {
          widget.commands.grouped('delete', () {
            for (final entity in _selection.toList()) {
              widget.commands.despawn(entity);
            }
          });
          _selection.clear();
          setState(() {});
        }
      }

      // Select all: Cmd/Ctrl + A
      if (event.logicalKey == LogicalKeyboardKey.keyA &&
          (HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed)) {
        _selection.clear();
        _selection.addAll(widget.world.entities.where(
          (e) => !widget.world.frame.has(e), // Don't select frames
        ));
        setState(() {});
      }

      // Reset zoom: Cmd/Ctrl + 0
      if (event.logicalKey == LogicalKeyboardKey.digit0 &&
          (HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed)) {
        _zoom = 1.0;
        _pan = Offset.zero;
        setState(() {});
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerSignal: _onPointerSignal,
        child: MouseRegion(
          cursor: _getCursor(),
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
                  pan: _pan,
                  zoom: _zoom,
                  selection: _selection,
                  interaction: _interaction,
                  snapResult: _snapResult,
                  dropPreview: _dropPreview,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  MouseCursor _getCursor() {
    return switch (_interaction) {
      Panning() => SystemMouseCursors.grabbing,
      Dragging() => SystemMouseCursors.move,
      MarqueeSelecting() => SystemMouseCursors.crosshair,
      Hovering(hoveredEntity: final e) when e != null => SystemMouseCursors.click,
      _ => SystemMouseCursors.basic,
    };
  }
}

/// CustomPainter that renders the ECS world with all overlays
class _CanvasPainter extends CustomPainter {
  final World world;
  final RenderSystem renderSystem;
  final ui.Rect viewport;
  final Offset pan;
  final double zoom;
  final Set<Entity> selection;
  final InteractionState interaction;
  final SnapResult snapResult;
  final DropPreview dropPreview;

  _CanvasPainter({
    required this.world,
    required this.renderSystem,
    required this.viewport,
    required this.pan,
    required this.zoom,
    required this.selection,
    required this.interaction,
    required this.snapResult,
    required this.dropPreview,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ═══════════════════════════════════════════════════════════════════════
    // Layer 1: Background (screen-space)
    // ═══════════════════════════════════════════════════════════════════════
    _paintBackground(canvas, size);

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 2: Grid (world-space)
    // ═══════════════════════════════════════════════════════════════════════
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);

    _paintGrid(canvas, viewport);

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 3: Content (world-space)
    // ═══════════════════════════════════════════════════════════════════════
    renderSystem.render(world, canvas, viewport);

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 4: Drop zone highlight (world-space)
    // ═══════════════════════════════════════════════════════════════════════
    if (dropPreview.isValid && dropPreview.targetParent != null) {
      _paintDropZone(canvas, dropPreview.targetParent!);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 5: Insertion indicator (world-space)
    // ═══════════════════════════════════════════════════════════════════════
    if (dropPreview.indicatorRect != null) {
      _paintInsertionIndicator(canvas, dropPreview.indicatorRect!);
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 6: Snap guides (world-space)
    // ═══════════════════════════════════════════════════════════════════════
    _paintSnapGuides(canvas);

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 7: Selection (world-space)
    // ═══════════════════════════════════════════════════════════════════════
    _paintSelection(canvas);

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 8: Hover highlight (world-space)
    // ═══════════════════════════════════════════════════════════════════════
    _paintHover(canvas);

    canvas.restore();

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 9: Marquee (screen-space)
    // ═══════════════════════════════════════════════════════════════════════
    _paintMarquee(canvas);

    // ═══════════════════════════════════════════════════════════════════════
    // Layer 10: Frame labels (screen-space)
    // ═══════════════════════════════════════════════════════════════════════
    _paintFrameLabels(canvas);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF1A1A1A),
    );
  }

  void _paintGrid(Canvas canvas, ui.Rect viewport) {
    const gridSize = 50.0;
    const dotRadius = 1.0;
    final dotPaint = Paint()..color = const Color(0xFF333333);

    // Calculate visible grid range
    final startX = (viewport.left / gridSize).floor() * gridSize;
    final startY = (viewport.top / gridSize).floor() * gridSize;
    final endX = viewport.right;
    final endY = viewport.bottom;

    for (var x = startX; x <= endX; x += gridSize) {
      for (var y = startY; y <= endY; y += gridSize) {
        canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);
      }
    }
  }

  void _paintDropZone(Canvas canvas, Entity parent) {
    final bounds = world.worldBounds.get(parent);
    if (bounds == null) return;

    canvas.drawRect(
      bounds.rect,
      Paint()
        ..color = const Color(0x220066FF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      bounds.rect,
      Paint()
        ..color = const Color(0xFF0066FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / zoom,
    );
  }

  void _paintInsertionIndicator(Canvas canvas, Rect rect) {
    // Main indicator line
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF0066FF),
    );

    // Glow effect
    canvas.drawRect(
      rect.inflate(4 / zoom),
      Paint()
        ..color = const Color(0x400066FF)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 8 / zoom),
    );

    // End nubs
    final nubRadius = 4 / zoom;
    final nubPaint = Paint()..color = const Color(0xFF0066FF);

    if (rect.width > rect.height) {
      // Horizontal indicator
      canvas.drawCircle(rect.centerLeft, nubRadius, nubPaint);
      canvas.drawCircle(rect.centerRight, nubRadius, nubPaint);
    } else {
      // Vertical indicator
      canvas.drawCircle(rect.topCenter, nubRadius, nubPaint);
      canvas.drawCircle(rect.bottomCenter, nubRadius, nubPaint);
    }
  }

  void _paintSnapGuides(Canvas canvas) {
    if (snapResult.guides.isEmpty) return;

    for (final guide in snapResult.guides) {
      final paint = Paint()
        ..color = const Color(0xFFFF00FF)
        ..strokeWidth = 1 / zoom;

      if (guide.type == SnapGuideType.center) {
        // Dashed line for center alignment
        _drawDashedLine(canvas, guide.start, guide.end, paint);
      } else {
        // Solid line for edge alignment
        canvas.drawLine(guide.start, guide.end, paint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 4.0;
    const gapLength = 4.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final length = (dx * dx + dy * dy).sqrt();
    final unitX = dx / length;
    final unitY = dy / length;

    var current = 0.0;
    while (current < length) {
      final dashEnd = (current + dashLength / zoom).clamp(0.0, length);
      canvas.drawLine(
        Offset(start.dx + unitX * current, start.dy + unitY * current),
        Offset(start.dx + unitX * dashEnd, start.dy + unitY * dashEnd),
        paint,
      );
      current += (dashLength + gapLength) / zoom;
    }
  }

  void _paintSelection(Canvas canvas) {
    if (selection.isEmpty) return;

    final selectionPaint = Paint()
      ..color = const Color(0xFF0066FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / zoom;

    for (final entity in selection) {
      final bounds = world.worldBounds.get(entity);
      if (bounds == null) continue;

      canvas.drawRect(bounds.rect, selectionPaint);

      // Draw resize handles (only for single selection, not during drag)
      if (selection.length == 1 && interaction is! Dragging) {
        _drawHandles(canvas, bounds.rect);
      }
    }
  }

  void _drawHandles(Canvas canvas, ui.Rect rect) {
    final handleSize = 8 / zoom;
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
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRect(handleRect, handlePaint);
      canvas.drawRect(handleRect, handleStroke);
    }
  }

  void _paintHover(Canvas canvas) {
    final hovering = interaction;
    if (hovering is! Hovering || hovering.hoveredEntity == null) return;
    if (selection.contains(hovering.hoveredEntity)) return;

    final bounds = world.worldBounds.get(hovering.hoveredEntity!);
    if (bounds == null) return;

    canvas.drawRect(
      bounds.rect,
      Paint()
        ..color = const Color(0x660066FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / zoom,
    );
  }

  void _paintMarquee(Canvas canvas) {
    if (interaction is! MarqueeSelecting) return;
    final marquee = interaction as MarqueeSelecting;

    // Convert world coordinates to screen
    final start = marquee.startWorldPos * zoom + pan;
    final end = marquee.currentWorldPos * zoom + pan;
    final rect = Rect.fromPoints(start, end);

    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x220066FF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF0066FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintFrameLabels(Canvas canvas) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final (entity, frame) in world.frame.entries) {
      final name = world.name.get(entity)?.value ?? 'Frame';
      final size = world.size.get(entity);

      // Get world position and convert to screen
      final worldPos = Offset(frame.canvasX, frame.canvasY);
      final screenPos = worldPos * zoom + pan;

      // Paint label above frame
      textPainter.text = TextSpan(
        text: name,
        style: const TextStyle(
          color: Color(0xFF888888),
          fontSize: 12,
        ),
      );
      textPainter.layout();

      final labelPos = Offset(screenPos.dx, screenPos.dy - textPainter.height - 8);
      textPainter.paint(canvas, labelPos);

      // Paint dimensions if selected
      if (selection.contains(entity) && size != null) {
        textPainter.text = TextSpan(
          text: '${size.width.round()} × ${size.height.round()}',
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(
          labelPos.dx + textPainter.width + 8,
          labelPos.dy + 2,
        ));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) {
    return true; // Could optimize with dirty tracking
  }
}

/// Extension for sqrt
extension on double {
  double sqrt() => this < 0 ? 0 : math.sqrt(this);
}

import 'dart:math' as math;
