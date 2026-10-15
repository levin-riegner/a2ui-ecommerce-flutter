import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/demo_commerce.dart';
import 'package:a2ui_flutter_commerce/src/data/product_attributes.dart';

/// Rebuild the granular evidence report with the same rules the app consumes.
void main(List<String> arguments) {
  if (arguments.length != 1) throw ArgumentError('Pass one output JSON path.');
  final catalog = parseCatalogProducts(
    File('assets/data/catalog/products.csv').readAsStringSync(),
  );
  const demo = DemoCommerce();
  final products = [
    for (final p in catalog)
      {
        'id': p.id,
        'name': p.name,
        'description': p.description,
        'category': p.category.name,
        'gender': p.gender,
        'color': p.color,
        'originalMaterial': p.material,
        'priceEur': p.price,
        'imageAsset': p.imageAsset,
        'attributes': p.attributes.toMap(),
        'variants': demo.variants(p).map((v) => v.toMap()).toList(),
        'sizeGuide': demo.sizeGuide(p),
        'missingVerifiedFacts': [
          'fibre percentages',
          'garment measurements',
          'waterproofing',
          'insulation ratings',
          'live merchant stock',
          'carrier delivery quote',
          'real checkout',
        ],
      },
  ];
  final coverage = {
    for (final field in ProductAttributes.fields)
      field: {
        'knownOrEstimated': catalog
            .where((p) => p.attributes[field].known)
            .length,
        'unknown': catalog.where((p) => !p.attributes[field].known).length,
      },
  };
  final report = {
    'schemaVersion': 1,
    'policy': 'Catalog-text classification and explicitly fictional local commerce. No generated field is supplier verification or measured performance. Raw CSV/images unchanged.',
    'productCount': catalog.length,
    'coverage': coverage,
    'demoVariantCount': products.fold<int>(
      0,
      (n, p) => n + (p['variants'] as List).length,
    ),
    'products': products,
  };
  final output = File(arguments.single)..parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    jsonEncode({
      'productCount': catalog.length,
      'coverage': coverage,
      'output': output.path,
      'bytes': output.lengthSync(),
    }),
  );
}
