import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';
import 'package:provider/provider.dart';

import '../../commands/command_palette_state.dart';
import '../workspace_state.dart';
import '../workspace_navigation.dart';

/// Side navigation bar showing module icons.
///
/// Always visible, fixed width.
/// Clicking a module navigates to that module.
class SideNavigation extends StatelessWidget {
  const SideNavigation({super.key});

  static const double width = 42.0;

  /// Modules that appear at the bottom of the nav (above avatar).
  static const _bottomModules = {ModuleType.settings};

  @override
  Widget build(BuildContext context) {
    // Use select to only rebuild when currentModule changes
    final currentModule = context.select((WorkspaceState s) => s.currentModule);

    // Split modules into top and bottom groups
    final topModules = ModuleType.values
        .where((m) => !_bottomModules.contains(m))
        .toList();
    final bottomModules = ModuleType.values
        .where((m) => _bottomModules.contains(m))
        .toList();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: context.colors.background.primary,
        border: Border(
          right: BorderSide(color: context.colors.overlay.overlay10, width: 1),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: 16),

          // Dreamflow logo at top
          const _DreamflowLogo(),

          SizedBox(height: 10),

          // Search button to open command palette
          _SearchButton(
            onTap: () => context.read<CommandPaletteState>().open(),
          ),

          // Top module icons (all except settings)
          ...topModules.map(
            (module) => _ModuleIcon(
              module: module,
              isSelected: module == currentModule,
              onTap: () => _navigateToModule(context, module),
            ),
          ),

          const Spacer(),

          // Bottom module icons (settings)
          ...bottomModules.map(
            (module) => _ModuleIcon(
              module: module,
              isSelected: module == currentModule,
              onTap: () => _navigateToModule(context, module),
            ),
          ),

          SizedBox(height: context.spacing.xxs),

          // User avatar
          const _UserAvatar(),

          SizedBox(height: 12),
        ],
      ),
    );
  }

  void _navigateToModule(BuildContext context, ModuleType module) {
    // Use WorkspaceNavigation, not WorkspaceRouter directly
    context.read<WorkspaceNavigation>().navigateTo(module);
  }
}

class _ModuleIcon extends StatelessWidget {
  const _ModuleIcon({
    required this.module,
    required this.isSelected,
    required this.onTap,
  });

  final ModuleType module;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: _SideNavIconButton(
        icon: module.icon,
        isSelected: isSelected,
        onPressed: onTap,
      ),
    );
  }
}

/// Custom icon button for side navigation.
class _SideNavIconButton extends StatelessWidget {
  const _SideNavIconButton({
    required this.icon,
    required this.isSelected,
    required this.onPressed,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HoloTappable(
      cursor: SystemMouseCursors.basic,
      onTap: onPressed,
      pressScale: HoloTappable.defaultPressScale,
      builder: (context, states, _) {
        final colors = context.colors;

        // Determine colors based on selection and interaction state
        final backgroundColor = states.resolve(
          base: isSelected ? colors.overlay.overlay05 : Colors.transparent,
          hovered: isSelected
              ? colors.overlay.overlay05
              : colors.overlay.overlay03,
          pressed: isSelected
              ? colors.overlay.overlay05
              : colors.overlay.overlay10,
        );

        final iconColor = states.resolve(
          base: isSelected ? colors.foreground.primary : colors.foreground.weak,
          hovered: isSelected
              ? colors.foreground.primary
              : colors.foreground.muted,
          disabled: colors.foreground.disabled,
        );

        return AnimatedContainer(
          duration: context.motion.fast,
          curve: context.motion.standard,
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(context.radius.sm),
          ),
          child: Center(child: Icon(icon, size: 15.5, color: iconColor)),
        );
      },
    );
  }
}

/// Dreamflow logo displayed at the top of the side navigation.
class _DreamflowLogo extends StatelessWidget {
  const _DreamflowLogo();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/svgs/df_logo_small.svg',
      width: 20,
      colorFilter: ColorFilter.mode(
        context.colors.foreground.primary,
        BlendMode.srcIn,
      ),
    );
  }
}

/// Search button that opens the command palette.
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: _SideNavIconButton(
        icon: LucideIcons.search,
        isSelected: false,
        onPressed: onTap,
      ),
    );
  }
}

/// User avatar displayed at the bottom of the side navigation.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    // TODO: Get user info from auth state
    return HoloAvatar(
      name: 'User',
      size: HoloAvatarSize.sm,
      onTap: () {
        // TODO: Show account menu
      },
    );
  }
}
