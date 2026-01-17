import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// Clickable color swatch that opens a color picker.
class ColorSwatch extends StatefulWidget {
  const ColorSwatch({
    required this.color,
    required this.onColorChanged,
    super.key,
  });

  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  State<ColorSwatch> createState() => _ColorSwatchState();
}

class _ColorSwatchState extends State<ColorSwatch> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _showColorPicker(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 28,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _isHovered
                  ? colors.overlay.overlay20
                  : colors.overlay.overlay10,
              width: 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: colors.overlay.overlay10,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        currentColor: widget.color,
        onColorSelected: (color) {
          widget.onColorChanged(color);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

/// Simple color picker dialog.
class _ColorPickerDialog extends StatelessWidget {
  const _ColorPickerDialog({
    required this.currentColor,
    required this.onColorSelected,
  });

  final Color currentColor;
  final ValueChanged<Color> onColorSelected;

  static const _colors = [
    // Grays & Black/White
    Color(0xFF000000), Color(0xFF424242), Color(0xFF757575),
    Color(0xFFBDBDBD), Color(0xFFEEEEEE), Color(0xFFFFFFFF),
    // Reds
    Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFF44336),
    Color(0xFFE57373), Color(0xFFFFCDD2),
    // Pinks
    Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFE91E63),
    Color(0xFFF06292), Color(0xFFF8BBD0),
    // Purples
    Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF9C27B0),
    Color(0xFFBA68C8), Color(0xFFE1BEE7),
    // Blues
    Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF2196F3),
    Color(0xFF64B5F6), Color(0xFFBBDEFB),
    // Cyans
    Color(0xFF006064), Color(0xFF0097A7), Color(0xFF00BCD4),
    Color(0xFF4DD0E1), Color(0xFFB2EBF2),
    // Greens
    Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF4CAF50),
    Color(0xFF81C784), Color(0xFFC8E6C9),
    // Yellows
    Color(0xFFF57F17), Color(0xFFFBC02D), Color(0xFFFFEB3B),
    Color(0xFFFFF176), Color(0xFFFFF9C4),
    // Oranges
    Color(0xFFE65100), Color(0xFFF57C00), Color(0xFFFF9800),
    Color(0xFFFFB74D), Color(0xFFFFE0B2),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Dialog(
      backgroundColor: colors.background.primary,
      child: Container(
        width: 320,
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick a Color',
              style: context.typography.body.mediumStrong.copyWith(
                color: colors.foreground.primary,
              ),
            ),
            SizedBox(height: spacing.md),
            SizedBox(
              height: 280,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  final color = _colors[index];
                  final isSelected =
                      color.toARGB32() == currentColor.toARGB32();

                  return GestureDetector(
                    onTap: () => onColorSelected(color),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected
                              ? colors.accent.purple.primary
                              : colors.overlay.overlay10,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
