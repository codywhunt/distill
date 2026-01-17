# Next Priorities

Focused roadmap for getting Distill from "promising demo" to "usable tool."

---

## Philosophy

The architecture is sound. The 3-stage pipeline, immutable IR, patch protocol, and DSL are the right abstractions. What's missing is the polish on fundamentals that makes a tool *usable* vs *demo-able*.

**Principle:** Make the simple things feel great before adding advanced features.

---

## Priority 1: Fix Drag & Drop

**Status:** Broken/incomplete on canvas and layer tree

### What's Wrong
- Reparenting nodes via drag doesn't work reliably
- Reordering children within a parent has edge cases
- Layer tree drag/drop is incomplete
- Visual feedback during drag is inconsistent

### Success Criteria
- [x] Drag node to new parent on canvas → reparents correctly
- [x] Drag node between siblings → reorders correctly
- [x] Layer tree drag mirrors canvas behavior
- [x] Insertion indicator shows valid drop targets
- [x] Invalid drops are prevented (can't drop parent into child)
- [x] Undo reverses the operation cleanly

### Why First
Can't edit without this. Every other feature depends on reliable node manipulation.

---

## Priority 2: Document & Frame Management

**Status:** No UI exists

### What's Missing
- No document creation flow
- No save/load (persistence)
- No frame list sidebar
- No frame navigation
- Can't rename frames easily
- Can't delete frames

### Success Criteria
- [ ] Create new document (empty canvas)
- [ ] Save document to file (JSON serialization)
- [ ] Load document from file
- [ ] Frame list panel showing all frames
- [ ] Click frame in list → canvas pans to frame
- [ ] Double-click frame → edit name inline
- [ ] Delete frame with confirmation
- [ ] Create new empty frame at canvas position

### Why Now
Without this, you can't use the tool for real projects. You're stuck in single-session demos.

---

## Priority 3: Copy & Paste

**Status:** Not implemented

### Scope
- Copy selected node(s)
- Paste into current selection or at cursor position
- Cut (copy + delete)
- Duplicate (copy + paste in place with offset)

### Implementation Notes
- Clipboard format: serialized Node subtree (or DSL?)
- On paste: generate new IDs for all nodes
- Handle cross-frame paste
- Preserve relative positions for multi-select

### Success Criteria
- [ ] Cmd+C copies selected node(s)
- [ ] Cmd+V pastes at cursor or into selection
- [ ] Cmd+X cuts
- [ ] Cmd+D duplicates with offset
- [ ] Pasted nodes get fresh IDs (no collisions)
- [ ] Cross-frame copy works
- [ ] Undo reverses paste

### Why Now
Basic editing primitive. Users expect this to exist.

---

## Priority 4: DSL Round-Trip Fidelity

**Status:** Unknown—no systematic testing

### The Problem
DSL is the contract between human editing and AI generation. If `parse(export(doc)) != doc`, then:
- AI-generated content silently loses properties
- Edits disappear on regeneration
- Debugging becomes a nightmare

### Approach
1. Property coverage audit: list every property in IR, verify DSL handles it
2. Fuzz testing: generate random valid documents, round-trip, compare
3. Edge case catalog: empty values, special characters, deep nesting, token refs

### Success Criteria
- [ ] Every Node property has DSL representation
- [ ] Every NodeLayout property has DSL representation
- [ ] Every NodeStyle property has DSL representation
- [ ] Fuzz test: 1000 random docs round-trip without diff
- [ ] Edge cases documented and tested:
  - [ ] Empty string text
  - [ ] Unicode in text content
  - [ ] Token references (`{color.primary}`)
  - [ ] Deeply nested nodes (10+ levels)
  - [ ] All 7 node types
  - [ ] Component instances with overrides

### Why Now
AI quality depends on DSL fidelity. Fix this before improving AI prompts.

---

## Priority 5: AI Patch Mode

**Status:** AI only does full regeneration

### Current Flow
```
User: "make the button blue"
AI: regenerates entire frame DSL
System: replaces all nodes
```

### Better Flow
```
User: "make the button blue"
AI: emits patch operations
System: applies surgical change
```

### Implementation
1. New prompt template for patch emission
2. AI returns JSON patch array instead of DSL
3. Validate patches before applying
4. Show user what changed (diff view?)

### Patch Output Format
```json
{
  "patches": [
    { "op": "SetProp", "id": "n_button", "path": "/style/fill/color", "value": "#007AFF" }
  ],
  "explanation": "Changed button fill to blue"
}
```

### Success Criteria
- [ ] AI can emit patches for property changes
- [ ] AI can emit patches for structural changes (add/remove node)
- [ ] Patches are validated before application
- [ ] Failed patches show clear error
- [ ] User sees explanation of what changed
- [ ] Fallback to full regeneration if patch mode fails

### Why Now
- Faster (fewer tokens)
- Safer (surgical vs wholesale)
- More trustworthy (user sees exactly what changed)
- Patch protocol already exists—just need AI to use it

---

## Priority 6: Quick-Edit Overlays

**Status:** Not implemented (in todos)

### What This Means
When you select a node, show contextual edit controls directly on the canvas:
- Text node → inline text editing (double-click to edit)
- Any node → color swatch for quick fill change
- Container → quick padding/gap adjusters

### Scope (Start Small)
1. **Double-click text node** → inline text editing
2. **Fill color swatch** → click to open color picker

Don't boil the ocean. These two alone are a big UX win.

### Success Criteria
- [ ] Double-click text node enters inline edit mode
- [ ] Typing updates text content live
- [ ] Click outside or Enter commits
- [ ] Escape cancels
- [ ] Fill swatch appears on selected nodes with fill
- [ ] Click swatch opens color picker positioned near node

### Why Now
Big UX improvement, relatively small scope. Makes the tool feel more direct-manipulation.

---

## Priority 7: Prompt Box Improvements

**Status:** Basic implementation exists

### Current Issues
- Prompt box is large/intrusive
- Not contextual to selection
- No indication of what AI will affect

### Improvements
1. **Smaller prompt box** — minimal input that expands on focus
2. **Contextual positioning** — appears near selection, not fixed position
3. **Scope indicator** — show what the AI will modify (selected node, frame, etc.)
4. **History** — recent prompts accessible

### Success Criteria
- [ ] Compact prompt input (single line, expands on focus)
- [ ] Positioned near current selection
- [ ] Shows "Editing: [node name]" or "Editing: [frame name]"
- [ ] Up arrow recalls previous prompts
- [ ] Loading state while AI generates
- [ ] Error state with retry option

### Why Now
Makes AI feel integrated rather than bolted-on. Reduces friction for quick edits.

---

## Out of Scope (For Now)

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
[1] Drag & Drop ─────┐
                     ├──→ [4] DSL Fidelity ──→ [5] AI Patch Mode
[2] Doc Management ──┤
                     │
[3] Copy & Paste ────┘
                          [6] Quick-Edit Overlays ──→ [7] Prompt Box
```

Priorities 1-3 are about **making editing work**.
Priority 4 is about **making AI reliable**.
Priority 5 is about **making AI better**.
Priorities 6-7 are about **making the UX feel polished**.

---

## How to Use This Document

Pick the top incomplete priority. Work on it until the success criteria are met. Check off items as you go. Move to the next priority.

Resist the urge to skip ahead to the "interesting" stuff. The boring fundamentals are what make the interesting stuff usable.
