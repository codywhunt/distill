import 'package:flutter/foundation.dart';

/// Controller for managing popover visibility state.
///
/// Use this controller to programmatically show, hide, or toggle a popover.
///
/// Example:
/// ```dart
/// final controller = HoloPopoverController();
///
/// // In your widget
/// HoloPopover(
///   controller: controller,
///   child: Button(onPressed: controller.toggle),
///   popoverBuilder: (context) => MyPopoverContent(),
/// )
///
/// // Programmatic control
/// controller.show();
/// controller.hide();
/// controller.toggle();
/// ```
class HoloPopoverController extends ChangeNotifier {
  bool _isOpen = false;

  /// Whether the popover is currently open.
  bool get isOpen => _isOpen;

  /// Shows the popover.
  void show() {
    if (!_isOpen) {
      _isOpen = true;
      notifyListeners();
    }
  }

  /// Hides the popover.
  void hide() {
    if (_isOpen) {
      _isOpen = false;
      notifyListeners();
    }
  }

  /// Toggles the popover visibility.
  void toggle() => _isOpen ? hide() : show();
}
