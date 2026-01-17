import 'package:flutter/material.dart';

import '../workspace/workspace_state.dart';
import '../workspace/components/module_error_boundary.dart';

// Module stubs
import 'canvas/canvas_module.dart';
import 'preview/preview_module.dart';
import 'code/code_module.dart';
import 'theme/theme_module.dart';
import 'backend/backend_module.dart';
import 'source_control/source_control_module.dart';
import 'settings/settings_module.dart';

/// Registry that maps modules to their panel builders.
///
/// This keeps the workspace shell decoupled from module implementations.
/// All content is wrapped in error boundaries to prevent module crashes
/// from affecting the entire workspace.
class ModuleRegistry {
  ModuleRegistry._();

  /// Build the left panel for a module (with error boundary).
  static Widget buildLeftPanel(ModuleType module) {
    return ModuleErrorBoundary(
      module: module,
      child: _buildLeftPanelContent(module),
    );
  }

  /// Build the center content for a module (with error boundary).
  static Widget buildCenterContent(ModuleType module) {
    return ModuleErrorBoundary(
      module: module,
      child: _buildCenterContentContent(module),
    );
  }

  /// Build the right panel for a module (with error boundary).
  static Widget buildRightPanel(ModuleType module) {
    return ModuleErrorBoundary(
      module: module,
      child: _buildRightPanelContent(module),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal builders (without error boundary)
  // ─────────────────────────────────────────────────────────────────────────

  static Widget _buildLeftPanelContent(ModuleType module) {
    return switch (module) {
      ModuleType.canvas => const CanvasLeftPanel(),
      ModuleType.preview => const PreviewLeftPanel(),
      ModuleType.code => const CodeLeftPanel(),
      ModuleType.theme => const ThemeLeftPanel(),
      ModuleType.backend => const BackendLeftPanel(),
      ModuleType.sourceControl => const SourceControlLeftPanel(),
      ModuleType.settings => const SettingsLeftPanel(),
    };
  }

  static Widget _buildCenterContentContent(ModuleType module) {
    return switch (module) {
      ModuleType.canvas => const CanvasCenterContent(),
      ModuleType.preview => const PreviewCenterContent(),
      ModuleType.code => const CodeCenterContent(),
      ModuleType.theme => const ThemeCenterContent(),
      ModuleType.backend => const BackendCenterContent(),
      ModuleType.sourceControl => const SourceControlCenterContent(),
      ModuleType.settings => const SettingsCenterContent(),
    };
  }

  static Widget _buildRightPanelContent(ModuleType module) {
    return switch (module) {
      ModuleType.canvas => const CanvasRightPanel(),
      ModuleType.preview => const PreviewRightPanel(),
      ModuleType.code => const CodeRightPanel(),
      ModuleType.theme => const ThemeRightPanel(),
      ModuleType.backend => const BackendRightPanel(),
      ModuleType.sourceControl => const SourceControlRightPanel(),
      ModuleType.settings => const SettingsRightPanel(),
    };
  }
}
