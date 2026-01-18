import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';
import 'package:provider/provider.dart';

import '../workspace_state.dart';
import '../workspace_layout_state.dart';

/// Persistent toggle button positioned next to macOS traffic lights.
///
/// This widget is always visible on macOS, regardless of whether the left
/// panel is open or closed. It toggles the left panel visibility.
///
/// On non-macOS platforms, this widget renders nothing.
///
/// Must be used inside a Stack widget.
class MacOSTrafficLightToggle extends StatelessWidget {
  const MacOSTrafficLightToggle({super.key});

  // Traffic lights positioning on macOS with toolbar
  // Traffic lights are ~7px from left, centered vertically in 52px toolbar
  static const _trafficLightsLeft = 7.0;
  static const _trafficLightsWidth = 68.0; // Space taken by 3 buttons + gaps
  static const _toolbarHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) return const SizedBox.shrink();

    final currentModule = context.select((WorkspaceState s) => s.currentModule);
    final hasLeftPanel = context.select(
      (WorkspaceLayoutState s) => s.hasLeftPanel(currentModule),
    );

    // Don't show if this module doesn't have a left panel
    if (!hasLeftPanel) return const SizedBox.shrink();

    final layout = context.read<WorkspaceLayoutState>();

    return Positioned(
      top: 0,
      left:
          _trafficLightsLeft +
          _trafficLightsWidth +
          14, // 8px gap after traffic lights
      height: _toolbarHeight,
      child: Center(
        child: HoloIconButton(
          icon: HoloIconData.huge(HugeIconsStrokeRounded.sidebarLeft),
          onPressed: () => layout.toggleLeftPanel(currentModule),
          size: 34,
          iconSize: 16,
          tooltip: 'Toggle left panel',
        ),
      ),
    );
  }
}
