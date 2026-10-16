import 'dart:convert';

/// Which party may choose a registered component in the connected experience.
enum ModelUiAvailability { modelSelectable, hostControlled, referenceOnly }

/// A renderer-independent copy of one actual renderer catalog registration.
class ModelUiCatalogEntry {
  ModelUiCatalogEntry({
    required this.name,
    required Map<String, Object?> schema,
    required this.guidance,
    required this.availability,
  }) : schema = _freeze(schema) as Map<String, Object?>;

  final String name;
  final Map<String, Object?> schema;
  final String guidance;
  final ModelUiAvailability availability;

  Map<String, Object?> toJson() => {
    'name': name,
    'schema': schema,
    'availability': availability.name,
    'guidance': guidance,
  };
}

/// Injected at composition: domain/runtime never imports a renderer SDK.
class ModelUiCatalog {
  ModelUiCatalog({
    required this.catalogId,
    required List<ModelUiCatalogEntry> entries,
    required List<String> instructions,
    required Map<String, Object?> actionSchema,
  }) : entries = List.unmodifiable(entries),
       instructions = List.unmodifiable(instructions),
       actionSchema = _freeze(actionSchema) as Map<String, Object?> {
    if (entries.map((entry) => entry.name).toSet().length != entries.length) {
      throw ArgumentError('UI catalog component names must be unique.');
    }
  }

  final String catalogId;
  final List<ModelUiCatalogEntry> entries;
  final List<String> instructions;
  final Map<String, Object?> actionSchema;

  List<String> get modelSelectableComponents => [
    for (final entry in entries)
      if (entry.availability == ModelUiAvailability.modelSelectable) entry.name,
  ];

  Map<String, Object?> toJson() => {
    'catalogId': catalogId,
    'instructions': instructions,
    'components': [for (final entry in entries) entry.toJson()],
    'hostActionSchema': actionSchema,
  };

  String get modelInstructions =>
      'UI catalog (the same schemas used by the Flutter renderer): '
      '${jsonEncode(toJson())}\n'
      'Choose a modelSelectable component with present_products.component. '
      'ProductCard shows individual recommendations; ThisOrThat compares exactly two; '
      'PicksStrip is a compact shortlist of one to five; AlternativePiece shows exactly '
      'one replacement while a selected piece is being adjusted. '
      'The host supplies all facts, bindings and actions and validates eligibility. '
      'HostControlled components appear only when host state permits. ReferenceOnly '
      'components are available in the learning gallery, not as live tool choices. '
      'Catalog action schemas describe host controls, not permission for a model '
      'to change a bag, submit checkout or bypass user confirmation. '
      'Do not emit arbitrary A2UI, properties, prices, action contexts or markup.';
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freeze(entry.value),
    });
  }
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  return value;
}
