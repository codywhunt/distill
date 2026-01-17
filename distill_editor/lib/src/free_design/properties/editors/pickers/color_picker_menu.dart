import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart' as picker;
import 'package:distill_ds/design_system.dart';

import '../core/editor_input_container.dart';
import '../core/editor_styling.dart';
import '../primitives/button_editor.dart';

/// A color picker popover that anchors to a trigger widget.
///
/// Positions to the direct left of the trigger using HoloPopover.
///
/// Usage:
/// ```dart
/// ColorPickerPopover(
///   initialColor: Color(0xFFFF5733),
///   onChanged: (color) => print(color),
///   child: ButtonEditor(
///     value: '#FF5733',
///     prefix: ColorSwatchPrefix(color: Color(0xFFFF5733)),
///   ),
/// )
/// ```
class ColorPickerPopover extends StatefulWidget {
  /// The trigger widget that opens the color picker when tapped.
  final Widget child;

  /// The initial color to display.
  final Color? initialColor;

  /// Called when the color changes.
  final ValueChanged<Color> onChanged;

  const ColorPickerPopover({
    super.key,
    required this.child,
    required this.initialColor,
    required this.onChanged,
  });

  @override
  State<ColorPickerPopover> createState() => _ColorPickerPopoverState();
}

class _ColorPickerPopoverState extends State<ColorPickerPopover> {
  late final HoloPopoverController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HoloPopoverController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clone the child widget and inject the onTap handler if it's a ButtonEditor
    Widget childWithTap = widget.child;
    if (widget.child is ButtonEditor) {
      final buttonEditor = widget.child as ButtonEditor;
      childWithTap = ButtonEditor(
        displayValue: buttonEditor.displayValue,
        placeholder: buttonEditor.placeholder,
        prefix: buttonEditor.prefix,
        suffix: buttonEditor.suffix,
        disabled: buttonEditor.disabled,
        hasError: buttonEditor.hasError,
        focusNode: buttonEditor.focusNode,
        onClear: buttonEditor.onClear,
        clearReplacesSuffix: buttonEditor.clearReplacesSuffix,
        onTap: _controller.toggle,
      );
    }

    return HoloPopover(
      controller: _controller,
      anchor: HoloPopoverAnchor.leftCenter,
      offset: const Offset(-8, 0), // 8px spacing from trigger
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 400),
      popoverBuilder: (context) => ColorPickerMenu(
        initialColor: widget.initialColor ?? Colors.white,
        onChanged: widget.onChanged,
        onClose: () => _controller.hide(),
      ),
      child: childWithTap,
    );
  }
}

/// A simplified color picker with HSV wheel, sliders, and hex input.
class ColorPickerMenu extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onChanged;
  final VoidCallback? onClose;

  const ColorPickerMenu({
    super.key,
    required this.initialColor,
    required this.onChanged,
    this.onClose,
  });

  @override
  State<ColorPickerMenu> createState() => _ColorPickerMenuState();
}

class _ColorPickerMenuState extends State<ColorPickerMenu> {
  late Color _current;
  late TextEditingController _hexController;
  bool _hexHasError = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_current));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return '#${hex.toUpperCase()}';
  }

  void _updateColor(Color color) {
    setState(() {
      _current = color;
      _hexController.text = _colorToHex(color);
      _hexHasError = false;
    });
    widget.onChanged(color);
  }

  Color? _tryParseHex(String value) {
    try {
      var v = value.trim().toUpperCase();
      if (v.startsWith('#')) v = v.substring(1);

      // Support 3-digit shorthand (#RGB -> #RRGGBB)
      if (v.length == 3) {
        v = v.split('').map((c) => '$c$c').join();
      }

      if (v.length != 6) return null;
      final reg = RegExp(r'^[0-9A-F]{6}$');
      if (!reg.hasMatch(v)) return null;

      return Color(int.parse('FF$v', radix: 16));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: context.colors.background.primary,
        borderRadius: BorderRadius.circular(context.radius.lg),
        border: Border.all(color: context.colors.stroke, width: 1.0),
        boxShadow: context.shadows.elevation200,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color picker area (HSV square)
          Container(
            height: 180,
            width: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radius.md),
              border: Border.all(color: context.colors.stroke, width: 1.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.radius.md),
              child: picker.ColorPickerArea(
                HSVColor.fromColor(_current),
                (HSVColor color) => _updateColor(color.toColor()),
                picker.PaletteType.hsv,
              ),
            ),
          ),
          SizedBox(height: context.spacing.sm),

          // Hue and Alpha sliders
          SizedBox(
            height: 52,
            child: Stack(
              children: [
                // Hue slider
                SizedBox(
                  height: 32,
                  child: picker.ColorPickerSlider(
                    picker.TrackType.hue,
                    HSVColor.fromColor(_current),
                    (HSVColor color) => _updateColor(color.toColor()),
                    displayThumbColor: true,
                  ),
                ),
                // Alpha slider
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: SizedBox(
                    height: 32,
                    child: picker.ColorPickerSlider(
                      picker.TrackType.alpha,
                      HSVColor.fromColor(_current),
                      (HSVColor color) => _updateColor(color.toColor()),
                      displayThumbColor: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.spacing.sm),

          // Hex input
          EditorInputContainer(
            hasError: _hexHasError,
            prefix: Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: _current,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: context.colors.overlay.overlay10,
                    width: 1.0,
                  ),
                  boxShadow: context.shadows.elevation100,
                ),
              ),
            ),
            suffix: Padding(
              padding: const EdgeInsets.only(right: 2.0, top: 1.0),
              child: Text(
                '${(_current.a * 100).round()}%',
                style: EditorTextStyles.suffix(context),
              ),
            ),
            child: TextSelectionTheme(
              data: editorTextSelectionTheme(context),
              child: TextField(
                controller: _hexController,
                style: EditorTextStyles.input(context),
                cursorColor: EditorColors.borderFocused(context),
                mouseCursor: SystemMouseCursors.basic,
                decoration: InputDecoration(
                  hintText: 'Hex Code',
                  hintStyle: EditorTextStyles.placeholder(context),
                  border: InputBorder.none,
                  contentPadding: EditorSpacing.horizontal,
                  isDense: true,
                ),
                onChanged: (value) {
                  final parsed = _tryParseHex(value);
                  setState(() => _hexHasError = parsed == null);
                  if (parsed != null) {
                    // Preserve alpha from current color
                    final withAlpha = parsed.withValues(alpha: _current.a);
                    setState(() => _current = withAlpha);
                    widget.onChanged(withAlpha);
                  }
                },
                onSubmitted: (value) {
                  final parsed = _tryParseHex(value);
                  if (parsed == null) {
                    setState(() => _hexHasError = true);
                    return;
                  }
                  final withAlpha = parsed.withValues(alpha: _current.a);
                  setState(() {
                    _current = withAlpha;
                    _hexController.text = _colorToHex(withAlpha);
                    _hexHasError = false;
                  });
                  widget.onChanged(withAlpha);
                },
              ),
            ),
          ),
          SizedBox(height: context.spacing.md),

          // Close button
          if (widget.onClose != null)
            SizedBox(
              width: double.infinity,
              child: HoloButton(label: 'Done', onPressed: widget.onClose),
            ),
        ],
      ),
    );
  }
}
