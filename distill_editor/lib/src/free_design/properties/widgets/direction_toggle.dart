import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../models/node_layout.dart';

/// Button group for selecting layout direction.
class PropertyDirectionToggle extends StatelessWidget {
  const PropertyDirectionToggle({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final LayoutDirection value;
  final ValueChanged<LayoutDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DirectionButton(
          icon: Icons.view_column,
          label: 'Horizontal',
          isSelected: value == LayoutDirection.horizontal,
          onTap: () => onChanged(LayoutDirection.horizontal),
        ),
        const SizedBox(width: 4),
        _DirectionButton(
          icon: Icons.view_agenda,
          label: 'Vertical',
          isSelected: value == LayoutDirection.vertical,
          onTap: () => onChanged(LayoutDirection.vertical),
        ),
      ],
    );
  }
}

class _DirectionButton extends StatefulWidget {
  const _DirectionButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DirectionButton> createState() => _DirectionButtonState();
}

class _DirectionButtonState extends State<_DirectionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? colors.accent.purple.primary
                : _isHovered
                ? colors.overlay.overlay10
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isSelected
                  ? colors.accent.purple.primary
                  : colors.overlay.overlay10,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected
                    ? Colors.white
                    : colors.foreground.primary,
              ),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: context.typography.body.small.copyWith(
                  color: widget.isSelected
                      ? Colors.white
                      : colors.foreground.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
