# Infinite Canvas Examples

This directory contains example applications demonstrating the Infinite Canvas package.

## Running the Examples

```bash
cd example
flutter run -d chrome  # or macos, windows, linux
```

## Examples Included

### Free Design Canvas

A basic design canvas demonstrating:

- Drag-to-move objects
- Tap-to-select
- Multi-selection
- Resize handles
- Smart snapping with guides

### Layout Lab

A graph layout laboratory demonstrating:

- Force-directed layout algorithm
- Hierarchical layout algorithm
- Tree layout algorithm
- Edge routing (straight, curved, orthogonal)
- Real-time layout animation

### Storyboard

A storyboard editor demonstrating:

- Grid-based card layout
- Connections between cards
- Zoom-based level of detail
- Focus-on-card navigation

### App Preview

A device preview demonstrating:

- Single-object focus
- Bounded panning
- Device frame selection
- Fit-to-content on device change

## Project Structure

```
example/
├── lib/
│   ├── main.dart              # App entry point and navigation
│   ├── examples/
│   │   ├── free_design/       # Free design canvas example
│   │   ├── layout_lab/        # Graph layout example
│   │   ├── storyboard/        # Storyboard editor example
│   │   └── app_preview/       # Device preview example
│   └── shared/
│       ├── theme.dart         # Shared visual theme
│       └── widgets/           # Shared UI components
└── pubspec.yaml
```
