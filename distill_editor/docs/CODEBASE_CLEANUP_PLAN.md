# Codebase Cleanup Plan

## Overview

This document outlines a comprehensive plan to clean up the Distill codebase, remove legacy code, improve organization, and establish better practices for maintainability.

**Goal**: A clean, well-organized codebase that is intuitive to navigate and maintain.

---

## Current State Assessment

### Repository Structure
```
distill/
├── distill_canvas/        # Infinite canvas library (mature, well-documented)
├── distill_ds/            # Design system v2 (components, tokens, styles)
├── distill_editor/        # Main application (mixed quality)
└── docs/                  # Root-level docs
```

### Issues Identified

| Category | Count | Severity | Description |
|----------|-------|----------|-------------|
| Dead code | 3 files | High | Unused property sections superseded by v2 |
| Stub modules | 6 files | Medium | Empty placeholder modules |
| Mock/demo files in prod | 3 files | Medium | Should be in test/example |
| System files | 5 files | Low | .DS_Store files in git |
| Test coverage gaps | ~90% | High | Modules and distill_ds largely untested |
| Circular dependencies | 1 area | Medium | modules ↔ free_design |
| Duplicated code | 2 instances | Low | FrameLabel in two places |
| TODOs in code | 9 items | Medium | Unaddressed implementation gaps |

---

## Cleanup Phases

### Phase 1: Immediate Cleanup (Low Risk, High Impact)

**Goal**: Remove obvious dead code and system files with zero functional impact.

#### 1.1 Delete Unused Property Sections

These files have been fully replaced by `layout_section_v2.dart`:

```bash
# Files to delete
rm lib/src/free_design/properties/sections/layout_section.dart
rm lib/src/free_design/properties/sections/position_section.dart
rm lib/src/free_design/properties/sections/auto_layout_section.dart
```

**Verification**:
```bash
# Confirm no imports exist
grep -r "layout_section.dart" --include="*.dart" lib/
grep -r "position_section.dart" --include="*.dart" lib/
grep -r "auto_layout_section.dart" --include="*.dart" lib/
```

**Impact**: ~19KB dead code removed

#### 1.2 Remove System Files from Git

```bash
# Add to .gitignore
echo ".DS_Store" >> .gitignore
echo "**/.DS_Store" >> .gitignore

# Remove from git (but keep locally)
git rm --cached distill_canvas/lib/src/.DS_Store
git rm --cached distill_ds/assets/.DS_Store
git rm --cached distill_ds/lib/.DS_Store
git rm --cached distill_ds/lib/components/.DS_Store
git rm --cached distill_ds/example/.DS_Store
```

#### 1.3 Relocate Mock/Demo Files

Move demo data out of production code:

```bash
# Create test fixtures directory
mkdir -p test/fixtures/demo_data

# Move mock frames (large demo dataset)
mv lib/modules/canvas/mock_frames.dart test/fixtures/demo_data/

# Update imports in affected files
# lib/modules/canvas/canvas_state.dart references mock_frames.dart
```

**Alternative**: Keep mock_frames.dart but rename to clearly indicate purpose:
```bash
mv lib/modules/canvas/mock_frames.dart lib/modules/canvas/_demo_fixtures.dart
```

Add comment at top:
```dart
/// Demo fixtures for development and testing.
/// This file should not be used in production builds.
/// TODO: Move to test/fixtures when demo mode is properly separated.
```

---

### Phase 2: Module Organization (Medium Risk)

**Goal**: Establish clear boundaries and remove circular dependencies.

#### 2.1 Resolve Circular Dependency

**Current Issue**:
- `modules/canvas/canvas_state.dart` imports from `src/free_design/`
- `src/free_design/canvas/*` imports from `modules/canvas/canvas_state.dart`

**Solution**: Extract shared types to a common location.

```
BEFORE:
modules/canvas/canvas_state.dart ←→ src/free_design/canvas/...

AFTER:
src/free_design/
├── state/
│   ├── canvas_state.dart        # Move here (source of truth)
│   ├── selection_state.dart     # Extract selection logic
│   └── focus_state.dart         # Extract focus logic
├── canvas/
│   └── ... (imports from state/)
└── ...

modules/canvas/
├── views/
│   └── canvas_view.dart         # UI only, imports from state/
└── widgets/
    └── ...                      # UI widgets only
```

**Implementation Steps**:

1. Create `src/free_design/state/` directory
2. Move `CanvasState` to new location
3. Extract `SelectionState` as separate class
4. Update all imports (use find-replace)
5. Verify no circular imports remain

```bash
# Check for circular imports after refactor
dart pub deps --no-dev | grep -E "circular|cycle"
```

#### 2.2 Consolidate Duplicate Code

**FrameLabel duplication**:
- `modules/canvas/widgets/frame_resize_handles.dart` (public)
- `src/free_design/canvas/widgets/selection_overlay.dart` (private `_FrameLabel`)

**Solution**: Create single shared component.

```dart
// lib/src/free_design/canvas/widgets/frame_label.dart

/// Label displayed above frames on the canvas.
/// Shows frame name and provides click/double-click interactions.
class FrameLabel extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onEditStart;

  const FrameLabel({
    super.key,
    required this.name,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onEditStart,
  });

  @override
  Widget build(BuildContext context) {
    // Unified implementation
  }
}
```

---

### Phase 3: Stub Module Resolution (Medium Risk)

**Goal**: Either implement or remove empty placeholder modules.

#### Current Stub Modules

| Module | Purpose | Recommendation |
|--------|---------|----------------|
| `backend/` | API integration | Remove (no near-term use) |
| `code/` | Code preview/export | Keep (roadmap item) |
| `library/` | Component library | Keep (roadmap item) |
| `settings/` | App settings | Keep (needed soon) |
| `source_control/` | Git integration | Remove (no near-term use) |
| `theme/` | Theme editor | Keep (roadmap item) |

#### Implementation

**Option A: Remove unused stubs**
```bash
rm -rf lib/modules/backend/
rm -rf lib/modules/source_control/

# Update module_registry.dart to remove references
```

**Option B: Mark as planned with timeline**

Update each stub with documentation:

```dart
// lib/modules/code/code_module.dart

/// Code Preview Module (Planned)
///
/// Status: Not yet implemented
/// Planned for: Phase 5 (Code Generation Backends)
/// See: docs/DIRECTION.md for roadmap
///
/// This module will provide:
/// - Live code preview for generated Flutter code
/// - Export to file functionality
/// - Syntax highlighting
/// - Copy to clipboard
class CodeModule extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const PanelPlaceholder(
      icon: Icons.code,
      title: 'Code Preview',
      subtitle: 'Coming in Phase 5',
    );
  }
}
```

---

### Phase 4: Test Coverage Improvement (Low Risk, High Value)

**Goal**: Establish baseline test coverage for critical paths.

#### Priority 1: distill_ds Components (0% → 80%)

Currently only `select` has tests. Add tests for:

```
distill_ds/test/components/
├── avatar_test.dart
├── button_test.dart
├── menu_test.dart
├── popover_test.dart
├── segmented_control_test.dart
├── tooltip_test.dart
└── select_test.dart (existing)
```

**Test template for components**:
```dart
void main() {
  group('Button', () {
    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Button(label: 'Click me', onPressed: () {})),
      );
      expect(find.text('Click me'), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(home: Button(label: 'Click', onPressed: () => pressed = true)),
      );
      await tester.tap(find.byType(Button));
      expect(pressed, isTrue);
    });

    testWidgets('respects disabled state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Button(label: 'Disabled', onPressed: null)),
      );
      expect(tester.widget<Button>(find.byType(Button)).onPressed, isNull);
    });
  });
}
```

#### Priority 2: Canvas Module Widgets

```
distill_editor/test/modules/canvas/
├── widgets/
│   ├── widget_tree_panel_test.dart
│   ├── canvas_toolbar_test.dart
│   └── frame_resize_handles_test.dart
├── canvas_state_test.dart
└── views/
    └── canvas_view_test.dart
```

#### Priority 3: Persistence Layer

```
distill_editor/test/free_design/persistence/
├── document_persistence_service_test.dart
├── document_controller_test.dart
└── document_migration_test.dart
```

---

### Phase 5: Code Quality Improvements (Low Risk)

**Goal**: Establish and enforce coding standards.

#### 5.1 Strengthen Linting Rules

Update `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    # Error prevention
    avoid_print: true
    avoid_dynamic_calls: true
    avoid_type_to_string: true
    cancel_subscriptions: true
    close_sinks: true

    # Code style
    prefer_single_quotes: true
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_fields: true
    prefer_final_in_for_each: true
    prefer_final_locals: true

    # Documentation
    public_member_api_docs: false  # Enable later when stable

    # Avoid
    avoid_empty_else: true
    avoid_returning_null_for_void: true
    avoid_unnecessary_containers: true

    # Require
    require_trailing_commas: true
    use_key_in_widget_constructors: true

analyzer:
  errors:
    missing_required_param: error
    missing_return: error
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
```

#### 5.2 Mark Deprecated Code

Add `@Deprecated` annotations to code scheduled for removal:

```dart
/// @deprecated Use [LayoutSectionV2] instead. Will be removed in v2.0.
@Deprecated('Use LayoutSectionV2 instead')
class LayoutSection extends StatelessWidget {
  // ...
}
```

#### 5.3 Address TODOs

Create tracking issues for each TODO:

| File | Line | TODO | Priority |
|------|------|------|----------|
| `render_compiler.dart` | 403 | Support gradients | High |
| `document_controller.dart` | 29, 51 | Check unsaved changes | Medium |
| `layout_section_v2.dart` | 419 | Add collapsible constraints | Low |
| `side_navigation.dart` | 209, 214 | User auth info | Low |
| `prompt_box_overlay.dart` | 188 | Get canvas center | Medium |
| `free_design_canvas.dart` | 534 | Focused frame tracking | Medium |

---

### Phase 6: Directory Structure Reorganization

**Goal**: Intuitive, scalable project structure.

#### Current Structure Issues

1. Confusing split between `modules/canvas/` and `src/free_design/canvas/`
2. No clear separation between UI and business logic
3. Services scattered across packages

#### Proposed Structure

```
distill_editor/lib/
├── main.dart
├── app.dart
│
├── core/                          # Shared core functionality
│   ├── models/                    # Domain models (Node, Frame, etc.)
│   ├── services/                  # App-wide services
│   └── utils/                     # Utilities and extensions
│
├── features/                      # Feature modules
│   ├── canvas/                    # Canvas editing
│   │   ├── data/                  # Data layer (repositories, sources)
│   │   ├── domain/                # Business logic (use cases)
│   │   ├── presentation/          # UI (widgets, pages, state)
│   │   │   ├── state/             # State management
│   │   │   ├── widgets/           # Reusable widgets
│   │   │   └── pages/             # Full pages/views
│   │   └── canvas_module.dart     # Module entry point
│   │
│   ├── properties/                # Property panel
│   │   ├── presentation/
│   │   │   ├── sections/          # Panel sections
│   │   │   └── editors/           # Property editors
│   │   └── properties_module.dart
│   │
│   ├── ai/                        # AI integration
│   │   ├── data/                  # AI service clients
│   │   ├── domain/                # AI logic (patch generation, etc.)
│   │   └── presentation/          # Prompt box, AI UI
│   │
│   └── persistence/               # Document save/load
│       ├── data/
│       └── domain/
│
├── workspace/                     # Shell/workspace infrastructure
│   ├── layout/                    # Panel layout, resizing
│   ├── navigation/                # Routing, side navigation
│   └── components/                # Shared workspace components
│
└── routing/                       # App routing configuration
```

#### Migration Strategy

1. **Don't migrate all at once** - Do incrementally per feature
2. **Start with new code** - New features use new structure
3. **Migrate on touch** - When modifying old code, migrate that module
4. **Maintain aliases** - Keep old imports working during transition

Example alias during migration:
```dart
// lib/src/free_design/models/node.dart
export 'package:distill_editor/core/models/node.dart';
```

---

## Implementation Schedule

### Immediate (Do Now)
- [ ] Delete 3 unused property section files
- [ ] Add .DS_Store to .gitignore and remove from git
- [ ] Add comments to stub modules indicating status

### Short-term (Next 2 Sprints)
- [ ] Resolve circular dependency between modules and free_design
- [ ] Consolidate FrameLabel implementations
- [ ] Add distill_ds component tests (7 components)
- [ ] Update analysis_options.yaml with stricter rules

### Medium-term (1-2 Months)
- [ ] Add canvas module widget tests
- [ ] Add persistence layer tests
- [ ] Address high-priority TODOs (gradient support)
- [ ] Document architecture decisions

### Long-term (Ongoing)
- [ ] Gradual directory restructure as features are touched
- [ ] Maintain 80%+ test coverage for new code
- [ ] Regular dependency audits

---

## Cleanup Checklist

Use this checklist when performing cleanup:

```markdown
### Pre-Cleanup
- [ ] Create branch for cleanup work
- [ ] Run all tests to establish baseline
- [ ] Document current state

### File Removal
- [ ] Verify no imports exist (grep)
- [ ] Verify no runtime references (search for string usage)
- [ ] Remove file
- [ ] Run tests
- [ ] Commit with clear message

### Code Refactor
- [ ] Write tests for current behavior (if missing)
- [ ] Make refactor changes
- [ ] Update all imports
- [ ] Run tests
- [ ] Run linter
- [ ] Manual smoke test
- [ ] Commit with clear message

### Post-Cleanup
- [ ] Update documentation if needed
- [ ] Create PR with detailed description
- [ ] Request review from maintainer
```

---

## Metrics to Track

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Dead code (lines) | ~1,500 | 0 | Manual audit |
| Test coverage | ~10% | 60% | `flutter test --coverage` |
| Lint warnings | Unknown | 0 | `flutter analyze` |
| TODOs in code | 9 | 0 (tracked) | `grep -r "TODO" lib/` |
| Circular deps | 1 | 0 | `dart pub deps` |
| Files without tests | ~250 | <50 | Audit |

---

## Appendix: File Inventory

### Files to Delete
```
lib/src/free_design/properties/sections/layout_section.dart
lib/src/free_design/properties/sections/position_section.dart
lib/src/free_design/properties/sections/auto_layout_section.dart
```

### Files to Move
```
lib/modules/canvas/mock_frames.dart → test/fixtures/demo_data/
lib/modules/canvas/views/free_design_demo.dart → example/ or test/
lib/src/free_design/ai/clients/mock_client.dart → test/mocks/
```

### Files to Merge
```
modules/canvas/widgets/frame_resize_handles.dart (FrameLabel)
  + src/free_design/canvas/widgets/selection_overlay.dart (_FrameLabel)
  → src/free_design/canvas/widgets/frame_label.dart
```

### System Files to Remove from Git
```
distill_canvas/lib/src/.DS_Store
distill_ds/assets/.DS_Store
distill_ds/lib/.DS_Store
distill_ds/lib/components/.DS_Store
distill_ds/example/.DS_Store
```
