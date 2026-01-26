/// ECS Core: World
///
/// The World is the container for all entities and components.
/// It's the single source of truth for application state.

import 'dart:ui';

import 'entity.dart';
import 'component.dart';
import '../components/components.dart';

/// The World holds all ECS data.
/// Access components through typed tables.
class World {
  final EntityAllocator _entities = EntityAllocator();

  // ─────────────────────────────────────────────────────────────────────────
  // Component Tables - one per component type
  // ─────────────────────────────────────────────────────────────────────────

  /// Spatial position (x, y in local coordinates)
  final ComponentTable<Position> position = ComponentTable();

  /// Size (width, height)
  final ComponentTable<Size> size = ComponentTable();

  /// Fill (background color, gradient, image)
  final ComponentTable<Fill> fill = ComponentTable();

  /// Stroke (border)
  final ComponentTable<Stroke> stroke = ComponentTable();

  /// Corner radius
  final ComponentTable<CornerRadius> cornerRadius = ComponentTable();

  /// Text content
  final ComponentTable<TextContent> text = ComponentTable();

  /// Hierarchy (parent-child relationships)
  final ComponentTable<Hierarchy> hierarchy = ComponentTable();

  /// Computed world transform (set by TransformSystem)
  final ComponentTable<WorldTransform> worldTransform = ComponentTable();

  /// Computed world bounds (set by BoundsSystem)
  final ComponentTable<WorldBounds> worldBounds = ComponentTable();

  /// Auto-layout settings
  final ComponentTable<AutoLayout> autoLayout = ComponentTable();

  /// Frame marker (indicates this entity is a frame/artboard)
  final ComponentTable<FrameMarker> frame = ComponentTable();

  /// Component instance (references a component definition)
  final ComponentTable<Instance> instance = ComponentTable();

  /// Component definition marker
  final ComponentTable<ComponentDef> componentDef = ComponentTable();

  /// Name/label for debugging and UI
  final ComponentTable<Name> name = ComponentTable();

  /// Opacity
  final ComponentTable<Opacity> opacity = ComponentTable();

  /// Visibility
  final ComponentTable<Visibility> visibility = ComponentTable();

  /// Shadow effects
  final ComponentTable<Shadows> shadows = ComponentTable();

  // ─────────────────────────────────────────────────────────────────────────
  // Entity Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Spawn a new empty entity
  Entity spawn() => _entities.spawn();

  /// Despawn an entity and remove all its components
  void despawn(Entity entity) {
    _entities.despawn(entity);
    _removeAllComponents(entity);
  }

  /// Check if entity is alive
  bool isAlive(Entity entity) => _entities.isAlive(entity);

  /// All living entities
  Set<Entity> get entities => _entities.alive;

  /// Remove entity from all component tables
  void _removeAllComponents(Entity entity) {
    position.remove(entity);
    size.remove(entity);
    fill.remove(entity);
    stroke.remove(entity);
    cornerRadius.remove(entity);
    text.remove(entity);
    hierarchy.remove(entity);
    worldTransform.remove(entity);
    worldBounds.remove(entity);
    autoLayout.remove(entity);
    frame.remove(entity);
    instance.remove(entity);
    componentDef.remove(entity);
    name.remove(entity);
    opacity.remove(entity);
    visibility.remove(entity);
    shadows.remove(entity);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Common Queries
  // ─────────────────────────────────────────────────────────────────────────

  /// All frames in the world
  Iterable<(Entity, FrameMarker)> get frames => frame.entries;

  /// All root entities (no parent)
  Iterable<Entity> get roots sync* {
    for (final entity in entities) {
      final h = hierarchy.get(entity);
      if (h == null || h.parent == null) {
        yield entity;
      }
    }
  }

  /// Children of an entity, sorted by childIndex
  List<Entity> childrenOf(Entity parent) {
    final children = <Entity>[];
    for (final (entity, h) in hierarchy.entries) {
      if (h.parent == parent) {
        children.add(entity);
      }
    }
    children.sort((a, b) {
      final aIdx = hierarchy.get(a)?.childIndex ?? 0;
      final bIdx = hierarchy.get(b)?.childIndex ?? 0;
      return aIdx.compareTo(bIdx);
    });
    return children;
  }

  /// All descendants of an entity (depth-first)
  Iterable<Entity> descendantsOf(Entity parent) sync* {
    for (final child in childrenOf(parent)) {
      yield child;
      yield* descendantsOf(child);
    }
  }

  /// Ancestors of an entity (parent, grandparent, etc.)
  Iterable<Entity> ancestorsOf(Entity entity) sync* {
    var current = hierarchy.get(entity)?.parent;
    while (current != null) {
      yield current;
      current = hierarchy.get(current)?.parent;
    }
  }

  /// Topological order for transform computation (parents before children)
  Iterable<Entity> topologicalOrder() sync* {
    // Simple BFS from roots
    final visited = <Entity>{};
    final queue = roots.toList();

    while (queue.isNotEmpty) {
      final entity = queue.removeAt(0);
      if (visited.contains(entity)) continue;
      visited.add(entity);
      yield entity;
      queue.addAll(childrenOf(entity));
    }
  }

  /// Entities visible in a viewport (requires worldBounds to be computed)
  Iterable<Entity> visibleIn(Rect viewport) sync* {
    for (final (entity, bounds) in worldBounds.entries) {
      if (bounds.rect.overlaps(viewport)) {
        yield entity;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Builder Pattern for Convenient Entity Creation
  // ─────────────────────────────────────────────────────────────────────────

  /// Fluent builder for creating entities
  EntityBuilder entity() => EntityBuilder(this);
}

/// Fluent builder for entity creation
class EntityBuilder {
  final World _world;
  final Entity _entity;

  EntityBuilder(this._world) : _entity = _world.spawn();

  Entity get id => _entity;

  EntityBuilder withPosition(double x, double y) {
    _world.position.set(_entity, Position(x, y));
    return this;
  }

  EntityBuilder withSize(double width, double height) {
    _world.size.set(_entity, Size(width, height));
    return this;
  }

  EntityBuilder withFill(Color color) {
    _world.fill.set(_entity, Fill.solid(color));
    return this;
  }

  EntityBuilder withStroke(Color color, double width) {
    _world.stroke.set(_entity, Stroke(color: color, width: width));
    return this;
  }

  EntityBuilder withCornerRadius(double radius) {
    _world.cornerRadius.set(_entity, CornerRadius.all(radius));
    return this;
  }

  EntityBuilder withText(String content, {TextStyle? style}) {
    _world.text.set(_entity, TextContent(text: content, style: style));
    return this;
  }

  EntityBuilder withName(String label) {
    _world.name.set(_entity, Name(label));
    return this;
  }

  EntityBuilder withParent(Entity parent, {int? childIndex}) {
    final idx = childIndex ?? _world.childrenOf(parent).length;
    _world.hierarchy.set(_entity, Hierarchy(parent: parent, childIndex: idx));
    return this;
  }

  EntityBuilder withAutoLayout({
    required LayoutDirection direction,
    double gap = 0,
    EdgePadding padding = EdgePadding.zero,
    MainAxisAlignment mainAxis = MainAxisAlignment.start,
    CrossAxisAlignment crossAxis = CrossAxisAlignment.start,
  }) {
    _world.autoLayout.set(_entity, AutoLayout(
      direction: direction,
      gap: gap,
      padding: padding,
      mainAxisAlignment: mainAxis,
      crossAxisAlignment: crossAxis,
    ));
    return this;
  }

  EntityBuilder asFrame({required double canvasX, required double canvasY}) {
    _world.frame.set(_entity, FrameMarker(canvasX: canvasX, canvasY: canvasY));
    return this;
  }

  EntityBuilder withOpacity(double value) {
    _world.opacity.set(_entity, Opacity(value));
    return this;
  }

  EntityBuilder visible(bool isVisible) {
    _world.visibility.set(_entity, Visibility(isVisible));
    return this;
  }

  /// Finish building and return the entity ID
  Entity build() => _entity;
}

/// Text style (simplified for this sketch)
class TextStyle {
  final double fontSize;
  final Color color;
  final String fontFamily;
  final FontWeight fontWeight;

  const TextStyle({
    this.fontSize = 14,
    this.color = const Color(0xFF000000),
    this.fontFamily = 'Inter',
    this.fontWeight = FontWeight.normal,
  });
}

/// Font weight enum
enum FontWeight { normal, bold }
