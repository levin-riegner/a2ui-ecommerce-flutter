import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/src/catalog/catalog_export.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_component_gallery.dart';
import 'package:a2ui_flutter_commerce/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/test/validation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  test(
    'export is the actual registered catalog and every fixture validates',
    () async {
      final catalog = buildCommerceCatalog();
      final bundle = exportCommerceCatalog(catalog);
      expect(bundle['catalog'], catalog.toCapabilitiesJson());
      expect(
        catalog.items.map((item) => item.name).toSet().length,
        catalog.items.length,
      );
      final examples = bundle['examples'] as List;
      for (final example in examples.cast<Map>()) {
        final messages = example['messages'] as List;
        final rows =
            (messages[1] as Map)['updateComponents']['components'] as List;
        for (final row in rows.cast<Map>()) {
          final item = catalog.items.singleWhere(
            (item) => item.name == row['component'],
          );
          final errors = await item.dataSchema.validate(
            row,
            schemaRegistry: createSchemaRegistryWithCommonTypes(),
          );
          expect(errors, isEmpty, reason: '${example['component']}: $errors');
        }
      }
      expect(examples.length, greaterThanOrEqualTo(99));
    },
  );

  test('all finalized Figma families have a registered renderer', () {
    final names = buildCommerceCatalog().items.map((item) => item.name).toSet();
    var count = 0;
    for (final section in ['left', 'right', 'shared']) {
      final manifest = jsonDecode(
        File('docs/design/finalized-$section.json').readAsStringSync(),
      ) as Map;
      for (final component in manifest['components'] as List) {
        final name = component['catalogName'] ?? component['name'];
        expect(names, contains(name), reason: 'Missing Figma renderer: $name');
        expect(component['sourceId'] ?? component['figmaNodes'], isNotEmpty);
        count++;
      }
    }
    expect(count, 40);
  });

  for (final size in [
    const Size(466, 678),
    const Size(669, 951),
    const Size(951, 669),
  ]) {
    testWidgets('all actual A2UI gallery states fit $size at maximum text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(3.12)),
            child: child!,
          ),
          home: const FinalizedComponentGallery(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      final state = tester.state<FinalizedComponentGalleryState>(
        find.byType(FinalizedComponentGallery),
      );
      for (final item in state.items) {
        for (var variant = 0; variant < item.exampleData.length; variant++) {
          state.select(item.name, variant);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            tester.takeException(),
            isNull,
            reason: '${item.name}/$variant at $size',
          );
        }
      }
    });
  }
}
