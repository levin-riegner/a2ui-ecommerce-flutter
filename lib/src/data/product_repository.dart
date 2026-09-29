import 'package:flutter/services.dart';

import 'models.dart';

abstract interface class ProductRepository {
  Future<List<Product>> search({
    String query = '',
    String? category,
    String? color,
    String? occasion,
    String? season,
    double? maxPrice,
    int limit = 12,
  });

  Future<List<Product>> recommendations({
    required DemoJourney journey,
    required ProductCategory category,
    int limit = 3,
  });
}

/// Deterministic offline data source used by the reference app.
class FixtureProductRepository implements ProductRepository {
  const FixtureProductRepository();

  static const _products = <Product>[
    Product(
      id: 'paris-dress-1',
      journey: DemoJourney.paris,
      category: ProductCategory.dress,
      name: 'Evening Long Dress',
      brand: 'Studio Sample',
      price: 874,
      meta: 'Black · Silk',
      tag: 'Most formal',
      swatch: '#1c1c1f',
    ),
    Product(
      id: 'paris-dress-2',
      journey: DemoJourney.paris,
      category: ProductCategory.dress,
      name: 'Column Dress',
      brand: 'Studio Sample',
      price: 690,
      meta: 'Black · Crepe',
      tag: 'Quietly elegant',
      swatch: '#35343a',
    ),
    Product(
      id: 'paris-dress-3',
      journey: DemoJourney.paris,
      category: ProductCategory.dress,
      name: 'Satin Midi Dress',
      brand: 'Studio Sample',
      price: 395,
      meta: 'Ink · Satin',
      tag: 'Best value',
      swatch: '#1c2a3a',
    ),
    Product(
      id: 'paris-shoes-1',
      journey: DemoJourney.paris,
      category: ProductCategory.shoes,
      name: 'Demo Pointed Pump',
      brand: 'Studio Sample',
      price: 545,
      meta: 'Black · Satin · 70mm',
      tag: 'Most formal',
      swatch: '#17171a',
    ),
    Product(
      id: 'paris-shoes-2',
      journey: DemoJourney.paris,
      category: ProductCategory.shoes,
      name: 'Leather Kitten Heel',
      brand: 'Studio Sample',
      price: 295,
      meta: 'Black · Leather · 55mm',
      tag: 'Easiest',
      swatch: '#2f3034',
    ),
    Product(
      id: 'paris-shoes-3',
      journey: DemoJourney.paris,
      category: ProductCategory.shoes,
      name: 'Suede Low-Top Sneaker',
      brand: 'Studio Sample',
      price: 349,
      meta: 'Off-white · Suede',
      tag: 'Relaxed',
      swatch: '#dedbd3',
    ),
    Product(
      id: 'berlin-layer-1',
      journey: DemoJourney.berlin,
      category: ProductCategory.layer,
      name: 'Fine Wool Blazer',
      brand: 'Studio Sample',
      price: 420,
      meta: 'Charcoal · Wool',
      tag: 'Easy polish',
      swatch: '#4d4d51',
    ),
    Product(
      id: 'berlin-shoes-1',
      journey: DemoJourney.berlin,
      category: ProductCategory.shoes,
      name: 'City Derby',
      brand: 'Studio Sample',
      price: 340,
      meta: 'Black · Leather',
      tag: 'Walkable',
      swatch: '#1c1c1f',
    ),
    Product(
      id: 'cotswolds-layer-1',
      journey: DemoJourney.cotswolds,
      category: ProductCategory.layer,
      name: 'Ribbed Wool Cardigan',
      brand: 'Studio Sample',
      price: 168,
      meta: 'Oat · Wool blend',
      tag: 'Warmest',
      swatch: '#c7bca8',
    ),
    Product(
      id: 'cotswolds-shoes-1',
      journey: DemoJourney.cotswolds,
      category: ProductCategory.shoes,
      name: 'Suede Chelsea Boot',
      brand: 'Studio Sample',
      price: 180,
      meta: 'Dark brown · Suede',
      tag: 'Weather ready',
      swatch: '#4b3528',
    ),
    Product(
      id: 'lisbon-dress-1',
      journey: DemoJourney.lisbon,
      category: ProductCategory.dress,
      name: 'Linen Column Dress',
      brand: 'Studio Sample',
      price: 245,
      meta: 'Ecru · Linen',
      tag: 'Lightest',
      swatch: '#d8d0c2',
    ),
    Product(
      id: 'lisbon-shoes-1',
      journey: DemoJourney.lisbon,
      category: ProductCategory.shoes,
      name: 'Minimal Leather Sandal',
      brand: 'Studio Sample',
      price: 235,
      meta: 'Tan · Leather',
      tag: 'Long-lunch ease',
      swatch: '#a77f5e',
    ),
  ];

  @override
  Future<List<Product>> search({
    String query = '',
    String? category,
    String? color,
    String? occasion,
    String? season,
    double? maxPrice,
    int limit = 12,
  }) async => _filterProducts(
    _products,
    query: query,
    category: category,
    color: color,
    occasion: occasion,
    season: season,
    maxPrice: maxPrice,
    limit: limit,
  );

  @override
  Future<List<Product>> recommendations({
    required DemoJourney journey,
    required ProductCategory category,
    int limit = 3,
  }) async {
    return _products
        .where(
          (product) =>
              product.journey == journey && product.category == category,
        )
        .take(limit)
        .toList(growable: false);
  }
}

/// Searchable offline catalog. The same public CSV can be used by an agent
/// service, while Flutter resolves image_asset as a bundled asset path.
class CsvProductRepository implements ProductRepository {
  CsvProductRepository({
    this.assetPath = 'assets/data/catalog/products.csv',
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final String assetPath;
  final AssetBundle _bundle;
  Future<List<Product>>? _products;

  Future<List<Product>> _load() => _products ??= _readProducts();

  Future<List<Product>> _readProducts() async {
    final records = _parseCsv(await _bundle.loadString(assetPath));
    if (records.isEmpty) return const [];
    final headers = records.first
        .map((value) => value.replaceFirst('\uFEFF', '').trim())
        .toList();
    final products = <Product>[];
    final seenIds = <String>{};
    for (final values in records.skip(1)) {
      if (values.length != headers.length) continue;
      final row = <String, String>{
        for (var i = 0; i < headers.length; i++) headers[i]: values[i].trim(),
      };
      final id = row['id'] ?? '';
      final name = row['name'] ?? '';
      final price = double.tryParse(row['price_eur'] ?? row['price'] ?? '');
      if (id.isEmpty ||
          name.isEmpty ||
          price == null ||
          !price.isFinite ||
          price < 0 ||
          !seenIds.add(id)) {
        continue;
      }
      final categoryName = row['category'] ?? '';
      final category = _categoryFromName(categoryName);
      if (category == null) continue;
      final color = row['color'] ?? '';
      final material = row['material'] ?? '';
      products.add(
        Product(
          id: id,
          journey: _journeyFromName(row['journey']),
          category: category,
          name: name,
          brand: row['brand'] ?? '',
          price: price,
          meta:
              row['meta'] ??
              [color, material].where((v) => v.isNotEmpty).join(' · '),
          tag: row['tag'] ?? (row['subcategory'] ?? categoryName),
          swatch: row['swatch'] ?? '#e4e4e7',
          description: row['description'] ?? '',
          subcategory: row['subcategory'] ?? '',
          color: color,
          material: material,
          season: row['season'] ?? '',
          occasion: row['occasion'] ?? '',
          imageAsset: row['image_asset'] ?? '',
          keywords: [categoryName, row['keywords'] ?? ''].join(' '),
        ),
      );
    }
    return List.unmodifiable(products);
  }

  @override
  Future<List<Product>> search({
    String query = '',
    String? category,
    String? color,
    String? occasion,
    String? season,
    double? maxPrice,
    int limit = 12,
  }) async => _filterProducts(
    await _load(),
    query: query,
    category: category,
    color: color,
    occasion: occasion,
    season: season,
    maxPrice: maxPrice,
    limit: limit,
  );

  @override
  Future<List<Product>> recommendations({
    required DemoJourney journey,
    required ProductCategory category,
    int limit = 3,
  }) async {
    if (limit <= 0) return const [];
    final products = await _load();
    final byJourney = products.where(
      (p) => p.journey == journey && p.category == category,
    );
    if (byJourney.isNotEmpty) return byJourney.take(limit).toList();
    // The public catalog has no hard-coded journeys. Prefer the brief's season
    // and occasion, then fill from the same category within the budget.
    final categoryProducts = products
        .where((p) => p.category == category && p.price <= journey.budget)
        .toList();
    int score(Product p) =>
        (_matchesTag(p.season, journey.season)
            ? 2
            : _matchesTag(p.season, 'all-season')
            ? 1
            : 0) +
        (_matchesTag(p.occasion, journey.catalogOccasion) ? 2 : 0);
    categoryProducts.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      return byScore != 0 ? byScore : a.id.compareTo(b.id);
    });
    return categoryProducts.take(limit).toList();
  }
}

DemoJourney? _journeyFromName(String? value) {
  for (final journey in DemoJourney.values) {
    if (journey.name == value) return journey;
  }
  return null;
}

ProductCategory? _categoryFromName(String? value) {
  for (final category in ProductCategory.values) {
    if (category.name == value) return category;
  }
  return null;
}

List<Product> _filterProducts(
  Iterable<Product> products, {
  required String query,
  required String? category,
  required String? color,
  required String? occasion,
  required String? season,
  required double? maxPrice,
  required int limit,
}) {
  if (limit <= 0) return const [];
  final words = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return products
      .where((p) {
        if (category != null &&
            category.isNotEmpty &&
            !_matchesTag(p.keywords, category) &&
            p.category.name != category.toLowerCase()) {
          return false;
        }
        if (color != null && color.isNotEmpty && !_matchesTag(p.color, color)) {
          return false;
        }
        if (occasion != null &&
            occasion.isNotEmpty &&
            !_matchesTag(p.occasion, occasion)) {
          return false;
        }
        if (season != null &&
            season.isNotEmpty &&
            !_matchesTag(p.season, season) &&
            !_matchesTag(p.season, 'all-season')) {
          return false;
        }
        if (maxPrice != null && p.price > maxPrice) return false;
        final haystack = [
          p.name,
          p.brand,
          p.description,
          p.subcategory,
          p.color,
          p.material,
          p.season,
          p.occasion,
          p.keywords,
        ].join(' ').toLowerCase();
        return words.every(haystack.contains);
      })
      .take(limit)
      .toList(growable: false);
}

bool _matchesTag(String value, String wanted) =>
    value.toLowerCase().contains(wanted.toLowerCase());

/// RFC 4180-style records, including escaped quotes and line breaks in cells.
List<List<String>> _parseCsv(String source) {
  final records = <List<String>>[];
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (character == '"') {
      if (quoted && index + 1 < source.length && source[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      fields.add(field.toString());
      field.clear();
    } else if ((character == '\n' || character == '\r') && !quoted) {
      fields.add(field.toString());
      field.clear();
      if (fields.any((value) => value.isNotEmpty)) records.add(fields);
      fields = <String>[];
      if (character == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index++;
      }
    } else {
      field.write(character);
    }
  }
  fields.add(field.toString());
  if (fields.any((value) => value.isNotEmpty)) records.add(fields);
  return records;
}
