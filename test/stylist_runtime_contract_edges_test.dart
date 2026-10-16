import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/outfit_plan.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_constraints.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

import 'stylist_runtime_test.dart' show products, action, toolResponse;

void main() {
  test('an otherwise filled look stays incomplete while restrictions need clarification', () {
    final plan = OutfitPlan.from(
      brief: 'summer dress',
      dressCode: 'dress',
      outfit: {
        for (final id in ['dress-1', 'shoes-1', 'bag-1'])
          products.singleWhere((p) => p.id == id).category.name: products
              .singleWhere((p) => p.id == id),
      },
      constraints: const StylistConstraints(
        clarificationRequests: ['Which pieces need the color restriction?'],
      ),
    );
    expect(plan.nextCategory, isNull);
    expect(plan.complete, isFalse);
  });
  test(
    'foreign outfit currency asks for EUR before making a model request',
    () async {
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (request) {
          calls++;
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await expectLater(
        runtime.turn({'message': 'My outfit budget is \$500'}),
        throwsA(
          isA<StylistInputError>()
              .having((e) => e.code, 'code', StylistInputErrorCode.invalidBrief)
              .having((e) => e.message, 'message', contains('euros')),
        ),
      );
      expect(calls, 0);
      expect(runtime.outfit['budget'], isNull);
      final corrected = await runtime.turn({'message': 'Casual under €500'});
      expect(corrected['brief']['budget'], 500);
    },
  );

  test('a model cannot invent the missing required dress code', () async {
    var first = true;
    final runtime = StylistRuntime(
      products: products,
      model: (request) {
        if (first) {
          first = false;
          return Future.value(
            toolResponse('save_outfit', {'dressCode': 'casual'}),
          );
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': 'I have 500 to spend on an outfit',
    });
    expect(result['brief']['budget'], 500);
    expect(result['missingFields'], ['dressCode']);
    expect(result['products'], isEmpty);
    expect(result['reply'], contains('€500'));
  });

  test('two additions in one category reject the whole atomic turn', () async {
    var selecting = false;
    final runtime = StylistRuntime(
      products: products,
      model: (request) {
        if (selecting && request.messages.last.role == Role.user) {
          return Future.value(
            toolResponse('apply_outfit_changes', {
              'addProductIds': ['dress-1', 'dress-2'],
            }),
          );
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    final initial = await runtime.turn({'message': 'A dress under €500'});
    expect(
      (initial['products'] as List).map((p) => p['id']),
      containsAll(['dress-1', 'dress-2']),
    );
    selecting = true;
    await expectLater(
      runtime.turn({'message': 'Choose both dresses'}),
      throwsA(
        isA<StylistInputError>().having(
          (e) => e.message,
          'message',
          contains('one product'),
        ),
      ),
    );
    expect(runtime.outfit['items'], isEmpty);
    expect(runtime.outfit['budget'], 500);
  });

  test('offline completed look can acknowledge a soft preference without searching', () async {
    final runtime = StylistRuntime(products: products);
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A summer dress under €500'});
    await runtime.turn(action('select_product', 'dress-1'));
    await runtime.turn(action('select_product', 'shoes-1'));
    await runtime.turn(action('select_product', 'bag-1'));
    final updated = await runtime.turn({'message': 'I prefer blue'});
    expect(updated['reply'], contains('preferred colors: blue'));
    expect(updated['reply'], contains('look is complete'));
    expect(updated['products'], isEmpty);
  });
}
