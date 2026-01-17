import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';
import 'package:provider/provider.dart';

import '../../../models/device_preset.dart';
import '../preview_state.dart';
import '../widgets/preview_device_frame.dart';

/// Infinite canvas view for app preview.
///
/// Displays a single device frame centered in the viewport with:
/// - Bounded panning (can't pan away from device)
/// - Zoom in/out support
/// - Frame label showing device name
class PreviewCanvasView extends StatefulWidget {
  const PreviewCanvasView({super.key});

  @override
  State<PreviewCanvasView> createState() => _PreviewCanvasViewState();
}

class _PreviewCanvasViewState extends State<PreviewCanvasView> {
  late final InfiniteCanvasController _controller;

  @override
  void initState() {
    super.initState();
    _controller = InfiniteCanvasController();

    // Register controller with state after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PreviewModuleState>().setCanvasController(_controller);
      }
    });
  }

  @override
  void dispose() {
    context.read<PreviewModuleState>().clearCanvasController();
    _controller.dispose();
    super.dispose();
  }

  /// Get the device bounds rect at origin.
  Rect _getDeviceBounds(DevicePreset preset) {
    return Rect.fromLTWH(0, 0, preset.size.width, preset.size.height);
  }

  /// Get pan bounds with margin around device.
  Rect _getPanBounds(DevicePreset preset) {
    return _getDeviceBounds(preset).inflate(100);
  }

  /// Focus canvas on current device bounds.
  void _focusOnDevice(DevicePreset preset) {
    _controller.focusOn(
      _getDeviceBounds(preset),
      padding: const EdgeInsets.all(200),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Selector<PreviewModuleState, (DevicePreset, String?)>(
      selector: (_, state) => (state.devicePreset, state.bezelColorId),
      builder: (context, record, _) {
        final (devicePreset, bezelColorId) = record;
        final deviceBounds = _getDeviceBounds(devicePreset);

        return InfiniteCanvas(
          controller: _controller,
          backgroundColor: colors.background.primary,
          initialViewport: InitialViewport.fitRect(
            deviceBounds,
            padding: const EdgeInsets.all(200),
          ),
          physicsConfig: CanvasPhysicsConfig(
            minZoom: 0.25,
            maxZoom: 2.0,
            panBounds: _getPanBounds(devicePreset),
          ),
          gestureConfig: CanvasGestureConfig.all,
          layers: CanvasLayers(
            background: (ctx, ctrl) => const _PreviewBackground(),
            content: (ctx, ctrl) => Stack(
              clipBehavior: Clip.none,
              children: [
                CanvasItem(
                  position: Offset.zero,
                  child: PreviewDeviceFrame(
                    preset: devicePreset,
                    bezelColorId: bezelColorId,
                  ),
                ),
              ],
            ),
          ),
          onDoubleTapWorld: (_) => _focusOnDevice(devicePreset),
        );
      },
    );
  }
}

/// Subtle background for the preview canvas.
class _PreviewBackground extends StatelessWidget {
  const _PreviewBackground();

  @override
  Widget build(BuildContext context) {
    // Simple solid background - could add subtle grid later
    return const SizedBox.shrink();
  }
}
