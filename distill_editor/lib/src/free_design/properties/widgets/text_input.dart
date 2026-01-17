import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// Simple text input with design system styling.
class PropertyTextInput extends StatefulWidget {
  const PropertyTextInput({
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  State<PropertyTextInput> createState() => _PropertyTextInputState();
}

class _PropertyTextInputState extends State<PropertyTextInput> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(PropertyTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      style: typography.body.medium.copyWith(color: colors.foreground.primary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.overlay.overlay10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.overlay.overlay10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: colors.accent.purple.primary, width: 2),
        ),
      ),
      onChanged: widget.onChanged,
    );
  }
}
