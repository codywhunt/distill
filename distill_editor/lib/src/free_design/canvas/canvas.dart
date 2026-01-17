/// Canvas state management and UI widgets for the free design editor.
///
/// Provides:
/// - [DragTarget] - Selectable/draggable targets (frames and nodes)
/// - [DragSession] - Ephemeral drag state with snap support
/// - [CanvasState] - Main state orchestrator (replaces FreeDesignState)
/// - [FreeDesignCanvas] - Main canvas widget
library;

export 'drag_session.dart';
export 'drag_target.dart';
export 'drop_preview.dart';
export 'drop_preview_engine.dart';
export '../../../modules/canvas/canvas_state.dart'; // Re-export from new location
export 'widgets/widgets.dart';
