import 'package:distill_canvas/infinite_canvas.dart';
import 'package:distill_ds/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../src/free_design/ai/ai_service.dart';
import '../../src/free_design/canvas/widgets/free_design_canvas.dart';
import '../../src/free_design/canvas/widgets/prompt_box_overlay.dart';
import '../../src/free_design/properties/property_panel.dart';
import '../../workspace/components/panel_container.dart';
import '../../workspace/workspace_layout_state.dart';
import '../../workspace/workspace_state.dart';
import 'canvas_state.dart';
import 'widgets/frame_list_panel.dart';
import 'widgets/widget_tree_panel.dart';
import 'widgets/widget_tree_state.dart';

/// Canvas module - Free design visual editor.
///
/// Left Panel: Widget tree with layers
/// Center: InfiniteCanvas with frames
/// Right: Properties + Agent

class CanvasLeftPanel extends StatefulWidget {
  const CanvasLeftPanel({super.key});

  @override
  State<CanvasLeftPanel> createState() => _CanvasLeftPanelState();
}

class _CanvasLeftPanelState extends State<CanvasLeftPanel> {
  late final WidgetTreeState _treeState;

  @override
  void initState() {
    super.initState();
    _treeState = WidgetTreeState();
  }

  @override
  void dispose() {
    _treeState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.read<WorkspaceLayoutState>();

    return PanelContainer(
      header: ModulePanelHeader(
        title: 'Layers',
        panelSide: PanelSide.left,
        onToggle: () => layout.toggleLeftPanel(ModuleType.canvas),
      ),
      child: Column(
        spacing: context.spacing.xxs,
        children: [
          // Frames section (collapsible, above layers)
          const FrameListPanel(),
          // Divider
          Container(height: 1, color: context.colors.overlay.overlay10),
          // Layers section (takes remaining space)
          Expanded(child: WidgetTreePanel(treeState: _treeState)),
        ],
      ),
    );
  }
}

class CanvasCenterContent extends StatefulWidget {
  const CanvasCenterContent({super.key});

  @override
  State<CanvasCenterContent> createState() => _CanvasCenterContentState();
}

class _CanvasCenterContentState extends State<CanvasCenterContent> {
  late final InfiniteCanvasController _controller;

  /// Cached AI service (created once, not on every rebuild).
  FreeDesignAiService? _aiService;

  @override
  void initState() {
    super.initState();
    _controller = InfiniteCanvasController();
    _aiService = createAiServiceFromEnv();

    // Register controller with CanvasState for zoom menu access
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CanvasState>().setCanvasController(_controller);
      }
    });
  }

  @override
  void dispose() {
    context.read<CanvasState>().clearCanvasController();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = context.watch<CanvasState>();

    return Stack(
      children: [
        // Canvas layer
        FreeDesignCanvas(state: canvasState, controller: _controller),
        // Prompt box overlay (outside canvas, so pointer events work correctly)
        PromptBoxOverlay(
          state: canvasState,
          aiService: _aiService,
          onError: (message) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class CanvasRightPanel extends StatelessWidget {
  const CanvasRightPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = context.read<WorkspaceLayoutState>();
    final canvasState = context.watch<CanvasState>();

    return PanelContainer(
      borderSide: PanelBorderSide.left,
      header: ModulePanelHeader(
        title: 'Properties',
        panelSide: PanelSide.right,
        onToggle: () => layout.toggleRightPanel(ModuleType.canvas),
      ),
      child: FreeDesignPropertyPanel(
        state: canvasState,
        store: canvasState.store,
      ),

      // Agent placeholder
    );
  }
}
