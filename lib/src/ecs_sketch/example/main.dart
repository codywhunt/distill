/// Example: Using the ECS Architecture
///
/// This demonstrates how to build a simple design editor with the ECS pattern.

import 'dart:ui';

import 'package:flutter/material.dart' hide TextStyle;

import '../ecs.dart';

void main() {
  runApp(const EcsExampleApp());
}

class EcsExampleApp extends StatelessWidget {
  const EcsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECS Design Editor',
      theme: ThemeData.dark(),
      home: const EditorScreen(),
    );
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final World _world;
  late final EventStore _events;
  late final CommandExecutor _commands;

  @override
  void initState() {
    super.initState();
    _world = World();
    _events = EventStore();
    _commands = CommandExecutor(_world, _events);

    // Create initial document
    _createSampleDocument();
  }

  void _createSampleDocument() {
    // ─────────────────────────────────────────────────────────────────────
    // Create a frame (artboard)
    // ─────────────────────────────────────────────────────────────────────
    final frame = _world.entity()
        .withName('Frame 1')
        .withSize(800, 600)
        .withFill(const Color(0xFFFFFFFF))
        .asFrame(canvasX: 100, canvasY: 100)
        .build();

    // ─────────────────────────────────────────────────────────────────────
    // Create a card container with auto-layout
    // ─────────────────────────────────────────────────────────────────────
    final card = _world.entity()
        .withName('Card')
        .withPosition(50, 50)
        .withSize(300, 200)
        .withFill(const Color(0xFFF5F5F5))
        .withCornerRadius(12)
        .withParent(frame)
        .withAutoLayout(
          direction: LayoutDirection.vertical,
          gap: 16,
          padding: EdgePadding.all(20),
        )
        .build();

    // Add shadow to card
    _world.shadows.set(card, const Shadows([
      Shadow(
        color: Color(0x1A000000),
        offsetY: 4,
        blur: 12,
      ),
    ]));

    // ─────────────────────────────────────────────────────────────────────
    // Create card content
    // ─────────────────────────────────────────────────────────────────────

    // Title
    _world.entity()
        .withName('Title')
        .withPosition(0, 0)
        .withSize(260, 24)
        .withText('Welcome to ECS', style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ))
        .withParent(card)
        .build();

    // Subtitle
    _world.entity()
        .withName('Subtitle')
        .withPosition(0, 0)
        .withSize(260, 40)
        .withText('A minimal Entity Component System architecture for design editors.', style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF666666),
        ))
        .withParent(card)
        .build();

    // Button
    final button = _world.entity()
        .withName('Button')
        .withPosition(0, 0)
        .withSize(120, 40)
        .withFill(const Color(0xFF0066FF))
        .withCornerRadius(8)
        .withParent(card)
        .build();

    _world.entity()
        .withName('Button Text')
        .withPosition(0, 10)
        .withSize(120, 20)
        .withText('Get Started', style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
        ))
        .withParent(button)
        .build();

    // ─────────────────────────────────────────────────────────────────────
    // Create some standalone shapes
    // ─────────────────────────────────────────────────────────────────────

    // Blue rectangle
    _world.entity()
        .withName('Rectangle')
        .withPosition(400, 100)
        .withSize(150, 100)
        .withFill(const Color(0xFF4A90D9))
        .withStroke(const Color(0xFF2D5A87), 2)
        .withCornerRadius(8)
        .withParent(frame)
        .build();

    // Green rectangle
    _world.entity()
        .withName('Green Box')
        .withPosition(400, 250)
        .withSize(100, 100)
        .withFill(const Color(0xFF4AD97A))
        .withParent(frame)
        .build();

    // Orange rectangle with opacity
    final orange = _world.entity()
        .withName('Orange Box')
        .withPosition(450, 300)
        .withSize(100, 100)
        .withFill(const Color(0xFFD9944A))
        .withOpacity(0.8)
        .withParent(frame)
        .build();

    // ─────────────────────────────────────────────────────────────────────
    // Create a second frame
    // ─────────────────────────────────────────────────────────────────────
    final frame2 = _world.entity()
        .withName('Frame 2')
        .withSize(400, 300)
        .withFill(const Color(0xFFF0F0F0))
        .asFrame(canvasX: 1000, canvasY: 100)
        .build();

    _world.entity()
        .withName('Circle')
        .withPosition(150, 100)
        .withSize(100, 100)
        .withFill(const Color(0xFFE91E63))
        .withCornerRadius(50) // Makes it a circle
        .withParent(frame2)
        .build();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ECS Design Editor'),
        actions: [
          // Undo button
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _commands.canUndo ? () => setState(() => _commands.undo()) : null,
          ),
          // Redo button
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _commands.canRedo ? () => setState(() => _commands.redo()) : null,
          ),
          const SizedBox(width: 16),
          // Add rectangle button
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Rectangle'),
            onPressed: _addRectangle,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Left panel: Entity list
          SizedBox(
            width: 250,
            child: _buildEntityList(),
          ),
          // Main canvas
          Expanded(
            child: EcsCanvas(
              world: _world,
              commands: _commands,
            ),
          ),
          // Right panel: Properties (placeholder)
          SizedBox(
            width: 250,
            child: _buildPropertiesPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityList() {
    return Container(
      color: const Color(0xFF2D2D2D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Entities',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _world.entities.length,
              itemBuilder: (context, index) {
                final entity = _world.entities.elementAt(index);
                final name = _world.name.get(entity)?.value ?? 'Entity $entity';
                final isFrame = _world.frame.has(entity);

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isFrame ? Icons.crop_landscape : Icons.square,
                    size: 16,
                  ),
                  title: Text(name),
                  subtitle: Text('ID: $entity'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertiesPanel() {
    return Container(
      color: const Color(0xFF2D2D2D),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Properties',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Select an entity\nto view properties',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addRectangle() {
    // Find first frame
    final frames = _world.frames.toList();
    if (frames.isEmpty) return;

    final frame = frames.first.$1;

    setState(() {
      _commands.grouped('add-rectangle', () {
        _world.entity()
            .withName('New Rectangle')
            .withPosition(100, 100)
            .withSize(100, 80)
            .withFill(const Color(0xFF9C27B0))
            .withCornerRadius(4)
            .withParent(frame)
            .build();
      });
    });
  }
}
