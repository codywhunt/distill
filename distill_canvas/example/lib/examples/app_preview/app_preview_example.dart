import 'package:flutter/material.dart';
import 'package:distill_canvas/infinite_canvas.dart';

import '../../shared/theme.dart';
import '../../shared/ui.dart';

/// App Preview Example
///
/// Demonstrates single-object viewing with zoom inspection.
/// Canvas features: InitialViewport.fitRect, focusOn, discrete zoom levels
class AppPreviewExample extends StatefulWidget {
  const AppPreviewExample({super.key});

  @override
  State<AppPreviewExample> createState() => _AppPreviewExampleState();
}

class _AppPreviewExampleState extends State<AppPreviewExample> {
  final _controller = InfiniteCanvasController();
  DeviceFrame _selectedDevice = DeviceFrame.iPhone14;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Rect get _deviceBounds => Rect.fromLTWH(
    0,
    0,
    _selectedDevice.size.width,
    _selectedDevice.size.height,
  );

  /// Pan bounds with margin around the device frame.
  /// Prevents panning infinitely into the void.
  Rect get _panBounds => _deviceBounds.inflate(200);

  void _fitToDevice() {
    _controller.focusOn(_deviceBounds, padding: const EdgeInsets.all(48));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        const ExampleHeader(
          title: 'App Preview',
          description: 'single-object viewing with bounded pan',
          features: ['fitRect', 'focusOn', 'panBounds'],
        ),

        // Toolbar
        Toolbar(
          children: [
            // Device selector
            DropdownSelector<DeviceFrame>(
              value: _selectedDevice,
              items: DeviceFrame.values,
              onChanged: (device) {
                setState(() => _selectedDevice = device);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _fitToDevice();
                });
              },
              itemBuilder:
                  (device) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(device.icon, size: 13),
                      const SizedBox(width: 6),
                      Text(device.label),
                    ],
                  ),
            ),
            const Spacer(),
            // Zoom controls
            ListenableBuilder(
              listenable: _controller,
              builder:
                  (context, _) => ZoomControls(
                    zoom: _controller.zoom,
                    onZoomChanged: (zoom) => _controller.setZoom(zoom),
                    onFitPressed: _fitToDevice,
                  ),
            ),
          ],
        ),

        // Canvas
        Expanded(
          child: InfiniteCanvas(
            controller: _controller,
            backgroundColor: AppTheme.background,
            initialViewport: InitialViewport.fitRect(
              _deviceBounds,
              padding: const EdgeInsets.all(48),
            ),
            physicsConfig: CanvasPhysicsConfig(
              minZoom: 0.1,
              maxZoom: 4.0,
              panBounds: _panBounds,
            ),
            layers: CanvasLayers(
              background: (ctx, ctrl) => const SizedBox.shrink(),
              content:
                  (ctx, ctrl) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CanvasItem(
                        position: Offset.zero,
                        child: _DeviceFrameWidget(
                          device: _selectedDevice,
                          child: _MockAppContent(device: _selectedDevice),
                        ),
                      ),
                    ],
                  ),
              overlay:
                  (ctx, ctrl) => _FrameLabel(
                    label: _selectedDevice.label,
                    worldBounds: _deviceBounds,
                    controller: ctrl,
                  ),
            ),
            onDoubleTapWorld: (_) => _fitToDevice(),
          ),
        ),

        // Status bar
        ListenableBuilder(
          listenable: _controller,
          builder:
              (context, _) => StatusBar(
                children: [
                  StatusItem(label: '${(_controller.zoom * 100).round()}%'),
                  StatusItem(
                    label:
                        '${_selectedDevice.size.width.round()}×${_selectedDevice.size.height.round()}',
                  ),
                  const Spacer(),
                  const StatusItem(
                    label: 'bounded pan  dbl-click: fit  scroll: zoom',
                  ),
                ],
              ),
        ),
      ],
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Device Frames
//─────────────────────────────────────────────────────────────────────────────

enum DeviceFrame {
  iPhone14('iPhone 14', Size(390, 844), Icons.phone_iphone, 47, 34),
  iPhone14Pro('iPhone 14 Pro', Size(393, 852), Icons.phone_iphone, 59, 34),
  iPhoneSE('iPhone SE', Size(375, 667), Icons.phone_iphone, 0, 0),
  pixel7('Pixel 7', Size(412, 915), Icons.phone_android, 24, 0),
  iPadMini('iPad Mini', Size(744, 1133), Icons.tablet_mac, 0, 0),
  custom('Custom', Size(400, 700), Icons.crop_square, 0, 0);

  const DeviceFrame(
    this.label,
    this.size,
    this.icon,
    this.notchHeight,
    this.notchWidth,
  );

  final String label;
  final Size size;
  final IconData icon;
  final double notchHeight;
  final double notchWidth;

  bool get hasNotch => notchHeight > 0;
}

//─────────────────────────────────────────────────────────────────────────────
// Frame Label (Overlay)
//─────────────────────────────────────────────────────────────────────────────

/// Figma-style frame label that appears above the device.
/// Rendered in screen-space but anchored to world-space bounds.
class _FrameLabel extends StatelessWidget {
  const _FrameLabel({
    required this.label,
    required this.worldBounds,
    required this.controller,
  });

  final String label;
  final Rect worldBounds;
  final InfiniteCanvasController controller;

  @override
  Widget build(BuildContext context) {
    // Hide label when zoomed out too far
    if (controller.zoom < 0.15) {
      return const SizedBox.shrink();
    }

    // Convert world bounds to screen position
    final viewBounds = controller.worldToViewRect(worldBounds);

    // Scale font size inversely with zoom, clamped
    final fontSize = (10.0 / controller.zoom).clamp(9.0, 11.0);

    return Stack(
      children: [
        Positioned(
          left: viewBounds.left,
          top: viewBounds.top - 18,
          child: Text(
            label.toLowerCase(),
            style: TextStyle(
              fontSize: fontSize,
              fontFamily: AppTheme.fontMono,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSubtle,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Device Frame Widget
//─────────────────────────────────────────────────────────────────────────────

class _DeviceFrameWidget extends StatelessWidget {
  const _DeviceFrameWidget({required this.device, required this.child});

  final DeviceFrame device;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: device.size.width + 16,
      height: device.size.height + 16,
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF27272A), width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF0A0A0C),
          child: Stack(
            children: [
              // Screen content
              Positioned.fill(child: child),

              // Notch/Dynamic Island
              if (device.hasNotch)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width:
                          device.notchWidth > 0
                              ? 120
                              : device.size.width * 0.35,
                      height: device.notchHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A0A0C),
                        borderRadius:
                            device.notchWidth > 0
                                ? BorderRadius.circular(16)
                                : const BorderRadius.vertical(
                                  bottom: Radius.circular(16),
                                ),
                      ),
                    ),
                  ),
                ),

              // Home indicator
              if (device != DeviceFrame.iPhoneSE)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3F3F46),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

//─────────────────────────────────────────────────────────────────────────────
// Mock App Content
//─────────────────────────────────────────────────────────────────────────────

class _MockAppContent extends StatelessWidget {
  const _MockAppContent({required this.device});
  final DeviceFrame device;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0C0C0E),
      child: Column(
        children: [
          // Status bar area
          SizedBox(height: device.hasNotch ? device.notchHeight + 8 : 20),

          // App bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF27272A),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.menu,
                    size: 14,
                    color: Color(0xFF71717A),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE4E4E7),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF27272A),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Stats row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(child: _StatCard(label: 'Tasks', value: '12')),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(label: 'Done', value: '8')),
                const SizedBox(width: 8),
                Expanded(child: _StatCard(label: 'Hours', value: '24')),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Section title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(
                  'Recent',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFA1A1AA),
                    letterSpacing: 0.3,
                  ),
                ),
                Spacer(),
                Text(
                  'view all',
                  style: TextStyle(fontSize: 10, color: Color(0xFF52525B)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // List items
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF111113),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF1C1C1F),
                    width: 0.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        [
                          Icons.folder_outlined,
                          Icons.image_outlined,
                          Icons.description_outlined,
                          Icons.code,
                        ][i],
                        color: const Color(0xFF52525B),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            [
                              'project-files',
                              'design-assets',
                              'documentation',
                              'source-code',
                            ][i],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFFE4E4E7),
                            ),
                          ),
                          Text(
                            ['12 items', '8 items', '5 items', '24 files'][i],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF52525B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF3F3F46),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Spacer(),

          // Bottom nav
          Container(
            height: 48,
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF111113),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1C1C1F), width: 0.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(icon: Icons.home_outlined, isActive: true),
                _NavItem(icon: Icons.search),
                _NavItem(icon: Icons.add),
                _NavItem(icon: Icons.grid_view_outlined),
                _NavItem(icon: Icons.settings_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111113),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1C1C1F), width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              fontFamily: AppTheme.fontMono,
              color: Color(0xFFE4E4E7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF52525B),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, this.isActive = false});
  final IconData icon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 18,
      color: isActive ? const Color(0xFFA1A1AA) : const Color(0xFF3F3F46),
    );
  }
}
