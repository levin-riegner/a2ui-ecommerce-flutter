import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';

import 'stylist_component_adoption_test.dart' show components;
import 'stylist_library_test.dart' show event, data;
import 'stylist_runtime_test.dart' show textResponse, toolResponse;
import 'stylist_store_helpers.dart';

const dress = Product(
  id: 'review-dress',
  category: ProductCategory.dress,
  name: 'Blue dress',
  brand: 'Alder',
  price: 80,
  meta: 'Blue',
  tag: 'Summer',
  swatch: '#3344ff',
  color: 'blue',
  gender: 'female',
  sizeOptions: ['M'],
  material: 'linen',
);
const brief =
    "Women's dress for summer under €500; I already own shoes and I already own a bag";

Future<void> buy(StylistRuntime runtime, int quantity) async {
  await runtime.turn(event('add_look_to_bag'));
  await runtime.turn(
    event('change_bag_quantity', {'productId': dress.id, 'quantity': quantity}),
  );
  final quote = await runtime.turn(event('preview_demo_checkout'));
  final button = components(quote)
      .singleWhere((c) => c['id'] == 'confirm-demo-checkout');
  await runtime.turn(
    event(
      'confirm_demo_checkout',
      Map<String, Object?>.from(button['action']['event']['context']),
    ),
  );
}

void main() {
  test('current stock survives reload and exhausted products cannot be recommended or selected', () async {
    final store = MemoryStylistStore();
    var runtime = StylistRuntime(products: [dress], store: store);
    await runtime.turn({'message': brief});
    await runtime.turn(event('select_product', {'productId': dress.id}));
    await buy(runtime, 5);
    await runtime.dispose();
    runtime = StylistRuntime(products: [dress], store: store);
    addTearDown(runtime.dispose);
    await runtime.loadLocalState();
    await runtime.turn(event('reset_look'));
    final remaining = await runtime.turn({'message': brief});
    expect(remaining['products'].single['demo_variants'].single['stock'], 1);
    await runtime.turn(event('select_product', {'productId': dress.id}));
    await buy(runtime, 1);
    await expectLater(
      runtime.turn(event('select_product', {'productId': dress.id})),
      throwsA(isA<StylistInputError>()),
    );
    await runtime.turn(event('reset_look'));
    final exhausted = await runtime.turn({'message': brief});
    expect(exhausted['products'], isEmpty);
    expect(exhausted['outfit']['items'], isEmpty);
    expect(data(exhausted)['recommendations'], isEmpty);
  });

  test(
    'material questions use catalog facts and do not open a size editor',
    () async {
      var questioning = false, answered = false;
      final runtime = StylistRuntime(
        products: [dress],
        model: (request) async {
          if (questioning) {
            if (request.messages.last.role == Role.user) {
              return toolResponse('respond_to_question', {
                'intent': 'styling_advice',
                'facts': <String>[],
              });
            }
            expect(request.messages.first.text, contains('linen'));
            answered = true;
            return textResponse('The catalog lists linen.');
          }
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': brief});
      await runtime.turn(event('select_product', {'productId': dress.id}));
      questioning = true;
      final result = await runtime.turn({
        'message': 'What material is this dress?',
      });
      expect(answered, isTrue);
      expect(result.reply, contains('The catalog lists linen.'));
      expect(result.view.productDetails, isNull);
      expect(result.view.selectionOptions, isNull);
    },
  );

  test(
    'colour changes retain a variant at an exact cent budget boundary',
    () async {
      const blue = Product(
        id: 'cent-blue',
        category: ProductCategory.dress,
        name: 'Blue dress',
        brand: 'Alder',
        price: .20,
        meta: 'Blue',
        tag: 'Summer',
        swatch: '#3344ff',
        color: 'blue',
        gender: 'female',
        sizeOptions: ['M'],
        variantGroup: 'cent-dress',
      );
      const black = Product(
        id: 'cent-black',
        category: ProductCategory.dress,
        name: 'Black dress',
        brand: 'Alder',
        price: .20,
        meta: 'Black',
        tag: 'Summer',
        swatch: '#111111',
        color: 'black',
        gender: 'female',
        sizeOptions: ['M'],
        variantGroup: 'cent-dress',
      );
      const shoes = Product(
        id: 'cent-shoes',
        category: ProductCategory.shoes,
        name: 'Sandals',
        brand: 'Alder',
        price: .10,
        meta: 'Black',
        tag: 'Summer',
        swatch: '#111111',
        gender: 'female',
        sizeOptions: ['41'],
      );
      final runtime = StylistRuntime(products: [blue, black, shoes]);
      addTearDown(runtime.dispose);
      await runtime.turn({
        'message': "Women's summer dress under €0.30; I already own a bag",
      });
      await runtime.turn(event('select_product', {'productId': blue.id}));
      await runtime.turn(event('select_product', {'productId': shoes.id}));
      await runtime.turn(
        event('choose_product_colour', {
          'productId': blue.id,
          'colour': 'Black',
        }),
      );
      expect(runtime.outfit['items'], {'dress': black.id, 'shoes': shoes.id});
    },
  );
}
