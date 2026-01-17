import 'package:flutter/widgets.dart';

/// A color variant for a device bezel.
@immutable
class BezelColorVariant {
  /// Unique identifier for this color variant.
  final String id;

  /// Display name (e.g., "Deep Blue", "Silver").
  final String name;

  /// Path to the SVG asset for this color variant.
  final String assetPath;

  /// Color to display in the swatch picker.
  final Color swatchColor;

  const BezelColorVariant({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.swatchColor,
  });
}

/// Configuration for a device bezel with multiple color variants.
///
/// Contains the screen area coordinates within the SVG and available
/// color variants, allowing content to be properly positioned inside
/// the bezel frame.
@immutable
class DeviceBezelConfig {
  /// The full size of the SVG viewport (same for all color variants).
  final Size svgSize;

  /// The screen area rect within the SVG where content should be rendered.
  final Rect screenRect;

  /// Border radius of the screen area for clipping.
  final double screenBorderRadius;

  /// Available color variants for this device.
  final List<BezelColorVariant> colorVariants;

  /// The default color variant ID.
  final String defaultColorId;

  const DeviceBezelConfig({
    required this.svgSize,
    required this.screenRect,
    required this.screenBorderRadius,
    required this.colorVariants,
    required this.defaultColorId,
  });

  /// The logical screen size (what the content sees).
  Size get screenSize => screenRect.size;

  /// Get the default color variant.
  BezelColorVariant get defaultColor =>
      colorVariants.firstWhere((v) => v.id == defaultColorId);

  /// Get a color variant by ID, or default if not found.
  BezelColorVariant getColor(String? colorId) {
    if (colorId == null) return defaultColor;
    return colorVariants.firstWhere(
      (v) => v.id == colorId,
      orElse: () => defaultColor,
    );
  }

  /// Scale factor to fit this bezel to a target screen size.
  double scaleForScreenSize(Size targetScreenSize) {
    return targetScreenSize.width / screenSize.width;
  }

  /// The total bezel size when scaled to fit a target screen size.
  Size sizeForScreenSize(Size targetScreenSize) {
    final scale = scaleForScreenSize(targetScreenSize);
    return Size(svgSize.width * scale, svgSize.height * scale);
  }
}

/// Collection of available device bezel configurations.
abstract class DeviceBezels {
  /// iPhone 17 Pro bezel configuration with color variants.
  static const iPhone17Pro = DeviceBezelConfig(
    svgSize: Size(1300, 2642),
    // From SVG: <rect x="65" y="55" width="1170" height="2532" rx="165"/>
    screenRect: Rect.fromLTWH(65, 55, 1170, 2532),
    screenBorderRadius: 165,
    defaultColorId: 'deep-blue',
    colorVariants: [
      BezelColorVariant(
        id: 'deep-blue',
        name: 'Deep Blue',
        assetPath: 'assets/bezels/iphone17pro-deepblue.svg',
        swatchColor: Color(0xFF1C3A5F),
      ),
      BezelColorVariant(
        id: 'silver',
        name: 'Silver',
        assetPath: 'assets/bezels/iphone17pro-silver.svg',
        swatchColor: Color(0xFFE3E3E3),
      ),
      BezelColorVariant(
        id: 'cosmic-orange',
        name: 'Cosmic Orange',
        assetPath: 'assets/bezels/iphone17pro-cosmicorange.svg',
        swatchColor: Color(0xFFD4714A),
      ),
    ],
  );

  /// Get a bezel config for a device ID, if available.
  static DeviceBezelConfig? forDeviceId(String deviceId) {
    return switch (deviceId) {
      'iphone-17-pro-max' => iPhone17Pro,
      'iphone-17-pro' => iPhone17Pro,
      'iphone-17' => iPhone17Pro,
      _ => null,
    };
  }
}
