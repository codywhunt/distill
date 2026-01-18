import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';
import 'package:macos_window_utils/macos_window_utils.dart';

import 'routing/router.dart';

/// Entry point for Dreamflow 2.0 frontend.
///
/// This is a parallel implementation of the workspace shell.
/// See lib/workspace/shell_contract.md for the design contract.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize macOS window customization
  if (Platform.isMacOS) {
    await WindowManipulator.initialize(enableWindowDelegate: true);

    // Modern transparent title bar with full-size content
    WindowManipulator.makeTitlebarTransparent();
    WindowManipulator.enableFullSizeContentView();
    WindowManipulator.hideTitle();
    WindowManipulator.addToolbar();
    WindowManipulator.setToolbarStyle(
      toolbarStyle: NSWindowToolbarStyle.unified,
    );
  }

  // Precache critical assets to avoid flash on load
  await _precacheAssets();

  runApp(const DreamflowApp());
}

/// Precaches PNG and other assets that should be ready before first paint.
Future<void> _precacheAssets() async {
  // Logo PNGs will be precached by Flutter's image cache when first loaded
  // No explicit precaching needed for PNG assets
}

class DreamflowApp extends StatelessWidget {
  const DreamflowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dreamflow 2.0',
      debugShowCheckedModeBanner: false,
      theme: HoloTheme.light,
      darkTheme: HoloTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: WorkspaceRouter.router,
    );
  }
}
