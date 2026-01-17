import '../models/frame.dart';
import '../models/node.dart';

/// A patch operation on the document.
///
/// Patch operations are atomic and invertible (for undo).
sealed class PatchOp {
  const PatchOp();

  factory PatchOp.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'SetProp' => SetProp.fromJson(json),
      'SetFrameProp' => SetFrameProp.fromJson(json),
      'InsertNode' => InsertNode.fromJson(json),
      'AttachChild' => AttachChild.fromJson(json),
      'DetachChild' => DetachChild.fromJson(json),
      'DeleteNode' => DeleteNode.fromJson(json),
      'MoveNode' => MoveNode.fromJson(json),
      'ReplaceNode' => ReplaceNode.fromJson(json),
      'InsertFrame' => InsertFrame.fromJson(json),
      'RemoveFrame' => RemoveFrame.fromJson(json),
      _ => throw ArgumentError('Unknown patch type: $type'),
    };
  }

  Map<String, dynamic> toJson();
}

// =============================================================================
// Property Operations
// =============================================================================

/// Set a property on a node by JSON Pointer path.
///
/// Example paths:
/// - `/layout/position/x`
/// - `/style/fill`
/// - `/props/text`
class SetProp extends PatchOp {
  /// Node ID to modify.
  final String id;

  /// JSON Pointer path to the property.
  final String path;

  /// New value for the property.
  final dynamic value;

  const SetProp({
    required this.id,
    required this.path,
    required this.value,
  });

  factory SetProp.fromJson(Map<String, dynamic> json) {
    return SetProp(
      id: json['id'] as String,
      path: json['path'] as String,
      value: json['value'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SetProp',
        'id': id,
        'path': path,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetProp &&
          id == other.id &&
          path == other.path &&
          value == other.value;

  @override
  int get hashCode => Object.hash(id, path, value);

  @override
  String toString() => 'SetProp(id: $id, path: $path, value: $value)';
}

/// Set a property on a frame by JSON Pointer path.
///
/// Example paths:
/// - `/canvas/position`
/// - `/canvas/size`
/// - `/name`
class SetFrameProp extends PatchOp {
  /// Frame ID to modify.
  final String frameId;

  /// JSON Pointer path to the property.
  final String path;

  /// New value for the property.
  final dynamic value;

  const SetFrameProp({
    required this.frameId,
    required this.path,
    required this.value,
  });

  factory SetFrameProp.fromJson(Map<String, dynamic> json) {
    return SetFrameProp(
      frameId: json['frameId'] as String,
      path: json['path'] as String,
      value: json['value'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'SetFrameProp',
        'frameId': frameId,
        'path': path,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SetFrameProp &&
          frameId == other.frameId &&
          path == other.path &&
          value == other.value;

  @override
  int get hashCode => Object.hash(frameId, path, value);

  @override
  String toString() =>
      'SetFrameProp(frameId: $frameId, path: $path, value: $value)';
}

// =============================================================================
// Node Structure Operations
// =============================================================================

/// Insert a node into the document's node map.
///
/// Does NOT attach to any parent - use with [AttachChild] to add to tree.
class InsertNode extends PatchOp {
  /// The node to insert.
  final Node node;

  const InsertNode(this.node);

  factory InsertNode.fromJson(Map<String, dynamic> json) {
    return InsertNode(
      Node.fromJson(json['node'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'InsertNode',
        'node': node.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InsertNode && node == other.node;

  @override
  int get hashCode => node.hashCode;

  @override
  String toString() => 'InsertNode(${node.id})';
}

/// Attach a node as a child of a parent.
///
/// The node must already exist in the nodes map (via [InsertNode]).
class AttachChild extends PatchOp {
  /// Parent node ID.
  final String parentId;

  /// Child node ID to attach.
  final String childId;

  /// Index to insert at (-1 = append).
  final int index;

  const AttachChild({
    required this.parentId,
    required this.childId,
    this.index = -1,
  });

  factory AttachChild.fromJson(Map<String, dynamic> json) {
    return AttachChild(
      parentId: json['parentId'] as String,
      childId: json['childId'] as String,
      index: json['index'] as int? ?? -1,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'AttachChild',
        'parentId': parentId,
        'childId': childId,
        'index': index,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttachChild &&
          parentId == other.parentId &&
          childId == other.childId &&
          index == other.index;

  @override
  int get hashCode => Object.hash(parentId, childId, index);

  @override
  String toString() =>
      'AttachChild(parent: $parentId, child: $childId, index: $index)';
}

/// Detach a node from its parent.
///
/// Does NOT remove from nodes map - use with [DeleteNode] to fully remove.
class DetachChild extends PatchOp {
  /// Parent node ID.
  final String parentId;

  /// Child node ID to detach.
  final String childId;

  const DetachChild({
    required this.parentId,
    required this.childId,
  });

  factory DetachChild.fromJson(Map<String, dynamic> json) {
    return DetachChild(
      parentId: json['parentId'] as String,
      childId: json['childId'] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DetachChild',
        'parentId': parentId,
        'childId': childId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetachChild &&
          parentId == other.parentId &&
          childId == other.childId;

  @override
  int get hashCode => Object.hash(parentId, childId);

  @override
  String toString() => 'DetachChild(parent: $parentId, child: $childId)';
}

/// Remove a node from the document's node map.
///
/// Should be detached first (via [DetachChild]).
class DeleteNode extends PatchOp {
  /// Node ID to delete.
  final String id;

  const DeleteNode(this.id);

  factory DeleteNode.fromJson(Map<String, dynamic> json) {
    return DeleteNode(json['id'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'DeleteNode',
        'id': id,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeleteNode && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DeleteNode($id)';
}

/// Move a node to a new parent.
///
/// Combines detach + attach as a single operation.
class MoveNode extends PatchOp {
  /// Node ID to move.
  final String id;

  /// New parent node ID.
  final String newParentId;

  /// Index in new parent's children (-1 = append).
  final int index;

  const MoveNode({
    required this.id,
    required this.newParentId,
    this.index = -1,
  });

  factory MoveNode.fromJson(Map<String, dynamic> json) {
    return MoveNode(
      id: json['id'] as String,
      newParentId: json['newParentId'] as String,
      index: json['index'] as int? ?? -1,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'MoveNode',
        'id': id,
        'newParentId': newParentId,
        'index': index,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveNode &&
          id == other.id &&
          newParentId == other.newParentId &&
          index == other.index;

  @override
  int get hashCode => Object.hash(id, newParentId, index);

  @override
  String toString() =>
      'MoveNode($id → $newParentId, index: $index)';
}

/// Replace a node's data entirely (keeps same ID).
class ReplaceNode extends PatchOp {
  /// Node ID to replace.
  final String id;

  /// New node data (must have same ID).
  final Node node;

  const ReplaceNode({
    required this.id,
    required this.node,
  });

  factory ReplaceNode.fromJson(Map<String, dynamic> json) {
    return ReplaceNode(
      id: json['id'] as String,
      node: Node.fromJson(json['node'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ReplaceNode',
        'id': id,
        'node': node.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReplaceNode && id == other.id && node == other.node;

  @override
  int get hashCode => Object.hash(id, node);

  @override
  String toString() => 'ReplaceNode($id)';
}

// =============================================================================
// Frame Operations
// =============================================================================

/// Insert a new frame into the document.
class InsertFrame extends PatchOp {
  /// The frame to insert.
  final Frame frame;

  const InsertFrame(this.frame);

  factory InsertFrame.fromJson(Map<String, dynamic> json) {
    return InsertFrame(
      Frame.fromJson(json['frame'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'InsertFrame',
        'frame': frame.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InsertFrame && frame == other.frame;

  @override
  int get hashCode => frame.hashCode;

  @override
  String toString() => 'InsertFrame(${frame.id})';
}

/// Remove a frame from the document.
class RemoveFrame extends PatchOp {
  /// Frame ID to remove.
  final String frameId;

  const RemoveFrame(this.frameId);

  factory RemoveFrame.fromJson(Map<String, dynamic> json) {
    return RemoveFrame(json['frameId'] as String);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'RemoveFrame',
        'frameId': frameId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoveFrame && frameId == other.frameId;

  @override
  int get hashCode => frameId.hashCode;

  @override
  String toString() => 'RemoveFrame($frameId)';
}
