import 'models.dart';

/// Conservative, reproducible labels derived from the retained catalog text.
/// Original descriptions remain authoritative; these are not supplier facts.
const garmentTypes = <String, ({ProductCategory category, String pattern})>{
  'robe': (category: ProductCategory.layer, pattern: r'\brobes?\b'),
  'cardigan': (category: ProductCategory.layer, pattern: r'\bcardigans?\b'),
  'vest': (category: ProductCategory.layer, pattern: r'\b(?:vests?|gilets?)\b'),
  'blazer': (category: ProductCategory.layer, pattern: r'\bblazers?\b'),
  'coat': (category: ProductCategory.layer, pattern: r'\b(?:coats?|parkas?)\b'),
  'jacket': (
    category: ProductCategory.layer,
    pattern: r'\b(?:jackets?|puffers?)\b',
  ),
  'hoodie': (category: ProductCategory.layer, pattern: r'\bhoodies?\b'),
  't-shirt': (
    category: ProductCategory.top,
    pattern: r'\b(?:t[ -]?shirts?|tees?)\b',
  ),
  'blouse': (category: ProductCategory.top, pattern: r'\bblouses?\b'),
  'shirt': (category: ProductCategory.top, pattern: r'\bshirts?\b'),
  'knit': (
    category: ProductCategory.top,
    pattern: r'\b(?:knits?|sweaters?|jumpers?)\b',
  ),
  'leggings': (category: ProductCategory.bottom, pattern: r'\bleggings?\b'),
  'shorts': (category: ProductCategory.bottom, pattern: r'\bshorts?\b'),
  'jeans': (category: ProductCategory.bottom, pattern: r'\bjeans?\b'),
  'skirt': (category: ProductCategory.bottom, pattern: r'\bskirts?\b'),
  'trousers': (
    category: ProductCategory.bottom,
    pattern: r'\b(?:trousers?|pants?|chinos?)\b',
  ),
  'trainers': (
    category: ProductCategory.shoes,
    pattern: r'\b(?:trainers?|sneakers?)\b',
  ),
  'boots': (category: ProductCategory.shoes, pattern: r'\bboots?\b'),
  'sandals': (category: ProductCategory.shoes, pattern: r'\bsandals?\b'),
  'heels': (category: ProductCategory.shoes, pattern: r'\bheels?\b'),
  'loafers': (category: ProductCategory.shoes, pattern: r'\bloafers?\b'),
  'tote': (category: ProductCategory.bag, pattern: r'\btotes?\b'),
  'handbag': (category: ProductCategory.bag, pattern: r'\bhandbags?\b'),
  'scarf': (category: ProductCategory.accessory, pattern: r'\bscar(?:f|ves)\b'),
  'watch': (category: ProductCategory.accessory, pattern: r'\bwatch(?:es)?\b'),
  'belt': (category: ProductCategory.accessory, pattern: r'\bbelts?\b'),
  'earrings': (category: ProductCategory.accessory, pattern: r'\bearrings?\b'),
  'coveralls': (category: ProductCategory.dress, pattern: r'\bcoveralls?\b'),
  'jumpsuit': (category: ProductCategory.dress, pattern: r'\bjumpsuits?\b'),
  'dress': (category: ProductCategory.dress, pattern: r'\bdress(?:es)?\b'),
};

String catalogGarmentType(Product product) {
  // Titles resolve inconsistent generic subcategories such as tee/cardigans.
  for (final text in [product.name, product.subcategory, product.description]) {
    for (final entry in garmentTypes.entries) {
      if (entry.value.category == product.category &&
          RegExp(entry.value.pattern, caseSensitive: false).hasMatch(text)) {
        return entry.key;
      }
    }
  }
  return '';
}

bool matchesGarmentRequest(Product product, String type) {
  final actual = catalogGarmentType(product);
  return actual == type ||
      (type == 'jacket' && actual == 'blazer') ||
      (type == 'knit' &&
          RegExp(
            r'\bknit',
            caseSensitive: false,
          ).hasMatch('${product.name} ${product.description}'));
}

/// Reject explicit casual/sleep/activewear evidence for a settled formal brief.
/// Unknown measurements, fit, and technical performance are never inferred.
bool matchesCatalogDressCode(Product product, String dressCode) {
  final formal = const {
    'business',
    'formal',
    'black-tie',
    'white-tie',
    'cocktail',
  }.contains(dressCode);
  if (!formal) return true;
  final text = '${product.name} ${product.subcategory} ${product.description}';
  if (RegExp(
    r'\b(?:lounge|sleepwear|loungewear|pyjamas?|pajamas?|gym|activewear|joggers?|sweatpants?|sweatshirts?|hoodies?|leggings?|coveralls?|utility jumpsuits?|flip[ -]?flops?|running|hiking)\b',
    caseSensitive: false,
  ).hasMatch(text)) {
    return false;
  }
  final type = catalogGarmentType(product);
  if (const {
    'robe',
    'hoodie',
    'leggings',
    'shorts',
    'jeans',
    't-shirt',
    'trainers',
  }.contains(type)) {
    return false;
  }
  return true;
}

const catalogColorFamilies = {
  'black': ['black'],
  'white': ['white', 'ivory', 'cream', 'off white', 'off-white'],
  'grey': ['grey', 'gray', 'silver', 'charcoal', 'graphite'],
  'beige': ['beige', 'oat', 'stone', 'sand', 'taupe', 'camel'],
  'brown': ['brown', 'chocolate', 'tan', 'cocoa'],
  'blue': ['blue', 'navy', 'indigo', 'denim'],
  'green': ['green', 'olive', 'sage', 'khaki', 'moss'],
  'red': ['red', 'burgundy', 'wine'],
  'pink': ['pink', 'rose', 'blush'],
  'purple': ['purple', 'lilac', 'lavender'],
  'yellow': ['yellow', 'mustard', 'gold'],
  'orange': ['orange', 'rust', 'terracotta', 'coral'],
};

Set<String> productColorFamilies(Product product) => {
  for (final entry in catalogColorFamilies.entries)
    if (entry.value.any(
      (term) => RegExp(
        '\\b${RegExp.escape(term)}\\b',
        caseSensitive: false,
      ).hasMatch(product.color),
    ))
      entry.key,
};

bool differentCatalogColor(Product a, Product b) {
  final first = productColorFamilies(a), second = productColorFamilies(b);
  return first.isEmpty || second.isEmpty
      ? a.color.trim().toLowerCase() != b.color.trim().toLowerCase()
      : first.intersection(second).isEmpty;
}

bool matchesCatalogColor(String value, String term) {
  String normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\bgray\b'), 'grey');
  final normalized = normalize(term);
  return (catalogColorFamilies[normalized] ?? [normalized]).any(
    (alias) =>
        RegExp('\\b${RegExp.escape(normalize(alias))}\\b')
            .hasMatch(normalize(value)),
  );
}
