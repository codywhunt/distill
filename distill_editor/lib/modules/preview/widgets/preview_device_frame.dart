import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../../models/device_bezel.dart';
import '../../../models/device_preset.dart';

/// Device frame for app preview with optional realistic bezel.
///
/// If a bezel SVG is available for the device, renders the SVG with content
/// positioned in the screen area. Otherwise, falls back to a simple styled
/// container.
class PreviewDeviceFrame extends StatelessWidget {
  const PreviewDeviceFrame({
    super.key,
    required this.preset,
    this.child,
    this.showBezel = true,
    this.bezelColorId,
  });

  /// The device preset determining size and styling.
  final DevicePreset preset;

  /// Optional content to display inside the frame.
  /// If null, shows placeholder content.
  final Widget? child;

  /// Whether to show the realistic bezel (if available).
  /// When false, always uses the simple frame style.
  final bool showBezel;

  /// The bezel color variant ID to use. If null, uses the default color.
  final String? bezelColorId;

  @override
  Widget build(BuildContext context) {
    final bezelConfig = showBezel ? DeviceBezels.forDeviceId(preset.id) : null;

    if (bezelConfig != null) {
      return _BezelFrame(
        preset: preset,
        bezelConfig: bezelConfig,
        colorVariant: bezelConfig.getColor(bezelColorId),
        child: child,
      );
    }

    return _SimpleFrame(preset: preset, child: child);
  }
}

/// Renders a device with an SVG bezel overlay.
class _BezelFrame extends StatelessWidget {
  const _BezelFrame({
    required this.preset,
    required this.bezelConfig,
    required this.colorVariant,
    this.child,
  });

  final DevicePreset preset;
  final DeviceBezelConfig bezelConfig;
  final BezelColorVariant colorVariant;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Calculate the scale to fit the bezel's screen area to the preset size
    final scale = bezelConfig.scaleForScreenSize(preset.size);
    final totalSize = bezelConfig.sizeForScreenSize(preset.size);

    // Calculate scaled screen position
    final scaledScreenRect = Rect.fromLTWH(
      bezelConfig.screenRect.left * scale,
      bezelConfig.screenRect.top * scale,
      bezelConfig.screenRect.width * scale,
      bezelConfig.screenRect.height * scale,
    );
    final scaledBorderRadius = bezelConfig.screenBorderRadius * scale;

    return SizedBox(
      width: totalSize.width,
      height: totalSize.height,
      child: Stack(
        children: [
          // Content layer (behind the bezel)
          Positioned(
            left: scaledScreenRect.left,
            top: scaledScreenRect.top,
            width: scaledScreenRect.width,
            height: scaledScreenRect.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(scaledBorderRadius),
              child: child ?? _PreviewPlaceholder(preset: preset),
            ),
          ),

          // SVG bezel layer (on top)
          Positioned.fill(
            child: IgnorePointer(
              child: SvgPicture.asset(
                colorVariant.assetPath,
                width: totalSize.width,
                height: totalSize.height,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple fallback frame without SVG bezel.
class _SimpleFrame extends StatelessWidget {
  const _SimpleFrame({required this.preset, this.child});

  final DevicePreset preset;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = preset.cardBorderRadius;

    return Container(
      width: preset.size.width,
      height: preset.size.height,
      decoration: BoxDecoration(
        color: colors.background.secondary,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colors.stroke, width: 1.5),
        boxShadow: context.shadows.elevation300,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - 1.5),
        child: child ?? _PreviewPlaceholder(preset: preset),
      ),
    );
  }
}

/// Placeholder content for the preview frame.
class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({required this.preset});

  final DevicePreset preset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      color: colors.background.secondary,
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Status bar area
          _StatusBar(preset: preset),

          // Content area
          Expanded(child: _PlaceholderContent()),

          // Home indicator (for phones/tablets)
          if (preset.category != DeviceCategory.desktop) _HomeIndicator(),
        ],
      ),
    );
  }
}

/// Status bar with dynamic island/notch indicator.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.preset});

  final DevicePreset preset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // Desktop doesn't have status bar
    if (preset.category == DeviceCategory.desktop) {
      return const SizedBox(height: 8);
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        // Dynamic island for phones
        child: preset.category == DeviceCategory.phone
            ? Container(
                width: 120,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.overlay.overlay10,
                  borderRadius: BorderRadius.circular(17),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Home indicator bar.
class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 28,
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Container(
          width: 120,
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

/// Placeholder content simulating an app screen.
class _PlaceholderContent extends StatelessWidget {
  const _PlaceholderContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App bar placeholder
          Row(
            children: [
              _PlaceholderBox(width: 32, height: 32),
              const SizedBox(width: 12),
              Expanded(child: _PlaceholderBox(height: 20)),
              const SizedBox(width: 12),
              _PlaceholderBox(width: 32, height: 32),
            ],
          ),
          const SizedBox(height: 24),

          // Hero section
          _PlaceholderBox(height: 120, widthFactor: 1.0),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(child: _PlaceholderBox(height: 64)),
              const SizedBox(width: 8),
              Expanded(child: _PlaceholderBox(height: 64)),
              const SizedBox(width: 8),
              Expanded(child: _PlaceholderBox(height: 64)),
            ],
          ),
          const SizedBox(height: 24),

          // Section title
          _PlaceholderBox(width: 80, height: 12),
          const SizedBox(height: 12),

          // List items
          _PlaceholderBox(height: 56, widthFactor: 1.0),
          const SizedBox(height: 8),
          _PlaceholderBox(height: 56, widthFactor: 1.0),
          const SizedBox(height: 8),
          _PlaceholderBox(height: 56, widthFactor: 1.0),

          const Spacer(),

          // Bottom action
          _PlaceholderBox(height: 48, widthFactor: 1.0),
        ],
      ),
    );
  }
}

/// A placeholder rectangle.
class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({this.width, required this.height, this.widthFactor});

  final double? width;
  final double height;
  final double? widthFactor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.overlay.overlay05,
        borderRadius: BorderRadius.circular(8),
      ),
    );

    if (widthFactor != null) {
      return FractionallySizedBox(widthFactor: widthFactor, child: box);
    }

    return box;
  }
}
