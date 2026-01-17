import 'dart:convert';
import 'dart:ui';

import '../models/node.dart';

/// Payload for clipboard operations (copy, cut, paste, duplicate).
///
/// Contains serialized node data with metadata for proper paste placement.
class ClipboardPayload {
  /// Magic string to identify Distill clipboard data.
  static const String payloadType = 'distill_clipboard';

  /// Current schema version.
  static const int currentVersion = 1;

  /// Type discriminator (always 'distill_clipboard').
  final String type;

  /// Schema version for forward compatibility.
  final int version;

  /// Source document ID (for potential same-doc detection).
  final String? sourceDocumentId;

  /// Source frame ID.
  final String? sourceFrameId;

  /// Top-level selected node IDs (not descendants).
  final List<String> rootIds;

  /// All nodes in subtrees (roots + all descendants).
  final List<Node> nodes;

  /// Bounding box top-left in frame-local coordinates.
  /// Used for anchor-based positioning during paste.
  final Offset anchor;

  const ClipboardPayload({
    this.type = payloadType,
    this.version = currentVersion,
    this.sourceDocumentId,
    this.sourceFrameId,
    required this.rootIds,
    required this.nodes,
    required this.anchor,
  });

  /// Serialize to JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
        'type': type,
        'version': version,
        if (sourceDocumentId != null || sourceFrameId != null)
          'source': {
            if (sourceDocumentId != null) 'documentId': sourceDocumentId,
            if (sourceFrameId != null) 'frameId': sourceFrameId,
          },
        'rootIds': rootIds,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'anchor': {'x': anchor.dx, 'y': anchor.dy},
      };

  /// Create from JSON map.
  ///
  /// Throws if the JSON is invalid or has wrong type/version.
  factory ClipboardPayload.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type != payloadType) {
      throw FormatException('Invalid clipboard type: $type');
    }

    final version = json['version'] as int?;
    if (version == null || version < 1) {
      throw FormatException('Invalid clipboard version: $version');
    }

    final source = json['source'] as Map<String, dynamic>?;
    final anchorJson = json['anchor'] as Map<String, dynamic>?;
    if (anchorJson == null) {
      throw const FormatException('Missing anchor field');
    }

    final rootIds = (json['rootIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [];

    final nodes = (json['nodes'] as List<dynamic>?)
            ?.map((e) => Node.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return ClipboardPayload(
      type: type!,
      version: version,
      sourceDocumentId: source?['documentId'] as String?,
      sourceFrameId: source?['frameId'] as String?,
      rootIds: rootIds,
      nodes: nodes,
      anchor: Offset(
        (anchorJson['x'] as num).toDouble(),
        (anchorJson['y'] as num).toDouble(),
      ),
    );
  }

  /// Try to create from JSON string.
  ///
  /// Returns null if the JSON is invalid, not Distill clipboard data,
  /// or has incompatible schema.
  static ClipboardPayload? tryFromJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString);
      if (json is! Map<String, dynamic>) return null;

      // Check type before full parsing
      final type = json['type'];
      if (type != payloadType) return null;

      return ClipboardPayload.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Check if this payload is empty (no nodes to paste).
  bool get isEmpty => nodes.isEmpty || rootIds.isEmpty;

  /// Check if this payload has content.
  bool get isNotEmpty => !isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardPayload &&
          type == other.type &&
          version == other.version &&
          sourceDocumentId == other.sourceDocumentId &&
          sourceFrameId == other.sourceFrameId &&
          _listEquals(rootIds, other.rootIds) &&
          _listEquals(nodes, other.nodes) &&
          anchor == other.anchor;

  @override
  int get hashCode => Object.hash(
        type,
        version,
        sourceDocumentId,
        sourceFrameId,
        Object.hashAll(rootIds),
        Object.hashAll(nodes),
        anchor,
      );

  @override
  String toString() =>
      'ClipboardPayload(rootIds: $rootIds, nodes: ${nodes.length}, anchor: $anchor)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
