import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Offset, Size;

/// Represents a page/screen in the project.
///
/// Pages are the primary content units that users create and edit.
/// They can be viewed in a grid, storyboard, or individual edit view.
@immutable
class PageModel {
  const PageModel({
    required this.id,
    required this.name,
    this.description,
    this.canvasSize = const Size(375, 812), // iPhone size default
    this.storyboardPosition = Offset.zero,
    this.pinnedPosition,
    required this.createdAt,
    required this.updatedAt,
    this.connectsTo = const [],
  });

  /// Unique identifier for this page.
  final String id;

  /// Display name of the page.
  final String name;

  /// Optional description of the page's purpose.
  final String? description;

  /// The canvas size for this page (device dimensions).
  final Size canvasSize;

  /// Position in storyboard view (used as fallback if not pinned).
  final Offset storyboardPosition;

  /// If non-null, this page is "pinned" to a manual position
  /// and will not be moved by auto-layout.
  final Offset? pinnedPosition;

  /// Whether this page has been manually positioned.
  bool get isPinned => pinnedPosition != null;

  /// When this page was created.
  final DateTime createdAt;

  /// When this page was last modified.
  final DateTime updatedAt;

  /// IDs of pages this page links to (for storyboard connections).
  /// Stubbed for future implementation.
  final List<String> connectsTo;

  /// Creates a copy with updated fields.
  ///
  /// Note: To clear [pinnedPosition], pass [clearPinnedPosition] as true.
  PageModel copyWith({
    String? id,
    String? name,
    String? description,
    Size? canvasSize,
    Offset? storyboardPosition,
    Offset? pinnedPosition,
    bool clearPinnedPosition = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? connectsTo,
  }) {
    return PageModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      canvasSize: canvasSize ?? this.canvasSize,
      storyboardPosition: storyboardPosition ?? this.storyboardPosition,
      pinnedPosition: clearPinnedPosition
          ? null
          : (pinnedPosition ?? this.pinnedPosition),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      connectsTo: connectsTo ?? this.connectsTo,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PageModel &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.canvasSize == canvasSize &&
        other.storyboardPosition == storyboardPosition &&
        other.pinnedPosition == pinnedPosition &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        listEquals(other.connectsTo, connectsTo);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        description,
        canvasSize,
        storyboardPosition,
        pinnedPosition,
        createdAt,
        updatedAt,
        Object.hashAll(connectsTo),
      );
}
