import '../models/component_def.dart';
import '../models/node.dart';
import '../models/node_props.dart';
import '../models/node_type.dart';
import '../patch/patch_op.dart';
import '../store/editor_document_store.dart';

/// Command to create a component from selected nodes.
///
/// v1 Rule: Exactly ONE selected node that is a direct child of its parent.
/// The entire subtree under that node is cloned into the component.
///
/// The command:
/// 1. Validates the selection
/// 2. Clones nodes with source-namespaced IDs
/// 3. Creates the component definition
/// 4. Replaces the original nodes with an instance
class CreateComponentCommand {
  final EditorDocumentStore store;
  final Set<String> selectedDocIds;

  /// Counter for generating unique local IDs within a component.
  int _localIdCounter = 0;

  CreateComponentCommand({
    required this.store,
    required this.selectedDocIds,
  });

  /// Execute the command.
  ///
  /// Returns the created component ID.
  /// Throws [ArgumentError] with explanation if selection is invalid.
  String execute({String? componentName}) {
    // 1. Validate: exactly one selected node
    if (selectedDocIds.isEmpty) {
      throw ArgumentError('No nodes selected');
    }
    if (selectedDocIds.length != 1) {
      throw ArgumentError(
        'v1 requires exactly one selected node (got ${selectedDocIds.length}). '
        'Select a single container to convert to a component.',
      );
    }

    final rootDocId = selectedDocIds.first;
    final rootNode = store.document.nodes[rootDocId];
    if (rootNode == null) {
      throw ArgumentError('Selected node "$rootDocId" not found');
    }

    // 2. Cannot be an instance
    if (rootNode.type == NodeType.instance) {
      throw ArgumentError('Cannot create component from an instance');
    }

    // 3. Get parent for replacement
    final parentId = store.parentIndex[rootDocId];
    if (parentId == null) {
      throw ArgumentError('Selected node has no parent (is it a frame root?)');
    }
    final parentNode = store.document.nodes[parentId]!;
    final originalIndex = parentNode.childIds.indexOf(rootDocId);

    // 4. Generate component ID
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final componentId = 'comp_$timestamp';

    // 5. Collect subtree and build oldId -> newId map
    final subtreeIds = _collectSubtree(rootDocId);
    final idMap = <String, String>{};
    final templateUidMap = <String, String>{};

    for (final oldId in subtreeIds) {
      // Generate unique local ID using counter
      final localId = _generateLocalId();
      idMap[oldId] = componentNodeId(componentId, localId);
      templateUidMap[oldId] = localId;
    }

    // 6. Clone nodes using the ID map
    final clonedNodes = <Node>[];
    for (final oldId in subtreeIds) {
      final oldNode = store.document.nodes[oldId]!;
      final newId = idMap[oldId]!;
      final newChildIds = oldNode.childIds.map((cid) => idMap[cid]!).toList();

      clonedNodes.add(oldNode.copyWith(
        id: newId,
        childIds: newChildIds,
        sourceComponentId: componentId,
        templateUid: templateUidMap[oldId],
      ));
    }

    // Root is the cloned version of the selected node
    final clonedRootId = idMap[rootDocId]!;

    // 7. Create component definition
    final now = DateTime.now();
    final component = ComponentDef(
      id: componentId,
      name: componentName ?? rootNode.name,
      rootNodeId: clonedRootId,
      createdAt: now,
      updatedAt: now,
    );

    // 8. Create instance to replace selection
    final instanceNode = Node(
      id: 'inst_$timestamp',
      name: component.name,
      type: NodeType.instance,
      props: InstanceProps(componentId: componentId),
    );

    // 9. Collect all nodes in original subtree for deletion
    final nodesToDelete = _collectSubtree(rootDocId);

    // 10. Build patches atomically
    final patches = <PatchOp>[
      // Insert cloned component nodes FIRST
      for (final node in clonedNodes) InsertNode(node),
      // Insert component definition
      InsertComponent(component),
      // Detach original root from parent
      DetachChild(parentId: parentId, childId: rootDocId),
      // Delete original subtree nodes
      for (final nodeId in nodesToDelete) DeleteNode(nodeId),
      // Insert instance
      InsertNode(instanceNode),
      // Attach instance at original position
      AttachChild(
        parentId: parentId,
        childId: instanceNode.id,
        index: originalIndex,
      ),
    ];

    store.applyPatches(patches, label: 'Create component from selection');
    return componentId;
  }

  /// Generate a unique local ID for a node within this component.
  String _generateLocalId() {
    return 'n${_localIdCounter++}';
  }

  /// Collect all node IDs in subtree (BFS order).
  List<String> _collectSubtree(String rootId) {
    final result = <String>[];
    final queue = [rootId];

    while (queue.isNotEmpty) {
      final nodeId = queue.removeAt(0);
      result.add(nodeId);

      final node = store.document.nodes[nodeId];
      if (node != null) {
        queue.addAll(node.childIds);
      }
    }

    return result;
  }
}
