import 'package:flutter/foundation.dart';

import 'command.dart';
import 'command_registry.dart';
import '../workspace/workspace_state.dart';

/// State for the command palette.
///
/// Manages:
/// - Open/close state
/// - Search query
/// - Filtered results
/// - Selection index
class CommandPaletteState extends ChangeNotifier {
  CommandPaletteState({required this.workspaceState});

  final WorkspaceState workspaceState;

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  String _query = '';
  String get query => _query;

  List<Command> _filteredCommands = [];
  List<Command> get filteredCommands => _filteredCommands;

  int _selectedIndex = 0;
  int get selectedIndex => _selectedIndex;

  /// Open the command palette.
  void open() {
    _isOpen = true;
    _query = '';
    _hydrate();
    notifyListeners();
  }

  /// Close the command palette.
  void close() {
    _isOpen = false;
    _query = '';
    _filteredCommands = [];
    _selectedIndex = 0;
    notifyListeners();
  }

  /// Toggle the command palette.
  void toggle() {
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  /// Update the search query.
  void updateQuery(String newQuery) {
    _query = newQuery;
    if (_query.isEmpty) {
      _hydrate();
    } else {
      _filteredCommands = _fuzzySearch(_query);
    }
    _selectedIndex = 0;
    notifyListeners();
  }

  /// Move selection up.
  void selectPrevious() {
    if (_filteredCommands.isEmpty) return;
    _selectedIndex = (_selectedIndex - 1) % _filteredCommands.length;
    if (_selectedIndex < 0) _selectedIndex = _filteredCommands.length - 1;
    notifyListeners();
  }

  /// Move selection down.
  void selectNext() {
    if (_filteredCommands.isEmpty) return;
    _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
    notifyListeners();
  }

  /// Set selection to a specific index.
  void setSelectedIndex(int index) {
    if (index >= 0 && index < _filteredCommands.length) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  /// Get the currently selected command.
  Command? get selectedCommand {
    if (_filteredCommands.isEmpty) return null;
    if (_selectedIndex >= _filteredCommands.length) return null;
    return _filteredCommands[_selectedIndex];
  }

  /// Hydrate with commands for current module.
  void _hydrate() {
    final module = workspaceState.currentModule;
    _filteredCommands = CommandRegistry.instance.getCommandsForModule(module);

    // Sort by relevance (could add recency/frequency later)
    _filteredCommands.sort((a, b) {
      // Prioritize navigation commands when in global scope
      final aIsNav = a.id.startsWith('nav.');
      final bIsNav = b.id.startsWith('nav.');
      if (aIsNav && !bIsNav) return -1;
      if (!aIsNav && bIsNav) return 1;
      return a.label.compareTo(b.label);
    });
  }

  /// Fuzzy search commands.
  List<Command> _fuzzySearch(String query) {
    final module = workspaceState.currentModule;
    final allCommands = CommandRegistry.instance.getCommandsForModule(module);
    final queryLower = query.toLowerCase();

    final scored =
        allCommands.map((cmd) {
          final score = _calculateScore(cmd, queryLower);
          return (command: cmd, score: score);
        }).where((e) => e.score > 0).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.command).toList();
  }

  double _calculateScore(Command cmd, String query) {
    double score = 0;
    final labelLower = cmd.label.toLowerCase();

    // Exact prefix match on label (highest priority)
    if (labelLower.startsWith(query)) {
      score += 100;
    }
    // Contains in label
    else if (labelLower.contains(query)) {
      score += 50;
    }

    // Keyword matches
    for (final keyword in cmd.keywords) {
      if (keyword.toLowerCase().contains(query)) {
        score += 30;
      }
    }

    // Description match
    if (cmd.description?.toLowerCase().contains(query) == true) {
      score += 20;
    }

    return score;
  }
}
