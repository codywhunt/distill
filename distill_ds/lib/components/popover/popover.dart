import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'popover_controller.dart';

/// The anchor point alignment for positioning a popover.
///
/// Default configuration places the popover below the trigger,
/// aligned to the left edge.
class HoloPopoverAnchor {
  /// Where the popover attaches to the trigger widget.
  final Alignment triggerAnchor;

  /// Where the trigger attaches to the popover.
  final Alignment popoverAnchor;

  const HoloPopoverAnchor({
    required this.triggerAnchor,
    required this.popoverAnchor,
  });

  /// Popover appears below trigger, aligned left.
  static const bottomLeft = HoloPopoverAnchor(
    triggerAnchor: Alignment.bottomLeft,
    popoverAnchor: Alignment.topLeft,
  );

  /// Popover appears below trigger, aligned right.
  static const bottomRight = HoloPopoverAnchor(
    triggerAnchor: Alignment.bottomRight,
    popoverAnchor: Alignment.topRight,
  );

  /// Popover appears below trigger, centered.
  static const bottomCenter = HoloPopoverAnchor(
    triggerAnchor: Alignment.bottomCenter,
    popoverAnchor: Alignment.topCenter,
  );

  /// Popover appears above trigger, aligned left.
  static const topLeft = HoloPopoverAnchor(
    triggerAnchor: Alignment.topLeft,
    popoverAnchor: Alignment.bottomLeft,
  );

  /// Popover appears above trigger, aligned right.
  static const topRight = HoloPopoverAnchor(
    triggerAnchor: Alignment.topRight,
    popoverAnchor: Alignment.bottomRight,
  );

  /// Popover appears to the right of trigger.
  static const rightCenter = HoloPopoverAnchor(
    triggerAnchor: Alignment.centerRight,
    popoverAnchor: Alignment.centerLeft,
  );

  /// Popover appears to the left of trigger.
  static const leftCenter = HoloPopoverAnchor(
    triggerAnchor: Alignment.centerLeft,
    popoverAnchor: Alignment.centerRight,
  );
}

/// A popover component that displays floating content anchored to a trigger widget.
///
/// Uses Flutter's [OverlayPortal] for declarative overlay management and
/// [CompositedTransformTarget]/[CompositedTransformFollower] for positioning.
///
/// Features:
/// - Anchor-based positioning with configurable alignment
/// - Auto-flip when near viewport edge (optional)
/// - Close on tap outside (configurable)
/// - Close on Escape key (configurable)
/// - Focus management for accessibility
///
/// Example:
/// ```dart
/// final controller = HoloPopoverController();
///
/// HoloPopover(
///   controller: controller,
///   child: HoloButton(
///     label: 'Open Menu',
///     onPressed: controller.toggle,
///   ),
///   popoverBuilder: (context) => Container(
///     padding: EdgeInsets.all(16),
///     child: Text('Popover content'),
///   ),
/// )
/// ```
class HoloPopover extends StatefulWidget {
  /// The trigger widget that the popover is anchored to.
  final Widget child;

  /// Builder for the popover content.
  final WidgetBuilder popoverBuilder;

  /// Controller for managing popover visibility.
  ///
  /// If not provided, an internal controller is created.
  final HoloPopoverController? controller;

  /// The anchor configuration for positioning.
  ///
  /// Defaults to [HoloPopoverAnchor.bottomLeft].
  final HoloPopoverAnchor anchor;

  /// Additional offset from the anchor position.
  final Offset offset;

  /// Whether to close the popover when tapping outside.
  ///
  /// Defaults to `true`.
  final bool closeOnTapOutside;

  /// Whether to close the popover when pressing Escape.
  ///
  /// Defaults to `true`.
  final bool closeOnEscape;

  /// Whether to automatically flip the popover when it would overflow the viewport.
  ///
  /// Defaults to `true`.
  final bool autoFlip;

  /// Constraints for the popover size.
  final BoxConstraints? constraints;

  /// Called when the popover opens.
  final VoidCallback? onOpen;

  /// Called when the popover closes.
  final VoidCallback? onClose;

  const HoloPopover({
    super.key,
    required this.child,
    required this.popoverBuilder,
    this.controller,
    this.anchor = HoloPopoverAnchor.bottomLeft,
    this.offset = Offset.zero,
    this.closeOnTapOutside = true,
    this.closeOnEscape = true,
    this.autoFlip = true,
    this.constraints,
    this.onOpen,
    this.onClose,
  });

  @override
  State<HoloPopover> createState() => _HoloPopoverState();
}

class _HoloPopoverState extends State<HoloPopover> {
  final LayerLink _layerLink = LayerLink();
  late final OverlayPortalController _overlayController;

  HoloPopoverController? _internalController;
  HoloPopoverController get _controller =>
      widget.controller ?? _internalController!;

  final FocusNode _focusNode = FocusNode(debugLabel: 'HoloPopover');

  @override
  void initState() {
    super.initState();
    _overlayController = OverlayPortalController();

    if (widget.controller == null) {
      _internalController = HoloPopoverController();
    }

    _controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(HoloPopover oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      _controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _internalController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    if (_controller.isOpen) {
      _overlayController.show();
      widget.onOpen?.call();
    } else {
      _overlayController.hide();
      widget.onClose?.call();
    }
  }

  void _handleTapOutside() {
    if (widget.closeOnTapOutside && _controller.isOpen) {
      _controller.hide();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.closeOnEscape &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _controller.isOpen) {
      _controller.hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) => _PopoverOverlay(
            layerLink: _layerLink,
            anchor: widget.anchor,
            offset: widget.offset,
            autoFlip: widget.autoFlip,
            constraints: widget.constraints,
            onTapOutside: _handleTapOutside,
            child: widget.popoverBuilder(context),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Internal widget that renders the popover content in the overlay.
class _PopoverOverlay extends StatefulWidget {
  final LayerLink layerLink;
  final HoloPopoverAnchor anchor;
  final Offset offset;
  final bool autoFlip;
  final BoxConstraints? constraints;
  final VoidCallback onTapOutside;
  final Widget child;

  const _PopoverOverlay({
    required this.layerLink,
    required this.anchor,
    required this.offset,
    required this.autoFlip,
    required this.constraints,
    required this.onTapOutside,
    required this.child,
  });

  @override
  State<_PopoverOverlay> createState() => _PopoverOverlayState();
}

class _PopoverOverlayState extends State<_PopoverOverlay> {
  final GlobalKey _popoverKey = GlobalKey();
  HoloPopoverAnchor? _effectiveAnchor;

  @override
  void initState() {
    super.initState();
    // Schedule a check after the first frame to determine if we need to flip
    if (widget.autoFlip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndFlipIfNeeded();
      });
    }
  }

  void _checkAndFlipIfNeeded() {
    if (!mounted || !widget.autoFlip) return;

    final renderBox =
        _popoverKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final size = renderBox.size;
    final position = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    HoloPopoverAnchor? newAnchor;

    // Check if popover overflows bottom
    if (position.dy + size.height > screenSize.height &&
        widget.anchor == HoloPopoverAnchor.bottomLeft) {
      newAnchor = HoloPopoverAnchor.topLeft;
    } else if (position.dy + size.height > screenSize.height &&
        widget.anchor == HoloPopoverAnchor.bottomRight) {
      newAnchor = HoloPopoverAnchor.topRight;
    } else if (position.dy + size.height > screenSize.height &&
        widget.anchor == HoloPopoverAnchor.bottomCenter) {
      newAnchor = const HoloPopoverAnchor(
        triggerAnchor: Alignment.topCenter,
        popoverAnchor: Alignment.bottomCenter,
      );
    }

    // Check if popover overflows top
    if (position.dy < 0 && widget.anchor == HoloPopoverAnchor.topLeft) {
      newAnchor = HoloPopoverAnchor.bottomLeft;
    } else if (position.dy < 0 && widget.anchor == HoloPopoverAnchor.topRight) {
      newAnchor = HoloPopoverAnchor.bottomRight;
    }

    // Check horizontal overflow
    if (position.dx + size.width > screenSize.width &&
        widget.anchor == HoloPopoverAnchor.rightCenter) {
      newAnchor = HoloPopoverAnchor.leftCenter;
    } else if (position.dx < 0 &&
        widget.anchor == HoloPopoverAnchor.leftCenter) {
      newAnchor = HoloPopoverAnchor.rightCenter;
    }

    if (newAnchor != null && newAnchor != _effectiveAnchor) {
      setState(() {
        _effectiveAnchor = newAnchor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAnchor = _effectiveAnchor ?? widget.anchor;

    return Stack(
      children: [
        // Tap barrier to detect taps outside the popover
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onTapOutside,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // The popover itself
        CompositedTransformFollower(
          link: widget.layerLink,
          showWhenUnlinked: false,
          targetAnchor: effectiveAnchor.triggerAnchor,
          followerAnchor: effectiveAnchor.popoverAnchor,
          offset: widget.offset,
          child: TapRegion(
            onTapOutside: (_) => widget.onTapOutside(),
            child: Container(
              key: _popoverKey,
              constraints: widget.constraints,
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
