# Free Design DSL: Design Document

> **Status:** Draft v0.5
> **Last Updated:** 2026-01-09
> **Authors:** Architecture Team

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Goals & Non-Goals](#goals--non-goals)
3. [Architecture Overview](#architecture-overview)
4. [Layer 1: Editor IR (Scene Graph)](#layer-1-editor-ir-scene-graph)
5. [Expanded Scene (Instance Expansion)](#expanded-scene-instance-expansion)
6. [Layer 2: Render DSL](#layer-2-render-dsl)
7. [Layer 3: Agent-Based Codegen](#layer-3-agent-based-codegen)
8. [Patch Protocol](#patch-protocol)
9. [Canvas Integration](#canvas-integration)
10. [Agent Integration](#agent-integration)
11. [Design Token System](#design-token-system)
12. [Component Library](#component-library)
13. [Test Suite](#test-suite)
14. [Implementation Roadmap](#implementation-roadmap)
15. [Open Questions](#open-questions)

---

## Executive Summary

This document describes a **two-layer intermediate representation (IR) with agent-based codegen** for building Figma-like visual editing in Hologram's "Free Design" mode. The system enables:

- **Canvas editing**: Drag, resize, reparent widgets with instant visual feedback
- **Agent generation**: AI agents can read, write, and patch UI structures
- **Flutter codegen**: Agent interprets designs and produces clean, idiomatic Flutter code

The core insight is that **editing semantics and rendering have different requirements** and should be handled by separate representations, while **code generation benefits from agent intelligence** rather than rigid compilation rules.

```
┌─────────────────────────────────────────────────────────────────┐
│                    Canvas (distill_canvas)                         │
│         Frame positions, zoom, selection, drag handles          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 EDITOR IR (Source of Truth)                     │
│   Nodes, Layout, Styles, Components, Instances                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│               EXPANDED SCENE (Derived, Disposable)              │
│   Instances flattened, overrides applied, IDs namespaced        │
└─────────────────────────────────────────────────────────────────┘
           │                                    │
           ▼                                    ▼
┌─────────────────────────┐        ┌─────────────────────────────┐
│      RENDER DSL         │        │     AGENT CODEGEN           │
│  (Deterministic)        │        │  (LLM Interpretation)       │
│  ExpandedScene→Widgets  │        │  Editor IR → Flutter Code   │
└─────────────────────────┘        └─────────────────────────────┘
           │                                    │
           ▼                                    ▼
┌─────────────────────────┐        ┌─────────────────────────────┐
│   Live Flutter Preview  │        │   Generated .dart files     │
└─────────────────────────┘        └─────────────────────────────┘
```

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Schema language | **Dart** | Native to the codebase |
| Codegen approach | **Agent-interpreted** | Higher quality output, contextual decisions |
| Token source | **Per-project theme** | User's project theme provides tokens |
| Component scope | **Global library** | Enables reusable component library |
| Storage | **Local state (v1)** | Simple; persistence can be added later |
| Canvas mode | **Replaces browse/edit** | Free design becomes the canvas module |

### V1 Implementation Notes

The following are intentional simplifications in v1 that differ from the full spec:

| Area | V1 Implementation | Full Spec (v2) | Rationale |
|------|-------------------|----------------|-----------|
| **Component nodes** | Reference global `document.nodes` via `rootNodeId` | Isolated `Map<String, Node> nodes` per component | Simpler queries; ID namespacing in ExpandedScene handles isolation |
| **Instance editing** | UI promotes selection to instance; patches target instance node | Users can "enter" instances to edit children in place | Reduces complexity; component editing via separate view |
| **SizeMode** | Unified enum: `hug`, `fill`, `fixed`, `hugWidth`, `hugHeight` | Separate `width: SizeMode` and `height: SizeMode` in `SizeSpec` | Simpler serialization and fewer edge cases |
| **NodeMeta** | Not implemented | `NodeMeta?` field for editor-only metadata | Not needed for v1 editing |
| **Token system** | Colors, spacing, radius tokens only | Full tokens including typography, shadows | Sufficient for v1; extend as needed |
| **Cache invalidation** | Clear entire frame cache on node change | Selective invalidation via expanded ID mapping | Simpler; still performant for v1 scale |

---

## Goals & Non-Goals

### Goals

1. **Figma-like canvas experience**
   - Drag to move frames and nodes
   - Resize with 8-point handles
   - Auto-layout (row/column with gap)
   - Smart guides and snap-to-grid
   - Multi-selection and marquee

2. **Agent-native DSL**
   - Small vocabulary (~10 node types)
   - Consistent, predictable structure
   - Token-based styling (agents use project theme tokens)
   - Patch-friendly (small edits, not full rewrites)

3. **High-quality Flutter codegen**
   - Agent interprets design intent
   - Idiomatic widget composition
   - Proper component extraction
   - Theme token integration

4. **Performance at scale**
   - Handle 100+ nodes per frame smoothly
   - Incremental compilation (only recompile changed subtrees)
   - Efficient spatial indexing for hit testing

### Non-Goals (v1)

1. **Responsive breakpoints** - v2
2. **Animations/transitions** - v2
3. **Data binding/expressions** - v2
4. **Interactions beyond tap** - v2
5. **Persistence to Firestore** - v2 (local state only for v1)
6. **Enter instance editing** - v2 (edit component instances inline)

---

## Architecture Overview

### Why Two Layers + Agent?

| Layer | Purpose | Implementation |
|-------|---------|----------------|
| **Editor IR** | Source of truth for designs | Dart models, JSON serializable |
| **Render DSL** | Fast preview rendering | Deterministic compiler |
| **Agent Codegen** | Flutter code generation | LLM interprets and generates |

**Key insight**: Codegen quality matters more than codegen speed. Agent interpretation produces better code than rigid compilation rules because it can:
- Make contextual naming decisions
- Extract components intelligently
- Follow Flutter idioms naturally
- Add appropriate comments and structure

### Data Flow

```
User drags node on canvas
        │
        ▼
Patch emitted: SetProp(id: 'btn1', path: '/layout/size/width', value: 200)
        │
        ▼
Editor IR updated (immutable copy-on-write)
        │
        ▼
Dirty nodes marked in compilation cache
        │
        ▼
Incremental compile: Editor IR → Render DSL (only dirty subtrees)
        │
        ▼
Flutter widget tree rebuilt (minimal via stable keys)
        │
        ▼
Preview updates at 60fps
```

---

## Layer 1: Editor IR (Scene Graph)

The Editor IR is the **source of truth** for all design data. It uses Dart classes that serialize to/from JSON.

### Document Structure

```dart
/// Root document containing all design data
class EditorDocument {
  final String irVersion;
  final String documentId;
  final Map<String, Frame> frames;
  final Map<String, Node> nodes;
  final Map<String, ComponentDef> components;  // Global component library

  const EditorDocument({
    this.irVersion = '1.0',
    required this.documentId,
    required this.frames,
    required this.nodes,
    required this.components,
  });

  factory EditorDocument.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  EditorDocument copyWith({
    Map<String, Frame>? frames,
    Map<String, Node>? nodes,
    Map<String, ComponentDef>? components,
  });
}
```

### Frame (Top-Level Canvas Surface)

Frames are top-level design surfaces (screens, pages, modals). They exist on the infinite canvas and replace the old `PageModel`.

```dart
/// A frame on the canvas (screen, page, modal, etc.)
class Frame {
  final String id;
  final String name;
  final String rootNodeId;

  // Canvas placement (world coordinates)
  final CanvasPlacement canvas;

  // Metadata
  final String? devicePreset;    // 'iphone_17_pro' or null for custom
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Frame({
    required this.id,
    required this.name,
    required this.rootNodeId,
    required this.canvas,
    this.devicePreset,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Frame.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

class CanvasPlacement {
  final Offset position;  // World coordinates
  final Size size;        // Device/frame size

  const CanvasPlacement({
    required this.position,
    required this.size,
  });

  factory CanvasPlacement.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### Node (Visual Element)

Everything visual is a node. Nodes form a tree via `children` arrays.

```dart
/// A visual element in the design
class Node {
  final String id;
  final NodeType type;
  final String name;

  // Tree structure
  final List<String> children;

  // Layout (sizing and auto-layout)
  final NodeLayout layout;

  // Visual styling
  final NodeStyle style;

  // Type-specific properties
  final NodeProps props;

  // Editor metadata (not rendered)
  final NodeMeta? meta;

  const Node({
    required this.id,
    required this.type,
    required this.name,
    required this.children,
    required this.layout,
    required this.style,
    required this.props,
    this.meta,
  });

  factory Node.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();

  Node copyWith({
    String? name,
    List<String>? children,
    NodeLayout? layout,
    NodeStyle? style,
    NodeProps? props,
    NodeMeta? meta,
  });
}

enum NodeType {
  container,   // Box with optional children
  text,        // Text content
  image,       // Image asset
  icon,        // Icon from icon set
  spacer,      // Flexible space (Expanded/Spacer)
  instance,    // Component instance
  slot,        // Component slot placeholder
}
```

### NodeLayout (Sizing & Auto-Layout)

The layout model supports **auto-layout** (Figma-style stacks) as the primary mode, with **absolute positioning** for free placement.

```dart
/// Layout properties for a node
class NodeLayout {
  final PositionMode position;  // auto (participates in parent layout) or absolute
  final SizeSpec size;
  final AutoLayout? autoLayout;
  final CrossAlign? alignSelf;  // Override parent's crossAlign

  const NodeLayout({
    this.position = const PositionMode.auto(),
    required this.size,
    this.autoLayout,
    this.alignSelf,
  });

  factory NodeLayout.defaults() => NodeLayout(
    size: SizeSpec.hug(),
  );

  factory NodeLayout.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

/// How a node is positioned within its parent
///
/// Serializes as:
/// - Auto: `{ "mode": "auto" }`
/// - Absolute: `{ "mode": "absolute", "x": 100, "y": 200 }`
///
/// This allows patching via paths like `/layout/position/x`
sealed class PositionMode {
  const PositionMode();

  /// Participates in parent's auto-layout flow
  const factory PositionMode.auto() = PositionModeAuto;

  /// Absolutely positioned relative to parent
  const factory PositionMode.absolute({
    required double x,
    required double y,
  }) = PositionModeAbsolute;

  factory PositionMode.fromJson(Map<String, dynamic> json) {
    return switch (json['mode']) {
      'auto' => const PositionModeAuto(),
      'absolute' => PositionModeAbsolute(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
      ),
      _ => throw ArgumentError('Unknown position mode: ${json['mode']}'),
    };
  }

  Map<String, dynamic> toJson();
}

class PositionModeAuto extends PositionMode {
  const PositionModeAuto();

  @override
  Map<String, dynamic> toJson() => {'mode': 'auto'};
}

class PositionModeAbsolute extends PositionMode {
  final double x;
  final double y;
  const PositionModeAbsolute({required this.x, required this.y});

  @override
  Map<String, dynamic> toJson() => {'mode': 'absolute', 'x': x, 'y': y};

  PositionModeAbsolute copyWith({double? x, double? y}) =>
      PositionModeAbsolute(x: x ?? this.x, y: y ?? this.y);
}

/// Size specification for width/height
class SizeSpec {
  final SizeMode width;
  final SizeMode height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  const SizeSpec({
    required this.width,
    required this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
  });

  factory SizeSpec.hug() => const SizeSpec(
    width: SizeMode.hug(),
    height: SizeMode.hug(),
  );

  factory SizeSpec.fill() => const SizeSpec(
    width: SizeMode.fill(),
    height: SizeMode.fill(),
  );

  factory SizeSpec.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

/// How a dimension is sized
sealed class SizeMode {
  const SizeMode();

  const factory SizeMode.hug() = SizeModeHug;
  const factory SizeMode.fill() = SizeModeFill;
  const factory SizeMode.fixed(double value) = SizeModeFixed;

  factory SizeMode.fromJson(dynamic json);
  dynamic toJson();
}

class SizeModeHug extends SizeMode {
  const SizeModeHug();
}

class SizeModeFill extends SizeMode {
  const SizeModeFill();
}

class SizeModeFixed extends SizeMode {
  final double value;
  const SizeModeFixed(this.value);
}

/// Auto-layout configuration (Figma-style)
class AutoLayout {
  final AxisDirection direction;
  final SpacingValue gap;
  final EdgeInsetsSpec padding;
  final MainAlign mainAlign;
  final CrossAlign crossAlign;

  const AutoLayout({
    required this.direction,
    required this.gap,
    required this.padding,
    this.mainAlign = MainAlign.start,
    this.crossAlign = CrossAlign.start,
  });

  factory AutoLayout.row({double gap = 0}) => AutoLayout(
    direction: AxisDirection.horizontal,
    gap: SpacingValue.fixed(gap),
    padding: EdgeInsetsSpec.zero,
  );

  factory AutoLayout.column({double gap = 0}) => AutoLayout(
    direction: AxisDirection.vertical,
    gap: SpacingValue.fixed(gap),
    padding: EdgeInsetsSpec.zero,
  );

  factory AutoLayout.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

enum AxisDirection { horizontal, vertical }
enum MainAlign { start, center, end, spaceBetween, spaceAround, spaceEvenly }
enum CrossAlign { start, center, end, stretch }

/// Spacing that can be a fixed value or a token reference
sealed class SpacingValue {
  const SpacingValue();

  const factory SpacingValue.fixed(double value) = SpacingFixed;
  const factory SpacingValue.token(String token) = SpacingToken;

  factory SpacingValue.fromJson(dynamic json);
  dynamic toJson();
}

class SpacingFixed extends SpacingValue {
  final double value;
  const SpacingFixed(this.value);
}

class SpacingToken extends SpacingValue {
  final String token;
  const SpacingToken(this.token);
}

/// Edge insets with token support
class EdgeInsetsSpec {
  final SpacingValue top;
  final SpacingValue right;
  final SpacingValue bottom;
  final SpacingValue left;

  const EdgeInsetsSpec({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  static const zero = EdgeInsetsSpec(
    top: SpacingFixed(0),
    right: SpacingFixed(0),
    bottom: SpacingFixed(0),
    left: SpacingFixed(0),
  );

  factory EdgeInsetsSpec.all(SpacingValue value) => EdgeInsetsSpec(
    top: value,
    right: value,
    bottom: value,
    left: value,
  );

  factory EdgeInsetsSpec.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### NodeStyle (Visual Properties)

All visual properties use **tokens** where possible. Tokens come from the user's project theme.

```dart
/// Visual styling for a node
class NodeStyle {
  final ColorValue? fill;
  final BorderSpec? border;
  final RadiusValue? radius;
  final ShadowValue? shadow;
  final double? opacity;
  final bool visible;

  const NodeStyle({
    this.fill,
    this.border,
    this.radius,
    this.shadow,
    this.opacity,
    this.visible = true,
  });

  factory NodeStyle.defaults() => const NodeStyle();

  factory NodeStyle.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

/// Color that can be a hex value or token reference
sealed class ColorValue {
  const ColorValue();

  const factory ColorValue.hex(String hex, {double? opacity}) = ColorHex;
  const factory ColorValue.token(String token) = ColorToken;

  factory ColorValue.fromJson(dynamic json);
  dynamic toJson();
}

class ColorHex extends ColorValue {
  final String hex;
  final double? opacity;
  const ColorHex(this.hex, {this.opacity});
}

class ColorToken extends ColorValue {
  final String token;
  const ColorToken(this.token);
}

/// Border specification
class BorderSpec {
  final ColorValue color;
  final double width;

  const BorderSpec({
    required this.color,
    required this.width,
  });

  factory BorderSpec.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

/// Border radius that can be uniform or per-corner
sealed class RadiusValue {
  const RadiusValue();

  const factory RadiusValue.all(double value) = RadiusAll;
  const factory RadiusValue.only({
    double topLeft,
    double topRight,
    double bottomRight,
    double bottomLeft,
  }) = RadiusOnly;
  const factory RadiusValue.token(String token) = RadiusToken;

  factory RadiusValue.fromJson(dynamic json);
  dynamic toJson();
}

class RadiusAll extends RadiusValue {
  final double value;
  const RadiusAll(this.value);
}

class RadiusOnly extends RadiusValue {
  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;
  const RadiusOnly({
    this.topLeft = 0,
    this.topRight = 0,
    this.bottomRight = 0,
    this.bottomLeft = 0,
  });
}

class RadiusToken extends RadiusValue {
  final String token;
  const RadiusToken(this.token);
}

/// Shadow specification
class ShadowValue {
  final ColorValue color;
  final double offsetX;
  final double offsetY;
  final double blur;
  final double spread;

  const ShadowValue({
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.blur,
    this.spread = 0,
  });

  factory ShadowValue.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### NodeProps (Type-Specific)

```dart
/// Type-specific properties for nodes
sealed class NodeProps {
  const NodeProps();

  factory NodeProps.fromJson(NodeType type, Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

/// Container has no special props
class ContainerProps extends NodeProps {
  const ContainerProps();
}

/// Text node properties
class TextProps extends NodeProps {
  final String text;
  final TextStyleValue textStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const TextProps({
    required this.text,
    required this.textStyle,
    this.textAlign = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });
}

enum TextAlign { left, center, right }
enum TextOverflow { clip, ellipsis, fade }

/// Text style that can be inline or token reference
sealed class TextStyleValue {
  const TextStyleValue();

  const factory TextStyleValue.token(String token) = TextStyleToken;
  const factory TextStyleValue.custom({
    String? fontFamily,
    required double fontSize,
    required int fontWeight,
    double? lineHeight,
    double? letterSpacing,
    required ColorValue color,
  }) = TextStyleCustom;

  factory TextStyleValue.fromJson(dynamic json);
  dynamic toJson();
}

class TextStyleToken extends TextStyleValue {
  final String token;
  const TextStyleToken(this.token);
}

class TextStyleCustom extends TextStyleValue {
  final String? fontFamily;
  final double fontSize;
  final int fontWeight;
  final double? lineHeight;
  final double? letterSpacing;
  final ColorValue color;

  const TextStyleCustom({
    this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    this.lineHeight,
    this.letterSpacing,
    required this.color,
  });
}

/// Image node properties
class ImageProps extends NodeProps {
  final String src;
  final BoxFit fit;
  final String? alt;

  const ImageProps({
    required this.src,
    this.fit = BoxFit.cover,
    this.alt,
  });
}

enum BoxFit { contain, cover, fill, none, scaleDown }

/// Icon node properties
class IconProps extends NodeProps {
  final String name;  // 'lucide:plus', 'material:home'
  final double size;
  final ColorValue color;

  const IconProps({
    required this.name,
    required this.size,
    required this.color,
  });
}

/// Spacer node properties (flexible space in auto-layout)
class SpacerProps extends NodeProps {
  final int flex;  // Flex factor (default 1)

  const SpacerProps({this.flex = 1});
}

/// Component instance properties
class InstanceProps extends NodeProps {
  final String componentId;
  final List<Override> overrides;
  final Map<String, List<String>>? slotContent;

  const InstanceProps({
    required this.componentId,
    required this.overrides,
    this.slotContent,
  });
}

/// An override applied to a component instance
class Override {
  final String targetId;  // Node ID inside component
  final String path;      // JSON Pointer path
  final dynamic value;

  const Override({
    required this.targetId,
    required this.path,
    required this.value,
  });

  factory Override.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### NodeMeta (Editor-Only)

```dart
/// Editor metadata (not rendered)
/// NOTE: `expanded` (tree view expand state) is view-only state, not stored here
class NodeMeta {
  final bool locked;
  final bool hidden;
  final String? notes;
  final NodeProvenance? provenance;

  const NodeMeta({
    this.locked = false,
    this.hidden = false,
    this.notes,
    this.provenance,
  });

  factory NodeMeta.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

/// Tracks who created/modified a node
class NodeProvenance {
  final String createdBy;  // 'user' or 'agent'
  final String? agentContext;

  const NodeProvenance({
    required this.createdBy,
    this.agentContext,
  });

  factory NodeProvenance.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

---

## Expanded Scene (Instance Expansion)

The Expanded Scene is an **intermediate layer** that flattens component instances for rendering and hit testing. This is computed on-demand, not stored in the document.

### Why Expanded Scene?

Component instances in Editor IR are references (`InstanceProps.componentId`). For rendering and hit testing, we need the actual nodes. The Expanded Scene:

1. **Expands instances** - Clones component nodes with namespaced IDs
2. **Applies overrides** - Merges instance overrides into cloned nodes
3. **Enables hit testing** - Provides bounds for all visible nodes
4. **Tracks provenance** - Maps expanded IDs back to source

### ID Namespacing

When expanding an instance, node IDs are namespaced to prevent collisions:

```
instanceId::localNodeId

Example:
- Instance ID: "n_card1"
- Component has node: "btn_submit"
- Expanded ID: "n_card1::btn_submit"
```

### ExpandedScene

```dart
/// A flattened view of the scene with instances expanded
///
/// Provenance maps:
/// - `patchTarget`: expandedId → document node ID that patches should target
///   For regular nodes: returns the node's own ID
///   For nodes inside instances: returns the instance node ID (v1 no enter-instance)
///
/// The `isInsideInstance()` helper uses ID format (contains '::') for fast checks.
class ExpandedScene {
  final String frameId;
  final String rootId;
  final Map<String, ExpandedNode> nodes;

  /// Maps expandedId → document node ID that should receive patches
  /// For regular nodes: same ID
  /// For instance children: the instance node ID (since we can't patch inside instances in v1)
  final Map<String, String> patchTarget;

  const ExpandedScene({
    required this.frameId,
    required this.rootId,
    required this.nodes,
    required this.patchTarget,
  });

  /// Get the document node ID that patches should target for this expanded node
  String? getPatchTarget(String expandedId) => patchTarget[expandedId];

  /// Check if a node is inside an instance (by ID format)
  bool isInsideInstance(String expandedId) => expandedId.contains('::');

  /// Get the instance ID if this node is inside one, otherwise null
  String? getOwningInstance(String expandedId) {
    if (!isInsideInstance(expandedId)) return null;
    return expandedId.split('::').first;
  }
}

/// A node in the expanded scene (ready for rendering/hit testing)
class ExpandedNode {
  final String id;            // Expanded ID (may be namespaced like 'inst1::btn')
  final String patchTargetId; // Document node ID to patch (instance ID if inside component)
  final NodeType type;
  final List<String> children;
  final NodeLayout layout;
  final NodeStyle style;
  final NodeProps props;

  // Computed bounds (set during layout pass)
  Rect? bounds;

  ExpandedNode({
    required this.id,
    required this.patchTargetId,
    required this.type,
    required this.children,
    required this.layout,
    required this.style,
    required this.props,
    this.bounds,
  });
}
```

### ExpandedSceneBuilder

The builder is **stateless** - it takes the document at call time to ensure fresh data.

```dart
/// Builds an expanded scene from Editor IR (stateless - pass doc each time)
class ExpandedSceneBuilder {
  const ExpandedSceneBuilder();

  /// Build expanded scene for a frame
  ExpandedScene build(String frameId, EditorDocument doc) {
    final frame = doc.frames[frameId];
    if (frame == null) {
      throw StateError('Frame not found: $frameId');
    }

    final nodes = <String, ExpandedNode>{};
    final patchTarget = <String, String>{};

    _expandNode(
      nodeId: frame.rootNodeId,
      instanceId: null,
      doc: doc,
      output: nodes,
      patchTarget: patchTarget,
    );

    return ExpandedScene(
      frameId: frameId,
      rootId: frame.rootNodeId,
      nodes: nodes,
      patchTarget: patchTarget,
    );
  }

  void _expandNode({
    required String nodeId,
    required String? instanceId,
    required EditorDocument doc,
    required Map<String, ExpandedNode> output,
    required Map<String, String> patchTarget,
  }) {
    final node = doc.nodes[nodeId];
    if (node == null) return;

    final expandedId = instanceId != null ? '$instanceId::$nodeId' : nodeId;

    // Patch target: if inside instance, patches go to instance node; otherwise to self
    patchTarget[expandedId] = instanceId ?? nodeId;

    if (node.type == NodeType.instance) {
      _expandInstance(
        instanceNode: node,
        expandedInstanceId: expandedId,
        doc: doc,
        output: output,
        patchTarget: patchTarget,
      );
    } else {
      final expandedChildren = <String>[];

      for (final childId in node.children) {
        final childExpandedId = instanceId != null
            ? '$instanceId::$childId'
            : childId;
        expandedChildren.add(childExpandedId);
        _expandNode(
          nodeId: childId,
          instanceId: instanceId,
          doc: doc,
          output: output,
          patchTarget: patchTarget,
        );
      }

      output[expandedId] = ExpandedNode(
        id: expandedId,
        patchTargetId: instanceId ?? nodeId,
        type: node.type,
        children: expandedChildren,
        layout: node.layout,
        style: node.style,
        props: node.props,
      );
    }
  }

  void _expandInstance({
    required Node instanceNode,
    required String expandedInstanceId,
    required EditorDocument doc,
    required Map<String, ExpandedNode> output,
    required Map<String, String> patchTarget,
  }) {
    final props = instanceNode.props as InstanceProps;
    final component = doc.components[props.componentId];

    if (component == null) {
      // Fallback: render as error box
      output[expandedInstanceId] = ExpandedNode(
        id: expandedInstanceId,
        patchTargetId: instanceNode.id,
        type: NodeType.container,
        children: [],
        layout: instanceNode.layout,
        style: const NodeStyle(fill: ColorHex('#FF0000')),
        props: const ContainerProps(),
      );
      patchTarget[expandedInstanceId] = instanceNode.id;
      return;
    }

    // Build override map for quick lookup
    final overrideMap = <String, Map<String, dynamic>>{};
    for (final override in props.overrides) {
      overrideMap.putIfAbsent(override.targetId, () => {});
      overrideMap[override.targetId]![override.path] = override.value;
    }

    // Expand component nodes under this instance's namespace
    _expandComponentNodes(
      nodeId: component.rootNodeId,
      componentNodes: component.nodes,
      instanceNodeId: instanceNode.id,
      expandedInstanceId: expandedInstanceId,
      overrides: overrideMap,
      output: output,
      patchTarget: patchTarget,
    );

    // The instance itself maps to its document node
    patchTarget[expandedInstanceId] = instanceNode.id;
  }

  void _expandComponentNodes({
    required String nodeId,
    required Map<String, Node> componentNodes,
    required String instanceNodeId,
    required String expandedInstanceId,
    required Map<String, Map<String, dynamic>> overrides,
    required Map<String, ExpandedNode> output,
    required Map<String, String> patchTarget,
  }) {
    final node = componentNodes[nodeId];
    if (node == null) return;

    final expandedId = '$expandedInstanceId::$nodeId';

    // Apply overrides if any
    var layout = node.layout;
    var style = node.style;
    var props = node.props;

    final nodeOverrides = overrides[nodeId];
    if (nodeOverrides != null) {
      // Apply each override path
      layout = _applyOverrides(layout, nodeOverrides);
      style = _applyOverrides(style, nodeOverrides);
      props = _applyOverrides(props, nodeOverrides);
    }

    final expandedChildren = <String>[];
    for (final childId in node.children) {
      expandedChildren.add('$expandedInstanceId::$childId');
      _expandComponentNodes(
        nodeId: childId,
        componentNodes: componentNodes,
        instanceNodeId: instanceNodeId,
        expandedInstanceId: expandedInstanceId,
        overrides: overrides,
        output: output,
        patchTarget: patchTarget,
      );
    }

    output[expandedId] = ExpandedNode(
      id: expandedId,
      patchTargetId: instanceNodeId,  // Patches target the instance, not component internals
      type: node.type,
      children: expandedChildren,
      layout: layout,
      style: style,
      props: props,
    );

    // All nodes inside instance patch to the instance node
    patchTarget[expandedId] = instanceNodeId;
  }

  T _applyOverrides<T>(T target, Map<String, dynamic> overrides) {
    // TODO: Implement JSON pointer-based override application
    // For now, return unchanged
    return target;
  }
}
```

### V1 Limitation: No Enter Instance

In v1, users **cannot enter instances** to edit component internals in place. When a user selects a node that's inside an instance (`id.contains('::')`), the selection is promoted to the instance itself. This simplifies:

- Hit testing (only need to track instance bounds)
- Patch routing (patches always target document nodes, not expanded nodes)
- State management (no need to track "entered" state)

**Implementation detail**: The `patchTargetId` field in `ExpandedNode` points to the instance node ID for nodes inside instances. The `NodeTarget.canPatch` getter returns `false` for these nodes based on this field being set to the instance ID (not the node's own ID). The UI layer uses `canPatch` to promote selection to the parent instance rather than selecting individual children.

Component editing happens by opening the component definition separately (v2 will add inline editing).

---

## Layer 2: Render DSL

The Render DSL is a **compiled, flattened** representation optimized for fast Flutter rendering.

### Design Principles

1. **No editor metadata** - Only what's needed to render
2. **Resolved tokens** - All tokens replaced with concrete values from project theme
3. **Uses Expanded Scene** - Renders from ExpandedScene, not raw Editor IR
4. **Stable node IDs** - Same as Expanded Scene for widget key stability

### RenderDocument

```dart
/// Compiled document ready for rendering
class RenderDocument {
  final String rootId;
  final Map<String, RenderNode> nodes;

  const RenderDocument({
    required this.rootId,
    required this.nodes,
  });
}

/// A compiled node ready for rendering
class RenderNode {
  final String id;
  final RenderNodeType type;
  final Map<String, dynamic> props;  // Resolved, type-specific props
  final List<String> childIds;

  /// Computed bounds from layout pass (local to parent)
  /// Set after layout computation, used for hit testing
  Rect? computedBounds;

  RenderNode({
    required this.id,
    required this.type,
    required this.props,
    required this.childIds,
    this.computedBounds,
  });
}

enum RenderNodeType {
  box,
  row,
  column,
  text,
  image,
  icon,
  spacer,
}
```

### RenderCompiler

The RenderCompiler takes an **ExpandedScene** as input (not EditorDocument). This ensures:
- Instances are already expanded with overrides applied
- Cache keys use expanded IDs for per-instance correctness
- No instance compilation logic needed here

```dart
/// Compiles ExpandedScene to Render DSL with incremental support
///
/// IMPORTANT: Input is ExpandedScene, not EditorDocument.
/// Instance expansion happens in ExpandedSceneBuilder, not here.
class RenderCompiler {
  final TokenResolver _tokens;
  final Map<String, RenderNode> _cache = {};
  final Set<String> _dirty = {};

  RenderCompiler(this._tokens);

  /// Mark nodes as dirty (need recompilation)
  /// Uses expanded IDs (e.g., 'inst1::btn' not 'btn')
  void markDirty(Set<String> expandedIds) {
    _dirty.addAll(expandedIds);
  }

  /// Clear all cached compilations
  void invalidateAll() {
    _cache.clear();
    _dirty.clear();
  }

  /// Compile an expanded scene to render document
  RenderDocument compile(ExpandedScene scene) {
    final nodes = <String, RenderNode>{};
    _compileNodeRecursive(scene.rootId, scene, nodes);
    return RenderDocument(rootId: scene.rootId, nodes: nodes);
  }

  void _compileNodeRecursive(
    String expandedId,
    ExpandedScene scene,
    Map<String, RenderNode> output,
  ) {
    // Use cache if available and not dirty
    if (_cache.containsKey(expandedId) && !_dirty.contains(expandedId)) {
      output[expandedId] = _cache[expandedId]!;
    } else {
      final node = scene.nodes[expandedId];
      if (node == null) return;

      final renderNode = _compileExpandedNode(node);
      output[expandedId] = renderNode;
      _cache[expandedId] = renderNode;
      _dirty.remove(expandedId);
    }

    // Compile children
    final node = scene.nodes[expandedId];
    if (node != null) {
      for (final childId in node.children) {
        _compileNodeRecursive(childId, scene, output);
      }
    }
  }

  RenderNode _compileExpandedNode(ExpandedNode node) {
    // No instance handling here - instances are already expanded
    return switch (node.type) {
      NodeType.container => _compileContainer(node),
      NodeType.text => _compileText(node),
      NodeType.image => _compileImage(node),
      NodeType.icon => _compileIcon(node),
      NodeType.spacer => _compileSpacer(node),
      NodeType.instance => throw StateError('Instances should be expanded before compilation'),
      NodeType.slot => _compileSlot(node),
    };
  }

  RenderNode _compileContainer(ExpandedNode node) {
    final layout = node.layout;
    final style = node.style;

    // Determine render type based on auto-layout
    final type = switch (layout.autoLayout?.direction) {
      AxisDirection.horizontal => RenderNodeType.row,
      AxisDirection.vertical => RenderNodeType.column,
      null => RenderNodeType.box,
    };

    return RenderNode(
      id: node.id,
      type: type,
      props: {
        if (layout.autoLayout != null) ...{
          'gap': _resolveSpacing(layout.autoLayout!.gap),
          'padding': _resolveEdgeInsets(layout.autoLayout!.padding),
          'mainAlign': layout.autoLayout!.mainAlign.name,
          'crossAlign': layout.autoLayout!.crossAlign.name,
        },
        'width': _resolveSizeMode(layout.size.width),
        'height': _resolveSizeMode(layout.size.height),
        if (layout.size.minWidth != null) 'minWidth': layout.size.minWidth,
        if (layout.size.maxWidth != null) 'maxWidth': layout.size.maxWidth,
        if (style.fill != null) 'backgroundColor': _resolveColor(style.fill!),
        if (style.border != null) ...{
          'borderColor': _resolveColor(style.border!.color),
          'borderWidth': style.border!.width,
        },
        if (style.radius != null) 'borderRadius': _resolveRadius(style.radius!),
        if (style.opacity != null) 'opacity': style.opacity,
        // Absolute positioning
        if (layout.position is PositionModeAbsolute) ...{
          'position': 'absolute',
          'x': (layout.position as PositionModeAbsolute).x,
          'y': (layout.position as PositionModeAbsolute).y,
        },
      },
      children: node.children,
    );
  }

  RenderNode _compileText(ExpandedNode node) {
    final props = node.props as TextProps;
    return RenderNode(
      id: node.id,
      type: RenderNodeType.text,
      props: {
        'text': props.text,
        'style': _resolveTextStyle(props.textStyle),
        'textAlign': props.textAlign.name,
        if (props.maxLines != null) 'maxLines': props.maxLines,
        'overflow': props.overflow.name,
      },
      children: [],
    );
  }

  RenderNode _compileSpacer(ExpandedNode node) {
    final props = node.props as SpacerProps;
    return RenderNode(
      id: node.id,
      type: RenderNodeType.spacer,
      props: {
        'flex': props.flex,
      },
      children: [],
    );
  }

  RenderNode _compileSlot(ExpandedNode node) {
    // Slots render as empty boxes (placeholder for slot content)
    return RenderNode(
      id: node.id,
      type: RenderNodeType.box,
      props: {},
      children: node.children,
    );
  }

  RenderNode _compileImage(ExpandedNode node) {
    final props = node.props as ImageProps;
    return RenderNode(
      id: node.id,
      type: RenderNodeType.image,
      props: {
        'src': props.src,
        'fit': props.fit.name,
        if (props.alt != null) 'alt': props.alt,
      },
      children: [],
    );
  }

  RenderNode _compileIcon(ExpandedNode node) {
    final props = node.props as IconProps;
    return RenderNode(
      id: node.id,
      type: RenderNodeType.icon,
      props: {
        'name': props.name,
        'size': props.size,
        'color': _resolveColor(props.color),
      },
      children: [],
    );
  }

  double _resolveSpacing(SpacingValue value) {
    return switch (value) {
      SpacingFixed(:final value) => value,
      SpacingToken(:final token) => _tokens.resolveSpacing(token) ?? 0,
    };
  }

  String _resolveColor(ColorValue value) {
    return switch (value) {
      ColorHex(:final hex) => hex,
      ColorToken(:final token) => _tokens.resolveColor(token) ?? '#000000',
    };
  }

  EdgeInsets _resolveEdgeInsets(EdgeInsetsSpec spec) {
    return EdgeInsets.fromLTRB(
      _resolveSpacing(spec.left),
      _resolveSpacing(spec.top),
      _resolveSpacing(spec.right),
      _resolveSpacing(spec.bottom),
    );
  }

  Map<String, dynamic> _resolveSizeMode(SizeMode mode) {
    return switch (mode) {
      SizeModeHug() => {'mode': 'hug'},
      SizeModeFill() => {'mode': 'fill'},
      SizeModeFixed(:final value) => {'mode': 'fixed', 'value': value},
    };
  }

  Map<String, dynamic> _resolveTextStyle(TextStyleValue style) {
    return switch (style) {
      TextStyleToken(:final token) => {'token': token, ..._tokens.resolveTextStyle(token)?.toJson() ?? {}},
      TextStyleCustom() => {
        'fontSize': style.fontSize,
        'fontWeight': style.fontWeight,
        'color': _resolveColor(style.color),
        if (style.fontFamily != null) 'fontFamily': style.fontFamily,
        if (style.lineHeight != null) 'lineHeight': style.lineHeight,
        if (style.letterSpacing != null) 'letterSpacing': style.letterSpacing,
      },
    };
  }

  double _resolveRadius(RadiusValue radius) {
    return switch (radius) {
      RadiusAll(:final value) => value,
      RadiusToken(:final token) => _tokens.resolveRadius(token) ?? 0,
      RadiusOnly() => radius.topLeft,  // Simplified - full impl would return all corners
    };
  }
}
```

---

## Layer 3: Agent-Based Codegen

Code generation is handled by an **agent (LLM)** rather than a deterministic compiler. This produces higher-quality, more idiomatic Flutter code.

### Why Agent-Based?

| Deterministic Compiler | Agent-Based |
|------------------------|-------------|
| Predictable but mechanical | Contextually intelligent |
| Limited to known patterns | Can make creative decisions |
| Same input = same output | May vary (can be guided) |
| Fast | Slower (LLM round-trip) |
| Lower quality output | Higher quality output |

For codegen, **quality matters more than speed**. Users export code occasionally, not continuously.

### Agent Codegen Flow

```
User clicks "Export to Flutter"
        │
        ▼
Editor IR serialized to JSON
        │
        ▼
Agent receives IR + project context + theme tokens
        │
        ▼
Agent analyzes design:
  - Identifies component boundaries
  - Chooses widget patterns
  - Generates semantic names
  - Maps tokens to Theme.of(context)
        │
        ▼
Agent produces Flutter code files
        │
        ▼
Code written to user's project
```

### Agent Prompt Structure

```dart
/// Builds the prompt for code generation
class CodegenPromptBuilder {
  String buildPrompt({
    required EditorDocument document,
    required Frame frame,
    required Map<String, dynamic> themeTokens,
    required String projectName,
  }) {
    return '''
You are generating Flutter code from a visual design.

## Design Document (Editor IR)

```json
${jsonEncode(document.toJson())}
```

## Frame to Generate: ${frame.name}

## Project Theme Tokens

```json
${jsonEncode(themeTokens)}
```

## Instructions

Generate clean, idiomatic Flutter code for the "${frame.name}" screen.

### Requirements

1. **Widget Structure**
   - Create a StatelessWidget for the screen
   - Extract reusable parts into private widgets or separate public widgets
   - Use const constructors where possible

2. **Layout Mapping**
   - `autoLayout.direction: horizontal` → Row
   - `autoLayout.direction: vertical` → Column
   - `mainAlign` → MainAxisAlignment
   - `crossAlign` → CrossAxisAlignment
   - Use SizedBox for gaps (not Padding between children)

3. **Styling**
   - Map color tokens to Theme.of(context).colorScheme
   - Map text tokens to Theme.of(context).textTheme
   - Map spacing tokens to theme extension or constants
   - Use const Color() for any hardcoded colors

4. **Naming**
   - Use semantic names based on node.name
   - Follow Flutter naming conventions (PascalCase for classes, camelCase for variables)

5. **Code Quality**
   - Add brief comments for complex sections
   - Group related widgets logically
   - Keep build methods focused (<50 lines ideally)

### Output Format

Provide the generated code as a single Dart file with all necessary imports.
Begin with the main screen widget, followed by any extracted private widgets.
''';
  }
}
```

### CodegenAgent

```dart
/// Agent that generates Flutter code from designs
class CodegenAgent {
  final LLMClient _llm;
  final CodegenPromptBuilder _promptBuilder;

  CodegenAgent(this._llm) : _promptBuilder = CodegenPromptBuilder();

  /// Generate Flutter code for a frame
  Future<CodegenResult> generateCode({
    required EditorDocument document,
    required Frame frame,
    required Map<String, dynamic> themeTokens,
    required String projectName,
  }) async {
    final prompt = _promptBuilder.buildPrompt(
      document: document,
      frame: frame,
      themeTokens: themeTokens,
      projectName: projectName,
    );

    final response = await _llm.generate(prompt);

    return CodegenResult(
      frameName: frame.name,
      code: _extractCode(response),
      fileName: _generateFileName(frame.name),
    );
  }

  String _extractCode(String response) {
    // Extract code from markdown code blocks if present
    final codeBlockRegex = RegExp(r'```dart\n([\s\S]*?)\n```');
    final match = codeBlockRegex.firstMatch(response);
    return match?.group(1) ?? response;
  }

  String _generateFileName(String frameName) {
    // 'Dashboard Screen' → 'dashboard_screen.dart'
    return frameName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '') +
        '.dart';
  }
}

class CodegenResult {
  final String frameName;
  final String code;
  final String fileName;

  const CodegenResult({
    required this.frameName,
    required this.code,
    required this.fileName,
  });
}
```

### Example Generated Code

From a header design with logo, title, and avatar:

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              colors: colors,
              textTheme: textTheme,
            ),
            Expanded(
              child: _Content(colors: colors),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.colors,
    required this.textTheme,
  });

  final ColorScheme colors;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.sparkles,
            size: 24,
            color: colors.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Dashboard',
            style: textTheme.headlineSmall,
          ),
          const Spacer(),
          const CircleAvatar(
            radius: 16,
            backgroundImage: AssetImage('assets/avatar.png'),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Content goes here
        ],
      ),
    );
  }
}
```

---

## Patch Protocol

The patch protocol enables **instant updates** for both canvas editing and agent modifications.

### Patch Operations

Patch operations are **atomic** and **invertible** (for undo). Node creation and tree attachment are separate operations.

```dart
/// A patch operation on the document
sealed class PatchOp {
  const PatchOp();

  factory PatchOp.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}

/// Set a property by path
class SetProp extends PatchOp {
  final String id;
  final String path;  // JSON Pointer: '/layout/position/x', '/style/fill'
  final dynamic value;

  const SetProp({
    required this.id,
    required this.path,
    required this.value,
  });
}

/// Insert a node into the document's node map (does NOT attach to parent)
/// Use with AttachChild to add to tree structure
class InsertNode extends PatchOp {
  final Node node;

  const InsertNode(this.node);
}

/// Attach a node as a child of a parent (node must already exist in nodes map)
class AttachChild extends PatchOp {
  final String parentId;
  final String childId;
  final int index;  // -1 = append

  const AttachChild({
    required this.parentId,
    required this.childId,
    required this.index,
  });
}

/// Detach a node from its parent (does NOT remove from nodes map)
class DetachChild extends PatchOp {
  final String parentId;
  final String childId;

  const DetachChild({
    required this.parentId,
    required this.childId,
  });
}

/// Remove a node from the document's node map (should be detached first)
class DeleteNode extends PatchOp {
  final String id;

  const DeleteNode(this.id);
}

/// Move a node to a new parent (combines detach + attach)
class MoveNode extends PatchOp {
  final String id;
  final String newParentId;
  final int index;

  const MoveNode({
    required this.id,
    required this.newParentId,
    required this.index,
  });
}

/// Replace a node's data entirely (keeps same ID)
class ReplaceNode extends PatchOp {
  final String id;
  final Node node;

  const ReplaceNode({
    required this.id,
    required this.node,
  });
}

/// Update frame properties
class SetFrameProp extends PatchOp {
  final String frameId;
  final String path;
  final dynamic value;

  const SetFrameProp({
    required this.frameId,
    required this.path,
    required this.value,
  });
}

/// Insert a new frame
class InsertFrame extends PatchOp {
  final Frame frame;

  const InsertFrame(this.frame);
}

/// Remove a frame (nodes should be deleted separately if needed)
class RemoveFrame extends PatchOp {
  final String frameId;

  const RemoveFrame(this.frameId);
}
```

### Composite Operations

Common operations involve multiple patches. Use `applyPatches()` for atomicity:

```dart
/// Create a node and attach it to a parent
List<PatchOp> createAndAttach(Node node, String parentId, {int index = -1}) {
  return [
    InsertNode(node),
    AttachChild(parentId: parentId, childId: node.id, index: index),
  ];
}

/// Delete a node and all its descendants
List<PatchOp> deleteSubtree(String nodeId, EditorDocument doc) {
  final ops = <PatchOp>[];

  void collectDeletes(String id) {
    final node = doc.nodes[id];
    if (node == null) return;

    // Collect children first (depth-first)
    for (final childId in node.children) {
      collectDeletes(childId);
    }
    ops.add(DeleteNode(id));
  }

  // Detach from parent first
  final parentId = _findParent(nodeId, doc);
  if (parentId != null) {
    ops.add(DetachChild(parentId: parentId, childId: nodeId));
  }

  collectDeletes(nodeId);
  return ops;
}
```

### PatchApplier

```dart
/// Applies patches to documents immutably
class PatchApplier {
  /// Apply a single patch
  EditorDocument apply(EditorDocument doc, PatchOp op) {
    return switch (op) {
      SetProp(:final id, :final path, :final value) =>
        _applySetProp(doc, id, path, value),
      InsertNode(:final node) =>
        _applyInsertNode(doc, node),
      AttachChild(:final parentId, :final childId, :final index) =>
        _applyAttachChild(doc, parentId, childId, index),
      DetachChild(:final parentId, :final childId) =>
        _applyDetachChild(doc, parentId, childId),
      DeleteNode(:final id) =>
        _applyDeleteNode(doc, id),
      MoveNode(:final id, :final newParentId, :final index) =>
        _applyMoveNode(doc, id, newParentId, index),
      ReplaceNode(:final id, :final node) =>
        _applyReplaceNode(doc, id, node),
      SetFrameProp(:final frameId, :final path, :final value) =>
        _applySetFrameProp(doc, frameId, path, value),
      InsertFrame(:final frame) =>
        _applyInsertFrame(doc, frame),
      RemoveFrame(:final frameId) =>
        _applyRemoveFrame(doc, frameId),
    };
  }

  /// Apply multiple patches atomically
  EditorDocument applyAll(EditorDocument doc, List<PatchOp> ops) {
    var result = doc;
    for (final op in ops) {
      result = apply(result, op);
    }
    return result;
  }

  EditorDocument _applySetProp(EditorDocument doc, String id, String path, dynamic value) {
    final node = doc.nodes[id];
    if (node == null) throw StateError('Node not found: $id');

    final updatedNode = _setByPath(node, path, value);
    return doc.copyWith(nodes: {...doc.nodes, id: updatedNode});
  }

  EditorDocument _applyInsertNode(EditorDocument doc, Node node) {
    if (doc.nodes.containsKey(node.id)) {
      throw StateError('Node already exists: ${node.id}');
    }
    return doc.copyWith(nodes: {...doc.nodes, node.id: node});
  }

  EditorDocument _applyAttachChild(EditorDocument doc, String parentId, String childId, int index) {
    final parent = doc.nodes[parentId];
    if (parent == null) throw StateError('Parent not found: $parentId');
    if (!doc.nodes.containsKey(childId)) throw StateError('Child not found: $childId');

    final newChildren = List<String>.from(parent.children);
    if (index < 0 || index > newChildren.length) {
      newChildren.add(childId);
    } else {
      newChildren.insert(index, childId);
    }

    return doc.copyWith(nodes: {
      ...doc.nodes,
      parentId: parent.copyWith(children: newChildren),
    });
  }

  EditorDocument _applyDetachChild(EditorDocument doc, String parentId, String childId) {
    final parent = doc.nodes[parentId];
    if (parent == null) throw StateError('Parent not found: $parentId');

    final newChildren = parent.children.where((id) => id != childId).toList();
    return doc.copyWith(nodes: {
      ...doc.nodes,
      parentId: parent.copyWith(children: newChildren),
    });
  }

  EditorDocument _applyDeleteNode(EditorDocument doc, String id) {
    final newNodes = Map<String, Node>.from(doc.nodes)..remove(id);
    return doc.copyWith(nodes: newNodes);
  }

  EditorDocument _applyMoveNode(EditorDocument doc, String id, String newParentId, int index) {
    // Find current parent
    String? currentParentId;
    for (final entry in doc.nodes.entries) {
      if (entry.value.children.contains(id)) {
        currentParentId = entry.key;
        break;
      }
    }

    var result = doc;
    if (currentParentId != null) {
      result = _applyDetachChild(result, currentParentId, id);
    }
    result = _applyAttachChild(result, newParentId, id, index);
    return result;
  }

  EditorDocument _applyReplaceNode(EditorDocument doc, String id, Node node) {
    if (!doc.nodes.containsKey(id)) throw StateError('Node not found: $id');
    return doc.copyWith(nodes: {...doc.nodes, id: node});
  }

  EditorDocument _applySetFrameProp(EditorDocument doc, String frameId, String path, dynamic value) {
    final frame = doc.frames[frameId];
    if (frame == null) throw StateError('Frame not found: $frameId');

    final updatedFrame = _setFrameByPath(frame, path, value);
    return doc.copyWith(frames: {...doc.frames, frameId: updatedFrame});
  }

  EditorDocument _applyInsertFrame(EditorDocument doc, Frame frame) {
    return doc.copyWith(frames: {...doc.frames, frame.id: frame});
  }

  EditorDocument _applyRemoveFrame(EditorDocument doc, String frameId) {
    final newFrames = Map<String, Frame>.from(doc.frames)..remove(frameId);
    return doc.copyWith(frames: newFrames);
  }

  Node _setByPath(Node node, String path, dynamic value) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) throw ArgumentError('Empty path');
    return _setByPathRecursive(node, segments, 0, value);
  }

  Frame _setFrameByPath(Frame frame, String path, dynamic value) {
    // Handle common frame paths
    if (path == '/canvas/position' && value is Map) {
      return frame.copyWith(
        canvas: frame.canvas.copyWith(
          position: Offset((value['x'] as num).toDouble(), (value['y'] as num).toDouble()),
        ),
      );
    }
    if (path == '/canvas/size' && value is Map) {
      return frame.copyWith(
        canvas: frame.canvas.copyWith(
          size: Size((value['width'] as num).toDouble(), (value['height'] as num).toDouble()),
        ),
      );
    }
    // ... other paths
    throw ArgumentError('Unsupported frame path: $path');
  }

  // ... additional implementation methods
}
```

### SceneChangeSet

The SceneChangeSet separates **geometry changes** (position, size) from **compilation changes** (structure, style). This enables:

- Geometry-only changes (dragging) to skip expensive recompilation
- Quick bounds updates during drag without rebuilding widgets
- Proper invalidation when structural changes occur

```dart
/// Tracks what changed in the scene after patches are applied
class SceneChangeSet {
  /// Nodes that need widget recompilation (structure, style, props changed)
  final Set<String> compilationDirty;

  /// Nodes that need bounds recalculation (position, size changed)
  final Set<String> geometryDirty;

  /// Frames that need reindexing in spatial index
  final Set<String> frameDirty;

  const SceneChangeSet({
    this.compilationDirty = const {},
    this.geometryDirty = const {},
    this.frameDirty = const {},
  });

  bool get isEmpty =>
      compilationDirty.isEmpty &&
      geometryDirty.isEmpty &&
      frameDirty.isEmpty;

  SceneChangeSet merge(SceneChangeSet other) => SceneChangeSet(
    compilationDirty: {...compilationDirty, ...other.compilationDirty},
    geometryDirty: {...geometryDirty, ...other.geometryDirty},
    frameDirty: {...frameDirty, ...other.frameDirty},
  );

  /// Factory to create appropriate change set based on patch type
  /// NOTE: Requires document context to compute subtrees correctly
  static SceneChangeSet fromPatch(
    PatchOp op,
    Map<String, String> parentIndex,
    Map<String, Node> nodes,
  ) {
    return switch (op) {
      // Geometry-only changes (during drag)
      SetProp(:final id, :final path) when _isGeometryPath(path) =>
        SceneChangeSet(geometryDirty: {id}),

      // Frame position/size changes
      SetFrameProp(:final frameId, :final path) when _isGeometryPath(path) =>
        SceneChangeSet(frameDirty: {frameId}),

      // Structural/style changes need full recompile
      SetProp(:final id) =>
        SceneChangeSet(compilationDirty: _withAncestors(id, parentIndex)),

      // Node insertion: mark the new node dirty (not subtree - it's new)
      InsertNode(:final node) =>
        SceneChangeSet(compilationDirty: {node.id}),

      // Attaching to parent: parent and ancestors need recompile
      AttachChild(:final parentId, :final childId) =>
        SceneChangeSet(
          compilationDirty: {
            ..._withAncestors(parentId, parentIndex),
            ..._subtree(childId, nodes),  // Mark new subtree
          },
        ),

      // Detaching: parent needs recompile
      DetachChild(:final parentId) =>
        SceneChangeSet(
          compilationDirty: _withAncestors(parentId, parentIndex),
        ),

      // Deleting node: no compilation needed (already detached)
      DeleteNode() => const SceneChangeSet(),

      MoveNode(:final id, :final newParentId) =>
        SceneChangeSet(
          compilationDirty: {
            ..._withAncestors(parentIndex[id] ?? '', parentIndex),
            ..._withAncestors(newParentId, parentIndex),
            ..._subtree(id, nodes),
          },
        ),

      ReplaceNode(:final id) =>
        SceneChangeSet(compilationDirty: _withAncestors(id, parentIndex)),

      SetFrameProp(:final frameId) =>
        SceneChangeSet(frameDirty: {frameId}),

      InsertFrame(:final frame) =>
        SceneChangeSet(frameDirty: {frame.id}),

      RemoveFrame(:final frameId) =>
        SceneChangeSet(frameDirty: {frameId}),
    };
  }

  static bool _isGeometryPath(String path) {
    return path.startsWith('/layout/position') ||
           path.startsWith('/layout/size') ||
           path.startsWith('/canvas/position') ||
           path.startsWith('/canvas/size');
  }

  static Set<String> _withAncestors(String id, Map<String, String> parentIndex) {
    final result = <String>{id};
    var current = id;
    while (true) {
      final parent = parentIndex[current];
      if (parent == null) break;
      result.add(parent);
      current = parent;
    }
    return result;
  }

  static Set<String> _subtree(String id, Map<String, Node> nodes) {
    final result = <String>{id};
    final node = nodes[id];
    if (node != null) {
      for (final childId in node.children) {
        result.addAll(_subtree(childId, nodes));
      }
    }
    return result;
  }
}
```

### EditorDocumentStore

```dart
/// Manages document state with change tracking
class EditorDocumentStore extends ChangeNotifier {
  EditorDocument _document;
  final PatchApplier _applier = PatchApplier();
  SceneChangeSet _pendingChanges = const SceneChangeSet();
  final Map<String, String> _parentIndex = {};  // nodeId → parentId

  EditorDocumentStore(this._document) {
    _rebuildParentIndex();
  }

  EditorDocument get document => _document;
  SceneChangeSet get pendingChanges => _pendingChanges;

  /// Apply a patch and track changes
  void applyPatch(PatchOp op) {
    _document = _applier.apply(_document, op);
    _pendingChanges = _pendingChanges.merge(
      SceneChangeSet.fromPatch(op, _parentIndex),
    );
    _rebuildParentIndex();
    notifyListeners();
  }

  /// Apply multiple patches atomically
  void applyPatches(List<PatchOp> ops) {
    _document = _applier.applyAll(_document, ops);
    for (final op in ops) {
      _pendingChanges = _pendingChanges.merge(
        SceneChangeSet.fromPatch(op, _parentIndex),
      );
    }
    _rebuildParentIndex();
    notifyListeners();
  }

  /// Clear change tracking (call after processing changes)
  void clearChanges() {
    _pendingChanges = const SceneChangeSet();
  }

  /// Get parent of a node
  String? getParentId(String nodeId) => _parentIndex[nodeId];

  void _rebuildParentIndex() {
    _parentIndex.clear();
    for (final node in _document.nodes.values) {
      for (final childId in node.children) {
        _parentIndex[childId] = node.id;
      }
    }
  }
}
```

---

## Canvas Integration

Free Design **replaces** the existing browse/edit modes in the canvas module.

### DragTarget (Frame vs Node)

Selection and dragging can target either **frames** (top-level canvas objects) or **nodes** (elements within a frame's tree). These have different geometry semantics:

- **Frames**: Position is in canvas world coordinates (`canvas.position`)
- **Nodes**: Position is relative to parent container (`layout.position`)

```dart
/// A selectable/draggable target on the canvas
sealed class DragTarget {
  const DragTarget();
}

/// A frame on the canvas (top-level)
class FrameTarget extends DragTarget {
  final String frameId;
  const FrameTarget(this.frameId);

  @override
  bool operator ==(Object other) =>
      other is FrameTarget && other.frameId == frameId;

  @override
  int get hashCode => frameId.hashCode;
}

/// A node within a frame's tree
class NodeTarget extends DragTarget {
  final String frameId;      // Containing frame
  final String expandedId;   // ID in expanded scene (may include instance path)
  final String? patchTarget; // Document node ID for patches (null if inside instance)

  const NodeTarget({
    required this.frameId,
    required this.expandedId,
    this.patchTarget,
  });

  /// Whether this node can be directly patched (not inside an instance)
  bool get canPatch => patchTarget != null;

  @override
  bool operator ==(Object other) =>
      other is NodeTarget &&
      other.frameId == frameId &&
      other.expandedId == expandedId;

  @override
  int get hashCode => Object.hash(frameId, expandedId);
}
```

### DragSession (Ephemeral Drag State)

The DragSession pattern keeps drag state **ephemeral** and only commits patches on drop. This prevents:

- Flooding the undo stack with per-frame patches
- Unnecessary recompilation during drag
- Jittery rendering from rapid patch application

```dart
/// Ephemeral state for an active drag operation
class DragSession {
  final DragMode mode;
  final Set<DragTarget> targets;
  final Map<DragTarget, Offset> startPositions;
  final Map<DragTarget, Size> startSizes;
  final ResizeHandle? handle;  // For resize mode

  Offset accumulator = Offset.zero;
  List<SnapGuide> activeGuides = [];

  DragSession._({
    required this.mode,
    required this.targets,
    required this.startPositions,
    required this.startSizes,
    this.handle,
  });

  /// Start a move drag session
  factory DragSession.move({
    required Set<DragTarget> targets,
    required Map<DragTarget, Offset> positions,
  }) {
    return DragSession._(
      mode: DragMode.move,
      targets: targets,
      startPositions: Map.from(positions),
      startSizes: {},
    );
  }

  /// Start a resize drag session
  factory DragSession.resize({
    required Set<DragTarget> targets,
    required Map<DragTarget, Offset> positions,
    required Map<DragTarget, Size> sizes,
    required ResizeHandle handle,
  }) {
    return DragSession._(
      mode: DragMode.resize,
      targets: targets,
      startPositions: Map.from(positions),
      startSizes: Map.from(sizes),
      handle: handle,
    );
  }

  /// Calculate current bounds for a target (without committing)
  Rect? getCurrentBounds(DragTarget target) {
    final startPos = startPositions[target];
    final startSize = startSizes[target];

    if (startPos == null) return null;

    if (mode == DragMode.move) {
      final size = startSize ?? const Size(100, 100);
      return Rect.fromLTWH(
        startPos.dx + accumulator.dx,
        startPos.dy + accumulator.dy,
        size.width,
        size.height,
      );
    }

    if (mode == DragMode.resize && startSize != null && handle != null) {
      return _calculateResizedBounds(startPos, startSize, accumulator, handle!);
    }

    return null;
  }

  /// Generate patches to commit this drag
  List<PatchOp> generatePatches() {
    final patches = <PatchOp>[];

    for (final target in targets) {
      final bounds = getCurrentBounds(target);
      if (bounds == null) continue;

      switch (target) {
        case FrameTarget(:final frameId):
          // Frame position is in canvas world coordinates
          patches.add(SetFrameProp(
            frameId: frameId,
            path: '/canvas/position',
            value: {'x': bounds.left, 'y': bounds.top},
          ));
          if (mode == DragMode.resize) {
            patches.add(SetFrameProp(
              frameId: frameId,
              path: '/canvas/size',
              value: {'width': bounds.width, 'height': bounds.height},
            ));
          }

        case NodeTarget(:final patchTarget):
          // Node position is relative to parent
          if (patchTarget == null) continue;  // Can't patch inside instances

          // Update position mode to absolute with new coordinates
          patches.add(SetProp(
            id: patchTarget,
            path: '/layout/position',
            value: {'mode': 'absolute', 'x': bounds.left, 'y': bounds.top},
          ));
          if (mode == DragMode.resize) {
            patches.add(SetProp(
              id: patchTarget,
              path: '/layout/size/width',
              value: bounds.width,
            ));
            patches.add(SetProp(
              id: patchTarget,
              path: '/layout/size/height',
              value: bounds.height,
            ));
          }
      }
    }

    return patches;
  }

  Rect _calculateResizedBounds(
    Offset startPos,
    Size startSize,
    Offset delta,
    ResizeHandle handle,
  ) {
    var pos = startPos;
    var size = startSize;

    switch (handle) {
      case ResizeHandle.topLeft:
        pos = Offset(startPos.dx + delta.dx, startPos.dy + delta.dy);
        size = Size(startSize.width - delta.dx, startSize.height - delta.dy);
      case ResizeHandle.topCenter:
        pos = Offset(startPos.dx, startPos.dy + delta.dy);
        size = Size(startSize.width, startSize.height - delta.dy);
      case ResizeHandle.topRight:
        pos = Offset(startPos.dx, startPos.dy + delta.dy);
        size = Size(startSize.width + delta.dx, startSize.height - delta.dy);
      case ResizeHandle.middleLeft:
        pos = Offset(startPos.dx + delta.dx, startPos.dy);
        size = Size(startSize.width - delta.dx, startSize.height);
      case ResizeHandle.middleRight:
        size = Size(startSize.width + delta.dx, startSize.height);
      case ResizeHandle.bottomLeft:
        pos = Offset(startPos.dx + delta.dx, startPos.dy);
        size = Size(startSize.width - delta.dx, startSize.height + delta.dy);
      case ResizeHandle.bottomCenter:
        size = Size(startSize.width, startSize.height + delta.dy);
      case ResizeHandle.bottomRight:
        size = Size(startSize.width + delta.dx, startSize.height + delta.dy);
    }

    // Enforce minimum size
    const minSize = 50.0;
    if (size.width < minSize) {
      if (handle.isLeft) pos = Offset(startPos.dx + startSize.width - minSize, pos.dy);
      size = Size(minSize, size.height);
    }
    if (size.height < minSize) {
      if (handle.isTop) pos = Offset(pos.dx, startPos.dy + startSize.height - minSize);
      size = Size(size.width, minSize);
    }

    return Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
  }
}

enum DragMode { move, resize, marquee }

enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  middleLeft,
  middleRight,
  bottomLeft,
  bottomCenter,
  bottomRight;

  bool get isLeft => this == topLeft || this == middleLeft || this == bottomLeft;
  bool get isRight => this == topRight || this == middleRight || this == bottomRight;
  bool get isTop => this == topLeft || this == topCenter || this == topRight;
  bool get isBottom => this == bottomLeft || this == bottomCenter || this == bottomRight;
}
```

### FreeDesignState

The state class orchestrates document management, selection, and drag operations. It uses **distill_canvas utilities** (`SpatialIndex`, `SnapEngine`) for performance.

```dart
/// State for the free design canvas
///
/// Coordinates with InfiniteCanvas via callbacks - distill_canvas reports
/// gestures in world coordinates, we interpret their meaning.
class FreeDesignState extends ChangeNotifier {
  // Document
  final EditorDocumentStore _store;
  final RenderCompiler _compiler;
  final ExpandedSceneBuilder _expander;

  // Compiled render trees (per frame)
  final Map<String, RenderDocument> _renderCache = {};

  // Expanded scenes (per frame)
  final Map<String, ExpandedScene> _expandedScenes = {};

  // Spatial index for hit testing - uses distill_canvas QuadTree
  // NOTE: Import from 'package:distill_canvas/utilities.dart'
  final SpatialIndex<String> _frameSpatialIndex = QuadTree(
    const Rect.fromLTWH(-50000, -50000, 100000, 100000),
  );

  // Selection using DragTarget (can be frames or nodes)
  final Set<DragTarget> _selection = {};
  DragTarget? _hovered;

  // View-only state (not persisted)
  final Set<String> _expandedTreeNodes = {};  // Layer panel expand state

  // Active drag session (ephemeral)
  DragSession? _dragSession;

  // Smart guides - uses distill_canvas SnapEngine
  // NOTE: Import from 'package:distill_canvas/utilities.dart'
  final SnapEngine _snapEngine = const SnapEngine(
    threshold: 8.0,
    enableEdgeSnap: true,
    enableCenterSnap: true,
  );

  FreeDesignState({
    required EditorDocumentStore store,
    required TokenResolver tokens,
  })  : _store = store,
        _compiler = RenderCompiler(tokens),
        _expander = const ExpandedSceneBuilder() {
    _store.addListener(_onDocumentChanged);
    _rebuildSpatialIndex();
  }

  // Getters
  EditorDocument get document => _store.document;
  Set<DragTarget> get selection => Set.unmodifiable(_selection);
  DragTarget? get hovered => _hovered;
  bool get isDragging => _dragSession != null;
  DragSession? get dragSession => _dragSession;
  List<SnapGuide> get activeGuides => _dragSession?.activeGuides ?? [];

  /// Get selected frame IDs (filters to FrameTargets only)
  Set<String> get selectedFrameIds => _selection
      .whereType<FrameTarget>()
      .map((t) => t.frameId)
      .toSet();

  /// Get selected node targets (filters to NodeTargets only)
  Set<NodeTarget> get selectedNodes => _selection
      .whereType<NodeTarget>()
      .toSet();

  /// Get compiled render document for a frame (lazy, cached)
  RenderDocument getRenderDoc(String frameId) {
    var cached = _renderCache[frameId];
    if (cached == null) {
      final scene = getExpandedScene(frameId);
      cached = _compiler.compile(scene);
      _renderCache[frameId] = cached;
    }
    return cached;
  }

  /// Get expanded scene for a frame (lazy, cached)
  ExpandedScene getExpandedScene(String frameId) {
    var cached = _expandedScenes[frameId];
    if (cached == null) {
      cached = _expander.build(frameId, document);
      _expandedScenes[frameId] = cached;
    }
    return cached;
  }

  /// Invalidate caches for affected frames/nodes
  /// Called by _onDocumentChanged - single place for cache invalidation
  void _invalidateCaches(SceneChangeSet changes) {
    // Frame changes: rebuild spatial index
    if (changes.frameDirty.isNotEmpty) {
      _rebuildSpatialIndex();
      // Also invalidate render cache for affected frames
      for (final frameId in changes.frameDirty) {
        _expandedScenes.remove(frameId);
        _renderCache.remove(frameId);
      }
    }

    // Compilation changes: invalidate affected frames
    if (changes.compilationDirty.isNotEmpty) {
      // Find which frames contain the dirty nodes and invalidate those
      // For simplicity in v1, clear all caches (can optimize later)
      _expandedScenes.clear();
      _renderCache.clear();
    }
  }

  void _onDocumentChanged() {
    final changes = _store.pendingChanges;
    _invalidateCaches(changes);
    _store.clearChanges();
    notifyListeners();
  }

  void _rebuildSpatialIndex() {
    _frameSpatialIndex.clear();

    // Index frames
    for (final frame in document.frames.values) {
      final bounds = Rect.fromLTWH(
        frame.canvas.position.dx,
        frame.canvas.position.dy,
        frame.canvas.size.width,
        frame.canvas.size.height,
      );
      _frameSpatialIndex.insert(frame.id, bounds);
    }
  }

  // === Selection ===

  void select(DragTarget target, {bool addToSelection = false}) {
    if (!addToSelection) _selection.clear();
    _selection.add(target);
    notifyListeners();
  }

  void selectFrame(String frameId, {bool addToSelection = false}) {
    select(FrameTarget(frameId), addToSelection: addToSelection);
  }

  void selectNode({
    required String frameId,
    required String expandedId,
    String? patchTarget,
    bool addToSelection = false,
  }) {
    select(
      NodeTarget(
        frameId: frameId,
        expandedId: expandedId,
        patchTarget: patchTarget,
      ),
      addToSelection: addToSelection,
    );
  }

  void deselect(DragTarget target) {
    _selection.remove(target);
    notifyListeners();
  }

  void deselectAll() {
    _selection.clear();
    notifyListeners();
  }

  void selectFramesInRect(Rect worldRect) {
    _selection.clear();
    final candidates = _frameSpatialIndex.query(worldRect);
    for (final frameId in candidates) {
      final bounds = _getFrameBounds(frameId);
      if (bounds != null && worldRect.overlaps(bounds)) {
        _selection.add(FrameTarget(frameId));
      }
    }
    notifyListeners();
  }

  void setHovered(DragTarget? target) {
    if (_hovered != target) {
      _hovered = target;
      notifyListeners();
    }
  }

  // === Drag Operations (using DragSession) ===

  void startDrag() {
    final positions = <DragTarget, Offset>{};
    for (final target in _selection) {
      final pos = _getPosition(target);
      if (pos != null) positions[target] = pos;
    }

    _dragSession = DragSession.move(
      targets: Set.from(_selection),
      positions: positions,
    );
    notifyListeners();
  }

  void updateDrag(Offset worldDelta, {double? gridSize, bool useSmartGuides = true}) {
    final session = _dragSession;
    if (session == null || session.mode != DragMode.move) return;

    session.accumulator += worldDelta;

    // Calculate intended bounds for smart guides
    Rect? selectionBounds;
    for (final target in session.targets) {
      final bounds = session.getCurrentBounds(target);
      if (bounds != null) {
        selectionBounds = selectionBounds?.expandToInclude(bounds) ?? bounds;
      }
    }

    // Smart guides (frame-level only for now)
    session.activeGuides = [];

    if (useSmartGuides && selectionBounds != null) {
      final nearbyIds = _frameSpatialIndex.query(selectionBounds.inflate(50));

      // Filter out selected frames from snap candidates
      final selectedFrameIds = session.targets
          .whereType<FrameTarget>()
          .map((t) => t.frameId)
          .toSet();

      final otherBounds = nearbyIds
          .where((id) => !selectedFrameIds.contains(id))
          .map((id) => _getFrameBounds(id))
          .whereType<Rect>();

      final snapResult = _snapEngine.calculate(
        movingBounds: selectionBounds,
        otherBounds: otherBounds,
        zoom: 1.0,  // TODO: Get from controller
      );

      if (snapResult.didSnap) {
        // Adjust accumulator to snap position
        final snapDelta = snapResult.snappedBounds.topLeft - selectionBounds.topLeft;
        session.accumulator += snapDelta;
        session.activeGuides = snapResult.guides;
      }
    }

    // Grid snap (if no smart guide snap)
    if (session.activeGuides.isEmpty && gridSize != null && gridSize > 0) {
      session.accumulator = Offset(
        (session.accumulator.dx / gridSize).round() * gridSize,
        (session.accumulator.dy / gridSize).round() * gridSize,
      );
    }

    // NOTE: No patches emitted during drag - just update session state
    notifyListeners();
  }

  void endDrag() {
    final session = _dragSession;
    if (session == null) return;

    // Commit patches only on drop
    final patches = session.generatePatches();
    if (patches.isNotEmpty) {
      _store.applyPatches(patches);
    }

    _dragSession = null;
    notifyListeners();
  }

  void cancelDrag() {
    _dragSession = null;
    notifyListeners();
  }

  // === Resize Operations (using DragSession) ===

  void startResize(ResizeHandle handle) {
    final positions = <DragTarget, Offset>{};
    final sizes = <DragTarget, Size>{};

    for (final target in _selection) {
      final pos = _getPosition(target);
      final size = _getSize(target);
      if (pos != null && size != null) {
        positions[target] = pos;
        sizes[target] = size;
      }
    }

    _dragSession = DragSession.resize(
      targets: Set.from(_selection),
      positions: positions,
      sizes: sizes,
      handle: handle,
    );
    notifyListeners();
  }

  void updateResize(Offset worldDelta, {double? gridSize}) {
    final session = _dragSession;
    if (session == null || session.mode != DragMode.resize) return;

    session.accumulator += worldDelta;

    // Apply grid snap
    if (gridSize != null && gridSize > 0) {
      session.accumulator = Offset(
        (session.accumulator.dx / gridSize).round() * gridSize,
        (session.accumulator.dy / gridSize).round() * gridSize,
      );
    }

    // NOTE: No patches emitted during resize - just update session state
    notifyListeners();
  }

  /// Get current bounds during drag (reads from session, not document)
  Rect? getCurrentBounds(DragTarget target) {
    final session = _dragSession;
    if (session != null && session.targets.contains(target)) {
      return session.getCurrentBounds(target);
    }
    return _getBounds(target);
  }

  // === Hit Testing ===

  /// Hit test for frame selection (returns FrameTarget)
  FrameTarget? hitTestFrame(Offset worldPos) {
    final candidates = _frameSpatialIndex.hitTest(worldPos).toList();

    // Return topmost (frames are rendered in order, last = top)
    final frameOrder = document.frames.keys.toList();
    candidates.sort((a, b) {
      final aIndex = frameOrder.indexOf(a);
      final bIndex = frameOrder.indexOf(b);
      return bIndex.compareTo(aIndex);
    });

    for (final frameId in candidates) {
      final bounds = _getFrameBounds(frameId);
      if (bounds?.contains(worldPos) == true) {
        return FrameTarget(frameId);
      }
    }
    return null;
  }

  /// Hit test for node selection within a frame (returns NodeTarget)
  ///
  /// Uses flat iteration over RenderDocument nodes instead of tree recursion.
  /// Finds the smallest (deepest) node containing the point.
  NodeTarget? hitTestNode(Offset worldPos, String frameId) {
    final scene = getExpandedScene(frameId);
    final frameBounds = _getFrameBounds(frameId);
    if (frameBounds == null) return null;

    // Convert world pos to local frame coordinates
    final localPos = worldPos - frameBounds.topLeft;
    final renderDoc = getRenderDoc(frameId);

    // Find deepest hit by smallest area (flat iteration, no recursion)
    String? bestId;
    double bestArea = double.infinity;

    for (final node in renderDoc.nodes.values) {
      final bounds = node.computedBounds;
      if (bounds != null && bounds.contains(localPos)) {
        final area = bounds.width * bounds.height;
        if (area < bestArea) {
          bestArea = area;
          bestId = node.id;
        }
      }
    }

    if (bestId == null) return null;

    return NodeTarget(
      frameId: frameId,
      expandedId: bestId,
      patchTarget: scene.getPatchTarget(bestId),
    );
  }

  ResizeHandle? hitTestHandle(
    Offset viewPos,
    InfiniteCanvasController controller,
  ) {
    const handleSize = 8.0;
    const hitPadding = 4.0;
    final hitRadius = handleSize / 2 + hitPadding;

    for (final target in _selection) {
      final worldBounds = _getBounds(target);
      if (worldBounds == null) continue;

      final viewBounds = controller.worldToViewRect(worldBounds);
      final handles = _getHandlePositions(viewBounds);

      for (final entry in handles.entries) {
        if ((viewPos - entry.value).distance <= hitRadius) {
          return entry.key;
        }
      }
    }
    return null;
  }

  Map<ResizeHandle, Offset> _getHandlePositions(Rect bounds) {
    return {
      ResizeHandle.topLeft: bounds.topLeft,
      ResizeHandle.topCenter: Offset(bounds.center.dx, bounds.top),
      ResizeHandle.topRight: bounds.topRight,
      ResizeHandle.middleLeft: Offset(bounds.left, bounds.center.dy),
      ResizeHandle.middleRight: Offset(bounds.right, bounds.center.dy),
      ResizeHandle.bottomLeft: bounds.bottomLeft,
      ResizeHandle.bottomCenter: Offset(bounds.center.dx, bounds.bottom),
      ResizeHandle.bottomRight: bounds.bottomRight,
    };
  }

  // === Helpers ===

  Rect? _getBounds(DragTarget target) {
    return switch (target) {
      FrameTarget(:final frameId) => _getFrameBounds(frameId),
      NodeTarget(:final frameId, :final expandedId) =>
          _getNodeBounds(frameId, expandedId),
    };
  }

  Rect? _getFrameBounds(String frameId) {
    final frame = document.frames[frameId];
    if (frame == null) return null;
    return Rect.fromLTWH(
      frame.canvas.position.dx,
      frame.canvas.position.dy,
      frame.canvas.size.width,
      frame.canvas.size.height,
    );
  }

  Rect? _getNodeBounds(String frameId, String expandedId) {
    final frameBounds = _getFrameBounds(frameId);
    if (frameBounds == null) return null;

    final renderDoc = getRenderDoc(frameId);
    final node = renderDoc.nodes[expandedId];
    final localBounds = node?.computedBounds;
    if (localBounds == null) return null;

    // Convert local bounds to world coordinates
    return localBounds.shift(frameBounds.topLeft);
  }

  Offset? _getPosition(DragTarget target) {
    return switch (target) {
      FrameTarget(:final frameId) => document.frames[frameId]?.canvas.position,
      NodeTarget(:final frameId, :final expandedId) => () {
          final renderDoc = getRenderDoc(frameId);
          return renderDoc.nodes[expandedId]?.computedBounds?.topLeft;
        }(),
    };
  }

  Size? _getSize(DragTarget target) {
    return switch (target) {
      FrameTarget(:final frameId) => document.frames[frameId]?.canvas.size,
      NodeTarget(:final frameId, :final expandedId) => () {
          final renderDoc = getRenderDoc(frameId);
          return renderDoc.nodes[expandedId]?.computedBounds?.size;
        }(),
    };
  }

  @override
  void dispose() {
    _store.removeListener(_onDocumentChanged);
    super.dispose();
  }
}
```

### FreeDesignCanvas Widget

Wires `FreeDesignState` to distill_canvas. distill_canvas reports gestures in world coordinates; we interpret their meaning.

```dart
/// Free Design canvas widget
class FreeDesignCanvas extends StatelessWidget {
  final FreeDesignState state;
  final InfiniteCanvasController controller;

  const FreeDesignCanvas({
    super.key,
    required this.state,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return InfiniteCanvas(
      controller: controller,
      // Configure gesture handling
      gestureConfig: CanvasGestureConfig.all,
      physicsConfig: const CanvasPhysicsConfig(
        minZoom: 0.1,
        maxZoom: 10.0,
      ),
      // Rendering layers
      layers: CanvasLayers(
        background: (context, ctrl) => const GridBackground(),
        content: (context, ctrl) => _ContentLayer(state: state, controller: ctrl),
        overlay: (context, ctrl) => _SelectionOverlay(state: state, controller: ctrl),
      ),
      // Gesture callbacks - distill_canvas reports in world coordinates
      onTapWorld: (worldPos) => _handleTap(worldPos),
      onDragStartWorld: (details) => _handleDragStart(details),
      onDragUpdateWorld: (details) => _handleDragUpdate(details),
      onDragEndWorld: (details) => _handleDragEnd(details),
      onHoverWorld: (worldPos) => _handleHover(worldPos),
    );
  }

  void _handleTap(Offset worldPos) {
    final hit = state.hitTestFrame(worldPos);
    if (hit != null) {
      state.selectFrame(hit.frameId);
    } else {
      state.deselectAll();
    }
  }

  void _handleDragStart(CanvasDragStartDetails details) {
    final hit = state.hitTestFrame(details.worldPosition);
    if (hit != null && state.selection.contains(hit)) {
      // Drag selected items
      state.startDrag();
    } else if (hit != null) {
      // Select and drag
      state.selectFrame(hit.frameId);
      state.startDrag();
    }
    // If no hit, could start marquee selection (v2)
  }

  void _handleDragUpdate(CanvasDragUpdateDetails details) {
    // Use worldDelta for moving objects
    state.updateDrag(
      details.worldDelta,
      gridSize: 10.0,
      useSmartGuides: true,
    );
  }

  void _handleDragEnd(CanvasDragEndDetails details) {
    state.endDrag();
  }

  void _handleHover(Offset worldPos) {
    final hit = state.hitTestFrame(worldPos);
    state.setHovered(hit);
  }
}

/// Content layer renders frames in world coordinates
class _ContentLayer extends StatelessWidget {
  final FreeDesignState state;
  final InfiniteCanvasController controller;

  const _ContentLayer({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        // Cull to visible frames for performance
        final visibleBounds = controller.getVisibleWorldBounds(
          MediaQuery.sizeOf(context),
        );
        final visibleFrameIds = state.document.frames.values
            .where((f) => visibleBounds.overlaps(_frameBounds(f)))
            .map((f) => f.id);

        return Stack(
          children: [
            for (final frameId in visibleFrameIds)
              _FrameWidget(
                key: ValueKey(frameId),
                state: state,
                frameId: frameId,
              ),
          ],
        );
      },
    );
  }

  Rect _frameBounds(Frame f) => Rect.fromLTWH(
    f.canvas.position.dx,
    f.canvas.position.dy,
    f.canvas.size.width,
    f.canvas.size.height,
  );
}

/// Overlay layer renders selection UI in screen coordinates
class _SelectionOverlay extends StatelessWidget {
  final FreeDesignState state;
  final InfiniteCanvasController controller;

  const _SelectionOverlay({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return CustomPaint(
          painter: _SelectionPainter(
            selection: state.selection,
            getBounds: (target) => state.getCurrentBounds(target),
            guides: state.activeGuides,
            controller: controller,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Paints selection rectangles and resize handles
class _SelectionPainter extends CustomPainter {
  final Set<DragTarget> selection;
  final Rect? Function(DragTarget) getBounds;
  final List<SnapGuide> guides;
  final InfiniteCanvasController controller;

  _SelectionPainter({
    required this.selection,
    required this.getBounds,
    required this.guides,
    required this.controller,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selectionPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw selection rectangles (convert world → view)
    for (final target in selection) {
      final worldBounds = getBounds(target);
      if (worldBounds == null) continue;

      // Convert world bounds to screen coordinates
      final viewBounds = controller.worldToViewRect(worldBounds);
      canvas.drawRect(viewBounds, selectionPaint);

      // Draw resize handles
      _drawHandles(canvas, viewBounds, handlePaint);
    }

    // Draw smart guides
    for (final guide in guides) {
      _drawGuide(canvas, guide);
    }
  }

  void _drawHandles(Canvas canvas, Rect bounds, Paint paint) {
    const handleSize = 8.0;
    final positions = [
      bounds.topLeft,
      Offset(bounds.center.dx, bounds.top),
      bounds.topRight,
      Offset(bounds.left, bounds.center.dy),
      Offset(bounds.right, bounds.center.dy),
      bounds.bottomLeft,
      Offset(bounds.center.dx, bounds.bottom),
      bounds.bottomRight,
    ];

    for (final pos in positions) {
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: handleSize, height: handleSize),
        paint,
      );
    }
  }

  void _drawGuide(Canvas canvas, SnapGuide guide) {
    final guidePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1;

    // Convert guide positions to view coordinates
    final viewStart = controller.worldToView(guide.start);
    final viewEnd = controller.worldToView(guide.end);
    canvas.drawLine(viewStart, viewEnd, guidePaint);
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => true;
}
```

---

## Agent Integration

Agents interact with the DSL through a **structured tool interface**.

### DesignAgentTools

```dart
/// Tools exposed to agents for design manipulation
class DesignAgentTools {
  final EditorDocumentStore _store;
  final IdGenerator _idGen = IdGenerator();

  DesignAgentTools(this._store);

  /// Read the current design as JSON
  Map<String, dynamic> readDesign() {
    return _store.document.toJson();
  }

  /// Read a specific frame
  Map<String, dynamic>? readFrame(String frameId) {
    return _store.document.frames[frameId]?.toJson();
  }

  /// Read a specific node
  Map<String, dynamic>? readNode(String nodeId) {
    return _store.document.nodes[nodeId]?.toJson();
  }

  /// Get a semantic summary of the design
  String summarizeDesign() {
    final doc = _store.document;
    final buffer = StringBuffer();

    for (final frame in doc.frames.values) {
      buffer.writeln('Frame: ${frame.name} (${frame.canvas.size.width}x${frame.canvas.size.height})');
      final rootNode = doc.nodes[frame.rootNodeId];
      if (rootNode != null) {
        _summarizeNode(rootNode, doc, buffer, indent: 1);
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  void _summarizeNode(
    Node node,
    EditorDocument doc,
    StringBuffer buffer, {
    required int indent,
  }) {
    final prefix = '  ' * indent;
    final typeLabel = node.type.name;
    final layoutLabel = _layoutLabel(node.layout);

    buffer.writeln('$prefix- ${node.name} ($typeLabel$layoutLabel)');

    for (final childId in node.children) {
      final child = doc.nodes[childId];
      if (child != null) {
        _summarizeNode(child, doc, buffer, indent: indent + 1);
      }
    }
  }

  String _layoutLabel(NodeLayout layout) {
    if (layout.autoLayout != null) {
      final dir = layout.autoLayout!.direction == AxisDirection.horizontal ? 'row' : 'column';
      return ', $dir';
    }
    return '';
  }

  /// Create a new frame
  String createFrame({
    required String name,
    required double x,
    required double y,
    required double width,
    required double height,
    String? devicePreset,
  }) {
    final frameId = _idGen.frame();
    final rootId = _idGen.node();

    // Create root node
    final rootNode = Node(
      id: rootId,
      type: NodeType.container,
      name: 'Root',
      children: [],
      layout: NodeLayout(
        size: SizeSpec.fill(),
        autoLayout: AutoLayout.column(),
      ),
      style: const NodeStyle(),
      props: const ContainerProps(),
    );

    // Create frame
    final frame = Frame(
      id: frameId,
      name: name,
      rootNodeId: rootId,
      canvas: CanvasPlacement(
        position: Offset(x, y),
        size: Size(width, height),
      ),
      devicePreset: devicePreset,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Apply as patches
    _store.applyPatches([
      InsertChild(parentId: '', index: -1, node: rootNode),  // Special: add to nodes
      // TODO: Add frame insertion patch
    ]);

    return frameId;
  }

  /// Create a new node
  String createNode({
    required String parentId,
    required String type,
    required String name,
    int? index,
    Map<String, dynamic>? layout,
    Map<String, dynamic>? style,
    Map<String, dynamic>? props,
  }) {
    final nodeId = _idGen.node();

    final node = Node(
      id: nodeId,
      type: NodeType.values.byName(type),
      name: name,
      children: [],
      layout: layout != null
          ? NodeLayout.fromJson(layout)
          : NodeLayout.defaults(),
      style: style != null
          ? NodeStyle.fromJson(style)
          : const NodeStyle(),
      props: props != null
          ? NodeProps.fromJson(NodeType.values.byName(type), props)
          : const ContainerProps(),
    );

    _store.applyPatch(InsertChild(
      parentId: parentId,
      index: index ?? -1,
      node: node,
    ));

    return nodeId;
  }

  /// Update a node property
  void updateNode(String nodeId, String path, dynamic value) {
    _store.applyPatch(SetProp(id: nodeId, path: path, value: value));
  }

  /// Delete a node
  void deleteNode(String nodeId) {
    _store.applyPatch(RemoveNode(nodeId));
  }

  /// Move a node to a new parent
  void moveNode(String nodeId, String newParentId, {int? index}) {
    _store.applyPatch(MoveNode(
      id: nodeId,
      newParentId: newParentId,
      index: index ?? -1,
    ));
  }

  /// Apply multiple patches atomically
  void applyPatches(List<Map<String, dynamic>> patches) {
    final ops = patches.map((p) => PatchOp.fromJson(p)).toList();
    _store.applyPatches(ops);
  }
}

/// Generates unique IDs for design elements
class IdGenerator {
  int _counter = 0;

  String frame() => 'frame_${_shortId()}';
  String node() => 'n_${_shortId()}';
  String component() => 'comp_${_shortId()}';

  String _shortId() {
    _counter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final count = _counter.toRadixString(36).padLeft(4, '0');
    return '$timestamp$count'.substring(0, 8);
  }
}
```

### Agent Guidelines

```markdown
## Design DSL Guidelines for Agents

### Understanding the Structure

- **Document** contains frames, nodes, and components
- **Frames** are screens/pages on the canvas
- **Nodes** are visual elements in a tree structure
- **Components** are reusable node templates (global library)

### Creating UI

1. **Always use tokens for styling**
   ```json
   { "fill": { "token": "color.primary" } }
   ```
   Not: `{ "fill": { "hex": "#8B5CF6" } }`

2. **Use auto-layout for containers**
   ```json
   {
     "autoLayout": {
       "direction": "vertical",
       "gap": { "token": "spacing.md" },
       "crossAlign": "stretch"
     }
   }
   ```

3. **Name nodes semantically**
   - Good: "Header", "ProfileCard", "SubmitButton"
   - Bad: "Container1", "Row2", "Box"

### Editing UI

1. **Use small patches**
   - Change text: `setProp` on `/props/text`
   - Don't replace entire nodes

2. **Read before modifying**
   - Use `summarizeDesign()` to understand structure
   - Use `readNode()` for specific details

### Node Types

| Type | Use For |
|------|---------|
| `container` | Cards, sections, wrappers |
| `text` | Text content |
| `icon` | Icons (lucide:name format) |
| `image` | Images and illustrations |
| `instance` | Component instances |

### Layout Sizing

| Mode | Behavior |
|------|----------|
| `hug` | Shrink to fit content |
| `fill` | Expand to fill available space |
| `{ fixed: 200 }` | Exact pixel size |
```

---

## Design Token System

Tokens come from the **user's project theme** and provide a safe vocabulary for styling.

> **V1 Implementation**: Currently supports `colors`, `spacing`, and `radius` tokens only. Typography (`text`) and shadow tokens are planned for v2.

### Token Categories

```dart
/// Project theme tokens (loaded from user's project)
class ProjectTheme {
  // V1: Implemented
  final Map<String, String> colors;      // 'color.primary' → '#8B5CF6'
  final Map<String, double> spacing;     // 'spacing.md' → 16.0
  final Map<String, double> radius;      // 'radius.lg' → 12.0

  // V2: Not yet implemented
  // final Map<String, TextStyleDef> text;  // 'text.h2' → TextStyleDef
  // final Map<String, ShadowDef> shadows;  // 'shadow.md' → ShadowDef

  const ProjectTheme({
    required this.colors,
    required this.spacing,
    required this.radius,
  });

  factory ProjectTheme.fromJson(Map<String, dynamic> json);
}

class TextStyleDef {
  final double fontSize;
  final int fontWeight;
  final String? fontFamily;
  final double? lineHeight;
  final String colorToken;

  const TextStyleDef({
    required this.fontSize,
    required this.fontWeight,
    this.fontFamily,
    this.lineHeight,
    required this.colorToken,
  });
}

class ShadowDef {
  final String colorToken;
  final double offsetX;
  final double offsetY;
  final double blur;
  final double spread;

  const ShadowDef({
    required this.colorToken,
    required this.offsetX,
    required this.offsetY,
    required this.blur,
    this.spread = 0,
  });
}
```

### TokenResolver

```dart
/// Resolves token references to concrete values
class TokenResolver {
  // V1: Simple map-based resolution
  final Map<String, Color> colors;
  final Map<String, double> spacing;
  final Map<String, double> radius;

  const TokenResolver({
    this.colors = const {},
    this.spacing = const {},
    this.radius = const {},
  });

  /// Resolve color token (strips 'colors.' prefix)
  Color? resolveColor(String token);

  /// Resolve spacing token (strips 'spacing.' prefix)
  double? resolveSpacing(String token);

  /// Resolve radius token (strips 'radius.' prefix)
  double? resolveRadius(String token);

  /// Check if a string is a token reference
  static bool isTokenRef(String value) {
    return value.startsWith('colors.') ||
           value.startsWith('spacing.') ||
           value.startsWith('radius.');
  }

  // V2: Add when typography/shadow tokens are implemented
  // TextStyleDef? resolveTextStyle(String token);
  // ShadowDef? resolveShadow(String token);
}
```

---

## Component Library

Components are stored **globally** in the document, enabling a reusable component library.

### ComponentDef

> **V1 Note**: The current implementation uses `rootNodeId` referencing the global `document.nodes` map instead of an isolated `nodes` map. This works because:
> 1. Component creation copies nodes with new IDs
> 2. Instance expansion namespaces IDs via `::` (e.g., `inst1::btn`)
> 3. All queries can use the global map without ambiguity
>
> V2 may add isolated `Map<String, Node> nodes` for better component portability.

```dart
/// A reusable component definition
class ComponentDef {
  final String id;
  final String name;
  final String? description;
  final String? category;  // For organization: 'Buttons', 'Cards', etc.

  // V1: References nodes in global document.nodes
  final String rootNodeId;

  // V2: Isolated node tree (not yet implemented)
  // final Map<String, Node> nodes;

  // Exposed properties that can be overridden on instances
  final Map<String, dynamic> exposedProps;

  // Component parameters (v2)
  // final List<ComponentParameter> parameters;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ComponentDef({
    required this.id,
    required this.name,
    this.description,
    this.category,
    required this.rootNodeId,
    this.exposedProps = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory ComponentDef.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
}
```

### Creating Components

```dart
/// Extract a node subtree into a component
ComponentDef createComponentFromNode(
  String nodeId,
  EditorDocument doc, {
  required String name,
  String? category,
}) {
  final componentId = IdGenerator().component();
  final nodesToCopy = <String, Node>{};

  // Collect node and all descendants
  void collectNodes(String id) {
    final node = doc.nodes[id];
    if (node == null) return;
    nodesToCopy[id] = node;
    for (final childId in node.children) {
      collectNodes(childId);
    }
  }
  collectNodes(nodeId);

  return ComponentDef(
    id: componentId,
    name: name,
    category: category,
    rootNodeId: nodeId,
    nodes: nodesToCopy,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
```

### Instance Expansion (in RenderCompiler)

```dart
RenderNode _compileInstance(Node node, EditorDocument doc) {
  final props = node.props as InstanceProps;
  final component = doc.components[props.componentId];

  if (component == null) {
    // Fallback for missing component
    return RenderNode(
      id: node.id,
      type: RenderNodeType.box,
      props: {'backgroundColor': '#FF0000'},  // Error indicator
      children: [],
    );
  }

  // Clone component nodes
  final clonedNodes = <String, Node>{};
  for (final entry in component.nodes.entries) {
    clonedNodes[entry.key] = entry.value;
  }

  // Apply overrides
  for (final override in props.overrides) {
    final targetNode = clonedNodes[override.targetId];
    if (targetNode != null) {
      clonedNodes[override.targetId] = _setByPath(
        targetNode,
        override.path,
        override.value,
      );
    }
  }

  // Compile the cloned root
  final rootNode = clonedNodes[component.rootNodeId]!;
  return _compileNodeWithNodes(rootNode, clonedNodes);
}
```

---

## Implementation Roadmap

The roadmap follows a **pure bottom-up** approach: build and validate each layer before the next depends on it. No phase starts until its dependencies are complete and tested.

### Phase 1: Core Models & Patch Protocol ✅ COMPLETE

**Goal**: Foundation layer - models, serialization, and immutable updates

**Tasks**:
- [x] Define all model classes (Node, Frame, Layout, Style, Props, PositionMode)
- [x] Implement `fromJson` / `toJson` for all models
- [x] Add `copyWith` methods for immutable updates
- [x] Define `PatchOp` sealed classes (including InsertFrame/RemoveFrame)
- [x] Implement `PatchApplier`
- [x] Create `EditorDocumentStore` with SceneChangeSet tracking
- [x] Write unit tests for serialization round-trips
- [x] Write unit tests for patch application

**Validation**: All 86 tests pass. Can create, serialize, patch, and deserialize documents.

### Phase 2: Expanded Scene & Render Compiler ✅ COMPLETE

**Goal**: Scene expansion and rendering pipeline

**Depends on**: Phase 1

**Tasks**:
- [x] Implement `ExpandedSceneBuilder` with ID namespacing
- [x] Implement `TokenResolver` for project theme
- [x] Implement `RenderCompiler` with token resolution
- [x] Add incremental compilation using SceneChangeSet
- [x] Build `RenderEngine` (Render DSL → Flutter widgets)
- [x] Write unit tests for instance expansion
- [x] Write unit tests for render compilation

**Validation**: All 150 tests pass. Can expand instances, resolve tokens, and produce widget trees.

### Phase 3: Canvas State & Hit Testing ✅ COMPLETE

**Goal**: Selection, drag session, and spatial queries

**Depends on**: Phase 2

**Tasks**:
- [x] Implement `DragSession` pattern
- [x] Implement `FreeDesignState` with selection management
- [x] Integrate `QuadTree` for spatial indexing
- [x] Add frame-level hit testing
- [x] Implement `getCurrentBounds()` for drag preview
- [x] Write unit tests for hit testing
- [x] Write unit tests for drag session lifecycle

**Validation**: All 227 tests pass. Can select items, start/update/commit drags, hit test correctly.

### Phase 4: Canvas UI ✅ COMPLETE

**Goal**: Visual canvas layer with interaction handling

**Depends on**: Phase 3

**Tasks**:
- [x] Build `FreeDesignCanvas` widget
- [x] Implement frame renderer widget
- [x] Add 8-point resize handles
- [x] Add selection overlays and hover states
- [x] Integrate `SnapEngine` for smart guides
- [x] Add marquee selection
- [x] Add snap guide overlay

**Validation**: All tests pass. Interactive canvas with drag, resize, selection, snapping.

### Phase 5: Component System

**Goal**: Reusable components with instances and overrides

**Depends on**: Phase 4

**Tasks**:
- [ ] Implement `ComponentDef` model
- [ ] Add component creation from selection
- [ ] Implement override application in ExpandedSceneBuilder
- [ ] Build component library UI panel
- [ ] Add component instantiation UI

**Validation**: Can create components, instantiate, apply overrides.

### Phase 6: Agent Integration

**Goal**: Agents can read and modify designs

**Depends on**: Phase 5

**Tasks**:
- [ ] Implement `DesignAgentTools`
- [ ] Add `summarizeDesign()` for agent comprehension
- [ ] Create tool definitions for agent framework
- [ ] Test with sample agent interactions

**Validation**: Agent can understand design structure and emit valid patches.

### Phase 7: Agent Codegen

**Goal**: Agent generates Flutter code from designs

**Depends on**: Phase 6

**Tasks**:
- [ ] Build `CodegenPromptBuilder`
- [ ] Implement `CodegenAgent` with LLM integration
- [ ] Add export UI flow
- [ ] Test and refine prompts for code quality

**Validation**: "Export to Flutter" produces clean, compilable code.

---

## Test Suite

A comprehensive test suite validates each layer before building on top of it. Tests are organized by phase and run in CI.

### Core Model Tests

```dart
// test/free_design/models/node_test.dart

void main() {
  group('Node serialization', () {
    test('round-trip container node', () {
      final node = Node(
        id: 'n1',
        type: NodeType.container,
        name: 'Card',
        children: ['n2', 'n3'],
        layout: NodeLayout(
          position: const PositionMode.auto(),
          size: SizeSpec.fill(),
          autoLayout: AutoLayout.column(gap: 16),
        ),
        style: const NodeStyle(
          fill: ColorToken('color.surface'),
          radius: RadiusAll(12),
        ),
        props: const ContainerProps(),
      );

      final json = node.toJson();
      final restored = Node.fromJson(json);

      expect(restored.id, node.id);
      expect(restored.type, node.type);
      expect(restored.children, node.children);
      expect(restored.layout.autoLayout?.direction, AxisDirection.vertical);
    });

    test('round-trip text node with custom style', () {
      final node = Node(
        id: 'txt1',
        type: NodeType.text,
        name: 'Heading',
        children: [],
        layout: NodeLayout.defaults(),
        style: const NodeStyle(),
        props: TextProps(
          text: 'Hello World',
          textStyle: TextStyleCustom(
            fontSize: 24,
            fontWeight: 700,
            color: ColorToken('color.onSurface'),
          ),
        ),
      );

      final json = node.toJson();
      final restored = Node.fromJson(json);

      expect(restored.props, isA<TextProps>());
      expect((restored.props as TextProps).text, 'Hello World');
    });

    test('absolute positioning serialization', () {
      final layout = NodeLayout(
        position: const PositionMode.absolute(x: 100, y: 200),
        size: const SizeSpec(
          width: SizeMode.fixed(150),
          height: SizeMode.fixed(50),
        ),
      );

      final json = layout.toJson();
      final restored = NodeLayout.fromJson(json);

      expect(restored.position, isA<PositionModeAbsolute>());
      final pos = restored.position as PositionModeAbsolute;
      expect(pos.x, 100);
      expect(pos.y, 200);
    });
  });
}
```

### Patch Protocol Tests

```dart
// test/free_design/patch/patch_applier_test.dart

void main() {
  group('PatchApplier', () {
    late EditorDocument doc;
    late PatchApplier applier;

    setUp(() {
      doc = _createTestDocument();
      applier = PatchApplier();
    });

    test('SetProp updates nested path', () {
      final result = applier.apply(
        doc,
        SetProp(
          id: 'n_header',
          path: '/style/fill',
          value: {'hex': '#FF0000'},
        ),
      );

      final node = result.nodes['n_header']!;
      expect(node.style.fill, isA<ColorHex>());
      expect((node.style.fill as ColorHex).hex, '#FF0000');
    });

    test('InsertChild adds node at index', () {
      final newNode = Node(
        id: 'n_new',
        type: NodeType.text,
        name: 'New Text',
        children: [],
        layout: NodeLayout.defaults(),
        style: const NodeStyle(),
        props: const TextProps(
          text: 'Hello',
          textStyle: TextStyleToken('text.body'),
        ),
      );

      final result = applier.apply(
        doc,
        InsertChild(parentId: 'n_root', index: 1, node: newNode),
      );

      expect(result.nodes['n_root']!.children, contains('n_new'));
      expect(result.nodes['n_new'], isNotNull);
    });

    test('RemoveNode removes node and updates parent', () {
      final result = applier.apply(doc, RemoveNode('n_header'));

      expect(result.nodes.containsKey('n_header'), isFalse);
      expect(result.nodes['n_root']!.children, isNot(contains('n_header')));
    });

    test('InsertFrame adds frame', () {
      final frame = Frame(
        id: 'frame_new',
        name: 'New Screen',
        rootNodeId: 'n_new_root',
        canvas: CanvasPlacement(
          position: const Offset(500, 0),
          size: const Size(375, 812),
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = applier.apply(doc, InsertFrame(frame));

      expect(result.frames.containsKey('frame_new'), isTrue);
    });
  });
}
```

### SceneChangeSet Tests

```dart
// test/free_design/patch/scene_change_set_test.dart

void main() {
  group('SceneChangeSet', () {
    test('geometry path triggers geometryDirty', () {
      final changes = SceneChangeSet.fromPatch(
        SetProp(
          id: 'n1',
          path: '/layout/position/x',
          value: 100,
        ),
        {},  // parentIndex
        {},  // nodes
      );

      expect(changes.geometryDirty, contains('n1'));
      expect(changes.compilationDirty, isEmpty);
    });

    test('style path triggers compilationDirty with ancestors', () {
      // Build a simple tree: n_root -> n1
      final nodes = <String, Node>{
        'n_root': Node(
          id: 'n_root',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: ['n1'],
          layout: NodeLayout(),
        ),
        'n1': Node(
          id: 'n1',
          type: NodeType.container,
          props: ContainerProps(),
          childIds: [],
          layout: NodeLayout(),
        ),
      };

      final changes = SceneChangeSet.fromPatch(
        SetProp(
          id: 'n1',
          path: '/style/fill',
          value: {'hex': '#FF0000'},
        ),
        {'n1': 'n_root'},  // parentIndex
        nodes,             // nodes (for _subtree)
      );

      expect(changes.compilationDirty, contains('n1'));
      expect(changes.compilationDirty, contains('n_root')); // ancestor
      expect(changes.geometryDirty, isEmpty);
    });

    test('frame position triggers frameDirty', () {
      final changes = SceneChangeSet.fromPatch(
        SetFrameProp(
          frameId: 'frame1',
          path: '/canvas/position',
          value: {'x': 100, 'y': 200},
        ),
        {},  // parentIndex
        {},  // nodes
      );

      expect(changes.frameDirty, contains('frame1'));
      expect(changes.compilationDirty, isEmpty);
    });

    test('InsertNode triggers compilationDirty for subtree', () {
      final newNode = Node(
        id: 'n_new',
        type: NodeType.container,
        props: ContainerProps(),
        childIds: ['n_child'],
        layout: NodeLayout(),
      );

      final nodes = <String, Node>{
        'n_child': Node(
          id: 'n_child',
          type: NodeType.text,
          props: TextProps(text: 'Hello'),
          childIds: [],
          layout: NodeLayout(),
        ),
      };

      final changes = SceneChangeSet.fromPatch(
        InsertNode(newNode),
        {},    // parentIndex
        nodes, // nodes
      );

      expect(changes.compilationDirty, contains('n_new'));
      expect(changes.compilationDirty, contains('n_child'));
    });
  });
}
```

### Expanded Scene Tests

```dart
// test/free_design/scene/expanded_scene_test.dart

void main() {
  group('ExpandedSceneBuilder', () {
    test('expands instance with namespaced IDs', () {
      final doc = _createDocWithComponent();
      const builder = ExpandedSceneBuilder();

      final scene = builder.build('frame_main', doc);

      // Instance node should be expanded
      expect(scene.nodes.containsKey('n_card1::btn_submit'), isTrue);
      expect(scene.nodes.containsKey('n_card1::txt_label'), isTrue);

      // Patch target should point to the instance node
      expect(scene.getPatchTarget('n_card1::btn_submit'), 'n_card1');
    });

    test('applies overrides to expanded nodes', () {
      final doc = _createDocWithComponentAndOverride();
      const builder = ExpandedSceneBuilder();

      final scene = builder.build('frame_main', doc);

      final expandedBtn = scene.nodes['n_card1::btn_submit']!;
      // Override should be applied
      expect(
        (expandedBtn.props as TextProps).text,
        'Custom Label', // overridden from 'Submit'
      );
    });

    test('isInsideInstance returns true for namespaced IDs', () {
      final doc = _createDocWithComponent();
      const builder = ExpandedSceneBuilder();

      final scene = builder.build('frame_main', doc);

      expect(scene.isInsideInstance('n_card1::btn_submit'), isTrue);
      expect(scene.isInsideInstance('n_root'), isFalse);
    });

    test('patchTarget is null for nodes deep inside instance', () {
      final doc = _createDocWithComponent();
      const builder = ExpandedSceneBuilder();

      final scene = builder.build('frame_main', doc);

      // Nodes inside instances can't be patched directly
      // (they would need override syntax)
      expect(scene.getPatchTarget('n_card1::btn_submit'), 'n_card1');

      // Regular nodes can be patched
      expect(scene.getPatchTarget('n_root'), 'n_root');
    });
  });
}
```

### DragSession Tests

```dart
// test/free_design/canvas/drag_session_test.dart

void main() {
  group('DragSession', () {
    test('move frame session calculates correct bounds', () {
      final target = FrameTarget('frame1');
      final session = DragSession.move(
        targets: {target},
        positions: {target: const Offset(0, 0)},
      );

      session.accumulator = const Offset(100, 50);

      final bounds = session.getCurrentBounds(target);
      expect(bounds?.left, 100);
      expect(bounds?.top, 50);
    });

    test('move node session calculates correct bounds', () {
      final target = NodeTarget(
        frameId: 'frame1',
        expandedId: 'n_button',
        patchTarget: 'n_button',
      );
      final session = DragSession.move(
        targets: {target},
        positions: {target: const Offset(0, 0)},
      );

      session.accumulator = const Offset(25, 30);

      final bounds = session.getCurrentBounds(target);
      expect(bounds?.left, 25);
      expect(bounds?.top, 30);
    });

    test('resize session respects minimum size', () {
      final target = FrameTarget('frame1');
      final session = DragSession.resize(
        targets: {target},
        positions: {target: const Offset(0, 0)},
        sizes: {target: const Size(200, 200)},
        handle: ResizeHandle.bottomRight,
      );

      // Shrink below minimum
      session.accumulator = const Offset(-180, -180);

      final bounds = session.getCurrentBounds(target);
      expect(bounds?.width, greaterThanOrEqualTo(50));
      expect(bounds?.height, greaterThanOrEqualTo(50));
    });

    test('generatePatches produces SetFrameProp for frames', () {
      final target1 = FrameTarget('frame1');
      final target2 = FrameTarget('frame2');
      final session = DragSession.move(
        targets: {target1, target2},
        positions: {
          target1: const Offset(0, 0),
          target2: const Offset(400, 0),
        },
      );

      session.accumulator = const Offset(50, 100);

      final patches = session.generatePatches();

      expect(patches.length, 2);
      expect(patches.every((p) => p is SetFrameProp), isTrue);
    });

    test('generatePatches produces SetProp for nodes', () {
      final target = NodeTarget(
        frameId: 'frame1',
        expandedId: 'n_button',
        patchTarget: 'n_button',
      );
      final session = DragSession.move(
        targets: {target},
        positions: {target: const Offset(10, 20)},
      );

      session.accumulator = const Offset(50, 50);

      final patches = session.generatePatches();

      expect(patches.length, 1);
      final patch = patches.first as SetProp;
      expect(patch.id, 'n_button');
      expect(patch.path, '/layout/position');
      expect(patch.value, {'mode': 'absolute', 'x': 60.0, 'y': 70.0});
    });

    test('generatePatches skips nodes inside instances', () {
      final target = NodeTarget(
        frameId: 'frame1',
        expandedId: 'instance1::n_button',
        patchTarget: null,  // Inside instance, can't patch
      );
      final session = DragSession.move(
        targets: {target},
        positions: {target: const Offset(10, 20)},
      );

      session.accumulator = const Offset(50, 50);

      final patches = session.generatePatches();

      expect(patches, isEmpty);  // Can't patch inside instances
    });
  });
}
```

### Running Tests

```bash
# Run all free design tests
dart test test/free_design/

# Run specific test file
dart test test/free_design/models/node_test.dart

# Run with coverage
dart test --coverage=coverage test/free_design/
genhtml coverage/lcov.info -o coverage/html
```

---

## Open Questions

### 1. Nested Node Selection

**Question**: How do users select nodes within frames (not just frames)?

**Options**:
- Double-click frame to enter "frame edit mode"
- Click-through to nested nodes always
- Modifier key (Cmd+click) for nested selection

**Recommendation**: Double-click to enter frame, click to select nodes within. Escape to exit.

### 2. Undo/Redo

**Question**: How should undo/redo work?

**Options**:
- Patch-based (store patch history, compute inverse)
- Snapshot-based (store document snapshots)
- Hybrid

**Recommendation**: Patch-based with inverse patches. More memory efficient.

### 3. Clipboard

**Question**: How should copy/paste work?

**Options**:
- Internal clipboard (nodes as JSON)
- System clipboard (could paste into Figma?)
- Both

**Recommendation**: Internal clipboard for v1. Serialized node JSON.

### 4. Asset Management

**Question**: How should images be handled?

**Options**:
- References to project assets
- Inline base64 (bad for large images)
- External URLs

**Recommendation**: References to project assets via `src` path.

---

## Appendix A: Full Example Document

```json
{
  "irVersion": "1.0",
  "documentId": "doc_example",
  "frames": {
    "frame_dashboard": {
      "id": "frame_dashboard",
      "name": "Dashboard",
      "rootNodeId": "n_root",
      "canvas": {
        "position": { "x": 0, "y": 0 },
        "size": { "width": 375, "height": 812 }
      },
      "devicePreset": "iphone_17_pro",
      "createdAt": "2026-01-09T10:00:00Z",
      "updatedAt": "2026-01-09T10:00:00Z"
    }
  },
  "nodes": {
    "n_root": {
      "id": "n_root",
      "type": "container",
      "name": "Root",
      "children": ["n_header", "n_content"],
      "layout": {
        "size": { "width": "fill", "height": "fill" },
        "autoLayout": {
          "direction": "vertical",
          "gap": 0,
          "padding": { "top": 0, "right": 0, "bottom": 0, "left": 0 },
          "mainAlign": "start",
          "crossAlign": "stretch"
        }
      },
      "style": {
        "fill": { "token": "color.background" }
      },
      "props": {}
    },
    "n_header": {
      "id": "n_header",
      "type": "container",
      "name": "Header",
      "children": ["n_logo", "n_title", "n_spacer", "n_avatar"],
      "layout": {
        "size": { "width": "fill", "height": "hug" },
        "autoLayout": {
          "direction": "horizontal",
          "gap": { "token": "spacing.md" },
          "padding": {
            "top": { "token": "spacing.md" },
            "right": { "token": "spacing.md" },
            "bottom": { "token": "spacing.md" },
            "left": { "token": "spacing.md" }
          },
          "mainAlign": "start",
          "crossAlign": "center"
        }
      },
      "style": {
        "fill": { "token": "color.surface" },
        "border": {
          "color": { "token": "color.border" },
          "width": 1
        }
      },
      "props": {}
    },
    "n_logo": {
      "id": "n_logo",
      "type": "icon",
      "name": "Logo",
      "children": [],
      "layout": {
        "size": { "width": { "fixed": 24 }, "height": { "fixed": 24 } }
      },
      "style": {},
      "props": {
        "name": "lucide:sparkles",
        "size": 24,
        "color": { "token": "color.primary" }
      }
    },
    "n_title": {
      "id": "n_title",
      "type": "text",
      "name": "Title",
      "children": [],
      "layout": {
        "size": { "width": "hug", "height": "hug" }
      },
      "style": {},
      "props": {
        "text": "Dashboard",
        "textStyle": { "token": "text.h2" },
        "textAlign": "left"
      }
    },
    "n_spacer": {
      "id": "n_spacer",
      "type": "container",
      "name": "Spacer",
      "children": [],
      "layout": {
        "size": { "width": "fill", "height": "hug" }
      },
      "style": {},
      "props": {}
    },
    "n_avatar": {
      "id": "n_avatar",
      "type": "image",
      "name": "Avatar",
      "children": [],
      "layout": {
        "size": { "width": { "fixed": 32 }, "height": { "fixed": 32 } }
      },
      "style": {
        "radius": { "token": "radius.full" }
      },
      "props": {
        "src": "assets/avatar.png",
        "fit": "cover"
      }
    },
    "n_content": {
      "id": "n_content",
      "type": "container",
      "name": "Content",
      "children": [],
      "layout": {
        "size": { "width": "fill", "height": "fill" },
        "autoLayout": {
          "direction": "vertical",
          "gap": { "token": "spacing.md" },
          "padding": {
            "top": { "token": "spacing.md" },
            "right": { "token": "spacing.md" },
            "bottom": { "token": "spacing.md" },
            "left": { "token": "spacing.md" }
          },
          "mainAlign": "start",
          "crossAlign": "stretch"
        }
      },
      "style": {},
      "props": {}
    }
  },
  "components": {}
}
```

---

## Appendix B: Directory Structure

```
distill_editor/lib/
├── modules/
│   └── canvas/
│       ├── free_design/
│       │   ├── models/
│       │   │   ├── editor_document.dart
│       │   │   ├── frame.dart
│       │   │   ├── node.dart
│       │   │   ├── node_layout.dart
│       │   │   ├── node_style.dart
│       │   │   ├── node_props.dart
│       │   │   ├── component_def.dart
│       │   │   ├── render_document.dart
│       │   │   └── patch.dart
│       │   ├── state/
│       │   │   ├── editor_document_store.dart
│       │   │   └── free_design_state.dart
│       │   ├── compiler/
│       │   │   ├── render_compiler.dart
│       │   │   └── token_resolver.dart
│       │   ├── renderer/
│       │   │   ├── render_engine.dart
│       │   │   ├── frame_renderer.dart
│       │   │   └── node_renderers.dart
│       │   ├── widgets/
│       │   │   ├── selection_handles.dart
│       │   │   ├── snap_guides_overlay.dart
│       │   │   └── marquee_rect.dart
│       │   ├── agent/
│       │   │   ├── design_agent_tools.dart
│       │   │   ├── codegen_agent.dart
│       │   │   └── codegen_prompt_builder.dart
│       │   └── free_design_canvas.dart
│       ├── canvas_module.dart  # Updated to use free design
│       └── ...
└── ...
```
