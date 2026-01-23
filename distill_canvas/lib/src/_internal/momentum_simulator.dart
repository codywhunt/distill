import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import '../canvas_momentum_config.dart';

/// Callback to clamp pan position to configured bounds.
typedef PanClampCallback = Offset Function(Offset pan);

/// Handles momentum/inertia simulation for viewport panning.
///
/// This class encapsulates the friction simulation logic for momentum scrolling.
/// It manages:
/// - Starting/stopping momentum animations
/// - Friction-based deceleration using [FrictionSimulation]
/// - Boundary collision detection (stops momentum when hitting bounds)
/// - Velocity threshold detection (stops when too slow)
///
/// The simulator is created by [InfiniteCanvasController] during [attach] and
/// uses callbacks to communicate state changes back to the controller.
class MomentumSimulator {
  /// Creates a momentum simulator.
  ///
  /// All callbacks are required because the simulator delegates state management
  /// to the owning controller:
  /// - [onPanChanged]: Called with new pan position during simulation
  /// - [clampPan]: Called to clamp pan to configured bounds
  /// - [onDeceleratingChanged]: Called when deceleration state changes
  /// - [onUpdate]: Called after each pan update (triggers [notifyListeners])
  MomentumSimulator({
    required TickerProvider vsync,
    required CanvasMomentumConfig config,
    required ValueChanged<Offset> onPanChanged,
    required PanClampCallback clampPan,
    required ValueChanged<bool> onDeceleratingChanged,
    required VoidCallback onUpdate,
  })  : _vsync = vsync,
        _config = config,
        _onPanChanged = onPanChanged,
        _clampPan = clampPan,
        _onDeceleratingChanged = onDeceleratingChanged,
        _onUpdate = onUpdate;

  final TickerProvider _vsync;
  CanvasMomentumConfig _config;
  final ValueChanged<Offset> _onPanChanged;
  final PanClampCallback _clampPan;
  final ValueChanged<bool> _onDeceleratingChanged;
  final VoidCallback _onUpdate;

  AnimationController? _controller;

  /// Whether momentum simulation is currently active.
  bool get isActive => _controller != null;

  /// Update the momentum configuration.
  ///
  /// Takes effect on the next [start] or [startWithFloor] call.
  void updateConfig(CanvasMomentumConfig config) {
    _config = config;
  }

  /// Start momentum simulation with given velocity (mouse/touch).
  ///
  /// This is a simple velocity-gated momentum for mouse/touch input.
  /// Returns immediately if momentum is disabled or velocity below threshold.
  ///
  /// For trackpad gestures, use [startWithFloor] which applies a velocity
  /// floor so even slow pans get momentum.
  void start(Offset velocity, {required Offset startPan}) {
    if (!_config.enableMomentum) return;

    final clampedVelocity = _config.clampVelocity(velocity);
    if (clampedVelocity.distance < _config.minVelocity) return;

    _startSimulation(clampedVelocity, startPan);
  }

  /// Start momentum with floor-based velocity (trackpad).
  ///
  /// Unlike [start], this applies a velocity floor so even slow pans
  /// get a small inertial tail when [hadPan] is true.
  ///
  /// - [velocity]: The filtered velocity at gesture end
  /// - [startPan]: Current pan position to start from
  /// - [hadPan]: Whether the gesture actually moved the viewport
  /// - [fallbackDirection]: Direction to use if velocity is near-zero
  void startWithFloor(
    Offset velocity, {
    required Offset startPan,
    required bool hadPan,
    required Offset fallbackDirection,
  }) {
    if (!_config.shouldApplyMomentum(velocity, hadPan: hadPan)) return;

    final effectiveVelocity = _config.applyVelocityFloor(
      velocity,
      fallbackDirection: fallbackDirection,
    );
    if (effectiveVelocity == Offset.zero) return;

    _startSimulation(effectiveVelocity, startPan);
  }

  /// Cancel any in-progress momentum animation.
  void cancel() {
    if (_controller != null) {
      _controller!.stop();
      _controller!.dispose();
      _controller = null;
      _onDeceleratingChanged(false);
    }
  }

  /// Dispose resources. Call when the parent controller is disposed.
  void dispose() {
    cancel();
  }

  void _startSimulation(Offset velocity, Offset startPan) {
    cancel();

    _onDeceleratingChanged(true);

    // Create separate friction simulations for X and Y axes
    final simX = FrictionSimulation(
      _config.friction,
      startPan.dx,
      velocity.dx,
    );
    final simY = FrictionSimulation(
      _config.friction,
      startPan.dy,
      velocity.dy,
    );

    // Estimate duration based on when velocity drops below threshold
    final durationMs = _estimateDuration(velocity);
    final duration = Duration(milliseconds: durationMs.clamp(100, 2000));

    _controller = AnimationController(vsync: _vsync, duration: duration);

    _controller!.addListener(() {
      // Convert animation progress to elapsed time in seconds
      final t = _controller!.value * (duration.inMilliseconds / 1000);

      final rawPan = Offset(simX.x(t), simY.x(t));
      final clampedPan = _clampPan(rawPan);

      // Check if we hit bounds (clamping changed the position significantly)
      final hitBounds = (clampedPan - rawPan).distance > 0.001;
      if (hitBounds) {
        _onPanChanged(clampedPan);
        _onUpdate();
        cancel();
        return;
      }

      // Check if simulation velocity has dropped below threshold
      final vx = simX.dx(t);
      final vy = simY.dx(t);
      final speed = math.sqrt(vx * vx + vy * vy);
      if (speed < _config.minVelocity) {
        cancel();
        return;
      }

      _onPanChanged(clampedPan);
      _onUpdate();
    });

    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDeceleratingChanged(false);
        _controller?.dispose();
        _controller = null;
      }
    });

    _controller!.forward();
  }

  /// Estimate duration for momentum to decay below minVelocity.
  ///
  /// Uses the physics formula for friction simulation:
  /// v(t) = v0 * e^(-friction * t)
  ///
  /// Solving for t when |v(t)| = minVelocity:
  /// t = -ln(minVelocity / v0) / friction
  int _estimateDuration(Offset velocity) {
    final magnitude = velocity.distance;
    if (magnitude < _config.minVelocity) return 0;

    final ratio = _config.minVelocity / magnitude;
    if (ratio >= 1) return 0;

    final t = -math.log(ratio) / _config.friction;
    return (t * 1000).round(); // Convert to milliseconds
  }
}
