import 'package:flutter/services.dart';

import 'models.dart';

abstract interface class ProductRepository {
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
      name: 'Indra Long Dress',
      brand: 'Zimmermann',
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
      brand: 'Toteme',
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
      brand: 'Rixo',
      price: 395,
      meta: 'Ink · Satin',
      tag: 'Best value',
      swatch: '#1c2a3a',
    ),
    Product(
      id: 'paris-shoes-1',
      journey: DemoJourney.paris,
      category: ProductCategory.shoes,
      name: 'Satin Pointed Pump',
      brand: 'Manolo Blahnik',
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
      brand: 'Aeyde',
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
      brand: 'Common Projects',
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
      brand: 'Loulou Studio',
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
      brand: 'Dear Frances',
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
      brand: 'Le Bon Shoppe',
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
      brand: 'Vagabond',
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
      brand: 'Faithfull',
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
      brand: 'A.Emery',
      price: 235,
      meta: 'Tan · Leather',
      tag: 'Long-lunch ease',
      swatch: '#a77f5e',
    ),
  ];

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

/// A deliberately small CSV adapter showing where a local data source can be
/// substituted without changing the catalog or surface code.
class CsvProductRepository implements ProductRepository {
  CsvProductRepository({
    this.assetPath = 'assets/data/products.csv',
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  final String assetPath;
  final AssetBundle _bundle;

  @override
  Future<List<Product>> recommendations({
    required DemoJourney journey,
    required ProductCategory category,
    int limit = 3,
  }) async {
    if (limit <= 0) return const [];

    final source = await _bundle.loadString(assetPath);
    final rows = source
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('#'))
        .toList();
    if (rows.length < 2) return const [];

    final headers = _parseCsvLine(rows.first)
        .map((header) => header.replaceFirst('\uFEFF', '').trim())
        .toList();
    final products = <Product>[];
    for (final row in rows.skip(1)) {
      final values = _parseCsvLine(row);
      if (values.length != headers.length) continue;
      final data = <String, String>{
        for (var index = 0; index < headers.length; index++)
          headers[index]: values[index].trim(),
      };
      final rowJourney = _journeyFromName(data['journey']);
      final rowCategory = _categoryFromName(data['category']);
      if (rowJourney == null || rowCategory == null) continue;
      if (rowJourney != journey || rowCategory != category) continue;
      products.add(
        Product(
          id: data['id'] ?? '',
          journey: rowJourney,
          category: rowCategory,
          name: data['name'] ?? '',
          brand: data['brand'] ?? '',
          price: double.tryParse(data['price'] ?? '') ?? 0,
          meta: data['meta'] ?? '',
          tag: data['tag'] ?? '',
          swatch: data['swatch'] ?? '#e4e4e7',
        ),
      );
      if (products.length == limit) break;
    }
    return products;
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

List<String> _parseCsvLine(String line) {
  final fields = <String>[];
  final field = StringBuffer();
  var quoted = false;

  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      if (quoted && index + 1 < line.length && line[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (character == ',' && !quoted) {
      fields.add(field.toString());
      field.clear();
    } else {
      field.write(character);
    }
  }
  fields.add(field.toString());
  return fields;
}
