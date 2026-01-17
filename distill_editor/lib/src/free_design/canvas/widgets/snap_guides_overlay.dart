import 'package:distill_canvas/infinite_canvas.dart';
import 'package:distill_canvas/utilities.dart';
import 'package:flutter/material.dart';

import '../../../../modules/canvas/canvas_state.dart';

/// Renders smart guides during drag operations.
///
/// This widget wraps the distill_canvas SnapGuidesOverlay and pulls
/// the active guides from CanvasState.
class FreeDesignSnapGuidesOverlay extends StatelessWidget {
  const FreeDesignSnapGuidesOverlay({
    required this.state,
    required this.controller,
    super.key,
  });

  final CanvasState state;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    final guides = state.activeGuides;
    if (guides.isEmpty) {
      return const SizedBox.shrink();
    }

    return SnapGuidesOverlay(
      guides: guides,
      controller: controller,
      color: const Color(0xFFFF00FF), // Figma-style magenta
      strokeWidth: 1.0,
    );
  }
}
