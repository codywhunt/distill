/// Hologram Design System v2
///
/// A modern, state-aware component library for Flutter.
///
/// ## Getting Started
///
/// Wrap your app with the design system theme:
///
/// ```dart
/// import 'package:distill_ds/design_system.dart';
///
/// MaterialApp(
///   theme: HoloTheme.light,
///   darkTheme: HoloTheme.dark,
///   themeMode: ThemeMode.system,
///   // ...
/// )
/// ```
///
/// ## Using Tokens
///
/// Access design tokens via context extensions:
///
/// ```dart
/// Container(
///   color: context.colors.background.primary,
///   padding: EdgeInsets.all(context.spacing.md),
///   child: Text(
///     'Hello',
///     style: context.typography.body.medium.copyWith(
///       color: context.colors.foreground.primary,
///     ),
///   ),
/// )
/// ```
///
/// ## Using Components
///
/// ```dart
/// HoloButton(
///   label: 'Save',
///   onPressed: () => save(),
/// )
///
/// HoloButton(
///   label: 'Delete',
///   style: HoloButtonStyle.destructive(context),
///   onPressed: () => delete(),
/// )
/// ```
///
/// ## State-Aware Styling
///
/// Use the `.states()` extension for state-aware colors:
///
/// ```dart
/// HoloButton(
///   label: 'Custom',
///   backgroundColor: context.colors.accent.green.primary.states(
///     hovered: context.colors.accent.green.primary.withOpacity(0.9),
///     pressed: context.colors.accent.green.primary.withOpacity(0.8),
///   ),
///   onPressed: () {},
/// )
/// ```
library;

// Foundation
export 'foundation/widget_states.dart';
export 'foundation/state_value.dart';
export 'foundation/tappable.dart';

// Tokens
export 'tokens/colors.dart';
export 'tokens/typography.dart';
export 'tokens/spacing.dart';
export 'tokens/radius.dart';
export 'tokens/shadows.dart';
export 'tokens/motion.dart';
export 'tokens/theme.dart';

// Styles
export 'styles/button_style.dart';

// Components
export 'components/icon.dart';
export 'components/button.dart';
export 'components/avatar.dart';
export 'components/popover/popover.dart';
export 'components/popover/popover_controller.dart';
export 'components/menu/menu.dart';
export 'components/select/select.dart';
export 'components/select/select_trigger.dart';
export 'components/tooltip.dart';
export 'components/segmented_control.dart';

// Re-export commonly used packages
export 'package:hugeicons/hugeicons.dart';
export 'package:hugeicons/styles/stroke_rounded.dart';
export 'package:hugeicons/styles/bulk_rounded.dart';
export 'package:lucide_icons_flutter/lucide_icons.dart';
export 'package:flutter_svg/flutter_svg.dart';
