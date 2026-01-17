# Hologram Canvas Architecture Analysis

## Executive Summary

Hologram is evolving from a code-first Flutter IDE to a **design-native development environment** where visual editing is the primary interaction mode and code is a compilation target. This architectural shift—decoupling editing from execution—is the right strategic direction. It enables Figma-like creative velocity while preserving Flutter's runtime fidelity, and creates a foundation for AI-native collaboration at a structural level rather than as an afterthought.

The current POC demonstrates strong architectural instincts: immutable IR, patch-based mutations, clean separation between editing and rendering, and a token-efficient DSL. The foundation is solid. What follows is an assessment of where you are, where the gaps lie, and how to sequence the work to get to the full vision.

---

## Part 1: Assessment of Current State

### What's Working Well

**1. Three-Stage Compilation Pipeline**

```
Editor IR → Expanded Scene → Render Document → Flutter Widgets
```

This is the correct factoring. Each stage has a clear responsibility:
- **Editor IR**: Source of truth for user intent, optimized for editing operations
- **Expanded Scene**: Component instances flattened, overrides applied—ready for layout
- **Render Document**: Tokens resolved, layout computed—ready for rendering

This separation means you can swap rendering backends without touching editing logic, cache aggressively at each stage, and reason about each concern in isolation.

**2. Minimal Node Type Vocabulary**

The 7 node types (`container`, `text`, `image`, `icon`, `spacer`, `instance`, `slot`) are well-chosen. This constraint has compounding benefits:

- **For users**: Small vocabulary means faster learning curve, less cognitive load
- **For agents**: Complete coverage is achievable—no hallucinated node types, deterministic grammar
- **For code generation**: Clear mapping to framework primitives across targets

The types map cleanly to both Figma's mental model and Flutter's widget tree, which reduces translation friction in both directions.

**3. Patch Protocol**

Atomic, invertible operations are exactly right for collaborative editing and undo/redo:

```dart
SetProp(id: 'n_button', path: '/style/fill', value: {...})
MoveNode(id: 'n_button', newParentId: 'n_footer', index: -1)
```

The JSON Pointer paths for property access are a good choice—they're standardized, tooling exists, and they map well to how agents think about targeted mutations.

**4. DSL Design**

The DSL achieves the right balance:

```
column#n_root - gap 24 pad 24 bg #FFFFFF w fill h fill
  text "Welcome Back" - size 24 weight 700 color #000000
```

- Indentation hierarchy is intuitive and unambiguous
- Shorthand properties reduce token count significantly
- Explicit IDs (`#n_root`) enable stable references
- Human-readable while being machine-parseable

The ~75% token reduction vs JSON is significant for always-on AI collaboration.

**5. Component Model**

`ComponentDef` + `instance` + `slot` gives you reusable components with override capability. This is essential for any serious design tool and maps well to both Figma's component model and code-level abstractions (widgets, components, views).

### Gaps and Areas for Development

**1. No Semantic Intent Layer**

The IR describes *what* exists visually but not *why* it exists semantically. A container with certain styling could be:
- A Card
- A Button  
- A ListTile
- A TextField container
- A custom branded component

For human editing, this ambiguity is fine—the visual output is what matters. But for code generation, semantic intent produces dramatically better output. A code generator that knows "this is a button" will emit `ElevatedButton` with proper accessibility, focus handling, and platform conventions. A generator that sees "container with blue fill and text child" will emit a styled `Container` with a `Text`—technically correct but missing platform idioms.

**2. No Interaction Model**

The IR handles static layout beautifully but has no representation of:
- Tap/gesture handlers
- Navigation targets
- State transitions
- Animations
- Conditional visibility

For design-to-code, this is where much of the "last mile" complexity lives. A design without interactions is a mockup; a design with interactions is a prototype that can generate functional code.

**3. Single Viewport Assumption**

`SizeMode` with `fixed/fill/hug` handles single-viewport sizing well, but there's no representation of responsive behavior:
- Breakpoint-conditional layouts
- Platform-specific variations
- Orientation changes

This is fine for MVP—responsive design is genuinely hard to abstract well—but it's a gap for production multi-platform output.

**4. Flutter-Implicit Rendering**

The render pipeline compiles directly to Flutter widgets. The IR itself is fairly abstract, but the rendering stage assumes Flutter. For framework-agnostic output, you'd need to insert a code generation backend between Render Document and output:

```
Current:    Render Document → Flutter Widgets (runtime)
Future:     Render Document → CodeGen Backend → Flutter/SwiftUI/React source files
```

**5. AI Interface is Generation-Only**

The current AI integration focuses on frame generation from prompts. For production use, you'll also need:
- Targeted edits ("make the button blue")
- Structural modifications ("add a header to this screen")  
- Style transfer ("apply our brand tokens to this design")
- Explanation ("why is this laid out this way?")

The patch protocol is the right interface for targeted edits, but agents need a way to emit patches directly rather than always going through DSL regeneration.

---

## Part 2: The AIDL Vision

### What AIDL Would Mean

AIDL (AI Design Language) as a framework-agnostic IR would transform Hologram from a **Flutter IDE with smart editing** to a **design-to-code platform where Flutter is the first target**.

The value propositions:

1. **Multi-platform output**: Same design → Flutter, SwiftUI, Compose, React, web
2. **Token-efficient AI collaboration**: Agents operate on compact structured data
3. **Design system portability**: Move between frameworks without redesigning
4. **Future-proofing**: New frameworks become new backends, not rewrites

### Current IR vs Full AIDL

Your current Editor IR is already ~70% of the way to framework-agnostic:

| Aspect | Current State | AIDL Requirement |
|--------|---------------|------------------|
| Layout model | `hug/fill/fixed` + auto-layout | ✅ Universal |
| Styling | Fills, strokes, radii, shadows | ✅ Universal |
| Typography | Size, weight, color, alignment | ✅ Universal |
| Node types | 7 types | ✅ Universal |
| Components | Instance + slot model | ✅ Universal |
| Tokens | Referenced by name | ✅ Universal |
| Semantic intent | ❌ Not present | Needed |
| Interactions | ❌ Not present | Needed |
| Responsive | ❌ Not present | Nice to have |
| Framework hints | ❌ Not present | Escape hatch |

The core IR is sound. The gaps are additive, not structural.

### Recommended AIDL Extensions

**Semantic Hints (Optional Annotation)**

```
container#n_card - w fill pad 16 bg #FFF r 12 shadow 0,2,8,#0001
  @hint card
  
container#n_submit - h 48 bg #007AFF r 8 align center,center
  @hint button.primary
```

Small vocabulary, optional, informs code generation without polluting core structure:
- `card`, `button`, `button.primary`, `button.secondary`
- `input`, `input.text`, `input.password`, `input.search`  
- `list`, `list.item`, `list.header`, `list.divider`
- `nav.bar`, `nav.tab`, `nav.drawer`, `nav.item`
- `modal`, `dialog`, `sheet`, `toast`
- `form`, `form.field`, `form.label`, `form.error`

~20 semantic types covering common UI patterns.

**Interaction Model (Minimal)**

```
container#n_submit - h 48 bg #007AFF r 8
  @action tap -> navigate('/home')
  @action tap -> callback(onSubmit)
  @action longPress -> callback(onLongPress)
```

Start with just:
- `navigate(route)` — navigation to named route
- `callback(name)` — reference to named handler (code provides implementation)
- `setState(key: value)` — simple state mutation

Anything more complex stays in code. The IR is not a programming language.

**Framework Hints (Sparse Escape Hatch)**

```
column#n_list - gap 0
  @flutter sliver
  @swiftui lazyVStack
```

Per-backend hints that override default code generation. Backends ignore hints they don't understand. Use sparingly—only when inference produces wrong output.

---

## Part 3: Recommended Architecture Evolution

### Phase 1: Solidify Core (Current → 4 weeks)

**Goal**: Production-ready editing experience with current scope

1. **Stabilize patch protocol**
   - Ensure all operations are truly invertible
   - Add patch validation with clear error messages
   - Implement undo/redo stack with proper grouping

2. **Complete property panel**
   - All node types fully editable
   - Batch updates for composite editors
   - Keyboard shortcuts for common operations

3. **Harden canvas interactions**
   - Multi-select with shift-click and marquee
   - Copy/paste within and across frames
   - Smart guides and distribution tools

4. **DSL round-trip fidelity**
   - Parse → Export → Parse produces identical IR
   - Property coverage testing for all node types
   - Error recovery for malformed input

### Phase 2: AI Integration Depth (4-8 weeks)

**Goal**: Agents as genuine collaborators, not just generators

1. **Dual-mode AI interface**
   
   *Generation mode* (existing): Agent emits DSL for new frames or major changes
   
   *Patch mode* (new): Agent emits patches for targeted edits
   
   ```json
   {
     "patches": [
       { "op": "SetProp", "id": "n_button", "path": "/style/fill/color", "value": "#007AFF" },
       { "op": "SetProp", "id": "n_button", "path": "/style/fill/type", "value": "solid" }
     ],
     "explanation": "Changed button to blue as requested"
   }
   ```

2. **Context-aware prompting**
   
   The `OutlineCompiler` is a good start. Extend it to provide:
   - Current selection context
   - Available design tokens
   - Component library summary
   - Recent edit history (for follow-up requests)

3. **Validation and repair pipeline**
   
   AI output is probabilistic. Build robust handling:
   - Schema validation before application
   - Structural repair for common errors (missing IDs, orphaned nodes)
   - User confirmation for ambiguous changes
   - Graceful degradation when repair fails

4. **Streaming generation UX**
   
   For large generations, stream partial results:
   - Show frame outline immediately
   - Populate nodes as they're generated
   - Allow cancellation mid-generation

### Phase 3: Semantic Layer (8-12 weeks)

**Goal**: IR captures design intent, not just visual structure

1. **Add `@hint` annotation support**
   
   DSL syntax:
   ```
   container#n_card - w fill pad 16 bg #FFF r 12
     @hint card
   ```
   
   IR representation:
   ```dart
   class Node {
     // ... existing fields
     final SemanticHint? hint;
   }
   ```

2. **Hint inference engine**
   
   When hints aren't provided, infer from structure:
   - Container with shadow + radius + padding → likely `card`
   - Container with solid fill + centered text child → likely `button`
   - Row with icon + text + spacer + icon → likely `list.item`
   
   Inference is heuristic and overridable.

3. **Design token integration**
   
   Tokens should be first-class, not string references:
   ```dart
   class TokenRef {
     final String path;  // e.g., 'color.primary', 'spacing.md'
     final dynamic resolvedValue;  // computed at render time
   }
   ```
   
   This enables:
   - Token autocomplete in property panel
   - Validation against token schema
   - Theme switching without IR changes

### Phase 4: Interaction Model (12-16 weeks)

**Goal**: Designs become interactive prototypes

1. **Action annotation syntax**
   
   ```
   container#n_submit - h 48 bg #007AFF r 8
     @action tap -> navigate('/home')
   ```

2. **Supported actions (minimal set)**
   
   | Action | Syntax | Code Output |
   |--------|--------|-------------|
   | Navigate | `navigate('/route')` | Navigator.pushNamed / NavigationLink |
   | Callback | `callback(handlerName)` | onTap: widget.handlerName |
   | Set state | `setState(key: value)` | State mutation |
   | Open URL | `openUrl('https://...')` | url_launcher / Link |

3. **Prototype mode in canvas**
   
   Toggle between edit mode and prototype mode:
   - Edit mode: current behavior, click to select
   - Prototype mode: click triggers actions, navigation works

4. **Action editor in property panel**
   
   Visual editor for adding/removing actions without DSL knowledge.

### Phase 5: Code Generation Backends (16-24 weeks)

**Goal**: IR compiles to production code, not just runtime widgets

1. **Abstract code generation interface**
   
   ```dart
   abstract class CodeBackend {
     String get name;  // 'flutter', 'swiftui', 'react'
     CodeOutput generate(RenderDocument doc, CodeGenOptions options);
   }
   ```

2. **Flutter backend (first)**
   
   Generate idiomatic Flutter code:
   - Use semantic hints to pick appropriate widgets
   - Respect framework hints (`@flutter sliver`)
   - Generate widget classes, not just widget trees
   - Include TODO comments for callback stubs

3. **Code preview panel**
   
   Side-by-side view: canvas | generated code
   - Syntax highlighting
   - Copy to clipboard
   - Export to file
   - Diff view for regeneration

4. **Incremental generation**
   
   Don't regenerate entire file on every change:
   - Track which IR changes affect which code regions
   - Surgical updates where possible
   - Full regeneration as fallback

### Phase 6: Multi-Platform (24+ weeks)

**Goal**: Same design → multiple framework outputs

1. **SwiftUI backend**
2. **React/React Native backend**
3. **Compose backend**
4. **Responsive variant system**

This phase is where AIDL fully pays off. The IR work from phases 1-4 enables backends to be relatively mechanical translations.

---

## Part 4: Technical Specifications

### DSL v2 Grammar (with extensions)

```ebnf
document     = "dsl:2" newline frame+
frame        = "frame" name annotations? "-" props newline node*
node         = indent type id? annotations? "-" props newline node*
annotations  = annotation+
annotation   = "@" annotation_type value?

annotation_type = "hint" | "action" | "flutter" | "swiftui" | "react"

(* Hints *)
hint_value   = semantic_type ("." semantic_subtype)?
semantic_type = "card" | "button" | "input" | "list" | "nav" | "modal" | "form"

(* Actions *)
action_value = gesture "->" action_target
gesture      = "tap" | "longPress" | "doubleTap" | "swipe"
action_target = navigate | callback | setState | openUrl
navigate     = "navigate(" route ")"
callback     = "callback(" identifier ")"
setState     = "setState(" key ":" value ")"
openUrl      = "openUrl(" url ")"
```

### Patch Protocol v2

```dart
sealed class PatchOp {
  // Property operations
  SetProp({required String id, required String path, required dynamic value});
  DeleteProp({required String id, required String path});
  
  // Node operations  
  InsertNode({required Node node});
  DeleteNode({required String id});
  ReplaceNode({required String id, required Node node});
  
  // Structure operations
  AttachChild({required String parentId, required String childId, required int index});
  DetachChild({required String parentId, required String childId});
  MoveNode({required String id, required String newParentId, required int index});
  
  // Frame operations
  InsertFrame({required Frame frame});
  DeleteFrame({required String frameId});
  SetFrameProp({required String frameId, required String path, required dynamic value});
  
  // Batch operations
  Batch({required List<PatchOp> ops});  // Atomic multi-op
}
```

### AI Interface Contract

```dart
abstract class AIEditingService {
  /// Generate new frame from natural language
  Future<GenerationResult> generateFrame({
    required String prompt,
    required EditorDocument document,
    required Offset position,
    required Size size,
    GenerationOptions? options,
  });
  
  /// Update existing frame from natural language
  Future<UpdateResult> updateFrame({
    required String prompt,
    required Frame frame,
    required Map<String, Node> nodes,
    List<String>? targetNodeIds,
    UpdateOptions? options,
  });
  
  /// Generate patches for targeted edit
  Future<PatchResult> generatePatches({
    required String prompt,
    required EditorDocument document,
    required List<String> targetNodeIds,
    PatchOptions? options,
  });
  
  /// Explain current structure
  Future<ExplanationResult> explain({
    required EditorDocument document,
    required List<String> targetNodeIds,
    ExplanationOptions? options,
  });
}

class PatchResult {
  final List<PatchOp> patches;
  final String explanation;
  final double confidence;
  final List<String> warnings;
}
```

### Semantic Hint Vocabulary

```dart
enum SemanticType {
  // Containers
  card,
  surface,
  modal,
  sheet,
  dialog,
  toast,
  
  // Interactive
  button,
  iconButton,
  fab,
  input,
  checkbox,
  radio,
  toggle,
  slider,
  
  // Lists
  list,
  listItem,
  listHeader,
  listDivider,
  
  // Navigation
  appBar,
  navBar,
  tabBar,
  tab,
  drawer,
  navItem,
  
  // Forms
  form,
  formField,
  formLabel,
  formError,
  formHelper,
  
  // Content
  avatar,
  badge,
  chip,
  tag,
  
  // Layout
  scaffold,
  safeArea,
}

enum SemanticVariant {
  primary,
  secondary,
  tertiary,
  destructive,
  ghost,
  outline,
}
```

---

## Part 5: Risk Assessment

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| DSL expressiveness ceiling | Medium | High | Early escape-hatch design; clear "eject to code" story |
| AI generation quality variance | High | Medium | Validation pipeline; repair heuristics; confidence thresholds |
| Round-trip fidelity (DSL ↔ IR) | Medium | High | Comprehensive property coverage tests; fuzzing |
| Render preview divergence from runtime | Medium | Medium | Clear UX distinction; "preview vs truth" mental model |
| Code generation idiom quality | High | High | Semantic hints; framework hints; human review step |

### Strategic Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Scope creep toward "full programming language" | High | High | Hard constraints on IR expressiveness; explicit boundaries |
| Framework-agnostic abstraction leaking | Medium | High | Layered hint system; per-backend escapes |
| AI dependency creating UX brittleness | Medium | Medium | Graceful degradation; manual fallbacks; offline operation |
| Competing with Figma on design, IDEs on code | Medium | High | Own the intersection; lean into AI-native collaboration |

---

## Part 6: Success Metrics

### Phase 1-2 (Foundation)
- DSL round-trip fidelity: 100% for supported properties
- Patch operation coverage: All node/frame mutations expressible
- AI generation acceptance rate: >80% without manual repair
- Canvas interaction latency: <16ms for all operations

### Phase 3-4 (Semantic + Interactions)
- Semantic hint coverage: >60% of nodes auto-inferred correctly
- Action model coverage: Navigation + callbacks handle >90% of prototyping needs
- Prototype mode usability: Users can demo flows without leaving canvas

### Phase 5-6 (Code Generation)
- Generated code quality: Passes linting, requires <20% manual cleanup
- Multi-platform parity: Same design produces functionally equivalent output
- Token efficiency: <2000 tokens for typical screen context

---

## Conclusion

The Free Design Canvas POC demonstrates the right architectural instincts. The core IR, patch protocol, and DSL are solid foundations. The path forward is:

1. **Short term**: Stabilize current scope, deepen AI integration with patch-mode editing
2. **Medium term**: Add semantic layer and interaction model to capture design intent
3. **Long term**: Code generation backends to realize the AIDL vision

The key insight—**editing substrate ≠ execution substrate**—is correct and positions Hologram uniquely between pure design tools (Figma) and pure code tools (VS Code). The opportunity is owning that intersection with AI-native collaboration as the differentiator.

The main discipline required is **resisting scope creep**. The IR should not become a programming language. The semantic vocabulary should stay small. The interaction model should stay minimal. Expressiveness comes from the escape hatches to code, not from ever-expanding IR complexity.

Build the narrow thing well, then widen it deliberately.

---

## Part 7: Strategic Decisions

The following decisions have been made and should guide implementation.

### 1. The "Eject to Code" Story

**Decision: One-way export with explicit ownership transfer**

The IR stays clean. When a screen needs something the IR can't express, the user explicitly "ejects" it:

```
Frame "Login" (IR-owned)
  → User clicks "Export to Code"
  → Flutter code generated
  → Frame marked as "code-owned" in project
  → IR version archived (for reference, not editing)
  → Future edits happen in code
```

**Key principle: Don't try to sync.** Bidirectional sync between visual IR and code is a tar pit. Figma Dev Mode doesn't try to parse your codebase back into Figma—it accepts that design and code diverge and provides tools to manage that divergence.

**Ownership modes:**
- **IR-owned screens**: Edit in canvas, generate code on demand
- **Code-owned screens**: Edit in code, preview in App Preview
- Clear UI indicating which mode each screen is in
- One-way migration (IR → code), not bidirectional

**When to eject:**
- Custom painters, complex animations
- Platform-specific behavior
- Business logic beyond simple navigation
- Anything requiring `@flutter` escape hatches repeatedly

### 2. Component Library Strategy

**Component Scope Hierarchy:**

```
Global (Hologram-provided)
  └── Primitives: container, text, image, icon, spacer
  └── Base components: Button, Input, Card (optional starter kit)

Project-level
  └── User-defined components (ComponentDef)
  └── Project theme tokens applied

Instance-level
  └── Overrides on component instances
```

**ComponentDef vs Semantic Hints — Orthogonal concepts:**

| Concept | Purpose | Example |
|---------|---------|---------|
| `ComponentDef` | Reusable structure with slots/overrides (like Figma components) | `PrimaryButton` with slot for label |
| `@hint button` | Code generation guidance (tells backend "emit ElevatedButton") | Any container that should become a button widget |

A user-defined component *can* have a semantic hint:

```
component PrimaryButton
  container#root - h 48 bg {color.primary} r 8
    @hint button.primary
    slot#content
```

But they're orthogonal. You might have:
- ComponentDef with no hint (custom layout pattern, no semantic meaning)
- Hint with no ComponentDef (one-off button that should generate as `ElevatedButton`)
- Both (reusable branded button that generates idiomatically)

**Where components live:**
- MVP: Project-level only, stored in `EditorDocument.components`
- Future: Shared library, importable across projects, versioned, publishable

### 3. Token System Architecture

**Token Schema:**

```yaml
tokens:
  color:
    primary: "#007AFF"
    secondary: "#5856D6"
    background: "#FFFFFF"
    surface: "#F5F5F5"
    text:
      primary: "#000000"
      secondary: "#666666"
      disabled: "#999999"
    error: "#FF3B30"
    success: "#34C759"

  spacing:
    xs: 4
    sm: 8
    md: 16
    lg: 24
    xl: 32
    xxl: 48

  radius:
    sm: 4
    md: 8
    lg: 12
    xl: 16
    full: 9999

  typography:
    display:
      size: 32
      weight: 700
      lineHeight: 1.2
    title:
      size: 24
      weight: 600
      lineHeight: 1.3
    body:
      size: 16
      weight: 400
      lineHeight: 1.5
    caption:
      size: 12
      weight: 400
      lineHeight: 1.4
```

**DSL syntax for token references:**

```
# Good (token reference)
container - bg {color.surface} pad {spacing.md} r {radius.md}

# Bad (raw values)
container - bg #F5F5F5 pad 16 r 8
```

**Token resolution pipeline:**

```
DSL Parse → TokenRef preserved in IR → Render stage resolves to concrete values
```

**AI integration rules:**
1. AI prompts include the token schema
2. Generation should emit token references, not raw values
3. `OutlineCompiler` / `AIContextCompiler` includes available tokens
4. Token filtering for patch mode (only include relevant categories)

**Where tokens live:**
- MVP: Project-level, stored alongside `EditorDocument` or sibling `ThemeDocument`
- Future: Integrate with Hologram's Theme Manager module

### 4. Interaction Model (Future - Phase 4)

**Supported actions (minimal set):**

| Action | Syntax | Code Output |
|--------|--------|-------------|
| Navigate | `navigate('/route')` | `Navigator.pushNamed` / `GoRouter` |
| Callback | `callback(handlerName)` | `onTap: widget.handlerName` |
| Open URL | `openUrl('https://...')` | `url_launcher` |

**Explicitly out of scope:**
- Conditional logic (`if`, `when`, `switch`)
- Loops or list generation
- State management beyond simple `setState`
- Animation definitions
- Form validation logic
- API calls

Complex logic lives in code. The IR names connection points; code provides implementations.

**DSL syntax:**

```
container#n_submit - h 48 bg {color.primary} r 8
  @action tap -> navigate('/home')
  @action tap -> callback(onSubmit)
  @action longPress -> callback(onLongPress)
```

---

## Part 8: Success Metrics (Detailed)

### AI Quality Metrics

**Acceptance Rate Definition:**
- "Accepted" = User applies AI output without modification OR with <3 manual property tweaks
- "Rejected" = User undoes AI output, significantly modifies structure, or re-prompts with correction
- Target: >80% acceptance rate for generation, >90% for patches

**Patch Accuracy Definition:**
- "Accurate" = Patch modifies exactly the intended nodes/properties, no side effects
- "Inaccurate" = Patch affects unintended nodes, misses requested changes, or produces invalid state
- Measured via: Unit tests with prompt→expected patches pairs

**Repair Rate:**
- Track % of AI outputs requiring repair before application
- Acceptable repairs: Missing IDs, orphaned nodes (auto-fixable)
- Unacceptable: Structural corruption, invalid property values
- Target: <10% require repair, <1% unrecoverable

### Eval Harness Structure

```
eval/
├── fixtures/
│   ├── documents/          # Sample EditorDocuments
│   ├── prompts/            # Test prompts with expected outcomes
│   └── tokens/             # Sample token schemas
├── generators/
│   ├── generate_eval.dart  # Test frame generation
│   ├── update_eval.dart    # Test frame updates
│   └── patch_eval.dart     # Test targeted patches
├── metrics/
│   ├── acceptance.dart     # Track acceptance rate
│   ├── accuracy.dart       # Track patch accuracy
│   └── repair.dart         # Track repair rate
└── reports/
    └── eval_report.dart    # Generate eval summary
```

**Eval cadence:**
- Run on every AI prompt/model change
- Weekly baseline against fixed test set
- Track metrics over time to detect regressions