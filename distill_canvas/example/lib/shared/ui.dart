import 'package:flutter/material.dart';
import 'theme.dart';

/// Header for each example showing title, description, and features.
class ExampleHeader extends StatelessWidget {
  const ExampleHeader({
    super.key,
    required this.title,
    required this.description,
    required this.features,
    this.actions,
  });

  final String title;
  final String description;
  final List<String> features;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          Container(
            width: 1,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: AppTheme.borderSubtle,
          ),
          Text(
            description,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(width: 10),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _FeatureTag(label: f),
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class _FeatureTag extends StatelessWidget {
  const _FeatureTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          fontFamily: AppTheme.fontMono,
          color: AppTheme.textMuted,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Toolbar button with icon.
class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: isActive ? AppTheme.surfaceHover : Colors.transparent,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(2),
        hoverColor: AppTheme.surfaceHover,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 14,
            color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Toolbar with horizontal layout and dividers.
class Toolbar extends StatelessWidget {
  const Toolbar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(children: children),
    );
  }
}

/// Vertical divider for toolbars.
class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: AppTheme.borderSubtle,
    );
  }
}

/// Zoom control buttons.
class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.zoom,
    required this.onZoomChanged,
    this.onFitPressed,
  });

  final double zoom;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback? onFitPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomPreset(
          label: '50%',
          zoom: 0.5,
          currentZoom: zoom,
          onTap: onZoomChanged,
        ),
        _ZoomPreset(
          label: '100%',
          zoom: 1.0,
          currentZoom: zoom,
          onTap: onZoomChanged,
        ),
        _ZoomPreset(
          label: '200%',
          zoom: 2.0,
          currentZoom: zoom,
          onTap: onZoomChanged,
        ),
        if (onFitPressed != null) ...[
          const SizedBox(width: 2),
          _ZoomPreset(
            label: 'fit',
            zoom: null,
            currentZoom: zoom,
            onTap: (_) => onFitPressed!(),
          ),
        ],
      ],
    );
  }
}

class _ZoomPreset extends StatelessWidget {
  const _ZoomPreset({
    required this.label,
    required this.zoom,
    required this.currentZoom,
    required this.onTap,
  });

  final String label;
  final double? zoom;
  final double currentZoom;
  final ValueChanged<double> onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = zoom != null && (currentZoom - zoom!).abs() < 0.01;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: isActive ? AppTheme.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: () => zoom != null ? onTap(zoom!) : onTap(currentZoom),
          borderRadius: BorderRadius.circular(2),
          hoverColor: AppTheme.surfaceHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontFamily: AppTheme.fontMono,
                fontWeight: FontWeight.w500,
                color: isActive ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status bar at bottom of canvas.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children:
            children
                .expand((w) => [w, const SizedBox(width: 12)])
                .take(children.length * 2 - 1)
                .toList(),
      ),
    );
  }
}

/// Status bar item.
class StatusItem extends StatelessWidget {
  const StatusItem({super.key, this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: AppTheme.textSubtle),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontFamily: AppTheme.fontMono,
            color: AppTheme.textSubtle,
          ),
        ),
      ],
    );
  }
}

/// Dropdown selector.
class DropdownSelector<T> extends StatelessWidget {
  const DropdownSelector({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemBuilder,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3),
        side: const BorderSide(color: AppTheme.border, width: 0.5),
      ),
      color: AppTheme.surface,
      itemBuilder:
          (context) =>
              items
                  .map(
                    (item) => PopupMenuItem(
                      value: item,
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                        child: IconTheme(
                          data: const IconThemeData(
                            size: 13,
                            color: AppTheme.textMuted,
                          ),
                          child: itemBuilder(item),
                        ),
                      ),
                    ),
                  )
                  .toList(),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultTextStyle(
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              child: IconTheme(
                data: const IconThemeData(size: 13, color: AppTheme.textMuted),
                child: itemBuilder(value),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.unfold_more, size: 12, color: AppTheme.textSubtle),
          ],
        ),
      ),
    );
  }
}
