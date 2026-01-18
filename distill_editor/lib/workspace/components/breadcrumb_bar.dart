import 'dart:io' show Platform;

import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';
import 'package:provider/provider.dart';

import '../workspace_state.dart';
import '../workspace_layout_state.dart';
import '../../commands/command_palette_state.dart';
import '../../modules/canvas/canvas_state.dart';
import '../../modules/canvas/widgets/device_selector_button.dart';
import '../../modules/canvas/widgets/zoom_menu_button.dart';
import '../../modules/preview/preview_state.dart';
import '../../modules/preview/widgets/preview_zoom_menu_button.dart';
import 'panel_container.dart';

/// Floating navigation bar at the top of the center content.
///
/// Uses a Stack layout to ensure the search bar is always truly centered,
/// regardless of the number or size of controls on either side.
///
/// Shows:
/// - Center: Search bar / breadcrumb (always centered)
/// - Left: Panel toggle (when hidden), device selector, back button (canvas)
/// - Right: Zoom menu (canvas), panel toggle (when hidden)
class CenterTopBar extends StatelessWidget {
  const CenterTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentModule = context.select((WorkspaceState s) => s.currentModule);

    return Selector<WorkspaceLayoutState, _PanelVisibility>(
      selector:
          (_, layout) => _PanelVisibility(
            leftHidden:
                layout.hasLeftPanel(currentModule) &&
                !layout.isLeftPanelVisible(currentModule),
            rightHidden:
                layout.hasRightPanel(currentModule) &&
                !layout.isRightPanelVisible(currentModule),
          ),
      builder: (context, visibility, _) {
        final layout = context.read<WorkspaceLayoutState>();
        final spacing = context.spacing;

        return Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left controls
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Panel toggle (when hidden) - only on non-macOS
                    // On macOS, the toggle is always visible next to traffic lights
                    if (visibility.leftHidden && !Platform.isMacOS) ...[
                      HiddenPanelToggle(
                        panelSide: PanelSide.left,
                        onTap: () => layout.toggleLeftPanel(currentModule),
                        tooltip: 'Show left panel',
                      ),
                      SizedBox(width: spacing.sm),
                    ],
                    // Device selector (preview only - canvas doesn't have device modes)
                    if (currentModule == ModuleType.preview) ...[
                      const _PreviewDeviceSelectorWrapper(),
                      SizedBox(width: spacing.sm),
                    ],
                    // No back button needed (no edit mode)
                  ],
                ),
              ),

              // Center search bar (always truly centered)
              Center(
                child: _SearchBarBreadcrumb(
                  module: currentModule,
                  onTap: () => context.read<CommandPaletteState>().open(),
                ),
              ),

              // Right controls
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom menu (canvas and preview)
                    if (currentModule == ModuleType.canvas)
                      const _ZoomMenuButtonWrapper(),
                    if (currentModule == ModuleType.preview)
                      const _PreviewZoomMenuButtonWrapper(),
                    // Spacing between zoom menu and panel toggle (only when both present)
                    if ((currentModule == ModuleType.canvas ||
                            currentModule == ModuleType.preview) &&
                        visibility.rightHidden)
                      SizedBox(width: spacing.sm),
                    // Panel toggle (when hidden)
                    if (visibility.rightHidden)
                      HiddenPanelToggle(
                        panelSide: PanelSide.right,
                        onTap: () => layout.toggleRightPanel(currentModule),
                        tooltip: 'Show right panel',
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// State for panel visibility selector.
class _PanelVisibility {
  final bool leftHidden;
  final bool rightHidden;

  _PanelVisibility({required this.leftHidden, required this.rightHidden});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PanelVisibility &&
          leftHidden == other.leftHidden &&
          rightHidden == other.rightHidden;

  @override
  int get hashCode => leftHidden.hashCode ^ rightHidden.hashCode;
}

/// Pill-shaped search bar showing the current module.
class _SearchBarBreadcrumb extends StatelessWidget {
  const _SearchBarBreadcrumb({required this.module, required this.onTap});

  final ModuleType module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Get the display label, which may include page name for canvas edit mode
    final displayLabel = _getDisplayLabel(context, module);

    return HoloTappable(
      onTap: onTap,
      cursor: SystemMouseCursors.basic,
      canRequestFocus: false,
      builder: (context, states, _) {
        final bgColor = states.resolve(
          base: context.colors.background.primary,
          hovered: context.colors.background.fullContrast,
          pressed: context.colors.background.secondary,
        );

        return Container(
          height: 34,
          constraints: const BoxConstraints(maxWidth: 450),
          padding: EdgeInsets.only(left: 14, right: context.spacing.md),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(context.radius.full),
            border: Border.all(
              color: context.colors.overlay.overlay10,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  displayLabel,
                  style: context.typography.body.medium.copyWith(
                    color: context.colors.foreground.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.spacing.md),
              HoloIcon(
                HoloIconData.huge(HugeIconsStrokeRounded.search01),
                size: 16,
                color: context.colors.foreground.disabled,
              ),
            ],
          ),
        );
      },
    );
  }

  String _getDisplayLabel(BuildContext context, ModuleType module) {
    // No edit mode, just return module label
    return module.label;
  }
}

/// Wrapper for ZoomMenuButton that gets the controller from canvas state.
class _ZoomMenuButtonWrapper extends StatelessWidget {
  const _ZoomMenuButtonWrapper();

  @override
  Widget build(BuildContext context) {
    final canvasState = context.watch<CanvasState>();
    final controller = canvasState.canvasController;

    if (controller == null) {
      // Controller not yet registered, show nothing
      return const SizedBox.shrink();
    }

    return ZoomMenuButton(controller: controller);
  }
}

/// Wrapper for DeviceSelectorButton that connects to PreviewModuleState.
class _PreviewDeviceSelectorWrapper extends StatelessWidget {
  const _PreviewDeviceSelectorWrapper();

  @override
  Widget build(BuildContext context) {
    final previewState = context.watch<PreviewModuleState>();

    return DeviceSelectorButton(
      value: previewState.devicePreset,
      onChanged: previewState.setDevicePreset,
      bezelColorId: previewState.bezelColorId,
      onBezelColorChanged: previewState.setBezelColor,
    );
  }
}

/// Wrapper for PreviewZoomMenuButton that gets the controller from preview state.
class _PreviewZoomMenuButtonWrapper extends StatelessWidget {
  const _PreviewZoomMenuButtonWrapper();

  @override
  Widget build(BuildContext context) {
    final previewState = context.watch<PreviewModuleState>();
    final controller = previewState.canvasController;

    if (controller == null) {
      return const SizedBox.shrink();
    }

    // Calculate device bounds at origin
    final deviceSize = previewState.devicePreset.size;
    final deviceBounds = Rect.fromLTWH(
      0,
      0,
      deviceSize.width,
      deviceSize.height,
    );

    return PreviewZoomMenuButton(
      controller: controller as InfiniteCanvasController,
      deviceBounds: deviceBounds,
    );
  }
}
