/// Immutable stored-state envelope. Catalog IDs, fit, constraints and commerce
/// rules are revalidated by the host when restoring a working look.
///
/// Unknown fields and optional-field absence survive a round trip. The runtime
/// decides whether it understands a schema version before replacing any state.
class StylistSnapshot {
  StylistSnapshot._(
    this._json, {
    required this.version,
    required this.looks,
    required this.bag,
    required this.nextLookId,
  });

  factory StylistSnapshot.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final looks = json['looks'];
    final bag = json['bag'];
    final nextLookId = json['nextLookId'];
    if (version is! int ||
        looks is! List ||
        bag is! Map ||
        nextLookId is! int ||
        looks.any(
          (look) => look is! Map || look.keys.any((key) => key is! String),
        ) ||
        bag.entries.any(
          (entry) => entry.key is! String || entry.value is! int,
        )) {
      throw const FormatException('Saved styling library is invalid.');
    }
    final frozen = _freeze(json) as Map<String, Object?>;
    return StylistSnapshot._(
      frozen,
      version: version,
      looks: List.unmodifiable(
        (frozen['looks'] as List).cast<Map<String, Object?>>(),
      ),
      bag: Map.unmodifiable(Map<String, int>.from(bag)),
      nextLookId: nextLookId,
    );
  }

  final Map<String, Object?> _json;
  final int version;
  final List<Map<String, Object?>> looks;
  final Map<String, int> bag;
  final int nextLookId;

  Map<String, Object?>? get current => _json['current'] is Map<String, Object?>
      ? _json['current'] as Map<String, Object?>
      : null;

  Map<String, Object?> toJson() => _json;
}

Object? _freeze(Object? value) {
  if (value is Map) {
    if (value.keys.any((key) => key is! String)) {
      throw const FormatException('Saved styling data is invalid.');
    }
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freeze(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value == null ||
      value is String ||
      value is bool ||
      (value is num && value.isFinite)) {
    return value;
  }
  throw const FormatException('Saved styling data is invalid.');
}
