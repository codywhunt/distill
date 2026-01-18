# PRD: Priority 6 - Quick-Edit Overlays

## Overview

Quick-Edit Overlays provide contextual edit controls directly on the canvas, enabling faster editing without requiring the property panel. This makes the tool feel more like direct manipulation and reduces friction for common operations.

**Status:** Not Started
**Dependencies:** Priority 1 (Drag & Drop) - Completed
**Estimated Complexity:** Medium

---

## Problem Statement

Currently, all property editing happens through the right-side property panel. This workflow has friction:

1. **Context switching**: Select node on canvas → look at panel → make change → look back at canvas
2. **Mouse travel**: Long distance between canvas selection and panel controls
3. **Discovery**: Users may not notice all available properties in the panel
4. **Common operations buried**: Changing text or color requires navigating panel sections

Design tools like Figma provide inline editing for the most common operations, creating a more fluid experience.

---

## Goals

1. **Direct text editing**: Double-click text nodes to edit inline
2. **Quick color access**: Color swatch on selected nodes for fast fill changes
3. **Minimal scope**: Ship two high-impact features, not a full overlay system
4. **Non-intrusive**: Overlays don't block other interactions
5. **Keyboard friendly**: Escape cancels, Enter commits

---

## Non-Goals (Out of Scope)

- Quick padding/gap adjusters (future)
- Quick font controls (future)
- Corner radius handles (future)
- Full floating toolbar
- Touch/mobile support

---

## Success Criteria

| Criterion | Metric | Validation Method |
|-----------|--------|-------------------|
| Double-click text enters edit mode | Text cursor appears | Manual test |
| Typing updates text content | Live preview | Manual test |
| Click outside commits | Text saved | Unit test |
| Enter commits | Text saved | Unit test |
| Escape cancels | Reverts to original | Unit test |
| Fill swatch appears | Visible on selected nodes with fill | Manual test |
| Click swatch opens picker | Color picker positioned near node | Manual test |
| Color change updates node | Live preview during pick | Unit test |
| Undo works | Single undo reverts | Unit test |

---

## Technical Architecture

### 1. Inline Text Editing

#### State Management

```dart
/// State for inline text editing overlay
class InlineTextEditState extends ChangeNotifier {
  /// Currently editing node ID (null if not editing)
  String? _editingNodeId;

  /// Original text (for cancel)
  String? _originalText;

  /// Current text (during edit)
  String? _currentText;

  /// Text field focus node
  final FocusNode _focusNode = FocusNode();

  /// Whether currently editing
  bool get isEditing => _editingNodeId != null;

  /// The node being edited
  String? get editingNodeId => _editingNodeId;

  /// Focus node for text field
  FocusNode get focusNode => _focusNode;

  /// Start editing a text node
  void startEditing(String nodeId, String currentText) {
    _editingNodeId = nodeId;
    _originalText = currentText;
    _currentText = currentText;
    notifyListeners();

    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// Update current text (during typing)
  void updateText(String text) {
    _currentText = text;
    notifyListeners();
  }

  /// Commit the edit
  void commit() {
    if (!isEditing) return;

    final nodeId = _editingNodeId!;
    final newText = _currentText ?? '';

    _editingNodeId = null;
    _originalText = null;
    _currentText = null;
    notifyListeners();

    // Return committed data for patch application
    // (Actual patch applied by parent widget)
  }

  /// Cancel the edit
  void cancel() {
    _editingNodeId = null;
    _originalText = null;
    _currentText = null;
    notifyListeners();
  }

  /// Get current text value
  String? get currentText => _currentText;

  /// Get original text (for comparison)
  String? get originalText => _originalText;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
```

#### Overlay Widget

```dart
/// Inline text edit overlay widget
class InlineTextEditOverlay extends StatefulWidget {
  final InlineTextEditState editState;
  final EditorDocumentStore documentStore;
  final InfiniteCanvasController canvasController;
  final VoidCallback onCommit;

  const InlineTextEditOverlay({
    super.key,
    required this.editState,
    required this.documentStore,
    required this.canvasController,
    required this.onCommit,
  });

  @override
  State<InlineTextEditOverlay> createState() => _InlineTextEditOverlayState();
}

class _InlineTextEditOverlayState extends State<InlineTextEditOverlay> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.editState.currentText ?? '',
    );
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.editState.updateText(_textController.text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.editState,
      builder: (context, _) {
        if (!widget.editState.isEditing) {
          return const SizedBox.shrink();
        }

        final nodeId = widget.editState.editingNodeId!;
        final node = widget.documentStore.document.nodes[nodeId];

        if (node == null || node.type != NodeType.text) {
          return const SizedBox.shrink();
        }

        // Calculate position in view coordinates
        final worldBounds = _calculateNodeBounds(node);
        final viewBounds = _worldToViewBounds(worldBounds);

        return Positioned(
          left: viewBounds.left,
          top: viewBounds.top,
          width: viewBounds.width,
          height: viewBounds.height,
          child: _buildEditField(node),
        );
      },
    );
  }

  Widget _buildEditField(Node node) {
    // Match the node's text styling
    final fontSize = node.props.fontSize ?? 16.0;
    final fontWeight = FontWeight.values[
      ((node.props.fontWeight ?? 400) ~/ 100).clamp(0, 8)
    ];
    final color = _parseColor(node.props.color ?? '#000000');
    final textAlign = _parseTextAlign(node.props.textAlign);

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.editState.cancel();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter &&
              !HardwareKeyboard.instance.isShiftPressed) {
            _commitEdit();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TapRegion(
        onTapOutside: (_) => _commitEdit(),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: EditableText(
            controller: _textController,
            focusNode: widget.editState.focusNode,
            style: TextStyle(
              fontSize: fontSize * widget.canvasController.zoom,
              fontWeight: fontWeight,
              color: color,
            ),
            textAlign: textAlign,
            cursorColor: Colors.blue,
            backgroundCursorColor: Colors.grey,
            maxLines: null,
            autofocus: true,
          ),
        ),
      ),
    );
  }

  void _commitEdit() {
    if (!widget.editState.isEditing) return;

    final nodeId = widget.editState.editingNodeId!;
    final newText = _textController.text;
    final originalText = widget.editState.originalText;

    widget.editState.commit();

    // Only apply patch if text changed
    if (newText != originalText) {
      widget.documentStore.applyPatches([
        SetProp(id: nodeId, path: '/props/text', value: newText),
      ]);
    }

    widget.onCommit();
  }

  Rect _calculateNodeBounds(Node node) {
    // Get node position and size from layout
    final x = node.layout.position?.x ?? 0;
    final y = node.layout.position?.y ?? 0;
    final width = node.layout.size?.width?.value ?? 100;
    final height = node.layout.size?.height?.value ?? 24;

    return Rect.fromLTWH(x, y, width, height);
  }

  Rect _worldToViewBounds(Rect worldBounds) {
    final controller = widget.canvasController;
    final topLeft = controller.worldToView(worldBounds.topLeft);
    final bottomRight = controller.worldToView(worldBounds.bottomRight);

    return Rect.fromPoints(topLeft, bottomRight);
  }

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      final hex = colorString.substring(1);
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.black;
  }

  TextAlign _parseTextAlign(String? align) {
    switch (align) {
      case 'center': return TextAlign.center;
      case 'right': return TextAlign.right;
      default: return TextAlign.left;
    }
  }
}
```

#### Double-Click Detection

```dart
/// Mixin for handling double-click on canvas nodes
mixin DoubleClickHandlerMixin on State<FreeDesignCanvas> {
  DateTime? _lastTapTime;
  String? _lastTappedNodeId;
  static const _doubleClickThreshold = Duration(milliseconds: 300);

  /// Handle tap on node, detect double-click
  void handleNodeTap(String nodeId, TapDownDetails details) {
    final now = DateTime.now();

    if (_lastTappedNodeId == nodeId &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < _doubleClickThreshold) {
      // Double-click detected
      _handleDoubleClick(nodeId);
      _lastTapTime = null;
      _lastTappedNodeId = null;
    } else {
      // Single click
      _lastTapTime = now;
      _lastTappedNodeId = nodeId;

      // Normal selection behavior
      _handleSingleClick(nodeId, details);
    }
  }

  void _handleDoubleClick(String nodeId) {
    final node = documentStore.document.nodes[nodeId];
    if (node == null) return;

    if (node.type == NodeType.text) {
      // Enter inline edit mode
      inlineTextEditState.startEditing(nodeId, node.props.text ?? '');
    }
  }

  void _handleSingleClick(String nodeId, TapDownDetails details) {
    // Existing selection logic
  }
}
```

### 2. Color Swatch Overlay

#### State Management

```dart
/// State for color swatch quick-edit
class ColorSwatchState extends ChangeNotifier {
  /// Whether color picker is open
  bool _isPickerOpen = false;

  /// Node being edited
  String? _editingNodeId;

  /// Original color (for cancel/undo)
  String? _originalColor;

  /// Picker position
  Offset? _pickerPosition;

  bool get isPickerOpen => _isPickerOpen;
  String? get editingNodeId => _editingNodeId;
  Offset? get pickerPosition => _pickerPosition;

  /// Open color picker for node
  void openPicker(String nodeId, String currentColor, Offset swatchPosition) {
    _editingNodeId = nodeId;
    _originalColor = currentColor;
    _isPickerOpen = true;

    // Position picker near swatch but ensure on-screen
    _pickerPosition = _calculatePickerPosition(swatchPosition);

    notifyListeners();
  }

  /// Close picker
  void closePicker() {
    _isPickerOpen = false;
    _editingNodeId = null;
    _originalColor = null;
    _pickerPosition = null;
    notifyListeners();
  }

  /// Get original color (for undo)
  String? get originalColor => _originalColor;

  Offset _calculatePickerPosition(Offset swatchPosition) {
    // TODO: Account for screen bounds
    // Position picker to the right of swatch with offset
    return swatchPosition + const Offset(24, -100);
  }
}
```

#### Swatch Widget

```dart
/// Color swatch displayed on selected nodes with fill
class ColorSwatchOverlay extends StatelessWidget {
  final CanvasState canvasState;
  final EditorDocumentStore documentStore;
  final InfiniteCanvasController canvasController;
  final ColorSwatchState swatchState;

  const ColorSwatchOverlay({
    super.key,
    required this.canvasState,
    required this.documentStore,
    required this.canvasController,
    required this.swatchState,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([canvasState, swatchState]),
      builder: (context, _) {
        final selectedNodeIds = canvasState.selectedNodeIds;

        // Only show for single selection with fill
        if (selectedNodeIds.length != 1) {
          return const SizedBox.shrink();
        }

        final nodeId = selectedNodeIds.first;
        final node = documentStore.document.nodes[nodeId];

        if (node == null) return const SizedBox.shrink();

        final fillColor = node.style?.fill?.color;
        if (fillColor == null || node.style?.fill?.type == FillType.none) {
          return const SizedBox.shrink();
        }

        // Calculate swatch position (top-right of selection bounds)
        final bounds = canvasState.getNodeBounds(nodeId);
        if (bounds == null) return const SizedBox.shrink();

        final viewTopRight = canvasController.worldToView(bounds.topRight);

        return Stack(
          children: [
            // Swatch button
            Positioned(
              left: viewTopRight.dx + 8,
              top: viewTopRight.dy - 12,
              child: _ColorSwatchButton(
                color: _parseColor(fillColor),
                onTap: () {
                  swatchState.openPicker(
                    nodeId,
                    fillColor,
                    viewTopRight + const Offset(8, -12),
                  );
                },
              ),
            ),

            // Color picker (if open)
            if (swatchState.isPickerOpen && swatchState.editingNodeId == nodeId)
              Positioned(
                left: swatchState.pickerPosition!.dx,
                top: swatchState.pickerPosition!.dy,
                child: _ColorPickerPopover(
                  initialColor: fillColor,
                  onColorChanged: (color) {
                    // Live preview
                    documentStore.applyPatches([
                      SetProp(id: nodeId, path: '/style/fill/color', value: color),
                    ], coalesce: true);
                  },
                  onClose: () {
                    swatchState.closePicker();
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      final hex = colorString.substring(1);
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    }
    // Handle token references
    if (colorString.startsWith('{')) {
      // TODO: Resolve token
      return Colors.grey;
    }
    return Colors.black;
  }
}

/// The clickable color swatch button
class _ColorSwatchButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorSwatchButton({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### Color Picker Popover

```dart
/// Compact color picker popover
class _ColorPickerPopover extends StatefulWidget {
  final String initialColor;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onClose;

  const _ColorPickerPopover({
    required this.initialColor,
    required this.onColorChanged,
    required this.onClose,
  });

  @override
  State<_ColorPickerPopover> createState() => _ColorPickerPopoverState();
}

class _ColorPickerPopoverState extends State<_ColorPickerPopover> {
  late HSVColor _currentHsv;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _currentHsv = _parseToHsv(widget.initialColor);
    _hexController = TextEditingController(text: widget.initialColor);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => widget.onClose(),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 240,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Color wheel
              SizedBox(
                width: 200,
                height: 200,
                child: _ColorWheel(
                  hsv: _currentHsv,
                  onChanged: _onWheelChanged,
                ),
              ),

              const SizedBox(height: 12),

              // Value/brightness slider
              _ValueSlider(
                hsv: _currentHsv,
                onChanged: _onValueChanged,
              ),

              const SizedBox(height: 12),

              // Hex input
              Row(
                children: [
                  // Color preview
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _currentHsv.toColor(),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Hex text field
                  Expanded(
                    child: TextField(
                      controller: _hexController,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _onHexSubmitted,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Preset colors (from theme tokens)
              _PresetColors(
                onSelected: (color) {
                  _currentHsv = _parseToHsv(color);
                  _hexController.text = color;
                  widget.onColorChanged(color);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onWheelChanged(HSVColor hsv) {
    setState(() {
      _currentHsv = hsv;
      _hexController.text = _hsvToHex(hsv);
    });
    widget.onColorChanged(_hsvToHex(hsv));
  }

  void _onValueChanged(double value) {
    setState(() {
      _currentHsv = _currentHsv.withValue(value);
      _hexController.text = _hsvToHex(_currentHsv);
    });
    widget.onColorChanged(_hsvToHex(_currentHsv));
  }

  void _onHexSubmitted(String hex) {
    if (_isValidHex(hex)) {
      final normalized = hex.startsWith('#') ? hex : '#$hex';
      setState(() {
        _currentHsv = _parseToHsv(normalized);
        _hexController.text = normalized;
      });
      widget.onColorChanged(normalized);
    }
  }

  HSVColor _parseToHsv(String colorString) {
    final color = _parseColor(colorString);
    return HSVColor.fromColor(color);
  }

  String _hsvToHex(HSVColor hsv) {
    final color = hsv.toColor();
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  bool _isValidHex(String hex) {
    final clean = hex.startsWith('#') ? hex.substring(1) : hex;
    return clean.length == 6 && int.tryParse(clean, radix: 16) != null;
  }

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      final hex = colorString.substring(1);
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Colors.black;
  }
}

/// Simple color wheel widget
class _ColorWheel extends StatelessWidget {
  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  const _ColorWheel({
    required this.hsv,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        // Calculate hue and saturation from position
        final center = Offset(100, 100);
        final position = details.localPosition - center;
        final hue = (atan2(position.dy, position.dx) * 180 / pi + 360) % 360;
        final saturation = (position.distance / 100).clamp(0.0, 1.0);

        onChanged(HSVColor.fromAHSV(1, hue, saturation, hsv.value));
      },
      child: CustomPaint(
        size: const Size(200, 200),
        painter: _ColorWheelPainter(hsv),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final HSVColor selectedHsv;

  _ColorWheelPainter(this.selectedHsv);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw color wheel
    for (var h = 0; h < 360; h++) {
      for (var s = 0.0; s <= 1.0; s += 0.02) {
        final angle = h * pi / 180;
        final distance = s * radius;
        final offset = Offset(
          center.dx + cos(angle) * distance,
          center.dy + sin(angle) * distance,
        );

        final paint = Paint()
          ..color = HSVColor.fromAHSV(1, h.toDouble(), s, selectedHsv.value).toColor()
          ..strokeWidth = 3;

        canvas.drawCircle(offset, 1.5, paint);
      }
    }

    // Draw selection indicator
    final selectedAngle = selectedHsv.hue * pi / 180;
    final selectedDistance = selectedHsv.saturation * radius;
    final selectedOffset = Offset(
      center.dx + cos(selectedAngle) * selectedDistance,
      center.dy + sin(selectedAngle) * selectedDistance,
    );

    canvas.drawCircle(
      selectedOffset,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      selectedOffset,
      6,
      Paint()..color = selectedHsv.toColor(),
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.selectedHsv != selectedHsv;
  }
}
```

### 3. Integration with Canvas

```dart
/// Updated FreeDesignCanvas with quick-edit overlays
class FreeDesignCanvas extends StatefulWidget {
  // ... existing props

  @override
  State<FreeDesignCanvas> createState() => _FreeDesignCanvasState();
}

class _FreeDesignCanvasState extends State<FreeDesignCanvas>
    with DoubleClickHandlerMixin {

  late InlineTextEditState _inlineTextEditState;
  late ColorSwatchState _colorSwatchState;

  @override
  void initState() {
    super.initState();
    _inlineTextEditState = InlineTextEditState();
    _colorSwatchState = ColorSwatchState();
  }

  @override
  void dispose() {
    _inlineTextEditState.dispose();
    _colorSwatchState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Canvas content
        InfiniteCanvas(
          controller: widget.canvasController,
          child: _buildCanvasContent(),
        ),

        // Existing overlays
        SelectionOverlay(...),
        ResizeHandles(...),

        // NEW: Quick-edit overlays
        InlineTextEditOverlay(
          editState: _inlineTextEditState,
          documentStore: widget.documentStore,
          canvasController: widget.canvasController,
          onCommit: () {
            // Re-enable canvas interactions
          },
        ),

        ColorSwatchOverlay(
          canvasState: widget.canvasState,
          documentStore: widget.documentStore,
          canvasController: widget.canvasController,
          swatchState: _colorSwatchState,
        ),
      ],
    );
  }

  // Handle node taps for double-click detection
  void _onNodeTap(String nodeId, TapDownDetails details) {
    handleNodeTap(nodeId, details);
  }
}
```

---

## UI/UX Specifications

### Inline Text Editing

| Aspect | Specification |
|--------|---------------|
| **Trigger** | Double-click on text node |
| **Visual** | Blue border around text, white background, cursor |
| **Text style** | Matches node styling (size, weight, color, align) |
| **Scaling** | Text scales with canvas zoom |
| **Commit** | Enter, click outside, Tab |
| **Cancel** | Escape |
| **Multi-line** | Shift+Enter adds line break |

### Color Swatch

| Aspect | Specification |
|--------|---------------|
| **Position** | Top-right of selection bounds, 8px offset |
| **Size** | 24x24px |
| **Visual** | Filled circle, white border, subtle shadow |
| **Trigger** | Single click on swatch |
| **Picker position** | Right of swatch, adjust to stay on screen |

### Color Picker

| Aspect | Specification |
|--------|---------------|
| **Size** | 240px wide, variable height |
| **Style** | White card, elevation 8, 8px radius |
| **Components** | Color wheel, value slider, hex input, presets |
| **Live preview** | Color updates node in real-time |
| **Close** | Click outside |

---

## Test Plan

### Unit Tests

```dart
group('InlineTextEditState', () {
  test('startEditing sets state correctly', () {
    final state = InlineTextEditState();

    state.startEditing('n_text', 'Hello');

    expect(state.isEditing, isTrue);
    expect(state.editingNodeId, equals('n_text'));
    expect(state.currentText, equals('Hello'));
    expect(state.originalText, equals('Hello'));
  });

  test('updateText updates current text', () {
    final state = InlineTextEditState();
    state.startEditing('n_text', 'Hello');

    state.updateText('Hello World');

    expect(state.currentText, equals('Hello World'));
    expect(state.originalText, equals('Hello')); // Original unchanged
  });

  test('commit clears state', () {
    final state = InlineTextEditState();
    state.startEditing('n_text', 'Hello');
    state.updateText('Updated');

    state.commit();

    expect(state.isEditing, isFalse);
    expect(state.editingNodeId, isNull);
  });

  test('cancel reverts to original', () {
    final state = InlineTextEditState();
    state.startEditing('n_text', 'Hello');
    state.updateText('Changed');

    state.cancel();

    expect(state.isEditing, isFalse);
    // Parent widget should NOT apply patch on cancel
  });
});

group('ColorSwatchState', () {
  test('openPicker sets state correctly', () {
    final state = ColorSwatchState();

    state.openPicker('n_button', '#FF0000', Offset(100, 100));

    expect(state.isPickerOpen, isTrue);
    expect(state.editingNodeId, equals('n_button'));
    expect(state.originalColor, equals('#FF0000'));
    expect(state.pickerPosition, isNotNull);
  });

  test('closePicker clears state', () {
    final state = ColorSwatchState();
    state.openPicker('n_button', '#FF0000', Offset(100, 100));

    state.closePicker();

    expect(state.isPickerOpen, isFalse);
    expect(state.editingNodeId, isNull);
  });
});

group('Double-click detection', () {
  test('detects double-click within threshold', () {
    final detector = DoubleClickDetector();

    final firstResult = detector.handleTap('n_text', DateTime.now());
    expect(firstResult, equals(TapResult.singleClick));

    final secondResult = detector.handleTap('n_text', DateTime.now());
    expect(secondResult, equals(TapResult.doubleClick));
  });

  test('resets after threshold exceeded', () async {
    final detector = DoubleClickDetector();

    detector.handleTap('n_text', DateTime.now());

    await Future.delayed(Duration(milliseconds: 400));

    final result = detector.handleTap('n_text', DateTime.now());
    expect(result, equals(TapResult.singleClick));
  });

  test('different nodes reset detection', () {
    final detector = DoubleClickDetector();

    detector.handleTap('n_text1', DateTime.now());
    final result = detector.handleTap('n_text2', DateTime.now());

    expect(result, equals(TapResult.singleClick));
  });
});
```

### Widget Tests

```dart
testWidgets('InlineTextEditOverlay shows for editing text node', (tester) async {
  final editState = InlineTextEditState();
  final documentStore = createTestDocumentStore();

  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          InlineTextEditOverlay(
            editState: editState,
            documentStore: documentStore,
            canvasController: createTestCanvasController(),
            onCommit: () {},
          ),
        ],
      ),
    ),
  );

  // Initially hidden
  expect(find.byType(EditableText), findsNothing);

  // Start editing
  editState.startEditing('n_text', 'Hello');
  await tester.pump();

  // Now visible
  expect(find.byType(EditableText), findsOneWidget);
  expect(find.text('Hello'), findsOneWidget);
});

testWidgets('Escape key cancels edit', (tester) async {
  final editState = InlineTextEditState();
  final committed = ValueNotifier(false);

  await tester.pumpWidget(
    MaterialApp(
      home: InlineTextEditOverlay(
        editState: editState,
        documentStore: createTestDocumentStore(),
        canvasController: createTestCanvasController(),
        onCommit: () => committed.value = true,
      ),
    ),
  );

  editState.startEditing('n_text', 'Hello');
  await tester.pump();

  // Press Escape
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();

  expect(editState.isEditing, isFalse);
  expect(committed.value, isFalse);
});

testWidgets('ColorSwatchOverlay shows for node with fill', (tester) async {
  final canvasState = createTestCanvasState();
  final swatchState = ColorSwatchState();

  final documentStore = createDocumentStoreWithFilledNode();

  await tester.pumpWidget(
    MaterialApp(
      home: ColorSwatchOverlay(
        canvasState: canvasState,
        documentStore: documentStore,
        canvasController: createTestCanvasController(),
        swatchState: swatchState,
      ),
    ),
  );

  // Select node with fill
  canvasState.select({'n_button'});
  await tester.pump();

  // Swatch should be visible
  expect(find.byType(_ColorSwatchButton), findsOneWidget);
});
```

### Integration Tests

```dart
testWidgets('complete inline text edit flow', (tester) async {
  await tester.pumpWidget(createTestApp());

  // Double-click text node
  await tester.tap(find.byKey(Key('node_n_text')));
  await tester.pump(Duration(milliseconds: 50));
  await tester.tap(find.byKey(Key('node_n_text')));
  await tester.pump();

  // Should enter edit mode
  expect(find.byType(EditableText), findsOneWidget);

  // Type new text
  await tester.enterText(find.byType(EditableText), 'Updated Text');
  await tester.pump();

  // Press Enter to commit
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();

  // Verify text updated
  final node = getDocumentStore(tester).document.nodes['n_text']!;
  expect(node.props.text, equals('Updated Text'));
});

testWidgets('color picker updates node live', (tester) async {
  await tester.pumpWidget(createTestApp());

  // Select node
  await tester.tap(find.byKey(Key('node_n_button')));
  await tester.pump();

  // Click color swatch
  await tester.tap(find.byType(_ColorSwatchButton));
  await tester.pump();

  // Color picker should appear
  expect(find.byType(_ColorPickerPopover), findsOneWidget);

  // Interact with picker (simulate color selection)
  // ... picker interaction tests

  // Verify live update
  final node = getDocumentStore(tester).document.nodes['n_button']!;
  // Color should be updated
});
```

---

## Implementation Order

1. **Phase 1: Inline Text Edit State**
   - [ ] Create `InlineTextEditState` class
   - [ ] Unit test state management
   - [ ] Implement double-click detection

2. **Phase 2: Inline Text Edit Overlay**
   - [ ] Create `InlineTextEditOverlay` widget
   - [ ] Position calculation from node bounds
   - [ ] Style matching (font, color, size)
   - [ ] Keyboard handling (Enter, Escape)
   - [ ] Widget tests

3. **Phase 3: Canvas Integration (Text)**
   - [ ] Add overlay to canvas stack
   - [ ] Wire double-click handling
   - [ ] Test end-to-end flow

4. **Phase 4: Color Swatch State**
   - [ ] Create `ColorSwatchState` class
   - [ ] Unit test state management

5. **Phase 5: Color Swatch Overlay**
   - [ ] Create swatch button widget
   - [ ] Position calculation
   - [ ] Click handling

6. **Phase 6: Color Picker**
   - [ ] Create color picker popover
   - [ ] Color wheel component
   - [ ] Hex input
   - [ ] Live preview
   - [ ] Widget tests

7. **Phase 7: Integration**
   - [ ] Add overlays to canvas stack
   - [ ] Test complete flows
   - [ ] Polish and edge cases

---

## File Locations

```
lib/src/free_design/
├── canvas/
│   ├── overlays/
│   │   ├── inline_text_edit_overlay.dart
│   │   ├── inline_text_edit_state.dart
│   │   ├── color_swatch_overlay.dart
│   │   ├── color_swatch_state.dart
│   │   └── color_picker_popover.dart
│   └── widgets/
│       └── free_design_canvas.dart  # Updated
└── ...

test/free_design/
├── canvas/
│   ├── overlays/
│   │   ├── inline_text_edit_state_test.dart
│   │   ├── inline_text_edit_overlay_test.dart
│   │   ├── color_swatch_state_test.dart
│   │   └── color_swatch_overlay_test.dart
│   └── double_click_detection_test.dart
└── ...
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Text scaling issues at extreme zoom | Medium | Low | Clamp zoom range for editing |
| Color picker position off-screen | Medium | Low | Viewport boundary detection |
| Focus conflicts with canvas | Medium | Medium | Careful focus management |
| Performance with many selections | Low | Low | Only show for single selection |

---

## Future Enhancements (Not in Scope)

1. **Quick padding/gap controls**: Drag handles for spacing
2. **Quick font controls**: Floating font picker
3. **Corner radius handles**: Drag to adjust radius
4. **Full floating toolbar**: All common tools in one overlay
5. **Contextual AI prompts**: "Make it pop" button on selection
