import 'package:flutter/widgets.dart';
import 'package:distill_ds/design_system.dart';

/// Category of device for grouping and icon selection.
enum DeviceCategory { phone, tablet, desktop }

/// A device preset representing a specific device size configuration.
///
/// Used to set the canvas/frame size for page editing.
@immutable
class DevicePreset {
  /// Unique identifier for this preset.
  final String id;

  /// Display name (e.g., "iPhone 16 Pro Max").
  final String name;

  /// The device screen size in logical pixels.
  final Size size;

  /// Category for grouping and icon selection.
  final DeviceCategory category;

  /// Whether this is a custom (user-defined) size.
  final bool isCustom;

  const DevicePreset({
    required this.id,
    required this.name,
    required this.size,
    required this.category,
    this.isCustom = false,
  });

  /// Creates a custom preset with arbitrary size.
  factory DevicePreset.custom(Size size) => DevicePreset(
    id: 'custom',
    name: 'Custom',
    size: size,
    category: DeviceCategory.phone,
    isCustom: true,
  );

  /// Display name including dimensions for custom presets.
  String get displayName =>
      isCustom ? 'Custom (${size.width.toInt()}×${size.height.toInt()})' : name;

  /// Display string for dimensions.
  String get dimensionsLabel => '${size.width.toInt()}×${size.height.toInt()}';

  /// Icon based on device category.
  IconData get icon => switch (category) {
    DeviceCategory.phone => LucideIcons.smartphone,
    DeviceCategory.tablet => LucideIcons.tablet,
    DeviceCategory.desktop => LucideIcons.monitor,
  };

  /// Border radius for storyboard card display.
  ///
  /// Phones get larger radius (rounded corners like real devices),
  /// tablets get medium radius, desktops get smaller radius.
  double get cardBorderRadius => switch (category) {
    DeviceCategory.phone => 44.0,
    DeviceCategory.tablet => 24.0,
    DeviceCategory.desktop => 12.0,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DevicePreset &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          size == other.size;

  @override
  int get hashCode => Object.hash(id, size);

  @override
  String toString() => 'DevicePreset($id, $size)';
}

/// Collection of curated device presets.
abstract class DevicePresets {
  // ─────────────────────────────────────────────────────────────────────────
  // Phones
  // ─────────────────────────────────────────────────────────────────────────

  static const iPhone17ProMax = DevicePreset(
    id: 'iphone-17-pro-max',
    name: 'iPhone 17 Pro Max',
    size: Size(440, 956),
    category: DeviceCategory.phone,
  );

  static const iPhone17Pro = DevicePreset(
    id: 'iphone-17-pro',
    name: 'iPhone 17 Pro',
    size: Size(402, 874),
    category: DeviceCategory.phone,
  );

  static const iPhone17 = DevicePreset(
    id: 'iphone-17',
    name: 'iPhone 17',
    size: Size(393, 852),
    category: DeviceCategory.phone,
  );

  static const iPhoneSE = DevicePreset(
    id: 'iphone-se',
    name: 'iPhone SE',
    size: Size(320, 568),
    category: DeviceCategory.phone,
  );

  static const androidCompact = DevicePreset(
    id: 'android-compact',
    name: 'Android Compact',
    size: Size(412, 917),
    category: DeviceCategory.phone,
  );

  static const androidMedium = DevicePreset(
    id: 'android-medium',
    name: 'Android Medium',
    size: Size(700, 840),
    category: DeviceCategory.phone,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Tablets
  // ─────────────────────────────────────────────────────────────────────────

  static const iPadMini = DevicePreset(
    id: 'ipad-mini',
    name: 'iPad mini 8.3"',
    size: Size(744, 1133),
    category: DeviceCategory.tablet,
  );

  static const iPadPro11 = DevicePreset(
    id: 'ipad-pro-11',
    name: 'iPad Pro 11"',
    size: Size(834, 1194),
    category: DeviceCategory.tablet,
  );

  static const iPadPro12 = DevicePreset(
    id: 'ipad-pro-12',
    name: 'iPad Pro 12.9"',
    size: Size(1024, 1366),
    category: DeviceCategory.tablet,
  );

  static const androidExpanded = DevicePreset(
    id: 'android-expanded',
    name: 'Android Expanded',
    size: Size(1280, 800),
    category: DeviceCategory.tablet,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Desktop
  // ─────────────────────────────────────────────────────────────────────────

  static const macBookAir = DevicePreset(
    id: 'macbook-air',
    name: 'MacBook Air',
    size: Size(1280, 832),
    category: DeviceCategory.desktop,
  );

  static const macBookPro14 = DevicePreset(
    id: 'macbook-pro-14',
    name: 'MacBook Pro 14"',
    size: Size(1512, 982),
    category: DeviceCategory.desktop,
  );

  static const macBookPro16 = DevicePreset(
    id: 'macbook-pro-16',
    name: 'MacBook Pro 16"',
    size: Size(1728, 1117),
    category: DeviceCategory.desktop,
  );

  static const desktop = DevicePreset(
    id: 'desktop',
    name: 'Desktop',
    size: Size(1440, 1024),
    category: DeviceCategory.desktop,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Collections
  // ─────────────────────────────────────────────────────────────────────────

  /// All phone presets.
  static const phones = [
    iPhone17ProMax,
    iPhone17Pro,
    iPhone17,
    iPhoneSE,
    androidCompact,
    androidMedium,
  ];

  /// All tablet presets.
  static const tablets = [iPadMini, iPadPro11, iPadPro12, androidExpanded];

  /// All desktop presets.
  static const desktops = [macBookAir, macBookPro14, macBookPro16, desktop];

  /// All presets grouped by category.
  static const byCategory = <DeviceCategory, List<DevicePreset>>{
    DeviceCategory.phone: phones,
    DeviceCategory.tablet: tablets,
    DeviceCategory.desktop: desktops,
  };

  /// All presets as a flat list.
  static const all = [...phones, ...tablets, ...desktops];

  /// Default preset (iPhone 17 Pro Max).
  static const defaultPreset = iPhone17ProMax;

  /// Find a preset by ID.
  static DevicePreset? findById(String id) {
    try {
      return all.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
