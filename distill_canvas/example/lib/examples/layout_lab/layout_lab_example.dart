import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme.dart';
import '../../shared/ui.dart';
import 'algorithms/layout_algorithm.dart';
import 'graph_presets.dart';
import 'layout_state.dart';
import 'routing/edge_router.dart';

/// Layout Lab example: test and compare layout algorithms.
class LayoutLabExample extends StatelessWidget {
  const LayoutLabExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LayoutState()..runLayout(),
      child: const _LayoutLabCanvas(),
    );
  }
}

class _LayoutLabCanvas extends StatefulWidget {
  const _LayoutLabCanvas();

  @override
  State<_LayoutLabCanvas> createState() => _LayoutLabCanvasState();
}

class _LayoutLabCanvasState extends State<_LayoutLabCanvas> {
  final _controller = InfiniteCanvasController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _fitToContent(LayoutState state) {
    final bounds = state.allNodesBounds;
    if (bounds != null) {
      _controller.animateToFit(bounds, padding: const EdgeInsets.all(80));
    }
  }

  void _handleDragStart(CanvasDragStartDetails details, LayoutState state) {
    final nodeId = state.hitTest(details.worldPosition);
    if (nodeId != null) {
      state.startDrag(nodeId);
    } else {
      state.selectNode(null);
    }
  }

  void _handleDragUpdate(CanvasDragUpdateDetails details, LayoutState state) {
    if (state.isDragging) {
      state.updateDrag(details.worldDelta);
    }
  }

  void _handleDragEnd(CanvasDragEndDetails details, LayoutState state) {
    state.endDrag();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LayoutState>();

    return Column(
      children: [
        ExampleHeader(
          title: 'Layout Lab',
          description: 'test graph layout algorithms',
          features: const ['animated', 'metrics', 'presets'],
          actions: [
            _buildAlgorithmSelector(state),
            const SizedBox(width: 8),
            _buildRouterSelector(state),
          ],
        ),
        _buildControlPanel(state),
        Expanded(
          child: Stack(
            children: [
              _buildCanvas(state),
              Positioned(
                right: 12,
                bottom: 12,
                child: _buildMetricsPanel(state),
              ),
            ],
          ),
        ),
        _buildStatusBar(state),
      ],
    );
  }

  Widget _buildAlgorithmSelector(LayoutState state) {
    return DropdownSelector<int>(
      value: state.selectedAlgorithmIndex,
      items: List.generate(LayoutState.availableAlgorithms.length, (i) => i),
      onChanged: state.selectAlgorithm,
      itemBuilder: (index) {
        final algo = LayoutState.availableAlgorithms[index];
        return Row(
          children: [
            const Icon(Icons.account_tree_outlined, size: 12),
            const SizedBox(width: 6),
            Text(algo.name.toLowerCase()),
          ],
        );
      },
    );
  }

  Widget _buildRouterSelector(LayoutState state) {
    return DropdownSelector<int>(
      value: state.selectedRouterIndex,
      items: List.generate(LayoutState.availableRouters.length, (i) => i),
      onChanged: state.selectRouter,
      itemBuilder: (index) {
        final router = LayoutState.availableRouters[index];
        return Row(
          children: [
            const Icon(Icons.route_outlined, size: 12),
            const SizedBox(width: 6),
            Text(router.name.toLowerCase()),
          ],
        );
      },
    );
  }

  Widget _buildControlPanel(LayoutState state) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Preset selector
          _buildPresetSelector(state),
          const ToolbarDivider(),

          // Direction selector (if supported)
          if (state.supportsDirection) ...[
            _buildDirectionSelector(state),
            const ToolbarDivider(),
          ],

          // Spacing slider
          _buildSpacingControl(state),
          const ToolbarDivider(),

          const Spacer(),

          // Action buttons
          _ActionButton(
            label: 'relayout',
            onPressed: () {
              state.clearPinned();
              state.runLayout();
            },
          ),
          const SizedBox(width: 6),
          _ActionButton(label: 'fit', onPressed: () => _fitToContent(state)),
        ],
      ),
    );
  }

  Widget _buildPresetSelector(LayoutState state) {
    return DropdownSelector<GraphPreset>(
      value: state.preset,
      items: GraphPreset.all,
      onChanged: state.loadPreset,
      itemBuilder: (preset) => Text(preset.name.toLowerCase()),
    );
  }

  Widget _buildDirectionSelector(LayoutState state) {
    final directions = state.selectedAlgorithm.supportedDirections.toList();
    if (directions.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final dir in LayoutDirection.values)
          _DirectionButton(
            direction: dir,
            isSelected: state.direction == dir,
            isSupported: directions.contains(dir),
            onPressed: () => state.setDirection(dir),
          ),
      ],
    );
  }

  Widget _buildSpacingControl(LayoutState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'spacing',
          style: TextStyle(
            fontSize: 10,
            fontFamily: AppTheme.fontMono,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: AppTheme.textMuted,
              inactiveTrackColor: AppTheme.border,
              thumbColor: AppTheme.textSecondary,
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: state.spacing,
              min: 40,
              max: 160,
              onChanged: state.setSpacing,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${state.spacing.toInt()}',
            style: const TextStyle(
              fontSize: 10,
              fontFamily: AppTheme.fontMono,
              color: AppTheme.textSubtle,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvas(LayoutState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        state.setBounds(Size(constraints.maxWidth, constraints.maxHeight));

        return InfiniteCanvas(
          controller: _controller,
          backgroundColor: AppTheme.canvasDefault,
          initialViewport: InitialViewport.fitContent(
            () => state.allNodesBounds,
            padding: const EdgeInsets.all(80),
            maxZoom: 1.0,
            fallback: const InitialViewport.centerOrigin(),
          ),
          physicsConfig: const CanvasPhysicsConfig(minZoom: 0.1, maxZoom: 4.0),
          onDragStartWorld: (d) => _handleDragStart(d, state),
          onDragUpdateWorld: (d) => _handleDragUpdate(d, state),
          onDragEndWorld: (d) => _handleDragEnd(d, state),
          layers: CanvasLayers(
            background:
                (context, controller) => DotBackground(
                  controller: controller,
                  color: Colors.white.withValues(alpha: 0.03),
                ),
            content: (context, controller) => _buildGraphContent(state),
          ),
        );
      },
    );
  }

  Widget _buildGraphContent(LayoutState state) {
    final positions = state.positions;
    if (positions.isEmpty) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: _EdgePainter(
            positions: Map.from(positions),
            nodes: state.nodes,
            edges: state.edges,
            direction: state.direction,
            layoutResult: state.layoutResult,
            router: state.selectedRouter,
          ),
        ),
        for (final node in state.nodes)
          if (positions.containsKey(node.id))
            Positioned(
              left: positions[node.id]!.dx - node.size.width / 2,
              top: positions[node.id]!.dy - node.size.height / 2,
              child: _GraphNode(
                node: node,
                isSelected: state.selectedNodeId == node.id,
                isDragging: state.isDragging && state.selectedNodeId == node.id,
              ),
            ),
      ],
    );
  }

  Widget _buildMetricsPanel(LayoutState state) {
    final result = state.layoutResult;
    if (result == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'metrics',
            style: TextStyle(
              fontSize: 9,
              fontFamily: AppTheme.fontMono,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          _MetricRow(
            label: 'compute',
            value: '${result.computeTime.inMicroseconds}µs',
          ),
          _MetricRow(label: 'crossings', value: '${result.edgeCrossings}'),
          _MetricRow(
            label: 'edge length',
            value: result.totalEdgeLength.toStringAsFixed(0),
          ),
          _MetricRow(label: 'nodes', value: '${state.nodes.length}'),
          _MetricRow(label: 'edges', value: '${state.edges.length}'),
        ],
      ),
    );
  }

  Widget _buildStatusBar(LayoutState state) {
    return StatusBar(
      children: [
        StatusItem(label: '${state.nodes.length} nodes'),
        StatusItem(label: '${state.edges.length} edges'),
        StatusItem(label: state.selectedAlgorithm.name.toLowerCase()),
        StatusItem(label: state.selectedRouter.name.toLowerCase()),
        ListenableBuilder(
          listenable: _controller,
          builder:
              (context, _) =>
                  StatusItem(label: '${(_controller.zoom * 100).toInt()}%'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceLight,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(2),
        hoverColor: AppTheme.surfaceHover,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: AppTheme.border, width: 0.5),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: AppTheme.fontMono,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.direction,
    required this.isSelected,
    required this.isSupported,
    required this.onPressed,
  });

  final LayoutDirection direction;
  final bool isSelected;
  final bool isSupported;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = switch (direction) {
      LayoutDirection.topToBottom => Icons.arrow_downward,
      LayoutDirection.bottomToTop => Icons.arrow_upward,
      LayoutDirection.leftToRight => Icons.arrow_forward,
      LayoutDirection.rightToLeft => Icons.arrow_back,
    };

    return Opacity(
      opacity: isSupported ? 1.0 : 0.3,
      child: Material(
        color: isSelected ? AppTheme.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: isSupported ? onPressed : null,
          borderRadius: BorderRadius.circular(2),
          hoverColor: AppTheme.surfaceHover,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 12,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: AppTheme.fontMono,
                color: AppTheme.textSubtle,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontFamily: AppTheme.fontMono,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GraphNode extends StatelessWidget {
  const _GraphNode({
    required this.node,
    required this.isSelected,
    required this.isDragging,
  });

  final LayoutNode node;
  final bool isSelected;
  final bool isDragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: node.size.width,
      height: node.size.height,
      decoration: BoxDecoration(
        color:
            isDragging
                ? AppTheme.surfaceHover
                : isSelected
                ? AppTheme.surfaceLight
                : AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? AppTheme.accent : AppTheme.border,
          width: isSelected ? 1.0 : 0.5,
        ),
        boxShadow:
            isDragging
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      alignment: Alignment.center,
      child: Text(
        node.id,
        style: TextStyle(
          fontSize: 10,
          fontFamily: AppTheme.fontMono,
          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edge Painter
// ─────────────────────────────────────────────────────────────────────────────

class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.positions,
    required this.nodes,
    required this.edges,
    required this.direction,
    required this.layoutResult,
    required this.router,
  });

  final Map<String, Offset> positions;
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final LayoutDirection direction;
  final LayoutResult? layoutResult;
  final EdgeRouter router;

  @override
  void paint(Canvas canvas, Size size) {
    final nodeMap = {for (final n in nodes) n.id: n};

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = AppTheme.border;

    for (final edge in edges) {
      final fromPos = positions[edge.fromId];
      final toPos = positions[edge.toId];
      final fromNode = nodeMap[edge.fromId];
      final toNode = nodeMap[edge.toId];

      if (fromPos == null ||
          toPos == null ||
          fromNode == null ||
          toNode == null) {
        continue;
      }

      final fromSide =
          layoutResult?.getExitPort(edge.fromId, direction) ?? PortSide.bottom;
      final toSide =
          layoutResult?.getEntryPort(edge.toId, direction) ?? PortSide.top;

      final points = router.route(
        start: fromPos,
        startSize: fromNode.size,
        startSide: fromSide,
        end: toPos,
        endSize: toNode.size,
        endSide: toSide,
        obstacles: _getObstacles(nodeMap, edge.fromId, edge.toId),
      );

      _drawEdge(canvas, points, paint);
      _drawArrow(canvas, points, paint);
    }
  }

  List<Rect> _getObstacles(
    Map<String, LayoutNode> nodeMap,
    String excludeFrom,
    String excludeTo,
  ) {
    final obstacles = <Rect>[];
    for (final node in nodes) {
      if (node.id == excludeFrom || node.id == excludeTo) continue;
      final pos = positions[node.id];
      if (pos == null) continue;
      obstacles.add(
        Rect.fromCenter(
          center: pos,
          width: node.size.width,
          height: node.size.height,
        ),
      );
    }
    return obstacles;
  }

  void _drawEdge(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length == 2) {
      // Straight line
      canvas.drawLine(points[0], points[1], paint);
    } else if (points.length == 4) {
      // Bezier curve (from curved router)
      final path =
          Path()
            ..moveTo(points[0].dx, points[0].dy)
            ..cubicTo(
              points[1].dx,
              points[1].dy,
              points[2].dx,
              points[2].dy,
              points[3].dx,
              points[3].dy,
            );
      canvas.drawPath(path, paint);
    } else {
      // Orthogonal polyline with rounded corners
      final path = Path()..moveTo(points[0].dx, points[0].dy);
      const cornerRadius = 8.0;

      for (var i = 1; i < points.length - 1; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final next = points[i + 1];

        // Calculate distances to adjacent points
        final distToPrev = (curr - prev).distance;
        final distToNext = (next - curr).distance;

        // Limit corner radius to half the shortest segment
        final maxRadius =
            (distToPrev < distToNext ? distToPrev : distToNext) / 2;
        final radius = cornerRadius < maxRadius ? cornerRadius : maxRadius;

        if (radius > 1) {
          // Calculate the start and end points of the arc
          final dirToPrev = (prev - curr) / distToPrev;
          final dirToNext = (next - curr) / distToNext;

          final arcStart = curr + dirToPrev * radius;
          final arcEnd = curr + dirToNext * radius;

          // Line to arc start, then arc to arc end
          path.lineTo(arcStart.dx, arcStart.dy);
          path.arcToPoint(
            Offset(arcEnd.dx, arcEnd.dy),
            radius: Radius.circular(radius),
          );
        } else {
          // Too small for rounding, just line to the corner
          path.lineTo(curr.dx, curr.dy);
        }
      }

      path.lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  void _drawArrow(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;

    final end = points.last;
    final prev = points[points.length - 2];
    final direction = (end - prev);
    final normalized =
        direction.distance > 0 ? direction / direction.distance : Offset.zero;

    const arrowSize = 6.0;
    final perpendicular = Offset(-normalized.dy, normalized.dx);

    final arrowPath =
        Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(
            end.dx -
                normalized.dx * arrowSize +
                perpendicular.dx * arrowSize * 0.5,
            end.dy -
                normalized.dy * arrowSize +
                perpendicular.dy * arrowSize * 0.5,
          )
          ..lineTo(
            end.dx -
                normalized.dx * arrowSize -
                perpendicular.dx * arrowSize * 0.5,
            end.dy -
                normalized.dy * arrowSize -
                perpendicular.dy * arrowSize * 0.5,
          )
          ..close();

    canvas.drawPath(
      arrowPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = AppTheme.border,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter oldDelegate) {
    // Now we compare actual data, not object references
    return oldDelegate.positions != positions ||
        oldDelegate.router != router ||
        oldDelegate.direction != direction;
  }
}
