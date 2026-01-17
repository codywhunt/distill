/// The intent of a drop operation.
///
/// Determined by comparing origin parent to target parent:
/// - [none]: Invalid drop or no structural change (absolute positioning)
/// - [reorder]: Same parent, different index (sibling movement)
/// - [reparent]: Different parent (moving to another container)
enum DropIntent {
  /// No structural change - invalid drop or absolute positioned node being moved.
  none,

  /// Reordering within the same parent (sibling movement).
  reorder,

  /// Reparenting to a different container.
  reparent,
}
