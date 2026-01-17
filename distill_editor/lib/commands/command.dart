import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../workspace/workspace_state.dart';

/// Represents a keyboard shortcut for a command.
@immutable
class CommandShortcut {
  const CommandShortcut({
    required this.key,
    this.meta = false,
    this.control = false,
    this.alt = false,
    this.shift = false,
  });

  final LogicalKeyboardKey key;
  final bool meta;
  final bool control;
  final bool alt;
  final bool shift;

  /// Returns a human-readable string for the shortcut.
  /// Uses platform-appropriate symbols (⌘ for Mac, Ctrl for others).
  String toDisplayString({bool isMacOS = true}) {
    final parts = <String>[];

    if (isMacOS) {
      if (control) parts.add('⌃');
      if (alt) parts.add('⌥');
      if (shift) parts.add('⇧');
      if (meta) parts.add('⌘');
    } else {
      if (control) parts.add('Ctrl');
      if (alt) parts.add('Alt');
      if (shift) parts.add('Shift');
      if (meta) parts.add('Win');
    }

    // Get key label
    final keyLabel = _getKeyLabel(key);
    parts.add(keyLabel);

    return isMacOS ? parts.join() : parts.join('+');
  }

  static String _getKeyLabel(LogicalKeyboardKey key) {
    // Handle common special keys
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.enter) return '↵';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.tab) return 'Tab';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.backspace) return '⌫';
    if (key == LogicalKeyboardKey.delete) return '⌦';
    if (key == LogicalKeyboardKey.slash) return '/';
    if (key == LogicalKeyboardKey.bracketLeft) return '[';
    if (key == LogicalKeyboardKey.bracketRight) return ']';

    // Handle digit keys
    if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId) {
      return String.fromCharCode(
        '0'.codeUnitAt(0) + (key.keyId - LogicalKeyboardKey.digit0.keyId),
      );
    }

    // Handle letter keys
    if (key.keyId >= LogicalKeyboardKey.keyA.keyId &&
        key.keyId <= LogicalKeyboardKey.keyZ.keyId) {
      return String.fromCharCode(
        'A'.codeUnitAt(0) + (key.keyId - LogicalKeyboardKey.keyA.keyId),
      );
    }

    // Fallback to key label
    return key.keyLabel.toUpperCase();
  }

  /// Check if the given key event matches this shortcut.
  bool matches(KeyEvent event) {
    if (event.logicalKey != key) return false;

    final keyboard = HardwareKeyboard.instance;
    if (meta != keyboard.isMetaPressed) return false;
    if (control != keyboard.isControlPressed) return false;
    if (alt != keyboard.isAltPressed) return false;
    if (shift != keyboard.isShiftPressed) return false;

    return true;
  }
}

/// A command that can be executed from the command palette.
@immutable
class Command {
  const Command({
    required this.id,
    required this.label,
    this.description,
    this.icon,
    this.keywords = const [],
    this.scopes = const ['global'],
    required this.execute,
    this.isEnabled,
    this.shortcut,
  });

  /// Unique identifier for the command.
  final String id;

  /// Display label shown in the palette.
  final String label;

  /// Optional description shown below the label.
  final String? description;

  /// Optional icon shown before the label.
  final IconData? icon;

  /// Keywords for fuzzy search (in addition to label).
  final List<String> keywords;

  /// Scopes where this command is available.
  /// - 'global': Available everywhere
  /// - 'canvas', 'library', etc.: Only in that module
  final List<String> scopes;

  /// The action to execute when the command is selected.
  final FutureOr<void> Function(BuildContext context) execute;

  /// Optional predicate to check if command is currently enabled.
  /// If null, command is always enabled.
  final bool Function(BuildContext context)? isEnabled;

  /// Optional keyboard shortcut for this command.
  final CommandShortcut? shortcut;

  /// Check if command is available in the given module.
  bool isAvailableIn(ModuleType module) {
    return scopes.contains('global') || scopes.contains(module.path);
  }
}
