import 'dart:async';
import 'package:flutter/material.dart';

/// Mixin that provides debounce functionality for widgets with frequent updates.
///
/// This mixin extracts the common pattern of debouncing callbacks to avoid
/// excessive updates (e.g., during text input or drag operations).
///
/// The mixin automatically cancels any pending debounce timer on dispose,
/// preventing memory leaks and callbacks after widget destruction.
///
/// Usage:
/// ```dart
/// class _MyInputState extends State<MyInput> with DebounceMixin {
///   void _onTextChanged(String value) {
///     debounce(const Duration(milliseconds: 300), () {
///       widget.onChanged?.call(value);
///     });
///   }
///
///   void _onSubmitted(String value) {
///     cancelDebounce(); // Cancel any pending debounce
///     widget.onSubmitted?.call(value);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return TextField(
///       onChanged: _onTextChanged,
///       onSubmitted: _onSubmitted,
///     );
///   }
/// }
/// ```
mixin DebounceMixin<T extends StatefulWidget> on State<T> {
  Timer? _debounceTimer;

  /// Schedules a callback to run after [duration] elapses.
  ///
  /// If called again before the duration elapses, the previous timer is
  /// cancelled and a new one is started. This ensures only the last call
  /// within the duration window actually executes.
  void debounce(Duration duration, VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, callback);
  }

  /// Cancels any pending debounced callback.
  ///
  /// Call this when you need to execute immediately (e.g., on submit)
  /// or when the widget is being disposed.
  void cancelDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Whether a debounce timer is currently active.
  bool get isDebouncing => _debounceTimer?.isActive ?? false;

  @override
  void dispose() {
    cancelDebounce();
    super.dispose();
  }
}
