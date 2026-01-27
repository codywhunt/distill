# Free Design Canvas: Features & Design Decisions

This document catalogs all design decisions and features implemented in the Distill free design canvas editor.

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Model Design Decisions](#2-data-model-design-decisions)
3. [Patch Protocol (Mutation System)](#3-patch-protocol-mutation-system)
4. [Canvas Interaction Features](#4-canvas-interaction-features)
5. [Rendering Pipeline](#5-rendering-pipeline)
6. [Layout System](#6-layout-system)
7. [Component System](#7-component-system)
8. [DSL (Domain Specific Language)](#8-dsl-domain-specific-language)
9. [AI Integration](#9-ai-integration)
10. [Property Panel System](#10-property-panel-system)
11. [State Management](#11-state-management)

---

## 1. Architecture Overview

The free design canvas follows a **three-stage compilation pipeline**:

```
Editor IR (Source of Truth)
    │
    ▼
Expanded Scene (Instances flattened, overrides applied)
    │
    ▼
Render Document (Tokens resolved, layout computed)
    │
    ▼
Flutter Widgets
```

### Key Architectural Principles

| Principle | Decision | Rationale |
|-----------|----------|-----------|
| Minimal Node Types | 7 types only | Small vocabulary agents can fully understand |
| Immutable Data | All models use `copyWith()` | Enables undo/redo; predictable state |
| Flat Storage | Nodes in map, not nested trees | O(1) lookups, simple serialization |
| Patch Protocol | Atomic, invertible operations | Collaborative editing; undo/redo |
| Separation of Concerns | IR → Scene → Render | Decouples editing from rendering |

### Module Organization

```
distill_editor/lib/src/free_design/
├── ai/           # LLM-powered generation
├── canvas/       # Canvas interaction (drag, selection)
├── compiler/     # OutlineCompiler for AI context
├── dsl/          # Domain Specific Language
├── layout/       # Layout validation
├── models/       # Editor IR data structures
├── patch/        # Atomic operations
├── projection/   # Projection service
├── properties/   # Property panel
├── render/       # Render pipeline
├── scene/        # Instance expansion
└── store/        # State management
```

---

## 2. Data Model Design Decisions

### EditorDocument

The root document is the **single source of truth**:

```dart
class EditorDocument {
  final String irVersion;
  final String documentId;
  final Map<String, Frame> frames;      // All frames (keyed by ID)
  final Map<String, Node> nodes;        // All nodes (flat, keyed by ID)
  final Map<String, ComponentDef> components;  // Reusable components
  final ThemeDocument theme;            // Design tokens
}
```

**Design Decision: Flat Storage**
- Nodes stored in a document-wide map, not nested inside parent nodes
- Parent-child relationships via `childIds` list and runtime parent index
- Enables O(1) node lookups and simple serialization

### Node

The fundamental building block:

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

**Design Decision: Immutability**
- All modifications create new instances via `copyWith()`
- Proper `==` operator and `hashCode` for value equality
- Enables efficient change detection and undo/redo

### Node Types (7 Total)

| Type | Description | Use Case |
|------|-------------|----------|
| `container` | Box with optional children and auto-layout | Layout containers, buttons, cards |
| `text` | Text content with styling | Labels, paragraphs, headings |
| `image` | Image asset reference | Photos, illustrations |
| `icon` | Icon from an icon set | UI icons |
| `spacer` | Flexible space (Expanded in Flutter) | Layout spacing |
| `instance` | Component instance - references ComponentDef | Reusable UI elements |
| `slot` | Content placeholder within component | Component customization |

**Design Decision: Minimal Type Set**
- Only 7 node types provides a small vocabulary that AI agents can fully understand
- Complex UIs are composed from these primitives
- Reduces edge cases and simplifies the codebase

### Frame

A top-level container on the canvas (like a Figma frame/artboard):

```dart
class Frame {
  final String id;
  final String name;
  final String rootNodeId;      // Root node of the frame's tree
  final CanvasPlacement canvas; // Position and size on infinite canvas
  final FrameKind kind;         // design | component
}
```

---

## 3. Patch Protocol (Mutation System)

All document mutations go through **patch operations** - atomic, invertible changes that enable undo/redo and collaborative editing.

### Patch Operation Types

```dart
sealed class PatchOp {
  // Property operations
  SetProp(id, path, value)          // Set node property by JSON Pointer
  SetFrameProp(frameId, path, value) // Set frame property

  // Node structure operations
  InsertNode(node)                   // Add node to document
  AttachChild(parentId, childId, index)  // Add child to parent
  DetachChild(parentId, childId)     // Remove child from parent
  DeleteNode(id)                     // Remove node from document
  MoveNode(id, newParentId, index)   // Reparent node
  ReplaceNode(id, node)              // Replace entire node

  // Frame operations
  InsertFrame(frame)
  RemoveFrame(frameId)

  // Component operations
  InsertComponent(component)
  RemoveComponent(componentId)
}
```

### Usage Example

```dart
// Property change via JSON Pointer path
store.applyPatch(SetProp(
  id: 'n_button',
  path: '/style/fill',
  value: {'type': 'solid', 'color': '#007AFF'},
));

// Structural change: add child
store.applyPatches([
  InsertNode(newNode),
  AttachChild(parentId: 'n_root', childId: newNode.id),
]);
```

**Design Decision: JSON Pointer Paths**
- Properties addressed by JSON Pointer paths (e.g., `/style/fill`, `/layout/position/x`)
- Enables fine-grained property updates without replacing entire objects
- Compatible with JSON Patch standard

**Design Decision: Separate Insert/Attach**
- `InsertNode` adds to document map but doesn't attach to tree
- `AttachChild` connects node to parent
- Separation enables flexible ordering and atomic operations

---

## 4. Canvas Interaction Features

The canvas is split into two packages:
- **distill_canvas**: Pure viewport + gesture surface (reusable)
- **free_design/canvas**: Editor-specific interactions

### Viewport Architecture

The canvas is a **pure viewport + gesture surface**. It handles:
- Camera/viewport math (pan, zoom, transform matrix)
- Gesture recognition and routing
- Layered rendering surfaces
- World-coordinate event reporting

It does NOT handle:
- Object/node data models
- Selection state
- Hit testing logic
- Domain-specific rendering

### Layer System

Four layers rendered bottom to top:

| Layer | Space | Purpose |
|-------|-------|---------|
| Background | World | Grid, dots, canvas texture |
| Content | World | Nodes, shapes, objects |
| Overlay | Screen | Selection UI, tooltips, HUD |
| Debug | Screen | Optional debugging overlay |

### Pan and Zoom

```dart
// Viewport state
controller.zoom   // Scale factor (1.0 = 100%)
controller.pan    // Offset where world origin appears in view

// Coordinate conversion
controller.viewToWorld(screenPoint)  // Screen → canvas
controller.worldToView(canvasPoint)  // Canvas → screen
```

**Features:**
- Spacebar + drag pan (Figma-style)
- Middle mouse button pan
- Scroll wheel zoom with focal point
- Trackpad pinch-to-zoom
- Momentum/inertia with configurable friction
- Bounded panning (optional)
- Animated transitions (`animateTo`, `animateToFit`)

### Selection

- Single and multi-select for frames and nodes
- Marquee (rectangle) selection
- Click-through to nested nodes
- Selection state managed separately from document

### Drag Operations

Three drag session types:

| Type | Trigger | Behavior |
|------|---------|----------|
| Move | Drag selected | Translate position in world space |
| Resize | Drag handle | Scale from anchor point |
| Marquee | Drag on canvas | Multi-select via rectangle |

### Hit Testing

**Design Decision: Spatial Indexing**
- QuadTree provides O(log n) hit testing
- Essential for performance with many objects
- Separate from rendering/selection concerns

```dart
// O(log n) queries
spatialIndex.hitTest(worldPoint)  // Objects at point
spatialIndex.query(viewportRect)  // Objects in region (culling)
```

### Snapping

Figma-style alignment guides:

| Snap Type | Behavior |
|-----------|----------|
| Edge | Align left/right/top/bottom edges |
| Center | Align center points |
| Grid | Fallback to grid alignment |

**Priority:** Object snap > Grid snap

```dart
final result = snapEngine.calculate(
  movingBounds: bounds,
  otherBounds: nearbyObjects,
  zoom: controller.zoom,
);
// result.snappedBounds - adjusted position
// result.guides - visual guide lines to render
```

### LOD (Level of Detail) Switching

Motion state tracking enables performance optimization:

```dart
controller.isPanning    // User is dragging to pan
controller.isZooming    // User is zooming
controller.isAnimating  // Programmatic animation
controller.isInMotion   // Any of the above
```

Use to simplify rendering during interaction:
- Hide text labels during pan/zoom
- Use placeholder rectangles instead of complex widgets
- Skip expensive shadows/effects

### Background Patterns

Two built-in patterns with adaptive LOD:

| Pattern | Description |
|---------|-------------|
| `GridBackground` | Line grid, spacing doubles when zoomed out |
| `DotBackground` | Figma-style dots, adapts to zoom level |

---

## 5. Rendering Pipeline

The render pipeline converts Editor IR to Flutter widgets through three stages:

### Stage 1: Expanded Scene

`ExpandedSceneBuilder` flattens component instances:
- Resolves `instance` nodes to their component definitions
- Applies instance overrides to component nodes
- Generates namespaced IDs for expanded nodes

### Stage 2: Render Compilation

`RenderCompiler` produces a `RenderDocument`:
- Resolves design tokens via `TokenResolver`
- Computes layout properties
- Produces render-ready data structures

### Stage 3: Widget Rendering

`RenderEngine` outputs Flutter widgets:
- Maps render nodes to Flutter widget trees
- Handles layout (Row, Column, Stack)
- Applies styles (colors, borders, shadows)

```dart
// Full pipeline
final scene = ExpandedSceneBuilder.build(document);
final renderDoc = RenderCompiler.compile(scene, tokenResolver);
final widget = RenderEngine.render(renderDoc, frameId);
```

---

## 6. Layout System

### Auto-Layout (Flexbox-like)

Containers support auto-layout similar to Figma:

| Property | Values | Flutter Equivalent |
|----------|--------|-------------------|
| Direction | `row`, `column` | `Row`, `Column` |
| Gap | Number (pixels) | `SizedBox` between children |
| Padding | 1, 2, or 4 values | `EdgeInsets` |
| Main Alignment | `start`, `center`, `end`, `spaceBetween`, `spaceAround`, `spaceEvenly` | `MainAxisAlignment` |
| Cross Alignment | `start`, `center`, `end`, `stretch` | `CrossAxisAlignment` |

### Size Modes

| Mode | DSL Syntax | Behavior |
|------|------------|----------|
| Fixed | `w 120` | Exact pixel size |
| Hug | `w hug` | Fit to content (intrinsic) |
| Fill | `w fill` | Expand to fill parent (`Expanded`) |

### Position Modes

| Mode | Behavior |
|------|----------|
| Auto | Participates in parent's auto-layout |
| Absolute | Fixed position relative to parent (`Positioned`) |

---

## 7. Component System

### ComponentDef

Reusable component definitions:

```dart
class ComponentDef {
  final String id;
  final String name;
  final String rootNodeId;      // Root of component's node tree
  final String? description;
  final List<ComponentParam> params;  // Configurable parameters
}
```

### Instance Nodes

Instances reference components and can override properties:

```dart
// Node with type: NodeType.instance
final instanceNode = Node(
  id: 'button_instance',
  type: NodeType.instance,
  props: InstanceProps(
    componentId: 'comp_button',
    overrides: {
      'label': {'text': 'Submit'},  // Override text content
      'style': {'fill': '#007AFF'}, // Override style
    },
  ),
);
```

### Slot Nodes

Placeholders within components for content injection:

```dart
// In component definition
final slot = Node(
  id: 'content_slot',
  type: NodeType.slot,
  props: SlotProps(
    slotKey: 'content',
    defaultChildIds: ['default_placeholder'],
  ),
);
```

**Design Decision: Override Addressing**
- Overrides target nodes by ID within the component
- Enables customization without copying the entire tree

---

## 8. DSL (Domain Specific Language)

A compact text format optimized for LLM token efficiency (~75% reduction vs JSON).

### Syntax Example

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

| Feature | Syntax | Example |
|---------|--------|---------|
| Indentation hierarchy | 2-space indent | Children nested under parent |
| Explicit IDs | `#id` suffix | `column#n_root` |
| Property separator | `-` | `text "Hello" - size 24` |
| Shorthand properties | See table below | `w`, `h`, `bg`, `r` |

### Property Shorthands

| Shorthand | Full Name | Example |
|-----------|-----------|---------|
| `w` | width | `w 120`, `w fill`, `w hug` |
| `h` | height | `h 40`, `h fill` |
| `gap` | gap | `gap 16` |
| `pad` | padding | `pad 24`, `pad 12,24` |
| `bg` | background | `bg #FFF`, `bg primary` |
| `r` | radius | `r 8`, `r 8,4,4,8` |
| `size` | fontSize | `size 16` |
| `weight` | fontWeight | `weight 600` |
| `color` | textColor | `color #000` |

### Parser/Exporter

```dart
// Parse DSL text to IR
final result = DslParser.parse(dslText);
final frame = result.frame;
final nodes = result.nodes;

// Export IR to DSL text
final dslText = DslExporter.export(document, frameId);
```

---

## 9. AI Integration

### Frame Generator

LLM-powered UI generation from natural language:

```dart
final generator = FrameGenerator(client);

// Generate new frame
final result = await generator.generate(
  prompt: 'A login form with email, password, and submit button',
  document: store.document,
  position: Offset(100, 100),
  size: Size(375, 812),
);

// Update existing frame
final result = await generator.update(
  prompt: 'Make the button blue and add a forgot password link',
  frame: existingFrame,
  nodes: frameNodes,
  targetNodeIds: ['n_button'],  // Focus on specific nodes
);
```

### Supported Providers

| Client | Provider |
|--------|----------|
| `AnthropicClient` | Claude (Anthropic) |
| `GeminiClient` | Gemini (Google) |
| `OpenAIClient` | GPT-4 (OpenAI) |
| `MockClient` | Testing/development |

### Outline Compiler

Generates context for AI prompts:

```dart
// Get AI-friendly context for a frame
final outline = OutlineCompiler.compile(
  document: document,
  frameId: frameId,
  focusNodeIds: selectedNodeIds,
);
```

**Design Decision: DSL for AI**
- Text-based DSL reduces token usage by ~75% compared to JSON
- Indentation-based syntax is natural for LLMs
- Shorthands minimize verbose property names

---

## 10. Property Panel System

### Editor Types

| Editor | Purpose |
|--------|---------|
| `NumberEditor` | Numeric values with optional min/max |
| `TextEditor` | Text content |
| `BooleanEditor` | Segmented true/false control |
| `DropdownEditor` | Select from options |
| `ToggleEditor` | Icon-based toggle buttons |
| `DirectionEditor` | Row/column direction toggle |
| `PaddingEditor` | Mode cycling (all/symmetric/individual) |
| `BorderRadiusEditor` | Mode cycling (all/individual corners) |
| `StrokeEditor` | Border width, color, alignment |
| `ShadowEditor` | Drop shadow properties |
| `ColorPickerMenu` | Visual color selection + hex input |

### Section Organization

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

### Performance Features

| Feature | Purpose |
|---------|---------|
| `DebounceMixin` | Reduces store updates during typing (~80% reduction) |
| `HoverStateMixin` | Standardized hover state management |
| Batch Updates | `store.updateNodeProps()` for composite editors |
| Value Equality | Proper `==` on value objects prevents unnecessary rebuilds |

---

## 11. State Management

### Three-Layer Architecture

| Layer | Class | Responsibility |
|-------|-------|----------------|
| Workspace | `WorkspaceState` | Cross-module state, routing, selection context |
| Canvas | `CanvasState` | Selection, drag sessions, hit testing, caching |
| Document | `EditorDocumentStore` | Document state, patch application, undo/redo |

### EditorDocumentStore

```dart
final store = EditorDocumentStore.empty();

// Apply patches
store.applyPatch(InsertNode(node));
store.applyPatches([...], groupId: 'drag-123', label: 'Move nodes');

// Query helpers
store.getParent(nodeId);
store.getAncestors(nodeId);
store.getDescendants(nodeId);
store.getFrameForNode(nodeId);

// Undo/redo
store.undo();
store.redo();
store.hasUnsavedChanges;
```

### Undo/Redo

**Features:**
- Atomic groups: Multiple patches coalesce into single undo entry
- Coalescing: Edits within 2 seconds with same `groupId` merge
- Inverse computation: `PatchInverter` computes reverse operations before applying
- Max history: 100 entries per stack
- Save tracking: `hasUnsavedChanges` tracks undo depth at last save

### CanvasState (Orchestrator)

~1700 lines managing all canvas interactions:

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
```

### Caching Strategy

```dart
// Cached data in CanvasState
final Map<String, ExpandedScene> _expandedScenes = {};
final Map<String, RenderDocument> _renderCache = {};
final Map<String, Map<String, Rect>> _nodeBoundsCache = {};
final Map<String, String> _outlineCache = {};
```

**Invalidation:**
- Document changes tracked via `SceneChangeSet`
- Three levels of dirty tracking: `frameDirty`, `compilationDirty`, `geometryDirty`
- Component changes invalidate all frames using those components

---

## Summary

The Distill free design canvas implements a Figma-like editing experience with:

- **7 node types** providing a minimal but complete vocabulary
- **Immutable data models** enabling predictable state and undo/redo
- **Patch protocol** for atomic, invertible mutations
- **Three-stage render pipeline** separating editing from rendering
- **Pure viewport abstraction** making the canvas reusable
- **DSL format** optimized for AI token efficiency
- **Multi-provider AI integration** for UI generation

The architecture prioritizes simplicity and AI-friendliness while maintaining the flexibility needed for a professional design tool.
