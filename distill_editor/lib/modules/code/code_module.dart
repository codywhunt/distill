import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../workspace/components/panel_container.dart';

/// Code module - Full IDE experience.
///
/// Left Panel: File tree
/// Center: Tabs + editor
/// Right: Properties + Agent

class CodeLeftPanel extends StatelessWidget {
  const CodeLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      header: ModulePanelHeader(title: 'FILES'),
      child: PanelPlaceholder(
        label: 'File Tree',
        icon: LucideIcons.folderTree200,
      ),
    );
  }
}

class CodeCenterContent extends StatelessWidget {
  const CodeCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelPlaceholder(label: 'Code Editor', icon: LucideIcons.code200);
  }
}

class CodeRightPanel extends StatelessWidget {
  const CodeRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelContainer(
      borderSide: PanelBorderSide.left,
      header: const ModulePanelHeader(title: 'PROPERTIES'),
      child: Column(
        children: [
          Expanded(
            child: PanelPlaceholder(
              label: 'Symbol Properties',
              icon: LucideIcons.slidersHorizontal200,
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
