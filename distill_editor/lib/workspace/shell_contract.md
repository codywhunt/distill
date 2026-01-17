# Dreamflow 2.0 Shell Contract

> This document defines the UI-level contract for the workspace shell.  
> It is the source of truth for navigation, layout, and cross-module behavior.

---

## 1. Modules & Navigation

| Module         | Icon | Path             | Shortcut | Description                          |
|----------------|------|------------------|----------|--------------------------------------|
| Canvas         | 🎨   | `/canvas`        | ⌘1       | Visual editing of components/pages   |
| App Preview    | ▶️   | `/preview`       | ⌘2       | Live preview of full running app     |
| Library        | 📚   | `/library`       | ⌘3       | Browse and manage project content    |
| Code           | 💻   | `/code`          | ⌘4       | Full IDE experience                  |
| Theme          | 🎭   | `/theme`         | ⌘5       | Design tokens and theming            |
| Backend        | ⚡   | `/backend`       | ⌘6       | Backend provider configuration       |
| Source Control | 🔀   | `/source`        | ⌘7       | Git operations and history           |
| Settings       | ⚙️   | `/settings`      | ⌘8       | Project configuration                |

**Switching behavior:**
- Instant. No loading spinners on module switch.
- State is preserved when switching away and back.
- Modules are lazily initialized on first visit.
- Animations are disabled during module switches (isContextSwitch flag).
- Lifecycle callbacks fired on module enter/exit.

---

## 2. URL Structure

```
/project/:projectId/:module?param1=value1&param2=value2
```

### What goes in the URL

| Scope          | Serialized To     | Examples                                    |
|----------------|-------------------|---------------------------------------------|
| Project        | Path              | `/project/abc123/...`                       |
| Module         | Path              | `.../canvas`, `.../library`                 |
| Primary selection | Query params   | `?doc=Button`, `?file=lib/main.dart`        |
| Secondary context | Query params   | `?tab=pages`, `?line=42`                    |

### What does NOT go in the URL

- Panel widths / visibility (→ localStorage)
- Scroll positions (→ memory)
- Expanded tree nodes (→ memory)
- Transient UI state (→ memory)

---

## 3. Panel Layout

```
┌──────┬─────────────┬──────────────────────────────────┬─────────────┐
│ Side │   Left      │          Center                  │    Right    │
│ Nav  │   Panel     │          Content                 │    Panel    │
│      │             │  ┌──────────────────────────┐    │             │
│  🎨  │  (varies    │  │     Breadcrumb Bar       │    │  (varies    │
│  📚  │   per       │  ├──────────────────────────┤    │   per       │
│  💻  │   module)   │  │                          │    │   module)   │
│  🎭  │             │  │     Module Content       │    │             │
│  ⚡  │             │  │                          │    │     +       │
│  🔀  │             │  │                          │    │             │
│  ⚙️  │             │  │                          │    │   Agent     │
│      │             │  │                          │    │   (always)  │
│      │             │  └──────────────────────────┘    │             │
└──────┴─────────────┴──────────────────────────────────┴─────────────┘
```

### Panel Configuration by Module

| Module         | Left Panel                        | Center Content              | Right Panel              |
|----------------|-----------------------------------|-----------------------------|--------------------------|
| Canvas         | Widget tree, view config          | Infinite canvas + device    | Properties + Agent       |
| App Preview    | Widget tree, navigation           | Device frame + running app  | Properties + Agent       |
| Library        | Content listing (pages, etc.)     | Grid/storyboard view        | Details + Agent          |
| Code           | File tree                         | Tabs + editor               | Properties + Agent       |
| Theme          | Token categories                  | Token editor                | Preview + Agent          |
| Backend        | Config sections                   | Config editor               | Agent                    |
| Source Control | Branches, changes, actions        | Diff/conflict view          | Agent                    |
| Settings       | Category list                     | Category form               | Agent                    |

### Panel Rules

- **Side Nav**: Always visible. Fixed width (~56px).
- **Left Panel**: Collapsible. Resizable. Width persisted. Border on RIGHT edge.
- **Center Content**: Expands to fill. Always visible.
- **Right Panel**: Collapsible. Resizable. Width persisted. Border on LEFT edge.
- **Agent**: Always available in right panel region.

---

## 4. Command Palette

### Triggers
- `/` key (when not focused in a text input)
- `Cmd+K` / `Ctrl+K`
- Click on breadcrumb bar

### Behavior
- Opens instantly, pre-hydrated with commands
- Shows: Global commands + Current module commands
- Fuzzy search on label + keywords
- Keyboard navigable (↑↓ + Enter)

### Command Scopes
- `global`: Available everywhere (e.g., "Switch to Canvas", "Open Settings")
- `canvas`: Only in Canvas module
- `library`: Only in Library module
- etc.

---

## 5. State Persistence

### Workspace-level (lives above modules)

| State                  | Storage         | Survives          |
|------------------------|-----------------|-------------------|
| Current project ID     | URL path        | Always            |
| Current module         | URL path        | Always            |
| Panel widths           | localStorage    | Session + refresh |
| Panel visibility       | localStorage    | Session + refresh |

### Module-level (scoped to each module)

| State                  | Storage         | Survives          |
|------------------------|-----------------|-------------------|
| Primary selection      | URL query       | Refresh + share   |
| Full module state      | Memory          | Module switches   |
| (Evictable if needed)  |                 |                   |

### Design rule

Modules must store meaningful state in a state object (not widget fields) so that:
1. State survives widget rebuilds
2. Future eviction is possible without rewrite

---

## 6. Agent Context

At any moment, the agent knows:

| Context            | Source                           |
|--------------------|----------------------------------|
| Current module     | WorkspaceState                   |
| Current selection  | Module's SelectionContext        |
| Active document    | Module-specific (file, page, etc)|
| Recent actions     | Command history (last N)         |

### SelectionContext interface

```dart
abstract class SelectionContext {
  ModuleType get module;
  String? get documentId;    // Page, component, file, etc.
  String? get widgetId;      // Selected widget if applicable
  Map<String, dynamic> toAgentContext();
}
```

Each module provides its own SelectionContext implementation.

---

## 7. Cross-Module Navigation

Modules can request navigation to other modules via `WorkspaceNavigation`:

```dart
// Open a document in Canvas
navigation.openInCanvas(documentId: 'Button');

// Open a file in Code editor
navigation.openFile(path: 'lib/main.dart', line: 42);

// Show usages in Library
navigation.showUsagesInLibrary(documentId: 'Button');
```

This keeps modules decoupled while enabling cross-module workflows.

---

## 8. Keyboard Shortcuts

### Global (always active)

| Shortcut       | Action                    |
|----------------|---------------------------|
| `/`            | Open command palette      |
| `Cmd+K`        | Open command palette      |
| `Cmd+1`        | Go to Canvas              |
| `Cmd+2`        | Go to App Preview         |
| `Cmd+3`        | Go to Library             |
| `Cmd+4`        | Go to Code                |
| `Cmd+5`        | Go to Theme               |
| `Cmd+6`        | Go to Backend             |
| `Cmd+7`        | Go to Source Control      |
| `Cmd+8`        | Go to Settings            |
| `Option+[`     | Toggle left panel         |
| `Option+]`     | Toggle right panel        |
| `Escape`       | Close overlay / deselect  |

### Module-specific

Defined by each module via command registration.

### Implementation

Shortcuts are registered via `HardwareKeyboard.instance.addHandler()` for truly global handling that works regardless of widget focus. The `/` shortcut is suppressed when focus is in a text field.

---

## 9. Performance Patterns

The shell implements specific performance optimizations that must be maintained:

### Local Drag State

`ResizablePanel` uses local state during drag operations to avoid provider notification storms:

```dart
// During drag: local state only
setState(() => _dragWidth = newWidth);

// At drag end: single provider notification
widget.onResize(_dragWidth!);
```

### GPU-Accelerated Animation

`AnimatedPanelWrapper` uses `SizeTransition` (GPU-composited) instead of `AnimatedContainer`:

```dart
SizeTransition(
  sizeFactor: _animation,
  axis: Axis.horizontal,
  axisAlignment: axisAlignment,
  child: widget.child,
)
```

### Minimal Rebuilds

`WorkspaceShell` uses `Selector` with immutable state objects instead of `context.watch`:

```dart
Selector<WorkspaceLayoutState, _LeftPanelState>(
  selector: (_, l) => _LeftPanelState(
    isVisible: l.isLeftPanelVisible(module),
    width: l.leftPanelWidth,
    isContextSwitch: l.isContextSwitch,
  ),
  builder: ...,
)
```

### Context Switch Flag

`isContextSwitch` temporarily disables animations when switching modules:

```dart
// In router, when module changes:
_layoutState.beginContextSwitch();
_workspaceState.setCurrentModule(newModule);
WidgetsBinding.instance.addPostFrameCallback((_) {
  _layoutState.endContextSwitch();
});
```

### RepaintBoundary

Each panel is wrapped in `RepaintBoundary` to isolate repaints.

---

## Revision History

| Date       | Change                              |
|------------|-------------------------------------|
| 2026-01-05 | Initial shell contract              |
| 2026-01-05 | Added performance patterns section  |
| 2026-01-05 | Updated shortcuts (Option+[/])      |
