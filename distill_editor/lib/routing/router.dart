import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../workspace/workspace_state.dart';
import '../workspace/workspace_layout_state.dart';
import '../workspace/workspace_shell.dart';
import '../workspace/workspace_navigation.dart';
import '../commands/command_registry.dart';
import '../commands/command_palette_state.dart';
import '../modules/canvas/canvas_state.dart';
import '../modules/preview/preview_state.dart';

/// Router configuration for the workspace.
///
/// URL structure: /project/:projectId/:module?param=value
class WorkspaceRouter {
  WorkspaceRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/project/demo/canvas',
    debugLogDiagnostics: true,
    routes: [
      // Project workspace route
      GoRoute(
        path: '/project/:projectId/:module',
        pageBuilder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          final modulePath = state.pathParameters['module']!;
          final module = ModuleType.fromPath(modulePath) ?? ModuleType.canvas;
          final queryParams = state.uri.queryParameters;

          // Key by projectId only - this keeps the workspace mounted across
          // module switches, but resets correctly for different projects.
          return NoTransitionPage(
            key: ValueKey('workspace_$projectId'),
            child: _WorkspaceProvider(
              projectId: projectId,
              initialModule: module,
              queryParams: queryParams,
              routerInstance: router,
            ),
          );
        },
      ),

      // Redirect root to default project (for development)
      GoRoute(path: '/', redirect: (_, _) => '/project/demo/canvas'),

      // Redirect project root to canvas
      GoRoute(
        path: '/project/:projectId',
        redirect: (_, state) {
          final projectId = state.pathParameters['projectId']!;
          return '/project/$projectId/canvas';
        },
      ),
    ],
  );

  /// Navigate to a specific module.
  static void navigateToModule(
    BuildContext context,
    String projectId,
    ModuleType module, {
    Map<String, String>? params,
  }) {
    final queryString =
        params != null && params.isNotEmpty
            ? '?${Uri(queryParameters: params).query}'
            : '';
    context.go('/project/$projectId/${module.path}$queryString');
  }
}

/// Provider wrapper for the workspace.
///
/// Sets up all workspace-level providers.
class _WorkspaceProvider extends StatefulWidget {
  const _WorkspaceProvider({
    required this.projectId,
    required this.initialModule,
    required this.queryParams,
    required this.routerInstance,
  });

  final String projectId;
  final ModuleType initialModule;
  final Map<String, String> queryParams;
  final GoRouter routerInstance;

  @override
  State<_WorkspaceProvider> createState() => _WorkspaceProviderState();
}

class _WorkspaceProviderState extends State<_WorkspaceProvider> {
  late final WorkspaceState _workspaceState;
  late final WorkspaceLayoutState _layoutState;
  late final CommandPaletteState _commandPaletteState;
  late final WorkspaceNavigation _navigation;
  late final CanvasState _canvasState;
  late final PreviewModuleState _previewState;

  @override
  void initState() {
    super.initState();

    // Initialize command registry
    CommandRegistry.instance.initialize();

    // Create state objects
    _workspaceState = WorkspaceState(projectId: widget.projectId);
    _workspaceState.setCurrentModule(widget.initialModule);
    _workspaceState.updateRouteParams(widget.queryParams);

    _layoutState = WorkspaceLayoutState();
    _layoutState.restore();

    _commandPaletteState = CommandPaletteState(
      workspaceState: _workspaceState,
    );

    _navigation = WorkspaceNavigation(
      projectId: widget.projectId,
      router: widget.routerInstance,
    );

    // Module-specific state
    _canvasState = CanvasState.demo();

    _previewState = PreviewModuleState();
  }

  @override
  void didUpdateWidget(_WorkspaceProvider oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update module when route changes
    if (widget.initialModule != oldWidget.initialModule) {
      // Begin context switch to disable panel animations
      _layoutState.beginContextSwitch();

      _workspaceState.setCurrentModule(widget.initialModule);

      // End context switch after frame to re-enable animations
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _layoutState.endContextSwitch();
        }
      });
    }

    // Update query params when they change
    if (widget.queryParams != oldWidget.queryParams) {
      _workspaceState.updateRouteParams(widget.queryParams);
      // No route sync needed for CanvasState (no page management)
    }
  }

  @override
  void dispose() {
    _workspaceState.dispose();
    _layoutState.dispose();
    _commandPaletteState.dispose();
    _canvasState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _workspaceState),
        ChangeNotifierProvider.value(value: _layoutState),
        ChangeNotifierProvider.value(value: _commandPaletteState),
        ChangeNotifierProvider.value(value: _canvasState),
        ChangeNotifierProvider.value(value: _previewState),
        Provider.value(value: _navigation),
      ],
      child: const _WorkspaceShortcuts(
        child: Scaffold(
          body: WorkspaceShell(),
        ),
      ),
    );
  }
}

/// Keyboard shortcuts wrapper for the workspace.
///
/// Uses Focus with onKeyEvent for global shortcuts that work regardless of
/// which widget has focus. The key is setting canRequestFocus: false and
/// skipTraversal: true so this doesn't interfere with normal focus flow.
class _WorkspaceShortcuts extends StatefulWidget {
  const _WorkspaceShortcuts({required this.child});

  final Widget child;

  @override
  State<_WorkspaceShortcuts> createState() => _WorkspaceShortcutsState();
}

class _WorkspaceShortcutsState extends State<_WorkspaceShortcuts> {
  @override
  void initState() {
    super.initState();
    // Register a hardware keyboard handler for truly global shortcuts
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  /// Handle hardware keyboard events globally.
  /// Returns true if the event was handled.
  bool _handleHardwareKey(KeyEvent event) {
    // Only handle key down events
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final hasModifier = isMeta || isControl;

    // Command palette: Cmd/Ctrl+K (always works)
    if (key == LogicalKeyboardKey.keyK && hasModifier && !isAlt) {
      _openCommandPalette();
      return true;
    }

    // Command palette: / (only when not in text field)
    if (key == LogicalKeyboardKey.slash && !hasModifier && !isAlt) {
      if (!_isInTextField()) {
        _openCommandPalette();
        return true;
      }
    }

    // Escape: Close command palette if open
    if (key == LogicalKeyboardKey.escape) {
      final paletteState = context.read<CommandPaletteState>();
      if (paletteState.isOpen) {
        paletteState.close();
        return true;
      }
    }

    // Panel toggles (Option+[ and Option+])
    if (isAlt && !isMeta && !isControl) {
      if (key == LogicalKeyboardKey.bracketLeft) {
        final layout = context.read<WorkspaceLayoutState>();
        final module = context.read<WorkspaceState>().currentModule;
        layout.toggleLeftPanel(module);
        return true;
      }
      if (key == LogicalKeyboardKey.bracketRight) {
        final layout = context.read<WorkspaceLayoutState>();
        final module = context.read<WorkspaceState>().currentModule;
        layout.toggleRightPanel(module);
        return true;
      }
    }

    // Module shortcuts (Cmd+1-9)
    if (isMeta && !isAlt) {
      final digitKeys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9,
      ];
      final index = digitKeys.indexOf(key);
      if (index >= 0 && index < ModuleType.values.length) {
        final projectId = context.read<WorkspaceState>().projectId;
        final module = ModuleType.values[index];
        WorkspaceRouter.navigateToModule(context, projectId, module);
        return true;
      }
    }

    return false;
  }

  void _openCommandPalette() {
    context.read<CommandPaletteState>().open();
  }

  /// Check if focus is currently in a text field.
  bool _isInTextField() {
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode == null) return false;

    final focusContext = focusNode.context;
    if (focusContext == null) return false;

    // Check if the focused element or any ancestor is an EditableText
    bool foundEditable = false;
    focusContext.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        foundEditable = true;
        return false;
      }
      return true;
    });

    // Also check the focused element itself
    if (!foundEditable && focusContext.widget is EditableText) {
      foundEditable = true;
    }

    return foundEditable;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
