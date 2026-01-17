import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workspace_state.dart';

/// Layout state for the workspace shell.
///
/// Manages:
/// - Panel visibility (per-module)
/// - Panel widths (global)
/// - Resize state
///
/// Persists to localStorage for cross-session continuity.
class WorkspaceLayoutState extends ChangeNotifier {
  WorkspaceLayoutState();

  // ─────────────────────────────────────────────────────────────────────────
  // Restoration State
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether the persisted state has been loaded.
  /// UI should wait for this before rendering to avoid flash of default state.
  bool _isRestored = false;
  bool get isRestored => _isRestored;

  // ─────────────────────────────────────────────────────────────────────────
  // Panel Widths (global, not per-module)
  // ─────────────────────────────────────────────────────────────────────────

  static const double minPanelWidth = 200.0;
  static const double maxPanelWidth = 500.0;
  static const double defaultLeftWidth = 280.0;
  static const double defaultRightWidth = 320.0;

  double _leftPanelWidth = defaultLeftWidth;
  double get leftPanelWidth => _leftPanelWidth;

  double _rightPanelWidth = defaultRightWidth;
  double get rightPanelWidth => _rightPanelWidth;

  /// Set left panel to an absolute width.
  /// Called by ResizablePanel at the END of a drag operation.
  void setLeftPanelWidth(double width) {
    _leftPanelWidth = width.clamp(minPanelWidth, maxPanelWidth);
    notifyListeners();
  }

  /// Set right panel to an absolute width.
  /// Called by ResizablePanel at the END of a drag operation.
  void setRightPanelWidth(double width) {
    _rightPanelWidth = width.clamp(minPanelWidth, maxPanelWidth);
    notifyListeners();
  }

  /// Persist left panel width to storage.
  /// Called by ResizablePanel at the END of a drag operation.
  Future<void> persistLeftPanelWidth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_prefsKey}_left_width', _leftPanelWidth);
  }

  /// Persist right panel width to storage.
  /// Called by ResizablePanel at the END of a drag operation.
  Future<void> persistRightPanelWidth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_prefsKey}_right_width', _rightPanelWidth);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Panel Visibility (per-module with defaults)
  // ─────────────────────────────────────────────────────────────────────────

  final Map<ModuleType, bool> _leftPanelVisible = {};
  final Map<ModuleType, bool> _rightPanelVisible = {};

  bool isLeftPanelVisible(ModuleType module) {
    return _leftPanelVisible[module] ?? _defaultLeftVisible(module);
  }

  bool isRightPanelVisible(ModuleType module) {
    return _rightPanelVisible[module] ?? _defaultRightVisible(module);
  }

  void toggleLeftPanel(ModuleType module) {
    final current = isLeftPanelVisible(module);
    _leftPanelVisible[module] = !current;
    _schedulePersist();
    notifyListeners();
  }

  void toggleRightPanel(ModuleType module) {
    final current = isRightPanelVisible(module);
    _rightPanelVisible[module] = !current;
    _schedulePersist();
    notifyListeners();
  }

  /// Whether the module has a left panel at all.
  bool hasLeftPanel(ModuleType module) {
    // All modules have left panels in current design
    return true;
  }

  /// Whether the module has a right panel at all.
  bool hasRightPanel(ModuleType module) {
    // All modules have agent in right panel
    return true;
  }

  bool _defaultLeftVisible(ModuleType module) => true;
  bool _defaultRightVisible(ModuleType module) => true;

  // ─────────────────────────────────────────────────────────────────────────
  // Transient State (NOT persisted)
  // ─────────────────────────────────────────────────────────────────────────

  bool _isResizing = false;
  bool get isResizing => _isResizing;

  void setResizing(bool value) {
    if (_isResizing == value) return;
    _isResizing = value;
    notifyListeners();
  }

  /// True during module switches - used to disable panel animations.
  /// Prevents jarring animations when switching between modules with
  /// different panel visibility states.
  bool _isContextSwitch = false;
  bool get isContextSwitch => _isContextSwitch;

  /// Mark the start of a context switch (disables animations).
  /// Call this BEFORE changing the current module.
  void beginContextSwitch() {
    _isContextSwitch = true;
    // Don't notify - we'll notify when the module actually changes
  }

  /// Mark the end of a context switch (re-enables animations).
  /// Called automatically after a frame to allow the UI to settle.
  void endContextSwitch() {
    if (!_isContextSwitch) return;
    _isContextSwitch = false;
    // Don't notify - avoids unnecessary rebuild
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Persistence (debounced to avoid chatty writes during drag)
  // ─────────────────────────────────────────────────────────────────────────

  static const _prefsKey = 'workspace_layout';
  Timer? _persistDebounce;

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 250), _persist);
  }

  /// Call this on resize end to ensure state is persisted immediately.
  Future<void> persistNow() async {
    _persistDebounce?.cancel();
    await _persist();
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final leftWidth = prefs.getDouble('${_prefsKey}_left_width');
    final rightWidth = prefs.getDouble('${_prefsKey}_right_width');

    if (leftWidth != null) _leftPanelWidth = leftWidth;
    if (rightWidth != null) _rightPanelWidth = rightWidth;

    // Restore per-module visibility
    for (final module in ModuleType.values) {
      final leftVisible = prefs.getBool('${_prefsKey}_${module.path}_left');
      final rightVisible = prefs.getBool('${_prefsKey}_${module.path}_right');
      if (leftVisible != null) _leftPanelVisible[module] = leftVisible;
      if (rightVisible != null) _rightPanelVisible[module] = rightVisible;
    }

    _isRestored = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_prefsKey}_left_width', _leftPanelWidth);
    await prefs.setDouble('${_prefsKey}_right_width', _rightPanelWidth);

    for (final module in ModuleType.values) {
      if (_leftPanelVisible.containsKey(module)) {
        await prefs.setBool(
          '${_prefsKey}_${module.path}_left',
          _leftPanelVisible[module]!,
        );
      }
      if (_rightPanelVisible.containsKey(module)) {
        await prefs.setBool(
          '${_prefsKey}_${module.path}_right',
          _rightPanelVisible[module]!,
        );
      }
    }
  }
}
