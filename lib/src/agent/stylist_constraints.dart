import '../data/models.dart';

/// Catalog-checkable user instructions. Hard restrictions survive search
/// fallbacks; preferences affect ranking without excluding alternatives.
/// Unavailable size, stock and fit facts are deliberately not inferred here.
class StylistConstraints {
  const StylistConstraints({
    this.excludedCategories = const {},
    this.ownedCategories = const {},
    this.allowedColors = const {},
    this.excludedColors = const {},
    this.excludedMaterials = const {},
    this.excludedBrands = const {},
    this.allowedMaterials = const {},
    this.allowedBrands = const {},
    this.preferredColors = const {},
    this.categoryConstraints = const {},
    this.clarificationRequests = const [],
    this.pendingScopeCategories = const {},
    this.excludedProductTerms = const {},
  });

  final Set<ProductCategory> excludedCategories;
  final Set<ProductCategory> ownedCategories;
  final Set<String> allowedColors;
  final Set<String> excludedColors;
  final Set<String> excludedMaterials;
  final Set<String> excludedBrands;
  final Set<String> allowedMaterials;
  final Set<String> allowedBrands;
  final Set<String> preferredColors;
  final Map<ProductCategory, StylistConstraints> categoryConstraints;
  final List<String> clarificationRequests;
  final Set<ProductCategory> pendingScopeCategories;
  final Set<String> excludedProductTerms;

  Set<ProductCategory> get skippedCategories =>
      Set.unmodifiable({...excludedCategories, ...ownedCategories});

  bool categoryPermitted(ProductCategory category) =>
      !skippedCategories.contains(category);

  bool matches(Product product) => violations(product).isEmpty;

  List<String> violations(Product product) => [
    if (excludedCategories.contains(product.category))
      '${product.category.name} was excluded',
    if (ownedCategories.contains(product.category))
      '${product.category.name} is already owned',
    if (allowedColors.isNotEmpty &&
        !allowedColors.any((color) => _contains(product.color, color)))
      'Color must be ${allowedColors.join(' or ')}',
    if (excludedColors.any((color) => _contains(product.color, color)))
      'Color was excluded',
    if (excludedMaterials.isNotEmpty &&
        {
          '',
          'unspecified',
          'unknown',
          'not specified',
        }.contains(product.material.trim().toLowerCase()))
      'Material is unknown; cannot verify the material restriction',
    if (excludedMaterials.any(
      (material) => _contains(product.material, material),
    ))
      'Material was excluded',
    if (allowedMaterials.isNotEmpty &&
        !allowedMaterials.any(
          (material) => _contains(product.material, material),
        ))
      'Material must be ${allowedMaterials.join(' or ')}',
    if (excludedBrands.isNotEmpty && product.brand.trim().isEmpty)
      'Brand is unknown; cannot verify the brand restriction',
    if (excludedBrands.any((brand) => _contains(product.brand, brand)))
      'Brand was excluded',
    if (allowedBrands.isNotEmpty &&
        !allowedBrands.any((brand) => _contains(product.brand, brand)))
      'Brand must be ${allowedBrands.join(' or ')}',
    ...?categoryConstraints[product.category]?.violations(product),
    for (final term in excludedProductTerms)
      if (_matchesProductType(product, term))
        'Catalog describes an excluded product type: $term',
  ];

  int preferenceScore(Product product) =>
      preferredColors.where((color) => _contains(product.color, color)).length +
      (categoryConstraints[product.category]?.preferenceScore(product) ?? 0);

  Map<String, Object?> toMap() => {
    if (excludedCategories.isNotEmpty)
      'excludedCategories': excludedCategories
          .map((value) => value.name)
          .toList(),
    if (ownedCategories.isNotEmpty)
      'ownedCategories': ownedCategories.map((value) => value.name).toList(),
    if (allowedColors.isNotEmpty) 'allowedColors': allowedColors.toList(),
    if (excludedColors.isNotEmpty) 'excludedColors': excludedColors.toList(),
    if (excludedMaterials.isNotEmpty)
      'excludedMaterials': excludedMaterials.toList(),
    if (excludedBrands.isNotEmpty) 'excludedBrands': excludedBrands.toList(),
    if (allowedMaterials.isNotEmpty)
      'allowedMaterials': allowedMaterials.toList(),
    if (allowedBrands.isNotEmpty) 'allowedBrands': allowedBrands.toList(),
    if (preferredColors.isNotEmpty) 'preferredColors': preferredColors.toList(),
    if (categoryConstraints.isNotEmpty)
      'categoryConstraints': {
        for (final entry in categoryConstraints.entries)
          entry.key.name: entry.value.toMap(),
      },
    if (clarificationRequests.isNotEmpty)
      'clarificationRequests': clarificationRequests,
    if (excludedProductTerms.isNotEmpty)
      'excludedProductTerms': excludedProductTerms.toList(),
  };

  /// Applies explicit instructions to the existing constraints. A positive
  /// correction such as "wool is okay now" releases that restriction; a new
  /// "only blue" replaces the previous required palette.
  StylistConstraints recordMessage(
    String message, {
    Iterable<String> knownBrands = const [],
  }) {
    final categories = {...excludedCategories};
    final owned = {...ownedCategories};
    var requiredColors = {...allowedColors};
    final deniedColors = {...excludedColors};
    final materials = {...excludedMaterials};
    final brands = {...excludedBrands};
    var requiredMaterials = {...allowedMaterials};
    var requiredBrands = {...allowedBrands};
    var preferences = {...preferredColors};
    final scopedConstraints = {...categoryConstraints};
    final pendingScopes = {...pendingScopeCategories};
    final excludedTypes = {...excludedProductTerms};
    var questions = [...clarificationRequests];
    final brandTerms = {
      ...excludedBrands,
      ...allowedBrands,
      ...knownBrands.map(_normalize),
      for (final scoped in categoryConstraints.values) ...scoped.excludedBrands,
      for (final scoped in categoryConstraints.values) ...scoped.allowedBrands,
    }.where((brand) => brand.isNotEmpty).toSet();
    for (final clause in _clauses(message)) {
      final scope = _restrictionScope(clause, {
        ..._colors,
        ..._materials,
        ...brandTerms,
      });
      if (scope.ambiguous) {
        pendingScopes.addAll(scope.categories);
        final question = scope.categories.length == 1
            ? 'Should this restriction apply to all ${scope.categories.single.name} pieces, '
                  'or only the specific product type you mentioned?'
            : 'Please state color, material or brand restrictions separately for '
                  '${scope.categories.map((category) => category.name).join(' and ')}.';
        if (!questions.contains(question)) questions.add(question);
        continue;
      }
      if (scope.categories.length == 1) {
        final category = scope.categories.single;
        var attributesOnly = clause;
        for (final pattern in categoryPatterns.values) {
          attributesOnly = attributesOnly.replaceAll(RegExp(pattern), '');
        }
        final revised =
            (scopedConstraints[category] ?? const StylistConstraints())
                .recordMessage(attributesOnly, knownBrands: brandTerms);
        if (revised.toMap().isEmpty) {
          scopedConstraints.remove(category);
        } else {
          scopedConstraints[category] = revised;
        }
        pendingScopes.remove(category);
        if (pendingScopes.isEmpty) questions = [];
        continue;
      }
      for (final type in _productTypes.entries) {
        for (final mention in RegExp(type.value.pattern).allMatches(clause)) {
          final intent = _intent(clause, mention);
          if (intent == _Intent.exclude) excludedTypes.add(type.key);
          if (intent == _Intent.allow || intent == _Intent.release) {
            excludedTypes.remove(type.key);
          }
        }
      }
      for (final entry in categoryPatterns.entries) {
        for (final match in RegExp(entry.value).allMatches(clause)) {
          final intent = _intent(clause, match);
          final modifiedByNarrowType = _productTypes.values.any(
            (type) =>
                type.category == entry.key &&
                RegExp(type.pattern)
                    .allMatches(clause)
                    .any(
                      (typeMention) =>
                          typeMention.end <= match.start &&
                          _intent(clause, typeMention) == _Intent.exclude &&
                          clause
                              .substring(typeMention.end, match.start)
                              .trim()
                              .isEmpty,
                    ),
          );
          if (modifiedByNarrowType) continue;
          final narrowType = _productTypes.entries
              .where(
                (type) => RegExp(type.value.pattern).hasMatch(match.group(0)!),
              )
              .firstOrNull;
          if (narrowType != null && intent != _Intent.owned) {
            if (intent == _Intent.exclude) excludedTypes.add(narrowType.key);
            if (intent == _Intent.allow || intent == _Intent.release) {
              excludedTypes.remove(narrowType.key);
            }
            continue;
          }
          if (intent == _Intent.exclude) {
            categories.add(entry.key);
            owned.remove(entry.key);
          } else if (intent == _Intent.owned) {
            owned.add(entry.key);
            categories.remove(entry.key);
          } else if (intent == _Intent.allow || intent == _Intent.release) {
            categories.remove(entry.key);
            owned.remove(entry.key);
          }
        }
      }
      final clauseRequired = <String>{};
      final clausePreferred = <String>{};
      for (final color in _colors) {
        for (final match in _term(color).allMatches(clause)) {
          switch (_intent(clause, match)) {
            case _Intent.exclude:
              deniedColors.add(color);
              requiredColors.remove(color);
              preferences.remove(color);
            case _Intent.require:
              clauseRequired.add(color);
              deniedColors.remove(color);
            case _Intent.prefer:
              clausePreferred.add(color);
              deniedColors.remove(color);
            case _Intent.allow:
              deniedColors.remove(color);
            case _Intent.release:
              deniedColors.remove(color);
              requiredColors.remove(color);
            case _Intent.owned || _Intent.unspecified:
              break;
          }
        }
      }
      if (clauseRequired.isNotEmpty) requiredColors = clauseRequired;
      if (clausePreferred.isNotEmpty) {
        preferences = clausePreferred;
        // An explicit switch to a preference releases an earlier hard palette.
        requiredColors = {};
      }
      final clauseRequiredMaterials = <String>{};
      for (final material in _materials) {
        _updateAttribute(
          materials,
          requiredMaterials,
          clauseRequiredMaterials,
          material,
          clause,
        );
      }
      if (clauseRequiredMaterials.isNotEmpty) {
        requiredMaterials = clauseRequiredMaterials;
      }
      final clauseRequiredBrands = <String>{};
      for (final brand in brandTerms) {
        _updateAttribute(
          brands,
          requiredBrands,
          clauseRequiredBrands,
          brand,
          clause,
        );
      }
      if (clauseRequiredBrands.isNotEmpty) {
        requiredBrands = clauseRequiredBrands;
      }
    }
    return StylistConstraints(
      excludedCategories: Set.unmodifiable(categories),
      ownedCategories: Set.unmodifiable(owned),
      allowedColors: Set.unmodifiable(requiredColors),
      excludedColors: Set.unmodifiable(deniedColors),
      excludedMaterials: Set.unmodifiable(materials),
      excludedBrands: Set.unmodifiable(brands),
      allowedMaterials: Set.unmodifiable(requiredMaterials),
      allowedBrands: Set.unmodifiable(requiredBrands),
      preferredColors: Set.unmodifiable(preferences),
      categoryConstraints: Map.unmodifiable(scopedConstraints),
      clarificationRequests: List.unmodifiable(questions),
      pendingScopeCategories: Set.unmodifiable(pendingScopes),
      excludedProductTerms: Set.unmodifiable(excludedTypes),
    );
  }
}

/// A category mentioned only to reject it or to describe an owned piece is not
/// a request to search that category.
ProductCategory? requestedProductCategory(
  String message, {
  StylistConstraints constraints = const StylistConstraints(),
}) {
  final effective = constraints.recordMessage(message);
  final requested = <ProductCategory>{};
  for (final clause in _clauses(message)) {
    for (final entry in categoryPatterns.entries) {
      if (!effective.categoryPermitted(entry.key)) continue;
      for (final match in RegExp(entry.value).allMatches(clause)) {
        final intent = _intent(clause, match);
        if (intent != _Intent.exclude && intent != _Intent.owned) {
          requested.add(entry.key);
        }
      }
    }
  }
  return requested.length == 1 ? requested.single : null;
}

const categoryPatterns = {
  ProductCategory.dress: r'\bdress(?:es)?\b',
  ProductCategory.top: r'\b(?:tops?|shirts?|knits?|blouses?)\b',
  ProductCategory.bottom: r'\b(?:bottoms?|trousers?|pants?|shorts?|skirts?)\b',
  ProductCategory.layer: r'\b(?:layers?|jackets?|coats?|outerwear)\b',
  ProductCategory.shoes:
      r'\b(?:shoes?|boots?|sandals?|heels?|trainers?|sneakers?)\b',
  ProductCategory.bag: r'\b(?:bags?|totes?|handbags?)\b',
  ProductCategory.accessory:
      r'\b(?:accessor(?:y|ies)|jewell?ery|scarves?|belts?)\b',
};

// Narrow types do not remove the broader category from the outfit plan.
const _productTypes = <String, ({ProductCategory category, String pattern})>{
  'heels': (category: ProductCategory.shoes, pattern: r'\bheel(?:s|ed)?\b'),
  'boots': (category: ProductCategory.shoes, pattern: r'\bboots?\b'),
  'sandals': (category: ProductCategory.shoes, pattern: r'\bsandals?\b'),
  'trainers': (
    category: ProductCategory.shoes,
    pattern: r'\b(?:trainers?|sneakers?)\b',
  ),
  'knits': (category: ProductCategory.top, pattern: r'\bknit(?:s|ted|wear)?\b'),
  'blouses': (category: ProductCategory.top, pattern: r'\bblouses?\b'),
  'shirts': (category: ProductCategory.top, pattern: r'\bshirts?\b'),
  'coats': (category: ProductCategory.layer, pattern: r'\bcoats?\b'),
  'jackets': (category: ProductCategory.layer, pattern: r'\bjackets?\b'),
  'trousers': (
    category: ProductCategory.bottom,
    pattern: r'\b(?:trousers?|pants?)\b',
  ),
  'shorts': (category: ProductCategory.bottom, pattern: r'\bshorts?\b'),
  'skirts': (category: ProductCategory.bottom, pattern: r'\bskirts?\b'),
  'totes': (category: ProductCategory.bag, pattern: r'\btotes?\b'),
  'handbags': (category: ProductCategory.bag, pattern: r'\bhandbags?\b'),
  'scarves': (
    category: ProductCategory.accessory,
    pattern: r'\bscar(?:f|ves)\b',
  ),
  'belts': (category: ProductCategory.accessory, pattern: r'\bbelts?\b'),
};

const _colors = {
  'red',
  'blue',
  'green',
  'olive',
  'black',
  'white',
  'cream',
  'beige',
  'brown',
  'grey',
  'gray',
  'navy',
  'pink',
  'purple',
  'yellow',
  'orange',
  'silver',
  'gold',
};
const _materials = {
  'wool',
  'cashmere',
  'leather',
  'suede',
  'silk',
  'cotton',
  'linen',
  'polyester',
  'nylon',
  'viscose',
  'acrylic',
  'fur',
  'down',
};

enum _Intent { exclude, owned, require, prefer, allow, release, unspecified }

Iterable<String> _clauses(String message) => message
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'\bdress[ -]*code\b|\bdressing[ -]*code\b'), 'style')
    .split(
      RegExp(
        r'[,;!?]|(?<=[a-z0-9]{2})\.(?=\s|$)|\bbut\b|\band\s+(?=(?:i|please|only|prefer)\b)',
      ),
    );

_Intent _intent(String clause, RegExpMatch mention) {
  final prefix = clause.substring(0, mention.start);
  final suffix = clause.substring(mention.end);
  // Explicit releases take precedence over an older restriction in state.
  if (_releasesRestriction(prefix, suffix)) return _Intent.release;
  if (RegExp(
    r'\b(?:no longer (?:have|own)|do not (?:have|own)|don\x27t (?:have|own))\s+(?:a\s+|any\s+)?$',
  ).hasMatch(prefix)) {
    return _Intent.allow;
  }
  if (RegExp(r'^\s+(?:is|are)\s+(?:ok(?:ay)?|fine|allowed)\b')
          .hasMatch(suffix) ||
      RegExp(
            r'\b(?:allow|include|want|need|show(?: me)?)\s+(?:(?:a|an|some|the|new|different)\s+){0,3}$',
          ).hasMatch(prefix) &&
          !_negative(prefix)) {
    return _Intent.allow;
  }
  if (_negative(prefix) || RegExp(r'^[- ]free\b').hasMatch(suffix)) {
    return _Intent.exclude;
  }
  if (RegExp(
        r'\b(?:i\s+(?:already\s+)?(?:have|own)|already\s+(?:have|own)|(?:use|wear)\s+my|my\s+own)\s+(?:[a-z]+\s+){0,5}$',
      ).hasMatch(prefix) ||
      RegExp(r'^\s+(?:i\s+)?(?:already\s+)?(?:own|have)\b').hasMatch(suffix)) {
    return _Intent.owned;
  }
  if (RegExp(r'\b(?:only|must\s+be|strictly)\b[^,;.!?]{0,45}$')
          .hasMatch(prefix) ||
      RegExp(r'^\s+only\b').hasMatch(suffix)) {
    return _Intent.require;
  }
  if (RegExp(r'\b(?:prefer|preferably|ideally|like)\b[^,;.!?]{0,45}$')
      .hasMatch(prefix)) {
    return _Intent.prefer;
  }
  return _Intent.unspecified;
}

bool _negative(String prefix) {
  final matches = RegExp(
    r"\b(?:no|not|without|avoid|exclude|except|skip|free of|allergic to|do not (?:want|need)|don't (?:want|need))\b",
  ).allMatches(prefix);
  if (matches.isEmpty) return false;
  final after = prefix.substring(matches.last.end);
  return after.trim().split(RegExp(r'\s+')).length <= 6 &&
      !RegExp(r'\b(?:want|need|prefer|only|include|allow)\b').hasMatch(after);
}

void _updateAttribute(
  Set<String> excluded,
  Set<String> allowed,
  Set<String> requiredInClause,
  String term,
  String clause,
) {
  for (final match in _term(term).allMatches(clause)) {
    final intent = _intent(clause, match);
    if (intent == _Intent.exclude) {
      excluded.add(term);
      allowed.remove(term);
    }
    if (intent == _Intent.require) {
      requiredInClause.add(term);
      excluded.remove(term);
    }
    if (intent == _Intent.allow || intent == _Intent.release) {
      excluded.remove(term);
    }
    if (intent == _Intent.release) allowed.remove(term);
  }
}

({Set<ProductCategory> categories, bool ambiguous}) _restrictionScope(
  String clause,
  Set<String> terms,
) {
  final categories = <ProductCategory, List<RegExpMatch>>{
    for (final entry in categoryPatterns.entries)
      if (RegExp(entry.value).hasMatch(clause))
        entry.key: RegExp(entry.value).allMatches(clause).toList(),
  };
  if (categories.isEmpty) {
    return (categories: <ProductCategory>{}, ambiguous: false);
  }
  final attributes = [
    for (final term in terms)
      for (final mention in _term(term).allMatches(clause))
        if (_intent(clause, mention) != _Intent.unspecified &&
            _intent(clause, mention) != _Intent.owned)
          mention,
  ];
  if (attributes.isEmpty) {
    return (categories: <ProductCategory>{}, ambiguous: false);
  }
  var attached = false;
  for (final mentions in categories.values) {
    for (final category in mentions) {
      for (final attribute in attributes) {
        if (attribute.end <= category.start) {
          final between = clause.substring(attribute.end, category.start);
          if (RegExp(r'^\s*(?:(?:a|an|the|new)\s+)?$').hasMatch(between) ||
              RegExp(
                r'^\s+(?:(?:color|material|brand)\s+)?(?:restriction|exclusion|constraint|rule|filter)s?\s+(?:for|on)\s+$',
              ).hasMatch(between)) {
            attached = true;
          }
        } else if (category.end <= attribute.start &&
            _intent(clause, category) != _Intent.exclude) {
          final between = clause.substring(category.end, attribute.start);
          if (RegExp(
            r'^\s+(?:must\s+be|only|in|without|with|no|not|avoid|prefer|preferably|are|should\s+be)\s+$',
          ).hasMatch(between)) {
            attached = true;
          }
        }
      }
    }
  }
  if (!attached) return (categories: <ProductCategory>{}, ambiguous: false);
  final narrowScope = categories.values
      .expand((matches) => matches)
      .any(
        (mention) => _productTypes.values.any(
          (type) => RegExp(type.pattern).hasMatch(mention.group(0)!),
        ),
      );
  return (
    categories: categories.keys.toSet(),
    ambiguous: categories.length > 1 || narrowScope,
  );
}

bool _releasesRestriction(String prefix, String suffix) {
  const operation =
      r'\b(?:forget|clear|remove|reset)\s+(?:(?:the|my|a|an)\s+)?';
  const restriction =
      r'(?:(?:color|material|brand|category)\s+)?(?:restriction|exclusion|constraint|rule|filter)s?';
  return RegExp('$operation\$').hasMatch(prefix) &&
          RegExp('^\\s+$restriction\\b').hasMatch(suffix) ||
      RegExp('$operation$restriction\\s+(?:on|against|for)\\s+\$')
          .hasMatch(prefix);
}

bool _matchesProductType(Product product, String term) {
  final type = _productTypes[term];
  if (type != null && type.category != product.category) return false;
  return RegExp(type?.pattern ?? _term(term).pattern).hasMatch(
    _normalize(
      '${product.subcategory} ${product.name} ${product.keywords} ${product.meta}',
    ),
  );
}

RegExp _term(String text) =>
    RegExp('(?<![a-z0-9])${RegExp.escape(_normalize(text))}(?![a-z0-9])');
String _normalize(String text) =>
    text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
bool _contains(String value, String term) =>
    _term(term).hasMatch(_normalize(value));
