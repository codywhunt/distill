# Dreamflow 2.0 Frontend

Next-generation workspace shell for Dreamflow.

## Overview

This is a parallel implementation of the Dreamflow frontend, focused on:

1. **Clean architecture** - Shell-first design with modular components
2. **Instant navigation** - IndexedStack for zero-latency module switching
3. **URL-driven state** - Deep linking and shareable URLs
4. **Command palette** - Raycast-like command interface
5. **Consistent layout** - Left/Center/Right panels with agent always available
6. **Performance-first** - Optimized resize, animation, and rebuild patterns

## Getting Started

```bash
cd distill_editor
fvm flutter pub get
fvm flutter run -d chrome
```

## Architecture

```
lib/
├── main.dart                    # App entry point
├── workspace/                   # Shell infrastructure
│   ├── shell_contract.md        # Design contract (source of truth)
│   ├── workspace_shell.dart     # Main layout widget
│   ├── workspace_state.dart     # Current module, selection context
│   ├── workspace_layout_state.dart  # Panel visibility, widths, persistence
│   ├── workspace_navigation.dart    # Cross-module navigation API
│   └── components/              # Shell components
│       ├── side_navigation.dart
│       ├── breadcrumb_bar.dart
│       ├── panel_container.dart
│       ├── resizable_panel.dart       # Optimized drag resize
│       └── animated_panel_wrapper.dart # GPU-accelerated show/hide
├── routing/
│   └── router.dart              # GoRouter configuration + shortcuts
├── commands/                    # Command palette
│   ├── command.dart             # Command model
│   ├── command_registry.dart    # Central registry
│   ├── command_palette_state.dart
│   └── command_palette_overlay.dart
└── modules/                     # Feature modules
    ├── module_registry.dart     # Maps modules to panels
    ├── canvas/
    ├── library/
    ├── code/
    ├── theme/
    ├── backend/
    ├── source_control/
    └── settings/
```

## Shell Contract

See `lib/workspace/shell_contract.md` for the complete design contract including:

- Module definitions and navigation
- URL structure
- Panel layout rules
- Command palette behavior
- State persistence strategy
- Agent context

## Development Principles

### 1. Performance-First Architecture

The shell uses several optimizations that **must be maintained**:

| Pattern | Purpose | Location |
|---------|---------|----------|
| `ResizablePanel` | Local drag state prevents provider spam | `components/resizable_panel.dart` |
| `AnimatedPanelWrapper` | GPU-accelerated `SizeTransition` for show/hide | `components/animated_panel_wrapper.dart` |
| `Selector` with state objects | Minimal rebuilds (not `context.watch`) | `workspace_shell.dart` |
| `RepaintBoundary` | Isolates panel repaints | Wraps each panel |
| `isContextSwitch` flag | Disables animation during module switches | `workspace_layout_state.dart` |

**Rule:** Never use `AnimatedContainer` for panel resize/show operations. It causes animation interference.

### 2. State Notification Rules

```dart
// ❌ BAD: Notify on every drag frame
void onDragUpdate(delta) {
  _width += delta;
  notifyListeners();  // Causes rebuild storm
}

// ✅ GOOD: Local state during drag, notify once at end
void onDragUpdate(delta) {
  setState(() => _localWidth += delta);  // Local only
}
void onDragEnd() {
  provider.setWidth(_localWidth);  // Single notification
}
```

### 3. Selector Usage

```dart
// ❌ BAD: Rebuilds on ANY layout state change
final layout = context.watch<WorkspaceLayoutState>();

// ✅ GOOD: Rebuilds only when specific values change
return Selector<WorkspaceLayoutState, _PanelState>(
  selector: (_, l) => _PanelState(
    isVisible: l.isLeftPanelVisible(module),
    width: l.leftPanelWidth,
    isContextSwitch: l.isContextSwitch,
  ),
  builder: (context, state, _) => ...,
);
```

### 4. Module Guidelines

When implementing a new module:

1. **Keep panel widgets stateless where possible** - Let providers manage state
2. **Use `const` constructors** - Helps Flutter skip rebuilds
3. **Register commands in `command_registry.dart`** - Not inside module widgets
4. **Update `SelectionContext`** - Keep agent aware of current selection
5. **Use `PanelContainer` with correct `borderSide`** - Left panels get `.right`, right panels get `.left`

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `/` | Open command palette |
| `Cmd+K` / `Ctrl+K` | Open command palette |
| `Cmd+1..7` | Switch to module 1-7 |
| `Option+[` | Toggle left panel |
| `Option+]` | Toggle right panel |
| `Escape` | Close overlay / deselect |

## Development Milestones

### ✅ Shell v1 (Current)

- [x] Side nav with module icons
- [x] Left/Center/Right panel containers
- [x] Animated panel show/hide (SizeTransition)
- [x] Resizable panels with optimized drag handles
- [x] Breadcrumb bar with module context
- [x] Command palette (opens via ⌘K or /)
- [x] URL routing per module
- [x] Instant module switching (IndexedStack)
- [x] Keyboard shortcuts (⌘1-7 for modules, ⌥[/] for panels)
- [x] All modules stubbed
- [x] Performance optimizations (local drag state, Selector, RepaintBoundary)
- [x] Context switch animation suppression

### 🔲 Next: Canvas Module

- [ ] Port widget tree from existing frontend
- [ ] Port canvas/device frame
- [ ] Port properties panel
- [ ] Connect to existing backend (hologram_client)

### 🔲 Later

- [ ] Port remaining modules one by one
- [ ] Integration with existing auth/project loading
- [ ] Module eviction for memory management
