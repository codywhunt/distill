import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

/// A unified icon type that can represent either standard [IconData] or HugeIcons.
///
/// Use the factory constructors to create icons:
/// ```dart
/// // From LucideIcons or any IconData
/// HoloIconData.icon(LucideIcons.search)
///
/// // From HugeIcons
/// HoloIconData.huge(HugeIconsStrokeRounded.search01)
/// ```
sealed class HoloIconData {
  const HoloIconData();

  /// Creates icon data from standard [IconData] (LucideIcons, Material Icons, etc.).
  const factory HoloIconData.icon(IconData icon) = StandardHoloIconData;

  /// Creates icon data from HugeIcons.
  const factory HoloIconData.huge(List<List<dynamic>> icon) = HugeHoloIconData;
}

/// Icon data wrapping standard [IconData].
final class StandardHoloIconData extends HoloIconData {
  /// The standard icon data.
  final IconData icon;

  /// Creates standard icon data.
  const StandardHoloIconData(this.icon);
}

/// Icon data wrapping HugeIcons.
final class HugeHoloIconData extends HoloIconData {
  /// The HugeIcons icon data.
  final List<List<dynamic>> icon;

  /// Creates HugeIcons icon data.
  const HugeHoloIconData(this.icon);
}

/// A unified icon widget that supports both standard [IconData] (like LucideIcons)
/// and HugeIcons through [HoloIconData].
///
/// This provides a consistent API for rendering icons regardless of the source:
///
/// ```dart
/// // Using LucideIcons (IconData)
/// HoloIcon(HoloIconData.icon(LucideIcons.search), size: 24, color: Colors.blue)
///
/// // Using HugeIcons
/// HoloIcon(HoloIconData.huge(HugeIconsStrokeRounded.search01), size: 24, color: Colors.blue)
/// ```
///
/// For convenience when working with just one icon type, use the named constructors:
///
/// ```dart
/// // Standard IconData
/// HoloIcon.iconData(LucideIcons.search, size: 24)
///
/// // HugeIcons
/// HoloIcon.hugeIcon(HugeIconsStrokeRounded.search01, size: 24, strokeWidth: 1.5)
/// ```
class HoloIcon extends StatelessWidget {
  /// The icon data to display.
  final HoloIconData iconData;

  /// The size of the icon in logical pixels.
  final double? size;

  /// The color of the icon.
  ///
  /// If null, the icon will inherit color from [IconTheme] or default to
  /// the current text color.
  final Color? color;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// The stroke width for HugeIcons (only applies to HugeIcons).
  final double? strokeWidth;

  /// The secondary color for duotone/twotone HugeIcons.
  final Color? secondaryColor;

  /// Creates a [HoloIcon] from [HoloIconData].
  const HoloIcon(
    this.iconData, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.strokeWidth,
    this.secondaryColor,
  });

  /// Creates a [HoloIcon] from standard [IconData] (LucideIcons, Material Icons, etc.).
  HoloIcon.iconData(
    IconData icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  })  : iconData = StandardHoloIconData(icon),
        strokeWidth = null,
        secondaryColor = null;

  /// Creates a [HoloIcon] from HugeIcons data.
  HoloIcon.hugeIcon(
    List<List<dynamic>> icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
    this.strokeWidth,
    this.secondaryColor,
  }) : iconData = HugeHoloIconData(icon);

  @override
  Widget build(BuildContext context) {
    return switch (iconData) {
      StandardHoloIconData(icon: final icon) => Icon(
          icon,
          size: size,
          color: color,
          semanticLabel: semanticLabel,
        ),
      HugeHoloIconData(icon: final icon) => HugeIcon(
          icon: icon,
          size: size,
          color: color,
          secondaryColor: secondaryColor,
          strokeWidth: strokeWidth,
        ),
    };
  }
}

/// Extension on [IconData] for convenient conversion to [HoloIconData].
extension IconDataToHoloIcon on IconData {
  /// Converts this [IconData] to [HoloIconData].
  HoloIconData get holo => HoloIconData.icon(this);
}

/// Extension on HugeIcon data for convenient conversion to [HoloIconData].
extension HugeIconDataToHoloIcon on List<List<dynamic>> {
  /// Converts this HugeIcon data to [HoloIconData].
  HoloIconData get holo => HoloIconData.huge(this);
}
