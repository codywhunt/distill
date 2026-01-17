import 'package:flutter/material.dart';
import 'package:distill_ds/design_system.dart';

void main() {
  runApp(const DesignSystemExampleApp());
}

class DesignSystemExampleApp extends StatefulWidget {
  const DesignSystemExampleApp({super.key});

  @override
  State<DesignSystemExampleApp> createState() => _DesignSystemExampleAppState();
}

class _DesignSystemExampleAppState extends State<DesignSystemExampleApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Design System v2 Example',
      debugShowCheckedModeBanner: false,
      theme: HoloTheme.light,
      darkTheme: HoloTheme.dark,
      themeMode: _themeMode,
      home: ExamplePage(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class ExamplePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const ExamplePage({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  bool _isLoading = false;

  void _simulateLoading() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background.primary,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            SizedBox(height: context.spacing.xxl),
            _buildSection(
              context,
              title: 'Button Variants',
              child: _buildButtonVariants(context),
            ),
            SizedBox(height: context.spacing.xxl),
            _buildSection(
              context,
              title: 'Button States',
              child: _buildButtonStates(context),
            ),
            SizedBox(height: context.spacing.xxl),
            _buildSection(
              context,
              title: 'Icon Buttons',
              child: _buildIconButtons(context),
            ),
            SizedBox(height: context.spacing.xxl),
            _buildSection(
              context,
              title: 'Custom State Colors',
              child: _buildCustomButtons(context),
            ),
            SizedBox(height: context.spacing.xxl),
            _buildSection(
              context,
              title: 'Color Tokens',
              child: _buildColorTokens(context),
            ),
            SizedBox(height: context.spacing.xxl),
            _buildSection(
              context,
              title: 'Typography',
              child: _buildTypography(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hologram Design System v2',
                style: context.typography.headings.display.copyWith(
                  color: context.colors.foreground.primary,
                ),
              ),
              SizedBox(height: context.spacing.sm),
              Text(
                'A modern, state-aware component library',
                style: context.typography.body.large.copyWith(
                  color: context.colors.foreground.muted,
                ),
              ),
            ],
          ),
        ),
        HoloIconButton(
          icon: widget.isDarkMode ? LucideIcons.sun : LucideIcons.moon,
          onPressed: widget.onToggleTheme,
          tooltip:
              widget.isDarkMode
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.typography.headings.large.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.lg),
        child,
      ],
    );
  }

  Widget _buildButtonVariants(BuildContext context) {
    return Wrap(
      spacing: context.spacing.md,
      runSpacing: context.spacing.md,
      children: [
        HoloButton(label: 'Secondary (Default)', onPressed: () {}),
        HoloButton(
          label: 'Primary',
          style: HoloButtonStyle.primary(context),
          onPressed: () {},
        ),
        HoloButton(
          label: 'Destructive',
          style: HoloButtonStyle.destructive(context),
          onPressed: () {},
        ),
        HoloButton(
          label: 'Outline',
          style: HoloButtonStyle.outline(context),
          onPressed: () {},
        ),
        HoloButton(
          label: 'Ghost',
          style: HoloButtonStyle.ghost(context),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildButtonStates(BuildContext context) {
    return Wrap(
      spacing: context.spacing.md,
      runSpacing: context.spacing.md,
      children: [
        HoloButton(
          label: 'Enabled',
          style: HoloButtonStyle.primary(context),
          onPressed: () {},
        ),
        HoloButton(
          label: 'Disabled',
          style: HoloButtonStyle.primary(context),
          isDisabled: true,
          onPressed: () {},
        ),
        HoloButton(
          label: 'Loading',
          style: HoloButtonStyle.primary(context),
          isLoading: _isLoading,
          onPressed: _simulateLoading,
        ),
        HoloButton(
          label: 'With Icon',
          icon: LucideIcons.plus,
          style: HoloButtonStyle.primary(context),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildIconButtons(BuildContext context) {
    return Wrap(
      spacing: context.spacing.sm,
      runSpacing: context.spacing.sm,
      children: [
        HoloIconButton(
          icon: LucideIcons.plus,
          onPressed: () {},
          tooltip: 'Add',
        ),
        HoloIconButton(
          icon: LucideIcons.pencil,
          onPressed: () {},
          tooltip: 'Edit',
        ),
        HoloIconButton(
          icon: LucideIcons.trash2,
          style: HoloButtonStyle.ghost(context).copyWith(
            foregroundColor: context.colors.accent.red.primary.states(
              hovered: context.colors.accent.red.primary.withValues(alpha: 0.8),
            ),
          ),
          onPressed: () {},
          tooltip: 'Delete',
        ),
        HoloIconButton(
          icon: LucideIcons.settings,
          onPressed: () {},
          tooltip: 'Settings',
        ),
        HoloIconButton(
          icon: LucideIcons.x,
          isDisabled: true,
          onPressed: () {},
          tooltip: 'Disabled',
        ),
      ],
    );
  }

  Widget _buildCustomButtons(BuildContext context) {
    return Wrap(
      spacing: context.spacing.md,
      runSpacing: context.spacing.md,
      children: [
        HoloButton(
          label: 'Green Custom',
          icon: LucideIcons.check200,
          backgroundColor: context.colors.accent.green.primary,
          foregroundColor: Colors.white,
          onPressed: () {},
        ),
        HoloButton(
          label: 'Orange Custom',
          icon: LucideIcons.triangleAlert200,
          backgroundColor: context.colors.accent.orange.primary,
          foregroundColor: Colors.white,
          onPressed: () {},
        ),
        HoloButton(
          label: 'Pink Custom',
          icon: LucideIcons.heart200,
          backgroundColor: context.colors.accent.pink.primary,
          foregroundColor: Colors.white,
          onPressed: () {},
        ),
        HoloButton(
          label: 'Custom State Colors',
          backgroundColorStates: context.colors.foreground.primary.states(
            hovered: context.colors.accent.purple.primary,
            pressed: context.colors.accent.pink.primary.withValues(alpha: 0.8),
          ),
          foregroundColorStates: StateColor(
            base: context.colors.background.primary,
          ),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildColorTokens(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColorRow(context, 'Background', [
          ('primary', context.colors.background.primary),
          ('secondary', context.colors.background.secondary),
          ('alternate', context.colors.background.alternate),
        ]),
        SizedBox(height: context.spacing.md),
        _buildColorRow(context, 'Foreground', [
          ('primary', context.colors.foreground.primary),
          ('muted', context.colors.foreground.muted),
          ('weak', context.colors.foreground.weak),
          ('disabled', context.colors.foreground.disabled),
        ]),
        SizedBox(height: context.spacing.md),
        _buildColorRow(context, 'Accents', [
          ('purple', context.colors.accent.purple.primary),
          ('orange', context.colors.accent.orange.primary),
          ('green', context.colors.accent.green.primary),
          ('red', context.colors.accent.red.primary),
          ('pink', context.colors.accent.pink.primary),
        ]),
      ],
    );
  }

  Widget _buildColorRow(
    BuildContext context,
    String label,
    List<(String, Color)> colors,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: context.typography.body.mediumStrong.copyWith(
              color: context.colors.foreground.muted,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: context.spacing.sm,
            runSpacing: context.spacing.sm,
            children:
                colors.map((entry) {
                  final (name, color) = entry;
                  return Tooltip(
                    message: name,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(context.radius.sm),
                        border: Border.all(
                          color: context.colors.stroke,
                          width: 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTypography(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display Heading',
          style: context.typography.headings.display.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.md),
        Text(
          'Large Heading',
          style: context.typography.headings.large.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.md),
        Text(
          'Medium Heading',
          style: context.typography.headings.medium.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.md),
        Text(
          'Small Heading',
          style: context.typography.headings.small.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.lg),
        Text(
          'Body Large - The quick brown fox jumps over the lazy dog.',
          style: context.typography.body.large.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.sm),
        Text(
          'Body Medium - The quick brown fox jumps over the lazy dog.',
          style: context.typography.body.medium.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.sm),
        Text(
          'Body Small - The quick brown fox jumps over the lazy dog.',
          style: context.typography.body.small.copyWith(
            color: context.colors.foreground.primary,
          ),
        ),
        SizedBox(height: context.spacing.lg),
        Container(
          padding: EdgeInsets.all(context.spacing.md),
          decoration: BoxDecoration(
            color: context.colors.background.alternate,
            borderRadius: BorderRadius.circular(context.radius.md),
          ),
          child: Text(
            'const greeting = "Hello, World!";\nprint(greeting);',
            style: context.typography.mono.medium.copyWith(
              color: context.colors.foreground.primary,
            ),
          ),
        ),
      ],
    );
  }
}
