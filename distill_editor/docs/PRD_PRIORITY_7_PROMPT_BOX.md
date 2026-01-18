# PRD: Priority 7 - Prompt Box Improvements

## Overview

The prompt box is the primary interface for AI collaboration. Currently it's basic and intrusive. This improvement makes the AI feel integrated rather than bolted-on by making the prompt input contextual, compact, and informative.

**Status:** Basic implementation exists
**Dependencies:** Priority 5 (AI Patch Mode) - Should be complete for full benefit
**Estimated Complexity:** Medium

---

## Problem Statement

Current prompt box issues:

1. **Large/intrusive**: Takes significant screen space
2. **Fixed position**: Not contextual to selection
3. **No scope indication**: User doesn't know what AI will affect
4. **No history**: Can't recall previous prompts
5. **Poor feedback**: Minimal loading/error states
6. **No mode indication**: Unclear if generating or patching

Users can't tell:
- What the AI will modify
- If their request will work
- What they asked before
- What's happening during generation

---

## Goals

1. **Compact input**: Minimal footprint that expands on focus
2. **Contextual positioning**: Appears near current selection
3. **Scope indicator**: Shows what AI will modify
4. **History access**: Recall recent prompts with Up arrow
5. **Clear states**: Loading, error, success feedback
6. **Mode awareness**: Indicates generation vs patch mode

---

## Non-Goals (Out of Scope)

- Voice input
- Prompt suggestions/autocomplete
- Multi-turn conversation UI
- Prompt templates library
- Collaborative prompts (sharing)

---

## Success Criteria

| Criterion | Metric | Validation Method |
|-----------|--------|-------------------|
| Compact initial state | Single line, <200px wide | Manual test |
| Expands on focus | Multi-line capability | Manual test |
| Positioned near selection | Within 200px of selection bounds | Manual test |
| Shows editing scope | "Editing: [name]" visible | Manual test |
| Up arrow recalls history | Previous prompts accessible | Unit test |
| Loading state shows spinner | Visual indicator during generation | Manual test |
| Error state shows message | Clear error with retry option | Manual test |
| Mode indicator | Shows "Generate" or "Edit" | Manual test |

---

## Technical Architecture

### 1. Prompt Box State

```dart
/// State management for contextual prompt box
class PromptBoxState extends ChangeNotifier {
  /// Input visibility
  bool _isVisible = false;

  /// Input focus state
  bool _isFocused = false;

  /// Current input text
  String _inputText = '';

  /// Prompt history
  final List<PromptHistoryEntry> _history = [];
  int _historyIndex = -1;

  /// Current AI mode
  AIMode _currentMode = AIMode.generate;

  /// Loading state
  bool _isLoading = false;

  /// Error state
  String? _error;

  /// Target scope description
  String? _scopeDescription;

  /// Position for contextual placement
  Offset? _position;

  // Getters
  bool get isVisible => _isVisible;
  bool get isFocused => _isFocused;
  bool get isExpanded => _isFocused || _inputText.isNotEmpty;
  String get inputText => _inputText;
  AIMode get currentMode => _currentMode;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get scopeDescription => _scopeDescription;
  Offset? get position => _position;
  List<PromptHistoryEntry> get history => List.unmodifiable(_history);

  /// Show prompt box at position
  void show({
    required Offset position,
    required String scopeDescription,
    required AIMode mode,
  }) {
    _isVisible = true;
    _position = position;
    _scopeDescription = scopeDescription;
    _currentMode = mode;
    _error = null;
    notifyListeners();
  }

  /// Hide prompt box
  void hide() {
    _isVisible = false;
    _isFocused = false;
    _inputText = '';
    _historyIndex = -1;
    _error = null;
    notifyListeners();
  }

  /// Update focus state
  void setFocused(bool focused) {
    _isFocused = focused;
    notifyListeners();
  }

  /// Update input text
  void setInputText(String text) {
    _inputText = text;
    _historyIndex = -1; // Reset history navigation
    notifyListeners();
  }

  /// Navigate history (returns new text or null if no history)
  String? navigateHistory(HistoryDirection direction) {
    if (_history.isEmpty) return null;

    if (direction == HistoryDirection.up) {
      if (_historyIndex < _history.length - 1) {
        _historyIndex++;
      }
    } else {
      if (_historyIndex > 0) {
        _historyIndex--;
      } else if (_historyIndex == 0) {
        _historyIndex = -1;
        return ''; // Return to empty input
      }
    }

    if (_historyIndex >= 0 && _historyIndex < _history.length) {
      return _history[_historyIndex].prompt;
    }

    return null;
  }

  /// Add prompt to history
  void addToHistory(String prompt, {bool success = true}) {
    // Don't add duplicates
    if (_history.isNotEmpty && _history.first.prompt == prompt) {
      return;
    }

    _history.insert(0, PromptHistoryEntry(
      prompt: prompt,
      timestamp: DateTime.now(),
      success: success,
    ));

    // Limit history size
    if (_history.length > 50) {
      _history.removeLast();
    }
  }

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _error = null;
    }
    notifyListeners();
  }

  /// Set error state
  void setError(String? error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  /// Update mode based on context
  void updateMode(AIMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

enum HistoryDirection { up, down }

class PromptHistoryEntry {
  final String prompt;
  final DateTime timestamp;
  final bool success;

  PromptHistoryEntry({
    required this.prompt,
    required this.timestamp,
    required this.success,
  });
}

enum AIMode {
  generate,  // Creating new content
  patch,     // Modifying selected content
  update,    // Regenerating frame
}
```

### 2. Contextual Position Calculator

```dart
/// Calculates optimal position for prompt box
class PromptBoxPositionCalculator {
  static const double promptBoxWidth = 320;
  static const double promptBoxMinHeight = 44;
  static const double padding = 16;

  /// Calculate position near selection
  static Offset calculate({
    required Rect? selectionBounds,
    required Size viewportSize,
    required InfiniteCanvasController canvasController,
  }) {
    // Default: center-bottom of viewport
    if (selectionBounds == null) {
      return Offset(
        (viewportSize.width - promptBoxWidth) / 2,
        viewportSize.height - 100,
      );
    }

    // Convert selection bounds to view coordinates
    final viewBounds = _worldToViewBounds(selectionBounds, canvasController);

    // Try positions in priority order:
    // 1. Below selection (preferred)
    // 2. Above selection
    // 3. Right of selection
    // 4. Left of selection

    final positions = [
      _belowPosition(viewBounds, viewportSize),
      _abovePosition(viewBounds, viewportSize),
      _rightPosition(viewBounds, viewportSize),
      _leftPosition(viewBounds, viewportSize),
    ];

    // Return first position that fits
    for (final pos in positions) {
      if (_fitsInViewport(pos, viewportSize)) {
        return pos;
      }
    }

    // Fallback: constrained center-bottom
    return Offset(
      (viewportSize.width - promptBoxWidth) / 2,
      viewportSize.height - 100,
    ).clamp(viewportSize);
  }

  static Offset _belowPosition(Rect viewBounds, Size viewport) {
    return Offset(
      (viewBounds.left + viewBounds.right - promptBoxWidth) / 2,
      viewBounds.bottom + padding,
    );
  }

  static Offset _abovePosition(Rect viewBounds, Size viewport) {
    return Offset(
      (viewBounds.left + viewBounds.right - promptBoxWidth) / 2,
      viewBounds.top - promptBoxMinHeight - padding,
    );
  }

  static Offset _rightPosition(Rect viewBounds, Size viewport) {
    return Offset(
      viewBounds.right + padding,
      (viewBounds.top + viewBounds.bottom - promptBoxMinHeight) / 2,
    );
  }

  static Offset _leftPosition(Rect viewBounds, Size viewport) {
    return Offset(
      viewBounds.left - promptBoxWidth - padding,
      (viewBounds.top + viewBounds.bottom - promptBoxMinHeight) / 2,
    );
  }

  static bool _fitsInViewport(Offset position, Size viewport) {
    return position.dx >= padding &&
           position.dx + promptBoxWidth <= viewport.width - padding &&
           position.dy >= padding &&
           position.dy + promptBoxMinHeight <= viewport.height - padding;
  }

  static Rect _worldToViewBounds(Rect world, InfiniteCanvasController controller) {
    final topLeft = controller.worldToView(world.topLeft);
    final bottomRight = controller.worldToView(world.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight);
  }
}

extension OffsetClamp on Offset {
  Offset clamp(Size viewport) {
    return Offset(
      dx.clamp(PromptBoxPositionCalculator.padding,
               viewport.width - PromptBoxPositionCalculator.promptBoxWidth - PromptBoxPositionCalculator.padding),
      dy.clamp(PromptBoxPositionCalculator.padding,
               viewport.height - PromptBoxPositionCalculator.promptBoxMinHeight - PromptBoxPositionCalculator.padding),
    );
  }
}
```

### 3. Prompt Box Widget

```dart
/// Contextual prompt input widget
class ContextualPromptBox extends StatefulWidget {
  final PromptBoxState state;
  final CanvasState canvasState;
  final EditorDocumentStore documentStore;
  final AIEditingService aiService;
  final InfiniteCanvasController canvasController;

  const ContextualPromptBox({
    super.key,
    required this.state,
    required this.canvasState,
    required this.documentStore,
    required this.aiService,
    required this.canvasController,
  });

  @override
  State<ContextualPromptBox> createState() => _ContextualPromptBoxState();
}

class _ContextualPromptBoxState extends State<ContextualPromptBox>
    with SingleTickerProviderStateMixin {

  late TextEditingController _textController;
  late FocusNode _focusNode;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    _expandController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOut,
    );

    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    widget.state.setFocused(_focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _expandController.forward();
    } else if (_textController.text.isEmpty) {
      _expandController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        if (!widget.state.isVisible) {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: widget.state.position?.dx ?? 0,
          top: widget.state.position?.dy ?? 0,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) => _buildPromptBox(),
          ),
        );
      },
    );
  }

  Widget _buildPromptBox() {
    final isExpanded = widget.state.isExpanded;
    final isLoading = widget.state.isLoading;
    final error = widget.state.error;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isExpanded ? 360 : 280,
        constraints: BoxConstraints(
          minHeight: 44,
          maxHeight: isExpanded ? 200 : 44,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: error != null
                ? Colors.red.shade300
                : _focusNode.hasFocus
                    ? Colors.blue
                    : Colors.grey.shade300,
            width: _focusNode.hasFocus ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scope indicator
            if (isExpanded) _buildScopeIndicator(),

            // Input row
            _buildInputRow(isLoading),

            // Error message
            if (error != null) _buildErrorMessage(error),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeIndicator() {
    final scope = widget.state.scopeDescription;
    final mode = widget.state.currentMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // Mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _modeColor(mode).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _modeLabel(mode),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _modeColor(mode),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Scope description
          Expanded(
            child: Text(
              scope ?? 'New frame',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // AI icon
          Icon(
            Icons.auto_awesome,
            size: 18,
            color: Colors.purple.shade400,
          ),

          const SizedBox(width: 8),

          // Text input
          Expanded(
            child: Focus(
              onKeyEvent: _handleKeyEvent,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !isLoading,
                maxLines: widget.state.isExpanded ? 4 : 1,
                minLines: 1,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _hintText(),
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _submit(),
                onChanged: (text) => widget.state.setInputText(text),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Submit button or loading
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.purple.shade400,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.send),
              iconSize: 18,
              color: _textController.text.isNotEmpty
                  ? Colors.purple.shade400
                  : Colors.grey.shade300,
              onPressed: _textController.text.isNotEmpty ? _submit : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 14,
            color: Colors.red.shade400,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _submit,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 24),
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Escape to close
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.state.hide();
      return KeyEventResult.handled;
    }

    // Up arrow for history
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        _textController.selection.start == 0) {
      final historyText = widget.state.navigateHistory(HistoryDirection.up);
      if (historyText != null) {
        _textController.text = historyText;
        _textController.selection = TextSelection.collapsed(
          offset: historyText.length,
        );
        return KeyEventResult.handled;
      }
    }

    // Down arrow for history
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final historyText = widget.state.navigateHistory(HistoryDirection.down);
      if (historyText != null) {
        _textController.text = historyText;
        _textController.selection = TextSelection.collapsed(
          offset: historyText.length,
        );
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _submit() async {
    final prompt = _textController.text.trim();
    if (prompt.isEmpty) return;

    widget.state.setLoading(true);
    widget.state.clearError();

    try {
      // Determine mode and execute
      final mode = widget.state.currentMode;

      if (mode == AIMode.patch) {
        await _executePatch(prompt);
      } else if (mode == AIMode.update) {
        await _executeUpdate(prompt);
      } else {
        await _executeGenerate(prompt);
      }

      // Success
      widget.state.addToHistory(prompt, success: true);
      _textController.clear();
      widget.state.hide();

    } catch (e) {
      widget.state.setError(e.toString());
      widget.state.addToHistory(prompt, success: false);
    } finally {
      widget.state.setLoading(false);
    }
  }

  Future<void> _executePatch(String prompt) async {
    final selectedNodeIds = widget.canvasState.selectedNodeIds.toList();

    final context = PatchContextCompiler.compile(
      document: widget.documentStore.document,
      selectedNodeIds: selectedNodeIds,
      focusedFrameId: widget.canvasState.focusedFrameId,
      theme: widget.documentStore.document.theme,
      recentEdits: [], // TODO: Track recent edits
      prompt: prompt,
    );

    final result = await widget.aiService.generatePatches(
      prompt: prompt,
      context: context,
    );

    if (!result.success || result.patches == null) {
      throw Exception(result.error ?? 'Failed to generate patches');
    }

    // Validate and apply
    final validator = PatchValidator(widget.documentStore.document);
    final validation = validator.validate(result.patches!);

    if (!validation.valid) {
      throw Exception(validation.errors.first.message);
    }

    widget.documentStore.applyPatches([Batch(ops: result.patches!)]);
  }

  Future<void> _executeUpdate(String prompt) async {
    // TODO: Implement update mode
    throw UnimplementedError('Update mode not yet implemented');
  }

  Future<void> _executeGenerate(String prompt) async {
    // TODO: Implement generate mode
    throw UnimplementedError('Generate mode not yet implemented');
  }

  String _hintText() {
    switch (widget.state.currentMode) {
      case AIMode.generate:
        return 'Describe what to create...';
      case AIMode.patch:
        return 'Describe the change...';
      case AIMode.update:
        return 'Describe the update...';
    }
  }

  String _modeLabel(AIMode mode) {
    switch (mode) {
      case AIMode.generate:
        return 'CREATE';
      case AIMode.patch:
        return 'EDIT';
      case AIMode.update:
        return 'UPDATE';
    }
  }

  Color _modeColor(AIMode mode) {
    switch (mode) {
      case AIMode.generate:
        return Colors.green;
      case AIMode.patch:
        return Colors.blue;
      case AIMode.update:
        return Colors.orange;
    }
  }
}
```

### 4. Keyboard Shortcut Integration

```dart
/// Keyboard shortcut handler for prompt box
class PromptBoxShortcutHandler {
  final PromptBoxState promptBoxState;
  final CanvasState canvasState;
  final EditorDocumentStore documentStore;
  final InfiniteCanvasController canvasController;
  final AIModeSelector modeSelector;

  PromptBoxShortcutHandler({
    required this.promptBoxState,
    required this.canvasState,
    required this.documentStore,
    required this.canvasController,
    required this.modeSelector,
  });

  /// Handle keyboard shortcut to open prompt box
  bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // Cmd/Ctrl + K to open prompt box
    final isModifier = HardwareKeyboard.instance.isMetaPressed ||
                       HardwareKeyboard.instance.isControlPressed;

    if (isModifier && event.logicalKey == LogicalKeyboardKey.keyK) {
      _openPromptBox();
      return true;
    }

    return false;
  }

  void _openPromptBox() {
    // Determine mode based on selection
    final selectedNodeIds = canvasState.selectedNodeIds.toList();
    final mode = modeSelector.selectMode(
      prompt: '', // Will be filled by user
      selectedNodeIds: selectedNodeIds,
      document: documentStore.document,
    );

    // Calculate scope description
    final scopeDescription = _getScopeDescription(selectedNodeIds);

    // Calculate position
    final viewportSize = _getViewportSize();
    final selectionBounds = _getSelectionBounds(selectedNodeIds);

    final position = PromptBoxPositionCalculator.calculate(
      selectionBounds: selectionBounds,
      viewportSize: viewportSize,
      canvasController: canvasController,
    );

    promptBoxState.show(
      position: position,
      scopeDescription: scopeDescription,
      mode: mode,
    );
  }

  String _getScopeDescription(List<String> selectedNodeIds) {
    if (selectedNodeIds.isEmpty) {
      final frameId = canvasState.focusedFrameId;
      if (frameId != null) {
        final frame = documentStore.document.frames[frameId];
        return 'Frame: ${frame?.name ?? frameId}';
      }
      return 'New frame';
    }

    if (selectedNodeIds.length == 1) {
      final node = documentStore.document.nodes[selectedNodeIds.first];
      if (node != null) {
        final name = node.props.text ?? node.type.name;
        return '${node.type.name}: ${_truncate(name, 20)}';
      }
    }

    return '${selectedNodeIds.length} selected';
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  Rect? _getSelectionBounds(List<String> nodeIds) {
    if (nodeIds.isEmpty) return null;

    final bounds = nodeIds
        .map((id) => canvasState.getNodeBounds(id))
        .whereType<Rect>()
        .toList();

    if (bounds.isEmpty) return null;

    return bounds.reduce((a, b) => a.expandToInclude(b));
  }

  Size _getViewportSize() {
    // TODO: Get actual viewport size from canvas
    return const Size(1200, 800);
  }
}
```

### 5. History Persistence

```dart
/// Persists prompt history across sessions
class PromptHistoryPersistence {
  static const _key = 'prompt_history';
  static const _maxEntries = 50;

  final SharedPreferences _prefs;

  PromptHistoryPersistence(this._prefs);

  /// Load history from storage
  List<PromptHistoryEntry> load() {
    final json = _prefs.getString(_key);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((e) => PromptHistoryEntry(
                prompt: e['prompt'] as String,
                timestamp: DateTime.parse(e['timestamp'] as String),
                success: e['success'] as bool? ?? true,
              ))
          .take(_maxEntries)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save history to storage
  Future<void> save(List<PromptHistoryEntry> history) async {
    final list = history.take(_maxEntries).map((e) => {
      'prompt': e.prompt,
      'timestamp': e.timestamp.toIso8601String(),
      'success': e.success,
    }).toList();

    await _prefs.setString(_key, jsonEncode(list));
  }
}
```

---

## UI/UX Specifications

### Visual States

| State | Appearance |
|-------|------------|
| **Collapsed** | 280px wide, single line, hint text, AI icon |
| **Focused** | 360px wide, blue border, up to 4 lines |
| **Loading** | Disabled input, spinning indicator |
| **Error** | Red border, error message, retry button |

### Positioning Rules

1. **Primary**: Below selection, horizontally centered
2. **Fallback 1**: Above selection if no room below
3. **Fallback 2**: Right of selection
4. **Fallback 3**: Left of selection
5. **Default**: Center-bottom of viewport (no selection)

### Mode Indicators

| Mode | Color | Label | Description |
|------|-------|-------|-------------|
| Generate | Green | CREATE | Creating new content |
| Patch | Blue | EDIT | Modifying selected nodes |
| Update | Orange | UPDATE | Regenerating frame |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd/Ctrl+K | Open prompt box |
| Enter | Submit prompt |
| Escape | Close prompt box |
| Up Arrow | Previous history entry |
| Down Arrow | Next history entry |

---

## Test Plan

### Unit Tests

```dart
group('PromptBoxState', () {
  test('show sets all state correctly', () {
    final state = PromptBoxState();

    state.show(
      position: Offset(100, 200),
      scopeDescription: 'Button: Submit',
      mode: AIMode.patch,
    );

    expect(state.isVisible, isTrue);
    expect(state.position, equals(Offset(100, 200)));
    expect(state.scopeDescription, equals('Button: Submit'));
    expect(state.currentMode, equals(AIMode.patch));
  });

  test('hide clears all state', () {
    final state = PromptBoxState();
    state.show(position: Offset.zero, scopeDescription: '', mode: AIMode.generate);
    state.setInputText('test');
    state.setFocused(true);

    state.hide();

    expect(state.isVisible, isFalse);
    expect(state.inputText, isEmpty);
    expect(state.isFocused, isFalse);
  });

  test('navigateHistory returns previous prompts', () {
    final state = PromptBoxState();
    state.addToHistory('first prompt');
    state.addToHistory('second prompt');
    state.addToHistory('third prompt');

    expect(state.navigateHistory(HistoryDirection.up), equals('third prompt'));
    expect(state.navigateHistory(HistoryDirection.up), equals('second prompt'));
    expect(state.navigateHistory(HistoryDirection.up), equals('first prompt'));
  });

  test('navigateHistory wraps around', () {
    final state = PromptBoxState();
    state.addToHistory('only prompt');

    state.navigateHistory(HistoryDirection.up);
    expect(state.navigateHistory(HistoryDirection.down), equals(''));
  });

  test('addToHistory prevents duplicates', () {
    final state = PromptBoxState();
    state.addToHistory('same prompt');
    state.addToHistory('same prompt');

    expect(state.history.length, equals(1));
  });

  test('isExpanded when focused or has text', () {
    final state = PromptBoxState();

    expect(state.isExpanded, isFalse);

    state.setFocused(true);
    expect(state.isExpanded, isTrue);

    state.setFocused(false);
    expect(state.isExpanded, isFalse);

    state.setInputText('some text');
    expect(state.isExpanded, isTrue);
  });
});

group('PromptBoxPositionCalculator', () {
  test('positions below selection when space available', () {
    final position = PromptBoxPositionCalculator.calculate(
      selectionBounds: Rect.fromLTWH(200, 200, 100, 50),
      viewportSize: Size(800, 600),
      canvasController: createMockCanvasController(),
    );

    // Should be below selection
    expect(position.dy, greaterThan(250));
  });

  test('positions above selection when no room below', () {
    final position = PromptBoxPositionCalculator.calculate(
      selectionBounds: Rect.fromLTWH(200, 500, 100, 50), // Near bottom
      viewportSize: Size(800, 600),
      canvasController: createMockCanvasController(),
    );

    // Should be above selection
    expect(position.dy, lessThan(500));
  });

  test('centers in viewport when no selection', () {
    final position = PromptBoxPositionCalculator.calculate(
      selectionBounds: null,
      viewportSize: Size(800, 600),
      canvasController: createMockCanvasController(),
    );

    // Should be horizontally centered
    final expectedX = (800 - PromptBoxPositionCalculator.promptBoxWidth) / 2;
    expect(position.dx, closeTo(expectedX, 10));
  });
});

group('PromptHistoryPersistence', () {
  test('saves and loads history', () async {
    final prefs = await SharedPreferences.getInstance();
    final persistence = PromptHistoryPersistence(prefs);

    final history = [
      PromptHistoryEntry(
        prompt: 'test prompt',
        timestamp: DateTime.now(),
        success: true,
      ),
    ];

    await persistence.save(history);
    final loaded = persistence.load();

    expect(loaded.length, equals(1));
    expect(loaded.first.prompt, equals('test prompt'));
  });

  test('limits to max entries', () async {
    final prefs = await SharedPreferences.getInstance();
    final persistence = PromptHistoryPersistence(prefs);

    final history = List.generate(100, (i) => PromptHistoryEntry(
      prompt: 'prompt $i',
      timestamp: DateTime.now(),
      success: true,
    ));

    await persistence.save(history);
    final loaded = persistence.load();

    expect(loaded.length, equals(50));
  });
});
```

### Widget Tests

```dart
testWidgets('ContextualPromptBox shows scope indicator when expanded', (tester) async {
  final state = PromptBoxState();

  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          ContextualPromptBox(
            state: state,
            canvasState: createMockCanvasState(),
            documentStore: createMockDocumentStore(),
            aiService: createMockAIService(),
            canvasController: createMockCanvasController(),
          ),
        ],
      ),
    ),
  );

  state.show(
    position: Offset(100, 100),
    scopeDescription: 'Button: Submit',
    mode: AIMode.patch,
  );
  await tester.pump();

  // Focus the input
  await tester.tap(find.byType(TextField));
  await tester.pump();

  // Scope indicator should be visible
  expect(find.text('Button: Submit'), findsOneWidget);
  expect(find.text('EDIT'), findsOneWidget);
});

testWidgets('Escape closes prompt box', (tester) async {
  final state = PromptBoxState();

  await tester.pumpWidget(
    MaterialApp(
      home: ContextualPromptBox(
        state: state,
        canvasState: createMockCanvasState(),
        documentStore: createMockDocumentStore(),
        aiService: createMockAIService(),
        canvasController: createMockCanvasController(),
      ),
    ),
  );

  state.show(
    position: Offset(100, 100),
    scopeDescription: 'Test',
    mode: AIMode.generate,
  );
  await tester.pump();

  // Focus and press Escape
  await tester.tap(find.byType(TextField));
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();

  expect(state.isVisible, isFalse);
});

testWidgets('shows loading state during submission', (tester) async {
  final state = PromptBoxState();
  final completer = Completer<void>();

  final mockAIService = MockAIService();
  when(mockAIService.generatePatches(any, any))
      .thenAnswer((_) => completer.future.then((_) => createMockPatchResult()));

  await tester.pumpWidget(
    MaterialApp(
      home: ContextualPromptBox(
        state: state,
        canvasState: createMockCanvasState(),
        documentStore: createMockDocumentStore(),
        aiService: mockAIService,
        canvasController: createMockCanvasController(),
      ),
    ),
  );

  state.show(
    position: Offset(100, 100),
    scopeDescription: 'Test',
    mode: AIMode.patch,
  );
  await tester.pump();

  // Enter text and submit
  await tester.enterText(find.byType(TextField), 'make it blue');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();

  // Should show loading indicator
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Complete the request
  completer.complete();
  await tester.pump();
});
```

---

## Implementation Order

1. **Phase 1: State Management**
   - [ ] Create `PromptBoxState` class
   - [ ] Unit test state transitions
   - [ ] Implement history navigation

2. **Phase 2: Position Calculator**
   - [ ] Implement `PromptBoxPositionCalculator`
   - [ ] Unit test positioning logic
   - [ ] Handle edge cases (small viewport, edge selection)

3. **Phase 3: Core Widget**
   - [ ] Create `ContextualPromptBox` widget
   - [ ] Implement collapsed/expanded states
   - [ ] Add scope indicator
   - [ ] Add mode indicator
   - [ ] Widget tests

4. **Phase 4: Input Handling**
   - [ ] Implement keyboard shortcuts (Escape, history navigation)
   - [ ] Connect to AI service
   - [ ] Add loading state
   - [ ] Add error state with retry

5. **Phase 5: History**
   - [ ] Implement history persistence
   - [ ] Up/Down arrow navigation
   - [ ] Unit test persistence

6. **Phase 6: Integration**
   - [ ] Add Cmd+K shortcut
   - [ ] Wire to canvas selection
   - [ ] End-to-end testing

---

## File Locations

```
lib/src/free_design/
├── canvas/
│   ├── overlays/
│   │   ├── prompt_box_overlay.dart    # Updated
│   │   ├── prompt_box_state.dart      # NEW
│   │   └── prompt_box_position.dart   # NEW
│   └── ...
├── ai/
│   └── ...
└── ...

lib/services/
└── prompt_history_persistence.dart    # NEW

test/free_design/
├── canvas/
│   ├── overlays/
│   │   ├── prompt_box_state_test.dart
│   │   └── prompt_box_position_test.dart
│   └── prompt_box_widget_test.dart
└── services/
    └── prompt_history_persistence_test.dart
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Position calculation edge cases | Medium | Low | Extensive test coverage |
| History grows unbounded | Low | Low | Limit to 50 entries |
| Mode selection incorrect | Medium | Medium | Clear visual indicators |
| Focus management conflicts | Medium | Medium | Careful focus node handling |

---

## Future Enhancements (Not in Scope)

1. **Prompt suggestions**: Autocomplete based on history
2. **Prompt templates**: Pre-defined prompt patterns
3. **Multi-turn conversation**: Context-aware follow-ups
4. **Voice input**: Microphone capture
5. **Rich prompts**: Include images/references
