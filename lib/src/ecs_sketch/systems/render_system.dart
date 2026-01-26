/// Render System
///
/// Paints entities to a Canvas.
/// This bypasses Flutter's widget system for performance.

import 'dart:ui' as ui;

import '../core/entity.dart';
import '../core/world.dart';
import '../components/components.dart';

/// Renders all visible entities to a Canvas
class RenderSystem {
  final Map<Entity, ui.Paragraph> _paragraphCache = {};

  /// Render all entities visible in the viewport
  void render(World world, ui.Canvas canvas, ui.Rect viewport) {
    // Get entities in render order (back to front)
    final renderOrder = _buildRenderOrder(world, viewport);

    for (final entity in renderOrder) {
      _renderEntity(world, canvas, entity);
    }
  }

  List<Entity> _buildRenderOrder(World world, ui.Rect viewport) {
    final result = <Entity>[];

    void collectRecursive(List<Entity> entities) {
      for (final entity in entities) {
        // Skip invisible
        final visibility = world.visibility.get(entity);
        if (visibility != null && !visibility.isVisible) continue;

        // Cull if outside viewport
        final bounds = world.worldBounds.get(entity);
        if (bounds != null && !bounds.overlaps(viewport)) continue;

        result.add(entity);

        // Children render after (on top of) parent
        collectRecursive(world.childrenOf(entity));
      }
    }

    collectRecursive(world.roots.toList());
    return result;
  }

  void _renderEntity(World world, ui.Canvas canvas, Entity entity) {
    final transform = world.worldTransform.get(entity);
    final size = world.size.get(entity);

    if (transform == null) return;

    canvas.save();

    // Apply world transform
    canvas.transform(Float64List.fromList(transform.matrix.storage));

    // Apply opacity
    final opacity = world.opacity.get(entity);
    if (opacity != null && opacity.value < 1.0) {
      canvas.saveLayer(
        null,
        ui.Paint()..color = ui.Color.fromARGB((opacity.value * 255).round(), 255, 255, 255),
      );
    }

    // Render based on components
    if (size != null) {
      final rect = ui.Rect.fromLTWH(0, 0, size.width, size.height);

      // Shadows (render first, behind shape)
      final shadows = world.shadows.get(entity);
      if (shadows != null) {
        _renderShadows(canvas, rect, world, entity, shadows);
      }

      // Fill
      final fill = world.fill.get(entity);
      if (fill != null && !fill.isNone) {
        _renderFill(canvas, rect, world, entity, fill);
      }

      // Stroke
      final stroke = world.stroke.get(entity);
      if (stroke != null) {
        _renderStroke(canvas, rect, world, entity, stroke);
      }
    }

    // Text
    final text = world.text.get(entity);
    if (text != null) {
      _renderText(canvas, world, entity, text, size);
    }

    // Pop opacity layer if applied
    if (opacity != null && opacity.value < 1.0) {
      canvas.restore();
    }

    canvas.restore();
  }

  void _renderFill(
    ui.Canvas canvas,
    ui.Rect rect,
    World world,
    Entity entity,
    Fill fill,
  ) {
    final paint = ui.Paint();

    switch (fill.type) {
      case FillType.solid:
        paint.color = fill.color!;
      case FillType.gradient:
        final gradient = fill.gradient!;
        if (gradient.type == GradientType.linear) {
          paint.shader = ui.Gradient.linear(
            rect.topLeft,
            rect.bottomRight,
            gradient.colors,
            gradient.stops,
          );
        } else {
          paint.shader = ui.Gradient.radial(
            rect.center,
            rect.shortestSide / 2,
            gradient.colors,
            gradient.stops,
          );
        }
      case FillType.image:
        // Image rendering would require asset loading - simplified here
        paint.color = const ui.Color(0xFFCCCCCC);
      case FillType.none:
        return;
    }

    final cornerRadius = world.cornerRadius.get(entity);
    if (cornerRadius != null) {
      canvas.drawRRect(
        ui.RRect.fromRectAndCorners(
          rect,
          topLeft: ui.Radius.circular(cornerRadius.topLeft),
          topRight: ui.Radius.circular(cornerRadius.topRight),
          bottomRight: ui.Radius.circular(cornerRadius.bottomRight),
          bottomLeft: ui.Radius.circular(cornerRadius.bottomLeft),
        ),
        paint,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  void _renderStroke(
    ui.Canvas canvas,
    ui.Rect rect,
    World world,
    Entity entity,
    Stroke stroke,
  ) {
    final paint = ui.Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..style = ui.PaintingStyle.stroke;

    // Adjust rect based on stroke position
    ui.Rect strokeRect;
    switch (stroke.position) {
      case StrokePosition.inside:
        strokeRect = rect.deflate(stroke.width / 2);
      case StrokePosition.center:
        strokeRect = rect;
      case StrokePosition.outside:
        strokeRect = rect.inflate(stroke.width / 2);
    }

    final cornerRadius = world.cornerRadius.get(entity);
    if (cornerRadius != null) {
      canvas.drawRRect(
        ui.RRect.fromRectAndCorners(
          strokeRect,
          topLeft: ui.Radius.circular(cornerRadius.topLeft),
          topRight: ui.Radius.circular(cornerRadius.topRight),
          bottomRight: ui.Radius.circular(cornerRadius.bottomRight),
          bottomLeft: ui.Radius.circular(cornerRadius.bottomLeft),
        ),
        paint,
      );
    } else {
      canvas.drawRect(strokeRect, paint);
    }
  }

  void _renderShadows(
    ui.Canvas canvas,
    ui.Rect rect,
    World world,
    Entity entity,
    Shadows shadows,
  ) {
    for (final shadow in shadows.shadows) {
      if (shadow.inner) continue; // Inner shadows are more complex

      final paint = ui.Paint()
        ..color = shadow.color
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, shadow.blur);

      final shadowRect = rect.translate(shadow.offsetX, shadow.offsetY);

      final cornerRadius = world.cornerRadius.get(entity);
      if (cornerRadius != null) {
        canvas.drawRRect(
          ui.RRect.fromRectAndCorners(
            shadowRect,
            topLeft: ui.Radius.circular(cornerRadius.topLeft),
            topRight: ui.Radius.circular(cornerRadius.topRight),
            bottomRight: ui.Radius.circular(cornerRadius.bottomRight),
            bottomLeft: ui.Radius.circular(cornerRadius.bottomLeft),
          ),
          paint,
        );
      } else {
        canvas.drawRect(shadowRect, paint);
      }
    }
  }

  void _renderText(
    ui.Canvas canvas,
    World world,
    Entity entity,
    TextContent text,
    Size? size,
  ) {
    // Check cache first
    var paragraph = _paragraphCache[entity];

    if (paragraph == null) {
      final style = text.style;
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: _convertTextAlign(text.align),
        maxLines: text.overflow == TextOverflow.ellipsis ? 1 : null,
        ellipsis: text.overflow == TextOverflow.ellipsis ? '...' : null,
      ));

      builder.pushStyle(ui.TextStyle(
        color: style?.color ?? const ui.Color(0xFF000000),
        fontSize: style?.fontSize ?? 14,
        fontFamily: style?.fontFamily ?? 'Inter',
        fontWeight: style?.fontWeight == FontWeight.bold
            ? ui.FontWeight.bold
            : ui.FontWeight.normal,
      ));

      builder.addText(text.text);
      paragraph = builder.build();

      final maxWidth = size?.width ?? double.infinity;
      paragraph.layout(ui.ParagraphConstraints(width: maxWidth));

      _paragraphCache[entity] = paragraph;
    }

    canvas.drawParagraph(paragraph, ui.Offset.zero);
  }

  ui.TextAlign _convertTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return ui.TextAlign.left;
      case TextAlign.center:
        return ui.TextAlign.center;
      case TextAlign.right:
        return ui.TextAlign.right;
      case TextAlign.justify:
        return ui.TextAlign.justify;
    }
  }

  /// Clear paragraph cache for an entity (call when text changes)
  void invalidateText(Entity entity) {
    _paragraphCache.remove(entity);
  }

  /// Clear entire paragraph cache
  void clearCache() {
    _paragraphCache.clear();
  }
}

/// Type alias for Float64List
typedef Float64List = List<double>;
