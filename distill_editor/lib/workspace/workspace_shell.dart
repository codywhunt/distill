import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'workspace_state.dart';
import 'workspace_layout_state.dart';
// import 'components/side_navigation.dart';
import 'components/breadcrumb_bar.dart';
import 'components/resizable_panel.dart';
import 'components/animated_panel_wrapper.dart';
import 'components/macos_traffic_light_toggle.dart';
import '../commands/command_palette_overlay.dart';
import '../modules/module_registry.dart';

/// The main workspace shell that wraps all module content.
///
/// Responsibilities:
/// - Side navigation
/// - Left panel container
/// - Center content with breadcrumb bar
/// - Right panel container
/// - Overlay stack (command palette, dialogs)
///
/// Key architectural decisions:
/// - IndexedStack for all three regions (left, center, right) to preserve
///   module state across switches
/// - Panels stay mounted when collapsed (visual-only collapse) to preserve
///   scroll positions, text field focus, etc.
/// - Lazy initialization: modules only build on first visit
/// - ResizablePanel uses local state during drag (no provider spam)
/// - AnimatedPanelWrapper uses SizeTransition (GPU-accelerated)
class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({super.key});

  @override
  State<WorkspaceShell> createState() => _WorkspaceShellState();
}

class _WorkspaceShellState extends State<WorkspaceShell> {
  /// Tracks which modules have been visited (for lazy initialization).
  final Set<ModuleType> _initializedModules = {};

  @override
  Widget build(BuildContext context) {
    // Wait for layout state to be restored from storage before rendering.
    // This prevents a flash of default panel visibility on page load.
    final isRestored = context.select((WorkspaceLayoutState s) => s.isRestored);
    if (!isRestored) {
      return const SizedBox.shrink();
    }

    final currentModule = context.select((WorkspaceState s) => s.currentModule);

    // Mark current module as initialized
    _initializedModules.add(currentModule);

    return Stack(
      children: [
        // Main layout
        Row(
          children: [
            // Side navigation (always visible)
            // const SideNavigation(),

            // Left panel with optimized resize + animation
            _buildLeftPanel(context, currentModule),

            // Center content (expands to fill)
            Expanded(
              child: Stack(
                children: [
                  // Module content (IndexedStack)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: _buildCenterContentStack(currentModule),
                    ),
                  ),

                  // Floating top bar with search and panel toggles
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: CenterTopBar(),
                  ),
                ],
              ),
            ),

            // Right panel with optimized resize + animation
            _buildRightPanel(context, currentModule),
          ],
        ),

        // macOS traffic light toggle (always visible, positioned next to traffic lights)
        if (Platform.isMacOS) const MacOSTrafficLightToggle(),

        // Overlay stack (command palette, dialogs)
        const CommandPaletteOverlay(),
      ],
    );
  }

  /// Builds the left panel with optimized resize and animation.
  Widget _buildLeftPanel(BuildContext context, ModuleType currentModule) {
    return Selector<WorkspaceLayoutState, _LeftPanelState>(
      selector:
          (_, layout) => _LeftPanelState(
            isVisible:
                layout.hasLeftPanel(currentModule) &&
                layout.isLeftPanelVisible(currentModule),
            width: layout.leftPanelWidth,
            isContextSwitch: layout.isContextSwitch,
          ),
      builder: (context, state, _) {
        final layout = context.read<WorkspaceLayoutState>();

        return AnimatedPanelWrapper(
          isVisible: state.isVisible,
          position: DragHandlePosition.right,
          animate:
              !state.isContextSwitch, // Disable animation during context switch
          child: RepaintBoundary(
            child: ResizablePanel(
              width: state.width,
              minWidth: WorkspaceLayoutState.minPanelWidth,
              maxWidth: WorkspaceLayoutState.maxPanelWidth,
              defaultWidth: WorkspaceLayoutState.defaultLeftWidth,
              dragHandlePosition: DragHandlePosition.right,
              onResize: layout.setLeftPanelWidth,
              onResizeStart: () => layout.setResizing(true),
              onResizeEnd: () {
                layout.setResizing(false);
                layout.persistLeftPanelWidth();
              },
              child: _buildLeftPanelStack(currentModule),
            ),
          ),
        );
      },
    );
  }

  /// Builds the right panel with optimized resize and animation.
  Widget _buildRightPanel(BuildContext context, ModuleType currentModule) {
    return Selector<WorkspaceLayoutState, _RightPanelState>(
      selector:
          (_, layout) => _RightPanelState(
            isVisible:
                layout.hasRightPanel(currentModule) &&
                layout.isRightPanelVisible(currentModule),
            width: layout.rightPanelWidth,
            isContextSwitch: layout.isContextSwitch,
          ),
      builder: (context, state, _) {
        final layout = context.read<WorkspaceLayoutState>();

        return AnimatedPanelWrapper(
          isVisible: state.isVisible,
          position: DragHandlePosition.left,
          animate:
              !state.isContextSwitch, // Disable animation during context switch
          child: RepaintBoundary(
            child: ResizablePanel(
              width: state.width,
              minWidth: WorkspaceLayoutState.minPanelWidth,
              maxWidth: WorkspaceLayoutState.maxPanelWidth,
              defaultWidth: WorkspaceLayoutState.defaultRightWidth,
              dragHandlePosition: DragHandlePosition.left,
              onResize: layout.setRightPanelWidth,
              onResizeStart: () => layout.setResizing(true),
              onResizeEnd: () {
                layout.setResizing(false);
                layout.persistRightPanelWidth();
              },
              child: _buildRightPanelStack(currentModule),
            ),
          ),
        );
      },
    );
  }

  /// Builds center content using IndexedStack for instant switching.
  Widget _buildCenterContentStack(ModuleType currentModule) {
    return IndexedStack(
      index: currentModule.index,
      children:
          ModuleType.values.map((module) {
            // Lazy init: only build modules that have been visited
            if (!_initializedModules.contains(module)) {
              return const SizedBox.shrink();
            }
            return ModuleRegistry.buildCenterContent(module);
          }).toList(),
    );
  }

  /// Builds left panel using IndexedStack for state preservation across modules.
  Widget _buildLeftPanelStack(ModuleType currentModule) {
    return IndexedStack(
      index: currentModule.index,
      children:
          ModuleType.values.map((module) {
            if (!_initializedModules.contains(module)) {
              return const SizedBox.shrink();
            }
            return ModuleRegistry.buildLeftPanel(module);
          }).toList(),
    );
  }

  /// Builds right panel using IndexedStack for state preservation across modules.
  Widget _buildRightPanelStack(ModuleType currentModule) {
    return IndexedStack(
      index: currentModule.index,
      children:
          ModuleType.values.map((module) {
            if (!_initializedModules.contains(module)) {
              return const SizedBox.shrink();
            }
            return ModuleRegistry.buildRightPanel(module);
          }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selector State Objects
// ─────────────────────────────────────────────────────────────────────────────

/// State for left panel selector (minimal rebuilds)
class _LeftPanelState {
  final bool isVisible;
  final double width;
  final bool isContextSwitch;

  _LeftPanelState({
    required this.isVisible,
    required this.width,
    required this.isContextSwitch,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _LeftPanelState &&
          runtimeType == other.runtimeType &&
          isVisible == other.isVisible &&
          width == other.width &&
          isContextSwitch == other.isContextSwitch;

  @override
  int get hashCode =>
      isVisible.hashCode ^ width.hashCode ^ isContextSwitch.hashCode;
}

/// State for right panel selector (minimal rebuilds)
class _RightPanelState {
  final bool isVisible;
  final double width;
  final bool isContextSwitch;

  _RightPanelState({
    required this.isVisible,
    required this.width,
    required this.isContextSwitch,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RightPanelState &&
          runtimeType == other.runtimeType &&
          isVisible == other.isVisible &&
          width == other.width &&
          isContextSwitch == other.isContextSwitch;

  @override
  int get hashCode =>
      isVisible.hashCode ^ width.hashCode ^ isContextSwitch.hashCode;
}
