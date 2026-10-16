/// A reproducible classification of catalog text, not supplier certification.
class CatalogAttribute {
  const CatalogAttribute({
    this.value = '',
    this.basis = 'unknown',
    this.confidence = 'unknown',
    this.field = '',
    this.quote = '',
  });
  final String value, basis, confidence, field, quote;
  bool get known => value.isNotEmpty;
  Map<String, Object?> toMap() => {
    'value': known ? value : null,
    'basis': basis,
    'confidence': confidence,
    'verified': false,
    if (known) 'evidence': {'field': field, 'quote': quote},
  };
}

class ProductAttributes {
  const ProductAttributes([this.values = const {}]);
  final Map<String, CatalogAttribute> values;
  CatalogAttribute operator [](String key) =>
      values[key] ?? const CatalogAttribute();
  Map<String, Object?> toMap() => {
    for (final key in fields) key: this[key].toMap(),
  };
  static const fields = [
    'length',
    'silhouette',
    'sleeve',
    'neckline',
    'closure',
    'layering_weight',
    'formality',
    'material',
    'material_hint',
    'weather_performance',
  ];

  factory ProductAttributes.fromCatalog(Map<String, String> row) {
    // Styling suggestions after the garment description describe other pieces.
    final description = (row['description'] ?? '')
        .split(RegExp(r'(?<=[.!?])\s+'))
        .first;
    final subject = {
      'name': row['name'] ?? '',
      'subcategory': row['subcategory'] ?? '',
      'description': description,
      'keywords': row['keywords'] ?? '',
    };
    CatalogAttribute find(
      Map<String, String> patterns, {
      bool inferred = false,
    }) {
      for (final source in subject.entries) {
        for (final entry in patterns.entries) {
          final expression = RegExp(
            '\\b(?:${entry.value})\\b',
            caseSensitive: false,
          );
          for (final match in expression.allMatches(source.value)) {
            final prefix = source.value.substring(0, match.start);
            if (RegExp(
              r'\b(?:no|not|without|non)[ -]?(?:\w+\s+){0,2}$',
              caseSensitive: false,
            ).hasMatch(prefix)) {
              continue;
            }
            return CatalogAttribute(
              value: entry.key,
              basis: inferred ? 'styling_inference' : 'catalog_text',
              confidence: inferred
                  ? 'low'
                  : source.key == 'keywords'
                  ? 'medium'
                  : 'high',
              field: source.key,
              quote: match.group(0)!,
            );
          }
        }
      }
      return const CatalogAttribute();
    }

    final category = row['category'];
    final clothing = const {
      'dress',
      'top',
      'bottom',
      'layer',
    }.contains(category);
    final output = <String, CatalogAttribute>{
      if (clothing) ...{
        'length': find({
          if (category == 'dress' || category == 'bottom') ...{
            'maxi': r'maxi',
            'midi': r'midi',
            'mini': r'mini',
            'knee length': r'knee[ -]length',
            'ankle length': r'ankle[ -]length',
            'full length': r'full[ -]length',
          },
          'cropped': r'cropped|crop length',
          'longline': r'longline|long[ -]line',
        }),
        'silhouette': find({
          'oversized': r'oversized',
          'boxy': r'boxy',
          'relaxed': r'relaxed|loose[ -]fit(?:ting)?',
          'fitted': r'fitted|body[ -]?con',
          'slim': r'slim(?:[ -]fit)?',
          'wide leg': r'wide[ -]leg',
          'tapered': r'tapered',
          'flared': r'flared|flare',
          'A-line': r'a[ -]line',
          'straight': r'straight(?:[ -]leg)?',
        }),
        if (category != 'bottom') ...{
          'sleeve': find({
            'sleeveless': r'sleeveless|tank',
            'cap sleeve': r'cap[ -]sleeve(?:s|d)?',
            'short sleeve': r'short[ -]sleeve(?:s|d)?',
            'three-quarter sleeve': r'three[ -]quarter[ -]sleeve(?:s|d)?',
            'long sleeve': r'long[ -]sleeve(?:s|d)?',
          }),
          'neckline': find({
            'V-neck': r'v[ -]neck(?:line)?',
            'crew neck': r'crew[ -]?neck(?:line)?',
            'round neck': r'round(?:ed)?[ -]neck(?:line)?',
            'high neck': r'high[ -]neck|turtleneck|roll[ -]neck',
            'square neck': r'square[ -]neck(?:line)?',
            'scoop neck': r'scoop[ -]neck(?:line)?',
            'collared': r'collared|pointed collar|spread collar',
            'halter': r'halter',
          }),
        },
      },
      'closure': find({
        'zip': r'zip(?:per|ped)?(?:[ -]front)?',
        'button': r'button[ -](?:front|down)|buttoned',
        'wrap': r'wrap',
        'lace-up': r'lace[ -]up',
        'buckle': r'buckle',
        'pull-on': r'pull[ -]on',
      }),
      if (clothing)
        'layering_weight': find({
          'lightweight': r'lightweight|light[ -]weight|airy|sheer',
          'heavyweight':
              r'heavyweight|heavy[ -]weight|chunky|padded|puffer|quilted',
          'midweight': r'midweight|mid[ -]weight',
        }, inferred: true),
      'formality': find({
        'smart casual': r'smart[ -]casual',
        'casual': r'casual|lounge\w*|sleepwear|pyjamas?|pajamas?|hoodie|sweatpants?|joggers?|utility jumpsuit|coveralls?',
        'evening': r'black[ -]tie|gala|evening|cocktail|gown',
        'business': r'business|office|tailored|blazer',
        'polished': r'polished',
      }, inferred: true),
    };
    if (clothing &&
        !output['layering_weight']!.known &&
        !RegExp(
          r'\b(?:not|no|non)[ -]lightweight\b',
          caseSensitive: false,
        ).hasMatch(description)) {
      output['layering_weight'] = find({
        'lightweight': r't[ -]?shirts?|tees?|blouses?|shirts?|linen',
        'midweight': r'cardigans?|sweaters?|jumpers?|knits?|jeans|trousers?|chinos?|blazers?|jackets?|coats?',
      }, inferred: true);
    }
    if (!output['formality']!.known) {
      final occasion = row['occasion'] ?? '';
      final estimate = const {
        'work': 'business',
        'celebration': 'evening',
        'weekend': 'casual',
        'travel': 'casual',
      }[occasion];
      if (estimate != null) {
        output['formality'] = CatalogAttribute(
          value: estimate,
          basis: 'styling_inference',
          confidence: 'low',
          field: 'occasion',
          quote: occasion,
        );
      }
    }
    final material = (row['material'] ?? '').trim();
    if (material.isNotEmpty && material.toLowerCase() != 'unspecified') {
      output['material'] = CatalogAttribute(
        value: material,
        basis: 'catalog_claim',
        confidence: 'medium',
        field: 'material',
        quote: material,
      );
    } else {
      output['material_hint'] = find({
        'cotton mention': r'cotton',
        'linen mention': r'linen',
        'wool mention': r'wool',
        'silk mention': r'silk',
        'leather mention': r'leather',
        'denim mention': r'denim',
      }, inferred: true);
    }
    // Neither a photo nor a season tag verifies fibre composition or rain/thermal performance.
    return ProductAttributes(Map.unmodifiable(output));
  }
}
