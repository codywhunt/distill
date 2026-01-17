import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData;
import 'package:distill_ds/design_system.dart';

/// The available modules in the workspace.
enum ModuleType {
  canvas(path: 'canvas', label: 'Canvas', icon: LucideIcons.vectorSquare300),
  preview(path: 'preview', label: 'App Preview', icon: LucideIcons.play300),
  code(path: 'code', label: 'Code', icon: LucideIcons.codeXml300),
  theme(path: 'theme', label: 'Theme', icon: LucideIcons.palette300),
  backend(path: 'backend', label: 'Backend', icon: LucideIcons.database300),
  sourceControl(
    path: 'source',
    label: 'Source Control',
    icon: LucideIcons.gitBranch300,
  ),
  settings(path: 'settings', label: 'Settings', icon: LucideIcons.settings300);

  const ModuleType({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;

  static ModuleType? fromPath(String path) {
    for (final module in values) {
      if (module.path == path) return module;
    }
    return null;
  }
}

/// Callback signature for module lifecycle events.
typedef ModuleLifecycleCallback = void Function(ModuleType module);

/// Workspace-level state that lives above all modules.
///
/// Manages:
/// - Current project context
/// - Active module
/// - Route parameters
/// - Cross-module selection awareness (for agent context)
/// - Module lifecycle callbacks
class WorkspaceState extends ChangeNotifier {
  WorkspaceState({required this.projectId});

  final String projectId;

  ModuleType _currentModule = ModuleType.canvas;
  ModuleType get currentModule => _currentModule;

  // ─────────────────────────────────────────────────────────────────────────
  // Route Parameters
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, String> _routeParams = {};
  Map<String, String> get routeParams => Map.unmodifiable(_routeParams);

  /// Update route parameters (called by router when query params change).
  void updateRouteParams(Map<String, String> params) {
    if (mapEquals(_routeParams, params)) return;
    _routeParams = Map.of(params);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Module Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  final List<ModuleLifecycleCallback> _onModuleEnterCallbacks = [];
  final List<ModuleLifecycleCallback> _onModuleExitCallbacks = [];

  /// Register a callback to be called when entering a module.
  void addOnModuleEnter(ModuleLifecycleCallback callback) {
    _onModuleEnterCallbacks.add(callback);
  }

  /// Remove a module enter callback.
  void removeOnModuleEnter(ModuleLifecycleCallback callback) {
    _onModuleEnterCallbacks.remove(callback);
  }

  /// Register a callback to be called when exiting a module.
  void addOnModuleExit(ModuleLifecycleCallback callback) {
    _onModuleExitCallbacks.add(callback);
  }

  /// Remove a module exit callback.
  void removeOnModuleExit(ModuleLifecycleCallback callback) {
    _onModuleExitCallbacks.remove(callback);
  }

  /// Switch to a different module.
  /// This is typically called by the router, not directly.
  void setCurrentModule(ModuleType module) {
    if (_currentModule == module) return;

    final previousModule = _currentModule;

    // Fire exit callbacks for previous module
    for (final callback in _onModuleExitCallbacks) {
      callback(previousModule);
    }

    _currentModule = module;

    // Fire enter callbacks for new module
    for (final callback in _onModuleEnterCallbacks) {
      callback(module);
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Selection Context
  // ─────────────────────────────────────────────────────────────────────────

  /// The current selection context from the active module.
  /// Used by the agent to understand what the user is working on.
  SelectionContext? _selectionContext;
  SelectionContext? get selectionContext => _selectionContext;

  void updateSelectionContext(SelectionContext? context) {
    // Early return if unchanged to reduce unnecessary rebuilds
    if (_selectionContext == context) return;
    _selectionContext = context;
    notifyListeners();
  }
}

/// Base class for module selection context.
/// Each module provides its own implementation.
///
/// IMPORTANT: Implementations MUST override == and hashCode for proper
/// change detection in WorkspaceState.updateSelectionContext().
@immutable
abstract class SelectionContext {
  const SelectionContext();

  ModuleType get module;
  String? get documentId;
  String? get widgetId;
  Map<String, dynamic> toAgentContext();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// A simple immutable selection context implementation.
///
/// Use this for modules with straightforward selection needs,
/// or as a base for custom implementations.
@immutable
class SimpleSelectionContext extends SelectionContext {
  const SimpleSelectionContext({
    required this.module,
    this.documentId,
    this.widgetId,
    this.extra = const {},
  });

  @override
  final ModuleType module;

  @override
  final String? documentId;

  @override
  final String? widgetId;

  /// Additional context data for the agent.
  final Map<String, dynamic> extra;

  @override
  Map<String, dynamic> toAgentContext() {
    return {
      'module': module.path,
      if (documentId != null) 'documentId': documentId,
      if (widgetId != null) 'widgetId': widgetId,
      ...extra,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SimpleSelectionContext &&
        other.module == module &&
        other.documentId == documentId &&
        other.widgetId == widgetId &&
        mapEquals(other.extra, extra);
  }

  @override
  int get hashCode => Object.hash(module, documentId, widgetId, extra);
}
