# Gesture Handling Guide

This guide covers gesture handling in InfiniteCanvas, including the tap/double-tap latency tradeoff, the `shouldHandleScroll` callback, and configuration options.

## Tap vs Double-Tap Latency

When both `onTapWorld` and `onDoubleTapWorld` are configured, there is an inherent **~300ms delay** before `onTapWorld` fires. This is a Flutter gesture system behavior, not specific to InfiniteCanvas.

### Why the Delay Exists

The gesture system must wait to determine if a second tap will follow:

```
User taps        ─────────────────────────────────────────────>
                 │
                 │ Tap #1 detected
                 │
                 ├─── Wait ~300ms for possible second tap ───┤
                 │                                            │
                 │                                            ├── No second tap: fire onTapWorld
                 │                                            │
                 └── Second tap detected: fire onDoubleTapWorld
```

### Workarounds

#### Option 1: Use Only onTapWorld

If double-tap isn't needed, omit `onDoubleTapWorld`. Single taps will fire immediately:

```dart
InfiniteCanvas(
  onTapWorld: (worldPos) {
    // Fires immediately!
    handleTap(worldPos);
  },
  // Don't define onDoubleTapWorld
  layers: ...,
)
```

#### Option 2: Use Raw Pointer Events

Wrap the canvas in a `Listener` and handle `onPointerDown` directly. You'll need to implement your own double-tap detection:

```dart
class _CanvasWrapperState extends State<CanvasWrapper> {
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;

  void _handlePointerDown(PointerDownEvent event) {
    final now = DateTime.now();
    final position = event.localPosition;

    // Check for double-tap
    if (_lastTapTime != null &&
        _lastTapPosition != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300 &&
        (position - _lastTapPosition!).distance < 20) {
      // Double-tap detected
      _handleDoubleTap(position);
      _lastTapTime = null;
      _lastTapPosition = null;
    } else {
      // Single tap (fires immediately)
      _handleSingleTap(position);
      _lastTapTime = now;
      _lastTapPosition = position;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      child: InfiniteCanvas(
        // Don't use onTapWorld/onDoubleTapWorld
        layers: ...,
      ),
    );
  }
}
```

#### Option 3: Accept the Latency

For many use cases, 300ms is acceptable. Selection, object inspection, and similar interactions work fine with this delay.

## shouldHandleScroll Callback

The `shouldHandleScroll` callback allows conditional scroll/zoom handling based on cursor position.

### Use Case: Nested Scrollables

When content inside canvas items needs to scroll independently:

```dart
InfiniteCanvas(
  shouldHandleScroll: (viewPosition) {
    // Convert to world coordinates
    final worldPos = controller.viewToWorld(viewPosition);

    // Check if over interactive content
    final hitFrame = hitTestFrame(worldPos);

    if (hitFrame != null && hitFrame.isInInteractMode) {
      return false;  // Let frame content handle scroll
    }

    return true;  // Canvas handles scroll (pan/zoom)
  },
  layers: ...,
)
```

### Behavior Matrix

| `shouldHandleScroll` | Effect |
|----------------------|--------|
| Returns `true` | Canvas handles scroll (pan via scroll, zoom via Cmd+scroll) |
| Returns `false` | Event propagates to children (nested scrollables can handle it) |
| Not provided (`null`) | Canvas always handles scroll |

### Events Affected

The callback applies to:

- **PointerScrollEvent** - Mouse wheel, trackpad two-finger scroll
- **PointerScaleEvent** - Trackpad pinch zoom (on web)

### Example: Region-Based Handling

Handle scroll only in certain areas of the canvas:

```dart
InfiniteCanvas(
  shouldHandleScroll: (viewPosition) {
    // Don't handle scroll in the right sidebar area
    if (viewPosition.dx > viewportWidth - 300) {
      return false;
    }
    return true;
  },
)
```

## Gesture Configuration

Use `CanvasGestureConfig` to customize gesture behavior:

```dart
InfiniteCanvas(
  gestureConfig: const CanvasGestureConfig(
    enablePan: true,         // Allow drag-to-pan
    enableZoom: true,        // Allow scroll/pinch zoom
    enableSpacebarPan: true, // Spacebar + drag to pan
    enableMiddleMousePan: true, // Middle mouse drag to pan
    enableScrollPan: true,   // Scroll wheel pans (when not zooming)
    naturalScrolling: true,  // Invert scroll direction (macOS style)
    dragThreshold: 5.0,      // Pixels before drag starts (mouse)
    hoverThrottleMs: 16,     // Throttle hover events
  ),
)
```

### Presets

```dart
// All gestures enabled (default)
CanvasGestureConfig.all

// All gestures disabled
CanvasGestureConfig.none

// Only zoom (no pan)
CanvasGestureConfig.zoomOnly

// Only pan (no zoom)
CanvasGestureConfig.panOnly
```

### Drag Threshold by Input Type

The drag threshold differs by input device to account for touch imprecision:

| Device | Default Threshold |
|--------|-------------------|
| Mouse | 5.0 logical pixels |
| Touch | 7.5 logical pixels (1.5× mouse) |
| Stylus | 7.5 logical pixels (1.5× mouse) |
| Trackpad | 5.0 logical pixels |

Customize with `touchDragThreshold`:

```dart
const CanvasGestureConfig(
  dragThreshold: 5.0,      // Mouse threshold
  touchDragThreshold: 15.0, // Touch threshold (override 1.5× default)
)
```

## Motion State Notifiers

Track gesture states for UI feedback or LOD optimization:

```dart
// Individual states
controller.isPanning.addListener(() {
  print('Panning: ${controller.isPanning.value}');
});

controller.isZooming.addListener(() {
  print('Zooming: ${controller.isZooming.value}');
});

controller.isAnimating.addListener(() {
  print('Animating: ${controller.isAnimating.value}');
});

controller.isDecelerating.addListener(() {
  print('Decelerating: ${controller.isDecelerating.value}');
});

// Combined (any motion)
controller.isInMotionListenable.addListener(() {
  final inMotion = controller.isPanning.value ||
      controller.isZooming.value ||
      controller.isAnimating.value ||
      controller.isDecelerating.value;
  print('In motion: $inMotion');
});
```

## Momentum Configuration

Configure momentum (inertial scrolling) behavior:

```dart
InfiniteCanvas(
  momentumConfig: const CanvasMomentumConfig(
    enableMomentum: true,    // Enable momentum
    friction: 0.015,         // Decay rate (higher = faster stop)
    minVelocity: 50.0,       // Velocity threshold to trigger
    maxVelocity: 8000.0,     // Cap initial velocity
    panSensitivity: 1.0,     // Trackpad pan multiplier
    scrollSensitivity: 1.0,  // Scroll wheel multiplier
  ),
)
```

### Presets

```dart
// No momentum (default, backward compatible)
CanvasMomentumConfig.defaults

// Figma-like (momentum on all gestures)
CanvasMomentumConfig.figmaLike

// iOS-like smooth scrolling
CanvasMomentumConfig.smooth

// Precise, no momentum
CanvasMomentumConfig.precise
```

## Input Device Handling

The canvas automatically adjusts behavior for different input devices:

| Input | Pan | Zoom | Momentum |
|-------|-----|------|----------|
| Mouse drag | ✓ | — | Via quick release |
| Mouse wheel | ✓ (scroll) | ✓ (Cmd+scroll) | — |
| Touch drag | ✓ | — | Via quick release |
| Touch pinch | — | ✓ | — |
| Trackpad scroll | ✓ | — | ✓ (filtered velocity) |
| Trackpad pinch | — | ✓ | — |
| Spacebar + drag | ✓ | — | Via quick release |
| Middle mouse | ✓ | — | Via quick release |

### Trackpad Velocity Filtering

Trackpad gestures use a low-pass filter for velocity to handle macOS's gesture deceleration frames:

```
User gesture    ─────────────────────────────────────────────>
                │   Fast movement                  │ OS deceleration
                │   v=1000 px/s                    │ v drops suddenly
                │                                  │
Raw velocity    ████████████████████████████████████░░░░░░░░░░
Filtered        ████████████████████████████████████████░░░░░░
                                                   ^
                                                   │
                              Filtered velocity captures
                              user's actual intent
```

This ensures momentum reflects the user's actual gesture velocity, not the OS deceleration.

## Summary

| Topic | Key Points |
|-------|------------|
| Tap/double-tap | ~300ms delay when both are configured; use raw pointers for instant taps |
| shouldHandleScroll | Return `false` to let nested scrollables handle events |
| Config presets | `all`, `none`, `zoomOnly`, `panOnly` |
| Motion states | `isPanning`, `isZooming`, `isAnimating`, `isDecelerating` |
| Momentum | Use `CanvasMomentumConfig.figmaLike` for Figma-like feel |
