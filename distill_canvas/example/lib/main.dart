import 'package:flutter/material.dart';

import 'shared/theme.dart';
import 'examples/app_preview/app_preview_example.dart';
import 'examples/free_design/free_design_example.dart';
import 'examples/storyboard/storyboard_example.dart';
import 'examples/action_flow/action_flow_example.dart';
import 'examples/layout_lab/layout_lab_example.dart';
import 'examples/kitchen_sink/editor.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Infinite Canvas Examples',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ExampleShell(),
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Example Shell with Sidebar
//─────────────────────────────────────────────────────────────────────────────

class ExampleShell extends StatefulWidget {
  const ExampleShell({super.key});

  @override
  State<ExampleShell> createState() => _ExampleShellState();
}

class _ExampleShellState extends State<ExampleShell> {
  int _selectedIndex = 0;

  static const _examples = <_ExampleInfo>[
    _ExampleInfo(
      title: 'App Preview',
      subtitle: 'single-object',
      widget: AppPreviewExample(),
    ),
    _ExampleInfo(
      title: 'Free Design',
      subtitle: 'composition',
      widget: FreeDesignExample(),
    ),
    _ExampleInfo(
      title: 'Storyboard',
      subtitle: 'page flow',
      widget: StoryboardExample(),
    ),
    _ExampleInfo(
      title: 'Action Flow',
      subtitle: 'node editor',
      widget: ActionFlowExample(),
    ),
    _ExampleInfo(
      title: 'Layout Lab',
      subtitle: 'algorithms',
      widget: LayoutLabExample(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          _Sidebar(
            examples: _examples,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
          ),

          // Divider
          Container(width: 0.5, color: AppTheme.borderSubtle),

          // Content
          Expanded(child: _examples[_selectedIndex].widget),
        ],
      ),
    );
  }
}

class _ExampleInfo {
  const _ExampleInfo({
    required this.title,
    required this.subtitle,
    required this.widget,
  });

  final String title;
  final String subtitle;
  final Widget widget;
}

//─────────────────────────────────────────────────────────────────────────────
// Sidebar
//─────────────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.examples,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_ExampleInfo> examples;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'distill_canvas',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: AppTheme.fontMono,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Text(
                  'v2',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: AppTheme.fontMono,
                    color: AppTheme.textSubtle,
                  ),
                ),
              ],
            ),
          ),

          Container(height: 0.5, color: AppTheme.borderSubtle),

          // Section label
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 14, 12, 6),
            child: Text(
              'EXAMPLES',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                fontFamily: AppTheme.fontMono,
                color: AppTheme.textSubtle,
              ),
            ),
          ),

          // Example list
          ...examples.asMap().entries.map((entry) {
            final index = entry.key;
            final example = entry.value;
            final isSelected = index == selectedIndex;

            return _SidebarItem(
              title: example.title,
              subtitle: example.subtitle,
              isSelected: isSelected,
              onTap: () => onSelect(index),
            );
          }),

          const Spacer(),

          Container(height: 0.5, color: AppTheme.borderSubtle),

          // Kitchen Sink link
          Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(2),
              child: InkWell(
                onTap: () => _showKitchenSink(context),
                borderRadius: BorderRadius.circular(2),
                hoverColor: AppTheme.surfaceHover,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 12,
                        color: AppTheme.textSubtle,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Kitchen Sink',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.open_in_new,
                        size: 10,
                        color: AppTheme.textSubtle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showKitchenSink(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: KitchenSinkExample()),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: isSelected ? AppTheme.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          hoverColor: AppTheme.surfaceHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Selection indicator
                Container(
                  width: 2,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppTheme.textSecondary
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w500 : FontWeight.w400,
                          color:
                              isSelected
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 9,
                          fontFamily: AppTheme.fontMono,
                          color: AppTheme.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
