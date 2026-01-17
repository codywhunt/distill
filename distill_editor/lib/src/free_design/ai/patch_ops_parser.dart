import 'dart:convert';

import '../models/node.dart';
import '../patch/patch_op.dart';

/// Parses LLM-generated PatchOps from JSON response.
///
/// Handles extraction from code blocks and parsing of all patch operation types.
class PatchOpsParser {
  const PatchOpsParser();

  /// Parse a list of patch operations from an LLM response.
  ///
  /// The response may contain the JSON array directly or wrapped in a code block.
  /// Throws [PatchOpsParseException] if parsing fails.
  List<PatchOp> parse(String response) {
    // Extract JSON from code blocks if present
    final jsonStr = _extractJson(response);

    // Parse JSON
    final dynamic decoded;
    try {
      decoded = json.decode(jsonStr);
    } catch (e) {
      throw PatchOpsParseException('Failed to parse JSON: $e\nInput: $jsonStr');
    }

    if (decoded is! List) {
      throw PatchOpsParseException(
        'Expected JSON array of PatchOps, got ${decoded.runtimeType}',
      );
    }

    // Parse each operation
    final patches = <PatchOp>[];
    for (var i = 0; i < decoded.length; i++) {
      final opJson = decoded[i];
      if (opJson is! Map<String, dynamic>) {
        throw PatchOpsParseException(
          'Expected object at index $i, got ${opJson.runtimeType}',
        );
      }

      try {
        final patch = _parseOp(opJson);
        patches.add(patch);
      } catch (e) {
        throw PatchOpsParseException(
          'Failed to parse operation at index $i: $e\nOperation: $opJson',
        );
      }
    }

    return patches;
  }

  /// Extract JSON from LLM response, handling code blocks.
  String _extractJson(String response) {
    // Try to extract from ```json code block
    final jsonBlockMatch = RegExp(
      r'```(?:json)?\s*([\s\S]*?)\s*```',
      multiLine: true,
    ).firstMatch(response);

    if (jsonBlockMatch != null) {
      return jsonBlockMatch.group(1)!.trim();
    }

    // Try to find raw JSON array
    final trimmed = response.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      return trimmed;
    }

    // Try to find JSON array anywhere in response
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
    if (arrayMatch != null) {
      return arrayMatch.group(0)!;
    }

    throw PatchOpsParseException(
      'No JSON array found in response. Expected [...] or ```json [...] ```',
    );
  }

  /// Parse a single patch operation from JSON.
  PatchOp _parseOp(Map<String, dynamic> opJson) {
    final opType = opJson['op'] as String?;
    if (opType == null) {
      throw PatchOpsParseException('Missing "op" field in patch operation');
    }

    return switch (opType) {
      'SetProp' => _parseSetProp(opJson),
      'SetFrameProp' => _parseSetFrameProp(opJson),
      'InsertNode' => _parseInsertNode(opJson),
      'ReplaceNode' => _parseReplaceNode(opJson),
      'AttachChild' => _parseAttachChild(opJson),
      'DetachChild' => _parseDetachChild(opJson),
      'DeleteNode' => _parseDeleteNode(opJson),
      'MoveNode' => _parseMoveNode(opJson),
      _ => throw PatchOpsParseException('Unknown op type: $opType'),
    };
  }

  SetProp _parseSetProp(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final path = json['path'] as String?;
    final value = json['value'];

    if (id == null) {
      throw PatchOpsParseException('SetProp missing "id" field');
    }
    if (path == null) {
      throw PatchOpsParseException('SetProp missing "path" field');
    }
    if (!json.containsKey('value')) {
      throw PatchOpsParseException('SetProp missing "value" field');
    }

    return SetProp(id: id, path: path, value: value);
  }

  SetFrameProp _parseSetFrameProp(Map<String, dynamic> json) {
    final frameId = json['frameId'] as String?;
    final path = json['path'] as String?;
    final value = json['value'];

    if (frameId == null) {
      throw PatchOpsParseException('SetFrameProp missing "frameId" field');
    }
    if (path == null) {
      throw PatchOpsParseException('SetFrameProp missing "path" field');
    }
    if (!json.containsKey('value')) {
      throw PatchOpsParseException('SetFrameProp missing "value" field');
    }

    return SetFrameProp(frameId: frameId, path: path, value: value);
  }

  InsertNode _parseInsertNode(Map<String, dynamic> json) {
    final nodeJson = json['node'] as Map<String, dynamic>?;

    if (nodeJson == null) {
      throw PatchOpsParseException('InsertNode missing "node" field');
    }

    try {
      final node = Node.fromJson(nodeJson);
      return InsertNode(node);
    } catch (e) {
      throw PatchOpsParseException('InsertNode: failed to parse node: $e');
    }
  }

  ReplaceNode _parseReplaceNode(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final nodeJson = json['node'] ?? json['newNode'];

    if (id == null) {
      throw PatchOpsParseException('ReplaceNode missing "id" field');
    }
    if (nodeJson == null) {
      throw PatchOpsParseException('ReplaceNode missing "node" or "newNode" field');
    }

    try {
      final node = Node.fromJson(nodeJson as Map<String, dynamic>);
      return ReplaceNode(id: id, node: node);
    } catch (e) {
      throw PatchOpsParseException('ReplaceNode: failed to parse node: $e');
    }
  }

  AttachChild _parseAttachChild(Map<String, dynamic> json) {
    final parentId = json['parentId'] as String?;
    final childId = json['childId'] as String?;
    final index = json['index'] as int?;

    if (parentId == null) {
      throw PatchOpsParseException('AttachChild missing "parentId" field');
    }
    if (childId == null) {
      throw PatchOpsParseException('AttachChild missing "childId" field');
    }

    return AttachChild(
      parentId: parentId,
      childId: childId,
      index: index ?? -1,
    );
  }

  DetachChild _parseDetachChild(Map<String, dynamic> json) {
    final parentId = json['parentId'] as String?;
    final childId = json['childId'] as String?;

    if (parentId == null) {
      throw PatchOpsParseException('DetachChild missing "parentId" field');
    }
    if (childId == null) {
      throw PatchOpsParseException('DetachChild missing "childId" field');
    }

    return DetachChild(parentId: parentId, childId: childId);
  }

  DeleteNode _parseDeleteNode(Map<String, dynamic> json) {
    final id = json['id'] as String?;

    if (id == null) {
      throw PatchOpsParseException('DeleteNode missing "id" field');
    }

    return DeleteNode(id);
  }

  MoveNode _parseMoveNode(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final newParentId = json['newParentId'] as String?;
    final index = json['index'] as int?;

    if (id == null) {
      throw PatchOpsParseException('MoveNode missing "id" field');
    }
    if (newParentId == null) {
      throw PatchOpsParseException('MoveNode missing "newParentId" field');
    }

    return MoveNode(
      id: id,
      newParentId: newParentId,
      index: index ?? -1,
    );
  }
}

/// Exception thrown when parsing PatchOps fails.
class PatchOpsParseException implements Exception {
  final String message;

  PatchOpsParseException(this.message);

  @override
  String toString() => 'PatchOpsParseException: $message';
}
