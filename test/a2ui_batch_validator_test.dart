import 'dart:convert';
import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/a2ui_batch_validator.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

List<core.A2uiMessage> events(List<dynamic> messages) => messages
    .map(
      (raw) => core.A2uiMessage.fromJson(Map<String, dynamic>.from(raw as Map)),
    )
    .toList();
List<dynamic> fixture() => jsonDecode(
  File('test/fixtures/protocol/recommendations.json').readAsStringSync(),
) as List;

void main() {
  test('a draft-bound choice chip needs no model action', () {
    final catalog = buildCommerceCatalog();
    final item = catalog.items.singleWhere((item) => item.name == 'ChoiceChip');
    final validator = A2uiBatchValidator(catalog);
    expect(
      item.dataSchema.validateSync({
        'id': 'owned-shoes',
        'component': 'ChoiceChip',
        'label': 'Shoes',
        'selected': {'path': '/ownedPieces/shoes'},
      }, schemaRegistry: validator.registry),
      isEmpty,
    );
  });
  test('candidate publication accepts the real recorded host fixture', () {
    A2uiBatchValidator(buildCommerceCatalog()).validate(events(fixture()));
  });
  test('invalid catalog properties reject before renderer publication', () {
    final messages = fixture();
    final update = messages.firstWhere(
      (row) => row['updateComponents'] != null,
    )['updateComponents'];
    final root = (update['components'] as List).firstWhere(
      (row) => row['id'] == 'root',
    );
    root['title'] = 42;
    expect(
      () =>
          A2uiBatchValidator(buildCommerceCatalog()).validate(events(messages)),
      throwsFormatException,
    );
  });
  test('dangling and cyclic child references reject before publication', () {
    for (final reference in ['missing', 'root']) {
      final messages = fixture();
      final update = messages.firstWhere(
        (row) => row['updateComponents'] != null,
      )['updateComponents'];
      final root = (update['components'] as List).firstWhere(
        (row) => row['id'] == 'root',
      );
      root['children'] = [reference];
      expect(
        () =>
            A2uiBatchValidator(buildCommerceCatalog())
                .validate(events(messages)),
        throwsFormatException,
      );
    }
  });
}
