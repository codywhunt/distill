import '../utils/collection_equality.dart';
import 'component_def.dart';
import 'default_theme.dart';
import 'frame.dart';
import 'node.dart';
import 'theme_document.dart';

/// Root document containing all design data.
///
/// The document is immutable. Use [copyWith] to create modified copies.
class EditorDocument {
  /// IR version for compatibility checking.
  final String irVersion;

  /// Unique identifier for this document.
  final String documentId;

  /// All frames in the document (keyed by frame ID).
  final Map<String, Frame> frames;

  /// All nodes in the document (keyed by node ID).
  final Map<String, Node> nodes;

  /// Component definitions (keyed by component ID).
  final Map<String, ComponentDef> components;

  /// Design theme containing token definitions.
  ///
  /// Always has a value - defaults to [defaultTheme] if not specified.
  /// This ensures consumers don't need null checks when accessing tokens.
  final ThemeDocument theme;

  EditorDocument({
    this.irVersion = '1.0',
    required this.documentId,
    this.frames = const {},
    this.nodes = const {},
    this.components = const {},
    ThemeDocument? theme,
  }) : theme = theme ?? defaultTheme;

  /// Create an empty document with a unique ID.
  factory EditorDocument.empty({String? documentId}) {
    return EditorDocument(
      documentId: documentId ?? _generateId(),
    );
  }

  /// Create a copy with modified fields.
  EditorDocument copyWith({
    String? irVersion,
    String? documentId,
    Map<String, Frame>? frames,
    Map<String, Node>? nodes,
    Map<String, ComponentDef>? components,
    ThemeDocument? theme,
  }) {
    return EditorDocument(
      irVersion: irVersion ?? this.irVersion,
      documentId: documentId ?? this.documentId,
      frames: frames ?? this.frames,
      nodes: nodes ?? this.nodes,
      components: components ?? this.components,
      theme: theme ?? this.theme,
    );
  }

  /// Create an EditorDocument from JSON.
  factory EditorDocument.fromJson(Map<String, dynamic> json) {
    return EditorDocument(
      irVersion: json['irVersion'] as String? ?? '1.0',
      documentId: json['documentId'] as String,
      frames: (json['frames'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Frame.fromJson(v as Map<String, dynamic>)),
          ) ??
          const {},
      nodes: (json['nodes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Node.fromJson(v as Map<String, dynamic>)),
          ) ??
          const {},
      components: (json['components'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, ComponentDef.fromJson(v as Map<String, dynamic>)),
          ) ??
          const {},
      // Theme is optional in JSON - missing means use defaultTheme
      theme: json['theme'] != null
          ? ThemeDocument.fromJson(json['theme'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
        'irVersion': irVersion,
        'documentId': documentId,
        'frames': frames.map((k, v) => MapEntry(k, v.toJson())),
        'nodes': nodes.map((k, v) => MapEntry(k, v.toJson())),
        'components': components.map((k, v) => MapEntry(k, v.toJson())),
        // Only serialize theme if not default (saves space for typical documents)
        if (theme.id != 'default') 'theme': theme.toJson(),
      };

  // ===========================================================================
  // Convenience methods for immutable updates
  // ===========================================================================

  /// Add or update a frame.
  EditorDocument withFrame(Frame frame) {
    return copyWith(
      frames: {...frames, frame.id: frame},
    );
  }

  /// Remove a frame.
  EditorDocument withoutFrame(String frameId) {
    final newFrames = Map<String, Frame>.from(frames);
    newFrames.remove(frameId);
    return copyWith(frames: newFrames);
  }

  /// Add or update a node.
  EditorDocument withNode(Node node) {
    return copyWith(
      nodes: {...nodes, node.id: node},
    );
  }

  /// Remove a node.
  EditorDocument withoutNode(String nodeId) {
    final newNodes = Map<String, Node>.from(nodes);
    newNodes.remove(nodeId);
    return copyWith(nodes: newNodes);
  }

  /// Add or update a component.
  EditorDocument withComponent(ComponentDef component) {
    return copyWith(
      components: {...components, component.id: component},
    );
  }

  /// Remove a component.
  EditorDocument withoutComponent(String componentId) {
    final newComponents = Map<String, ComponentDef>.from(components);
    newComponents.remove(componentId);
    return copyWith(components: newComponents);
  }

  // ===========================================================================
  // Query methods
  // ===========================================================================

  /// Get all node IDs that are children of the given node.
  Set<String> getSubtree(String nodeId) {
    final result = <String>{nodeId};
    final node = nodes[nodeId];
    if (node == null) return result;

    for (final childId in node.childIds) {
      result.addAll(getSubtree(childId));
    }
    return result;
  }

  /// Build a parent index (child ID → parent ID).
  Map<String, String> buildParentIndex() {
    final index = <String, String>{};
    for (final node in nodes.values) {
      for (final childId in node.childIds) {
        index[childId] = node.id;
      }
    }
    return index;
  }

  /// Get all frame IDs that contain the given node.
  Set<String> getFramesContaining(String nodeId) {
    final result = <String>{};
    for (final frame in frames.values) {
      if (getSubtree(frame.rootNodeId).contains(nodeId)) {
        result.add(frame.id);
      }
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorDocument &&
          irVersion == other.irVersion &&
          documentId == other.documentId &&
          mapEquals(frames, other.frames) &&
          mapEquals(nodes, other.nodes) &&
          mapEquals(components, other.components) &&
          theme == other.theme;

  @override
  int get hashCode => Object.hash(
        irVersion,
        documentId,
        Object.hashAll(frames.entries),
        Object.hashAll(nodes.entries),
        Object.hashAll(components.entries),
        theme,
      );

  @override
  String toString() =>
      'EditorDocument(id: $documentId, frames: ${frames.length}, nodes: ${nodes.length})';
}

int _idCounter = 0;
String _generateId() => 'doc_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
