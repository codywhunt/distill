# Free Design Canvas

Figma-like visual editing system for Hologram with AI-powered UI generation.

## Overview

Free Design provides a visual editing experience where users can:

- **Canvas editing** - Drag, resize, and reparent widgets with instant visual feedback
- **AI generation** - Generate UI from natural language descriptions via DSL
- **Live preview** - See changes rendered as Flutter widgets in real-time
- **Property editing** - Edit node properties through a streamlined property panel

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CanvasState (Orchestrator)                    │
│   Selection, drag sessions, hit testing, spatial indexing        │
└─────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌─────────────────┐   ┌─────────────────────┐
│  Property     │   │ EditorDocument  │   │  DSL Parser/        │
│  Panel        │   │ Store           │   │  Exporter           │
│  (UI)         │   │ (State)         │   │  (AI Interface)     │
└───────────────┘   └─────────────────┘   └─────────────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 EDITOR IR (Source of Truth)                      │
│   EditorDocument: Frames, Nodes, Components (immutable)          │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐
│ ExpandedScene   │  │  Patch Applier  │  │  OutlineCompiler    │
│ Builder         │  │  (Mutations)    │  │  (AI Context)       │
└─────────────────┘  └─────────────────┘  └─────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│               EXPANDED SCENE (Derived, Cached)                   │
│   Instances flattened, overrides applied, IDs namespaced         │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│               RENDER COMPILER → RENDER DOCUMENT                  │
│   Token resolution, layout props, ready for widgets              │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER WIDGETS                               │
│   FreeDesignCanvas, FrameRenderer, SelectionOverlay, etc.        │
└─────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
lib/src/free_design/
├── ai/                      # LLM-powered generation
│   ├── clients/             # Anthropic, Gemini, OpenAI, Mock
│   ├── prompts/             # System prompts for generation/update
│   ├── repair/              # Validation and repair of AI output
│   ├── ai_service.dart      # High-level service layer
│   └── frame_generator.dart # Main generation API
├── canvas/                  # Canvas interaction
│   ├── widgets/             # Canvas UI components
│   ├── drag_target.dart     # Selection types (Frame/Node)
│   └── drag_session.dart    # Drag state management
├── compiler/                # Compilation pipeline
│   ├── compiler.dart        # RenderCompiler entry
│   └── outline_compiler.dart# AI context generation
├── dsl/                     # Domain Specific Language
│   ├── grammar.dart         # DSL v1 specification
│   ├── dsl_parser.dart      # Text → IR
│   └── dsl_exporter.dart    # IR → Text
├── layout/                  # Layout validation
├── models/                  # Editor IR data structures
│   ├── editor_document.dart # Source of truth
│   ├── frame.dart           # Canvas surface
│   ├── node.dart            # Visual element
│   ├── node_layout.dart     # Positioning & sizing
│   ├── node_style.dart      # Visual styling
│   ├── node_props.dart      # Type-specific properties
│   └── component_def.dart   # Reusable components
├── patch/                   # Atomic operations
│   ├── patch_op.dart        # All operation types
│   ├── patch_applier.dart   # Immutable application
│   ├── patch_validator.dart # Pre-validation
│   └── scene_change_set.dart# Dirty tracking
├── projection/              # Projection service
├── properties/              # Property panel
│   ├── editors/             # Input widgets
│   │   ├── core/            # Styling, mixins, validation
│   │   ├── primitives/      # Number, text, boolean, dropdown
│   │   ├── composite/       # Padding, border-radius, stroke, shadow
│   │   ├── pickers/         # Color picker
│   │   ├── slots/           # Prefix widgets
│   │   └── widgets/         # PropertyField wrapper
│   ├── sections/            # Grouped property UI
│   └── property_panel.dart  # Main panel widget
├── render/                  # Render pipeline
├── scene/                   # Instance expansion
│   ├── expanded_scene.dart  # Flattened scene model
│   └── expanded_scene_builder.dart
├── store/                   # State management
│   └── editor_document_store.dart
└── free_design.dart         # Library exports
```

### Module Summary

| Module | Purpose |
|--------|---------|
| `models/` | Editor IR data structures (Node, Frame, Layout, Style) |
| `patch/` | Atomic, invertible operations for editing |
| `store/` | State management with change tracking |
| `scene/` | Instance expansion for component rendering |
| `render/` | Deterministic compilation to Flutter widgets |
| `canvas/` | Drag, selection, and canvas interaction |
| `dsl/` | Compact text format for AI generation (~75% token reduction) |
| `properties/` | Property panel with streaming editors |
| `ai/` | LLM-powered frame generation and updates |
| `compiler/` | OutlineCompiler for AI context |

## Quick Start

```dart
import 'package:distill_editor/src/free_design/free_design.dart';

// Create a store with an empty document
final store = EditorDocumentStore.empty();

// Create a node
final node = Node(
  id: 'n_button',
  name: 'Submit Button',
  type: NodeType.container,
  props: ContainerProps(),
  layout: NodeLayout(
    size: SizeMode.fixed(width: 120, height: 40),
  ),
  style: NodeStyle(
    fill: SolidFill(HexColor('#007AFF')),
    cornerRadius: CornerRadius.all(8),
  ),
);

// Add to document via patch
store.applyPatch(InsertNode(node));
```

## Data Models

### Node

The fundamental building block. Nodes are **immutable** - use `copyWith()` to create modified copies.

```dart
class Node {
  final String id;          // Unique identifier
  final String name;        // Human-readable name
  final NodeType type;      // container, text, image, icon, spacer, instance, slot
  final NodeProps props;    // Type-specific properties
  final NodeLayout layout;  // Position, size, auto-layout
  final NodeStyle style;    // Fill, stroke, corner radius, etc.
  final List<String> childIds;  // Child node IDs (order matters)
}
```

### Node Types

| Type | Description |
|------|-------------|
| `container` | Box container with optional children and auto-layout |
| `text` | Text content with styling |
| `image` | Image asset reference |
| `icon` | Icon from an icon set |
| `spacer` | Flexible space (Expanded/Spacer in Flutter) |
| `instance` | Component instance - references a ComponentDef |
| `slot` | Slot placeholder within a component definition |

### Frame

A top-level container on the canvas (like a Figma frame/artboard).

```dart
class Frame {
  final String id;
  final String name;
  final String rootNodeId;      // Root node of the frame's tree
  final CanvasPlacement canvas; // Position and size on canvas
}
```

### EditorDocument

The complete document containing all frames, nodes, and components.

```dart
class EditorDocument {
  final String id;
  final Map<String, Frame> frames;
  final Map<String, Node> nodes;
  final Map<String, ComponentDef> components;
}
```

## Patch Protocol

All mutations go through **patch operations** - atomic, invertible changes that enable undo/redo.

### Property Operations

```dart
// Set a property on a node by JSON Pointer path
SetProp(id: 'n_button', path: '/style/fill', value: {...})

// Set a property on a frame
SetFrameProp(frameId: 'f_home', path: '/name', value: 'Home Screen')
```

### Node Structure Operations

```dart
// Insert node into document (doesn't attach to parent)
InsertNode(node)

// Attach node as child of parent
AttachChild(parentId: 'n_root', childId: 'n_button', index: 0)

// Detach node from parent (doesn't remove from document)
DetachChild(parentId: 'n_root', childId: 'n_button')

// Remove node from document
DeleteNode('n_button')

// Move node to new parent (combines detach + attach)
MoveNode(id: 'n_button', newParentId: 'n_footer', index: -1)

// Replace node data entirely (keeps same ID)
ReplaceNode(id: 'n_button', node: updatedNode)
```

### Frame Operations

```dart
// Insert a new frame
InsertFrame(frame)

// Remove a frame
RemoveFrame('f_home')
```

## Store

`EditorDocumentStore` manages document state with change tracking.

```dart
final store = EditorDocumentStore.empty();

// Apply single patch
store.applyPatch(InsertNode(node));

// Apply multiple patches atomically
store.applyPatches([
  InsertNode(node),
  AttachChild(parentId: 'root', childId: node.id),
]);

// Query helpers
store.getParent(nodeId);      // Get parent ID
store.getAncestors(nodeId);   // Get all ancestors to root
store.getDescendants(nodeId); // Get all descendants
store.getFrameForNode(nodeId); // Get containing frame

// Extension methods for convenience
store.addNode(node, parentId: 'root');
store.removeNode(nodeId);
store.moveNode(nodeId, newParentId: 'footer');
store.updateNodeProp(nodeId, '/style/fill', value);
```

## AI Integration

The `ai/` module provides LLM-powered frame generation.

### Supported Providers

| Client | Provider |
|--------|----------|
| `AnthropicClient` | Claude (Anthropic) |
| `GeminiClient` | Gemini (Google) |
| `OpenAIClient` | GPT-4 (OpenAI) |
| `MockClient` | Testing/development |

### Frame Generation

```dart
final client = AnthropicClient(apiKey: 'sk-...');
final generator = FrameGenerator(client);

// Generate new frame from description
final result = await generator.generate(
  prompt: 'A login form with email, password, and submit button',
  document: store.document,
  position: Offset(100, 100),
  size: Size(375, 812),
);

// Apply to document
store.applyPatches([
  InsertFrame(result.frame),
  ...result.nodes.values.map((n) => InsertNode(n)),
]);
```

### Update Existing Frame

```dart
final result = await generator.update(
  prompt: 'Make the button blue and add a forgot password link',
  frame: existingFrame,
  nodes: frameNodes,
  targetNodeIds: ['n_button'], // Optional: focus on specific nodes
);
```

## Canvas

The `canvas/` module provides interactive editing.

### Key Components

| Component | Purpose |
|-----------|---------|
| `FreeDesignCanvas` | Main canvas widget with zoom/pan |
| `DragTarget` | Represents a draggable frame or node |
| `DragSession` | Manages drag state with snap support |
| `CanvasState` | Main state orchestrator |

### Canvas Widgets

- `FrameRenderer` - Renders a frame and its node tree
- `SelectionOverlay` - Selection highlight and handles
- `ResizeHandles` - 8-point resize handles
- `SnapGuidesOverlay` - Smart alignment guides
- `MarqueeOverlay` - Multi-select rectangle
- `PromptBoxOverlay` - AI prompt input
- `InsertionIndicatorOverlay` - Drop target indicator

## Render Pipeline

The render pipeline converts Editor IR to Flutter widgets:

1. **ExpandedScene** - Flattens component instances
2. **RenderCompiler** - Compiles to RenderDocument
3. **TokenResolver** - Resolves design tokens
4. **RenderEngine** - Outputs Flutter widgets

```dart
// Build expanded scene from document
final scene = ExpandedSceneBuilder.build(document);

// Compile to render document
final renderDoc = RenderCompiler.compile(scene, tokenResolver);

// Render to widgets
final widget = RenderEngine.render(renderDoc, frameId);
```

## DSL (Domain Specific Language)

The Free Design DSL is a compact **text-based** format optimized for LLM token efficiency (~75% reduction vs JSON).

### DSL v1 Syntax

```
dsl:1
frame Login - w 375 h 812
  column#n_root - gap 24 pad 24 bg #FFFFFF w fill h fill
    text "Welcome Back" - size 24 weight 700 color #000000
    column - gap 16
      text "Email" - size 14 weight 500 color #666666
      container - h 48 pad 12 bg #F5F5F5 r 8
        text "email@example.com" - size 16 color #000000
    container - h 48 bg #007AFF r 8 align center,center
      text "Sign In" - size 16 weight 600 color #FFFFFF
```

### Key Features

- **Indentation-based hierarchy** - Children are indented under parents
- **Shorthand properties** - `w` (width), `h` (height), `bg` (background), `r` (radius)
- **Explicit IDs** - `#n_root` syntax for node IDs
- **Property separator** - `-` separates node type from properties

### Node Types (DSL)

| Type | Aliases | Description |
|------|---------|-------------|
| `container` | - | Box with optional children |
| `row` | - | Horizontal auto-layout container |
| `column` | `col` | Vertical auto-layout container |
| `text` | - | Text content with styling |
| `image` | `img` | Image asset reference |
| `icon` | - | Icon from an icon set |
| `spacer` | - | Flexible space (Expanded) |
| `use` | - | Component instance |

### Property Shorthands

| Shorthand | Full Name | Example |
|-----------|-----------|---------|
| `w` | width | `w 120`, `w fill`, `w hug` |
| `h` | height | `h 40`, `h fill`, `h hug` |
| `gap` | gap | `gap 16` |
| `pad` | padding | `pad 24`, `pad 12,24`, `pad 8,16,8,16` |
| `align` | alignment | `align start,center` |
| `bg` | background | `bg #FFF`, `bg primary` |
| `r` | radius | `r 8`, `r 8,4,4,8` |
| `border` | border | `border 1 #000` |
| `opacity` | opacity | `opacity 0.5` |

### Size Modes

| Mode | DSL Syntax | Flutter Equivalent |
|------|------------|--------------------|
| Hug content | `w hug` | Intrinsic size |
| Fill parent | `w fill` | Expanded |
| Fixed pixels | `w 120` | SizedBox(width: 120) |

### Parser/Exporter Usage

```dart
// Parse DSL text to IR
final result = DslParser.parse(dslText);
final frame = result.frame;
final nodes = result.nodes;

// Export IR to DSL text
final dslText = DslExporter.export(document, frameId);
```

## Design Philosophy

| Aspect | Choice | Rationale |
|--------|--------|-----------|
| **Minimal Node Types** | 7 types | Small vocabulary agents can fully understand |
| **Layout Model** | Auto-layout + hug/fill/fixed | Figma-like; flexible and responsive |
| **Immutable Data** | All models use `copyWith()` | Enables undo/redo; predictable state |
| **Patch Protocol** | Atomic, invertible operations | Collaborative editing; undo/redo |
| **Separation** | Editor IR → Expanded Scene → Render | Decouples editing from rendering |

## Property Panel

The property panel provides editors for all node properties.

### Architecture

```
PropertyPanel
├── FrameSection (when frame selected)
│   └── Name, position, size
└── Node Sections (when node selected)
    ├── ContentSection (type-specific: text, image src, icon)
    ├── PositionSection (position mode, absolute x/y)
    ├── AutoLayoutSection (direction, gap, padding, alignment)
    └── AppearanceSection (fill, stroke, radius, shadow, opacity)
```

### Editor Types

| Editor | Purpose |
|--------|---------|
| `NumberEditor` | Numeric values with optional min/max |
| `TextEditor` | Text content |
| `BooleanEditor` | Segmented true/false control |
| `DropdownEditor` | Select from options |
| `ToggleEditor` | Icon-based toggle buttons |
| `DirectionEditor` | Row/column direction toggle |
| `PaddingEditor` | Mode cycling (all/symmetric/only) |
| `BorderRadiusEditor` | Mode cycling (all/only) |
| `StrokeEditor` | Border width, color, alignment |
| `ShadowEditor` | Drop shadow properties |
| `ColorPickerMenu` | Visual color selection + hex input |

### Update Flow

```dart
// In a property section
NumberEditor(
  value: node.style.opacity,
  onChanged: (value) {
    if (value != null) {
      store.updateNodeProp(nodeId, '/style/opacity', value);
    }
  },
)

// Batch updates for composite editors
store.updateNodeProps(nodeId, {
  '/style/cornerRadius/topLeft': 8.0,
  '/style/cornerRadius/topRight': 8.0,
  '/style/cornerRadius/bottomLeft': 8.0,
  '/style/cornerRadius/bottomRight': 8.0,
});
```

### Performance Features

- **DebounceMixin** - Reduces store updates during typing (~80% reduction)
- **HoverStateMixin** - Standardized hover state management
- **Batch Updates** - `store.updateNodeProps()` for composite editors
- **Value Equality** - Proper `==` on value objects prevents unnecessary rebuilds

## CanvasState (Orchestrator)

The `CanvasState` class (in `modules/canvas/canvas_state.dart`) orchestrates all canvas interactions:

### Responsibilities

- **Selection** - Frames and nodes, single and multi-select
- **Drag Sessions** - Move, resize, marquee selection
- **Hit Testing** - Spatial indexing via QuadTree for O(log n) frame lookup
- **Caching** - Expanded scenes, render documents, node bounds, AI outlines
- **Smart Guides** - Snap engine integration during drag operations
- **AI State** - Tracks generating/updating frames for loading indicators

### Key Methods

```dart
// Selection
canvasState.select(target);
canvasState.selectFrame(frameId);
canvasState.selectNode(frameId, expandedId);
canvasState.deselectAll();

// Drag operations
canvasState.startDrag();
canvasState.updateDrag(worldDelta, useSmartGuides: true);
canvasState.endDrag();

// Hit testing
final frame = canvasState.hitTestFrame(worldPos);
final node = canvasState.hitTestNode(worldPos, frameId);

// Render access
final scene = canvasState.getExpandedScene(frameId);
final renderDoc = canvasState.getRenderDoc(frameId);
final outline = canvasState.getOutline(frameId, focusNodeIds);
```

## Related Documentation

- [FREE_DESIGN_DSL.md](../../docs/FREE_DESIGN_DSL.md) - Full DSL specification
- [PROPERTY_PANEL_SPEC.md](../../PROPERTY_PANEL_SPEC.md) - Property panel architecture
