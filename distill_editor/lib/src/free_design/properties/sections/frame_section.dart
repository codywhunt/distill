import 'package:flutter/widgets.dart';
import 'package:distill_ds/design_system.dart';

import '../../../../models/device_preset.dart';
import '../../models/frame.dart';
import '../../store/editor_document_store.dart';
import '../widgets/property_section_header.dart';
import '../editors/widgets/property_field.dart';
import '../editors/primitives/number_editor.dart';

/// Properties for a selected frame.
class FrameSection extends StatelessWidget {
  const FrameSection({
    required this.frameId,
    required this.frame,
    required this.store,
    super.key,
  });

  final String frameId;
  final Frame frame;
  final EditorDocumentStore store;

  @override
  Widget build(BuildContext context) {
    // Determine current device preset based on frame size
    final currentPreset = _matchDevicePreset(frame.canvas.size);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PropertySectionHeader(title: 'Frame', showTopDivider: false),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.xs,
          ),
          child: Column(
            children: [
              // Device selector dropdown
              PropertyField(
                label: 'Device',
                child: _FrameDeviceSelector(
                  currentPreset: currentPreset,
                  onChanged: (preset) {
                    // Update both width and height at once
                    store.updateFrameProp(
                      frameId,
                      '/canvas/size/width',
                      preset.size.width,
                    );
                    store.updateFrameProp(
                      frameId,
                      '/canvas/size/height',
                      preset.size.height,
                    );
                  },
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Width input
              PropertyField(
                label: 'W',
                child: NumberEditor(
                  value: frame.canvas.size.width,
                  onChanged: (v) {
                    if (v != null && v > 0) {
                      store.updateFrameProp(
                        frameId,
                        '/canvas/size/width',
                        v.toDouble(),
                      );
                    }
                  },
                  min: 1,
                  allowDecimals: false,
                ),
              ),
              SizedBox(height: context.spacing.xs),

              // Height input
              PropertyField(
                label: 'H',
                child: NumberEditor(
                  value: frame.canvas.size.height,
                  onChanged: (v) {
                    if (v != null && v > 0) {
                      store.updateFrameProp(
                        frameId,
                        '/canvas/size/height',
                        v.toDouble(),
                      );
                    }
                  },
                  min: 1,
                  allowDecimals: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Match current frame size to a device preset, or return Custom.
  DevicePreset _matchDevicePreset(Size size) {
    // Try to find exact match in presets
    for (final preset in DevicePresets.all) {
      if (preset.size == size) {
        return preset;
      }
    }
    // No match - return custom
    return DevicePreset.custom(size);
  }
}

/// Device selector dropdown for frame property panel.
///
/// Shows grouped presets (Phones, Tablets, Desktop) and a Custom group
/// when the current size doesn't match any preset.
class _FrameDeviceSelector extends StatelessWidget {
  const _FrameDeviceSelector({
    required this.currentPreset,
    required this.onChanged,
  });

  final DevicePreset currentPreset;
  final ValueChanged<DevicePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    final groups = <HoloSelectGroup<DevicePreset>>[
      HoloSelectGroup(
        label: 'Phones',
        items: DevicePresets.phones.map(_toItem).toList(),
      ),
      HoloSelectGroup(
        label: 'Tablets',
        items: DevicePresets.tablets.map(_toItem).toList(),
      ),
      HoloSelectGroup(
        label: 'Desktop',
        items: DevicePresets.desktops.map(_toItem).toList(),
      ),
      // Show Custom group if current size doesn't match any preset
      if (currentPreset.isCustom)
        HoloSelectGroup(label: 'Custom', items: [_toItem(currentPreset)]),
    ];

    return HoloSelect<DevicePreset>.grouped(
      value: currentPreset,
      onChanged: (preset) {
        if (preset != null) onChanged(preset);
      },
      groups: groups,
      menuWidth: 220,
      expand: true,
    );
  }

  HoloSelectItem<DevicePreset> _toItem(DevicePreset p) => HoloSelectItem(
    value: p,
    label: p.displayName,
    subtitle: p.dimensionsLabel,
  );
}
