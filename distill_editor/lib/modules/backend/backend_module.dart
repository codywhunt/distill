import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../workspace/components/panel_container.dart';

/// Backend module - Backend provider configuration.
///
/// Left Panel: Config sections (provider, auth, schema, etc.)
/// Center: Config editor
/// Right: Agent only

class BackendLeftPanel extends StatelessWidget {
  const BackendLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      header: ModulePanelHeader(title: 'BACKEND'),
      child: PanelPlaceholder(
        label: 'Configuration',
        icon: LucideIcons.server200,
      ),
    );
  }
}

class BackendCenterContent extends StatelessWidget {
  const BackendCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelPlaceholder(
      label: 'Backend Manager',
      icon: LucideIcons.server200,
    );
  }
}

class BackendRightPanel extends StatelessWidget {
  const BackendRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      borderSide: PanelBorderSide.left,
      header: ModulePanelHeader(title: 'AGENT'),
      child: PanelPlaceholder(label: 'Agent', icon: LucideIcons.sparkles200),
    );
  }
}
