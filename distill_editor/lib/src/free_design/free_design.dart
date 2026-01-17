/// Free Design DSL - Figma-like visual editing for Hologram.
///
/// This library provides:
/// - **Editor IR**: The source of truth data model for designs
/// - **Patch Protocol**: Atomic, invertible operations for editing
/// - **Store**: State management with change tracking
///
/// ## Quick Start
///
/// ```dart
/// import 'package:hologram/src/free_design/free_design.dart';
///
/// // Create a store with an empty document
/// final store = EditorDocumentStore.empty();
///
/// // Create a node
/// final node = Node(
///   id: 'n_button',
///   name: 'Submit Button',
///   type: NodeType.container,
///   props: ContainerProps(),
///   layout: NodeLayout(
///     size: SizeMode.fixed(width: 120, height: 40),
///   ),
///   style: NodeStyle(
///     fill: SolidFill(HexColor('#007AFF')),
///     cornerRadius: CornerRadius.all(8),
///   ),
/// );
///
/// // Add to document via patch
/// store.applyPatch(InsertNode(node));
/// ```
library;

export 'ai/ai.dart';
export 'canvas/canvas.dart';
export 'compiler/compiler.dart';
export 'dsl/dsl.dart';
export 'layout/layout.dart';
export 'models/models.dart';
export 'patch/patch.dart';
export 'projection/projection.dart';
export 'render/render.dart';
export 'scene/scene.dart';
export 'store/store.dart';
