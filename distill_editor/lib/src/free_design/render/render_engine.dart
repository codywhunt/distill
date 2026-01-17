import 'package:flutter/material.dart';

import '../models/node_layout.dart' hide MainAxisAlignment, CrossAxisAlignment;
import '../utils/lucide_icons.dart';
import '../utils/material_icons.dart';
import 'render_document.dart';

/// Converts a [RenderDocument] to Flutter widgets.
///
/// The render engine takes a fully-compiled RenderDocument (with all tokens
/// resolved) and produces a Flutter widget tree that can be rendered.
///
/// ## Widget Mapping
///
/// - `box` → Container with decoration, Stack for absolute children
/// - `row` → Row with gap via SizedBox
/// - `column` → Column with gap via SizedBox
/// - `text` → Text with TextStyle
/// - `image` → Image.network or Image.asset
/// - `icon` → Icon widget
/// - `spacer` → Spacer or SizedBox
///
/// ## Bounds Tracking
///
/// Each node is wrapped with a [_BoundsTracker] widget that reports its
/// rendered bounds via [onBoundsChanged]. This enables accurate hit testing
/// for nodes positioned by Flutter's layout system (auto-layout).
class RenderEngine {
  /// Create a render engine with optional bounds tracking.
  ///
  /// If [onBoundsChanged] is provided, node bounds will be reported after layout.
  /// The [frameRootKey] identifies the frame's root widget for computing
  /// frame-local coordinates.
  /// The [reflowOffsets] apply temporary position shifts during drag operations.
  const RenderEngine({
    this.onBoundsChanged,
    this.frameRootKey,
    this.reflowOffsets = const {},
  });

  /// Callback invoked when a node's bounds change after layout.
  ///
  /// The rect is in frame-local coordinates (relative to the frame's origin).
  final void Function(String nodeId, Rect bounds)? onBoundsChanged;

  /// Key identifying the frame's root widget.
  ///
  /// Used by [_BoundsTracker] to compute frame-local coordinates via
  /// `localToGlobal(ancestor: frameRoot)`.
  final GlobalKey? frameRootKey;

  /// Temporary position offsets for reflow animation during drag.
  ///
  /// Maps node ID → offset. Applied additively to node positions.
  final Map<String, Offset> reflowOffsets;

  /// Build a widget tree from a render document.
  Widget build(RenderDocument doc) {
    if (doc.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use document's identity hash as generation marker
    // When doc changes (recompiled), this forces remeasurement
    return _buildNode(doc.rootId, doc, doc.hashCode);
  }

  /// Build a widget for a single node.
  ///
  /// [docGeneration] is the hashCode of the RenderDocument, used to detect
  /// when the document has been recompiled (forcing remeasurement).
  Widget _buildNode(String nodeId, RenderDocument doc, int docGeneration) {
    final node = doc.nodes[nodeId];
    if (node == null) {
      return const SizedBox.shrink();
    }

    // Check visibility
    final visible = node.propOr<bool>('visible', true);
    if (!visible) {
      return const SizedBox.shrink();
    }

    // Build based on type
    Widget widget = switch (node.type) {
      RenderNodeType.box => _buildBox(node, doc, docGeneration),
      RenderNodeType.row => _buildRow(node, doc, docGeneration),
      RenderNodeType.column => _buildColumn(node, doc, docGeneration),
      RenderNodeType.text => _buildText(node),
      RenderNodeType.image => _buildImage(node),
      RenderNodeType.icon => _buildIcon(node),
      RenderNodeType.spacer => _buildSpacer(node),
    };

    // Apply opacity if not 1.0
    final opacity = node.propOr<double>('opacity', 1.0);
    if (opacity < 1.0) {
      widget = Opacity(opacity: opacity, child: widget);
    }

    // Wrap with bounds tracker if callback provided
    if (onBoundsChanged != null && frameRootKey != null) {
      // Compute hash of props + childIds to detect changes
      final propsHash = Object.hash(
        Object.hashAll(
          node.props.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        Object.hashAll(node.childIds),
      );

      widget = _BoundsTracker(
        nodeId: nodeId,
        frameRootKey: frameRootKey!,
        onBoundsChanged: onBoundsChanged!,
        compiledBounds: node.compiledBounds,
        propsHash: propsHash,
        docGeneration: docGeneration,
        child: widget,
      );
    }

    return widget;
  }

  /// Build a box container widget.
  Widget _buildBox(RenderNode node, RenderDocument doc, int docGeneration) {
    final children = _buildChildren(node.childIds, doc, docGeneration);

    // Determine if we need a Stack for absolute positioning
    final hasAbsoluteChildren = children.any((entry) {
      final childNode = doc.nodes[entry.key];
      return childNode?.propOr<String>('positionMode', 'auto') == 'absolute';
    });

    Widget child;
    if (children.isEmpty) {
      child = const SizedBox.shrink();
    } else if (hasAbsoluteChildren) {
      // Use Stack for absolute positioning
      child = Stack(
        children:
            children.map((entry) {
              final childNode = doc.nodes[entry.key];
              final positionMode =
                  childNode?.propOr<String>('positionMode', 'auto') ?? 'auto';

              if (positionMode == 'absolute') {
                final x = childNode?.propOr<double>('x', 0.0) ?? 0.0;
                final y = childNode?.propOr<double>('y', 0.0) ?? 0.0;

                // Note: reflow offset is applied in _applySizing Step 4 (single place)
                return Positioned(
                  left: x,
                  top: y,
                  child: entry.value,
                );
              }
              return entry.value;
            }).toList(),
      );
    } else if (children.length == 1) {
      child = children.first.value;
    } else {
      // Default to Column for multiple non-absolute children
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: children.map((e) => e.value).toList(),
      );
    }

    // Wrap in scroll view if scrollable
    final scrollDirection = node.propOr<String?>('scrollDirection', null);
    if (scrollDirection != null) {
      child = SingleChildScrollView(
        scrollDirection:
            scrollDirection == 'horizontal' ? Axis.horizontal : Axis.vertical,
        physics: const ClampingScrollPhysics(),
        child: child,
      );
    }

    return _applySizing(node, child, doc);
  }

  /// Build a row widget.
  Widget _buildRow(RenderNode node, RenderDocument doc, int docGeneration) {
    final children = _buildChildren(node.childIds, doc, docGeneration);
    final gap = node.propOr<double>('gap', 0.0);
    final mainAlign = _parseMainAxisAlignment(
      node.propOr<String>('mainAxisAlignment', 'start'),
    );
    final crossAlign = _parseCrossAxisAlignment(
      node.propOr<String>('crossAxisAlignment', 'start'),
    );

    // Build children WITHOUT gaps first, applying Fill sizing
    final builtChildren = <Widget>[];
    bool anyChildHasMainAxisFill = false;

    for (final entry in children) {
      final childNode = doc.nodes[entry.key];
      if (childNode == null) continue;

      final child = entry.value;

      // Note: reflow offset is applied in _applySizing Step 4 (single place)

      // Apply child Fill sizing for auto-layout
      final (sizedChild, hasMainAxisFill) = _applyChildFillSizing(
        childNode,
        child,
        LayoutDirection.horizontal,
        crossAlign == CrossAxisAlignment.stretch,
        doc,
      );

      builtChildren.add(sizedChild);
      if (hasMainAxisFill) anyChildHasMainAxisFill = true;
    }

    // Insert gaps BETWEEN children (not wrapping Expanded)
    final rowChildren = <Widget>[];
    for (var i = 0; i < builtChildren.length; i++) {
      rowChildren.add(builtChildren[i]);
      if (i < builtChildren.length - 1 && gap > 0) {
        rowChildren.add(SizedBox(width: gap));
      }
    }

    Widget row = Row(
      mainAxisAlignment: mainAlign,
      crossAxisAlignment: crossAlign,
      // MainAxisSize.max when any child has main-axis Fill
      mainAxisSize:
          anyChildHasMainAxisFill ? MainAxisSize.max : MainAxisSize.min,
      children: rowChildren,
    );

    // Wrap in scroll view if scrollable (horizontal for row)
    final scrollDirection = node.propOr<String?>('scrollDirection', null);
    if (scrollDirection == 'horizontal') {
      row = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: row,
      );
    }

    return _applySizing(node, row, doc);
  }

  /// Build a column widget.
  Widget _buildColumn(RenderNode node, RenderDocument doc, int docGeneration) {
    final children = _buildChildren(node.childIds, doc, docGeneration);
    final gap = node.propOr<double>('gap', 0.0);
    final mainAlign = _parseMainAxisAlignment(
      node.propOr<String>('mainAxisAlignment', 'start'),
    );
    final crossAlign = _parseCrossAxisAlignment(
      node.propOr<String>('crossAxisAlignment', 'start'),
    );

    // Build children WITHOUT gaps first, applying Fill sizing
    final builtChildren = <Widget>[];
    bool anyChildHasMainAxisFill = false;

    for (final entry in children) {
      final childNode = doc.nodes[entry.key];
      if (childNode == null) continue;

      final child = entry.value;

      // Note: reflow offset is applied in _applySizing Step 4 (single place)

      // Apply child Fill sizing for auto-layout
      final (sizedChild, hasMainAxisFill) = _applyChildFillSizing(
        childNode,
        child,
        LayoutDirection.vertical,
        crossAlign == CrossAxisAlignment.stretch,
        doc,
      );

      builtChildren.add(sizedChild);
      if (hasMainAxisFill) anyChildHasMainAxisFill = true;
    }

    // Insert gaps BETWEEN children (not wrapping Expanded)
    final colChildren = <Widget>[];
    for (var i = 0; i < builtChildren.length; i++) {
      colChildren.add(builtChildren[i]);
      if (i < builtChildren.length - 1 && gap > 0) {
        colChildren.add(SizedBox(height: gap));
      }
    }

    Widget column = Column(
      mainAxisAlignment: mainAlign,
      crossAxisAlignment: crossAlign,
      // MainAxisSize.max when any child has main-axis Fill
      mainAxisSize:
          anyChildHasMainAxisFill ? MainAxisSize.max : MainAxisSize.min,
      children: colChildren,
    );

    // Wrap in scroll view if scrollable (vertical for column)
    final scrollDirection = node.propOr<String?>('scrollDirection', null);
    if (scrollDirection == 'vertical') {
      column = SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: const ClampingScrollPhysics(),
        child: column,
      );
    }

    return _applySizing(node, column, doc);
  }

  /// Build a text widget.
  Widget _buildText(RenderNode node) {
    final text = node.propOr<String>('text', '');
    final fontSize = node.propOr<double>('fontSize', 14.0);
    final fontWeight = _parseFontWeight(node.propOr<int>('fontWeight', 400));
    final textAlign = _parseTextAlign(node.propOr<String>('textAlign', 'left'));
    final color = node.prop<Color>('textColor');
    final fontFamily = node.prop<String>('fontFamily');
    final lineHeight = node.prop<double>('lineHeight');
    final letterSpacing = node.prop<double>('letterSpacing');
    final decoration = _parseTextDecoration(
      node.propOr<String>('textDecoration', 'none'),
    );

    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontFamily: fontFamily,
        height: lineHeight,
        letterSpacing: letterSpacing,
        decoration: decoration,
      ),
    );
  }

  /// Build an image widget.
  Widget _buildImage(RenderNode node) {
    final src = node.propOr<String>('src', '');
    final fit = _parseBoxFit(node.propOr<String>('fit', 'cover'));

    if (src.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build image widget
    Widget image;
    if (src.startsWith('http://') || src.startsWith('https://')) {
      image = Image.network(
        src,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image);
        },
      );
    } else {
      image = Image.asset(
        src,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.broken_image);
        },
      );
    }

    // Apply corner radius clipping if present
    final cornerTopLeft = node.propOr<double>('cornerTopLeft', 0.0);
    final cornerTopRight = node.propOr<double>('cornerTopRight', 0.0);
    final cornerBottomLeft = node.propOr<double>('cornerBottomLeft', 0.0);
    final cornerBottomRight = node.propOr<double>('cornerBottomRight', 0.0);

    if (cornerTopLeft > 0 ||
        cornerTopRight > 0 ||
        cornerBottomLeft > 0 ||
        cornerBottomRight > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(cornerTopLeft),
          topRight: Radius.circular(cornerTopRight),
          bottomLeft: Radius.circular(cornerBottomLeft),
          bottomRight: Radius.circular(cornerBottomRight),
        ),
        child: image,
      );
    }

    return image;
  }

  /// Build an icon widget.
  ///
  /// Icons are resolved with Lucide priority, falling back to Material Icons
  /// if the icon name is not found in Lucide.
  Widget _buildIcon(RenderNode node) {
    final iconName = node.propOr<String>('icon', '');
    final size = node.propOr<double>('iconSize', 24.0);
    final color = node.prop<Color>('iconColor');

    final iconData = _resolveIcon(iconName);

    return Icon(
      iconData,
      size: size,
      color: color,
      semanticLabel: iconName,
    );
  }

  /// Resolve an icon by name with Lucide priority and Material fallback.
  ///
  /// Strategy:
  /// 1. Try to resolve as Lucide icon (1,657+ icons) using kebab-case
  /// 2. If not found, fall back to Material Icons (8,800+ icons) using snake_case
  /// 3. If still not found, return help icon as fallback
  ///
  /// Supports both kebab-case and snake_case input - normalizes appropriately for each library.
  IconData _resolveIcon(String name) {
    // Normalize to kebab-case for Lucide attempt
    final kebabName = name.replaceAll('_', '-');
    final lucideIcon = _resolveLucideIcon(kebabName);
    if (lucideIcon != null) {
      return lucideIcon;
    }

    // Fall back to Material Icons (uses snake_case)
    return _resolveMaterialIcon(name);
  }

  /// Resolve a Lucide icon by name (kebab-case).
  ///
  /// Returns null if not found, allowing fallback to Material Icons.
  ///
  /// IMPORTANT: This expects kebab-case input (e.g., 'arrow-left').
  /// The caller should normalize underscores to dashes before calling this.
  ///
  /// Uses the generated lucideIconMap from lucide_icons.dart which includes
  /// all 1,657 Lucide icons, plus common Material → Lucide aliases.
  IconData? _resolveLucideIcon(String kebabName) {
    // Check common Material Icon name aliases first
    // This allows Material-style names to resolve to Lucide icons
    final aliasedName = switch (kebabName) {
      'home' => 'house',
      'add' => 'plus',
      'remove' => 'minus',
      'edit' => 'pencil',
      'close' => 'x',
      'favorite' => 'heart',
      'notifications' => 'bell',
      'videocam' => 'video',
      'photo-camera' => 'camera',
      'location-on' => 'map-pin',
      'calendar-today' => 'calendar',
      'access-time' => 'clock',
      'account-circle' => 'user-round',
      'more-vert' => 'ellipsis-vertical',
      'more-horiz' => 'ellipsis',
      'attach-file' => 'paperclip',
      'file-copy' => 'file',
      'thumb-up' => 'thumbs-up',
      'thumb-down' => 'thumbs-down',
      'visibility' => 'eye',
      'visibility-off' => 'eye-off',
      'lock-open' => 'lock-open',
      'person' => 'user',
      'person-circle' => 'circle-user',
      'person-add' => 'user-round-plus',
      'person-remove' => 'user-round-minus',
      'person-edit' => 'user-round-pen',
      'person-delete' => 'user-round-x',
      _ => kebabName, // Use original if no alias
    };

    // Use the generated resolver function (expects kebab-case)
    return resolveLucideIcon(aliasedName);
  }

  /// Resolve a Material icon by name.
  ///
  /// This is the fallback when an icon is not found in Lucide.
  /// Uses the IconHelper which provides access to all ~8,800 Material Icons.
  IconData _resolveMaterialIcon(String name) {
    // Material Icons use snake_case
    // Convert kebab-case to snake_case if needed
    final snakeName = name.replaceAll('-', '_');

    // Try to get icon from the comprehensive IconHelper
    final icon = IconHelper.getIconByName(snakeName);

    // Fall back to help_outline if not found
    return icon ?? Icons.help_outline;
  }

  /// Build a spacer widget.
  Widget _buildSpacer(RenderNode node) {
    final flex = node.propOr<int>('flex', 1);
    final width = node.prop<double>('width');
    final height = node.prop<double>('height');

    if (width != null || height != null) {
      return SizedBox(width: width, height: height);
    }

    return Spacer(flex: flex);
  }

  /// Build children widgets with their IDs.
  List<MapEntry<String, Widget>> _buildChildren(
    List<String> childIds,
    RenderDocument doc,
    int docGeneration,
  ) {
    return childIds
        .map((id) => MapEntry(id, _buildNode(id, doc, docGeneration)))
        .where(
          (e) => e.value is! SizedBox || (e.value as SizedBox).child != null,
        )
        .toList();
  }

  /// Apply sizing, constraints, and decoration to a widget.
  ///
  /// Handles Hug/Fill/Fixed modes for the node itself (not its children).
  /// For auto-layout children, use _applyChildFillSizing instead.
  ///
  /// Steps:
  /// 1. Apply sizing (Hug/Fixed/Fill via SizedBox/SizedBox.expand/LayoutBuilder)
  /// 2. Apply layout constraints (min/max bounds via ConstrainedBox)
  /// 3. Apply decoration and padding (Container)
  /// 4. Apply reflow offset (Transform for drag preview)
  Widget _applySizing(
    RenderNode node,
    Widget child,
    RenderDocument doc,
  ) {
    final widthMode = node.propOr<String>('widthMode', 'hug');
    final heightMode = node.propOr<String>('heightMode', 'hug');
    final width = node.prop<double>('width');
    final height = node.prop<double>('height');

    Widget result = child;

    // Step 1: Apply sizing (container-level)
    if (widthMode == 'fill' && heightMode == 'fill') {
      // Both axes Fill → SizedBox.expand
      result = SizedBox.expand(child: result);
    } else if (widthMode == 'fill' || heightMode == 'fill') {
      // Single-axis Fill → Use LayoutBuilder to get constraints
      result = LayoutBuilder(
        builder: (context, constraints) {
          final w =
              widthMode == 'fill'
                  ? constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : null
                  : (widthMode == 'fixed' ? width : null);
          final h =
              heightMode == 'fill'
                  ? constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : null
                  : (heightMode == 'fixed' ? height : null);

          // Fallback to Hug if constraints unbounded
          if ((widthMode == 'fill' && (w == null || w == double.infinity)) ||
              (heightMode == 'fill' && (h == null || h == double.infinity))) {
            debugPrint(
              'WARN: Node ${node.id} has Fill but parent unbounded. '
              'Falling back to Hug.',
            );
            // Downgrade to Hug
            return child;
          }

          return SizedBox(width: w, height: h, child: child);
        },
      );
    } else if (widthMode == 'fixed' || heightMode == 'fixed') {
      // Fixed size
      final w = widthMode == 'fixed' ? width : null;
      final h = heightMode == 'fixed' ? height : null;
      result = SizedBox(width: w, height: h, child: result);
    }
    // Else: Hug (default) - no wrapper

    // Step 2: Apply layout constraints (min/max bounds)
    final constraints = node.prop<Map<String, dynamic>>('constraints');
    if (constraints != null) {
      final minWidth = constraints['minWidth'] as double?;
      final maxWidth = constraints['maxWidth'] as double?;
      final minHeight = constraints['minHeight'] as double?;
      final maxHeight = constraints['maxHeight'] as double?;

      if (minWidth != null ||
          maxWidth != null ||
          minHeight != null ||
          maxHeight != null) {
        result = ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth ?? 0,
            maxWidth: maxWidth ?? double.infinity,
            minHeight: minHeight ?? 0,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: result,
        );
      }
    }

    // Step 3: Apply decoration and padding
    final decoration = _buildDecoration(node);
    final padding = _buildPadding(node);

    if (decoration != null || padding != EdgeInsets.zero) {
      result = Container(
        padding: padding != EdgeInsets.zero ? padding : null,
        decoration: decoration,
        child: result,
      );
    }

    // Step 4: Apply reflow offset (drag preview transform)
    final reflowOffset = reflowOffsets[node.id];
    if (reflowOffset != null && reflowOffset != Offset.zero) {
      result = Transform.translate(
        offset: reflowOffset,
        child: result,
      );
    }

    return result;
  }

  /// Apply Fill sizing for auto-layout children.
  ///
  /// Determines:
  /// - Main-axis Fill → Expanded(flex: 1)
  /// - Cross-axis Fill → Handled via parent crossAxisAlignment.stretch if [parentHasStretch],
  ///   otherwise uses LayoutBuilder
  /// - Fixed/Hug → Plain child (possibly wrapped in SizedBox for Fixed)
  ///
  /// Returns: (widget, hasMainAxisFill)
  (Widget, bool) _applyChildFillSizing(
    RenderNode childNode,
    Widget child,
    LayoutDirection parentDirection,
    bool parentHasStretch,
    RenderDocument doc,
  ) {
    final widthMode = childNode.propOr<String>('widthMode', 'hug');
    final heightMode = childNode.propOr<String>('heightMode', 'hug');
    final width = childNode.prop<double>('width');
    final height = childNode.prop<double>('height');

    final isHorizontalLayout = parentDirection == LayoutDirection.horizontal;

    // Determine which axis is main-axis
    final mainAxisMode = isHorizontalLayout ? widthMode : heightMode;
    final crossAxisMode = isHorizontalLayout ? heightMode : widthMode;

    // Main-axis Fill → Expanded
    if (mainAxisMode == 'fill') {
      Widget result = child;

      // Apply cross-axis sizing
      if (crossAxisMode == 'fill') {
        // Cross-axis Fill: if parent has stretch, Flutter handles it automatically
        // Otherwise, use LayoutBuilder to get available space
        if (!parentHasStretch) {
          result = LayoutBuilder(
            builder: (context, constraints) {
              final crossSize =
                  isHorizontalLayout
                      ? (constraints.maxHeight.isFinite
                          ? constraints.maxHeight
                          : null)
                      : (constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : null);

              if (crossSize == null) {
                return child; // Unbounded - fall back to Hug
              }

              return isHorizontalLayout
                  ? SizedBox(height: crossSize, child: child)
                  : SizedBox(width: crossSize, child: child);
            },
          );
        }
        // else: parentHasStretch handles cross-axis Fill automatically
      } else if (crossAxisMode == 'fixed') {
        // Fixed cross-axis size
        final crossSize = isHorizontalLayout ? height : width;
        if (crossSize != null) {
          result =
              isHorizontalLayout
                  ? SizedBox(height: crossSize, child: result)
                  : SizedBox(width: crossSize, child: result);
        }
      }

      // Wrap in Expanded for main-axis Fill
      return (Expanded(flex: 1, child: result), true);
    }

    // Main-axis Fixed → SizedBox
    if (mainAxisMode == 'fixed') {
      final mainSize = isHorizontalLayout ? width : height;
      if (mainSize != null) {
        Widget result = child;

        // Apply cross-axis sizing
        if (crossAxisMode == 'fill') {
          // Cross-axis Fill: if parent has stretch, Flutter handles it automatically
          // Otherwise, use LayoutBuilder
          if (parentHasStretch) {
            // Just apply main-axis size, stretch handles cross-axis
            result =
                isHorizontalLayout
                    ? SizedBox(width: mainSize, child: result)
                    : SizedBox(height: mainSize, child: result);
          } else {
            result = LayoutBuilder(
              builder: (context, constraints) {
                final crossSize =
                    isHorizontalLayout
                        ? (constraints.maxHeight.isFinite
                            ? constraints.maxHeight
                            : null)
                        : (constraints.maxWidth.isFinite
                            ? constraints.maxWidth
                            : null);

                if (crossSize == null) {
                  // Unbounded - apply only main-axis size
                  return isHorizontalLayout
                      ? SizedBox(width: mainSize, child: child)
                      : SizedBox(height: mainSize, child: child);
                }

                return isHorizontalLayout
                    ? SizedBox(width: mainSize, height: crossSize, child: child)
                    : SizedBox(
                      width: crossSize,
                      height: mainSize,
                      child: child,
                    );
              },
            );
          }
        } else if (crossAxisMode == 'fixed') {
          // Both axes Fixed
          final crossSize = isHorizontalLayout ? height : width;
          result =
              isHorizontalLayout
                  ? SizedBox(width: mainSize, height: crossSize, child: result)
                  : SizedBox(width: crossSize, height: mainSize, child: result);
        } else {
          // Main-axis Fixed, cross-axis Hug
          result =
              isHorizontalLayout
                  ? SizedBox(width: mainSize, child: result)
                  : SizedBox(height: mainSize, child: result);
        }

        return (result, false);
      }
    }

    // Hug on main-axis
    if (crossAxisMode == 'fill') {
      // Cross-axis Fill only: if parent has stretch, Flutter handles it automatically
      // Otherwise, use LayoutBuilder
      if (parentHasStretch) {
        // No wrapper needed - stretch handles cross-axis Fill
        return (child, false);
      }
      final result = LayoutBuilder(
        builder: (context, constraints) {
          final crossSize =
              isHorizontalLayout
                  ? (constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : null)
                  : (constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : null);

          if (crossSize == null) {
            return child; // Unbounded - fall back to Hug
          }

          return isHorizontalLayout
              ? SizedBox(height: crossSize, child: child)
              : SizedBox(width: crossSize, child: child);
        },
      );
      return (result, false);
    } else if (crossAxisMode == 'fixed') {
      // Cross-axis Fixed only
      final crossSize = isHorizontalLayout ? height : width;
      if (crossSize != null) {
        final result =
            isHorizontalLayout
                ? SizedBox(height: crossSize, child: child)
                : SizedBox(width: crossSize, child: child);
        return (result, false);
      }
    }

    // Both axes Hug (default)
    return (child, false);
  }

  /// Build padding from node properties.
  EdgeInsets _buildPadding(RenderNode node) {
    final paddingLeft = node.propOr<double>('paddingLeft', 0.0);
    final paddingTop = node.propOr<double>('paddingTop', 0.0);
    final paddingRight = node.propOr<double>('paddingRight', 0.0);
    final paddingBottom = node.propOr<double>('paddingBottom', 0.0);

    return EdgeInsets.only(
      left: paddingLeft,
      top: paddingTop,
      right: paddingRight,
      bottom: paddingBottom,
    );
  }

  /// Build decoration (background, border, shadow) from node properties.
  BoxDecoration? _buildDecoration(RenderNode node) {
    final fillColor = node.prop<Color>('fillColor');
    final strokeColor = node.prop<Color>('strokeColor');
    final strokeWidth = node.propOr<double>('strokeWidth', 0.0);

    final cornerTopLeft = node.propOr<double>('cornerTopLeft', 0.0);
    final cornerTopRight = node.propOr<double>('cornerTopRight', 0.0);
    final cornerBottomLeft = node.propOr<double>('cornerBottomLeft', 0.0);
    final cornerBottomRight = node.propOr<double>('cornerBottomRight', 0.0);

    BorderRadius? borderRadius;
    if (cornerTopLeft > 0 ||
        cornerTopRight > 0 ||
        cornerBottomLeft > 0 ||
        cornerBottomRight > 0) {
      borderRadius = BorderRadius.only(
        topLeft: Radius.circular(cornerTopLeft),
        topRight: Radius.circular(cornerTopRight),
        bottomLeft: Radius.circular(cornerBottomLeft),
        bottomRight: Radius.circular(cornerBottomRight),
      );
    }

    Border? border;
    if (strokeColor != null && strokeWidth > 0) {
      border = Border.all(color: strokeColor, width: strokeWidth);
    }

    // Shadow
    List<BoxShadow>? boxShadow;
    final shadowColor = node.prop<Color>('shadowColor');
    if (shadowColor != null) {
      final shadowOffsetX = node.propOr<double>('shadowOffsetX', 0.0);
      final shadowOffsetY = node.propOr<double>('shadowOffsetY', 4.0);
      final shadowBlur = node.propOr<double>('shadowBlur', 8.0);
      final shadowSpread = node.propOr<double>('shadowSpread', 0.0);

      boxShadow = [
        BoxShadow(
          color: shadowColor,
          offset: Offset(shadowOffsetX, shadowOffsetY),
          blurRadius: shadowBlur,
          spreadRadius: shadowSpread,
        ),
      ];
    }

    if (fillColor != null ||
        border != null ||
        borderRadius != null ||
        boxShadow != null) {
      return BoxDecoration(
        color: fillColor,
        border: border,
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      );
    }

    return null;
  }

  // ==========================================================================
  // Parsing helpers
  // ==========================================================================

  MainAxisAlignment _parseMainAxisAlignment(String value) {
    return switch (value) {
      'start' => MainAxisAlignment.start,
      'center' => MainAxisAlignment.center,
      'end' => MainAxisAlignment.end,
      'spaceBetween' => MainAxisAlignment.spaceBetween,
      'spaceAround' => MainAxisAlignment.spaceAround,
      'spaceEvenly' => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String value) {
    return switch (value) {
      'start' => CrossAxisAlignment.start,
      'center' => CrossAxisAlignment.center,
      'end' => CrossAxisAlignment.end,
      'stretch' => CrossAxisAlignment.stretch,
      _ => CrossAxisAlignment.start,
    };
  }

  TextAlign _parseTextAlign(String value) {
    return switch (value) {
      'left' => TextAlign.left,
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };
  }

  TextDecoration _parseTextDecoration(String value) {
    return switch (value) {
      'underline' => TextDecoration.underline,
      'lineThrough' => TextDecoration.lineThrough,
      _ => TextDecoration.none,
    };
  }

  FontWeight _parseFontWeight(int weight) {
    return switch (weight) {
      100 => FontWeight.w100,
      200 => FontWeight.w200,
      300 => FontWeight.w300,
      400 => FontWeight.w400,
      500 => FontWeight.w500,
      600 => FontWeight.w600,
      700 => FontWeight.w700,
      800 => FontWeight.w800,
      900 => FontWeight.w900,
      _ => FontWeight.w400,
    };
  }

  BoxFit _parseBoxFit(String value) {
    return switch (value) {
      'contain' => BoxFit.contain,
      'cover' => BoxFit.cover,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      'none' => BoxFit.none,
      'scaleDown' => BoxFit.scaleDown,
      _ => BoxFit.cover,
    };
  }
}

// =============================================================================
// Bounds Tracking
// =============================================================================

/// Widget that tracks its rendered bounds and reports them via callback.
///
/// Uses a post-frame callback to get accurate bounds after layout.
/// Bounds are reported in frame-local coordinates (relative to [frameRootKey]).
class _BoundsTracker extends StatefulWidget {
  const _BoundsTracker({
    required this.nodeId,
    required this.frameRootKey,
    required this.onBoundsChanged,
    required this.child,
    this.compiledBounds,
    this.propsHash,
    required this.docGeneration,
  });

  final String nodeId;

  /// Key identifying the frame's root widget for coordinate conversion.
  final GlobalKey frameRootKey;

  final void Function(String nodeId, Rect bounds) onBoundsChanged;
  final Widget child;

  /// Optional pre-computed bounds from compilation.
  final Rect? compiledBounds;

  /// Hash of props + childIds to detect changes that require remeasurement.
  final int? propsHash;

  /// Document generation (hashCode). When this changes, the document was
  /// recompiled, so we need to remeasure even if propsHash is unchanged.
  final int docGeneration;

  @override
  State<_BoundsTracker> createState() => _BoundsTrackerState();
}

class _BoundsTrackerState extends State<_BoundsTracker> {
  final _key = GlobalKey();
  Rect? _lastBounds;
  int _measurementAttempts = 0;
  static const int kMaxAttempts = 10; // Max 10 frame retries

  @override
  void initState() {
    super.initState();

    // If bounds already compiled, report immediately
    if (widget.compiledBounds != null) {
      _reportBounds(widget.compiledBounds!);
    } else {
      // Auto-layout node - schedule measurement
      _scheduleMeasurement();
    }
  }

  @override
  void didUpdateWidget(_BoundsTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset attempt counter on widget update
    _measurementAttempts = 0;

    // Handle compiled bounds change
    if (widget.compiledBounds != oldWidget.compiledBounds) {
      if (widget.compiledBounds != null) {
        _reportBounds(widget.compiledBounds!);
        return;
      } else {
        // Lost compiled bounds - remeasure
        _scheduleMeasurement();
        return;
      }
    }

    // For auto-layout nodes, remeasure if:
    // 1. Props changed (detected by propsHash)
    // 2. Document was recompiled (detected by docGeneration)
    if (widget.compiledBounds == null) {
      if (widget.propsHash != oldWidget.propsHash) {
        _scheduleMeasurement();
      } else if (widget.docGeneration != oldWidget.docGeneration) {
        // Clear cached bounds so remeasurement will report even if value is same
        _lastBounds = null;
        _scheduleMeasurement();
      }
    }
  }

  void _reportBounds(Rect bounds) {
    if (_lastBounds != bounds) {
      _lastBounds = bounds;
      widget.onBoundsChanged(widget.nodeId, bounds);
    }
  }

  void _scheduleMeasurement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureAndReportBounds();
    });
  }

  void _measureAndReportBounds() {
    // Increment attempt counter
    _measurementAttempts++;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      if (_measurementAttempts >= kMaxAttempts) {
        // Give up after max attempts - use fallback
        _reportFallbackBounds();
        return;
      }
      // RenderBox not ready yet, reschedule measurement
      _scheduleMeasurement();
      return;
    }

    // Get the frame root's RenderBox for coordinate conversion
    final frameRootContext = widget.frameRootKey.currentContext;
    if (frameRootContext == null) {
      if (_measurementAttempts >= kMaxAttempts) {
        // Give up after max attempts - use fallback
        _reportFallbackBounds();
        return;
      }
      // Frame root context not ready yet, reschedule measurement
      _scheduleMeasurement();
      return;
    }

    final frameRootBox = frameRootContext.findRenderObject() as RenderBox?;
    if (frameRootBox == null) {
      if (_measurementAttempts >= kMaxAttempts) {
        // Give up after max attempts - use fallback
        _reportFallbackBounds();
        return;
      }
      // Frame root RenderBox not ready yet, reschedule measurement
      _scheduleMeasurement();
      return;
    }

    // Success - get position relative to the frame root (frame-local coordinates)
    final position = renderBox.localToGlobal(
      Offset.zero,
      ancestor: frameRootBox,
    );
    final size = renderBox.size;
    final bounds = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    _reportBounds(bounds);
    _measurementAttempts = 0; // Reset for next update
  }

  void _reportFallbackBounds() {
    // Use compiled bounds if available
    final compiled = widget.compiledBounds;
    if (compiled != null && _lastBounds != compiled) {
      _lastBounds = compiled;
      widget.onBoundsChanged(widget.nodeId, compiled);
      return;
    }

    // No fallback available - log and give up
    debugPrint(
      'BoundsTracker: Failed to measure ${widget.nodeId} after $kMaxAttempts attempts',
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}
