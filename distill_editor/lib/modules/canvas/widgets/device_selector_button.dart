import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../../models/device_bezel.dart';
import '../../../models/device_preset.dart';

/// A dropdown button for selecting the device/frame size.
///
/// Shows the current device name and icon, with a menu grouped by
/// device category (Phones, Tablets, Desktop).
///
/// Used in controlled mode - requires value and onChanged callbacks.
///
/// When a device has bezel color variants, shows color swatches below the
/// selected device item in the menu.
class DeviceSelectorButton extends StatelessWidget {
  const DeviceSelectorButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.bezelColorId,
    this.onBezelColorChanged,
  });

  /// The current device preset.
  final DevicePreset value;

  /// Called when a new preset is selected.
  final ValueChanged<DevicePreset> onChanged;

  /// The current bezel color variant ID.
  final String? bezelColorId;

  /// Called when a bezel color is selected.
  final ValueChanged<String>? onBezelColorChanged;

  @override
  Widget build(BuildContext context) {
    // Always use controlled mode
    final currentPreset = value;
    final handleChange = onChanged;

    // Check if current device has bezel color options
    // Only show color swatches when onBezelColorChanged is provided (preview module only)
    final bezelConfig = DeviceBezels.forDeviceId(currentPreset.id);
    final hasColorOptions =
        onBezelColorChanged != null &&
        bezelConfig != null &&
        bezelConfig.colorVariants.length > 1;

    // Build groups from device presets
    final groups = <HoloSelectGroup<DevicePreset>>[
      HoloSelectGroup(
        label: 'Phones',
        items: DevicePresets.phones
            .map(
              (p) => HoloSelectItem(
                value: p,
                label: p.displayName,
                subtitle: p.dimensionsLabel,
              ),
            )
            .toList(),
      ),
      HoloSelectGroup(
        label: 'Tablets',
        items: DevicePresets.tablets
            .map(
              (p) => HoloSelectItem(
                value: p,
                label: p.displayName,
                subtitle: p.dimensionsLabel,
              ),
            )
            .toList(),
      ),
      HoloSelectGroup(
        label: 'Desktop',
        items: DevicePresets.desktops
            .map(
              (p) => HoloSelectItem(
                value: p,
                label: p.displayName,
                subtitle: p.dimensionsLabel,
              ),
            )
            .toList(),
      ),
      // Add custom group if current preset is custom
      if (currentPreset.isCustom)
        HoloSelectGroup(
          label: 'Custom',
          items: [
            HoloSelectItem(
              value: currentPreset,
              label: currentPreset.displayName,
              subtitle: currentPreset.dimensionsLabel,
            ),
          ],
        ),
    ];

    return HoloSelect<DevicePreset>.grouped(
      value: currentPreset,
      onChanged: (preset) {
        if (preset != null) {
          handleChange(preset);
        }
      },
      groups: groups,
      menuWidth: 240,
      itemBuilder: hasColorOptions
          ? (context, item, isSelected, isHighlighted) => _DeviceMenuItem(
              item: item,
              isSelected: isSelected,
              isHighlighted: isHighlighted,
              showColorSwatches:
                  isSelected && DeviceBezels.forDeviceId(item.value.id) != null,
              bezelConfig: isSelected
                  ? DeviceBezels.forDeviceId(item.value.id)
                  : null,
              selectedColorId: bezelColorId,
              onColorSelected: onBezelColorChanged,
            )
          : null,
    );
  }
}

/// Custom menu item that can show color swatches for selected devices with bezels.
class _DeviceMenuItem extends StatelessWidget {
  const _DeviceMenuItem({
    required this.item,
    required this.isSelected,
    required this.isHighlighted,
    required this.showColorSwatches,
    this.bezelConfig,
    this.selectedColorId,
    this.onColorSelected,
  });

  final HoloSelectItem<DevicePreset> item;
  final bool isSelected;
  final bool isHighlighted;
  final bool showColorSwatches;
  final DeviceBezelConfig? bezelConfig;
  final String? selectedColorId;
  final ValueChanged<String>? onColorSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isHighlighted ? colors.overlay.overlay03 : null,
        borderRadius: BorderRadius.circular(radius.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Checkmark space
              SizedBox(
                width: 16,
                child: isSelected
                    ? Icon(
                        LucideIcons.check200,
                        size: 14,
                        color: colors.foreground.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 8),

              // Label
              Expanded(
                child: Text(
                  item.label,
                  style: context.typography.body.medium.copyWith(
                    color: colors.foreground.primary,
                  ),
                ),
              ),

              // Subtitle (dimensions)
              if (item.subtitle != null) ...[
                const SizedBox(width: 16),
                Text(
                  item.subtitle!,
                  style: context.typography.mono.small.copyWith(
                    color: colors.foreground.weak,
                  ),
                ),
              ],
            ],
          ),
          // Color swatches for selected device with bezel options
          if (showColorSwatches && bezelConfig != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 4),
              child: _BezelColorSwatches(
                config: bezelConfig!,
                selectedColorId: selectedColorId,
                onColorSelected: onColorSelected,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Row of color swatches for bezel variants.
class _BezelColorSwatches extends StatelessWidget {
  const _BezelColorSwatches({
    required this.config,
    this.selectedColorId,
    this.onColorSelected,
  });

  final DeviceBezelConfig config;
  final String? selectedColorId;
  final ValueChanged<String>? onColorSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final effectiveSelectedId = selectedColorId ?? config.defaultColorId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 6),
        Icon(
          LucideIcons.cornerDownRight200,
          size: 12,
          color: colors.foreground.weak,
        ),
        const SizedBox(width: 8),
        for (final variant in config.colorVariants) ...[
          Tooltip(
            message: variant.name,
            child: GestureDetector(
              onTap: () => onColorSelected?.call(variant.id),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: variant.swatchColor,
                  borderRadius: BorderRadius.circular(context.radius.xs),
                  boxShadow: context.shadows.elevation100,
                  border: Border.all(
                    color: effectiveSelectedId == variant.id
                        ? colors.foreground.primary
                        : colors.stroke,
                    width: effectiveSelectedId == variant.id ? 1 : 0,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: spacing.xs),
        ],
      ],
    );
  }
}
