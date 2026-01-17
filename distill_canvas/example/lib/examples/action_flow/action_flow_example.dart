import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:distill_canvas/infinite_canvas.dart';

import '../../shared/theme.dart';
import '../../shared/ui.dart';
import 'flow_state.dart';

/// Action Flow Example
///
/// Demonstrates node-based workflow editing with:
/// - Typed input/output ports
/// - Drag from port to create connections
/// - Connection validation by type
/// - Execution visualization
/// - Node palette
class ActionFlowExample extends StatelessWidget {
  const ActionFlowExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FlowState()..addInitialNodes(),
      child: const _ActionFlowCanvas(),
    );
  }
}

class _ActionFlowCanvas extends StatefulWidget {
  const _ActionFlowCanvas();

  @override
  State<_ActionFlowCanvas> createState() => _ActionFlowCanvasState();
}

class _ActionFlowCanvasState extends State<_ActionFlowCanvas> {
  final _controller = InfiniteCanvasController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FlowState>();

    return Column(
      children: [
        // Header
        const ExampleHeader(
          title: 'Action Flow',
          description: 'node-based workflow editor',
          features: ['ports', 'connections', 'execution'],
        ),

        // Toolbar
        _Toolbar(
          onRun: state.isExecuting ? state.stopExecution : state.runExecution,
          isExecuting: state.isExecuting,
          onFocusAll: () {
            final bounds = state.allNodesBounds;
            if (bounds != null) {
              _controller.focusOn(bounds, padding: const EdgeInsets.all(80));
            }
          },
          onDelete:
              (state.selectedNodeId != null || state.selectedConnection != null)
                  ? state.deleteSelected
                  : null,
        ),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Node palette
              _NodePalette(
                onAddNode: (type) {
                  final center = _controller.visibleWorldCenter;
                  if (center != null) {
                    state.addNodeAt(type, center);
                  }
                },
              ),

              // Canvas
              Expanded(
                child: KeyboardListener(
                  focusNode: _focusNode,
                  autofocus: true,
                  onKeyEvent: _handleKeyEvent,
                  child: InfiniteCanvas(
                    controller: _controller,
                    backgroundColor: AppTheme.background,
                    initialViewport: InitialViewport.fitContent(
                      () => state.allNodesBounds,
                      padding: const EdgeInsets.all(80),
                      maxZoom: 1.0,
                      fallback: const InitialViewport.centerOrigin(),
                    ),
                    physicsConfig: const CanvasPhysicsConfig(
                      minZoom: 0.2,
                      maxZoom: 2.0,
                    ),
                    layers: CanvasLayers(
                      background:
                          (ctx, ctrl) => DotBackground(
                            controller: ctrl,
                            spacing: 20,
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
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

  Widget _buildContent(FlowState state, InfiniteCanvasController ctrl) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Connections
        _ConnectionsLayer(state: state),

        // Nodes
        for (final node in state.nodes.values)
          CanvasItem(
            key: ValueKey(node.id),
            position: node.position,
            child: _FlowNodeWidget(
              node: node,
              isSelected: state.selectedNodeId == node.id,
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Overlay Layer (connection preview)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverlay(FlowState state, InfiniteCanvasController ctrl) {
    if (state.connectionStart == null || state.connectionEndPoint == null) {
      return const SizedBox.shrink();
    }

    // Get start position
    final startNode = state.nodes[state.connectionStart!.nodeId];
    if (startNode == null) return const SizedBox.shrink();

    final startPort =
        state.connectionStart!.isOutput
            ? startNode.outputs.firstWhere(
              (p) => p.id == state.connectionStart!.portId,
            )
            : startNode.inputs.firstWhere(
              (p) => p.id == state.connectionStart!.portId,
            );

    final startPos = ctrl.worldToView(startNode.getPortPosition(startPort));
    final endPos = ctrl.worldToView(state.connectionEndPoint!);

    return CustomPaint(
      size: Size.infinite,
      painter: _ConnectionPreviewPainter(
        start: startPos,
        end: endPos,
        color: startPort.color,
        isFromOutput: state.connectionStart!.isOutput,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Gesture Handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _handleTap(Offset worldPos, FlowState state) {
    // Check for connection hit
    final connHit = _hitTestConnection(worldPos, state);
    if (connHit != null) {
      state.selectConnection(connHit);
      return;
    }

    // Check for node hit
    final nodeHit = state.hitTestNode(worldPos);
    if (nodeHit != null) {
      state.select(nodeHit.id);
    } else {
      state.deselectAll();
    }
  }

  FlowConnection? _hitTestConnection(Offset worldPos, FlowState state) {
    for (final conn in state.connections) {
      final fromNode = state.nodes[conn.fromNode];
      final toNode = state.nodes[conn.toNode];
      if (fromNode == null || toNode == null) continue;

      final fromPort = fromNode.outputs.firstWhere(
        (p) => p.id == conn.fromPort,
      );
      final toPort = toNode.inputs.firstWhere((p) => p.id == conn.toPort);

      final start = fromNode.getPortPosition(fromPort);
      final end = toNode.getPortPosition(toPort);

      // Simple distance check to bezier midpoint
      final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      if ((worldPos - mid).distance < 20) {
        return conn;
      }
    }
    return null;
  }

  void _handleDoubleTap(Offset worldPos, FlowState state) {
    final hit = state.hitTestNode(worldPos);
    if (hit != null) {
      _controller.focusOn(hit.bounds, padding: const EdgeInsets.all(150));
    }
  }

  void _handleDragStart(CanvasDragStartDetails details, FlowState state) {
    // Check for port hit first
    final portHit = state.hitTestPort(details.worldPosition);
    if (portHit != null) {
      state.startConnection(portHit.node, portHit.port);
      return;
    }

    // Check for node hit
    final nodeHit = state.hitTestNode(details.worldPosition);
    if (nodeHit != null) {
      state.startDrag(nodeHit.id);
    }
  }

  void _handleDragUpdate(CanvasDragUpdateDetails details, FlowState state) {
    if (state.connectionStart != null) {
      state.updateConnectionDrag(details.worldPosition);
    } else if (state.isDragging) {
      state.updateDrag(details.worldDelta);
    }
  }

  void _handleDragEnd(CanvasDragEndDetails details, FlowState state) {
    if (state.connectionStart != null) {
      state.endConnection(details.worldPosition);
    } else if (state.isDragging) {
      state.endDrag();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final state = context.read<FlowState>();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.delete:
      case LogicalKeyboardKey.backspace:
        state.deleteSelected();
        break;
      case LogicalKeyboardKey.escape:
        if (state.connectionStart != null) {
          state.cancelConnection();
        } else {
          state.deselectAll();
        }
        break;
      case LogicalKeyboardKey.keyF:
        final bounds = state.allNodesBounds;
        if (bounds != null) {
          _controller.focusOn(bounds, padding: const EdgeInsets.all(80));
        }
        break;
      case LogicalKeyboardKey.space:
        if (!state.isExecuting) {
          state.runExecution();
        } else {
          state.stopExecution();
        }
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
    required this.onRun,
    required this.isExecuting,
    required this.onFocusAll,
    this.onDelete,
  });

  final VoidCallback onRun;
  final bool isExecuting;
  final VoidCallback onFocusAll;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Toolbar(
      children: [
        // Run/Stop button
        Material(
          color:
              isExecuting
                  ? AppTheme.error.withValues(alpha: 0.15)
                  : AppTheme.surfaceHover,
          borderRadius: BorderRadius.circular(2),
          child: InkWell(
            onTap: onRun,
            borderRadius: BorderRadius.circular(2),
            hoverColor: AppTheme.surfaceHover,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExecuting ? Icons.stop : Icons.play_arrow,
                    size: 12,
                    color:
                        isExecuting ? AppTheme.error : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isExecuting ? 'stop' : 'run',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: AppTheme.fontMono,
                      fontWeight: FontWeight.w500,
                      color:
                          isExecuting ? AppTheme.error : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const ToolbarDivider(),

        ToolbarButton(
          icon: Icons.fit_screen,
          tooltip: 'Focus All (F)',
          onPressed: onFocusAll,
        ),
        ToolbarButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete (⌫)',
          onPressed: onDelete ?? () {},
        ),

        const Spacer(),

        const Text(
          'drag port: connect  space: run  click: select',
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
// Node Palette
// ─────────────────────────────────────────────────────────────────────────────

class _NodePalette extends StatelessWidget {
  const _NodePalette({required this.onAddNode});

  final void Function(NodeType) onAddNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Text(
              'NODES',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                fontFamily: AppTheme.fontMono,
                color: AppTheme.textSubtle,
              ),
            ),
          ),
          _PaletteItem(
            icon: Icons.bolt,
            label: 'trigger',
            color: const Color(0xFF6366F1),
            onTap: () => onAddNode(NodeType.trigger),
          ),
          _PaletteItem(
            icon: Icons.play_circle_outline,
            label: 'action',
            color: const Color(0xFF22C55E),
            onTap: () => onAddNode(NodeType.action),
          ),
          _PaletteItem(
            icon: Icons.call_split,
            label: 'condition',
            color: const Color(0xFFF59E0B),
            onTap: () => onAddNode(NodeType.logic),
          ),
          _PaletteItem(
            icon: Icons.data_object,
            label: 'data',
            color: const Color(0xFF8B5CF6),
            onTap: () => onAddNode(NodeType.data),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'click to add at center',
              style: TextStyle(
                fontSize: 9,
                fontFamily: AppTheme.fontMono,
                color: AppTheme.textSubtle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteItem extends StatelessWidget {
  const _PaletteItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          hoverColor: AppTheme.surfaceHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Icon(
                    icon,
                    size: 12,
                    color: color.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: AppTheme.fontMono,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flow Node Widget
// ─────────────────────────────────────────────────────────────────────────────

class _FlowNodeWidget extends StatelessWidget {
  const _FlowNodeWidget({required this.node, required this.isSelected});

  final FlowNode node;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: node.size.width,
      height: node.size.height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? AppTheme.textSecondary : AppTheme.borderSubtle,
          width: isSelected ? 1 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: node.headerColor.withValues(alpha: 0.8),
            alignment: Alignment.centerLeft,
            child: Text(
              node.name.toLowerCase(),
              style: const TextStyle(
                fontSize: 10,
                fontFamily: AppTheme.fontMono,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ),

          // Ports
          Expanded(
            child: Stack(
              children: [
                // Input ports (left side)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (final port in node.inputs)
                        _PortWidget(port: port, isLeft: true),
                    ],
                  ),
                ),

                // Output ports (right side)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (final port in node.outputs)
                        _PortWidget(port: port, isLeft: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortWidget extends StatelessWidget {
  const _PortWidget({required this.port, required this.isLeft});

  final Port port;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeft) ...[
            Text(
              port.label.toLowerCase(),
              style: const TextStyle(
                fontSize: 9,
                fontFamily: AppTheme.fontMono,
                color: AppTheme.textSubtle,
              ),
            ),
            const SizedBox(width: 3),
          ],
          // Port circle - hit testing handled by canvas drag callbacks
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: port.color.withValues(alpha: 0.8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 1.5),
            ),
          ),
          if (isLeft) ...[
            const SizedBox(width: 3),
            Text(
              port.label.toLowerCase(),
              style: const TextStyle(
                fontSize: 9,
                fontFamily: AppTheme.fontMono,
                color: AppTheme.textSubtle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connections Layer
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionsLayer extends StatelessWidget {
  const _ConnectionsLayer({required this.state});

  final FlowState state;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ConnectionsPainter(
        connections: state.connections,
        nodes: state.nodes,
        selectedConnection: state.selectedConnection,
        activeConnectionId: state.activeConnectionId,
      ),
    );
  }
}

class _ConnectionsPainter extends CustomPainter {
  _ConnectionsPainter({
    required this.connections,
    required this.nodes,
    required this.selectedConnection,
    required this.activeConnectionId,
  });

  final List<FlowConnection> connections;
  final Map<String, FlowNode> nodes;
  final FlowConnection? selectedConnection;
  final String? activeConnectionId;

  @override
  void paint(Canvas canvas, Size size) {
    for (final conn in connections) {
      final fromNode = nodes[conn.fromNode];
      final toNode = nodes[conn.toNode];
      if (fromNode == null || toNode == null) continue;

      final fromPort =
          fromNode.outputs.where((p) => p.id == conn.fromPort).firstOrNull;
      final toPort =
          toNode.inputs.where((p) => p.id == conn.toPort).firstOrNull;
      if (fromPort == null || toPort == null) continue;

      final start = fromNode.getPortPosition(fromPort);
      final end = toNode.getPortPosition(toPort);

      final isSelected = conn == selectedConnection;
      final isActive = conn.id == activeConnectionId;

      final paint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 2 : 1.5
            ..color =
                isActive
                    ? fromPort.color
                    : isSelected
                    ? AppTheme.textSecondary
                    : fromPort.color.withValues(alpha: 0.5);

      // Draw bezier curve
      final path = Path();
      path.moveTo(start.dx, start.dy);

      final dx = (end.dx - start.dx).abs();
      final controlOffset = math.max(dx * 0.5, 50.0);

      path.cubicTo(
        start.dx + controlOffset,
        start.dy,
        end.dx - controlOffset,
        end.dy,
        end.dx,
        end.dy,
      );

      // Glow effect for active connection
      if (isActive) {
        final glowPaint =
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = fromPort.color.withValues(alpha: 0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawPath(path, glowPaint);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectionsPainter oldDelegate) => true;
}

class _ConnectionPreviewPainter extends CustomPainter {
  _ConnectionPreviewPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.isFromOutput,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final bool isFromOutput;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.8);

    final path = Path();

    if (isFromOutput) {
      path.moveTo(start.dx, start.dy);
      final dx = (end.dx - start.dx).abs();
      final controlOffset = math.max(dx * 0.5, 30.0);
      path.cubicTo(
        start.dx + controlOffset,
        start.dy,
        end.dx - controlOffset,
        end.dy,
        end.dx,
        end.dy,
      );
    } else {
      path.moveTo(end.dx, end.dy);
      final dx = (start.dx - end.dx).abs();
      final controlOffset = math.max(dx * 0.5, 30.0);
      path.cubicTo(
        end.dx + controlOffset,
        end.dy,
        start.dx - controlOffset,
        start.dy,
        start.dx,
        start.dy,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConnectionPreviewPainter oldDelegate) =>
      start != oldDelegate.start || end != oldDelegate.end;
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.state});

  final InfiniteCanvasController controller;
  final FlowState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder:
          (context, _) => StatusBar(
            children: [
              StatusItem(
                icon: Icons.account_tree,
                label: '${state.nodes.length} nodes',
              ),
              StatusItem(
                icon: Icons.link,
                label: '${state.connections.length} connections',
              ),
              if (state.isExecuting)
                const StatusItem(icon: Icons.play_circle, label: 'Running...'),
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
