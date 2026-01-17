import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:distill_ds/design_system.dart';
import 'package:provider/provider.dart';

import 'command.dart';
import '../modules/canvas/canvas_state.dart';
import '../src/free_design/ai/ai.dart';
import '../workspace/workspace_state.dart';
import '../workspace/workspace_layout_state.dart';

/// Central registry for all commands.
///
/// Commands are registered once at startup.
/// The command palette queries this registry to get available commands.
class CommandRegistry {
  CommandRegistry._();
  static final instance = CommandRegistry._();

  final Map<String, Command> _commands = {};
  bool _initialized = false;

  /// Register a single command.
  void register(Command command) {
    _commands[command.id] = command;
  }

  /// Register multiple commands.
  void registerAll(List<Command> commands) {
    for (final command in commands) {
      _commands[command.id] = command;
    }
  }

  /// Get all commands available in the given module.
  List<Command> getCommandsForModule(ModuleType module) {
    return _commands.values.where((cmd) => cmd.isAvailableIn(module)).toList();
  }

  /// Get all registered commands.
  List<Command> get allCommands => _commands.values.toList();

  /// Get a command by ID.
  Command? getCommand(String id) => _commands[id];

  /// Get all commands with shortcuts.
  List<Command> get commandsWithShortcuts =>
      _commands.values.where((cmd) => cmd.shortcut != null).toList();

  /// Initialize with global commands.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    registerAll(_globalCommands);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global Commands
// ─────────────────────────────────────────────────────────────────────────────

final _globalCommands = [
  // Module navigation
  Command(
    id: 'nav.canvas',
    label: 'Go to Canvas',
    icon: ModuleType.canvas.icon,
    keywords: ['switch', 'navigate', 'visual', 'editor', 'builder'],
    scopes: ['global'],
    shortcut: const CommandShortcut(key: LogicalKeyboardKey.digit1, meta: true),
    execute: (context) {
      final projectId = context.read<WorkspaceState>().projectId;
      context.go('/project/$projectId/canvas');
    },
  ),
  Command(
    id: 'nav.preview',
    label: 'Go to App Preview',
    icon: ModuleType.preview.icon,
    keywords: ['switch', 'navigate', 'run', 'app', 'live'],
    scopes: ['global'],
    shortcut: const CommandShortcut(key: LogicalKeyboardKey.digit2, meta: true),
    execute: (context) {
      final projectId = context.read<WorkspaceState>().projectId;
      context.go('/project/$projectId/preview');
    },
  ),
  Command(
    id: 'nav.code',
    label: 'Go to Code',
    icon: ModuleType.code.icon,
    keywords: ['switch', 'navigate', 'editor', 'files', 'ide'],
    scopes: ['global'],
    shortcut: const CommandShortcut(key: LogicalKeyboardKey.digit3, meta: true),
    execute: (context) {
      final projectId = context.read<WorkspaceState>().projectId;
      context.go('/project/$projectId/code');
    },
  ),
  Command(
    id: 'nav.theme',
    label: 'Go to Theme',
    icon: ModuleType.theme.icon,
    keywords: [
      'switch',
      'navigate',
      'colors',
      'typography',
      'design',
      'tokens',
    ],
    scopes: ['global'],
    shortcut: const CommandShortcut(key: LogicalKeyboardKey.digit4, meta: true),
    execute: (context) {
      final projectId = context.read<WorkspaceState>().projectId;
      context.go('/project/$projectId/theme');
    },
  ),
  Command(
    id: 'nav.backend',
    label: 'Go to Backend',
    icon: ModuleType.backend.icon,
    keywords: ['switch', 'navigate', 'firebase', 'supabase', 'database', 'api'],
    scopes: ['global'],
    shortcut: const CommandShortcut(key: LogicalKeyboardKey.digit5, meta: true),
    execute: (context) {
      final projectId = context.read<WorkspaceState>().projectId;
      context.go('/project/$projectId/backend');
    },
  ),
  Command(
    id: 'nav.source',
    label: 'Go to Source Control',
    icon: ModuleType.sourceControl.icon,
    keywords: [
      'switch',
      'navigate',
      'git',
      'github',
      'branch',
      'commit',
      'version',
    ],
    scopes: ['global'],
    shortcut: const CommandShortcut(key: LogicalKeyboardKey.digit6, meta: true),
    execute: (context) {
      final projectId = context.read<WorkspaceState>().projectId;
      context.go('/project/$projectId/source');
    },
  ),
  Command(
    id: 'nav.settings',
    label: 'Go to Settings',
    icon: ModuleType.settings.icon,
    keywords: ['switch', 'navigate', 'preferences', 'config', 'options'],
    scopes: ['global'],
    shortcut: const CommandShortcut(key: LogicalKeyboardKey.digit7, meta: true),
    execute: (context) {
      final projectId = context.read<WorkspaceState>().projectId;
      context.go('/project/$projectId/settings');
    },
  ),

  // Layout commands
  Command(
    id: 'layout.toggle_left',
    label: 'Toggle Left Panel',
    icon: LucideIcons.panelLeft,
    keywords: ['hide', 'show', 'panel', 'sidebar', 'collapse'],
    scopes: ['global'],
    shortcut: const CommandShortcut(
      key: LogicalKeyboardKey.bracketLeft,
      alt: true,
    ),
    execute: (context) {
      final layout = context.read<WorkspaceLayoutState>();
      final module = context.read<WorkspaceState>().currentModule;
      layout.toggleLeftPanel(module);
    },
  ),
  Command(
    id: 'layout.toggle_right',
    label: 'Toggle Right Panel',
    icon: LucideIcons.panelRight,
    keywords: ['hide', 'show', 'panel', 'sidebar', 'agent', 'collapse'],
    scopes: ['global'],
    shortcut: const CommandShortcut(
      key: LogicalKeyboardKey.bracketRight,
      alt: true,
    ),
    execute: (context) {
      final layout = context.read<WorkspaceLayoutState>();
      final module = context.read<WorkspaceState>().currentModule;
      layout.toggleRightPanel(module);
    },
  ),

  // AI commands
  Command(
    id: 'ai.generate_frame',
    label: 'Generate Frame with AI',
    icon: LucideIcons.sparkles,
    keywords: [
      'ai',
      'generate',
      'create',
      'design',
      'prompt',
      'llm',
      'claude',
      'gpt',
    ],
    scopes: ['canvas'],
    execute: (context) async {
      final aiService = createAiServiceFromEnv();
      if (aiService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI not configured. Run with --dart-define=ANTHROPIC_API_KEY=... '
              '(or OPENAI_API_KEY, GEMINI_API_KEY, GROQ_API_KEY, CEREBRAS_API_KEY)',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final canvasState = context.read<CanvasState>();
      await executeAiGenerateFrame(context, canvasState.store, aiService);
    },
  ),
];
