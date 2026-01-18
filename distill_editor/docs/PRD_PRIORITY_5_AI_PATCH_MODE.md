# PRD: Priority 5 - AI Patch Mode

## Overview

Currently, AI edits work by regenerating entire frames from scratch. This is inefficient, risky, and opaque. AI Patch Mode enables surgical AI edits where the AI emits specific patch operations rather than replacing everything.

**Status:** Not Started
**Dependencies:** Priority 4 (DSL Fidelity) - Should be complete first
**Estimated Complexity:** High

---

## Problem Statement

### Current Flow (Generation Mode)
```
User: "make the button blue"
AI: regenerates entire frame DSL (~500 tokens)
System: replaces all nodes (potentially loses uncommitted state)
User: can't see what changed
```

### Problems with Current Approach
1. **Wasteful**: Full regeneration for single property change
2. **Risky**: Could inadvertently change unrelated elements
3. **Opaque**: User doesn't know what AI actually modified
4. **Slow**: More tokens = more latency
5. **Expensive**: More tokens = higher API cost
6. **Brittle**: Small prompt variations can cause major differences

---

## Goals

1. **Surgical edits**: AI emits minimal patches for targeted changes
2. **Transparency**: User sees exactly what will change before applying
3. **Efficiency**: 80%+ reduction in tokens for property changes
4. **Safety**: Validate patches before application
5. **Fallback**: Graceful degradation to full regeneration when needed

---

## Non-Goals (Out of Scope)

- Multi-turn patch conversations (single request/response)
- Patch streaming (wait for complete response)
- Collaborative editing (single user)
- Patch suggestions without user prompt
- Learning from user corrections

---

## Success Criteria

| Criterion | Metric | Validation Method |
|-----------|--------|-------------------|
| AI can emit property patches | "make it blue" → SetProp | Integration test |
| AI can emit structural patches | "add a button" → InsertNode + AttachChild | Integration test |
| Patches are validated | Invalid patches rejected with message | Unit test |
| Failed patches show error | Clear error state in UI | Manual test |
| User sees explanation | Natural language description shown | Manual test |
| Fallback works | Invalid patch → offer full regeneration | Integration test |
| Confidence threshold | Low confidence shows alternatives | Unit test |
| Token efficiency | 80%+ reduction for property changes | Measurement |
| Acceptance rate | >80% patches apply without modification | Eval harness |

---

## Technical Architecture

### 1. AI Interface Modes

```dart
/// AI editing service with dual-mode support
abstract class AIEditingService {
  /// Generate new frame from natural language (existing)
  Future<GenerationResult> generateFrame({
    required String prompt,
    required AIContext context,
  });

  /// Generate patches for targeted edit (NEW)
  Future<PatchResult> generatePatches({
    required String prompt,
    required PatchContext context,
  });

  /// Update existing frame via regeneration (existing)
  Future<UpdateResult> updateFrame({
    required String prompt,
    required UpdateContext context,
  });
}

/// Result from patch generation
class PatchResult {
  /// Whether generation succeeded
  final bool success;

  /// Patches to apply (null if failed)
  final List<PatchOp>? patches;

  /// Natural language explanation
  final String? explanation;

  /// Confidence score (0-1)
  final double confidence;

  /// Alternative interpretations (if confidence < threshold)
  final List<PatchAlternative>? alternatives;

  /// Error message (if failed)
  final String? error;

  /// Token usage
  final TokenUsage usage;

  PatchResult({
    required this.success,
    this.patches,
    this.explanation,
    this.confidence = 1.0,
    this.alternatives,
    this.error,
    required this.usage,
  });
}

class PatchAlternative {
  final List<PatchOp> patches;
  final String explanation;
  final double confidence;

  PatchAlternative({
    required this.patches,
    required this.explanation,
    required this.confidence,
  });
}

class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
}
```

### 2. Patch Context Compilation

```dart
/// Compiler for patch-mode AI context
class PatchContextCompiler {
  /// Compile minimal context for patch generation
  static PatchContext compile({
    required EditorDocument document,
    required List<String> selectedNodeIds,
    required String? focusedFrameId,
    required ThemeDocument theme,
    required List<EditSummary> recentEdits,
    required String prompt,
  }) {
    // Filter tokens based on prompt content
    final relevantTokens = _filterTokensForPrompt(prompt, theme);

    // Build selection context
    final selectionContext = _buildSelectionContext(
      selectedNodeIds,
      document,
    );

    // Build ancestor context for structural understanding
    final ancestorContext = _buildAncestorContext(
      selectedNodeIds,
      document,
    );

    return PatchContext(
      selectedNodes: selectionContext,
      ancestors: ancestorContext,
      tokens: relevantTokens,
      recentEdits: recentEdits.take(5).toList(),
      frameId: focusedFrameId,
    );
  }

  /// Filter tokens to relevant subset based on prompt keywords
  static TokenSchema _filterTokensForPrompt(String prompt, ThemeDocument theme) {
    final lowerPrompt = prompt.toLowerCase();

    final includeColors = _mentionsColor(lowerPrompt);
    final includeSpacing = _mentionsSpacing(lowerPrompt);
    final includeRadius = _mentionsRadius(lowerPrompt);
    final includeTypography = _mentionsTypography(lowerPrompt);

    return TokenSchema(
      colors: includeColors ? theme.colors : {},
      spacing: includeSpacing ? theme.spacing : {},
      radius: includeRadius ? theme.radius : {},
      typography: includeTypography ? theme.typography : {},
    );
  }

  static bool _mentionsColor(String prompt) {
    final colorKeywords = [
      'color', 'blue', 'red', 'green', 'yellow', 'purple', 'orange',
      'black', 'white', 'gray', 'grey', 'background', 'bg', 'fill',
      'text color', 'border color', 'primary', 'secondary', 'accent',
    ];
    return colorKeywords.any((k) => prompt.contains(k));
  }

  static bool _mentionsSpacing(String prompt) {
    final spacingKeywords = [
      'spacing', 'padding', 'margin', 'gap', 'space', 'distance',
      'tight', 'loose', 'compact', 'spread', 'closer', 'further',
    ];
    return spacingKeywords.any((k) => prompt.contains(k));
  }

  static bool _mentionsRadius(String prompt) {
    final radiusKeywords = [
      'radius', 'rounded', 'corner', 'square', 'sharp', 'circular',
      'pill', 'round',
    ];
    return radiusKeywords.any((k) => prompt.contains(k));
  }

  static bool _mentionsTypography(String prompt) {
    final typographyKeywords = [
      'font', 'text', 'size', 'weight', 'bold', 'italic',
      'heading', 'title', 'body', 'caption', 'larger', 'smaller',
    ];
    return typographyKeywords.any((k) => prompt.contains(k));
  }

  static List<SelectedNodeContext> _buildSelectionContext(
    List<String> nodeIds,
    EditorDocument document,
  ) {
    return nodeIds.map((id) {
      final node = document.nodes[id];
      if (node == null) return null;

      return SelectedNodeContext(
        node: node,
        childIds: node.children,
        siblingIndex: _getSiblingIndex(id, document),
        siblingCount: _getSiblingCount(id, document),
      );
    }).whereType<SelectedNodeContext>().toList();
  }

  static List<AncestorContext> _buildAncestorContext(
    List<String> nodeIds,
    EditorDocument document,
  ) {
    if (nodeIds.isEmpty) return [];

    final ancestors = <AncestorContext>[];
    var currentId = nodeIds.first;

    while (true) {
      final parentId = _findParent(currentId, document);
      if (parentId == null) break;

      final parent = document.nodes[parentId];
      if (parent == null) break;

      ancestors.add(AncestorContext(
        id: parent.id,
        type: parent.type,
        autoLayout: parent.layout.autoLayout,
      ));

      currentId = parentId;
    }

    return ancestors;
  }
}

/// Minimal context for patch mode
class PatchContext {
  final List<SelectedNodeContext> selectedNodes;
  final List<AncestorContext> ancestors;
  final TokenSchema tokens;
  final List<EditSummary> recentEdits;
  final String? frameId;

  PatchContext({
    required this.selectedNodes,
    required this.ancestors,
    required this.tokens,
    required this.recentEdits,
    this.frameId,
  });

  /// Serialize to prompt format
  String toPromptString() {
    final buffer = StringBuffer();

    buffer.writeln('## Selected Nodes');
    for (final node in selectedNodes) {
      buffer.writeln(_nodeToString(node));
    }

    if (ancestors.isNotEmpty) {
      buffer.writeln('\n## Parent Context');
      for (final ancestor in ancestors) {
        buffer.writeln('- ${ancestor.type.name}#${ancestor.id}');
        if (ancestor.autoLayout != null) {
          buffer.writeln('  direction: ${ancestor.autoLayout!.direction}');
          buffer.writeln('  gap: ${ancestor.autoLayout!.gap}');
        }
      }
    }

    if (tokens.isNotEmpty) {
      buffer.writeln('\n## Available Tokens');
      buffer.writeln(tokens.toPromptString());
    }

    if (recentEdits.isNotEmpty) {
      buffer.writeln('\n## Recent Edits');
      for (final edit in recentEdits) {
        buffer.writeln('- ${edit.description}');
      }
    }

    return buffer.toString();
  }

  String _nodeToString(SelectedNodeContext context) {
    final node = context.node;
    final buffer = StringBuffer();

    buffer.writeln('${node.type.name}#${node.id}');

    // Layout
    if (node.layout.position != null) {
      buffer.writeln('  position: (${node.layout.position!.x}, ${node.layout.position!.y})');
    }
    if (node.layout.size != null) {
      final w = node.layout.size!.width;
      final h = node.layout.size!.height;
      buffer.writeln('  size: ${w?.value ?? w?.mode.name} x ${h?.value ?? h?.mode.name}');
    }
    if (node.layout.padding != null) {
      buffer.writeln('  padding: ${node.layout.padding}');
    }

    // Style
    if (node.style?.fill != null) {
      buffer.writeln('  fill: ${node.style!.fill!.color}');
    }
    if (node.style?.stroke != null) {
      buffer.writeln('  stroke: ${node.style!.stroke!.width}px ${node.style!.stroke!.color}');
    }
    if (node.style?.cornerRadius != null) {
      buffer.writeln('  radius: ${node.style!.cornerRadius}');
    }

    // Props
    if (node.props.text != null) {
      buffer.writeln('  text: "${node.props.text}"');
    }

    return buffer.toString();
  }
}
```

### 3. Prompt Templates

```dart
/// Prompt template manager for AI modes
class AIPromptTemplates {
  /// System prompt for patch mode
  static const patchModeSystem = '''
You are an AI assistant for a visual design editor. Your task is to generate precise patch operations that modify the design based on user requests.

## Output Format
Respond with a JSON object:
{
  "patches": [
    { "op": "SetProp", "id": "node_id", "path": "/json/pointer/path", "value": ... }
  ],
  "explanation": "Brief description of changes",
  "confidence": 0.0-1.0
}

## Patch Operations

### Property Operations
- **SetProp**: Set a property value
  `{ "op": "SetProp", "id": "n_button", "path": "/style/fill/color", "value": "#007AFF" }`

- **DeleteProp**: Remove a property
  `{ "op": "DeleteProp", "id": "n_button", "path": "/style/shadow" }`

### Node Operations
- **InsertNode**: Add a new node (must include full node definition)
  `{ "op": "InsertNode", "node": { "id": "n_new", "type": "text", "props": { "text": "Hello" }, ... } }`

- **DeleteNode**: Remove a node
  `{ "op": "DeleteNode", "id": "n_old" }`

- **AttachChild**: Attach node as child of another
  `{ "op": "AttachChild", "parentId": "n_container", "childId": "n_new", "index": 0 }`

- **DetachChild**: Remove node from parent (without deleting)
  `{ "op": "DetachChild", "parentId": "n_container", "childId": "n_button" }`

- **MoveNode**: Move node to new parent
  `{ "op": "MoveNode", "id": "n_button", "newParentId": "n_footer", "index": -1 }`

## Common Property Paths

### Style Properties
- `/style/fill/type` - "solid" | "gradient" | "none"
- `/style/fill/color` - "#RRGGBB" or "{token.path}"
- `/style/stroke/width` - number (pixels)
- `/style/stroke/color` - "#RRGGBB" or "{token.path}"
- `/style/cornerRadius/all` - number (pixels)
- `/style/cornerRadius/topLeft`, `topRight`, `bottomLeft`, `bottomRight` - number
- `/style/opacity` - 0.0 to 1.0
- `/style/shadow/offsetX`, `offsetY`, `blur` - number
- `/style/shadow/color` - "#RRGGBBAA"

### Layout Properties
- `/layout/size/width/value` - number (pixels)
- `/layout/size/width/mode` - "fixed" | "fill" | "hug"
- `/layout/size/height/value` - number
- `/layout/size/height/mode` - "fixed" | "fill" | "hug"
- `/layout/padding/top`, `right`, `bottom`, `left` - number
- `/layout/autoLayout/direction` - "row" | "column"
- `/layout/autoLayout/gap` - number
- `/layout/autoLayout/mainAxisAlignment` - "start" | "center" | "end" | "spaceBetween" | "spaceAround"
- `/layout/autoLayout/crossAxisAlignment` - "start" | "center" | "end" | "stretch"

### Text Properties (for text nodes)
- `/props/text` - string content
- `/props/fontSize` - number
- `/props/fontWeight` - 100-900 (400 normal, 700 bold)
- `/props/color` - "#RRGGBB" or "{token.path}"
- `/props/textAlign` - "left" | "center" | "right"

## Rules
1. Only modify nodes that are selected or directly related to the request
2. Use token references ({token.path}) when the existing value uses tokens
3. Never change node IDs - they are stable references
4. Use minimum patches needed to achieve the goal
5. If the request is ambiguous, set confidence lower and explain in the explanation field
6. If you can't fulfill the request with patches, set confidence to 0 and explain why

## Confidence Guidelines
- 1.0: Unambiguous request, clear mapping to patches
- 0.8-0.9: High confidence but minor ambiguity
- 0.6-0.8: Moderate confidence, multiple valid interpretations
- 0.4-0.6: Low confidence, significant ambiguity
- 0.0-0.4: Cannot confidently fulfill request
''';

  /// User prompt template for patch mode
  static String patchModeUser(String prompt, PatchContext context) {
    return '''
${context.toPromptString()}

## User Request
$prompt
''';
  }
}
```

### 4. Patch Validation

```dart
/// Validates AI-generated patches before application
class PatchValidator {
  final EditorDocument document;

  PatchValidator(this.document);

  /// Validate a list of patches
  ValidationResult validate(List<PatchOp> patches) {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    for (var i = 0; i < patches.length; i++) {
      final patch = patches[i];
      final patchErrors = _validatePatch(patch, i);
      errors.addAll(patchErrors);

      final patchWarnings = _checkWarnings(patch, i);
      warnings.addAll(patchWarnings);
    }

    return ValidationResult(
      valid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  List<ValidationError> _validatePatch(PatchOp patch, int index) {
    return switch (patch) {
      SetProp p => _validateSetProp(p, index),
      DeleteProp p => _validateDeleteProp(p, index),
      InsertNode p => _validateInsertNode(p, index),
      DeleteNode p => _validateDeleteNode(p, index),
      AttachChild p => _validateAttachChild(p, index),
      DetachChild p => _validateDetachChild(p, index),
      MoveNode p => _validateMoveNode(p, index),
      Batch p => p.ops.expand((op) => _validatePatch(op, index)).toList(),
      _ => [],
    };
  }

  List<ValidationError> _validateSetProp(SetProp patch, int index) {
    final errors = <ValidationError>[];

    // Check target exists
    if (!document.nodes.containsKey(patch.id) &&
        !document.frames.containsKey(patch.id)) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'TARGET_NOT_FOUND',
        message: 'Node or frame "${patch.id}" not found',
      ));
    }

    // Validate path format
    if (!patch.path.startsWith('/')) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'INVALID_PATH',
        message: 'Path must start with /: "${patch.path}"',
      ));
    }

    // Validate path exists on target
    if (document.nodes.containsKey(patch.id)) {
      final pathError = _validatePropertyPath(patch.id, patch.path);
      if (pathError != null) {
        errors.add(ValidationError(
          patchIndex: index,
          code: 'INVALID_PROPERTY_PATH',
          message: pathError,
        ));
      }
    }

    // Validate value type
    final valueError = _validateValueForPath(patch.path, patch.value);
    if (valueError != null) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'INVALID_VALUE_TYPE',
        message: valueError,
      ));
    }

    return errors;
  }

  List<ValidationError> _validateInsertNode(InsertNode patch, int index) {
    final errors = <ValidationError>[];

    // Check ID doesn't already exist
    if (document.nodes.containsKey(patch.node.id)) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'DUPLICATE_ID',
        message: 'Node ID "${patch.node.id}" already exists',
      ));
    }

    // Validate node structure
    final structureErrors = _validateNodeStructure(patch.node);
    errors.addAll(structureErrors.map((e) => ValidationError(
      patchIndex: index,
      code: 'INVALID_NODE_STRUCTURE',
      message: e,
    )));

    return errors;
  }

  List<ValidationError> _validateDeleteNode(DeleteNode patch, int index) {
    final errors = <ValidationError>[];

    // Check target exists
    if (!document.nodes.containsKey(patch.id)) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'TARGET_NOT_FOUND',
        message: 'Node "${patch.id}" not found',
      ));
    }

    // Check not a frame root
    for (final frame in document.frames.values) {
      if (frame.rootNodeId == patch.id) {
        errors.add(ValidationError(
          patchIndex: index,
          code: 'CANNOT_DELETE_ROOT',
          message: 'Cannot delete frame root node "${patch.id}"',
        ));
      }
    }

    return errors;
  }

  List<ValidationError> _validateAttachChild(AttachChild patch, int index) {
    final errors = <ValidationError>[];

    // Check parent exists
    if (!document.nodes.containsKey(patch.parentId)) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'PARENT_NOT_FOUND',
        message: 'Parent node "${patch.parentId}" not found',
      ));
    }

    // Check child exists (or will exist after earlier patches)
    // Note: This is simplified; real impl needs patch sequence awareness

    // Check parent is container type
    final parent = document.nodes[patch.parentId];
    if (parent != null && parent.type != NodeType.container) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'PARENT_NOT_CONTAINER',
        message: 'Parent "${patch.parentId}" is ${parent.type}, not container',
      ));
    }

    // Check for circular reference
    if (_wouldCreateCycle(patch.parentId, patch.childId)) {
      errors.add(ValidationError(
        patchIndex: index,
        code: 'CIRCULAR_REFERENCE',
        message: 'Attaching "${patch.childId}" to "${patch.parentId}" would create cycle',
      ));
    }

    return errors;
  }

  List<ValidationWarning> _checkWarnings(PatchOp patch, int index) {
    final warnings = <ValidationWarning>[];

    if (patch is DeleteNode) {
      // Warn if deleting node with children
      final node = document.nodes[patch.id];
      if (node != null && node.children.isNotEmpty) {
        warnings.add(ValidationWarning(
          patchIndex: index,
          code: 'DELETING_PARENT',
          message: 'Deleting "${patch.id}" will orphan ${node.children.length} children',
        ));
      }
    }

    if (patch is SetProp && patch.path.contains('fill/color')) {
      // Warn if overwriting token reference with raw value
      final node = document.nodes[patch.id];
      final currentValue = node?.style?.fill?.color;
      if (currentValue != null &&
          currentValue.startsWith('{') &&
          patch.value is String &&
          !(patch.value as String).startsWith('{')) {
        warnings.add(ValidationWarning(
          patchIndex: index,
          code: 'OVERWRITING_TOKEN',
          message: 'Replacing token reference "$currentValue" with raw value',
        ));
      }
    }

    return warnings;
  }

  bool _wouldCreateCycle(String parentId, String childId) {
    // Check if childId is an ancestor of parentId
    var current = parentId;
    final visited = <String>{};

    while (true) {
      if (visited.contains(current)) break;
      visited.add(current);

      if (current == childId) return true;

      // Find parent of current
      String? parentOfCurrent;
      for (final node in document.nodes.values) {
        if (node.children.contains(current)) {
          parentOfCurrent = node.id;
          break;
        }
      }

      if (parentOfCurrent == null) break;
      current = parentOfCurrent;
    }

    return false;
  }

  // Additional validation helpers...
}

class ValidationResult {
  final bool valid;
  final List<ValidationError> errors;
  final List<ValidationWarning> warnings;

  ValidationResult({
    required this.valid,
    required this.errors,
    required this.warnings,
  });
}

class ValidationError {
  final int patchIndex;
  final String code;
  final String message;

  ValidationError({
    required this.patchIndex,
    required this.code,
    required this.message,
  });
}

class ValidationWarning {
  final int patchIndex;
  final String code;
  final String message;

  ValidationWarning({
    required this.patchIndex,
    required this.code,
    required this.message,
  });
}
```

### 5. Confidence-Based UX

```dart
/// Determines UX flow based on patch confidence
enum PatchApplicationMode {
  /// >= 0.9: Auto-apply with toast notification
  autoApply,

  /// 0.7-0.9: Show preview, one-click apply
  previewApply,

  /// 0.5-0.7: Show preview with alternatives
  selectApply,

  /// < 0.5: Show warning, suggest rephrasing
  warn,
}

class PatchApplicationController {
  PatchApplicationMode getModeForConfidence(double confidence) {
    if (confidence >= 0.9) return PatchApplicationMode.autoApply;
    if (confidence >= 0.7) return PatchApplicationMode.previewApply;
    if (confidence >= 0.5) return PatchApplicationMode.selectApply;
    return PatchApplicationMode.warn;
  }

  /// Handle patch result based on confidence
  Future<void> handlePatchResult(
    PatchResult result,
    EditorDocumentStore store,
    BuildContext context,
  ) async {
    if (!result.success || result.patches == null) {
      _showError(context, result.error ?? 'Failed to generate patches');
      return;
    }

    // Validate patches
    final validator = PatchValidator(store.document);
    final validation = validator.validate(result.patches!);

    if (!validation.valid) {
      _showValidationErrors(context, validation);
      return;
    }

    final mode = getModeForConfidence(result.confidence);

    switch (mode) {
      case PatchApplicationMode.autoApply:
        _applyPatches(store, result.patches!, result.explanation);
        _showToast(context, result.explanation ?? 'Changes applied');
        break;

      case PatchApplicationMode.previewApply:
        final confirmed = await _showPreviewDialog(
          context,
          patches: result.patches!,
          explanation: result.explanation,
          warnings: validation.warnings,
        );
        if (confirmed) {
          _applyPatches(store, result.patches!, result.explanation);
        }
        break;

      case PatchApplicationMode.selectApply:
        final selected = await _showAlternativesDialog(
          context,
          primary: result,
          alternatives: result.alternatives ?? [],
        );
        if (selected != null) {
          _applyPatches(store, selected.patches!, selected.explanation);
        }
        break;

      case PatchApplicationMode.warn:
        await _showLowConfidenceWarning(
          context,
          explanation: result.explanation,
          confidence: result.confidence,
        );
        break;
    }
  }

  void _applyPatches(
    EditorDocumentStore store,
    List<PatchOp> patches,
    String? explanation,
  ) {
    // Wrap in batch for single undo
    store.applyPatches(
      [Batch(ops: patches)],
      coalesce: false,
    );
  }

  // Dialog implementations...
}
```

### 6. Mode Selection Logic

```dart
/// Determines whether to use patch mode or generation mode
class AIModeSelector {
  /// Analyze prompt to determine best mode
  AIMode selectMode({
    required String prompt,
    required List<String> selectedNodeIds,
    required EditorDocument document,
  }) {
    // No selection → generation mode (creating new content)
    if (selectedNodeIds.isEmpty) {
      return AIMode.generate;
    }

    // Check prompt intent
    final intent = _analyzePromptIntent(prompt);

    switch (intent) {
      case PromptIntent.createNew:
        return AIMode.generate;

      case PromptIntent.modifyProperty:
      case PromptIntent.modifyStructure:
        return AIMode.patch;

      case PromptIntent.majorRedesign:
        return AIMode.update; // Full regeneration of frame

      case PromptIntent.ambiguous:
        // Default to patch for selected content
        return AIMode.patch;
    }
  }

  PromptIntent _analyzePromptIntent(String prompt) {
    final lower = prompt.toLowerCase();

    // Creation keywords
    if (_containsAny(lower, ['create', 'add', 'new', 'generate', 'build'])) {
      // But "add X to Y" might be structural patch
      if (_containsAny(lower, [' to ', ' into ', ' inside '])) {
        return PromptIntent.modifyStructure;
      }
      return PromptIntent.createNew;
    }

    // Property modification keywords
    if (_containsAny(lower, [
      'make', 'change', 'set', 'update', 'modify',
      'color', 'blue', 'red', 'size', 'bigger', 'smaller',
      'padding', 'margin', 'gap', 'rounded', 'bold',
    ])) {
      return PromptIntent.modifyProperty;
    }

    // Structural keywords
    if (_containsAny(lower, [
      'move', 'remove', 'delete', 'swap', 'reorder',
      'wrap', 'unwrap', 'group', 'ungroup',
    ])) {
      return PromptIntent.modifyStructure;
    }

    // Major redesign keywords
    if (_containsAny(lower, [
      'redesign', 'redo', 'remake', 'completely',
      'from scratch', 'replace all',
    ])) {
      return PromptIntent.majorRedesign;
    }

    return PromptIntent.ambiguous;
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }
}

enum AIMode {
  generate,  // Create new frame
  patch,     // Surgical edit
  update,    // Full frame regeneration
}

enum PromptIntent {
  createNew,
  modifyProperty,
  modifyStructure,
  majorRedesign,
  ambiguous,
}
```

---

## Test Plan

### Unit Tests

```dart
group('PatchContextCompiler', () {
  test('filters tokens based on prompt content', () {
    final theme = createTestTheme();

    final colorContext = PatchContextCompiler.compile(
      document: createTestDocument(),
      selectedNodeIds: ['n_button'],
      focusedFrameId: 'frame_1',
      theme: theme,
      recentEdits: [],
      prompt: 'make it blue',
    );

    expect(colorContext.tokens.colors, isNotEmpty);
    expect(colorContext.tokens.spacing, isEmpty);
  });

  test('builds ancestor context correctly', () {
    final document = createNestedDocument();

    final context = PatchContextCompiler.compile(
      document: document,
      selectedNodeIds: ['n_deeply_nested'],
      focusedFrameId: 'frame_1',
      theme: ThemeDocument.empty(),
      recentEdits: [],
      prompt: 'test',
    );

    expect(context.ancestors.length, greaterThan(0));
    expect(context.ancestors.first.id, equals('n_parent'));
  });
});

group('PatchValidator', () {
  test('rejects SetProp on non-existent node', () {
    final validator = PatchValidator(createTestDocument());

    final result = validator.validate([
      SetProp(id: 'n_nonexistent', path: '/style/fill/color', value: '#FF0000'),
    ]);

    expect(result.valid, isFalse);
    expect(result.errors.first.code, equals('TARGET_NOT_FOUND'));
  });

  test('rejects circular reference in AttachChild', () {
    final document = createTestDocument();
    final validator = PatchValidator(document);

    // Try to attach parent to child
    final result = validator.validate([
      AttachChild(parentId: 'n_child', childId: 'n_parent', index: 0),
    ]);

    expect(result.valid, isFalse);
    expect(result.errors.first.code, equals('CIRCULAR_REFERENCE'));
  });

  test('warns when overwriting token reference', () {
    final document = createDocumentWithTokens();
    final validator = PatchValidator(document);

    final result = validator.validate([
      SetProp(id: 'n_button', path: '/style/fill/color', value: '#FF0000'),
    ]);

    expect(result.valid, isTrue);
    expect(result.warnings.any((w) => w.code == 'OVERWRITING_TOKEN'), isTrue);
  });

  test('rejects deleting frame root', () {
    final document = createTestDocument();
    final validator = PatchValidator(document);

    final result = validator.validate([
      DeleteNode(id: document.frames.values.first.rootNodeId),
    ]);

    expect(result.valid, isFalse);
    expect(result.errors.first.code, equals('CANNOT_DELETE_ROOT'));
  });
});

group('AIModeSelector', () {
  test('selects generate mode for no selection', () {
    final selector = AIModeSelector();

    final mode = selector.selectMode(
      prompt: 'create a login form',
      selectedNodeIds: [],
      document: createTestDocument(),
    );

    expect(mode, equals(AIMode.generate));
  });

  test('selects patch mode for property changes', () {
    final selector = AIModeSelector();

    final mode = selector.selectMode(
      prompt: 'make the button blue',
      selectedNodeIds: ['n_button'],
      document: createTestDocument(),
    );

    expect(mode, equals(AIMode.patch));
  });

  test('selects patch mode for structural changes', () {
    final selector = AIModeSelector();

    final mode = selector.selectMode(
      prompt: 'add a subtitle below the title',
      selectedNodeIds: ['n_title'],
      document: createTestDocument(),
    );

    expect(mode, equals(AIMode.patch));
  });
});

group('PatchApplicationController', () {
  test('auto-applies high confidence patches', () async {
    final controller = PatchApplicationController();
    final store = createMockStore();

    await controller.handlePatchResult(
      PatchResult(
        success: true,
        patches: [SetProp(id: 'n_button', path: '/style/fill/color', value: '#007AFF')],
        explanation: 'Changed to blue',
        confidence: 0.95,
        usage: TokenUsage(promptTokens: 100, completionTokens: 50, totalTokens: 150),
      ),
      store,
      MockBuildContext(),
    );

    expect(store.patchesApplied, isTrue);
  });

  test('shows preview for medium confidence', () async {
    final controller = PatchApplicationController();
    final dialogShown = Completer<bool>();

    // Mock dialog to return true
    controller.showPreviewDialog = (_) async {
      dialogShown.complete(true);
      return true;
    };

    await controller.handlePatchResult(
      PatchResult(
        success: true,
        patches: [...],
        confidence: 0.75,
        usage: TokenUsage(...),
      ),
      createMockStore(),
      MockBuildContext(),
    );

    expect(await dialogShown.future, isTrue);
  });
});
```

### Integration Tests

```dart
group('AI Patch Mode Integration', () {
  test('end-to-end property change flow', () async {
    final service = AIEditingService.create(mockClient: true);
    final document = createTestDocument();
    final store = EditorDocumentStore(document);

    // Compile context
    final context = PatchContextCompiler.compile(
      document: document,
      selectedNodeIds: ['n_button'],
      focusedFrameId: 'frame_1',
      theme: ThemeDocument.empty(),
      recentEdits: [],
      prompt: 'make the button blue',
    );

    // Generate patches
    final result = await service.generatePatches(
      prompt: 'make the button blue',
      context: context,
    );

    expect(result.success, isTrue);
    expect(result.patches, isNotEmpty);

    // Validate
    final validator = PatchValidator(document);
    final validation = validator.validate(result.patches!);
    expect(validation.valid, isTrue);

    // Apply
    store.applyPatches([Batch(ops: result.patches!)]);

    // Verify
    final updatedButton = store.document.nodes['n_button']!;
    expect(updatedButton.style?.fill?.color, contains('blue') || equals('#007AFF'));
  });

  test('fallback to generation on patch failure', () async {
    final service = AIEditingService.create(mockClient: true);

    // First try patch mode
    final patchResult = await service.generatePatches(
      prompt: 'completely redesign this screen',
      context: createPatchContext(),
    );

    // Low confidence should trigger fallback
    expect(patchResult.confidence, lessThan(0.5));

    // Fall back to update mode
    final updateResult = await service.updateFrame(
      prompt: 'completely redesign this screen',
      context: createUpdateContext(),
    );

    expect(updateResult.success, isTrue);
  });
});
```

### Eval Harness

```dart
/// Evaluation harness for AI patch quality
class PatchEvalHarness {
  final List<EvalCase> cases;
  final AIEditingService service;

  PatchEvalHarness({
    required this.cases,
    required this.service,
  });

  Future<EvalReport> run() async {
    final results = <EvalResult>[];

    for (final testCase in cases) {
      final result = await _evaluateCase(testCase);
      results.add(result);
    }

    return EvalReport(
      totalCases: cases.length,
      passed: results.where((r) => r.passed).length,
      failed: results.where((r) => !r.passed).length,
      averageConfidence: results.map((r) => r.confidence).average,
      averageTokens: results.map((r) => r.tokensUsed).average,
      results: results,
    );
  }

  Future<EvalResult> _evaluateCase(EvalCase testCase) async {
    final context = PatchContextCompiler.compile(
      document: testCase.document,
      selectedNodeIds: testCase.selectedNodeIds,
      focusedFrameId: testCase.frameId,
      theme: testCase.theme,
      recentEdits: [],
      prompt: testCase.prompt,
    );

    final result = await service.generatePatches(
      prompt: testCase.prompt,
      context: context,
    );

    // Check expectations
    final passed = _checkExpectations(result, testCase.expectations);

    return EvalResult(
      caseId: testCase.id,
      passed: passed,
      confidence: result.confidence,
      tokensUsed: result.usage.totalTokens,
      patches: result.patches,
      explanation: result.explanation,
      expectedPatches: testCase.expectations.expectedPatches,
    );
  }

  bool _checkExpectations(PatchResult result, EvalExpectations expectations) {
    if (!result.success) return false;
    if (result.patches == null) return false;

    // Check required patch operations are present
    for (final expected in expectations.expectedPatches) {
      final found = result.patches!.any((p) => _matchesPatch(p, expected));
      if (!found) return false;
    }

    // Check no forbidden operations
    for (final forbidden in expectations.forbiddenPatches) {
      final found = result.patches!.any((p) => _matchesPatch(p, forbidden));
      if (found) return false;
    }

    // Check confidence threshold
    if (result.confidence < expectations.minConfidence) return false;

    return true;
  }
}

class EvalCase {
  final String id;
  final String prompt;
  final EditorDocument document;
  final List<String> selectedNodeIds;
  final String frameId;
  final ThemeDocument theme;
  final EvalExpectations expectations;

  EvalCase({...});
}

class EvalExpectations {
  final List<PatchMatcher> expectedPatches;
  final List<PatchMatcher> forbiddenPatches;
  final double minConfidence;

  EvalExpectations({...});
}
```

---

## Implementation Order

1. **Phase 1: Infrastructure**
   - [ ] Define `PatchResult` and `PatchContext` models
   - [ ] Implement `PatchContextCompiler`
   - [ ] Create prompt templates
   - [ ] Unit test context compilation

2. **Phase 2: Validation**
   - [ ] Implement `PatchValidator`
   - [ ] Add all validation rules
   - [ ] Unit test validation

3. **Phase 3: AI Integration**
   - [ ] Add `generatePatches` to `AIEditingService`
   - [ ] Implement mode selection logic
   - [ ] Create mock client for testing
   - [ ] Integration test with mock

4. **Phase 4: UX**
   - [ ] Implement confidence-based UX flow
   - [ ] Create preview dialog
   - [ ] Create alternatives dialog
   - [ ] Add toast notifications

5. **Phase 5: Eval Harness**
   - [ ] Create eval case fixtures
   - [ ] Implement eval harness
   - [ ] Run baseline evaluation
   - [ ] Iterate on prompts

---

## File Locations

```
lib/src/free_design/
├── ai/
│   ├── ai_editing_service.dart        # Service interface
│   ├── patch_context_compiler.dart    # Context compilation
│   ├── patch_validator.dart           # Patch validation
│   ├── ai_mode_selector.dart          # Mode selection
│   ├── ai_prompt_templates.dart       # Prompt templates
│   ├── patch_application_controller.dart
│   └── clients/
│       ├── anthropic_client.dart
│       └── mock_client.dart
└── ...

test/free_design/
├── ai/
│   ├── patch_context_compiler_test.dart
│   ├── patch_validator_test.dart
│   ├── ai_mode_selector_test.dart
│   └── patch_integration_test.dart
└── ...

eval/
├── fixtures/
│   ├── documents/
│   └── prompts/
├── patch_eval_harness.dart
└── run_eval.dart
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| AI generates invalid patches | High | Medium | Validation before application |
| AI misunderstands intent | Medium | Medium | Confidence thresholds + alternatives |
| Token efficiency not achieved | Medium | Low | Aggressive context filtering |
| Fallback overused | Medium | Low | Tune mode selection heuristics |

---

## Future Enhancements (Not in Scope)

1. **Multi-turn patch conversations** - "No, make it darker"
2. **Patch streaming** - Apply patches as they're generated
3. **Learning from corrections** - Improve from user edits
4. **Patch explanations in UI** - Show diff view of changes
