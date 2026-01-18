import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

/// Which side of the panel should have a border.
enum PanelBorderSide {
  /// Border on the left side (use for right panels)
  left,

  /// Border on the right side (use for left panels)
  right,

  /// No border
  none,
}

/// Standard panel container with header and content.
///
/// Used for left and right panels across all modules.
/// Shell owns resizing/collapse; PanelContainer owns just visual framing.
class PanelContainer extends StatelessWidget {
  const PanelContainer({
    super.key,
    this.header,
    required this.child,
    this.borderSide = PanelBorderSide.right,
  });

  final Widget? header;
  final Widget child;
  final PanelBorderSide borderSide;

  @override
  Widget build(BuildContext context) {
    final border = switch (borderSide) {
      PanelBorderSide.left => Border(
        left: BorderSide(color: context.colors.overlay.overlay05, width: 1),
      ),
      PanelBorderSide.right => Border(
        right: BorderSide(color: context.colors.overlay.overlay05, width: 1),
      ),
      PanelBorderSide.none => const Border(),
    };

    return Container(
      decoration: BoxDecoration(
        color: context.colors.background.primary,
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (header != null) header!, Expanded(child: child)],
      ),
    );
  }
}

/// Which side the panel is on (affects toggle icon direction).
enum PanelSide { left, right }

/// Standard panel header with title and optional search/toggle actions.
/// Named ModulePanelHeader to avoid conflict with design system's PanelHeader.
///
/// On macOS with full-size content view, the left panel header automatically
/// accounts for the traffic light buttons (close, minimize, zoom).
class ModulePanelHeader extends StatefulWidget {
  const ModulePanelHeader({
    super.key,
    required this.title,
    this.onSearch,
    this.onToggle,
    this.panelSide = PanelSide.left,
  });

  /// The panel title (displayed in uppercase muted style).
  final String title;

  /// Called when search is tapped. If null, search button is hidden.
  final VoidCallback? onSearch;

  /// Called when toggle is tapped. If null, toggle button is hidden.
  final VoidCallback? onToggle;

  /// Which side the panel is on (affects toggle icon direction).
  final PanelSide panelSide;

  @override
  State<ModulePanelHeader> createState() => _ModulePanelHeaderState();
}

class _ModulePanelHeaderState extends State<ModulePanelHeader> {
  @override
  Widget build(BuildContext context) {
    // Toggle icon points toward the edge to indicate collapse direction
    final toggleIcon =
        widget.panelSide == PanelSide.left
            ? LucideIcons.panelLeft200
            : LucideIcons.panelRight200;

    // On macOS, left panel has a special layout with traffic lights
    final isLeftPanelOnMacOS =
        Platform.isMacOS && widget.panelSide == PanelSide.left;

    if (isLeftPanelOnMacOS) {
      return _buildMacOSLeftPanelHeader(context, toggleIcon);
    }

    return _buildStandardHeader(context, toggleIcon);
  }

  /// Builds the standard header layout (non-macOS or right panel).
  Widget _buildStandardHeader(BuildContext context, IconData toggleIcon) {
    return Container(
      height: 46,
      padding: EdgeInsets.only(
        left: context.spacing.md,
        right: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.overlay.overlay05, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            widget.title,
            style: context.typography.body.mediumStrong.copyWith(
              color: context.colors.foreground.primary,
            ),
          ),
          const Spacer(),
          if (widget.onSearch != null)
            HoloIconButton(
              icon: HoloIconData.icon(LucideIcons.search200),
              onPressed: widget.onSearch,
              size: 28,
              iconSize: 14,
            ),
          if (widget.onToggle != null)
            HoloIconButton(
              icon: HoloIconData.icon(toggleIcon),
              onPressed: widget.onToggle,
              size: 28,
              iconSize: 16,
            ),
        ],
      ),
    );
  }

  /// Builds macOS left panel header with spacing for traffic lights/toolbar.
  ///
  /// The toggle button is handled by [MacOSTrafficLightToggle] which is
  /// always visible, so this header just needs the title row with proper
  /// top spacing for the toolbar area.
  Widget _buildMacOSLeftPanelHeader(BuildContext context, IconData toggleIcon) {
    // Toolbar height on macOS (where traffic lights and toggle live)
    const toolbarHeight = 46.0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.colors.overlay.overlay05, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Spacer for toolbar area (traffic lights + toggle button)
          const SizedBox(height: toolbarHeight),
          // Title row
          Container(
            height: 46,
            padding: EdgeInsets.only(
              left: context.spacing.lg,
              right: context.spacing.xs,
            ),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: context.typography.body.mediumStrong.copyWith(
                    color: context.colors.foreground.muted,
                  ),
                ),
                const Spacer(),
                if (widget.onSearch != null)
                  HoloIconButton(
                    icon: HoloIconData.icon(LucideIcons.search200),
                    onPressed: widget.onSearch,
                    size: 28,
                    iconSize: 14,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Button to show a hidden panel, displayed at the edge of center content.
class HiddenPanelToggle extends StatelessWidget {
  const HiddenPanelToggle({
    super.key,
    required this.panelSide,
    required this.onTap,
    this.tooltip,
  });

  /// Which side the panel is on (determines icon and positioning).
  final PanelSide panelSide;

  /// Called when the button is tapped.
  final VoidCallback onTap;

  /// Optional tooltip text.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // Icon points outward to indicate expand direction
    final icon =
        panelSide == PanelSide.left
            ? HoloIconData.huge(HugeIconsStrokeRounded.sidebarLeft)
            : HoloIconData.huge(HugeIconsStrokeRounded.sidebarRight);

    return HoloIconButton(
      icon: icon,
      onPressed: onTap,
      size: 34,
      iconSize: 16,
      tooltip: tooltip,
      style: HoloButtonStyle.ghost(context),
    );
  }
}

/// Placeholder panel content for stubs.
class PanelPlaceholder extends StatelessWidget {
  const PanelPlaceholder({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24, color: context.colors.foreground.weak),
            SizedBox(height: context.spacing.sm),
          ],
          Text(
            label,
            style: context.typography.body.medium.copyWith(
              color: context.colors.foreground.muted,
            ),
          ),
        ],
      ),
    );
  }
}
