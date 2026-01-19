import 'package:distill_ds/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../src/free_design/commands/create_component_command.dart';
import '../../../src/free_design/models/component_def.dart';
import '../../../src/free_design/store/editor_document_store.dart';
import '../../../workspace/components/confirm_dialog.dart';
import '../canvas_state.dart';
import 'component_library_item.dart';

/// Collapsible section displaying all components in the document.
///
/// Features:
/// - Collapsible header with component count
/// - List of all components sorted by name
/// - Click to navigate to component frame
/// - "+" button to create component from selection
/// - "+" button on each component to instantiate
/// - Search/filter when more than 3 components
/// - Delete with confirmation (blocked if instances exist)
class ComponentLibraryPanel extends StatefulWidget {
  const ComponentLibraryPanel({super.key});

  @override
  State<ComponentLibraryPanel> createState() => _ComponentLibraryPanelState();
}

class _ComponentLibraryPanelState extends State<ComponentLibraryPanel> {
  bool _isExpanded = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = context.watch<CanvasState>();
    final allComponents = canvasState.document.components.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Filter by search (case-insensitive contains)
    final components = _searchQuery.isEmpty
        ? allComponents
        : allComponents
            .where(
              (c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: context.spacing.xxs),
        // Collapsible header
        _ComponentSectionHeader(
          componentCount: components.length,
          isExpanded: _isExpanded,
          onToggle: () => setState(() => _isExpanded = !_isExpanded),
          onAddComponent: _canCreateComponent(canvasState)
              ? () => _createFromSelection(context)
              : null,
        ),

        // Search field (when expanded and more than 3 components)
        if (_isExpanded && allComponents.length > 3) _buildSearchField(context),

        // Component list (when expanded)
        if (_isExpanded)
          components.isEmpty
              ? _buildEmptyState(context)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: context.spacing.xxs),
                    for (final component in components)
                      ComponentLibraryItem(
                        component: component,
                        onTap: () => _navigateToComponent(context, component),
                        onInsert: () => _insertInstance(context, component),
                        onDelete: () => _confirmDelete(context, component),
                      ),
                    SizedBox(height: context.spacing.xxs),
                  ],
                ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        'No components yet',
        style: context.typography.body.medium.copyWith(
          color: context.colors.foreground.muted,
        ),
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        height: 26,
        child: TextField(
          controller: _searchController,
          style: context.typography.body.medium.copyWith(
            color: context.colors.foreground.primary,
          ),
          decoration: InputDecoration(
            hintText: 'Search components...',
            hintStyle: context.typography.body.medium.copyWith(
              color: context.colors.foreground.weak,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius.sm),
              borderSide: BorderSide(color: context.colors.overlay.overlay10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius.sm),
              borderSide: BorderSide(color: context.colors.overlay.overlay10),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(context.radius.sm),
              borderSide: BorderSide(color: context.colors.accent.teal.primary),
            ),
            prefixIcon: Icon(
              LucideIcons.search200,
              size: 12,
              color: context.colors.foreground.muted,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 28,
              minHeight: 26,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  /// Check if we can create a component from the current selection.
  /// v1: exactly one selected node with patchTarget (editable node).
  bool _canCreateComponent(CanvasState state) {
    final editableNodes = state.selectedNodes.where((t) => t.patchTarget != null);
    return editableNodes.length == 1;
  }

  void _navigateToComponent(BuildContext context, ComponentDef component) {
    // Uses Phase 1.5's navigateToComponent (creates frame if needed)
    context.read<CanvasState>().navigateToComponent(component.id);
  }

  void _insertInstance(BuildContext context, ComponentDef component) {
    final canvasState = context.read<CanvasState>();

    // Find target: first selected frame, or frame containing selected node
    String? frameId;
    if (canvasState.selectedFrameIds.isNotEmpty) {
      frameId = canvasState.selectedFrameIds.first;
    } else if (canvasState.selectedNodes.isNotEmpty) {
      frameId = canvasState.selectedNodes.first.frameId;
    }

    if (frameId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a frame first')),
      );
      return;
    }

    final frame = canvasState.document.frames[frameId];
    if (frame == null) return;

    canvasState.store.instantiateComponent(
      componentId: component.id,
      parentId: frame.rootNodeId,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ComponentDef component,
  ) async {
    final store = context.read<CanvasState>().store;
    final instanceCount = store.countInstancesOfComponent(component.id);

    if (instanceCount > 0) {
      // Show blocked dialog (info-only)
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Cannot Delete '${component.name}'"),
          content: Text(
            'This component is used by $instanceCount instance(s). '
            'Delete the instances first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: "Delete '${component.name}'?",
      message: 'This will remove the component from your library.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed && context.mounted) {
      store.deleteComponent(component.id);
    }
  }

  void _createFromSelection(BuildContext context) {
    final canvasState = context.read<CanvasState>();
    final selectedDocIds = canvasState.selectedNodes
        .where((t) => t.patchTarget != null)
        .map((t) => t.patchTarget!)
        .toSet();

    try {
      final command = CreateComponentCommand(
        store: canvasState.store,
        selectedDocIds: selectedDocIds,
      );
      final componentId = command.execute();

      // Navigate to the new component
      canvasState.navigateToComponent(componentId);
    } on ArgumentError catch (e) {
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed to create component')),
      );
    }
  }
}

/// Collapsible section header for components.
class _ComponentSectionHeader extends StatelessWidget {
  const _ComponentSectionHeader({
    required this.componentCount,
    required this.isExpanded,
    required this.onToggle,
    required this.onAddComponent,
  });

  final int componentCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onAddComponent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Expand/collapse chevron
            Icon(
              isExpanded
                  ? LucideIcons.chevronDown200
                  : LucideIcons.chevronRight200,
              size: 12,
              color: context.colors.foreground.muted,
            ),
            const SizedBox(width: 4),
            // Title with count
            Text(
              'Components',
              style: context.typography.body.medium.copyWith(
                color: context.colors.foreground.muted,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($componentCount)',
              style: context.typography.body.medium.copyWith(
                color: context.colors.foreground.weak,
              ),
            ),
            const Spacer(),
            // Add button (enabled when selection allows creating component)
            GestureDetector(
              onTap: onAddComponent,
              child: Tooltip(
                message: onAddComponent != null
                    ? 'Create component from selection'
                    : 'Select a single node to create a component',
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    LucideIcons.plus200,
                    size: 14,
                    color: onAddComponent != null
                        ? context.colors.foreground.muted
                        : context.colors.foreground.weak,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
