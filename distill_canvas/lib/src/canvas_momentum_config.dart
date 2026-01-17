import 'dart:ui';

/// Configuration for pan/scroll momentum and sensitivity.
///
/// Controls how trackpad and scroll gestures feel:
/// - **Sensitivity** makes panning feel quicker or slower
/// - **Momentum** adds inertia after gesture release
///
/// ```dart
/// InfiniteCanvas(
///   momentumConfig: CanvasMomentumConfig(
///     panSensitivity: 1.5,           // 50% faster panning
///     enableMomentum: true,          // Inertia on release
///     friction: 0.015,               // How quickly momentum decays
///   ),
/// )
/// ```
///
/// Use presets for common configurations:
/// - [CanvasMomentumConfig.defaults] — No momentum (backward compatible)
/// - [CanvasMomentumConfig.figmaLike] — Quick, smooth, Figma-style feel
/// - [CanvasMomentumConfig.smooth] — iOS-like long glide
/// - [CanvasMomentumConfig.precise] — No momentum, slight sensitivity boost
class CanvasMomentumConfig {
  const CanvasMomentumConfig({
    this.panSensitivity = 1.0,
    this.scrollSensitivity = 1.0,
    this.enableMomentum = false,
    this.friction = 0.015,
    this.minVelocity = 50.0,
    this.maxVelocity = 8000.0,
  }) : assert(panSensitivity > 0, 'panSensitivity must be positive'),
       assert(scrollSensitivity > 0, 'scrollSensitivity must be positive'),
       assert(friction > 0 && friction < 1, 'friction must be in range (0, 1)'),
       assert(minVelocity >= 0, 'minVelocity must be non-negative'),
       assert(maxVelocity > minVelocity, 'maxVelocity must be > minVelocity');

  /// Multiplier for trackpad pan delta.
  ///
  /// - 1.0 = default (raw delta)
  /// - 1.5 = recommended for Figma-like responsiveness
  /// - 2.0 = very fast
  ///
  /// Applied to `PointerPanZoomUpdateEvent.localPanDelta`.
  final double panSensitivity;

  /// Multiplier for scroll wheel pan delta.
  ///
  /// Separate from [panSensitivity] because scroll wheels often
  /// have different delta magnitudes than trackpad gestures.
  ///
  /// - 1.0 = default
  /// - Values < 1.0 = smoother scrolling on mice with high-resolution wheels
  final double scrollSensitivity;

  /// Whether to apply momentum/inertia when pan gesture ends.
  ///
  /// When true, the viewport continues moving after finger lift,
  /// gradually decelerating based on [friction].
  ///
  /// Defaults to false (immediate stop) for backward compatibility.
  final bool enableMomentum;

  /// Friction coefficient for momentum deceleration.
  ///
  /// Controls how quickly momentum decays. This is passed to
  /// Flutter's [FrictionSimulation].
  ///
  /// - Lower values = more friction = stops faster
  /// - Higher values = less friction = glides longer
  ///
  /// Typical values:
  /// - 0.010 = high friction (stops quickly)
  /// - 0.015 = default (balanced)
  /// - 0.025 = low friction (long glide, like iOS)
  ///
  /// Must be in range (0, 1).
  final double friction;

  /// Minimum velocity (pixels/sec) floor for momentum glide.
  ///
  /// When momentum is enabled, this acts as a floor (not a gate):
  /// - If release velocity >= minVelocity: use release velocity
  /// - If release velocity < minVelocity but gesture moved: use minVelocity
  ///
  /// This ensures even slow/short pans get a small inertial tail (Figma-like).
  ///
  /// Default: 50.0 pixels/second
  final double minVelocity;

  /// Maximum velocity (pixels/sec) for momentum animation.
  ///
  /// Caps the initial momentum velocity to prevent wild flings.
  ///
  /// Default: 8000.0 pixels/second
  final double maxVelocity;

  //─────────────────────────────────────────────────────────────────────────────
  // Presets
  //─────────────────────────────────────────────────────────────────────────────

  /// Default: no momentum, standard sensitivity.
  ///
  /// Matches current behavior for backward compatibility.
  static const defaults = CanvasMomentumConfig();

  /// Figma-like feel: quicker pan, smooth momentum on all gestures.
  ///
  /// Recommended for design tools and creative apps.
  /// Uses a very low minVelocity so even light/short pans get momentum.
  static const figmaLike = CanvasMomentumConfig(
    panSensitivity: 1.8,
    scrollSensitivity: 1.2,
    enableMomentum: true,
    friction: 0.012,
    minVelocity: 5,
  );

  /// iOS-like feel: light friction, long glide.
  ///
  /// Good for content browsing and exploration.
  static const smooth = CanvasMomentumConfig(
    panSensitivity: 1.3,
    enableMomentum: true,
    friction: 0.012,
    minVelocity: 80.0,
  );

  /// Precise control: no momentum, slightly boosted sensitivity.
  ///
  /// Good for technical/precision work.
  static const precise = CanvasMomentumConfig(
    panSensitivity: 1.2,
    enableMomentum: false,
  );

  //─────────────────────────────────────────────────────────────────────────────
  // Helpers
  //─────────────────────────────────────────────────────────────────────────────

  /// Clamp velocity to configured bounds (max only, no min gate).
  Offset clampVelocity(Offset velocity) {
    final magnitude = velocity.distance;
    if (magnitude > maxVelocity) {
      return velocity * (maxVelocity / magnitude);
    }
    return velocity;
  }

  /// Apply velocity floor: if velocity is below [minVelocity] but we have
  /// a fallback direction, use [minVelocity] in that direction.
  ///
  /// This ensures all pans get at least a small glide (Figma-like behavior).
  Offset applyVelocityFloor(
    Offset velocity, {
    required Offset fallbackDirection,
  }) {
    final magnitude = velocity.distance;

    // Already above floor - just clamp to max
    if (magnitude >= minVelocity) {
      return clampVelocity(velocity);
    }

    // Below floor - use minVelocity in the best available direction
    Offset direction;
    if (magnitude > 0.0001) {
      // Use velocity direction if available
      direction = velocity / magnitude;
    } else if (fallbackDirection.distance > 0.0001) {
      // Use fallback direction (e.g., last non-zero velocity)
      direction = fallbackDirection / fallbackDirection.distance;
    } else {
      // No direction available - can't apply momentum
      return Offset.zero;
    }

    return direction * minVelocity;
  }

  /// Check if momentum should be applied for a trackpad gesture.
  ///
  /// For trackpad gestures, momentum is applied if:
  /// - [enableMomentum] is true, AND
  /// - The gesture actually moved ([hadPan] is true), OR velocity is non-zero
  ///
  /// This differs from velocity-only checks because trackpad gestures often
  /// end with deceleration frames that zero out the velocity.
  bool shouldApplyMomentum(Offset velocity, {bool hadPan = false}) {
    if (!enableMomentum) return false;
    if (hadPan) return true; // Any pan gets momentum
    return velocity.distance > 0.0001;
  }

  //─────────────────────────────────────────────────────────────────────────────
  // copyWith / equality
  //─────────────────────────────────────────────────────────────────────────────

  /// Create a copy with modified values.
  CanvasMomentumConfig copyWith({
    double? panSensitivity,
    double? scrollSensitivity,
    bool? enableMomentum,
    double? friction,
    double? minVelocity,
    double? maxVelocity,
  }) {
    return CanvasMomentumConfig(
      panSensitivity: panSensitivity ?? this.panSensitivity,
      scrollSensitivity: scrollSensitivity ?? this.scrollSensitivity,
      enableMomentum: enableMomentum ?? this.enableMomentum,
      friction: friction ?? this.friction,
      minVelocity: minVelocity ?? this.minVelocity,
      maxVelocity: maxVelocity ?? this.maxVelocity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasMomentumConfig &&
          runtimeType == other.runtimeType &&
          panSensitivity == other.panSensitivity &&
          scrollSensitivity == other.scrollSensitivity &&
          enableMomentum == other.enableMomentum &&
          friction == other.friction &&
          minVelocity == other.minVelocity &&
          maxVelocity == other.maxVelocity;

  @override
  int get hashCode => Object.hash(
    panSensitivity,
    scrollSensitivity,
    enableMomentum,
    friction,
    minVelocity,
    maxVelocity,
  );
}
