import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:distill_ds/design_system.dart';

/// Simple number input with design system styling.
class PropertyNumberInput extends StatefulWidget {
  const PropertyNumberInput({
    required this.value,
    required this.onChanged,
    this.suffix,
    super.key,
  });

  final num value;
  final ValueChanged<num?> onChanged;
  final String? suffix;

  @override
  State<PropertyNumberInput> createState() => _PropertyNumberInputState();
}

class _PropertyNumberInputState extends State<PropertyNumberInput> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(PropertyNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final currentText = widget.value.toString();
      if (_controller.text != currentText) {
        _controller.text = currentText;
      }
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      style: typography.body.medium.copyWith(color: colors.foreground.primary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        suffixText: widget.suffix,
        suffixStyle: typography.body.small.copyWith(
          color: colors.foreground.muted,
        ),
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
      onChanged: (value) {
        final number = num.tryParse(value);
        widget.onChanged(number);
      },
    );
  }
}
