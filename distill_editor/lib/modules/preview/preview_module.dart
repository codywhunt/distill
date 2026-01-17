import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../workspace/components/panel_container.dart';
import 'views/preview_canvas_view.dart';

/// App Preview module - Live preview of the full running app.
///
/// Left Panel: Widget tree (focused on current view)
/// Center: Infinite canvas with device frame (slimmed down builder)
/// Right: Properties + Agent

class PreviewLeftPanel extends StatelessWidget {
  const PreviewLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelContainer(
      header: const ModulePanelHeader(title: 'APP PREVIEW'),
      child: Column(
        children: [
          // Widget tree placeholder
          const Expanded(
            child: PanelPlaceholder(
              label: 'Widget Tree',
              icon: LucideIcons.layers200,
            ),
          ),

          // Navigation state placeholder
          Container(height: 1, color: context.colors.overlay.overlay10),
          const SizedBox(
            height: 100,
            child: PanelPlaceholder(
              label: 'Navigation',
              icon: LucideIcons.route200,
            ),
          ),
        ],
      ),
    );
  }
}

class PreviewCenterContent extends StatelessWidget {
  const PreviewCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    // PreviewModuleState is provided at the workspace level in router.dart
    return const PreviewCanvasView();
  }
}

class PreviewRightPanel extends StatelessWidget {
  const PreviewRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelContainer(
      borderSide: PanelBorderSide.left,
      header: const ModulePanelHeader(title: 'INSPECTOR'),
      child: Column(
        children: [
          // Properties placeholder
          Expanded(
            child: PanelPlaceholder(
              label: 'Widget Properties',
              icon: LucideIcons.slidersHorizontal200,
            ),
          ),

          // Agent placeholder
          Container(height: 1, color: context.colors.overlay.overlay10),
          const Expanded(
            child: PanelPlaceholder(
              label: 'Agent',
              icon: LucideIcons.sparkles200,
            ),
          ),
        ],
      ),
    );
  }
}
