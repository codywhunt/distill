# Next Priorities

Focused roadmap for getting Distill from "promising demo" to "usable tool."

**Last Updated:** Based on comprehensive code audit

---

## Philosophy

The architecture is sound. The 3-stage pipeline, immutable IR, patch protocol, and DSL are the right abstractions. What's missing is the polish on fundamentals that makes a tool *usable* vs *demo-able*.

**Principle:** Make the simple things feel great before adding advanced features.

---

## Status Summary

| Priority | Feature | Status | Completion |
|----------|---------|--------|------------|
| 1 | Drag & Drop | ✅ **COMPLETE** | 100% |
| 2 | Document & Frame Management | ✅ **COMPLETE** | 100% |
| 3 | Copy & Paste | ✅ **COMPLETE** | 100% |
| 4 | DSL Round-Trip Fidelity | ⚠️ **NEEDS TESTING** | 95% code, 0% tests |
| 5 | AI Patch Mode | ✅ **COMPLETE** | 100% |
| 6 | Quick-Edit Overlays | ❌ **NOT STARTED** | 0% |
| 7 | Prompt Box Improvements | ⚠️ **PARTIAL** | 50% |

---

## Priority 1: Fix Drag & Drop ✅ COMPLETE

**Status:** Fully implemented with comprehensive testing

### Implementation
- Canvas drag: move, resize, marquee selection
- Layer tree drag/drop with selection sync
- Reparenting and reordering with visual feedback
- 80+ tests covering all scenarios
- 9 documented invariants enforced

### Success Criteria
- [x] Drag node to new parent on canvas → reparents correctly
- [x] Drag node between siblings → reorders correctly
- [x] Layer tree drag mirrors canvas behavior
- [x] Insertion indicator shows valid drop targets
- [x] Invalid drops are prevented (can't drop parent into child)
- [x] Undo reverses the operation cleanly

---

## Priority 2: Document & Frame Management ✅ COMPLETE

**Status:** Fully implemented with persistence and UI

### Implementation
- `DocumentPersistenceService` with platform-specific I/O
- Frame list panel with create/delete/rename
- Frame navigation (click to pan)
- Inline frame renaming on double-click
- Full undo/redo support

### Success Criteria
- [x] Create new document (empty canvas)
- [x] Save document to file (JSON serialization)
- [x] Load document from file
- [x] Frame list panel showing all frames
- [x] Click frame in list → canvas pans to frame
- [x] Double-click frame → edit name inline
- [x] Delete frame with confirmation
- [x] Create new empty frame at canvas position

---

## Priority 3: Copy & Paste ✅ COMPLETE

**Status:** Fully implemented with all keyboard shortcuts

### Implementation
- `ClipboardService` with dual clipboard (internal + system)
- `ClipboardPayload` for serialization
- `NodeRemapper` for ID regeneration
- All shortcuts wired: Cmd+C/V/X/D
- Cross-frame paste working
- Multi-select with relative position preservation

### Success Criteria
- [x] Cmd+C copies selected node(s)
- [x] Cmd+V pastes at cursor or into selection
- [x] Cmd+X cuts
- [x] Cmd+D duplicates with offset
- [x] Pasted nodes get fresh IDs (no collisions)
- [x] Cross-frame copy works
- [x] Undo reverses paste

---

## Priority 4: DSL Round-Trip Fidelity ⚠️ NEEDS TESTING

**Status:** Implementation complete, **ZERO TEST COVERAGE**

### The Problem
DSL parser and exporter work and are actively used in AI generation, but have no tests. This is a critical gap - we're using untested code in production.

### Implementation (Complete)
- `DslParser` (637 lines) - parses DSL to Frame + Nodes
- `DslExporter` (460 lines) - exports Frame + Nodes to DSL
- Active in `ai_service.dart` for frame generation
- Supports all 7 node types, most properties

### Testing Gap (Critical)
- ❌ No round-trip tests
- ❌ No property coverage tests
- ❌ No fuzz tests
- ❌ No edge case tests

### Success Criteria
- [ ] Every Node property has round-trip test
- [ ] Every NodeLayout property has round-trip test
- [ ] Every NodeStyle property has round-trip test
- [ ] Fuzz test: 1000 random docs round-trip without diff
- [ ] Edge cases tested:
  - [ ] Empty string text
  - [ ] Unicode in text content
  - [ ] Token references (`{color.primary}`)
  - [ ] Deeply nested nodes (10+ levels)
  - [ ] All 7 node types
  - [ ] Component instances with overrides

### Why Now
AI quality depends on DSL fidelity. If round-trip is lossy, AI-generated content silently loses properties. **Test this before trusting AI output.**

**See:** `docs/PRD_PRIORITY_4_DSL_FIDELITY.md` for detailed test plan

---

## Priority 5: AI Patch Mode ✅ COMPLETE

**Status:** Fully implemented and actively used in UI

### Implementation
- `EditViaPatchesPrompt` - comprehensive prompt template
- `PatchOpsParser` - robust JSON extraction from AI responses
- `PatchValidator` - full invariant checking before apply
- `PatchApplier` - immutable patch application (well-tested)
- Auto-repair with 2 retries on validation failure
- Wired in `prompt_box_overlay.dart`

### Success Criteria
- [x] AI can emit patches for property changes
- [x] AI can emit patches for structural changes (add/remove node)
- [x] Patches are validated before application
- [x] Failed patches show clear error
- [x] User sees explanation of what changed (via repair diagnostics)
- [x] Fallback to full regeneration if patch mode fails

---

## Priority 6: Quick-Edit Overlays ❌ NOT STARTED

**Status:** Not implemented (0%)

### What This Means
When you select a node, show contextual edit controls directly on the canvas:
- Text node → inline text editing (double-click to edit)
- Any node → color swatch for quick fill change

### Current State
- Double-click detection exists but only triggers zoom, not edit
- Color swatch exists in property panel but not on canvas
- No overlay widgets or state management

### Success Criteria
- [ ] Double-click text node enters inline edit mode
- [ ] Typing updates text content live
- [ ] Click outside or Enter commits
- [ ] Escape cancels
- [ ] Fill swatch appears on selected nodes with fill
- [ ] Click swatch opens color picker positioned near node

### Why Now
Big UX improvement, relatively small scope. Makes the tool feel more direct-manipulation.

**See:** `docs/PRD_PRIORITY_6_QUICK_EDIT_OVERLAYS.md` for detailed spec

---

## Priority 7: Prompt Box Improvements ⚠️ PARTIAL (50%)

**Status:** Basic implementation works, UX polish missing

### What's Working ✅
- Basic prompt box widget
- Text input with Enter/Escape
- Context chips showing selection
- Model selection dropdown
- Loading state with spinner
- AI integration (generate + patch modes)

### What's Missing ❌
- Prompt history (Up/Down arrow navigation)
- Contextual positioning (fixed at bottom center)
- Scope indicator ("Editing: Button")
- Mode badges (CREATE/EDIT visual indicator)
- Persistent history across sessions
- Error display with retry button

### Success Criteria
- [x] Basic prompt input works
- [x] Loading state while AI generates
- [ ] Compact prompt input (expands on focus)
- [ ] Positioned near current selection
- [ ] Shows "Editing: [node name]" or "Creating new frame"
- [ ] Up arrow recalls previous prompts
- [ ] Error state with retry option

### Why Now
Makes AI feel integrated rather than bolted-on. Reduces friction for quick edits.

**See:** `docs/PRD_PRIORITY_7_PROMPT_BOX.md` for detailed spec

---

## Recommended Next Steps

Based on the audit, here's the recommended work order:

### Immediate (Do First)
1. **DSL Testing (Priority 4)** - 3-4 days
   - This is critical technical debt
   - We're using untested code in production
   - Write round-trip tests, edge case tests, fuzz tests

### Short-term (After DSL Testing)
2. **Quick-Edit Overlays (Priority 6)** - 3-5 days
   - High user impact
   - Inline text editing + color swatch
   - Makes editing feel more direct

3. **Prompt Box Polish (Priority 7)** - 3 days
   - History navigation
   - Scope indicator
   - Contextual positioning

### Out of Scope (For Now)

These are good ideas but should wait:

| Feature | Why Wait |
|---------|----------|
| Semantic hints (`@hint button`) | Solving a code-gen problem we don't have yet |
| Code generation | New product surface; need more experience with current system |
| Interaction model (`@action tap`) | Adds complexity; focus on static design first |
| Responsive/breakpoints | Hard to abstract well; single viewport is fine for MVP |
| Multi-platform output | Way down the road |

---

## Sequencing

```
COMPLETED:
[1] Drag & Drop ────────┐
                        ├──→ [5] AI Patch Mode ✅
[2] Doc Management ─────┤
                        │
[3] Copy & Paste ───────┘

REMAINING:
[4] DSL Testing ──→ [6] Quick-Edit Overlays ──→ [7] Prompt Box Polish
    (critical)         (high impact)              (polish)
```

The completed foundations (1-3, 5) enable the remaining work. Priority 4 (DSL testing) should come first because it validates the AI pipeline that everything else depends on.

---

## How to Use This Document

1. Start with Priority 4 (DSL Testing) - it's critical technical debt
2. Move to Priority 6 (Quick-Edit) - highest user impact
3. Finish with Priority 7 (Prompt Box) - polish

Check off items as you complete them. Update status when priorities change.
