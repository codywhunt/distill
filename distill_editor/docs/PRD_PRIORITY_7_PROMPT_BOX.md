# PRD: Priority 7 - Prompt Box Improvements

## Overview

The prompt box is the primary interface for AI collaboration. A basic implementation exists and is functional, but several UX improvements are needed to make AI feel integrated rather than bolted-on.

**Status:** ~50% complete
**Implementation:** `prompt_box_overlay.dart` (928 lines)

---

## Current State

### What's Implemented ✅

| Feature | Status | Location |
|---------|--------|----------|
| Basic prompt box widget | ✅ Working | lines 31-49 |
| Text input with Enter/Escape | ✅ Working | lines 446-477 |
| Context chips (selection display) | ✅ Working | lines 409-576 |
| Model selection dropdown | ✅ Working | lines 902-928 |
| Loading state with spinner | ✅ Working | lines 798-829 |
| AI integration (generate/patch) | ✅ Working | lines 87-337 |
| Focus state styling | ✅ Working | lines 61-85 |
| Error callback to parent | ✅ Working | line 45 |

### What's Missing ❌

| Feature | Status | Notes |
|---------|--------|-------|
| Prompt history | ❌ Not started | No Up/Down arrow navigation |
| Contextual positioning | ❌ Not started | Fixed at bottom center |
| Scope indicator label | ❌ Not started | No "Editing: X" display |
| Mode badges (CREATE/EDIT) | ❌ Not started | No visual mode indication |
| Compact/expanded modes | ❌ Not started | Always same size |
| Persistent history | ❌ Not started | Lost on restart |
| Error display in box | ❌ Not started | Only callback, no UI |
| Cmd+K shortcut | ❌ Not started | No keyboard shortcut to open |

---

## Remaining Work

### 1. Prompt History (High Priority)

Enable recalling previous prompts with arrow keys.

**Implementation:**

```dart
// Add to PromptBoxOverlay state
final List<String> _history = [];
int _historyIndex = -1;
String _savedInput = '';  // Save current input when navigating

void _navigateHistory(HistoryDirection direction) {
  if (_history.isEmpty) return;

  if (direction == HistoryDirection.up) {
    if (_historyIndex == -1) {
      _savedInput = _textController.text;  // Save current input
    }
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _textController.text = _history[_historyIndex];
    }
  } else {
    if (_historyIndex > 0) {
      _historyIndex--;
      _textController.text = _history[_historyIndex];
    } else if (_historyIndex == 0) {
      _historyIndex = -1;
      _textController.text = _savedInput;  // Restore saved input
    }
  }
}

void _addToHistory(String prompt) {
  if (prompt.isEmpty) return;
  if (_history.isNotEmpty && _history.first == prompt) return;  // No duplicates
  _history.insert(0, prompt);
  if (_history.length > 50) _history.removeLast();
  _historyIndex = -1;
}
```

**Keyboard handling:**
```dart
// In text field's onKey handler
if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
  _navigateHistory(HistoryDirection.up);
  return KeyEventResult.handled;
}
if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
  _navigateHistory(HistoryDirection.down);
  return KeyEventResult.handled;
}
```

### 2. Scope Indicator (Medium Priority)

Show what the AI will modify.

**Add above text input:**
```dart
Widget _buildScopeIndicator() {
  final mode = _determineMode();
  final scopeText = _getScopeText();

  return Row(
    children: [
      // Mode badge
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _modeColor(mode).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          mode == AiMode.generate ? 'CREATE' : 'EDIT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _modeColor(mode),
          ),
        ),
      ),
      SizedBox(width: 8),
      // Scope text
      Text(
        scopeText,  // e.g., "Button: Submit" or "Frame: Login"
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    ],
  );
}

String _getScopeText() {
  final selected = widget.state.selectedNodeIds;
  if (selected.isEmpty) {
    final frame = widget.state.focusedFrame;
    return frame != null ? 'Frame: ${frame.name}' : 'New frame';
  }
  if (selected.length == 1) {
    final node = widget.state.store.document.nodes[selected.first];
    return '${node?.type.name}: ${node?.name ?? node?.id}';
  }
  return '${selected.length} selected';
}

Color _modeColor(AiMode mode) {
  return mode == AiMode.generate ? Colors.green : Colors.blue;
}
```

### 3. Contextual Positioning (Medium Priority)

Position prompt box near selection instead of fixed bottom center.

**Current code (lines 358-359):**
```dart
// CURRENT: Fixed position
bottom: 16,
left: 0,
right: 0,
```

**New implementation:**
```dart
Offset _calculatePosition(Size viewportSize) {
  final selectionBounds = _getSelectionBounds();

  if (selectionBounds == null) {
    // No selection: center-bottom
    return Offset(
      (viewportSize.width - _boxWidth) / 2,
      viewportSize.height - 80,
    );
  }

  // Try positions in priority order
  final positions = [
    _belowSelection(selectionBounds, viewportSize),
    _aboveSelection(selectionBounds, viewportSize),
    _rightOfSelection(selectionBounds, viewportSize),
  ];

  for (final pos in positions) {
    if (_fitsInViewport(pos, viewportSize)) return pos;
  }

  // Fallback: center-bottom
  return Offset(
    (viewportSize.width - _boxWidth) / 2,
    viewportSize.height - 80,
  );
}
```

### 4. Error Display (Low Priority)

Show errors inline with retry option.

```dart
Widget _buildErrorState(String error) {
  return Container(
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      border: Border.all(color: Colors.red.shade200),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, size: 16, color: Colors.red),
        SizedBox(width: 8),
        Expanded(
          child: Text(error, style: TextStyle(color: Colors.red.shade700)),
        ),
        TextButton(
          onPressed: _retry,
          child: Text('Retry'),
        ),
      ],
    ),
  );
}
```

### 5. Persistent History (Low Priority)

Save history across sessions.

```dart
class PromptHistoryPersistence {
  static const _key = 'prompt_history';

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> save(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, history.take(50).toList());
  }
}
```

---

## Implementation Order

| Phase | Feature | Effort | Priority |
|-------|---------|--------|----------|
| 1 | Prompt history + Up/Down navigation | 0.5 day | High |
| 2 | Scope indicator + mode badge | 0.5 day | Medium |
| 3 | Contextual positioning | 1 day | Medium |
| 4 | Error display with retry | 0.5 day | Low |
| 5 | Persistent history | 0.5 day | Low |
| **Total** | | **3 days** | |

---

## Success Criteria

| Criterion | Status |
|-----------|--------|
| Up arrow recalls previous prompts | ❌ |
| Shows "CREATE" or "EDIT" mode badge | ❌ |
| Shows scope (node name or frame name) | ❌ |
| Positioned near selection (not fixed bottom) | ❌ |
| Error state with retry button | ❌ |
| History persists across sessions | ❌ |

---

## Files to Modify

```
lib/src/free_design/canvas/widgets/
└── prompt_box_overlay.dart     # Add history, scope, positioning

lib/services/                    # New directory
└── prompt_history_persistence.dart  # SharedPreferences storage
```

---

## Notes

- The existing implementation is solid - just needs UX polish
- Context chips already show selection, just need the scope label
- Mode is already determined internally, just need visual indicator
- Don't over-engineer - simple improvements will have big impact
