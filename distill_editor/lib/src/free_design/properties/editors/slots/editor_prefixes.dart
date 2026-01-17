import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// Standard size for prefix/suffix widgets.
const double editorPrefixSize = 18.0;

/// Border radius for prefix containers.
const double editorPrefixBorderRadius = 4.0;

/// Grid size for transparency pattern.
const double _transparencyGridSize = 3.0;

/// Color swatch prefix with transparency grid support.
///
/// Shows:
/// - Checkered pattern for null or fully transparent colors
/// - Split view (solid left, transparent right) for semi-transparent colors
/// - Solid color for fully opaque colors
///
/// Usage:
/// ```dart
/// ButtonEditor(
///   displayValue: '#FF0000',
///   prefix: ColorSwatchPrefix(color: Colors.red),
///   onTap: () => showColorPicker(),
/// )
/// ```
class ColorSwatchPrefix extends StatelessWidget {
  final Color? color;

  const ColorSwatchPrefix({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(editorPrefixBorderRadius);

    // Null color - show checkerboard
    if (color == null) {
      return _SwatchContainer(
        borderRadius: borderRadius,
        child: _TransparencyGrid(),
      );
    }

    final isFullyTransparent = color!.a == 0;
    final isTransparent = color!.a < 1;
    final solidColor = color!.withValues(alpha: 1.0);

    // Fully transparent - show checkerboard only
    if (isFullyTransparent) {
      return _SwatchContainer(
        borderRadius: borderRadius,
        child: _TransparencyGrid(),
      );
    }

    // Semi-transparent - show split view
    if (isTransparent) {
      return _SwatchContainer(
        borderRadius: borderRadius,
        child: Row(
          children: [
            // Left half: solid color
            Expanded(child: Container(color: solidColor)),
            // Right half: checkerboard with transparent overlay
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _TransparencyGrid(),
                  Container(color: color),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Fully opaque - solid color
    return _SwatchContainer(
      borderRadius: borderRadius,
      backgroundColor: color,
      child: const SizedBox.shrink(),
    );
  }
}

/// Internal container for swatch prefixes with consistent sizing, border radius, and shadow.
class _SwatchContainer extends StatelessWidget {
  final BorderRadius borderRadius;
  final Widget child;
  final Color? backgroundColor;

  const _SwatchContainer({
    required this.borderRadius,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: editorPrefixSize,
      height: editorPrefixSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? context.colors.background.alternate,
        borderRadius: borderRadius,
        boxShadow: context.shadows.elevation100,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }
}

/// Checkered transparency grid widget.
///
/// Used to indicate transparent/empty values in color and gradient prefixes.
class _TransparencyGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TransparencyGridPainter(
        color1: context.colors.overlay.overlay03,
        color2: context.colors.overlay.overlay15,
        size: _transparencyGridSize,
      ),
    );
  }
}

/// Painter for the checkered transparency pattern.
class _TransparencyGridPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double size;

  _TransparencyGridPainter({
    required this.color1,
    required this.color2,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    for (double y = 0; y < canvasSize.height; y += size) {
      for (double x = 0; x < canvasSize.width; x += size) {
        final isEvenRow = ((y / size).floor() % 2 == 0);
        final isEvenCol = ((x / size).floor() % 2 == 0);
        final useColor1 = isEvenRow == isEvenCol;

        canvas.drawRect(
          Rect.fromLTWH(x, y, size, size),
          useColor1 ? paint1 : paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TransparencyGridPainter oldDelegate) {
    return oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2 ||
        oldDelegate.size != size;
  }
}
