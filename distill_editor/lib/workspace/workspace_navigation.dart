import 'package:go_router/go_router.dart';

import 'workspace_state.dart';

/// Cross-module navigation API.
///
/// Provides a decoupled way for modules to navigate to other modules
/// with specific context. This keeps modules from importing each other.
class WorkspaceNavigation {
  WorkspaceNavigation({
    required this.projectId,
    required GoRouter router,
  }) : _router = router;

  final String projectId;
  final GoRouter _router;

  /// Navigate to a module with optional query parameters.
  void navigateTo(ModuleType module, {Map<String, String>? params}) {
    final queryString =
        params != null && params.isNotEmpty
            ? '?${Uri(queryParameters: params).query}'
            : '';
    _router.go('/project/$projectId/${module.path}$queryString');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Convenience methods for common cross-module navigations
  // ─────────────────────────────────────────────────────────────────────────

  /// Open a document (component/page) in the Canvas module.
  void openInCanvas({required String documentId, String? focusWidget}) {
    navigateTo(
      ModuleType.canvas,
      params: {
        'doc': documentId,
        if (focusWidget != null) 'widget': focusWidget,
      },
    );
  }

  /// Open a specific page in canvas edit mode.
  void openCanvasPage(String pageId) {
    navigateTo(ModuleType.canvas, params: {'pageId': pageId});
  }

  /// Return to canvas browse mode (no page selected).
  void closeCanvasPage() {
    navigateTo(ModuleType.canvas);
  }

  /// Open a file in the Code editor.
  void openFile({required String path, int? line, int? column}) {
    navigateTo(
      ModuleType.code,
      params: {
        'file': path,
        if (line != null) 'line': line.toString(),
        if (column != null) 'col': column.toString(),
      },
    );
  }

  /// Open a specific theme token category.
  void openThemeCategory({required String category}) {
    navigateTo(ModuleType.theme, params: {'category': category});
  }

  /// Open source control to a specific tab.
  void openSourceControl({String? tab}) {
    navigateTo(
      ModuleType.sourceControl,
      params: {
        if (tab != null) 'tab': tab,
      },
    );
  }

  /// Open settings to a specific category.
  void openSettings({String? category}) {
    navigateTo(
      ModuleType.settings,
      params: {
        if (category != null) 'category': category,
      },
    );
  }
}
