# Components v2: Target Architecture & Roadmap

> The path from "components exist" to "components are actually useful"

**Status**: Planning
**Related**: [v1 Implementation Reference](./components-instances-slots.md)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Target End-State](#target-end-state)
3. [Current State Assessment](#current-state-assessment)
4. [Key Architectural Decisions](#key-architectural-decisions)
   - [Decision 1: Component Node Storage](#decision-1-component-node-storage)
   - [Decision 2: Stable Node Identity](#decision-2-stable-node-identity-for-bindings)
   - [Decision 3: Parameters as Real Model](#decision-3-parameters-as-real-model)
   - [Decision 4: Slot Content Ownership](#decision-4-slot-content-ownership)
   - [Decision 5: Cycle Detection](#decision-5-cycle-detection)
   - [Decision 6: Variant Selection Model](#decision-6-variant-selection-model)
5. [Data Model Changes](#data-model-changes)
6. [Expansion Resolution Order](#expansion-resolution-order)
7. [Implementation Phases](#implementation-phases)
8. [Testing Strategy](#testing-strategy)
9. [Definition of Done](#definition-of-done)

---

## Executive Summary

The v1 component system provides a solid foundation: instances expand correctly, overrides apply, and the rendering pipeline is clean. However, components aren't yet *useful* for real design work because:

- **Slots don't inject content** - They render as placeholders only
- **Components aren't editable on canvas** - They're data blobs, not visual surfaces
- **Overrides are brittle** - Keyed to internal component structure
- **No variants** - Can't represent size/state variations
- **No designer-facing parameters** - Overrides are low-level, not typed controls

This document defines the target architecture and a phased implementation plan to reach "components that actually work."

---

## Target End-State

### Canvas Model
- **Frames**: Regular design surfaces
- **Component Canvases**: Components edited visually like frames
- **Component Sets**: Variants grouped by axes (size, state, etc.)

### Authoring Capabilities
- Create component from selection
- Open/edit component on canvas
- Create variants and manage axes
- Add slots in components
- Place instances in frames or other components

### Instance UX
When you select an instance, the property panel shows:
- **Variant selection** (if part of a set)
- **Parameters** (typed controls with defaults, override indicators, reset)
- **Slot controls** (inject/replace/reset content)
- "Go to main component" action

### Engine Invariants
- `EditorDocument` is the single source of truth
- `ExpandedScene` is always derived (never persisted)
- No corruption: stable identities, no cycles, robust to component changes

---

## Current State Assessment

### What We Have (Strong Foundation)

| Feature | Status | Notes |
|---------|--------|-------|
| `NodeType.instance` with `componentId` + `overrides` | ✅ | Works |
| `NodeType.slot` with `slotName` | ✅ | Data model exists |
| Scene expansion with namespacing | ✅ | `inst1::btn_root` pattern |
| Override application (props/style/layout) | ✅ | Applied during expansion |
| Instance child editing blocked | ✅ | `patchTargetId = null` |
| Rendering pipeline | ✅ | Clean flow to widgets |
| UI protection (layer tree + prop panel) | ✅ | Shows badges, blocks editing |

### What's Missing (Core Gaps)

| Gap | Impact | Priority |
|-----|--------|----------|
| **Slot content injection** | Components can't accept custom content | P0 |
| **Component-as-canvas** | Can't visually edit components | P1 |
| **Stable node identity** | Overrides break when component changes | P0 |
| **Parameters model** | Prop panel is hacky, no typed controls | P1 |
| **Variants model** | No size/state variations | P2 |
| **Cycle detection** | Nested instances could infinite-loop | P0 |

---

## Key Architectural Decisions

### Decision 1: Component Node Storage

**Problem**: Component nodes currently live in global `doc.nodes`. Two components could both have a node called `btn_root`, causing collisions.

**Decision**: **Source-namespace component nodes**

Component nodes are stored with their component ID prefix:
```
comp_button::btn_root
comp_button::btn_label
comp_card::card_root
comp_card::card_header
```

**Rationale**:
- Prevents ID collisions without a separate store
- Makes ownership explicit and queryable
- Enables "find all nodes for component X" trivially
- Smaller migration than moving to `component.nodes`

**Naming helper**:
```dart
/// Generate a namespaced ID for a component node.
String componentNodeId(String componentId, String localName) {
  return '$componentId::$localName';
}

/// Extract the local name from a namespaced ID.
String? localNameFromId(String id) {
  final parts = id.split('::');
  return parts.length == 2 ? parts[1] : null;
}
```

**Validation rule**: If `sourceComponentId != null`, the node's `id` must start with `"$sourceComponentId::"`. This is enforced at node creation time to prevent half-migrated graphs.

**Future path**: If this becomes unwieldy, we can migrate to `component.nodes` later.

---

### Decision 2: Stable Node Identity for Bindings

**Problem**: Overrides are keyed by node ID (`btn_label`). If someone restructures the component, all instance overrides break silently.

**Decision**: **Add template `uid` for component nodes, keep `id` stable**

**Critical invariant**: `Node.id` is the stable document identity used everywhere (childIds, patchTarget, selection, etc.). It **never changes**. `Node.name` is the user-facing display label that can be renamed freely.

```dart
class Node {
  final String id;           // STABLE document identity (never changes)
  final String name;         // Display label (can be renamed)
  final String? templateUid; // Template identity for param bindings (component nodes only)
  // ...
}
```

**Role clarification**:
- `id` = stable key in `doc.nodes`, referenced by `childIds`, `rootNodeId`, etc. Source-namespaced for component nodes (`comp_button::btn_root`).
- `name` = what the user sees in the layer tree, can be changed without breaking anything.
- `templateUid` = semantic identity within a component template, used by parameter bindings so they survive internal restructuring (e.g., if you rebuild the component tree but want bindings to reconnect). Only set for nodes within components.

**Why both namespaced `id` AND `templateUid`?**
- Namespaced `id` prevents collisions across components.
- `templateUid` allows bindings to survive if you delete and recreate nodes within the same component (rare, but prevents silent breakage).

**Migration**: Existing component nodes get `templateUid = localPartOfId` (the part after `::`).

**Non-component nodes**: `templateUid = null` (not needed since they're not binding targets).

---

### Decision 3: Parameters as Real Model

**Problem**: Current `exposedProps` is disconnected. Overrides use raw node IDs and field paths.

**Decision**: **Real parameter definitions with constrained v1 bindings**

```dart
class ComponentParamDef {
  final String key;              // "label", "iconName"
  final ParamType type;          // string, bool, color, number, enum
  final dynamic defaultValue;
  final String? group;           // "Content", "Style"
  final ParamBinding binding;    // Single binding in v1
}

class ParamBinding {
  final String targetTemplateUid;  // References Node.templateUid
  final OverrideBucket bucket;     // props | style | layout
  final ParamField field;          // Structured enum, not arbitrary string
}

enum ParamField {
  // Props fields
  text,
  icon,
  imageSrc,

  // Style fields
  fillColor,
  opacity,
  cornerRadius,

  // Layout fields
  width,
  height,
  padding,
}
```

**v1 constraints**:
- Single binding per parameter (most common case)
- `ParamField` is a structured enum, not arbitrary JSON paths
- Can expand to multi-binding and paths in v2

---

### Decision 4: Slot Content Ownership

**Problem**: Where does slot-injected content live? Who owns it?

**Decision**: **Slot content is instance-owned, stored in document nodes, single root in v1**

```dart
class InstanceProps extends NodeProps {
  final String componentId;
  final Map<String, dynamic> paramOverrides;  // Keyed by param key
  final Map<String, SlotAssignment> slots;    // Keyed by slot name
}

class SlotAssignment {
  final String? rootNodeId;  // Single root node in v1 (null = use default or empty)
}
```

**v1 constraint: single root per slot**

Injecting multiple roots into a slot creates ambiguity (siblings? implicit wrapper? what layout?). For v1, each slot accepts exactly one root node. If you need multiple elements, wrap them in a container first.

Future expansion: `List<String> rootNodeIds` with explicit `SlotLayoutMode` (column, row, stack).

**Ownership backlink**:
```dart
class Node {
  // ...
  final String? ownerInstanceId;  // For slot content nodes only
}
```

This enables:
- Querying "what slot content does this instance own?"
- Garbage collection when instance is deleted
- Validation that slot content isn't orphaned

**Slot expansion behavior**:

When a slot is **filled**, the slot node does not appear in `ExpandedScene`. Instead, the slot's parent `childIds` references the injected root directly. The slot is a "placeholder location," not a real layer in the expanded tree.

When a slot is **empty** (no assignment, no default), the slot node can appear as a visual placeholder or be omitted entirely (implementation choice).

**Key behaviors**:
- Slot content nodes live in `doc.nodes` (not inside the component)
- They have `ownerInstanceId` pointing back to their owning instance
- Deleting an instance cleans up all nodes where `ownerInstanceId == instanceId`
- Slot content IS editable (`patchTargetId = contentNodeId`)
- Component-owned children remain non-editable

**Layer tree display**:
- Instance shows as collapsed (component children hidden)
- Slot content shows as children of the instance (editable)

**Validation invariants**:
- If a node has `ownerInstanceId != null`, all its descendants must have the same `ownerInstanceId`
- Slot assignment root must have `ownerInstanceId` set at creation time
- No mixed-ownership subtrees allowed (enforced by node creation helpers)

---

### Decision 5: Cycle Detection

**Decision**: **Path-based cycle detection during expansion**

The check is **path-scoped**, not global. A component using the same child component twice (e.g., two Icon instances) is valid. A component containing itself (directly or transitively) is a cycle.

```dart
String? _expandInstance({
  required Node instanceNode,
  required Set<String> ancestorComponentIds,  // Components in current expansion path
  // ...
}) {
  final componentId = props.componentId;

  // Cycle = re-entering a component that's already an ancestor in this path
  if (ancestorComponentIds.contains(componentId)) {
    return _createCyclePlaceholder(instanceNode, namespace, nodes, patchTarget);
  }

  // Add to path for recursive expansion
  final newAncestors = {...ancestorComponentIds, componentId};
  // Pass newAncestors to _expandComponentTree and nested _expandInstance calls
}
```

**Valid**: `Card` contains two `Button` instances (same component, different paths).
**Invalid**: `Card` → `Header` → `Card` (cycle detected on second `Card`).

**Behavior**: Cycles render as error placeholders with visual indicator, not infinite loops.

---

### Decision 6: Variant Selection Model

**Problem**: With variants, how does an instance know which variant to use?

**Options**:
1. **Direct**: Instance stores a specific `componentId` pointing to a variant
2. **Axis-based**: Instance stores `setId` + axis selections, resolved at expansion time

**Decision**: **Direct reference in v1**

```dart
class InstanceProps extends NodeProps {
  final String componentId;  // Points directly to a specific variant
  // ...
}
```

**Rationale**:
- Simpler implementation
- No runtime resolution logic
- Swapping variants = changing `componentId`
- Works for 90% of use cases

**Variant switching behavior**:
- UI shows variant switcher when component is part of a set
- Switching updates `componentId` to the new variant's ID
- Param overrides are preserved if the new variant has a param with the same key
- Overrides for params that don't exist on the new variant are dropped (no error)

**v1 param compatibility rule**: Preserve override if param key exists on new component. Application is binding-driven: if the preserved override doesn't bind cleanly (e.g., the param now targets a different `templateUid` or field), it's ignored at application time rather than causing an error.

**Future expansion**: Axis-based selection for "smart matching" (e.g., swap only size, keep state).

---

## Data Model Changes

### Node (updated)

```dart
class Node {
  final String id;                      // STABLE document key (namespaced for component nodes)
  final String name;                    // Display label (user can rename)
  final String? templateUid;            // NEW: stable identity for param bindings (component nodes only)
  final String? sourceComponentId;      // NEW: which component owns this node (null for frame nodes)
  final String? ownerInstanceId;        // NEW: for slot content nodes only
  final NodeType type;
  final List<String> childIds;
  final NodeLayout layout;
  final NodeStyle style;
  final NodeProps props;
}
```

**Field purposes**:
- `id`: Stable key, never changes. Namespaced for component nodes (`comp_button::btn_root`).
- `name`: User-facing label shown in layer tree. Can be renamed freely.
- `templateUid`: Semantic identity for parameter bindings. Survives internal component restructuring.
- `sourceComponentId`: Which component owns this node (`null` for regular frame nodes).
- `ownerInstanceId`: Which instance owns this slot content (`null` for most nodes).

### ComponentDef (updated)

```dart
class ComponentDef {
  final String id;
  final String name;
  final String? description;
  final String rootNodeId;              // Now prefixed: "comp_button::btn_root"
  final List<ComponentParamDef> params; // NEW: replaces exposedProps
  final String? setId;                  // NEW: variant set membership
  final Map<String, String> axisValues; // NEW: {"size": "md", "state": "default"}
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### ComponentParamDef (new)

```dart
class ComponentParamDef {
  final String key;
  final ParamType type;
  final dynamic defaultValue;
  final String? group;
  final ParamBinding binding;
}

enum ParamType {
  string,
  number,
  boolean,
  color,
  enumValue,  // With options list
}

class ParamBinding {
  final String targetTemplateUid;  // References Node.templateUid
  final OverrideBucket bucket;
  final ParamField field;
}

enum OverrideBucket { props, style, layout }

enum ParamField {
  // Props
  text, icon, imageSrc,
  // Style
  fillColor, strokeColor, opacity, cornerRadius,
  // Layout
  width, height, paddingAll, paddingHorizontal, paddingVertical, gap,
}
```

### InstanceProps (updated)

```dart
class InstanceProps extends NodeProps {
  final String componentId;                   // Direct reference to variant (see Decision 6)
  final Map<String, dynamic> paramOverrides;  // Keyed by param key
  final Map<String, SlotAssignment> slots;    // Slot assignments
}

class SlotAssignment {
  final String? rootNodeId;  // Single root in v1 (null = empty/default)
}
```

### SlotProps (unchanged)

```dart
class SlotProps extends NodeProps {
  final String slotName;
  final String? defaultContentId;  // Component-owned default content
}
```

### ComponentSet (new)

```dart
class ComponentSet {
  final String id;
  final String name;
  final List<VariantAxis> axes;
  final List<String> variantComponentIds;
}

class VariantAxis {
  final String key;           // "size", "state"
  final List<String> values;  // ["sm", "md", "lg"]
}
```

### ExpandedNode (updated)

```dart
class ExpandedNode {
  final String id;
  final String? patchTargetId;
  final NodeType type;
  final List<String> childIds;
  final NodeLayout layout;
  final NodeStyle style;
  final NodeProps props;
  Rect? bounds;

  // NEW: Origin metadata
  final ExpandedNodeOrigin? origin;
}

class ExpandedNodeOrigin {
  final OriginKind kind;              // NEW: enables trivial UI decisions
  final String? componentId;
  final String? componentTemplateUid; // Renamed from componentNodeUid
  final List<String> instancePath;    // For nested instances
  final bool isOverridden;
  final SlotOrigin? slotOrigin;       // If this came from slot injection
}

/// Categorizes where an expanded node came from.
/// Makes UI logic trivial (tree rendering, prop panel, context menus).
enum OriginKind {
  /// Regular node in a frame (not from component)
  frameNode,

  /// The instance node itself (the root that references a component)
  instanceRoot,

  /// A node inside a component (not directly editable)
  componentChild,

  /// Content injected into a slot (editable, owned by instance)
  slotContent,

  /// Error placeholder (cycle detected, missing component, etc.)
  errorPlaceholder,
}

class SlotOrigin {
  final String slotName;
  final String instanceId;
}
```

**OriginKind usage examples**:
- Layer tree: `componentChild` → show with badge, disable drag
- Property panel: `componentChild` → show "Edit Main Component" instead of controls
- Context menu: `slotContent` → show "Clear Slot" option
- Selection: `errorPlaceholder` → show error styling

### Frame (updated)

```dart
class Frame {
  final String id;
  final String name;
  final String rootNodeId;
  final CanvasPlacement canvas;
  final FrameKind kind;           // NEW: design | component
  final String? componentId;      // NEW: for component frames
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum FrameKind { design, component }
```

### EditorDocument (updated)

```dart
class EditorDocument {
  final String irVersion;
  final String documentId;
  final Map<String, Frame> frames;
  final Map<String, Node> nodes;
  final Map<String, ComponentDef> components;
  final Map<String, ComponentSet> componentSets;  // NEW
  final ThemeDocument theme;
}
```

---

## Expansion Resolution Order

When building an `ExpandedScene` from an `EditorDocument`, the builder follows this resolution order:

1. **Expand frame nodes** — Walk the frame's node tree, creating `ExpandedNode` entries
2. **Detect instance nodes** — When encountering `NodeType.instance`, begin component expansion
3. **Check for cycles** — Verify `componentId` not in `ancestorComponentIds`; create error placeholder if cycle detected
4. **Expand component tree** — Recursively expand the component's node tree with namespacing (`instanceId::nodeId`)
5. **Apply parameters** — Resolve param bindings: use `defaultValue` unless `paramOverrides[key]` exists
6. **Resolve slots** — For each slot node: replace with injected content if `SlotAssignment.rootNodeId` exists, else use `defaultContentId`, else keep slot placeholder
7. **Assign origin metadata** — Set `OriginKind`, `instancePath`, `isOverridden`, `slotOrigin` for each expanded node
8. **Set patch targets** — `patchTargetId = nodeId` for frame nodes and slot content; `null` for component children

This order ensures that overrides and slot content are applied after the base component tree is established, and that origin metadata accurately reflects the final resolved state.

---

## Implementation Phases

### Phase 0: Foundation Hardening

**Goal**: Prevent corruption and enable future features without breaking changes.

| Task | Description | Files |
|------|-------------|-------|
| Add path-based cycle detection | Track ancestor components, create error placeholder on cycle | `expanded_scene_builder.dart` |
| Add `ExpandedNodeOrigin` with `OriginKind` | Track componentId, templateUid, instancePath, isOverridden, kind | `expanded_scene.dart` |
| Add `templateUid` to Node | Stable identity for param bindings (component nodes only) | `node.dart` |
| Add `sourceComponentId` to Node | Track which component owns a node | `node.dart` |
| Add `ownerInstanceId` to Node | Track slot content ownership | `node.dart` |
| Clarify `id` vs `name` semantics | `id` is stable key (never changes); `name` is display label (already exists) | `node.dart`, docs |
| Source-namespace component nodes | Store as `comp_button::btn_root` | `component_def.dart`, `mock_frames.dart` |
| Add `componentNodeId` helper | Consistent namespaced ID generation with validation | new utils or `node.dart` |
| Update existing tests | Fix any tests broken by model changes | various test files |

**Exit criteria**: See [Phase 0 Test Gate](#phase-0-test-gate-foundation-hardening)

---

### Phase 1: Slots That Work

**Goal**: Make components actually useful by enabling content injection.

| Task | Description | Files |
|------|-------------|-------|
| Add `SlotAssignment` model | Single root node ID | `node_props.dart` |
| Add `slots` to `InstanceProps` | Map<slotName, SlotAssignment> | `node_props.dart` |
| Expand slot with injected content | Replace slot node with content nodes | `expanded_scene_builder.dart` |
| Make slot content editable | `patchTargetId = contentNodeId` | `expanded_scene_builder.dart` |
| Handle default slot content | If no assignment, use `defaultContentId` | `expanded_scene_builder.dart` |
| Slot UI in property panel | Show slots, add/clear content buttons | `content_section.dart` |
| Show slot content in layer tree | Render as editable children of instance | `widget_tree_panel.dart` |
| Slot content lifecycle | Delete content nodes when instance deleted | `editor_document.dart` |

**Exit criteria**: See [Phase 1 Test Gate](#phase-1-test-gate-slots-that-work)

---

### Phase 1.5: Minimal Component Navigation

**Goal**: Basic component canvas UX before full library panel.

| Task | Description | Files |
|------|-------------|-------|
| Add `FrameKind` enum | `design` vs `component` | `frame.dart` |
| Add `componentId` to Frame | Link component frames to ComponentDef | `frame.dart` |
| "Go to main component" action | Context menu on instance → navigate to component frame | `node_tree_item.dart`, navigation |
| Create component frame on component creation | Auto-create editable canvas for component | component creation flow |

**Exit criteria**: See [Phase 1.5 Test Gate](#phase-15-test-gate-component-navigation)

---

### Phase 2: Parameters

**Goal**: Clean, typed property controls for instances.

**Why before Library?** A component library without parameters means users can insert components but can't customize them meaningfully. Parameters make instances actually useful.

| Task | Description | Files |
|------|-------------|-------|
| Add `ComponentParamDef` model | Key, type, default, binding | new `component_param.dart` |
| Add `ParamBinding` model | targetTemplateUid, bucket, field | new `component_param.dart` |
| Add `params` to ComponentDef | Replace `exposedProps` | `component_def.dart` |
| Add `paramOverrides` to InstanceProps | Keyed by param key | `node_props.dart` |
| Apply params during expansion | Resolve bindings → node field values | `expanded_scene_builder.dart` |
| Parameter section in prop panel | Grouped, typed controls | `content_section.dart` |
| Override indicators | Visual badge when param differs from default | prop panel |
| Reset param action | Reset single param or all params | prop panel |

**Exit criteria**: See [Phase 2 Test Gate](#phase-2-test-gate-parameters)

---

### Phase 3: Component Library Panel

**Goal**: Browse and instantiate components visually.

| Task | Description | Files |
|------|-------------|-------|
| Component Library panel widget | List all components with thumbnails | new `component_library_panel.dart` |
| Drag-to-instantiate | Drag component from library → create instance on canvas | drag handlers |
| "Create component from selection" | Extract selected nodes into new component | command handler |
| Component search/filter | Filter by name, set | library panel |
| Show component sets grouped | Visual grouping by variant set | library panel |

**Exit criteria**: See [Phase 3 Test Gate](#phase-3-test-gate-component-library)

---

### Phase 4: Variants

**Goal**: Support component variations (size, state, etc.)

| Task | Description | Files |
|------|-------------|-------|
| Add `ComponentSet` model | Axes + variant component IDs | new `component_set.dart` |
| Add `VariantAxis` model | Key + values | new `component_set.dart` |
| Add variant membership to ComponentDef | `setId` + `axisValues` | `component_def.dart` |
| Add `componentSets` to EditorDocument | Map<setId, ComponentSet> | `editor_document.dart` |
| Variant switcher in prop panel | Dropdown/chips to swap variants | prop panel |
| "Create variant" action | Duplicate component with different axis values | command handler |
| "Create variant set" action | Group existing components into set | command handler |
| Variant grid view in library | Show variants in grid by axes | library panel |

**Exit criteria**: See [Phase 4 Test Gate](#phase-4-test-gate-variants)

---

### Phase 5: Polish & Advanced (Future)

| Feature | Description |
|---------|-------------|
| "Edit instance children" | Optional direct editing with automatic override creation |
| "Push override to main" | Promote instance override to component default |
| "Detach instance" | Convert instance to regular nodes |
| Multi-binding params | One param affects multiple node fields |
| Arbitrary field paths | Beyond enum, support `style.fill.color` paths |
| Team/shared libraries | Components shared across projects |

---

## Definition of Done

We've reached the target end-state when:

- [ ] **Components are edited like frames on canvas**
  - Component canvases exist and are navigable
  - "Go to main component" works from any instance

- [ ] **Variant sets exist and instances can swap variants**
  - ComponentSet model implemented
  - Variant switcher in property panel
  - Library shows variants grouped

- [ ] **Instances expose clean, typed parameters**
  - ComponentParamDef with real bindings
  - Property panel shows params with types, defaults, reset
  - Override indicators show what's customized

- [ ] **Slots work and injected content is editable**
  - Slot assignments stored on instance
  - Injected content renders in place of slot
  - Injected content appears in layer tree and is editable
  - Default content works when no assignment

- [ ] **Components can nest safely**
  - Cycle detection prevents infinite expansion
  - Updates to components propagate to all instances
  - Stable identities prevent override breakage

---

## Testing Strategy

Each phase has a **test gate**: all tests must pass before proceeding to the next phase. Tests are organized by test file location and include both unit tests and integration tests.

### Test File Organization

```
test/free_design/
├── models/
│   ├── node_test.dart                    # Node model tests
│   ├── component_def_test.dart           # ComponentDef tests
│   ├── component_param_test.dart         # ComponentParamDef tests (Phase 2)
│   └── component_set_test.dart           # ComponentSet tests (Phase 4)
├── scene/
│   ├── expanded_scene_test.dart          # ExpandedScene/ExpandedNode tests
│   └── expanded_scene_builder_test.dart  # Scene expansion tests
└── integration/
    ├── component_cycle_test.dart         # Cycle detection integration
    ├── slot_injection_test.dart          # Slot content injection
    ├── parameter_binding_test.dart       # Parameter override flow
    └── variant_switching_test.dart       # Variant swap behavior
```

---

### Phase 0 Test Gate: Foundation Hardening

**Must pass before starting Phase 1.**

#### Unit Tests: `expanded_scene_builder_test.dart`

```dart
group('Cycle Detection', () {
  test('direct self-reference creates error placeholder', () {
    // Component A contains instance of Component A
    // → Should create placeholder, not infinite loop
  });

  test('indirect cycle creates error placeholder', () {
    // Component A → Component B → Component A
    // → Second A should be placeholder
  });

  test('same component used twice is NOT a cycle', () {
    // Card contains two Button instances
    // → Both should expand normally
  });

  test('deeply nested same component works', () {
    // A → B → Icon, A → C → Icon
    // → Both Icons expand, no cycle
  });
});

group('Origin Metadata', () {
  test('frameNode origin for regular nodes', () {
    // Node in frame (not component) → OriginKind.frameNode
  });

  test('instanceRoot origin for instance nodes', () {
    // Instance node itself → OriginKind.instanceRoot
  });

  test('componentChild origin for expanded component nodes', () {
    // Nodes expanded from component → OriginKind.componentChild
  });

  test('errorPlaceholder origin for cycle/missing', () {
    // Cycle or missing component → OriginKind.errorPlaceholder
  });

  test('instancePath tracks nesting depth', () {
    // A → B → C → node
    // → instancePath = ['instA', 'instB', 'instC']
  });
});
```

#### Unit Tests: `node_test.dart`

```dart
group('Node Identity', () {
  test('id is stable document key', () {
    // id never changes, used in childIds/rootNodeId
  });

  test('name is display label, can change', () {
    // name update doesn't affect id or references
  });

  test('templateUid set for component nodes', () {
    // Component node has templateUid
  });

  test('templateUid null for frame nodes', () {
    // Regular frame node has null templateUid
  });

  test('sourceComponentId tracks ownership', () {
    // comp_button::btn_root has sourceComponentId = comp_button
  });
});

group('Source Namespacing', () {
  test('component nodes have namespaced ids', () {
    // btn_root → comp_button::btn_root
  });

  test('two components can have same local name', () {
    // comp_button::label and comp_card::label don't collide
  });

  test('childIds use namespaced form', () {
    // comp_button::btn_root.childIds = ['comp_button::btn_label']
  });
});
```

#### Integration Test: `component_cycle_test.dart`

```dart
test('full expansion with cycle doesn\'t hang', () {
  // Create document with cyclic component reference
  // Build expanded scene
  // Verify completes in < 100ms
  // Verify placeholder present
});

test('error placeholder renders visually', () {
  // Expand scene with cycle
  // Render to widget tree
  // Verify error indicator visible
});
```

#### Unit Tests: `node_test.dart` (namespacing validation)

```dart
group('Component Node Namespacing', () {
  test('componentNodeId generates correct format', () {
    // componentNodeId('comp_button', 'btn_root') == 'comp_button::btn_root'
  });

  test('node with sourceComponentId requires namespaced id', () {
    // Creating node with sourceComponentId but non-namespaced id → throws
  });

  test('node with sourceComponentId validates prefix matches', () {
    // sourceComponentId = 'comp_button', id = 'comp_card::foo' → throws
  });

  test('localNameFromId extracts correctly', () {
    // localNameFromId('comp_button::btn_root') == 'btn_root'
    // localNameFromId('not_namespaced') == null
  });
});
```

---

### Phase 1 Test Gate: Slots That Work

**Must pass before starting Phase 1.5.**

#### Unit Tests: `expanded_scene_builder_test.dart`

```dart
group('Slot Expansion', () {
  test('slot with no assignment renders as placeholder', () {
    // Component has slot, instance has no assignment
    // → Slot node present in expanded scene
  });

  test('slot with assignment renders injected content', () {
    // Instance has SlotAssignment with rootNodeId
    // → Injected content replaces slot in childIds
  });

  test('slot with defaultContentId uses default when empty', () {
    // Slot has defaultContentId, instance has no assignment
    // → Default content renders
  });

  test('injected content is editable (patchTargetId set)', () {
    // Slot content node has patchTargetId = its own id
    // → NOT null like component children
  });

  test('component children still not editable', () {
    // Non-slot nodes inside component
    // → patchTargetId = null
  });

  test('slot content has slotContent origin kind', () {
    // Injected node → OriginKind.slotContent
  });

  test('slot content has correct slotOrigin', () {
    // SlotOrigin.slotName and SlotOrigin.instanceId set
  });
});
```

#### Unit Tests: `node_test.dart`

```dart
group('Slot Content Ownership', () {
  test('slot content node has ownerInstanceId', () {
    // Content node points back to instance
  });

  test('non-slot nodes have null ownerInstanceId', () {
    // Regular nodes don't have owner
  });
});
```

#### Integration Test: `slot_injection_test.dart`

```dart
test('delete instance cleans up slot content', () {
  // Create instance with slot content
  // Delete instance
  // Verify slot content nodes removed from doc.nodes
});

test('slot content editable in property panel', () {
  // Select slot content node
  // Verify property panel shows editable controls
});

test('slot content shows in layer tree as instance child', () {
  // Expand instance in layer tree
  // Verify slot content visible and editable
});
```

---

### Phase 1.5 Test Gate: Component Navigation

**Must pass before starting Phase 2.**

#### Unit Tests: `frame_test.dart`

```dart
group('Frame Kind', () {
  test('design frame has FrameKind.design', () {});
  test('component frame has FrameKind.component', () {});
  test('component frame has componentId set', () {});
});
```

#### Integration Tests

```dart
test('"Go to main component" navigates to component frame', () {
  // Select instance
  // Trigger "Go to main component"
  // Verify navigation to component frame
});

test('creating component creates component frame', () {
  // Create component from selection
  // Verify component frame created
  // Verify frame.componentId matches component.id
});
```

---

### Phase 2 Test Gate: Parameters

**Must pass before starting Phase 3.**

#### Unit Tests: `component_param_test.dart`

```dart
group('ComponentParamDef', () {
  test('param has key, type, defaultValue, binding', () {});
  test('ParamBinding references templateUid', () {});
  test('ParamField enum covers expected fields', () {});
  test('JSON serialization round-trips', () {});
});
```

#### Unit Tests: `expanded_scene_builder_test.dart`

```dart
group('Parameter Application', () {
  test('param with no override uses default', () {
    // Component has param with defaultValue
    // Instance has no override
    // → Expanded node has default value
  });

  test('param override applied to correct node', () {
    // Instance has paramOverrides[key] = value
    // → Target node has overridden value
  });

  test('param binding resolves by templateUid', () {
    // Binding targets templateUid, not id
    // → Correct node receives override
  });

  test('unknown param key ignored gracefully', () {
    // Instance has override for nonexistent param
    // → No error, just ignored
  });

  test('isOverridden set correctly in origin', () {
    // Node with param override → origin.isOverridden = true
  });
});
```

#### Integration Test: `parameter_binding_test.dart`

```dart
test('property panel shows param controls', () {
  // Select instance
  // Verify param controls rendered with correct types
});

test('param override shows indicator', () {
  // Set param override
  // Verify visual indicator in property panel
});

test('reset param reverts to default', () {
  // Override param
  // Reset param
  // Verify value matches default
});

test('param change updates expanded scene', () {
  // Change param value
  // Verify expanded scene updated
  // Verify render reflects change
});
```

---

### Phase 3 Test Gate: Component Library

**Must pass before starting Phase 4.**

#### Integration Tests

```dart
test('library panel lists all components', () {
  // Create multiple components
  // Verify all appear in library panel
});

test('drag from library creates instance', () {
  // Drag component from library to canvas
  // Verify instance created with correct componentId
});

test('create component from selection works', () {
  // Select nodes
  // Create component
  // Verify component created
  // Verify selection replaced with instance
});

test('search filters components', () {
  // Create components with different names
  // Search by name
  // Verify filtering works
});
```

---

### Phase 4 Test Gate: Variants

**Must pass before Phase 5 (future).**

#### Unit Tests: `component_set_test.dart`

```dart
group('ComponentSet', () {
  test('set has axes and variant list', () {});
  test('variant has setId and axisValues', () {});
  test('JSON serialization round-trips', () {});
});
```

#### Integration Test: `variant_switching_test.dart`

```dart
test('swap variant updates componentId', () {
  // Instance pointing to variant A
  // Switch to variant B
  // Verify componentId changed
});

test('swap variant preserves compatible params', () {
  // Instance has param overrides
  // Switch to variant with same params
  // Verify overrides preserved
});

test('swap variant drops incompatible params', () {
  // Instance has param override
  // Switch to variant without that param
  // Verify override removed (not error)
});

test('variant switcher shows in property panel', () {
  // Select instance of component in a set
  // Verify variant selector UI visible
});

test('library shows variants grouped', () {
  // Create component set
  // Verify library groups variants visually
});
```

---

### Running Tests

Use the JSON reporter for concise output:

```bash
# Run all component tests
flutter test test/free_design/ --reporter json 2>&1 | jq -s '{
  total: [.[] | select(.type == "testDone")] | length,
  passed: [.[] | select(.type == "testDone" and .result == "success")] | length,
  failed: [.[] | select(.type == "testDone" and .result == "failure")] | length
}'

# Run specific phase tests
flutter test test/free_design/scene/expanded_scene_builder_test.dart --reporter json 2>&1 | jq -s '.[-1].success'
```

### Gate Criteria

A phase gate is **passed** when:
1. All unit tests for that phase pass
2. All integration tests for that phase pass
3. No regressions in previous phase tests
4. Manual smoke test confirms expected UX behavior

**Do not proceed to the next phase until the gate is passed.**

---

*Document created: January 2026*
*Last updated: January 2026*
