import '../ai/repair/repair_diagnostics.dart';
import '../models/component_def.dart';
import '../models/editor_document.dart';
import '../models/frame.dart';
import '../models/node.dart';
import '../models/node_props.dart';
import '../models/node_type.dart';
import 'patch_op.dart';

/// Validates patches by applying them to a lightweight document model
/// and checking invariants on the resulting state.
///
/// This is POST-STATE validation - we actually apply the patches to a mutable
/// copy and then check that the result is valid, rather than using heuristics.
class PatchValidator {
  const PatchValidator();

  /// Validate patches against the document.
  ///
  /// Returns a [ValidationResult] containing any errors or warnings.
  /// If [result.isValid] is false, the patches should not be applied.
  ValidationResult validate(List<PatchOp> patches, EditorDocument doc) {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // Apply patches to a mutable copy
      final resultState = _DocumentState.from(doc);

      for (var i = 0; i < patches.length; i++) {
        final patch = patches[i];
        _applyPatch(resultState, patch, i, errors);
      }

      // Validate post-state invariants
      _validateInvariants(resultState, errors, warnings);
    } catch (e, stackTrace) {
      errors.add('Failed to apply patches: $e\n$stackTrace');
    }

    return ValidationResult(errors: errors, warnings: warnings);
  }

  /// Apply a single patch to the mutable state.
  void _applyPatch(
    _DocumentState state,
    PatchOp patch,
    int index,
    List<String> errors,
  ) {
    try {
      switch (patch) {
        case InsertNode(:final node):
          _applyInsertNode(state, node, index, errors);

        case DeleteNode(:final id):
          _applyDeleteNode(state, id, index, errors);

        case AttachChild(:final parentId, :final childId, :final index):
          _applyAttachChild(state, parentId, childId, index, errors);

        case DetachChild(:final parentId, :final childId):
          _applyDetachChild(state, parentId, childId, index, errors);

        case ReplaceNode(:final id, :final node):
          _applyReplaceNode(state, id, node, index, errors);

        case SetProp(:final id, :final path, :final value):
          _applySetProp(state, id, path, value, index, errors);

        case SetFrameProp(:final frameId, :final path, :final value):
          _applySetFrameProp(state, frameId, path, value, index, errors);

        case MoveNode(:final id, :final newParentId, :final index):
          _applyMoveNode(state, id, newParentId, index, errors);

        case InsertFrame(:final frame):
          _applyInsertFrame(state, frame, index, errors);

        case RemoveFrame(:final frameId):
          _applyRemoveFrame(state, frameId, index, errors);

        case InsertComponent(:final component):
          _applyInsertComponent(state, component, index, errors);

        case RemoveComponent(:final componentId):
          _applyRemoveComponent(state, componentId, index, errors);
      }
    } catch (e) {
      errors.add('[$index] Error applying ${patch.runtimeType}: $e');
    }
  }

  void _applyInsertNode(
    _DocumentState state,
    Node node,
    int patchIndex,
    List<String> errors,
  ) {
    if (state.nodes.containsKey(node.id)) {
      errors.add('[$patchIndex] InsertNode: Node ${node.id} already exists');
      return;
    }
    state.nodes[node.id] = node;
  }

  void _applyDeleteNode(
    _DocumentState state,
    String nodeId,
    int patchIndex,
    List<String> errors,
  ) {
    if (!state.nodes.containsKey(nodeId)) {
      errors.add('[$patchIndex] DeleteNode: Node $nodeId does not exist');
      return;
    }

    // CRITICAL: Detach from parent first
    for (final parentNode in state.nodes.values.toList()) {
      if (parentNode.childIds.contains(nodeId)) {
        final newChildIds = List<String>.from(parentNode.childIds);
        newChildIds.remove(nodeId);
        state.nodes[parentNode.id] = parentNode.copyWith(childIds: newChildIds);
      }
    }

    // Recursively delete children
    _deleteNodeRecursive(state, nodeId);
  }

  void _deleteNodeRecursive(_DocumentState state, String nodeId) {
    final node = state.nodes[nodeId];
    if (node == null) return;

    // Recursively delete children first
    for (final childId in node.childIds) {
      _deleteNodeRecursive(state, childId);
    }

    state.nodes.remove(nodeId);
  }

  void _applyAttachChild(
    _DocumentState state,
    String parentId,
    String childId,
    int index,
    List<String> errors,
  ) {
    final parent = state.nodes[parentId];
    if (parent == null) {
      errors.add('[${errors.length}] AttachChild: Parent $parentId does not exist');
      return;
    }
    if (!state.nodes.containsKey(childId)) {
      errors.add('[${errors.length}] AttachChild: Child $childId does not exist');
      return;
    }

    // CRITICAL: Check for duplicate attachment
    if (parent.childIds.contains(childId)) {
      errors.add(
        '[${errors.length}] AttachChild: Child $childId already attached to parent $parentId',
      );
      return;
    }

    final newChildIds = List<String>.from(parent.childIds);
    final insertIndex = index < 0 ? newChildIds.length : index;
    newChildIds.insert(insertIndex.clamp(0, newChildIds.length), childId);
    state.nodes[parentId] = parent.copyWith(childIds: newChildIds);
  }

  void _applyDetachChild(
    _DocumentState state,
    String parentId,
    String childId,
    int patchIndex,
    List<String> errors,
  ) {
    final parent = state.nodes[parentId];
    if (parent == null) {
      errors.add('[$patchIndex] DetachChild: Parent $parentId does not exist');
      return;
    }

    if (!parent.childIds.contains(childId)) {
      errors.add(
        '[$patchIndex] DetachChild: Child $childId is not attached to parent $parentId',
      );
      return;
    }

    final newChildIds = List<String>.from(parent.childIds);
    newChildIds.remove(childId);
    state.nodes[parentId] = parent.copyWith(childIds: newChildIds);
  }

  void _applyReplaceNode(
    _DocumentState state,
    String id,
    Node node,
    int patchIndex,
    List<String> errors,
  ) {
    if (!state.nodes.containsKey(id)) {
      errors.add('[$patchIndex] ReplaceNode: Node $id does not exist');
      return;
    }
    state.nodes[id] = node;
  }

  void _applySetProp(
    _DocumentState state,
    String id,
    String path,
    dynamic value,
    int patchIndex,
    List<String> errors,
  ) {
    final node = state.nodes[id];
    if (node == null) {
      errors.add('[$patchIndex] SetProp: Node $id does not exist');
      return;
    }

    // Validate path is valid for this node type
    final pathValidation = _validatePath(path, node.type);
    if (pathValidation != null) {
      errors.add('[$patchIndex] SetProp: $pathValidation');
    }

    // Note: We don't actually apply SetProp to the state copy
    // since we'd need full JSON pointer implementation.
    // We just validate the node exists and path is valid.
  }

  void _applySetFrameProp(
    _DocumentState state,
    String frameId,
    String path,
    dynamic value,
    int patchIndex,
    List<String> errors,
  ) {
    final frame = state.frames[frameId];
    if (frame == null) {
      errors.add('[$patchIndex] SetFrameProp: Frame $frameId does not exist');
      return;
    }

    // Validate path is valid for frames
    final pathValidation = _validateFramePath(path);
    if (pathValidation != null) {
      errors.add('[$patchIndex] SetFrameProp: $pathValidation');
    }
  }

  void _applyMoveNode(
    _DocumentState state,
    String id,
    String newParentId,
    int index,
    List<String> errors,
  ) {
    if (!state.nodes.containsKey(id)) {
      errors.add('[${errors.length}] MoveNode: Node $id does not exist');
      return;
    }
    if (!state.nodes.containsKey(newParentId)) {
      errors.add('[${errors.length}] MoveNode: New parent $newParentId does not exist');
      return;
    }

    // Find and detach from current parent
    for (final parentNode in state.nodes.values.toList()) {
      if (parentNode.childIds.contains(id)) {
        final newChildIds = List<String>.from(parentNode.childIds);
        newChildIds.remove(id);
        state.nodes[parentNode.id] = parentNode.copyWith(childIds: newChildIds);
        break;
      }
    }

    // Attach to new parent
    final newParent = state.nodes[newParentId]!;
    final newChildIds = List<String>.from(newParent.childIds);
    final insertIndex = index < 0 ? newChildIds.length : index;
    newChildIds.insert(insertIndex.clamp(0, newChildIds.length), id);
    state.nodes[newParentId] = newParent.copyWith(childIds: newChildIds);
  }

  void _applyInsertFrame(
    _DocumentState state,
    Frame frame,
    int patchIndex,
    List<String> errors,
  ) {
    if (state.frames.containsKey(frame.id)) {
      errors.add('[$patchIndex] InsertFrame: Frame ${frame.id} already exists');
      return;
    }
    state.frames[frame.id] = frame;
  }

  void _applyRemoveFrame(
    _DocumentState state,
    String frameId,
    int patchIndex,
    List<String> errors,
  ) {
    if (!state.frames.containsKey(frameId)) {
      errors.add('[$patchIndex] RemoveFrame: Frame $frameId does not exist');
      return;
    }
    state.frames.remove(frameId);
  }

  void _applyInsertComponent(
    _DocumentState state,
    ComponentDef component,
    int patchIndex,
    List<String> errors,
  ) {
    if (state.components.containsKey(component.id)) {
      errors.add(
        '[$patchIndex] InsertComponent: Component ${component.id} already exists',
      );
      return;
    }
    // Note: We validate rootNodeId exists in _validateInvariants
    state.components[component.id] = component;
  }

  void _applyRemoveComponent(
    _DocumentState state,
    String componentId,
    int patchIndex,
    List<String> errors,
  ) {
    if (!state.components.containsKey(componentId)) {
      errors.add(
        '[$patchIndex] RemoveComponent: Component $componentId does not exist',
      );
      return;
    }
    state.components.remove(componentId);
  }

  /// Validate post-state invariants after all patches are applied.
  void _validateInvariants(
    _DocumentState state,
    List<String> errors,
    List<String> warnings,
  ) {
    // Build parent map
    final parentMap = <String, String>{}; // child → parent

    for (final node in state.nodes.values) {
      for (final childId in node.childIds) {
        // Check: child exists
        if (!state.nodes.containsKey(childId)) {
          errors.add(
            'Node ${node.id} references non-existent child: $childId',
          );
          continue;
        }

        // Check: exactly one parent
        if (parentMap.containsKey(childId)) {
          errors.add(
            'Node $childId has multiple parents: ${parentMap[childId]} and ${node.id}',
          );
        }
        parentMap[childId] = node.id;
      }
    }

    // Check: no cycles using proper algorithm
    if (_hasCycle(state, parentMap)) {
      errors.add('Cycle detected in node hierarchy');
    }

    // Check: frame roots exist
    for (final frame in state.frames.values) {
      if (!state.nodes.containsKey(frame.rootNodeId)) {
        errors.add('Frame ${frame.id} has invalid root: ${frame.rootNodeId}');
      }
    }

    // Check: instance component references are valid
    for (final node in state.nodes.values) {
      if (node.props is InstanceProps) {
        final componentId = (node.props as InstanceProps).componentId;
        if (!state.components.containsKey(componentId)) {
          warnings.add(
            'Instance ${node.id} references non-existent component: $componentId',
          );
        }
      }
    }
  }

  /// Detect cycles in the node hierarchy using DFS with proper visited/visiting sets.
  bool _hasCycle(_DocumentState state, Map<String, String> parentMap) {
    final visited = <String>{}; // Fully processed
    final visiting = <String>{}; // Currently in recursion stack

    for (final nodeId in state.nodes.keys) {
      if (_hasCycleFrom(nodeId, parentMap, visiting, visited)) {
        return true;
      }
    }

    return false;
  }

  bool _hasCycleFrom(
    String nodeId,
    Map<String, String> parentMap,
    Set<String> visiting,
    Set<String> visited,
  ) {
    if (visited.contains(nodeId)) return false; // Already fully processed
    if (visiting.contains(nodeId)) return true; // Cycle detected!

    visiting.add(nodeId);

    // Follow parent edge
    final parentId = parentMap[nodeId];
    if (parentId != null) {
      if (_hasCycleFrom(parentId, parentMap, visiting, visited)) {
        return true;
      }
    }

    visiting.remove(nodeId);
    visited.add(nodeId);

    return false;
  }

  /// Validate a JSON Pointer path for a node.
  String? _validatePath(String path, NodeType type) {
    if (!path.startsWith('/')) {
      return 'Path must start with /: $path';
    }

    final segments = path.substring(1).split('/');
    if (segments.isEmpty) {
      return 'Path must have at least one segment: $path';
    }

    final root = segments[0];

    // Validate root segment
    if (!['props', 'layout', 'style', 'childIds', 'name'].contains(root)) {
      return 'Invalid root segment "$root" in path: $path';
    }

    // Type-specific validation for props paths
    if (root == 'props' && segments.length > 1) {
      final field = segments[1];
      final validFields = _validPropsFields(type);
      if (!validFields.contains(field)) {
        return 'Invalid props field "$field" for ${type.name}: $path';
      }
    }

    // Layout path validation
    if (root == 'layout' && segments.length > 1) {
      final validLayoutPaths = [
        'position',
        'size',
        'autoLayout',
        'constraints',
      ];
      if (!validLayoutPaths.contains(segments[1])) {
        return 'Invalid layout field "${segments[1]}": $path';
      }
    }

    // Style path validation
    if (root == 'style' && segments.length > 1) {
      final validStylePaths = [
        'fill',
        'stroke',
        'cornerRadius',
        'shadow',
        'opacity',
        'visible',
      ];
      if (!validStylePaths.contains(segments[1])) {
        return 'Invalid style field "${segments[1]}": $path';
      }
    }

    return null;
  }

  /// Get valid props fields for a node type.
  Set<String> _validPropsFields(NodeType type) {
    return switch (type) {
      NodeType.container => {'clipContent', 'scrollDirection'},
      NodeType.text => {
          'text',
          'fontFamily',
          'fontSize',
          'fontWeight',
          'color',
          'textAlign',
          'lineHeight',
          'letterSpacing',
          'decoration',
        },
      NodeType.image => {'src', 'fit', 'alt'},
      NodeType.icon => {'icon', 'iconSet', 'size', 'color'},
      NodeType.spacer => {'flex'},
      NodeType.instance => {'componentId', 'overrides'},
      NodeType.slot => {'slotName', 'defaultContentId'},
    };
  }

  /// Validate a JSON Pointer path for a frame.
  String? _validateFramePath(String path) {
    if (!path.startsWith('/')) {
      return 'Path must start with /: $path';
    }

    final segments = path.substring(1).split('/');
    if (segments.isEmpty) {
      return 'Path must have at least one segment: $path';
    }

    final root = segments[0];
    final validRoots = ['name', 'rootNodeId', 'canvas', 'createdAt', 'updatedAt'];

    if (!validRoots.contains(root)) {
      return 'Invalid root segment "$root" for frame path: $path';
    }

    return null;
  }
}

/// Lightweight mutable document state for validation.
class _DocumentState {
  final Map<String, Node> nodes;
  final Map<String, Frame> frames;
  final Map<String, ComponentDef> components;

  _DocumentState({
    required this.nodes,
    required this.frames,
    required this.components,
  });

  factory _DocumentState.from(EditorDocument doc) {
    return _DocumentState(
      nodes: Map.from(doc.nodes),
      frames: Map.from(doc.frames),
      components: Map.from(doc.components),
    );
  }
}

/// Result of patch validation.
class ValidationResult {
  /// Hard errors that prevent patch application.
  final List<String> errors;

  /// Warnings that don't prevent application but may indicate issues.
  final List<String> warnings;

  /// Whether the patches are valid and can be applied.
  bool get isValid => errors.isEmpty;

  const ValidationResult({
    required this.errors,
    required this.warnings,
  });

  /// Convert to structured DiagnosticReport for AI repair mode.
  DiagnosticReport toDiagnosticReport() {
    final diagnostics = <RepairDiagnostic>[];

    for (final error in errors) {
      diagnostics.add(_parseToDiagnostic(error, DiagnosticSeverity.error));
    }

    for (final warning in warnings) {
      diagnostics.add(_parseToDiagnostic(warning, DiagnosticSeverity.warning));
    }

    return DiagnosticReport(diagnostics);
  }

  /// Parse an error string into a structured diagnostic.
  RepairDiagnostic _parseToDiagnostic(String message, DiagnosticSeverity severity) {
    // Try to extract patch index: "[0] InsertNode: ..."
    final indexMatch = RegExp(r'^\[(\d+)\]\s*(\w+):\s*(.+)$').firstMatch(message);

    if (indexMatch != null) {
      final index = indexMatch.group(1);
      final opType = indexMatch.group(2)!;
      final details = indexMatch.group(3)!;

      return RepairDiagnostic(
        code: _inferErrorCode(opType, details),
        message: details,
        location: 'patch index $index ($opType)',
        severity: severity,
        suggestions: _inferSuggestions(opType, details),
      );
    }

    // Try to parse "Node X references non-existent child: Y"
    final refMatch = RegExp(r'Node (\S+) references non-existent (\w+): (\S+)').firstMatch(message);
    if (refMatch != null) {
      return RepairDiagnostic(
        code: RepairErrorCode.invalidNodeReference,
        message: message,
        location: refMatch.group(1),
        suggestions: [
          'Create node "${refMatch.group(3)}" using InsertNode before referencing it',
          'Remove the invalid reference from childIds',
        ],
        severity: severity,
      );
    }

    // Try to parse "Node X has multiple parents"
    final multiParentMatch = RegExp(r'Node (\S+) has multiple parents').firstMatch(message);
    if (multiParentMatch != null) {
      return RepairDiagnostic(
        code: RepairErrorCode.invalidParentChild,
        message: message,
        location: multiParentMatch.group(1),
        suggestions: [
          'Ensure each node is attached to only one parent',
          'Use DetachChild before re-attaching to a different parent',
        ],
        severity: severity,
      );
    }

    // Default: generic diagnostic
    return RepairDiagnostic(
      code: RepairErrorCode.patchInvalidOp,
      message: message,
      severity: severity,
    );
  }

  /// Infer error code from operation type and message.
  RepairErrorCode _inferErrorCode(String opType, String details) {
    if (details.contains('does not exist')) {
      return RepairErrorCode.missingNode;
    }
    if (details.contains('already exists')) {
      return RepairErrorCode.duplicateNodeId;
    }
    if (details.contains('already attached')) {
      return RepairErrorCode.invalidParentChild;
    }
    if (details.contains('not attached')) {
      return RepairErrorCode.orphanedNode;
    }
    if (details.contains('Invalid')) {
      return RepairErrorCode.invalidPropertyPath;
    }

    return RepairErrorCode.patchInvalidOp;
  }

  /// Infer suggestions from operation type and details.
  List<String> _inferSuggestions(String opType, String details) {
    final suggestions = <String>[];

    if (details.contains('does not exist')) {
      if (opType == 'AttachChild' || opType == 'SetProp' || opType == 'ReplaceNode') {
        suggestions.add('Add InsertNode for the missing node before this operation');
      }
      if (opType == 'DeleteNode' || opType == 'DetachChild') {
        suggestions.add('Check if the node ID is correct');
        suggestions.add('Remove this operation if the node was already deleted');
      }
    }

    if (details.contains('already attached')) {
      suggestions.add('Remove duplicate AttachChild operations');
      suggestions.add('Use DetachChild first if moving to a new position');
    }

    if (details.contains('already exists')) {
      suggestions.add('Use a unique node ID');
      suggestions.add('Use ReplaceNode instead of InsertNode to update existing nodes');
    }

    return suggestions;
  }

  @override
  String toString() {
    final buffer = StringBuffer();

    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('Warnings:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }

    if (isValid && warnings.isEmpty) {
      buffer.writeln('Valid');
    }

    return buffer.toString();
  }
}
