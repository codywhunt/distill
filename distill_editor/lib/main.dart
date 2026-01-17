import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

import 'routing/router.dart';

/// Entry point for Dreamflow 2.0 frontend.
///
/// This is a parallel implementation of the workspace shell.
/// See lib/workspace/shell_contract.md for the design contract.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
