import 'package:flutter/material.dart';

/// State management for the Action Flow example.
class FlowState extends ChangeNotifier {
  final Map<String, FlowNode> nodes = {};
  final List<FlowConnection> connections = [];
  String? selectedNodeId;
  FlowConnection? selectedConnection;

  // Drag state
  bool isDragging = false;
  Map<String, Offset> _dragStartPositions = {};
  Offset _dragAccumulator = Offset.zero;

  // Connection creation state
  PortRef? connectionStart;
  Offset? connectionEndPoint;

  // Execution state
  bool isExecuting = false;
  String? activeConnectionId;

  int _nextId = 0;

  /// Add initial demo nodes.
  void addInitialNodes() {
    // Trigger node
    _addNode(
      'Trigger',
      NodeType.trigger,
      const Offset(50, 150),
      outputs: [PortDef('trigger', PortDataType.trigger, 'On Start')],
    );

    // Condition node
    _addNode(
      'Condition',
      NodeType.logic,
      const Offset(300, 100),
      inputs: [PortDef('input', PortDataType.trigger, 'In')],
      outputs: [
        PortDef('true', PortDataType.trigger, 'True'),
        PortDef('false', PortDataType.trigger, 'False'),
      ],
    );

    // Action nodes
    _addNode(
      'Send Email',
      NodeType.action,
      const Offset(550, 50),
      inputs: [
        PortDef('trigger', PortDataType.trigger, 'In'),
        PortDef('to', PortDataType.string, 'To'),
      ],
      outputs: [PortDef('done', PortDataType.trigger, 'Done')],
    );

    _addNode(
      'Log Message',
      NodeType.action,
      const Offset(550, 200),
      inputs: [
        PortDef('trigger', PortDataType.trigger, 'In'),
        PortDef('message', PortDataType.string, 'Message'),
      ],
      outputs: [PortDef('done', PortDataType.trigger, 'Done')],
    );

    // Data node
    _addNode(
      'Get User',
      NodeType.data,
      const Offset(300, 300),
      inputs: [PortDef('id', PortDataType.number, 'User ID')],
      outputs: [
        PortDef('name', PortDataType.string, 'Name'),
        PortDef('email', PortDataType.string, 'Email'),
      ],
    );

    // Initial connections
    _addConnection('node-0', 'trigger', 'node-1', 'input');
    _addConnection('node-1', 'true', 'node-2', 'trigger');
    _addConnection('node-1', 'false', 'node-3', 'trigger');

    notifyListeners();
  }

  void _addNode(
    String name,
    NodeType type,
    Offset position, {
    List<PortDef> inputs = const [],
    List<PortDef> outputs = const [],
  }) {
    final id = 'node-${_nextId++}';
    nodes[id] = FlowNode(
      id: id,
      name: name,
      type: type,
      position: position,
      inputs:
          inputs
              .map(
                (p) => Port(
                  id: p.id,
                  dataType: p.dataType,
                  label: p.label,
                  isOutput: false,
                ),
              )
              .toList(),
      outputs:
          outputs
              .map(
                (p) => Port(
                  id: p.id,
                  dataType: p.dataType,
                  label: p.label,
                  isOutput: true,
                ),
              )
              .toList(),
    );
  }

  void _addConnection(
    String fromNode,
    String fromPort,
    String toNode,
    String toPort,
  ) {
    connections.add(
      FlowConnection(
        id: 'conn-${connections.length}',
        fromNode: fromNode,
        fromPort: fromPort,
        toNode: toNode,
        toPort: toPort,
      ),
    );
  }

  void addNodeAt(NodeType type, Offset position) {
    final id = 'node-${_nextId++}';
    final node = _createNodeOfType(id, type, position);
    nodes[id] = node;
    selectedNodeId = id;
    selectedConnection = null;
    notifyListeners();
  }

  FlowNode _createNodeOfType(String id, NodeType type, Offset position) {
    return switch (type) {
      NodeType.trigger => FlowNode(
        id: id,
        name: 'Trigger',
        type: type,
        position: position - const Offset(60, 30),
        inputs: [],
        outputs: [
          Port(
            id: 'trigger',
            dataType: PortDataType.trigger,
            label: 'Out',
            isOutput: true,
          ),
        ],
      ),
      NodeType.action => FlowNode(
        id: id,
        name: 'Action',
        type: type,
        position: position - const Offset(70, 40),
        inputs: [
          Port(
            id: 'trigger',
            dataType: PortDataType.trigger,
            label: 'In',
            isOutput: false,
          ),
        ],
        outputs: [
          Port(
            id: 'done',
            dataType: PortDataType.trigger,
            label: 'Done',
            isOutput: true,
          ),
        ],
      ),
      NodeType.logic => FlowNode(
        id: id,
        name: 'Condition',
        type: type,
        position: position - const Offset(70, 50),
        inputs: [
          Port(
            id: 'input',
            dataType: PortDataType.trigger,
            label: 'In',
            isOutput: false,
          ),
        ],
        outputs: [
          Port(
            id: 'true',
            dataType: PortDataType.trigger,
            label: 'True',
            isOutput: true,
          ),
          Port(
            id: 'false',
            dataType: PortDataType.trigger,
            label: 'False',
            isOutput: true,
          ),
        ],
      ),
      NodeType.data => FlowNode(
        id: id,
        name: 'Data',
        type: type,
        position: position - const Offset(70, 50),
        inputs: [
          Port(
            id: 'input',
            dataType: PortDataType.any,
            label: 'In',
            isOutput: false,
          ),
        ],
        outputs: [
          Port(
            id: 'output',
            dataType: PortDataType.any,
            label: 'Out',
            isOutput: true,
          ),
        ],
      ),
    };
  }

  void deleteSelected() {
    if (selectedNodeId != null) {
      nodes.remove(selectedNodeId);
      connections.removeWhere(
        (c) => c.fromNode == selectedNodeId || c.toNode == selectedNodeId,
      );
      selectedNodeId = null;
    }
    if (selectedConnection != null) {
      connections.remove(selectedConnection);
      selectedConnection = null;
    }
    notifyListeners();
  }

  FlowNode? hitTestNode(Offset worldPos) {
    for (final node in nodes.values.toList().reversed) {
      if (node.bounds.contains(worldPos)) {
        return node;
      }
    }
    return null;
  }

  PortHit? hitTestPort(Offset worldPos) {
    // Check ports with generous hit radius (port circle is 12px, add 6px padding)
    const hitRadius = 12.0;
    for (final node in nodes.values) {
      for (final port in [...node.inputs, ...node.outputs]) {
        final portCenter = node.getPortPosition(port);
        if ((worldPos - portCenter).distance < hitRadius) {
          return PortHit(node: node, port: port);
        }
      }
    }
    return null;
  }

  void select(String nodeId) {
    selectedNodeId = nodeId;
    selectedConnection = null;
    notifyListeners();
  }

  void selectConnection(FlowConnection conn) {
    selectedConnection = conn;
    selectedNodeId = null;
    notifyListeners();
  }

  void deselectAll() {
    selectedNodeId = null;
    selectedConnection = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Drag / Move
  // ─────────────────────────────────────────────────────────────────────────

  void startDrag(String nodeId) {
    isDragging = true;
    _dragAccumulator = Offset.zero;
    selectedNodeId = nodeId;
    selectedConnection = null;

    _dragStartPositions = {nodeId: nodes[nodeId]!.position};
    notifyListeners();
  }

  void updateDrag(Offset worldDelta) {
    if (!isDragging || _dragStartPositions.isEmpty) return;

    _dragAccumulator += worldDelta;

    for (final entry in _dragStartPositions.entries) {
      final node = nodes[entry.key];
      if (node == null) continue;

      final newPos = entry.value + _dragAccumulator;
      nodes[entry.key] = node.copyWith(position: newPos);
    }

    notifyListeners();
  }

  void endDrag() {
    isDragging = false;
    _dragStartPositions.clear();
    _dragAccumulator = Offset.zero;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Connection Creation
  // ─────────────────────────────────────────────────────────────────────────

  void startConnection(FlowNode node, Port port) {
    connectionStart = PortRef(
      nodeId: node.id,
      portId: port.id,
      isOutput: port.isOutput,
    );
    connectionEndPoint = node.getPortPosition(port);
    notifyListeners();
  }

  void updateConnectionDrag(Offset worldPos) {
    if (connectionStart == null) return;
    connectionEndPoint = worldPos;
    notifyListeners();
  }

  void endConnection(Offset worldPos) {
    if (connectionStart == null) {
      cancelConnection();
      return;
    }

    final hit = hitTestPort(worldPos);
    if (hit != null && _canConnect(connectionStart!, hit)) {
      // Create connection
      final fromRef =
          connectionStart!.isOutput
              ? connectionStart!
              : PortRef(
                nodeId: hit.node.id,
                portId: hit.port.id,
                isOutput: hit.port.isOutput,
              );
      final toRef =
          connectionStart!.isOutput
              ? PortRef(
                nodeId: hit.node.id,
                portId: hit.port.id,
                isOutput: hit.port.isOutput,
              )
              : connectionStart!;

      // Remove existing connection to this input
      connections.removeWhere(
        (c) => c.toNode == toRef.nodeId && c.toPort == toRef.portId,
      );

      connections.add(
        FlowConnection(
          id: 'conn-${connections.length}',
          fromNode: fromRef.nodeId,
          fromPort: fromRef.portId,
          toNode: toRef.nodeId,
          toPort: toRef.portId,
        ),
      );
    }

    cancelConnection();
  }

  void cancelConnection() {
    connectionStart = null;
    connectionEndPoint = null;
    notifyListeners();
  }

  bool _canConnect(PortRef start, PortHit target) {
    // Can't connect to same node
    if (start.nodeId == target.node.id) return false;

    // Must be different directions (output to input)
    if (start.isOutput == target.port.isOutput) return false;

    // Type compatibility (simplified)
    final startPort = _getPort(start);
    if (startPort == null) return false;

    return _typesCompatible(startPort.dataType, target.port.dataType);
  }

  Port? _getPort(PortRef ref) {
    final node = nodes[ref.nodeId];
    if (node == null) return null;
    final ports = ref.isOutput ? node.outputs : node.inputs;
    return ports.where((p) => p.id == ref.portId).firstOrNull;
  }

  bool _typesCompatible(PortDataType a, PortDataType b) {
    if (a == PortDataType.any || b == PortDataType.any) return true;
    return a == b;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Execution Simulation
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> runExecution() async {
    if (isExecuting) return;
    isExecuting = true;
    notifyListeners();

    // Find trigger nodes and trace connections
    final executionOrder = <String>[];
    for (final conn in connections) {
      executionOrder.add(conn.id);
    }

    for (final connId in executionOrder) {
      activeConnectionId = connId;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    activeConnectionId = null;
    isExecuting = false;
    notifyListeners();
  }

  void stopExecution() {
    isExecuting = false;
    activeConnectionId = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bounds
  // ─────────────────────────────────────────────────────────────────────────

  Rect? get allNodesBounds {
    if (nodes.isEmpty) return null;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final node in nodes.values) {
      minX = minX < node.bounds.left ? minX : node.bounds.left;
      minY = minY < node.bounds.top ? minY : node.bounds.top;
      maxX = maxX > node.bounds.right ? maxX : node.bounds.right;
      maxY = maxY > node.bounds.bottom ? maxY : node.bounds.bottom;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum NodeType { trigger, action, logic, data }

enum PortDataType { trigger, string, number, boolean, any }

class PortDef {
  const PortDef(this.id, this.dataType, this.label);
  final String id;
  final PortDataType dataType;
  final String label;
}

class Port {
  const Port({
    required this.id,
    required this.dataType,
    required this.label,
    required this.isOutput,
  });

  final String id;
  final PortDataType dataType;
  final String label;
  final bool isOutput;

  Color get color => switch (dataType) {
    PortDataType.trigger => const Color(0xFF22D3EE),
    PortDataType.string => const Color(0xFF22C55E),
    PortDataType.number => const Color(0xFFF59E0B),
    PortDataType.boolean => const Color(0xFFEC4899),
    PortDataType.any => const Color(0xFF9CA3AF),
  };
}

class FlowNode {
  const FlowNode({
    required this.id,
    required this.name,
    required this.type,
    required this.position,
    required this.inputs,
    required this.outputs,
  });

  final String id;
  final String name;
  final NodeType type;
  final Offset position;
  final List<Port> inputs;
  final List<Port> outputs;

  Size get size {
    final portCount =
        inputs.length > outputs.length ? inputs.length : outputs.length;
    final height = 60.0 + portCount * 24.0;
    return Size(140, height);
  }

  Rect get bounds =>
      Rect.fromLTWH(position.dx, position.dy, size.width, size.height);

  Color get headerColor => switch (type) {
    NodeType.trigger => const Color(0xFF6366F1),
    NodeType.action => const Color(0xFF22C55E),
    NodeType.logic => const Color(0xFFF59E0B),
    NodeType.data => const Color(0xFF8B5CF6),
  };

  Offset getPortPosition(Port port) {
    final ports = port.isOutput ? outputs : inputs;
    final index = ports.indexOf(port);
    // Port circle is 12px wide, positioned 6px inset from edge
    final x = port.isOutput ? bounds.right - 6 : bounds.left + 6;
    // Header is 28px, port rows are 24px tall, center of port circle is 12px into each row
    final startY = position.dy + 28; // Below header
    final y = startY + index * 24 + 12;
    return Offset(x, y);
  }

  FlowNode copyWith({Offset? position, String? name}) {
    return FlowNode(
      id: id,
      name: name ?? this.name,
      type: type,
      position: position ?? this.position,
      inputs: inputs,
      outputs: outputs,
    );
  }
}

class FlowConnection {
  const FlowConnection({
    required this.id,
    required this.fromNode,
    required this.fromPort,
    required this.toNode,
    required this.toPort,
  });

  final String id;
  final String fromNode;
  final String fromPort;
  final String toNode;
  final String toPort;
}

class PortRef {
  const PortRef({
    required this.nodeId,
    required this.portId,
    required this.isOutput,
  });

  final String nodeId;
  final String portId;
  final bool isOutput;
}

class PortHit {
  const PortHit({required this.node, required this.port});
  final FlowNode node;
  final Port port;
}
