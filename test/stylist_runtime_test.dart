import 'dart:async';

import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

const products = [
  Product(
    id: 'dress-1',
    category: ProductCategory.dress,
    name: 'Linen dress',
    brand: 'Sample',
    price: 80,
    meta: 'Blue · Linen',
    tag: 'Summer',
    swatch: '#123456',
    color: 'blue',
    material: 'linen',
    occasion: 'travel',
    season: 'summer',
    imageAsset: 'assets/images/products/demo-1.jpg',
  ),
  Product(
    id: 'dress-2',
    category: ProductCategory.dress,
    name: 'Silk dress',
    brand: 'Sample',
    price: 150,
    meta: 'Black · Silk',
    tag: 'Formal',
    swatch: '#000000',
    color: 'black',
    season: 'all-season',
    occasion: 'celebration',
  ),
  Product(
    id: 'shoes-1',
    category: ProductCategory.shoes,
    name: 'Leather sandals',
    brand: 'Sample',
    price: 40,
    meta: 'Tan · Leather',
    tag: 'Summer',
    swatch: '#123456',
    color: 'tan',
    season: 'summer',
    occasion: 'travel',
  ),
];

ModelResponse textResponse(String text, {FinishReason? reason}) =>
    ModelResponse(
      finishReason: reason ?? FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [TextPart(text: text)],
      ),
    );
ModelResponse toolResponse(String name, Map<String, dynamic> input) =>
    ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(
        role: Role.model,
        content: [
          ToolRequestPart(
            toolRequest: ToolRequest(
              name: name,
              ref: 'ref-$name',
              input: input,
            ),
          ),
        ],
      ),
    );
Map<String, dynamic> action(String name, String id) => {
  'action': {
    'name': name,
    'context': {'productId': id},
  },
};

void main() {
  test(
    'Genkit tools produce authoritative cards and persistent outfit surfaces',
    () async {
      final runtime = StylistRuntime(products: products);
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'A summer dress under €100',
      });
      expect((result['products'] as List).single['id'], 'dress-1');
      expect(result['outfit']['budget'], 100);
      final messages = result['messages'] as List;
      final cards = messages.firstWhere(
        (m) => m['updateDataModel']?['surfaceId'] == 'inline-1',
      )['updateDataModel']['value']['recommendations'];
      expect(cards.single['name'], 'Linen dress');
      expect(cards.single['imageAsset'], products.first.imageAsset);
      await runtime.turn(action('select_product', 'dress-1'));
      expect(runtime.outfit['items'], {'dress': 'dress-1'});
      await runtime.turn(action('remove_product', 'dress-1'));
      expect(runtime.outfit['items'], isEmpty);
    },
  );

  test(
    'unknown selections and over-budget selections never call a model',
    () async {
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (r) {
          calls++;
          return offlineStylistModel(r);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A dress under €200'});
      await runtime.turn({'message': 'Change budget to €100'});
      final before = calls;
      await expectLater(
        runtime.turn(action('select_product', 'invented')),
        throwsStateError,
      );
      await expectLater(
        runtime.turn(action('select_product', 'dress-2')),
        throwsStateError,
      );
      expect(calls, before);
      expect(runtime.outfit['items'], isEmpty);
    },
  );

  test('failed action rolls back outfit, budget, history, and turn number before retry', () async {
    var fail = false;
    final runtime = StylistRuntime(
      products: products,
      model: (r) async {
        if (fail) throw StateError('provider failed');
        return offlineStylistModel(r);
      },
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A dress under €200'});
    fail = true;
    await expectLater(
      runtime.turn(action('select_product', 'dress-1')),
      throwsStateError,
    );
    expect(runtime.outfit['items'], isEmpty);
    expect(runtime.outfit['budget'], 200);
    fail = false;
    final result = await runtime.turn(action('select_product', 'dress-1'));
    expect(runtime.outfit['items'], {'dress': 'dress-1'});
    expect(
      (result['messages'] as List).any(
        (m) => m['createSurface']?['surfaceId'] == 'inline-2',
      ),
      isTrue,
    );
  });

  for (final ids in [
    <String>[],
    ['invented'],
    ['dress-1', 'dress-1'],
    List.filled(6, 'dress-1'),
  ]) {
    test('presentation rejects invalid IDs $ids', () async {
      var count = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (r) async {
          if (++count == 1) {
            return toolResponse('search_products', {'query': 'dress'});
          }
          if (count == 2) {
            return toolResponse('present_products', {'productIds': ids});
          }
          expect(
            r.messages.last.content.last.toolResponse!.output,
            containsPair('error', isA<String>()),
          );
          return textResponse('Choose again');
        },
      );
      addTearDown(runtime.dispose);
      expect(
        (await runtime.turn({'message': 'Under €200'}))['products'],
        isEmpty,
      );
    });
  }

  test(
    'presentation rechecks remaining budget for previously seen IDs',
    () async {
      var bad = false;
      final runtime = StylistRuntime(
        products: products,
        model: (r) async {
          if (!bad) return offlineStylistModel(r);
          if (r.messages.last.role == Role.user) {
            return toolResponse('present_products', {
              'productIds': ['dress-2'],
            });
          }
          expect(
            r.messages.last.content.last.toolResponse!.output,
            containsPair('error', isA<String>()),
          );
          return textResponse('Find something cheaper');
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'Under €200'});
      bad = true;
      expect(
        (await runtime.turn({'message': 'Under €100'}))['products'],
        isEmpty,
      );
    },
  );

  test(
    'fourth request is prose-only and repeated tools cannot trigger a fifth',
    () async {
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (r) async {
          calls++;
          if (calls == 4) {
            expect(r.tools, isEmpty);
            expect(r.toolChoice, 'none');
          }
          return toolResponse('search_products', {'query': 'dress'});
        },
      );
      addTearDown(runtime.dispose);
      await expectLater(
        runtime.turn({'message': 'Under €200'}),
        throwsStateError,
      );
      expect(calls, 4);
      expect(runtime.outfit['budget'], isNull);
    },
  );

  test('truncated generation never publishes a partial turn', () async {
    final runtime = StylistRuntime(
      products: products,
      model: (r) async => textResponse('Partial', reason: FinishReason.length),
    );
    addTearDown(runtime.dispose);
    await expectLater(
      runtime.turn({'message': 'Under €200'}),
      throwsStateError,
    );
    expect(runtime.outfit['budget'], isNull);
  });

  test(
    'queued turns serialize and two connections keep state isolated',
    () async {
      final entered = Completer<void>();
      final waiting = Completer<void>();
      var calls = 0;
      final first = StylistRuntime(
        products: products,
        model: (r) async {
          if (++calls == 1) {
            entered.complete();
            await waiting.future;
          }
          return offlineStylistModel(r);
        },
      );
      final second = StylistRuntime(products: products);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final a = first.turn({'message': 'Under €100'});
      await entered.future;
      final b = first.turn({'message': 'Under €120'});
      await second.turn({'message': 'Under €300'});
      expect(calls, 1);
      waiting.complete();
      await Future.wait([a, b]);
      expect(first.outfit['budget'], 120);
      expect(second.outfit['budget'], 300);
    },
  );

  test('disconnect cancels generation and ignores late response', () async {
    final entered = Completer<void>();
    final response = Completer<ModelResponse>();
    var calls = 0;
    final runtime = StylistRuntime(
      products: products,
      model: (r) {
        calls++;
        entered.complete();
        return response.future;
      },
    );
    final pending = expectLater(
      runtime.turn({'message': 'Under €100'}),
      throwsA(anything),
    );
    await entered.future;
    await runtime.dispose();
    response.complete(toolResponse('search_products', {'query': 'dress'}));
    await pending;
    expect(calls, 1);
    expect(runtime.outfit['budget'], isNull);
  });

  test('budget parsing preserves decimal and grouped euro amounts', () {
    for (final entry in {
      'under €1,200': 1200.0,
      '€1.200,50': 1200.5,
      '100,50 EUR': 100.5,
      '€0': 0.0,
    }.entries) {
      expect(parseStylistBudget(entry.key), entry.value);
    }
    expect(parseStylistBudget('under a hundred'), isNull);
  });

  test('search ranks titles, filters facets, caps prices and returns bundled facts', () {
    expect(
      searchStylistProducts(products, {
        'query': 'dress',
        'priceMax': 100,
      }).single.id,
      'dress-1',
    );
    expect(
      searchStylistProducts(products, {
        'query': 'dress',
        'color': 'black',
      }).single.id,
      'dress-2',
    );
    expect(
      searchStylistProducts(products, {
        'query': 'sandals',
        'season': 'summer',
      }).single.id,
      'shoes-1',
    );
    expect(
      searchStylistProducts(products, {'query': 'not-in-catalog'}),
      isEmpty,
    );
  });
}
