import 'package:a2ui_flutter_commerce/data/catalog/repository/csv_catalog_source.dart';

import 'dart:io';

import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/catalog_snapshot.dart';

/// Genkit Developer UI entry point; always uses the free offline model.
Future<void> main() async {
  final snapshot = await CsvCatalogSource(
    readText: () => File(bundledCatalogPath).readAsString(),
  ).load();
  StylistRuntime(
    products: snapshot.products,
    catalog: snapshot,
    developerTools: true,
  );
  stdout.writeln(
    'Genkit Dart stylist ready. Developer UI turns use the offline catalog preview.',
  );
}
