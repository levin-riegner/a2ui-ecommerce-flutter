import 'package:a2ui_flutter_commerce/src/agent/product_facts.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_command.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_schemas.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'shared brief schemas agree on positive budgets and date fields',
    () async {
      for (final budget in [0, -1]) {
        expect(
          await stylistBriefSchema.validate({'budget': budget}),
          isNotEmpty,
        );
        expect(
          await stylistChangesSchema.validate({
            'brief': {'budget': budget},
          }),
          isNotEmpty,
        );
      }
      final patch = {
        'budget': 100.01,
        'tripStart': '2026-10-16',
        'tripEnd': '2026-10-18',
      };
      expect(await stylistBriefSchema.validate(patch), isEmpty);
      expect(await stylistChangesSchema.validate({'brief': patch}), isEmpty);
      expect(
        await stylistBriefSchema.validate({'tripStart': 'tomorrow'}),
        isNotEmpty,
      );
    },
  );

  test(
    'presentation schema advertises the enforced ID bounds and uniqueness',
    () async {
      for (final ids in [
        <String>[],
        ['a', 'a'],
        List.generate(6, (i) => '$i'),
        [''],
      ]) {
        expect(
          await stylistPresentSchema.validate({'productIds': ids}),
          isNotEmpty,
        );
      }
      expect(
        await stylistPresentSchema.validate({
          'productIds': ['a', 'b'],
        }),
        isEmpty,
      );
    },
  );

  test(
    'named command decoder rejects unknown and malformed actions safely',
    () async {
      for (final raw in [
        null,
        {'name': 42},
        {'name': 'checkout', 'context': {}},
        {
          'name': 'select_product',
          'context': {'productId': 42},
        },
      ]) {
        await expectLater(
          StylistCommand.decode(raw),
          throwsA(isA<StylistInputError>()),
        );
      }
      final command = await StylistCommand.decode({
        'name': 'select_product',
        'context': {'productId': 'p1'},
      });
      expect(command.kind, StylistCommandKind.selectProduct);
      expect(command.productId, 'p1');
      expect(() => command.context['productId'] = 'p2', throwsUnsupportedError);
      expect(
        stylistCommandContexts.keys.toSet(),
        StylistCommandKind.values.map((v) => v.wireName).toSet(),
      );
    },
  );

  test('command contexts are copied and recursively immutable', () async {
    final colors = ['Blue'];
    final command = await StylistCommand.decode({
      'name': 'update_preferences',
      'context': {'colours': colors},
    });
    colors.add('Red');
    expect(command.context['colours'], ['Blue']);
    expect(
      () => (command.context['colours'] as List).add('Green'),
      throwsUnsupportedError,
    );
  });

  test(
    'tool response contracts require meaningful success or corrective error',
    () async {
      for (final name in [
        'respond_to_question',
        'search_products',
        'present_products',
        'save_outfit',
        'add_to_outfit',
        'remove_from_outfit',
        'apply_outfit_changes',
      ]) {
        final schema = stylistToolOutputSchema(name);
        expect(
          await schema.validate(<String, Object?>{}),
          isNotEmpty,
          reason: name,
        );
        expect(
          await schema.validate({
            'code': 'invalid_input',
            'error': 'Choose a compatible product.',
          }),
          isEmpty,
          reason: name,
        );
        expect(await schema.validate({'error': ''}), isNotEmpty, reason: name);
      }
      expect(
        await stylistToolOutputSchema('present_products').validate({
          'presentedIds': ['p1'],
        }),
        isEmpty,
      );
    },
  );

  test('model product facts identify host-derived classifications', () async {
    const product = Product(
      id: 'p1',
      category: ProductCategory.top,
      name: 'Blue shirt',
      brand: 'Demo',
      price: 100.01,
      meta: 'cotton',
      tag: 'casual',
      swatch: '#0000ff',
      color: 'blue',
    );
    final facts = ProductFacts(product).toJson();
    expect(facts['price_eur'], 100.01);
    expect(facts['derived_provenance'], {
      'garment_type': 'host_catalog_semantics_v1',
      'color_families': 'host_catalog_semantics_v1',
    });
    expect(
      await stylistObjectSchema(productFactsJsonSchema).validate(facts),
      isEmpty,
    );
  });
}
