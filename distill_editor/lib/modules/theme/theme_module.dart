import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../workspace/components/panel_container.dart';

/// Theme module - Design tokens and theming.
///
/// Left Panel: Token categories (colors, typography, etc.)
/// Center: Token editor
/// Right: Live preview + Agent

class ThemeLeftPanel extends StatelessWidget {
  const ThemeLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      header: ModulePanelHeader(title: 'THEME'),
      child: PanelPlaceholder(
        label: 'Token Categories',
        icon: LucideIcons.paintbrush200,
      ),
    );
  }
}

class ThemeCenterContent extends StatelessWidget {
  const ThemeCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelPlaceholder(
      label: 'Theme Manager',
      icon: LucideIcons.paintbrush200,
    );
  }
}

class ThemeRightPanel extends StatelessWidget {
  const ThemeRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelContainer(
      borderSide: PanelBorderSide.left,
      header: const ModulePanelHeader(title: 'PREVIEW'),
      child: Column(
        children: [
          const Expanded(
            child: PanelPlaceholder(
              label: 'Live Preview',
              icon: LucideIcons.eye200,
            ),
          ),
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
