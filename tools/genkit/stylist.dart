import 'dart:io';

import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';

/// Genkit Developer UI entry point; always uses the free offline model.
Future<void> main() async {
  final products = parseCatalogProducts(
    await File('assets/data/catalog/products.csv').readAsString(),
  );
  StylistRuntime(products: products, developerTools: true);
  stdout.writeln(
    'Genkit Dart stylist ready. Developer UI turns use the offline catalog preview.',
  );
}
