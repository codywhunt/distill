import 'package:distill_canvas/infinite_canvas.dart';
import 'package:flutter/material.dart';

import '../../../src/free_design/canvas/widgets/free_design_canvas.dart';
import '../canvas_state.dart';

/// Demo view for testing FreeDesignCanvas with sample data.
///
/// Uses [CanvasState.demo()] to create a canvas with mock frames and nodes.
class FreeDesignDemo extends StatefulWidget {
  const FreeDesignDemo({super.key});

  @override
  State<FreeDesignDemo> createState() => _FreeDesignDemoState();
}

class _FreeDesignDemoState extends State<FreeDesignDemo> {
  late final CanvasState _state;
  late final InfiniteCanvasController _controller;

  @override
  void initState() {
    super.initState();
    _state = CanvasState.demo();
    _controller = InfiniteCanvasController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FreeDesignCanvas(state: _state, controller: _controller);
  }
}
