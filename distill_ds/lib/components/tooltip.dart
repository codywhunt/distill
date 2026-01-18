import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:distill_ds/design_system.dart';

enum TooltipStyle { ordinary, code }

/// Defines where the tooltip should appear relative to the target widget.
enum TooltipPosition {
  /// Tooltip appears below the target (default)
  below,

  /// Tooltip appears above the target
  above,

  /// Tooltip appears to the right of the target
  right,

  /// Tooltip appears to the left of the target
  left,

  /// Automatically determines the best position based on available space
  auto,
}

// How long to wait til the Tooltip appears.
const kDefaultWaitDuration = Duration(milliseconds: 500);

/// Hologram-wrapped tooltip used across the design system.
///
/// This behaves similarly to Flutter's [Tooltip] but:
/// - Uses Hologram typography, colors, and spacing tokens.
/// - Shows a rich body with optional shortcut and link metadata.
/// - Uses a custom hover-only implementation that always respects [waitDuration]
///   and avoids the "instant re-show" behavior when moving between tooltip
///   targets (see [_HologramTooltipCore]).
///
/// The [child] is the widget that is rendered in the tree and receives hover
/// events. The [message] is the text shown inside the tooltip overlay when the
/// user hovers over [child]. If [message] is null or empty, the tooltip is
/// disabled and [child] is returned as-is.
class HologramTooltip extends StatelessWidget {
  /// The text content displayed inside the tooltip overlay.
  final String? message;

  /// The widget that is rendered and hovered to trigger the tooltip.
  final Widget child;
  final String? shortcut;
  final String? linkText;
  final String? linkUrl;
  final VoidCallback? onLinkTap;
  final Duration? durationOverride;
  final TooltipStyle? tooltipStyle;
  final List<String>? boldPhrases;

  /// The position of the tooltip relative to the target widget.
  final TooltipPosition position;

  /// Override the default offset distance from the target.
  /// If null, uses sensible defaults based on position.
  final double? offsetOverride;

  const HologramTooltip({
    super.key,
    this.message,
    required this.child,
    this.shortcut,
    this.linkText,
    this.linkUrl,
    this.onLinkTap,
    this.durationOverride,
    this.tooltipStyle = TooltipStyle.ordinary,
    this.boldPhrases,
    this.position = TooltipPosition.below,
    this.offsetOverride = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return child;
    }

    // Use simple tooltip if no shortcut or link is provided
    final bool useSimpleTooltip =
        shortcut == null &&
        linkText == null &&
        onLinkTap == null &&
        linkUrl == null &&
        (boldPhrases == null || boldPhrases!.isEmpty);

    if (useSimpleTooltip) {
      return _HologramTooltipCore(
        message: message,
        waitDuration: durationOverride ?? kDefaultWaitDuration,
        position: position,
        offsetOverride: offsetOverride,
        tooltipContent: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            message!,
            style: tooltipStyle == TooltipStyle.code
                ? context.typography.mono.medium.copyWith(
                    color: context.colors.foreground.tooltip,
                  )
                : context.typography.body.medium.copyWith(
                    color: context.colors.foreground.tooltip,
                  ),
          ),
        ),
        decoration: BoxDecoration(
          color: context.colors.background.tooltip,
          borderRadius: BorderRadius.circular(context.radius.xs),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.sm,
          vertical: context.spacing.xxs,
        ),
        child: child,
      );
    }

    List<TextSpan> buildMessageSpans(String text) {
      final List<TextSpan> spans = [];
      if (boldPhrases == null || boldPhrases!.isEmpty) {
        spans.add(
          TextSpan(
            text: text,
            style: context.typography.body.medium.copyWith(
              color: context.colors.foreground.tooltip,
            ),
          ),
        );
        return spans;
      }

      int index = 0;
      while (index < text.length) {
        int closestStart = -1;
        String? matchedPhrase;
        for (final phrase in boldPhrases!) {
          final start = text.indexOf(phrase, index);
          if (start != -1 && (closestStart == -1 || start < closestStart)) {
            closestStart = start;
            matchedPhrase = phrase;
          }
        }
        if (closestStart == -1 || matchedPhrase == null) {
          // remainder
          spans.add(
            TextSpan(
              text: text.substring(index),
              style: context.typography.body.medium.copyWith(
                color: context.colors.foreground.tooltip,
              ),
            ),
          );
          break;
        }
        if (closestStart > index) {
          spans.add(
            TextSpan(
              text: text.substring(index, closestStart),
              style: context.typography.body.medium.copyWith(
                color: context.colors.foreground.tooltip,
              ),
            ),
          );
        }
        spans.add(
          TextSpan(
            text: matchedPhrase,
            style: context.typography.body.mediumStrong.copyWith(
              color: context.colors.foreground.tooltip,
            ),
          ),
        );
        index = closestStart + matchedPhrase.length;
      }
      return spans;
    }

    // Use rich tooltip if shortcut or link is provided
    return _HologramTooltipCore(
      message: message,
      waitDuration: durationOverride ?? kDefaultWaitDuration,
      position: position,
      offsetOverride: offsetOverride,
      tooltipContent: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        child: RichText(
          softWrap: true,
          text: TextSpan(
            children: [
              // Main message
              ...buildMessageSpans(message!),

              // Shortcut
              if (shortcut != null) ...[
                TextSpan(text: ' ', style: DefaultTextStyle.of(context).style),
                TextSpan(
                  text: shortcut!,
                  style: context.typography.body.mediumStrong.copyWith(
                    color: context.colors.foreground.tooltipMuted,
                  ),
                ),
              ],

              // Link
              if (linkText != null &&
                  (onLinkTap != null || linkUrl != null)) ...[
                TextSpan(text: ' ', style: DefaultTextStyle.of(context).style),
                TextSpan(
                  text: linkText!,
                  style: context.typography.body.mediumStrong.copyWith(
                    color: context.colors.foreground.tooltipLink,
                  ),
                  recognizer:
                      TapGestureRecognizer()
                        ..onTap = () async {
                          if (onLinkTap != null) {
                            onLinkTap!();
                          } else if (linkUrl != null) {
                            // TODO: Implement link navigation
                          }
                        },
                ),
              ],
            ],
          ),
        ),
      ),
      decoration: BoxDecoration(
        color: context.colors.background.tooltip,
        borderRadius: BorderRadius.circular(context.radius.xs),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.sm,
        vertical: context.spacing.xxs,
      ),
      child: child,
    );
  }
}

/// A custom tooltip implementation.
///
/// Based on the Material tooltip, with an additional fix for this issue:
/// https://github.com/flutter/flutter/issues/131549, where tooltips would
/// appear immediately when switching between widgets.
class _HologramTooltipCore extends StatefulWidget {
  final String? message;
  final Widget child;
  final Widget tooltipContent;
  final EdgeInsetsGeometry padding;
  final BoxDecoration decoration;
  final Duration waitDuration;
  final TooltipPosition position;
  final double? offsetOverride;

  const _HologramTooltipCore({
    required this.message,
    required this.child,
    required this.tooltipContent,
    required this.padding,
    required this.decoration,
    required this.waitDuration,
    this.position = TooltipPosition.below,
    this.offsetOverride,
  });

  @override
  State<_HologramTooltipCore> createState() => _HologramTooltipCoreState();
}

class _HologramTooltipCoreState extends State<_HologramTooltipCore> {
  static _HologramTooltipCoreState? _currentVisible;

  OverlayEntry? _overlayEntry;
  Timer? _showTimer;
  bool _isHovering = false;

  @override
  void dispose() {
    _cancelTimer();
    _hideTooltip();
    super.dispose();
  }

  void _cancelTimer() {
    _showTimer?.cancel();
    _showTimer = null;
  }

  void _handleEnter(PointerEnterEvent event) {
    _isHovering = true;
    _scheduleShow();
  }

  void _handleExit(PointerExitEvent event) {
    _isHovering = false;
    _cancelTimer();
    _hideTooltip();
  }

  void _scheduleShow() {
    _cancelTimer();
    final delay = widget.waitDuration;
    if (delay <= Duration.zero) {
      _showTooltip();
    } else {
      _showTimer = Timer(delay, () {
        if (!mounted || !_isHovering) return;
        _showTooltip();
      });
    }
  }

  void _showTooltip() {
    if (!mounted) return;

    // Always respect waitDuration, but ensure only one tooltip is visible.
    if (_currentVisible != null && _currentVisible != this) {
      _currentVisible!._hideTooltip();
    }

    _hideTooltip();

    final overlay = Overlay.of(context, debugRequiredFor: widget);

    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return;

    final overlayRenderBox = overlay.context.findRenderObject();
    if (overlayRenderBox is! RenderBox) return;

    final target = renderBox.localToGlobal(
      renderBox.size.center(Offset.zero),
      ancestor: overlayRenderBox,
    );
    final targetSize = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: CustomSingleChildLayout(
              delegate: _HologramTooltipPositionDelegate(
                target: target,
                targetSize: targetSize,
                position: widget.position,
                offsetOverride: widget.offsetOverride,
              ),
              child: Container(
                decoration: widget.decoration,
                padding: widget.padding,
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: widget.tooltipContent,
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _currentVisible = this;
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_currentVisible == this) {
      _currentVisible = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = widget.child;

    if (widget.message != null && widget.message!.isNotEmpty) {
      result = Semantics(tooltip: widget.message, child: result);
    }

    return MouseRegion(
      onEnter: _handleEnter,
      onExit: _handleExit,
      child: result,
    );
  }
}

class _HologramTooltipPositionDelegate extends SingleChildLayoutDelegate {
  final Offset target;
  final Size targetSize;
  final TooltipPosition position;
  final double? offsetOverride;

  _HologramTooltipPositionDelegate({
    required this.target,
    required this.targetSize,
    required this.position,
    this.offsetOverride,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Keep a small inset so the tooltip is never flush with the viewport edge.
    const edgePadding = 8.0;

    // Default offsets for each position
    const defaultVerticalOffset = 24.0;
    const defaultHorizontalOffset = 8.0;

    final maxX = (size.width - childSize.width - edgePadding).clamp(
      0.0,
      size.width,
    );
    final maxY = (size.height - childSize.height - edgePadding).clamp(
      0.0,
      size.height,
    );

    // Determine actual position (resolve 'auto' if needed)
    TooltipPosition actualPosition = position;
    if (position == TooltipPosition.auto) {
      actualPosition = _determineAutoPosition(size, childSize, edgePadding);
    }

    double x;
    double y;

    switch (actualPosition) {
      case TooltipPosition.below:
        final offset = offsetOverride ?? defaultVerticalOffset;
        x = (target.dx - childSize.width / 2).clamp(edgePadding, maxX);
        y = (target.dy + targetSize.height / 2 + offset).clamp(
          edgePadding,
          maxY,
        );
        break;

      case TooltipPosition.above:
        final offset = offsetOverride ?? defaultVerticalOffset;
        x = (target.dx - childSize.width / 2).clamp(edgePadding, maxX);
        y = (target.dy - targetSize.height / 2 - childSize.height - offset)
            .clamp(edgePadding, maxY);
        break;

      case TooltipPosition.right:
        final offset = offsetOverride ?? defaultHorizontalOffset;
        x = (target.dx + targetSize.width / 2 + offset).clamp(
          edgePadding,
          maxX,
        );
        y = (target.dy - childSize.height / 2).clamp(edgePadding, maxY);
        break;

      case TooltipPosition.left:
        final offset = offsetOverride ?? defaultHorizontalOffset;
        x = (target.dx - targetSize.width / 2 - childSize.width - offset).clamp(
          edgePadding,
          maxX,
        );
        y = (target.dy - childSize.height / 2).clamp(edgePadding, maxY);
        break;

      case TooltipPosition.auto:
        // Should never reach here as auto is resolved above
        x = (target.dx - childSize.width / 2).clamp(edgePadding, maxX);
        y = (target.dy + defaultVerticalOffset).clamp(edgePadding, maxY);
        break;
    }

    return Offset(x, y);
  }

  /// Determines the best position for the tooltip based on available space.
  TooltipPosition _determineAutoPosition(
    Size viewportSize,
    Size tooltipSize,
    double edgePadding,
  ) {
    // Calculate available space in each direction
    final spaceBelow = viewportSize.height - target.dy - targetSize.height / 2;
    final spaceAbove = target.dy - targetSize.height / 2;
    final spaceRight = viewportSize.width - target.dx - targetSize.width / 2;
    final spaceLeft = target.dx - targetSize.width / 2;

    // Prefer below, then right, then above, then left
    if (spaceBelow >= tooltipSize.height + edgePadding * 2) {
      return TooltipPosition.below;
    } else if (spaceRight >= tooltipSize.width + edgePadding * 2) {
      return TooltipPosition.right;
    } else if (spaceAbove >= tooltipSize.height + edgePadding * 2) {
      return TooltipPosition.above;
    } else if (spaceLeft >= tooltipSize.width + edgePadding * 2) {
      return TooltipPosition.left;
    }

    // Default to below if no good fit
    return TooltipPosition.below;
  }

  @override
  bool shouldRelayout(covariant _HologramTooltipPositionDelegate oldDelegate) {
    return target != oldDelegate.target ||
        targetSize != oldDelegate.targetSize ||
        position != oldDelegate.position ||
        offsetOverride != oldDelegate.offsetOverride;
  }
}
