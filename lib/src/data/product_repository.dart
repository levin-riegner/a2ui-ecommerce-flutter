import 'package:flutter/services.dart';

import 'models.dart';
import 'catalog_products.dart';

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

/// Searchable offline catalog backed by the same parser as the bundled stylist.
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
    return parseCatalogProducts(await _bundle.loadString(assetPath));
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
  final categoryFilter = category?.trim().toLowerCase();
  final words = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return products
      .where((p) {
        if (categoryFilter != null &&
            categoryFilter.isNotEmpty &&
            p.category.name != categoryFilter) {
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
