import 'dart:ui';

import '../models/editor_document.dart';
import '../models/frame.dart';
import '../models/node.dart';
import '../models/node_layout.dart';
import '../models/node_props.dart';
import '../models/node_style.dart';
import '../models/numeric_value.dart';
import '../models/node_type.dart';
import 'patch_op.dart';

/// Applies patch operations to produce new documents.
///
/// All operations are immutable - a new document is returned.
class PatchApplier {
  const PatchApplier();

  /// Apply a patch operation to a document.
  EditorDocument apply(EditorDocument doc, PatchOp op) {
    return switch (op) {
      SetProp() => _applySetProp(doc, op),
      SetFrameProp() => _applySetFrameProp(doc, op),
      InsertNode() => _applyInsertNode(doc, op),
      AttachChild() => _applyAttachChild(doc, op),
      DetachChild() => _applyDetachChild(doc, op),
      DeleteNode() => _applyDeleteNode(doc, op),
      MoveNode() => _applyMoveNode(doc, op),
      ReplaceNode() => _applyReplaceNode(doc, op),
      InsertFrame() => _applyInsertFrame(doc, op),
      RemoveFrame() => _applyRemoveFrame(doc, op),
    };
  }

  /// Apply multiple patches in order.
  EditorDocument applyAll(EditorDocument doc, Iterable<PatchOp> ops) {
    var result = doc;
    for (final op in ops) {
      result = apply(result, op);
    }
    return result;
  }

  // ===========================================================================
  // Property Operations
  // ===========================================================================

  EditorDocument _applySetProp(EditorDocument doc, SetProp op) {
    final node = doc.nodes[op.id];
    if (node == null) return doc;

    final updatedNode = _setNodeProperty(node, op.path, op.value);
    return doc.withNode(updatedNode);
  }

  EditorDocument _applySetFrameProp(EditorDocument doc, SetFrameProp op) {
    final frame = doc.frames[op.frameId];
    if (frame == null) return doc;

    final updatedFrame = _setFrameProperty(frame, op.path, op.value);
    return doc.withFrame(updatedFrame);
  }

  // ===========================================================================
  // Node Structure Operations
  // ===========================================================================

  EditorDocument _applyInsertNode(EditorDocument doc, InsertNode op) {
    return doc.withNode(op.node);
  }

  EditorDocument _applyAttachChild(EditorDocument doc, AttachChild op) {
    final parent = doc.nodes[op.parentId];
    if (parent == null) return doc;

    final newChildren = List<String>.from(parent.childIds);
    if (op.index < 0 || op.index >= newChildren.length) {
      newChildren.add(op.childId);
    } else {
      newChildren.insert(op.index, op.childId);
    }

    return doc.withNode(parent.copyWith(childIds: newChildren));
  }

  EditorDocument _applyDetachChild(EditorDocument doc, DetachChild op) {
    final parent = doc.nodes[op.parentId];
    if (parent == null) return doc;

    final newChildren = parent.childIds.where((id) => id != op.childId).toList();
    return doc.withNode(parent.copyWith(childIds: newChildren));
  }

  EditorDocument _applyDeleteNode(EditorDocument doc, DeleteNode op) {
    return doc.withoutNode(op.id);
  }

  EditorDocument _applyMoveNode(EditorDocument doc, MoveNode op) {
    // Find current parent
    final parentIndex = doc.buildParentIndex();
    final currentParentId = parentIndex[op.id];

    var result = doc;

    // Detach from current parent (if any)
    if (currentParentId != null) {
      result = _applyDetachChild(
        result,
        DetachChild(parentId: currentParentId, childId: op.id),
      );
    }

    // Attach to new parent
    result = _applyAttachChild(
      result,
      AttachChild(
        parentId: op.newParentId,
        childId: op.id,
        index: op.index,
      ),
    );

    return result;
  }

  EditorDocument _applyReplaceNode(EditorDocument doc, ReplaceNode op) {
    if (!doc.nodes.containsKey(op.id)) return doc;
    return doc.withNode(op.node);
  }

  // ===========================================================================
  // Frame Operations
  // ===========================================================================

  EditorDocument _applyInsertFrame(EditorDocument doc, InsertFrame op) {
    return doc.withFrame(op.frame);
  }

  EditorDocument _applyRemoveFrame(EditorDocument doc, RemoveFrame op) {
    return doc.withoutFrame(op.frameId);
  }

  // ===========================================================================
  // Property Path Helpers
  // ===========================================================================

  /// Set a property on a node by JSON Pointer path.
  Node _setNodeProperty(Node node, String path, dynamic value) {
    final segments = _parsePath(path);
    if (segments.isEmpty) return node;

    final root = segments[0];
    return switch (root) {
      'layout' => node.copyWith(
          layout: _setLayoutProperty(node.layout, segments.sublist(1), value),
        ),
      'style' => node.copyWith(
          style: _setStyleProperty(node.style, segments.sublist(1), value),
        ),
      'props' => node.copyWith(
          props: _setPropsProperty(node.type, node.props, segments.sublist(1), value),
        ),
      'name' => node.copyWith(name: value as String),
      'childIds' => node.copyWith(childIds: (value as List).cast<String>()),
      _ => node, // Unknown path, ignore
    };
  }

  /// Set a property on a frame by JSON Pointer path.
  Frame _setFrameProperty(Frame frame, String path, dynamic value) {
    final segments = _parsePath(path);
    if (segments.isEmpty) return frame;

    final root = segments[0];
    return switch (root) {
      'canvas' => frame.copyWith(
          canvas: _setCanvasProperty(frame.canvas, segments.sublist(1), value),
        ),
      'name' => frame.copyWith(name: value as String),
      'rootNodeId' => frame.copyWith(rootNodeId: value as String),
      _ => frame, // Unknown path, ignore
    };
  }

  NodeLayout _setLayoutProperty(
    NodeLayout layout,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return NodeLayout.fromJson(value as Map<String, dynamic>);
    }

    final root = segments[0];
    return switch (root) {
      'position' when segments.length == 1 =>
        layout.copyWith(position: PositionMode.fromJson(value as Map<String, dynamic>)),
      'position' => layout.copyWith(
          position: _setPositionProperty(layout.position, segments.sublist(1), value),
        ),
      'size' when segments.length == 1 =>
        layout.copyWith(size: SizeMode.fromJson(value as Map<String, dynamic>)),
      'size' => layout.copyWith(
          size: _setSizeProperty(layout.size, segments.sublist(1), value),
        ),
      'autoLayout' when segments.length == 1 =>
        layout.copyWith(
          autoLayout: value != null
              ? AutoLayout.fromJson(value as Map<String, dynamic>)
              : null,
        ),
      'autoLayout' => layout.copyWith(
          autoLayout: layout.autoLayout != null
              ? _setAutoLayoutProperty(layout.autoLayout!, segments.sublist(1), value)
              : null,
        ),
      'constraints' => layout.copyWith(
          constraints: value != null
              ? LayoutConstraints.fromJson(value as Map<String, dynamic>)
              : null,
        ),
      _ => layout,
    };
  }

  PositionMode _setPositionProperty(
    PositionMode position,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return PositionMode.fromJson(value as Map<String, dynamic>);
    }

    // Can only modify x/y on absolute positions
    if (position is! PositionModeAbsolute) {
      // Convert to absolute if setting x or y
      if (segments[0] == 'x' || segments[0] == 'y') {
        final x = segments[0] == 'x' ? (value as num).toDouble() : 0.0;
        final y = segments[0] == 'y' ? (value as num).toDouble() : 0.0;
        return PositionModeAbsolute(x: x, y: y);
      }
      return position;
    }

    return switch (segments[0]) {
      'x' => PositionModeAbsolute(x: (value as num).toDouble(), y: position.y),
      'y' => PositionModeAbsolute(x: position.x, y: (value as num).toDouble()),
      _ => position,
    };
  }

  SizeMode _setSizeProperty(
    SizeMode size,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return SizeMode.fromJson(value as Map<String, dynamic>);
    }

    final axis = segments[0]; // 'width' or 'height'

    if (axis == 'width') {
      if (segments.length == 1) {
        // Replacing entire width axis: /layout/size/width
        return size.copyWith(
          width: AxisSize.fromJson(value as Map<String, dynamic>),
        );
      } else if (segments[1] == 'value') {
        // Setting width value: /layout/size/width/value
        final newValue = (value as num).toDouble();
        return size.copyWith(width: AxisSizeFixed(newValue));
      }
    } else if (axis == 'height') {
      if (segments.length == 1) {
        // Replacing entire height axis: /layout/size/height
        return size.copyWith(
          height: AxisSize.fromJson(value as Map<String, dynamic>),
        );
      } else if (segments[1] == 'value') {
        // Setting height value: /layout/size/height/value
        final newValue = (value as num).toDouble();
        return size.copyWith(height: AxisSizeFixed(newValue));
      }
    }

    return size;
  }

  AutoLayout _setAutoLayoutProperty(
    AutoLayout autoLayout,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return AutoLayout.fromJson(value as Map<String, dynamic>);
    }

    final property = segments[0];
    return switch (property) {
      'direction' => autoLayout.copyWith(
          direction: LayoutDirection.values.firstWhere(
            (e) => e.name == value,
            orElse: () => LayoutDirection.vertical,
          ),
        ),
      'gap' => autoLayout.copyWith(gap: FixedNumeric((value as num).toDouble())),
      'mainAlign' => autoLayout.copyWith(
          mainAlign: MainAxisAlignment.values.firstWhere(
            (e) => e.name == value,
            orElse: () => MainAxisAlignment.start,
          ),
        ),
      'crossAlign' => autoLayout.copyWith(
          crossAlign: CrossAxisAlignment.values.firstWhere(
            (e) => e.name == value,
            orElse: () => CrossAxisAlignment.start,
          ),
        ),
      'padding' => autoLayout.copyWith(
          padding: TokenEdgePadding.fromJson(value as Map<String, dynamic>),
        ),
      _ => autoLayout,
    };
  }

  NodeStyle _setStyleProperty(
    NodeStyle style,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return NodeStyle.fromJson(value as Map<String, dynamic>);
    }

    final root = segments[0];
    return switch (root) {
      'fill' when segments.length == 1 => style.copyWith(
          fill: value != null
              ? Fill.fromJson(value as Map<String, dynamic>)
              : null,
        ),
      'fill' => style.copyWith(
          fill: _setFillProperty(style.fill, segments.sublist(1), value),
        ),
      'stroke' => style.copyWith(
          stroke: value != null
              ? Stroke.fromJson(value as Map<String, dynamic>)
              : null,
        ),
      'cornerRadius' when segments.length == 1 => style.copyWith(
          cornerRadius: value != null
              ? CornerRadius.fromJson(value as Map<String, dynamic>)
              : null,
        ),
      'cornerRadius' => style.copyWith(
          cornerRadius: _setCornerRadiusProperty(
            style.cornerRadius,
            segments.sublist(1),
            value,
          ),
        ),
      'shadow' => style.copyWith(
          shadow: value != null
              ? Shadow.fromJson(value as Map<String, dynamic>)
              : null,
        ),
      'opacity' => style.copyWith(opacity: (value as num).toDouble()),
      'visible' => style.copyWith(visible: value as bool),
      _ => style,
    };
  }

  Fill? _setFillProperty(Fill? fill, List<String> segments, dynamic value) {
    if (segments.isEmpty) {
      return value != null ? Fill.fromJson(value as Map<String, dynamic>) : null;
    }

    // Handle /style/fill/color/hex path
    if (segments.length >= 2 && segments[0] == 'color' && segments[1] == 'hex') {
      final hexValue = value as String;
      return SolidFill(HexColor(hexValue));
    }

    // Handle /style/fill/color path (full color object)
    if (segments.length == 1 && segments[0] == 'color') {
      final colorJson = value as Map<String, dynamic>;
      return SolidFill(ColorValue.fromJson(colorJson));
    }

    return fill;
  }

  CornerRadius? _setCornerRadiusProperty(
    CornerRadius? radius,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return value != null
          ? CornerRadius.fromJson(value as Map<String, dynamic>)
          : null;
    }

    final property = segments[0];
    final numValue = (value as num).toDouble();
    final base = radius ?? const CornerRadius();

    // Handle setting individual corners or 'all'
    final fixedValue = FixedNumeric(numValue);
    return switch (property) {
      'all' => CornerRadius.all(fixedValue),
      'topLeft' => CornerRadius(
          topLeft: fixedValue,
          topRight: base.topRight,
          bottomRight: base.bottomRight,
          bottomLeft: base.bottomLeft,
        ),
      'topRight' => CornerRadius(
          topLeft: base.topLeft,
          topRight: fixedValue,
          bottomRight: base.bottomRight,
          bottomLeft: base.bottomLeft,
        ),
      'bottomLeft' => CornerRadius(
          topLeft: base.topLeft,
          topRight: base.topRight,
          bottomRight: base.bottomRight,
          bottomLeft: fixedValue,
        ),
      'bottomRight' => CornerRadius(
          topLeft: base.topLeft,
          topRight: base.topRight,
          bottomRight: fixedValue,
          bottomLeft: base.bottomLeft,
        ),
      _ => radius,
    };
  }

  NodeProps _setPropsProperty(
    NodeType type,
    NodeProps props,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return NodeProps.fromJson(type, value as Map<String, dynamic>);
    }

    // For now, reconstruct the entire props from JSON with the update
    final json = props.toJson();
    _setNestedValue(json, segments, value);
    return NodeProps.fromJson(type, json);
  }

  CanvasPlacement _setCanvasProperty(
    CanvasPlacement canvas,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) {
      return CanvasPlacement.fromJson(value as Map<String, dynamic>);
    }

    final root = segments[0];
    return switch (root) {
      'position' when segments.length == 1 => canvas.copyWith(
          position: Offset(
            (value['x'] as num).toDouble(),
            (value['y'] as num).toDouble(),
          ),
        ),
      'position' when segments.length > 1 => switch (segments[1]) {
          'x' => canvas.copyWith(
              position: Offset((value as num).toDouble(), canvas.position.dy),
            ),
          'y' => canvas.copyWith(
              position: Offset(canvas.position.dx, (value as num).toDouble()),
            ),
          _ => canvas,
        },
      'size' when segments.length == 1 => canvas.copyWith(
          size: Size(
            (value['width'] as num).toDouble(),
            (value['height'] as num).toDouble(),
          ),
        ),
      'size' when segments.length > 1 => switch (segments[1]) {
          'width' => canvas.copyWith(
              size: Size((value as num).toDouble(), canvas.size.height),
            ),
          'height' => canvas.copyWith(
              size: Size(canvas.size.width, (value as num).toDouble()),
            ),
          _ => canvas,
        },
      _ => canvas,
    };
  }

  /// Parse a JSON Pointer path into segments.
  List<String> _parsePath(String path) {
    if (path.isEmpty) return [];
    if (!path.startsWith('/')) return [path];
    return path.substring(1).split('/');
  }

  /// Set a nested value in a map.
  void _setNestedValue(
    Map<String, dynamic> map,
    List<String> segments,
    dynamic value,
  ) {
    if (segments.isEmpty) return;

    if (segments.length == 1) {
      map[segments[0]] = value;
      return;
    }

    final key = segments[0];
    if (!map.containsKey(key) || map[key] is! Map<String, dynamic>) {
      map[key] = <String, dynamic>{};
    }
    _setNestedValue(
      map[key] as Map<String, dynamic>,
      segments.sublist(1),
      value,
    );
  }
}
