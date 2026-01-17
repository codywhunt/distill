import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../workspace/components/panel_container.dart';

/// Settings module - Project configuration.
///
/// Left Panel: Settings categories
/// Center: Category form
/// Right: Agent only

class SettingsLeftPanel extends StatelessWidget {
  const SettingsLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      header: ModulePanelHeader(title: 'SETTINGS'),
      child: PanelPlaceholder(
        label: 'Categories',
        icon: LucideIcons.settings200,
      ),
    );
  }
}

class SettingsCenterContent extends StatelessWidget {
  const SettingsCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelPlaceholder(
      label: 'Project Settings',
      icon: LucideIcons.settings200,
    );
  }
}

class SettingsRightPanel extends StatelessWidget {
  const SettingsRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      borderSide: PanelBorderSide.left,
      header: ModulePanelHeader(title: 'AGENT'),
      child: PanelPlaceholder(label: 'Agent', icon: LucideIcons.sparkles200),
    );
  }
}
