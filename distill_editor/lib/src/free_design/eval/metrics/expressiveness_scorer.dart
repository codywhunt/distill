/// Expressiveness evaluation for DSL capabilities.
///
/// Measures which UI patterns can be expressed in the current DSL
/// and identifies gaps for improvement.
library;

import '../eval_models.dart';

/// Evaluates DSL expressiveness against a catalog of UI patterns.
class ExpressivenessScorer {
  const ExpressivenessScorer();

  /// Full catalog of UI patterns to evaluate against.
  static const List<UIPattern> patternCatalog = [
    // Layout Patterns - Core
    UIPattern(
      id: 'layout.column',
      name: 'Vertical Stack',
      category: 'Layout',
      description: 'Stack children vertically with gap',
      supported: true,
      dslExample: 'column - gap 16',
    ),
    UIPattern(
      id: 'layout.row',
      name: 'Horizontal Stack',
      category: 'Layout',
      description: 'Stack children horizontally with gap',
      supported: true,
      dslExample: 'row - gap 12',
    ),
    UIPattern(
      id: 'layout.stack',
      name: 'Absolute Stack',
      category: 'Layout',
      description: 'Stack children absolutely positioned',
      supported: true,
      dslExample: 'container\n  child - pos abs x 10 y 10',
    ),
    UIPattern(
      id: 'layout.padding',
      name: 'Padding',
      category: 'Layout',
      description: 'Add padding to a container',
      supported: true,
      dslExample: 'container - pad 16',
    ),
    UIPattern(
      id: 'layout.fill',
      name: 'Fill Parent',
      category: 'Layout',
      description: 'Expand to fill available space',
      supported: true,
      dslExample: 'container - w fill h fill',
    ),
    UIPattern(
      id: 'layout.fixed',
      name: 'Fixed Size',
      category: 'Layout',
      description: 'Explicit width/height',
      supported: true,
      dslExample: 'container - w 200 h 100',
    ),
    UIPattern(
      id: 'layout.hug',
      name: 'Hug Content',
      category: 'Layout',
      description: 'Size to content',
      supported: true,
      dslExample: 'container  // hug is default',
    ),
    UIPattern(
      id: 'layout.alignment',
      name: 'Alignment',
      category: 'Layout',
      description: 'Align children on main/cross axis',
      supported: true,
      dslExample: 'row - align center,stretch',
    ),
    UIPattern(
      id: 'layout.spacer',
      name: 'Flexible Spacer',
      category: 'Layout',
      description: 'Flexible space between items',
      supported: true,
      dslExample: 'spacer - flex 2',
    ),

    // Layout Patterns - Advanced
    UIPattern(
      id: 'layout.scroll',
      name: 'Scrollable',
      category: 'Layout',
      description: 'Scrollable container',
      supported: true,
      dslExample: 'column - scroll vertical',
    ),
    UIPattern(
      id: 'layout.clip',
      name: 'Clip Content',
      category: 'Layout',
      description: 'Clip overflow content',
      supported: true,
      dslExample: 'container - clip',
    ),
    UIPattern(
      id: 'layout.wrap',
      name: 'Wrap Layout',
      category: 'Layout',
      description: 'Wrap children to next line',
      supported: false,
      priority: PatternPriority.medium,
    ),
    UIPattern(
      id: 'layout.grid',
      name: 'Grid Layout',
      category: 'Layout',
      description: 'CSS-style grid layout',
      supported: false,
      priority: PatternPriority.medium,
    ),
    UIPattern(
      id: 'layout.responsive',
      name: 'Responsive Breakpoints',
      category: 'Layout',
      description: 'Different layouts at breakpoints',
      supported: false,
      priority: PatternPriority.high,
    ),

    // Style Patterns - Colors
    UIPattern(
      id: 'style.solidFill',
      name: 'Solid Background',
      category: 'Style',
      description: 'Solid color background',
      supported: true,
      dslExample: 'container - bg #FF5500',
    ),
    UIPattern(
      id: 'style.tokenColor',
      name: 'Token Color',
      category: 'Style',
      description: 'Design token color reference',
      supported: true,
      dslExample: 'container - bg {color.primary}',
    ),
    UIPattern(
      id: 'style.linearGradient',
      name: 'Linear Gradient',
      category: 'Style',
      description: 'Linear gradient background',
      supported: true,
      dslExample: 'container - bg linear(90,#FF0000,#0000FF)',
    ),
    UIPattern(
      id: 'style.radialGradient',
      name: 'Radial Gradient',
      category: 'Style',
      description: 'Radial gradient background',
      supported: true,
      dslExample: 'container - bg radial(#FF0000,#0000FF)',
    ),

    // Style Patterns - Effects
    UIPattern(
      id: 'style.borderRadius',
      name: 'Border Radius',
      category: 'Style',
      description: 'Rounded corners',
      supported: true,
      dslExample: 'container - r 8',
    ),
    UIPattern(
      id: 'style.perCornerRadius',
      name: 'Per-Corner Radius',
      category: 'Style',
      description: 'Different radius per corner',
      supported: true,
      dslExample: 'container - r 8,8,0,0',
    ),
    UIPattern(
      id: 'style.border',
      name: 'Border Stroke',
      category: 'Style',
      description: 'Border with width and color',
      supported: true,
      dslExample: 'container - border 1 #CCCCCC',
    ),
    UIPattern(
      id: 'style.shadow',
      name: 'Drop Shadow',
      category: 'Style',
      description: 'Box shadow effect',
      supported: true,
      dslExample: 'container - shadow 0,4,8,0 #00000033',
    ),
    UIPattern(
      id: 'style.opacity',
      name: 'Opacity',
      category: 'Style',
      description: 'Transparency',
      supported: true,
      dslExample: 'container - opacity 0.5',
    ),
    UIPattern(
      id: 'style.blur',
      name: 'Blur Effect',
      category: 'Style',
      description: 'Blur/backdrop blur',
      supported: false,
      priority: PatternPriority.medium,
    ),

    // Style Patterns - Transforms
    UIPattern(
      id: 'style.rotate',
      name: 'Rotation',
      category: 'Style',
      description: 'Rotate element',
      supported: false,
      priority: PatternPriority.medium,
    ),
    UIPattern(
      id: 'style.scale',
      name: 'Scale',
      category: 'Style',
      description: 'Scale element',
      supported: false,
      priority: PatternPriority.low,
    ),
    UIPattern(
      id: 'style.translate',
      name: 'Translate',
      category: 'Style',
      description: 'Offset element position',
      supported: false,
      priority: PatternPriority.low,
    ),

    // Text Patterns
    UIPattern(
      id: 'text.basic',
      name: 'Basic Text',
      category: 'Text',
      description: 'Simple text content',
      supported: true,
      dslExample: 'text "Hello World"',
    ),
    UIPattern(
      id: 'text.fontSize',
      name: 'Font Size',
      category: 'Text',
      description: 'Text size',
      supported: true,
      dslExample: 'text "Title" - size 24',
    ),
    UIPattern(
      id: 'text.fontWeight',
      name: 'Font Weight',
      category: 'Text',
      description: 'Text weight (bold, etc)',
      supported: true,
      dslExample: 'text "Bold" - weight 700',
    ),
    UIPattern(
      id: 'text.color',
      name: 'Text Color',
      category: 'Text',
      description: 'Text foreground color',
      supported: true,
      dslExample: 'text "Red" - color #FF0000',
    ),
    UIPattern(
      id: 'text.align',
      name: 'Text Alignment',
      category: 'Text',
      description: 'Text alignment',
      supported: true,
      dslExample: 'text "Centered" - textAlign center',
    ),
    UIPattern(
      id: 'text.family',
      name: 'Font Family',
      category: 'Text',
      description: 'Custom font family',
      supported: true,
      dslExample: 'text "Custom" - family "Inter"',
    ),
    UIPattern(
      id: 'text.richText',
      name: 'Rich Text Spans',
      category: 'Text',
      description: 'Mixed styles in one text',
      supported: false,
      priority: PatternPriority.high,
    ),
    UIPattern(
      id: 'text.lineHeight',
      name: 'Line Height',
      category: 'Text',
      description: 'Line height/spacing',
      supported: true,
      dslExample: 'text "Multi-line" - lh 1.5',
    ),
    UIPattern(
      id: 'text.letterSpacing',
      name: 'Letter Spacing',
      category: 'Text',
      description: 'Character spacing',
      supported: true,
      dslExample: 'text "Spaced" - ls 0.5',
    ),
    UIPattern(
      id: 'text.decoration',
      name: 'Text Decoration',
      category: 'Text',
      description: 'Underline, strikethrough',
      supported: true,
      dslExample: 'text "Link" - decor underline',
    ),

    // Image Patterns
    UIPattern(
      id: 'image.basic',
      name: 'Basic Image',
      category: 'Image',
      description: 'Display an image',
      supported: true,
      dslExample: 'img "https://example.com/img.png"',
    ),
    UIPattern(
      id: 'image.fit',
      name: 'Image Fit',
      category: 'Image',
      description: 'Image sizing mode',
      supported: true,
      dslExample: 'img "url" - fit contain',
    ),
    UIPattern(
      id: 'image.alt',
      name: 'Alt Text',
      category: 'Image',
      description: 'Accessibility alt text',
      supported: true,
      dslExample: 'img "url" - alt "Description"',
    ),

    // Icon Patterns
    UIPattern(
      id: 'icon.basic',
      name: 'Basic Icon',
      category: 'Icon',
      description: 'Display an icon',
      supported: true,
      dslExample: 'icon "home"',
    ),
    UIPattern(
      id: 'icon.size',
      name: 'Icon Size',
      category: 'Icon',
      description: 'Custom icon size',
      supported: true,
      dslExample: 'icon "home" - size 32',
    ),
    UIPattern(
      id: 'icon.color',
      name: 'Icon Color',
      category: 'Icon',
      description: 'Icon color',
      supported: true,
      dslExample: 'icon "home" - color #666666',
    ),
    UIPattern(
      id: 'icon.set',
      name: 'Icon Set',
      category: 'Icon',
      description: 'Different icon sets',
      supported: true,
      dslExample: 'icon "home" - iconSet lucide',
    ),

    // Component Patterns
    UIPattern(
      id: 'component.use',
      name: 'Component Instance',
      category: 'Component',
      description: 'Use a component',
      supported: true,
      dslExample: 'use "ButtonPrimary"',
    ),
    UIPattern(
      id: 'component.slot',
      name: 'Slot Content',
      category: 'Component',
      description: 'Slot placeholder',
      supported: true,
      dslExample: 'slot "content"',
    ),
    UIPattern(
      id: 'component.params',
      name: 'Component Parameters',
      category: 'Component',
      description: 'Parameter overrides',
      supported: false,
      priority: PatternPriority.critical,
    ),

    // Token Patterns
    UIPattern(
      id: 'token.color',
      name: 'Color Token',
      category: 'Token',
      description: 'Token reference for colors',
      supported: true,
      dslExample: 'bg {color.primary}',
    ),
    UIPattern(
      id: 'token.spacing',
      name: 'Spacing Token',
      category: 'Token',
      description: 'Token reference for spacing',
      supported: true,
      dslExample: 'gap {spacing.md}',
    ),
    UIPattern(
      id: 'token.radius',
      name: 'Radius Token',
      category: 'Token',
      description: 'Token reference for radius',
      supported: true,
      dslExample: 'r {radius.md}',
    ),
  ];

  /// Evaluate expressiveness and return a report.
  ExpressivenessReport evaluate() {
    final supported = patternCatalog.where((p) => p.supported).toList();
    final unsupported = patternCatalog.where((p) => !p.supported).toList();

    final gaps = unsupported
        .map((p) => UnsupportedPattern(
              patternId: p.id,
              name: p.name,
              category: p.category,
              description: p.description,
              priority: p.priority ?? PatternPriority.medium,
            ))
        .toList()
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return ExpressivenessReport(
      totalPatterns: patternCatalog.length,
      supportedPatterns: supported.length,
      coverage: patternCatalog.isNotEmpty
          ? supported.length / patternCatalog.length
          : 0,
      gaps: gaps,
    );
  }

  /// Get patterns by category.
  Map<String, List<UIPattern>> getPatternsByCategory() {
    final result = <String, List<UIPattern>>{};
    for (final pattern in patternCatalog) {
      result.putIfAbsent(pattern.category, () => []).add(pattern);
    }
    return result;
  }

  /// Get supported patterns only.
  List<UIPattern> getSupportedPatterns() =>
      patternCatalog.where((p) => p.supported).toList();

  /// Get unsupported patterns sorted by priority.
  List<UIPattern> getGaps() => patternCatalog
      .where((p) => !p.supported)
      .toList()
    ..sort((a, b) =>
        (a.priority?.index ?? 2).compareTo(b.priority?.index ?? 2));

  /// Check if a specific pattern is supported.
  bool isPatternSupported(String patternId) =>
      patternCatalog.any((p) => p.id == patternId && p.supported);
}

/// A UI pattern in the expressiveness catalog.
class UIPattern {
  final String id;
  final String name;
  final String category;
  final String description;
  final bool supported;
  final String? dslExample;
  final PatternPriority? priority;

  const UIPattern({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.supported,
    this.dslExample,
    this.priority,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'supported': supported,
        if (dslExample != null) 'dslExample': dslExample,
        if (priority != null) 'priority': priority!.name,
      };
}
