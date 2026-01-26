/// Flutter Integration: Provider Setup
///
/// Provides ECS World and CommandExecutor to the widget tree.

import 'package:flutter/material.dart';

import '../core/world.dart';
import '../core/commands.dart';
import '../core/events.dart';

/// Provides ECS dependencies to the widget tree
class EcsProvider extends InheritedWidget {
  final World world;
  final EventStore events;
  final CommandExecutor commands;

  EcsProvider({
    super.key,
    required this.world,
    required this.events,
    required this.commands,
    required super.child,
  });

  /// Create with default instances
  factory EcsProvider.create({
    required Widget child,
    World? world,
  }) {
    final w = world ?? World();
    final e = EventStore();
    final c = CommandExecutor(w, e);
    return EcsProvider(
      world: w,
      events: e,
      commands: c,
      child: child,
    );
  }

  static EcsProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<EcsProvider>();
    assert(provider != null, 'No EcsProvider found in context');
    return provider!;
  }

  static World worldOf(BuildContext context) => of(context).world;
  static CommandExecutor commandsOf(BuildContext context) => of(context).commands;
  static EventStore eventsOf(BuildContext context) => of(context).events;

  @override
  bool updateShouldNotify(EcsProvider oldWidget) {
    return world != oldWidget.world ||
        events != oldWidget.events ||
        commands != oldWidget.commands;
  }
}

/// Widget that rebuilds when the ECS world changes
class EcsBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, World world, CommandExecutor commands) builder;

  const EcsBuilder({
    super.key,
    required this.builder,
  });

  @override
  State<EcsBuilder> createState() => _EcsBuilderState();
}

class _EcsBuilderState extends State<EcsBuilder> {
  late CommandExecutor _commands;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _commands = EcsProvider.commandsOf(context);
    _commands.addListener(_onWorldChanged);
  }

  @override
  void dispose() {
    _commands.removeListener(_onWorldChanged);
    super.dispose();
  }

  void _onWorldChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = EcsProvider.of(context);
    return widget.builder(context, provider.world, provider.commands);
  }
}

/// Hook-like helper for accessing ECS in callbacks
mixin EcsMixin<T extends StatefulWidget> on State<T> {
  World get world => EcsProvider.worldOf(context);
  CommandExecutor get commands => EcsProvider.commandsOf(context);
  EventStore get events => EcsProvider.eventsOf(context);
}
