import 'package:flutter/widgets.dart';

/// State controller for the widget tree panel.
///
/// Manages expand/collapse state, scroll position, and GlobalKeys for
/// auto-scrolling. Uses expanded IDs throughout (which may include instance
/// namespacing like "inst::child").
class WidgetTreeState extends ChangeNotifier {
  /// Expanded nodes by their expanded ID.
  final Set<String> _expandedNodes = {};

  /// Scroll controller for auto-scroll functionality.
  final ScrollController scrollController = ScrollController();

  /// GlobalKeys for measuring tree item positions.
  ///
  /// These are cleaned up when the focus frame changes to avoid memory bloat.
  final Map<String, GlobalKey> _itemKeys = {};

  /// Check if a node is expanded.
  bool isExpanded(String expandedId) => _expandedNodes.contains(expandedId);

  /// Toggle the expanded state of a node.
  void toggleExpanded(String expandedId) {
    if (_expandedNodes.contains(expandedId)) {
      _expandedNodes.remove(expandedId);
    } else {
      _expandedNodes.add(expandedId);
    }
    notifyListeners();
  }

  /// Expand all ancestors in the given path.
  ///
  /// This is used to reveal a selected node by expanding its entire ancestor
  /// chain.
  void expandPath(List<String> ancestorExpandedIds) {
    _expandedNodes.addAll(ancestorExpandedIds);
    notifyListeners();
  }

  /// Scroll to make a node visible.
  ///
  /// Uses the GlobalKey associated with the node to find its render box and
  /// scroll it into view with a smooth animation.
  Future<void> scrollToNode(String expandedId) async {
    final key = _itemKeys[expandedId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: 0.5, // Center in viewport
      );
    }
  }

  /// Get or create a GlobalKey for a node.
  ///
  /// These keys are used to measure node positions for auto-scrolling.
  GlobalKey getOrCreateKey(String expandedId) {
    return _itemKeys.putIfAbsent(expandedId, () => GlobalKey());
  }

  /// Clear all GlobalKeys.
  ///
  /// This should be called when the focus frame changes to avoid accumulating
  /// keys for nodes that are no longer visible.
  void clearKeys() => _itemKeys.clear();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}
