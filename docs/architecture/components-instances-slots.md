# Components, Instances, and Slots Architecture

> A comprehensive technical reference for the component system in Distill Editor

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [DSL Grammar](#dsl-grammar)
3. [Intermediate Representation (IR)](#intermediate-representation-ir)
4. [Scene Expansion](#scene-expansion)
5. [Rendering Pipeline](#rendering-pipeline)
6. [Layer Tree Display](#layer-tree-display)
7. [Property Panel](#property-panel)
8. [Component Management](#component-management)
9. [Data Flow Diagram](#data-flow-diagram)
10. [Implementation Status](#implementation-status)
11. [Key Files Reference](#key-files-reference)
12. [Design Decisions](#design-decisions)
13. [Future Work](#future-work)

---

## Executive Summary

The Distill editor implements a **component-based design system** that allows designers to create reusable UI components, instantiate them with overrides, and define flexible content slots. The architecture follows a clear pipeline:

```
DSL Text → EditorDocument (IR) → ExpandedScene → RenderDocument → Flutter Widgets
```

**Key Concepts:**
- **ComponentDef**: Reusable component definitions with a root node tree
- **Instance**: A reference to a component with property overrides
- **Slot**: A placeholder within a component for content injection
- **ID Namespacing**: Prevents collisions when same component is used multiple times (e.g., `inst1::btn_root`)

**Current Status**: Core functionality is fully implemented. Advanced features like direct instance child editing are intentionally disabled in v1 to prevent data corruption.

---

## DSL Grammar

### Location
- [grammar.dart](../../distill_editor/lib/src/free_design/dsl/grammar.dart)
- [dsl_parser.dart](../../distill_editor/lib/src/free_design/dsl/dsl_parser.dart)
- [dsl_exporter.dart](../../distill_editor/lib/src/free_design/dsl/dsl_exporter.dart)

### Syntax

**Instance Declaration** - Uses the `use` keyword:
```
use(comp_button) - w 120 h 40
```

**Slot Declaration** - Uses the `slot` keyword:
```
slot(content) - w fill h hug
```

### Parser Implementation

The parser maps DSL node types to `NodeType` enum values:

```dart
// dsl_parser.dart
NodeType _mapNodeType(String typeStr) {
  return switch (typeStr.toLowerCase()) {
    'use' => NodeType.instance,
    // ... other types
  };
}
```

Props are created based on node type:

```dart
NodeType.instance => InstanceProps(
  componentId: content ?? '',
  overrides: const {},
),
NodeType.slot => SlotProps(slotName: content ?? ''),
```

### Exporter Implementation

Converts back to DSL text:

```dart
// dsl_exporter.dart
String _mapNodeTypeToString(NodeType type, AutoLayout? autoLayout) {
  return switch (type) {
    NodeType.instance => 'use',
    NodeType.slot => 'slot',
    // ... other cases
  };
}
```

---

## Intermediate Representation (IR)

### NodeType Enum

**Location**: [node_type.dart](../../distill_editor/lib/src/free_design/models/node_type.dart)

```dart
enum NodeType {
  container,
  text,
  image,
  icon,
  spacer,
  instance,  // Component instance - references a ComponentDef
  slot;      // Slot placeholder within a component definition
}
```

### ComponentDef Model

**Location**: [component_def.dart](../../distill_editor/lib/src/free_design/models/component_def.dart)

```dart
class ComponentDef {
  final String id;                           // Unique identifier (e.g., 'comp_button')
  final String name;                         // Human-readable name
  final String? description;                 // Optional description
  final String rootNodeId;                   // Root node of the component tree
  final Map<String, dynamic> exposedProps;   // Properties that can be overridden
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Key Points:**
- Immutable data structure (use `copyWith` to modify)
- The component's node tree exists in the document's `nodes` map
- `exposedProps` defines which properties can be overridden with default values

### InstanceProps

**Location**: [node_props.dart](../../distill_editor/lib/src/free_design/models/node_props.dart) (lines 426-476)

```dart
class InstanceProps extends NodeProps {
  final String componentId;                 // Reference to ComponentDef.id
  final Map<String, dynamic> overrides;     // Property overrides by node ID

  const InstanceProps({
    required this.componentId,
    this.overrides = const {},
  });
}
```

**Override Structure:**
```dart
overrides: {
  'btn_label': {                    // Target node ID within component
    'props': {'text': 'Submit'},    // Props overrides
  },
  'btn_root': {
    'style': {'opacity': 0.6},      // Style overrides
  },
}
```

### SlotProps

**Location**: [node_props.dart](../../distill_editor/lib/src/free_design/models/node_props.dart) (lines 477-527)

```dart
class SlotProps extends NodeProps {
  final String slotName;              // Identifier for the slot
  final String? defaultContentId;     // Optional default content node

  const SlotProps({
    required this.slotName,
    this.defaultContentId,
  });
}
```

### Document Storage

**Location**: [editor_document.dart](../../distill_editor/lib/src/free_design/models/editor_document.dart)

Components are stored at the document level:

```dart
class EditorDocument {
  final Map<String, Frame> frames;
  final Map<String, Node> nodes;
  final Map<String, ComponentDef> components;  // Component definitions
  final ThemeDocument theme;
}
```

---

## Scene Expansion

Scene expansion is the process of transforming component instances into their full, renderable node trees.

### Location
- [expanded_scene.dart](../../distill_editor/lib/src/free_design/scene/expanded_scene.dart)
- [expanded_scene_builder.dart](../../distill_editor/lib/src/free_design/scene/expanded_scene_builder.dart)

### ExpandedScene Model

```dart
class ExpandedScene {
  final String frameId;
  final String rootId;
  final Map<String, ExpandedNode> nodes;        // All expanded nodes
  final Map<String, String?> patchTarget;       // Maps expanded ID → document node ID

  bool isInsideInstance(String expandedId) => expandedId.contains('::');

  String? getOwningInstance(String expandedId) {
    if (!isInsideInstance(expandedId)) return null;
    return expandedId.split('::').first;
  }
}
```

### ExpandedNode Model

```dart
class ExpandedNode {
  final String id;                    // May be namespaced: 'inst1::btn_root'
  final String? patchTargetId;        // Document node to edit (null for instance children)
  final NodeType type;
  final List<String> childIds;        // References other expanded nodes
  final NodeLayout layout;
  final NodeStyle style;
  final NodeProps props;              // With overrides applied
  Rect? bounds;                       // Computed after layout pass
}
```

### ID Namespacing System

**Pattern**: `{instanceId}::{localNodeId}`

| Scenario | ID Format |
|----------|-----------|
| Regular node | `n_button` |
| Inside instance `inst1` | `inst1::n_button` |
| Nested instances | `inst1::inst2::n_button` |

**Purpose**: Prevents ID collisions when the same component is instantiated multiple times.

### Expansion Algorithm

```dart
ExpandedScene? build(String frameId, EditorDocument doc) {
  final frame = doc.frames[frameId];
  final rootNode = doc.nodes[frame.rootNodeId];

  final nodes = <String, ExpandedNode>{};
  final patchTarget = <String, String?>{};

  _expandNode(
    node: rootNode,
    doc: doc,
    namespace: null,
    instancePatchTarget: null,
    nodes: nodes,
    patchTarget: patchTarget,
  );

  return ExpandedScene(
    frameId: frameId,
    rootId: rootNode.id,
    nodes: nodes,
    patchTarget: patchTarget,
  );
}
```

### Instance Expansion Process

1. **Detect Instance Node**
   ```dart
   if (node.type == NodeType.instance) {
     return _expandInstance(...);
   }
   ```

2. **Lookup Component Definition**
   ```dart
   final props = instanceNode.props as InstanceProps;
   final component = doc.components[props.componentId];
   if (component == null) {
     return _createPlaceholder(...);  // Fallback for missing component
   }
   ```

3. **Create Instance Namespace**
   ```dart
   final instanceId = _namespaceId(instanceNode.id, namespace);
   final instanceNamespace = instanceId;
   patchTarget[instanceId] = instanceNode.id;
   ```

4. **Recursively Expand Component Tree**
   ```dart
   _expandComponentTree(
     node: componentRoot,
     doc: doc,
     component: component,
     instanceId: instanceId,
     instanceNamespace: instanceNamespace,
     overrides: props.overrides,
     nodes: nodes,
     patchTarget: patchTarget,
   );
   ```

5. **Return Component Root's Expanded ID**
   ```dart
   return '$instanceNamespace::${component.rootNodeId}';
   ```

### Override Application

```dart
void _expandComponentTree({...}) {
  var resolvedNode = node;
  final nodeOverrides = overrides[node.id];

  if (nodeOverrides != null && nodeOverrides is Map<String, dynamic>) {
    resolvedNode = _applyOverrides(node, nodeOverrides);
  }

  final expandedNode = ExpandedNode.fromNode(
    resolvedNode,
    expandedId: expandedId,
    patchTargetId: null,  // Instance children not directly editable
    childIds: expandedChildIds,
  );
}
```

**Supported Override Types:**
- `props` - Text content, icon names, image sources, etc.
- `style` - Opacity, fill colors, etc.
- `layout` - Size, position (partially implemented)

### Patch Targeting Strategy

The `patchTarget` map determines which document node should be modified when editing an expanded node:

| Node Type | patchTargetId | Editable? |
|-----------|---------------|-----------|
| Regular node | `nodeId` | ✅ Yes |
| Instance node itself | `instanceId` | ✅ Yes |
| Instance children | `null` | ❌ No (v1 limitation) |

**Rationale**: Editing instance children would require sophisticated merge logic between the component definition and instance overrides. v1 allows editing only via the override system.

---

## Rendering Pipeline

### Flow

```
EditorDocument → ExpandedScene → RenderDocument → Flutter Widgets
```

### RenderCompiler

**Location**: [render_compiler.dart](../../distill_editor/lib/src/free_design/render/render_compiler.dart)

Converts expanded nodes to render-ready nodes with resolved tokens:

```dart
RenderNodeType _mapNodeType(ExpandedNode node) {
  return switch (node.type) {
    NodeType.instance => RenderNodeType.box,  // Should be expanded already
    NodeType.slot => RenderNodeType.box,      // Slot renders as container
    // ... other types
  };
}
```

> **Note**: Instance nodes should be fully expanded before reaching the compiler. If an instance node appears unexpectedly, it's treated as a box container (error fallback).

### RenderEngine

**Location**: [render_engine.dart](../../distill_editor/lib/src/free_design/render/render_engine.dart)

Builds Flutter widgets from render nodes:

```dart
Widget widget = switch (node.type) {
  RenderNodeType.box => _buildBox(node, doc, docGeneration),
  RenderNodeType.row => _buildRow(node, doc, docGeneration),
  RenderNodeType.column => _buildColumn(node, doc, docGeneration),
  RenderNodeType.text => _buildText(node),
  RenderNodeType.image => _buildImage(node),
  RenderNodeType.icon => _buildIcon(node),
  RenderNodeType.spacer => _buildSpacer(node),
};
```

### FrameRenderer

**Location**: [frame_renderer.dart](../../distill_editor/lib/src/free_design/canvas/widgets/frame_renderer.dart)

Renders a complete frame with bounds tracking:

```dart
final renderDoc = widget.state.getRenderDoc(widget.frameId);

Widget content = ClipRect(
  child: KeyedSubtree(
    key: _frameRootKey,
    child: RenderEngine(
      frameRootKey: _frameRootKey,
      onBoundsChanged: (nodeId, bounds) {
        widget.state.updateNodeBounds(widget.frameId, nodeId, bounds);
      },
      reflowOffsets: reflowOffsets,
    ).build(renderDoc),
  ),
);
```

---

## Layer Tree Display

### WidgetTreePanel

**Location**: [widget_tree_panel.dart](../../distill_editor/lib/modules/canvas/widgets/widget_tree_panel.dart)

Displays the node hierarchy with special handling for instances:

```dart
// Instance nodes (patchTarget == null) are leaves - don't render children
final canExpand =
    expandedNode.patchTargetId != null && expandedNode.childIds.isNotEmpty;
final isExpanded = canExpand && widget.treeState.isExpanded(expandedId);
```

**Behavior:**
- Instances shown as collapsed nodes by default
- Children of instances are hidden (v1 limitation)
- Cannot expand instance nodes (patchTargetId == null)

### NodeTreeItem

**Location**: [node_tree_item.dart](../../distill_editor/lib/modules/canvas/widgets/node_tree_item.dart)

Renders individual tree items with instance badge:

```dart
if (isInstance) ...[
  const SizedBox(width: 4),
  Tooltip(
    message: 'Component instance (children hidden)',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF9333EA).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Icon(
        LucideIcons.component200,
        size: 12,
        color: Color(0xFF9333EA),
      ),
    ),
  ),
],
```

### Node Type Icons

**Location**: [node_type_icon.dart](../../distill_editor/lib/modules/canvas/widgets/node_type_icon.dart)

```dart
NodeType.instance => HoloIconData.huge(HugeIconsStrokeRounded.diamond),
NodeType.slot => HoloIconData.huge(HugeIconsStrokeRounded.dashedLine01),
```

---

## Property Panel

### FreeDesignPropertyPanel

**Location**: [property_panel.dart](../../distill_editor/lib/src/free_design/properties/property_panel.dart)

Protects instance children from direct editing:

```dart
Widget _buildNodeProperties(BuildContext context, NodeTarget target) {
  final nodeId = target.patchTarget;
  if (nodeId == null) {
    return Center(
      child: Text(
        'Cannot edit nodes inside instances',
        style: context.typography.body.small.copyWith(
          color: context.colors.foreground.muted,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  // ... render property sections
}
```

### ContentSection

**Location**: [content_section.dart](../../distill_editor/lib/src/free_design/properties/sections/content_section.dart)

Handles instance and slot props display:

```dart
if (props is InstanceProps) {
  return _buildInstanceProps(context, props);
}

if (props is SlotProps) {
  return _buildSlotProps(context, props);
}
```

---

## Component Management

### Document-Level Operations

**Location**: [editor_document.dart](../../distill_editor/lib/src/free_design/models/editor_document.dart)

```dart
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
```

### Example: Creating a Button Component

```dart
// Define the component
final buttonComponent = ComponentDef(
  id: 'comp_button',
  name: 'Button',
  description: 'A simple button with label',
  rootNodeId: 'btn_root',
  exposedProps: {'label': 'Click Me'},
  createdAt: now,
  updatedAt: now,
);

// Define the component's node tree
final btnRoot = Node(
  id: 'btn_root',
  name: 'Button Container',
  type: NodeType.container,
  props: ContainerProps(),
  layout: NodeLayout(
    size: SizeMode.hug(),
    autoLayout: AutoLayout(
      direction: LayoutDirection.horizontal,
      padding: TokenEdgePadding.symmetric(horizontal: 16, vertical: 10),
      mainAlign: MainAxisAlignment.center,
      crossAlign: CrossAxisAlignment.center,
    ),
  ),
  style: NodeStyle(
    fill: SolidFill(HexColor('#007AFF')),
    cornerRadius: CornerRadius.circular(8),
  ),
  childIds: ['btn_label'],
);

final btnLabel = Node(
  id: 'btn_label',
  name: 'Button Label',
  type: NodeType.text,
  props: TextProps(text: 'Click Me', fontSize: 14, fontWeight: 600, color: '#FFFFFF'),
  layout: NodeLayout(size: SizeMode.hug()),
);

// Add to document
final doc = document
    .withNode(btnRoot)
    .withNode(btnLabel)
    .withComponent(buttonComponent);
```

### Example: Using an Instance with Overrides

```dart
final myButton = Node(
  id: 'inst_primary_btn',
  name: 'Primary Button',
  type: NodeType.instance,
  props: InstanceProps(
    componentId: 'comp_button',
    overrides: {
      'btn_label': {
        'props': {'text': 'Submit'},  // Override the button text
      },
      'btn_root': {
        'style': {'opacity': 0.8},    // Make it slightly transparent
      },
    },
  ),
  layout: NodeLayout(size: SizeMode.hug()),
);
```

### Example: Creating a Component with Slot

```dart
final cardComponent = ComponentDef(
  id: 'comp_card',
  name: 'Card',
  description: 'A card with content slot',
  rootNodeId: 'card_root',
  exposedProps: {'title': 'Card Title'},
  createdAt: now,
  updatedAt: now,
);

final cardContentSlot = Node(
  id: 'card_content_slot',
  name: 'Content Slot',
  type: NodeType.slot,
  props: SlotProps(
    slotName: 'content',
    defaultContentId: null,  // No default content
  ),
  layout: NodeLayout(size: SizeMode.fixed(double.infinity, 60)),
  style: NodeStyle(
    fill: SolidFill(HexColor('#F0F0F0')),
    cornerRadius: CornerRadius.circular(8),
  ),
);
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      DSL TEXT FORMAT                             │
│                                                                  │
│  use(comp_button) - w 120 h 40                                  │
│  slot(content) - w fill h hug                                   │
└─────────────────────┬───────────────────────────────────────────┘
                      │ DslParser
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                  EDITOR DOCUMENT (IR)                            │
│                                                                  │
│  ┌────────────────────────────────────────────┐                 │
│  │ ComponentDef(comp_button)                  │                 │
│  │  - id: 'comp_button'                       │                 │
│  │  - rootNodeId: 'btn_root'                  │                 │
│  │  - exposedProps: {label: 'Click Me'}       │                 │
│  └────────────────────────────────────────────┘                 │
│                                                                  │
│  ┌────────────────────────────────────────────┐                 │
│  │ Node(inst1, type: instance)                │                 │
│  │  props: InstanceProps(                     │                 │
│  │    componentId: 'comp_button'              │                 │
│  │    overrides: {                            │                 │
│  │      'btn_label': {props: {text: 'OK'}}   │                 │
│  │    }                                       │                 │
│  │  )                                         │                 │
│  └────────────────────────────────────────────┘                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │ ExpandedSceneBuilder
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              EXPANDED SCENE (Flattened Tree)                     │
│                                                                  │
│  ┌────────────────────────────────────────────┐                 │
│  │ ExpandedNode(inst1::btn_root)              │                 │
│  │  - patchTargetId: null (not editable)      │                 │
│  │  - childIds: ['inst1::btn_label']          │                 │
│  └────────────────────────────────────────────┘                 │
│                                                                  │
│  ┌────────────────────────────────────────────┐                 │
│  │ ExpandedNode(inst1::btn_label)             │                 │
│  │  - props: TextProps(text: 'OK')            │ ← Override      │
│  │  - patchTargetId: null                     │   applied!      │
│  └────────────────────────────────────────────┘                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │ RenderCompiler
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│            RENDER DOCUMENT (Widget-Ready)                        │
│                                                                  │
│  - Design tokens resolved to concrete values                    │
│  - Layout properties extracted and normalized                   │
│  - Ready for Flutter widget construction                        │
└─────────────────────┬───────────────────────────────────────────┘
                      │ RenderEngine
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   FLUTTER WIDGETS                                │
│                                                                  │
│  Container(                                                      │
│    decoration: BoxDecoration(                                    │
│      color: Color(0xFF007AFF),                                  │
│      borderRadius: BorderRadius.circular(8),                    │
│    ),                                                            │
│    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), │
│    child: Text('OK', style: TextStyle(...)),                    │
│  )                                                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| **DSL Parsing** | ✅ Complete | `use` and `slot` keywords work |
| **DSL Export** | ✅ Complete | Round-trip tested |
| **ComponentDef Model** | ✅ Complete | Full CRUD via EditorDocument |
| **InstanceProps Model** | ✅ Complete | Override system functional |
| **SlotProps Model** | ✅ Complete | Basic slot support |
| **Scene Expansion** | ✅ Complete | ID namespacing, override application |
| **Instance Rendering** | ✅ Complete | Fully expanded and rendered |
| **Slot Rendering** | ⚠️ Partial | Renders as container; content injection not implemented |
| **Layer Tree Display** | ✅ Complete | Shows instances with badge, prevents expansion |
| **Property Panel** | ⚠️ Partial | Protection works; override editing UI limited |
| **Instance Child Editing** | ❌ Disabled (v1) | Intentionally blocked to prevent corruption |
| **Component Creation UI** | ⚠️ Limited | No dedicated UI; manual creation only |
| **Nested Instances** | ✅ Complete | Multi-level namespacing works |
| **Override System** | ✅ Complete | Props, style, layout overrides work |

---

## Key Files Reference

### Core Models
| File | Description |
|------|-------------|
| [component_def.dart](../../distill_editor/lib/src/free_design/models/component_def.dart) | ComponentDef model |
| [node_type.dart](../../distill_editor/lib/src/free_design/models/node_type.dart) | NodeType enum |
| [node_props.dart](../../distill_editor/lib/src/free_design/models/node_props.dart) | InstanceProps, SlotProps |
| [editor_document.dart](../../distill_editor/lib/src/free_design/models/editor_document.dart) | Document storage |

### DSL Layer
| File | Description |
|------|-------------|
| [grammar.dart](../../distill_editor/lib/src/free_design/dsl/grammar.dart) | Grammar constants |
| [dsl_parser.dart](../../distill_editor/lib/src/free_design/dsl/dsl_parser.dart) | Text → IR parser |
| [dsl_exporter.dart](../../distill_editor/lib/src/free_design/dsl/dsl_exporter.dart) | IR → text exporter |

### Scene Expansion
| File | Description |
|------|-------------|
| [expanded_scene.dart](../../distill_editor/lib/src/free_design/scene/expanded_scene.dart) | ExpandedScene model |
| [expanded_scene_builder.dart](../../distill_editor/lib/src/free_design/scene/expanded_scene_builder.dart) | Instance expansion algorithm |

### Rendering
| File | Description |
|------|-------------|
| [render_compiler.dart](../../distill_editor/lib/src/free_design/render/render_compiler.dart) | Token resolution |
| [render_engine.dart](../../distill_editor/lib/src/free_design/render/render_engine.dart) | Widget building |
| [render_document.dart](../../distill_editor/lib/src/free_design/render/render_document.dart) | RenderDocument model |
| [frame_renderer.dart](../../distill_editor/lib/src/free_design/canvas/widgets/frame_renderer.dart) | Frame rendering |

### UI Layer
| File | Description |
|------|-------------|
| [widget_tree_panel.dart](../../distill_editor/lib/modules/canvas/widgets/widget_tree_panel.dart) | Layer hierarchy |
| [node_tree_item.dart](../../distill_editor/lib/modules/canvas/widgets/node_tree_item.dart) | Tree item with instance badge |
| [property_panel.dart](../../distill_editor/lib/src/free_design/properties/property_panel.dart) | Property editing |
| [node_type_icon.dart](../../distill_editor/lib/modules/canvas/widgets/node_type_icon.dart) | Type icons |

### Tests
| File | Description |
|------|-------------|
| [expanded_scene_builder_test.dart](../../distill_editor/test/free_design/scene/expanded_scene_builder_test.dart) | Expansion tests |
| [dsl_parser_test.dart](../../distill_editor/test/free_design/dsl/dsl_parser_test.dart) | DSL parsing tests |

### Examples
| File | Description |
|------|-------------|
| [mock_frames.dart](../../distill_editor/lib/modules/canvas/mock_frames.dart) | Complete working examples (lines 800-1200) |

---

## Design Decisions

### v1 Limitation: No Direct Instance Child Editing

**Decision**: Instance children cannot be directly edited.

**Rationale**: Editing instance children would require sophisticated merge logic between the component definition and instance overrides. Without this, edits could:
- Conflict with future component updates
- Create orphaned override data
- Lead to inconsistent state

**Evidence** (expanded_scene_builder.dart):
```dart
// Create expanded node - instance children cannot be edited (v1)
// Set patchTargetId to null to prevent editing
final expandedNode = ExpandedNode.fromNode(
  resolvedNode,
  expandedId: expandedId,
  patchTargetId: null,  // Explicitly null
  childIds: expandedChildIds,
);
```

**User Experience**: Property panel shows "Cannot edit nodes inside instances" message when an instance child is selected.

### ID Namespacing Convention

**Pattern**: `{instanceId}::{componentNodeId}::{nestedInstanceId}::...`

**Examples**:
- `inst1::btn_root` - Button root inside instance 1
- `inst1::inst2::icon` - Icon inside nested instance

**Benefit**: Allows unlimited instances of the same component without ID collisions.

### Separation of Document and Expanded State

**Decision**: Keep the source document (IR) separate from the expanded/rendered view.

**Rationale**:
- Single source of truth (document)
- Expansion can be recomputed when needed
- Cleaner undo/redo (only document changes)
- Component updates automatically propagate to all instances

---

## Future Work

Based on code patterns and v1 limitations, these features could be added:

### 1. Slot Content Injection
Slots currently render as empty containers. Future work needed:
- Mechanism for passing content to slot positions
- UI for dragging content into slots
- Override mechanism for slot content

### 2. Advanced Override UI
While overrides work programmatically, a visual UI is needed:
- Visual editor for property overrides
- Preview of overridden vs default values
- Reset override functionality

### 3. Component Library Panel
No dedicated panel for browsing components:
- Component browser/picker
- Drag-and-drop component instantiation
- Component search and filtering

### 4. Component Editing Mode
Ability to edit component definitions directly:
- "Enter component" context
- Edit component in isolation
- See affected instances

### 5. Instance Child Direct Editing (v2+)
Enable editing instance children with proper merge logic:
- Automatic override creation
- Conflict resolution UI
- Override inheritance chain

---

*Last updated: January 2026*
