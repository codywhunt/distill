import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// A simplified device-shaped page card for browse mode.
///
/// Displays a device-like frame with faded placeholder content.
/// The page name label is rendered separately in the overlay layer
/// so it maintains a constant screen-space size regardless of zoom.
class PageCardBrowse extends StatelessWidget {
  const PageCardBrowse({
    super.key,
    required this.size,
    this.borderRadius,
    this.isSelected = false,
    this.isHovered = false,
  });

  final Size size;

  /// Border radius for the card frame.
  /// If null, defaults to a proportional value based on width.
  final double? borderRadius;

  final bool isSelected;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    // Just the device frame - label is in overlay layer
    return _DeviceFrame(
      size: size,
      borderRadius: borderRadius,
      isSelected: isSelected,
      isHovered: isHovered,
    );
  }
}

/// Device-like frame container with rounded corners and device styling.
class _DeviceFrame extends StatelessWidget {
  const _DeviceFrame({
    required this.size,
    this.borderRadius,
    required this.isSelected,
    required this.isHovered,
  });

  final Size size;
  final double? borderRadius;
  final bool isSelected;
  final bool isHovered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Use provided border radius or calculate proportionally
    final cornerRadius = borderRadius ?? size.width * 0.08;

    // Determine border color based on state
    final borderColor = isSelected
        ? colors.accent.purple.primary
        : isHovered
        ? colors.foreground.weak
        : colors.stroke;

    // Determine border width based on state
    final borderWidth = 2.0;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: colors.background.secondary,
        borderRadius: BorderRadius.circular(cornerRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: context.shadows.elevation300,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cornerRadius - 1),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Status bar area
            _StatusBar(isSelected: isSelected),

            // Content area with placeholders
            Expanded(child: _PlaceholderContent()),

            // Home indicator
            _HomeIndicator(),
          ],
        ),
      ),
    );
  }
}

/// Status bar with notch/dynamic island indicator.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.isSelected});

  final bool isSelected;

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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header placeholder
          const _PlaceholderRect(widthFactor: 0.5, height: 16),
          const SizedBox(height: 16),

          // Hero/banner placeholder
          const _PlaceholderRect(widthFactor: 1.0, height: 80),
          const SizedBox(height: 12),

          // Two-column content
          const Row(
            children: [
              Expanded(child: _PlaceholderRect(height: 60)),
              SizedBox(width: 8),
              Expanded(child: _PlaceholderRect(height: 60)),
            ],
          ),
          const SizedBox(height: 12),

          // List items
          const _PlaceholderRect(widthFactor: 1.0, height: 40),
          const SizedBox(height: 8),
          const _PlaceholderRect(widthFactor: 0.9, height: 40),
          const SizedBox(height: 8),
          const _PlaceholderRect(widthFactor: 0.85, height: 40),

          const Spacer(),

          // Bottom button placeholder
          const _PlaceholderRect(widthFactor: 1.0, height: 44),
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
