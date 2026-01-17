import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../workspace/components/panel_container.dart';

/// Source Control module - Git operations and history.
///
/// Left Panel: Branches, current changes, actions
/// Center: Diff viewer, conflict resolution
/// Right: Agent only

class SourceControlLeftPanel extends StatelessWidget {
  const SourceControlLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      header: ModulePanelHeader(title: 'SOURCE CONTROL'),
      child: PanelPlaceholder(
        label: 'Branches & Changes',
        icon: LucideIcons.gitBranch200,
      ),
    );
  }
}

class SourceControlCenterContent extends StatelessWidget {
  const SourceControlCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelPlaceholder(
      label: 'Source Control',
      icon: LucideIcons.gitBranch200,
    );
  }
}

class SourceControlRightPanel extends StatelessWidget {
  const SourceControlRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      borderSide: PanelBorderSide.left,
      header: ModulePanelHeader(title: 'AGENT'),
      child: PanelPlaceholder(label: 'Agent', icon: LucideIcons.sparkles200),
    );
  }
}
