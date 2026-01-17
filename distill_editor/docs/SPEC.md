# AI Context Contract Specification

## Overview

This document defines the context contract between the Free Design editor and AI services. The quality of AI-generated edits is directly proportional to the quality of context provided. This spec ensures agents have consistent, complete, and correctly-scoped information for both generation and targeted editing.

---

## Context Modes

The AI interface operates in three distinct modes, each requiring different context:

| Mode | Trigger | Context Scope | Output |
|------|---------|---------------|--------|
| **Generate** | "Create a login screen" | Document-level + tokens | New Frame + Nodes (DSL) |
| **Update** | "Add a forgot password link" | Frame-level + selection | Modified Nodes (DSL) |
| **Patch** | "Make the button blue" | Selection-focused | Patch operations (JSON) |

---

## Context Structure

### Base Context (All Modes)

```typescript
interface AIContext {
  // Mode identification
  mode: 'generate' | 'update' | 'patch';
  
  // Project-level context
  project: ProjectContext;
  
  // Document state
  document: DocumentContext;
  
  // User intent
  prompt: string;
  
  // Conversation history (for follow-ups)
  history?: ConversationHistory;
}
```

### Project Context

```typescript
interface ProjectContext {
  // Design tokens (always included)
  tokens: TokenSchema;
  
  // Available components (summary, not full definitions)
  components: ComponentSummary[];
  
  // Project metadata
  meta: {
    name: string;
    platform: 'mobile' | 'tablet' | 'desktop' | 'web';
    framework: 'flutter';  // Future: swiftui, react, etc.
  };
}

interface TokenSchema {
  color: Record<string, string | Record<string, string>>;
  spacing: Record<string, number>;
  radius: Record<string, number>;
  typography: Record<string, TypographyToken>;
  // Extensible for project-specific tokens
  [category: string]: unknown;
}

interface ComponentSummary {
  id: string;
  name: string;
  description?: string;
  slots: string[];  // Available slot names
  // Full definition NOT included to save tokens
}
```

### Document Context

```typescript
interface DocumentContext {
  // All frames (summary level)
  frames: FrameSummary[];
  
  // Currently active frame (if any)
  activeFrame?: FrameContext;
  
  // Current selection
  selection: SelectionContext;
}

interface FrameSummary {
  id: string;
  name: string;
  size: { width: number; height: number };
  nodeCount: number;
  // NOT included: full node tree (too expensive)
}

interface FrameContext {
  frame: Frame;
  
  // Full node tree as DSL (compact)
  dsl: string;
  
  // Or as outline (even more compact)
  outline: string;
}
```

### Selection Context

```typescript
interface SelectionContext {
  // What's selected
  type: 'none' | 'frame' | 'node' | 'multi-node';
  
  // Selected IDs
  frameId?: string;
  nodeIds: string[];
  
  // Selected nodes with immediate context
  nodes: SelectedNodeContext[];
  
  // Parent chain for structural understanding
  ancestors: AncestorContext[];
}

interface SelectedNodeContext {
  // Full node data
  node: Node;
  
  // Expanded ID (for instances)
  expandedId: string;
  
  // Immediate children (IDs only)
  childIds: string[];
  
  // Sibling context
  siblingIndex: number;
  siblingCount: number;
}

interface AncestorContext {
  id: string;
  name: string;
  type: NodeType;
  
  // Layout context (important for understanding constraints)
  layout: {
    direction?: 'row' | 'column';
    gap?: number;
    padding?: EdgeInsets;
    alignment?: Alignment;
  };
}
```

### Conversation History

```typescript
interface ConversationHistory {
  // Recent exchanges (last 5-10)
  exchanges: Exchange[];
  
  // Recent edits (last 10-20 patches)
  recentEdits: EditSummary[];
}

interface Exchange {
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
}

interface EditSummary {
  // Natural language description
  description: string;
  
  // Affected nodes
  nodeIds: string[];
  
  // Edit type
  type: 'create' | 'update' | 'delete' | 'move' | 'style';
  
  timestamp: number;
}
```

---

## Mode-Specific Context

### Generate Mode

Full document awareness, minimal selection context.

```typescript
interface GenerateContext extends AIContext {
  mode: 'generate';
  
  // Target placement
  target: {
    position: { x: number; y: number };
    size: { width: number; height: number };
  };
  
  // Optional reference frames (for style matching)
  referenceFrames?: FrameContext[];
}
```

**Context Budget**: ~2000-3000 tokens typical

**Included**:
- Full token schema
- All component summaries
- Frame list (summaries)
- Reference frame DSL (if provided)

**Excluded**:
- Other frame details
- Node-level data from unrelated frames

### Update Mode

Frame-focused with selection awareness.

```typescript
interface UpdateContext extends AIContext {
  mode: 'update';
  
  // Target frame (required)
  targetFrame: FrameContext;
  
  // Focus nodes (optional - narrows scope)
  focusNodeIds?: string[];
}
```

**Context Budget**: ~1500-2500 tokens typical

**Included**:
- Token schema
- Component summaries
- Target frame full DSL
- Selection context
- Ancestor chain

**Excluded**:
- Other frames
- Unrelated node details

### Patch Mode

Selection-focused, minimal surrounding context.

```typescript
interface PatchContext extends AIContext {
  mode: 'patch';
  
  // Must have selection
  selection: SelectionContext & { nodeIds: [string, ...string[]] };
  
  // Allowed operations (constraints)
  allowedOps?: PatchOpType[];
}

type PatchOpType = 
  | 'SetProp' 
  | 'DeleteProp'
  | 'InsertNode' 
  | 'DeleteNode'
  | 'AttachChild'
  | 'DetachChild'
  | 'MoveNode'
  | 'ReplaceNode';
```

**Context Budget**: ~500-1000 tokens typical

**Included**:
- Relevant tokens only (colors if color change, spacing if layout change)
- Selected nodes full detail
- Immediate parent context
- Recent edit history (for follow-ups)

**Excluded**:
- Full frame DSL
- Unrelated nodes
- Full token schema (filtered to relevant subset)

---

## Context Compilation

### OutlineCompiler Extensions

The existing `OutlineCompiler` should be extended to support mode-specific context:

```dart
class AIContextCompiler {
  /// Compile context for generation mode
  static GenerateContext forGeneration({
    required EditorDocument document,
    required TokenSchema tokens,
    required Offset position,
    required Size size,
    List<String>? referenceFrameIds,
  });
  
  /// Compile context for update mode
  static UpdateContext forUpdate({
    required EditorDocument document,
    required TokenSchema tokens,
    required String frameId,
    required SelectionState selection,
    List<String>? focusNodeIds,
  });
  
  /// Compile context for patch mode
  static PatchContext forPatch({
    required EditorDocument document,
    required TokenSchema tokens,
    required SelectionState selection,
    required List<EditSummary> recentEdits,
  });
}
```

### Token Filtering

For patch mode, filter tokens to relevant subset:

```dart
TokenSchema filterTokensForEdit(String prompt, TokenSchema fullSchema) {
  final mentionsColor = prompt.containsAny(['color', 'blue', 'red', ...]);
  final mentionsSpacing = prompt.containsAny(['padding', 'margin', 'gap', 'space', ...]);
  final mentionsRadius = prompt.containsAny(['radius', 'rounded', 'corner', ...]);
  
  return TokenSchema(
    color: mentionsColor ? fullSchema.color : {},
    spacing: mentionsSpacing ? fullSchema.spacing : {},
    radius: mentionsRadius ? fullSchema.radius : {},
    typography: {}, // Include if text-related
  );
}
```

---

## Output Contracts

### Generate Output

```typescript
interface GenerateResult {
  success: boolean;
  
  // Generated content (DSL format)
  dsl?: string;
  
  // Parsed for convenience
  frame?: Frame;
  nodes?: Record<string, Node>;
  
  // Metadata
  meta: {
    tokensUsed: number;
    generationTimeMs: number;
    model: string;
  };
  
  // Issues encountered
  warnings?: string[];
  errors?: string[];
}
```

### Update Output

```typescript
interface UpdateResult {
  success: boolean;
  
  // Updated DSL (full frame)
  dsl?: string;
  
  // Diff for review
  diff?: {
    added: string[];
    removed: string[];
    modified: string[];
  };
  
  meta: GenerateResultMeta;
  warnings?: string[];
  errors?: string[];
}
```

### Patch Output

```typescript
interface PatchResult {
  success: boolean;
  
  // Patches to apply
  patches?: PatchOp[];
  
  // Natural language explanation
  explanation?: string;
  
  // Confidence score (0-1)
  confidence?: number;
  
  // If confidence < threshold, include alternatives
  alternatives?: {
    patches: PatchOp[];
    explanation: string;
    confidence: number;
  }[];
  
  meta: {
    tokensUsed: number;
    generationTimeMs: number;
    model: string;
  };
  
  warnings?: string[];
  errors?: string[];
}
```

---

## Confidence Thresholds

Patch mode should use confidence to determine UX:

| Confidence | Behavior |
|------------|----------|
| ≥ 0.9 | Auto-apply, show toast notification |
| 0.7 - 0.9 | Show preview, one-click apply |
| 0.5 - 0.7 | Show preview with alternatives, require selection |
| < 0.5 | Show warning, suggest rephrasing prompt |

```dart
enum PatchApplicationMode {
  autoApply,      // >= 0.9
  previewApply,   // 0.7 - 0.9
  selectApply,    // 0.5 - 0.7
  warn,           // < 0.5
}

PatchApplicationMode getModeForConfidence(double confidence) {
  if (confidence >= 0.9) return PatchApplicationMode.autoApply;
  if (confidence >= 0.7) return PatchApplicationMode.previewApply;
  if (confidence >= 0.5) return PatchApplicationMode.selectApply;
  return PatchApplicationMode.warn;
}
```

---

## Prompt Templates

### Patch Mode System Prompt

```
You are an AI assistant for a visual design editor. Your task is to generate precise patch operations that modify the design based on user requests.

## Context
- Selected nodes: {selectedNodes}
- Parent context: {parentContext}
- Available tokens: {filteredTokens}
- Recent edits: {recentEdits}

## Output Format
Respond with a JSON object:
{
  "patches": [
    { "op": "SetProp", "id": "node_id", "path": "/json/pointer", "value": ... },
    ...
  ],
  "explanation": "Brief description of changes",
  "confidence": 0.0-1.0
}

## Rules
1. Only modify nodes in the selection or their direct properties
2. Use token references ({token.path}) when matching existing token usage
3. Preserve node IDs - never regenerate them
4. Use the minimum number of patches to achieve the goal
5. If the request is ambiguous, set confidence lower and explain alternatives

## Patch Operations Available
- SetProp: Set a property value by JSON pointer path
- DeleteProp: Remove a property
- InsertNode: Add a new node (must include full node definition)
- DeleteNode: Remove a node by ID
- MoveNode: Move node to new parent
- AttachChild: Attach existing node as child
- DetachChild: Detach node from parent

## Property Paths
Common paths for SetProp:
- /style/fill/color - Background color
- /style/fill/type - Fill type (solid, gradient, none)
- /style/cornerRadius/all - Border radius (all corners)
- /style/stroke/width - Border width
- /style/stroke/color - Border color
- /style/opacity - Opacity (0-1)
- /layout/size/width/value - Fixed width
- /layout/size/height/value - Fixed height
- /layout/padding/* - Padding values
- /layout/gap - Auto-layout gap
- /props/text - Text content (for text nodes)
- /props/fontWeight - Font weight
- /props/fontSize - Font size
```

### Follow-up Handling

When `recentEdits` includes the previous exchange, the agent can handle follow-ups:

**User**: "Make the button blue"
**Agent**: Sets fill color to blue
**User**: "A bit darker"
**Agent**: (Sees recent edit was color change to button) → Adjusts same fill to darker blue

```typescript
// Recent edits provide context for follow-ups
recentEdits: [
  {
    description: "Changed n_button fill color to #007AFF",
    nodeIds: ["n_button"],
    type: "style",
    timestamp: 1699900000
  }
]
```

---

## Validation Pipeline

All AI output must pass through validation before application:

```dart
class AIOutputValidator {
  /// Validate patch result before application
  ValidationResult validatePatches(
    PatchResult result,
    EditorDocument document,
  ) {
    final errors = <String>[];
    final warnings = <String>[];
    
    for (final patch in result.patches ?? []) {
      // 1. Check target exists
      if (!_targetExists(patch, document)) {
        errors.add('Target ${patch.targetId} not found');
        continue;
      }
      
      // 2. Check operation validity
      final opError = _validateOperation(patch, document);
      if (opError != null) errors.add(opError);
      
      // 3. Check value schema
      final schemaError = _validateValueSchema(patch);
      if (schemaError != null) errors.add(schemaError);
      
      // 4. Check for destructive operations
      if (_isDestructive(patch)) {
        warnings.add('Destructive operation: ${patch.op} on ${patch.targetId}');
      }
    }
    
    return ValidationResult(
      valid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
```

---

## Token Budget Guidelines

| Mode | Target | Max | Notes |
|------|--------|-----|-------|
| Generate | 2500 | 4000 | Full context needed for quality |
| Update | 1500 | 3000 | Frame DSL is bulk of budget |
| Patch | 800 | 1500 | Selection-focused, minimal context |

### Budget Breakdown (Patch Mode Example)

```
System prompt:     ~400 tokens (fixed)
Selected nodes:    ~100-300 tokens (varies with selection size)
Parent context:    ~50-100 tokens
Filtered tokens:   ~100-200 tokens (only relevant categories)
Recent edits:      ~100-200 tokens (last 5-10)
User prompt:       ~20-50 tokens
─────────────────────────────
Total:             ~770-1250 tokens
```

---

## Implementation Checklist

- [ ] Extend `OutlineCompiler` to `AIContextCompiler` with mode-specific methods
- [ ] Implement `TokenSchema` data structure and project-level storage
- [ ] Implement token filtering for patch mode
- [ ] Add `SelectionContext` to `CanvasState` for easy access
- [ ] Add `EditHistory` tracking in `EditorDocumentStore`
- [ ] Implement confidence-based UX flow for patch application
- [ ] Create prompt templates as configurable resources
- [ ] Add validation pipeline for all AI outputs
- [ ] Implement follow-up detection and context threading
- [ ] Add telemetry for context size / generation quality correlation