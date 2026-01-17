import 'drop_preview.dart';

/// Debug configuration for drag and drop system.
///
/// Set to `true` during development to enable:
/// - Console logging of all intermediate values per spec Section 12
/// - Visual debug overlay showing parent bounds, child midpoints, insertion line
///
/// All debug code is guarded by this flag and should be tree-shaken when false.
const bool kDragDropDebug = false;

/// Throttle interval for debug logs in milliseconds.
///
/// Prevents console spam during rapid drag movements.
/// At 100ms, logs appear ~10 times per second maximum.
const int kDebugLogThrottleMs = 100;

/// Debug logging helper with throttling.
///
/// Provides centralized logging for the drag and drop system with:
/// - Automatic throttling to prevent console spam
/// - Formatted output for intermediate values
/// - Guard checks so no work is done when debug is disabled
class DragDebugLogger {
  DragDebugLogger._();

  static DateTime? _lastLogTime;

  /// Log a debug message with throttling.
  ///
  /// Messages are only logged if [kDragDropDebug] is true and
  /// at least [kDebugLogThrottleMs] have passed since the last log.
  static void log(String message) {
    if (!kDragDropDebug) return;

    final now = DateTime.now();
    if (_lastLogTime != null &&
        now.difference(_lastLogTime!).inMilliseconds < kDebugLogThrottleMs) {
      return;
    }
    _lastLogTime = now;

    // ignore: avoid_print
    print('[DragDrop] $message');
  }

  /// Log a message without throttling.
  ///
  /// Use sparingly - only for important one-time events like
  /// drag start/end, not for per-frame updates.
  static void logOnce(String message) {
    if (!kDragDropDebug) return;
    // ignore: avoid_print
    print('[DragDrop] $message');
  }

  /// Log all intermediate values from a [DropPreview] per spec Section 12.
  ///
  /// This provides a consolidated view of the drop preview state for debugging:
  /// - frameId
  /// - hoveredExpandedId (the initially hit container)
  /// - hoveredDocId
  /// - targetParentExpandedId (after climbing to auto-layout)
  /// - targetParentDocId
  /// - isAutoLayout
  /// - childrenCountFiltered
  /// - insertionIndex
  /// - intent
  /// - invalidReason
  ///
  /// Output is throttled to prevent console spam.
  static void logDropPreview(
    DropPreview preview, {
    String? hoveredExpandedId,
    String? hoveredDocId,
    bool? isAutoLayout,
  }) {
    if (!kDragDropDebug) return;

    final now = DateTime.now();
    if (_lastLogTime != null &&
        now.difference(_lastLogTime!).inMilliseconds < kDebugLogThrottleMs) {
      return;
    }
    _lastLogTime = now;

    final buffer =
        StringBuffer()
          ..writeln('--- Drop Preview ---')
          ..writeln('frameId: ${preview.frameId}')
          ..writeln('hoveredExpandedId: $hoveredExpandedId')
          ..writeln('hoveredDocId: $hoveredDocId')
          ..writeln('targetParentExpandedId: ${preview.targetParentExpandedId}')
          ..writeln('targetParentDocId: ${preview.targetParentDocId}')
          ..writeln('isAutoLayout: $isAutoLayout')
          ..writeln(
            'childrenCountFiltered: ${preview.targetChildrenExpandedIds.length}',
          )
          ..writeln('insertionIndex: ${preview.insertionIndex}')
          ..writeln('intent: ${preview.intent}')
          ..writeln('invalidReason: ${preview.invalidReason}')
          ..writeln('indicatorRect: ${preview.indicatorWorldRect}')
          ..writeln('reflowCount: ${preview.reflowOffsetsByExpandedId.length}')
          ..writeln('--------------------');

    // ignore: avoid_print
    print('[DragDrop] ${buffer.toString()}');
  }

  /// Reset throttle timer.
  ///
  /// Call this at drag start to ensure first log appears immediately.
  static void resetThrottle() {
    _lastLogTime = null;
  }
}
