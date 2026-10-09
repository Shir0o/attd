/// Finds the value of [values] whose [Enum.name] matches [name], or `null` if
/// [name] is null or unrecognized.
T? enumByNameOrNull<T extends Enum>(Iterable<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}
