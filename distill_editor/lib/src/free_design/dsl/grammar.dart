/// DSL Grammar Version 1
///
/// A compact text format for UI designs that reduces token usage by ~75%
/// compared to JSON while maintaining full expressiveness.
///
/// ## Example
/// ```
/// dsl:1
/// frame Login - w 375 h 812
///   column#n_root - gap 24 pad 24 bg #FFFFFF w fill h fill
///     text "Welcome Back" - size 24 weight 700 color #000000
///     column - gap 16
///       text "Email" - size 14 weight 500 color #666666
///       container - h 48 pad 12 bg #F5F5F5 r 8
///         text "email@example.com" - size 16 color #000000
///     container - h 48 bg #007AFF r 8 align center,center
///       text "Sign In" - size 16 weight 600 color #FFFFFF
/// ```
library;

/// Grammar constants for DSL version 1.
class DslGrammar {
  /// Current DSL version.
  static const version = '1';

  /// Node types supported in DSL.
  static const nodeTypes = [
    // Containers
    'container',
    'row',
    'column',
    'col',
    // Leaf nodes
    'text',
    'image',
    'img',
    'icon',
    'spacer',
    // Component reference
    'use',
  ];

  /// Layout properties (shorthand → full name).
  static const layoutProps = {
    'w': 'width', // w 120 | w hug | w fill
    'h': 'height', // h 40 | h hug | h fill
    'gap': 'gap', // gap 16
    'pad': 'padding', // pad 24 | pad 12,24 | pad 8,16,8,16
    'align': 'alignment', // align start,center | align center,stretch
    'pos': 'position', // pos auto | pos abs x 100 y 200
  };

  /// Style properties (shorthand → full name).
  static const styleProps = {
    'bg': 'background', // bg #FFF | bg {token} | bg linear(90,#F00,#00F)
    'fg': 'foreground', // fg #000 | fg text_primary
    'r': 'radius', // r 8 | r 8,4,4,8
    'border': 'border', // border 1 #000 | border 2 primary
    'shadow': 'shadow', // shadow 0,4,8,0 #00000033
    'opacity': 'opacity', // opacity 0.5
  };

  /// Gradient types supported.
  static const gradientTypes = ['linear', 'radial'];

  /// Text-specific properties.
  static const textProps = {
    'size': 'fontSize',
    'weight': 'fontWeight',
    'color': 'color',
    'textAlign': 'textAlign',
    'family': 'fontFamily',
    'lh': 'lineHeight', // lh 1.5
    'ls': 'letterSpacing', // ls 0.5
    'decor': 'decoration', // decor underline | decor lineThrough
  };

  /// Icon-specific properties.
  static const iconProps = {
    'icon': 'icon',
    'iconSet': 'iconSet',
    'size': 'size',
    'color': 'color',
  };

  /// Image-specific properties.
  static const imageProps = {
    'src': 'src',
    'fit': 'fit',
    'alt': 'alt',
  };

  /// Container-specific properties.
  static const containerProps = {
    'clip': 'clipContent',
    'scroll': 'scrollDirection',
  };

  /// Special size values.
  static const sizeModifiers = ['hug', 'fill', 'auto'];

  /// Position modes.
  static const positionModes = ['auto', 'abs'];

  /// Layout directions.
  static const directions = ['row', 'column', 'col', 'horizontal', 'vertical'];

  /// Main axis alignment values.
  static const mainAlignValues = [
    'start',
    'center',
    'end',
    'spaceBetween',
    'spaceAround',
    'spaceEvenly',
  ];

  /// Cross axis alignment values.
  static const crossAlignValues = [
    'start',
    'center',
    'end',
    'stretch',
  ];

  /// Image fit values.
  static const imageFitValues = [
    'cover',
    'contain',
    'fill',
    'fitWidth',
    'fitHeight',
    'none',
    'scaleDown',
  ];

  /// All known property keys (for validation).
  static Set<String> get allPropertyKeys => {
        ...layoutProps.keys,
        ...styleProps.keys,
        ...textProps.keys,
        ...iconProps.keys,
        ...imageProps.keys,
        ...containerProps.keys,
        // Additional modifier keys
        'x',
        'y',
        'visible',
      };

  /// Check if a string is a valid node type.
  static bool isValidNodeType(String type) {
    return nodeTypes.contains(type.toLowerCase());
  }

  /// Check if a string is a valid size modifier.
  static bool isSizeModifier(String value) {
    return sizeModifiers.contains(value.toLowerCase());
  }

  /// Check if a string is a valid property key.
  static bool isPropertyKey(String key) {
    return allPropertyKeys.contains(key);
  }
}
