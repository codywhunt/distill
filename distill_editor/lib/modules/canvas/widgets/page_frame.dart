import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// A simple frame representing a page on the canvas in edit mode.
///
/// Shows the page boundaries as a clean box with the same placeholder
/// pattern as browse mode cards (status bar, content placeholders, home indicator).
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.size, this.child});

  /// The size of the page frame.
  final Size size;

  /// Optional content to display inside the frame.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: colors.background.secondary,
        boxShadow: context.shadows.elevation100,
        borderRadius: BorderRadius.circular(context.radius.sm),
      ),
      child: const _PagePlaceholder(),
    );
  }
}

/// Placeholder content matching browse mode card pattern.
class _PagePlaceholder extends StatelessWidget {
  const _PagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Status bar area
        const _StatusBar(),

        // Content area with placeholders
        const Expanded(child: _PlaceholderContent()),

        // Home indicator
        const _HomeIndicator(),
      ],
    );
  }
}

/// Status bar with notch/dynamic island indicator.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        // Dynamic island style notch
        child: Container(
          width: 80,
          height: 24,
          decoration: BoxDecoration(
            color: colors.overlay.overlay10,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Bottom home indicator bar.
class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 24,
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Container(
          width: 100,
          height: 4,
          decoration: BoxDecoration(
            color: colors.overlay.overlay10,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Faded placeholder content simulating widgets on the page.
class _PlaceholderContent extends StatelessWidget {
  const _PlaceholderContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header placeholder
          _PlaceholderRect(widthFactor: 0.5, height: 16),
          SizedBox(height: 16),

          // Hero/banner placeholder
          _PlaceholderRect(widthFactor: 1.0, height: 80),
          SizedBox(height: 12),

          // Two-column content
          Row(
            children: [
              Expanded(child: _PlaceholderRect(height: 60)),
              SizedBox(width: 8),
              Expanded(child: _PlaceholderRect(height: 60)),
            ],
          ),
          SizedBox(height: 12),

          // List items
          _PlaceholderRect(widthFactor: 1.0, height: 40),
          SizedBox(height: 8),
          _PlaceholderRect(widthFactor: 0.9, height: 40),
          SizedBox(height: 8),
          _PlaceholderRect(widthFactor: 0.85, height: 40),

          Spacer(),

          // Bottom button placeholder
          _PlaceholderRect(widthFactor: 1.0, height: 44),
        ],
      ),
    );
  }
}

/// A single placeholder rectangle representing a widget.
class _PlaceholderRect extends StatelessWidget {
  const _PlaceholderRect({this.widthFactor = 1.0, required this.height});

  /// Fraction of available width (0.0 to 1.0).
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.overlay.overlay05,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
