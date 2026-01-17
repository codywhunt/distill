import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import '../../workspace/components/panel_container.dart';

/// Library module - Browse and manage project content.
///
/// Left Panel: Content listing (pages, components)
/// Center: Grid/storyboard view
/// Right: Details + Agent

class LibraryLeftPanel extends StatelessWidget {
  const LibraryLeftPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelContainer(
      header: ModulePanelHeader(title: 'LIBRARY'),
      child: PanelPlaceholder(
        label: 'Pages & Components',
        icon: LucideIcons.library200,
      ),
    );
  }
}

class LibraryCenterContent extends StatelessWidget {
  const LibraryCenterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelPlaceholder(label: 'Library', icon: LucideIcons.library200);
  }
}

class LibraryRightPanel extends StatelessWidget {
  const LibraryRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return PanelContainer(
      borderSide: PanelBorderSide.left,
      header: const ModulePanelHeader(title: 'DETAILS'),
      child: Column(
        children: [
          const Expanded(
            child: PanelPlaceholder(
              label: 'Document Details',
              icon: LucideIcons.info200,
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
