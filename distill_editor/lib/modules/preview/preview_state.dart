import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/widgets.dart';

import '../../models/device_bezel.dart';
import '../../models/device_preset.dart';

/// State management for the App Preview module.
///
/// Manages:
/// - Device preset (determines preview frame size)
/// - Bezel color variant selection
/// - Canvas controller reference for toolbar controls
class PreviewModuleState extends ChangeNotifier {
  // ─────────────────────────────────────────────────────────────────────────
  // Device Preset
  // ─────────────────────────────────────────────────────────────────────────

  DevicePreset _devicePreset = DevicePresets.defaultPreset;

  /// The current device preset (determines preview frame size).
  DevicePreset get devicePreset => _devicePreset;

  /// Set the device preset for the preview.
  ///
  /// Automatically triggers a "fit to screen" animation to center
  /// on the new device bounds. Resets bezel color to default for new device.
  void setDevicePreset(DevicePreset preset) {
    if (_devicePreset.id == preset.id && !preset.isCustom) return;
    _devicePreset = preset;
    // Reset to default color for new device
    _bezelColorId = null;
    notifyListeners();

    // Fit to new device bounds after frame renders with new size
    if (_canvasController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bounds = Rect.fromLTWH(
          0,
          0,
          preset.size.width,
          preset.size.height,
        );
        (_canvasController as InfiniteCanvasController).focusOn(
          bounds,
          padding: const EdgeInsets.all(80),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bezel Color
  // ─────────────────────────────────────────────────────────────────────────

  String? _bezelColorId;

  /// The selected bezel color variant ID, or null for default.
  String? get bezelColorId => _bezelColorId;

  /// The bezel config for the current device, if available.
  DeviceBezelConfig? get bezelConfig =>
      DeviceBezels.forDeviceId(_devicePreset.id);

  /// The current bezel color variant, using default if none selected.
  BezelColorVariant? get currentBezelColor {
    final config = bezelConfig;
    if (config == null) return null;
    return config.getColor(_bezelColorId);
  }

  /// Set the bezel color variant.
  void setBezelColor(String colorId) {
    if (_bezelColorId == colorId) return;
    _bezelColorId = colorId;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Canvas Controller Reference
  // ─────────────────────────────────────────────────────────────────────────

  /// Reference to the active canvas controller.
  ///
  /// Set by PreviewCanvasView when it mounts, cleared when it unmounts.
  /// Used by toolbar controls (zoom menu) to interact with the canvas.
  dynamic _canvasController;

  /// The active canvas controller, if available.
  ///
  /// Returns null if the preview canvas is not mounted.
  /// Type is dynamic to avoid circular import with distill_canvas.
  dynamic get canvasController => _canvasController;

  /// Set the canvas controller reference (called by PreviewCanvasView).
  void setCanvasController(dynamic controller) {
    _canvasController = controller;
    notifyListeners();
  }

  /// Clear the canvas controller reference (called by PreviewCanvasView on dispose).
  void clearCanvasController() {
    _canvasController = null;
    notifyListeners();
  }
}
