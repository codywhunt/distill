/// Utility functions for comparing collections by value.
///
/// These are used throughout the Free Design module for implementing
/// equality checks in immutable data classes.

/// Compares two lists for value equality.
///
/// Returns true if both lists have the same length and all elements
/// at corresponding indices are equal.
bool listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Compares two maps for value equality.
///
/// Returns true if both maps have the same keys and all values
/// for corresponding keys are equal.
bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
