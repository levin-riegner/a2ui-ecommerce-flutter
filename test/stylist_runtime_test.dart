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
  Product(
    id: 'top-1',
    category: ProductCategory.top,
    name: 'Cotton shirt',
    brand: 'Sample',
    price: 60,
    meta: 'Blue · Cotton',
    tag: 'Everyday',
    swatch: '#123456',
    season: 'all-season',
    occasion: 'work',
  ),
  Product(
    id: 'bottom-1',
    category: ProductCategory.bottom,
    name: 'Linen trousers',
    brand: 'Sample',
    price: 70,
    meta: 'Blue · Cotton',
    tag: 'Everyday',
    swatch: '#123456',
    season: 'all-season',
    occasion: 'work',
  ),
  Product(
    id: 'bag-1',
    category: ProductCategory.bag,
    name: 'Canvas tote',
    brand: 'Sample',
    price: 30,
    meta: 'Blue · Cotton',
    tag: 'Everyday',
    swatch: '#123456',
    season: 'all-season',
    occasion: 'work',
  ),
  Product(
    id: 'layer-1',
    category: ProductCategory.layer,
    name: 'Wool jacket',
    brand: 'Sample',
    price: 50,
    meta: 'Blue · Cotton',
    tag: 'Everyday',
    swatch: '#123456',
    season: 'all-season',
    occasion: 'work',
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
    'action confirmations preserve styling guidance and host budget in history',
    () async {
      var afterOpening = false;
      var removing = false;
      var checkedHistory = false;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (afterOpening &&
              request.messages.last.role == Role.user &&
              removing) {
            final previous = request.messages
                .where((message) => message.role == Role.model)
                .last
                .text;
            expect(
              previous,
              contains('Selected Linen dress. €120.00 left in your budget.'),
            );
            expect(previous, contains('The linen keeps the look relaxed.'));
            expect(previous, isNot(contains('€5')));
            checkedHistory = true;
          }
          final response = await offlineStylistModel(request);
          if (afterOpening &&
              response.message!.content.every((part) => part.isText)) {
            return textResponse(
              'Your remaining budget is €5. The linen keeps the look relaxed.',
            );
          }
          return response;
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A dress under €200'});
      afterOpening = true;
      final selected = await runtime.turn(action('select_product', 'dress-1'));
      expect(
        selected['reply'],
        contains('Selected Linen dress. €120.00 left in your budget.'),
      );
      expect(selected['reply'], contains('The linen keeps the look relaxed.'));
      expect(selected['reply'], isNot(contains('€5')));
      expect(
        (selected['products'] as List).every((p) => p['category'] == 'shoes'),
        isTrue,
      );
      removing = true;
      final removed = await runtime.turn(action('remove_product', 'dress-1'));
      expect(checkedHistory, isTrue);
      expect(
        removed['reply'],
        contains('Removed Linen dress. €200.00 left in your budget.'),
      );
      expect(
        (removed['products'] as List).every((p) => p['category'] == 'dress'),
        isTrue,
      );
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
      await expectLater(
        runtime.turn({'message': 'A dress under €200'}),
        throwsStateError,
      );
      expect(runtime.outfit['budget'], isNull);
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
      await runtime.turn({'message': 'A dress under €200'});
      bad = true;
      await expectLater(
        runtime.turn({'message': 'A dress under €100'}),
        throwsStateError,
      );
      expect(runtime.outfit['budget'], 200);
    },
  );

  test(
    'two searches leave time to present cards and finish within four requests',
    () async {
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          calls++;
          if (calls <= 2) {
            return toolResponse('search_products', {
              'query': calls == 1 ? 'linen' : 'dress',
            });
          }
          if (calls == 3) {
            expect(request.tools!.map((tool) => tool.name), [
              'present_products',
            ]);
            return toolResponse('present_products', {
              'productIds': ['dress-1', 'dress-2'],
            });
          }
          expect(request.tools, isEmpty);
          return textResponse('A linen dress with leather sandals.');
        },
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({'message': 'Summer dress under €200'});
      expect((result['products'] as List).map((p) => p['id']), [
        'dress-1',
        'dress-2',
      ]);
      expect(result['reply'], 'A linen dress with leather sandals.');
      expect(calls, 4);
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
          return toolResponse('search_products', {'query': 'not-in-catalog'});
        },
      );
      addTearDown(runtime.dispose);
      await expectLater(
        runtime.turn({'message': 'A dress under €200'}),
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
      runtime.turn({'message': 'A dress under €200'}),
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
      final a = first.turn({'message': 'A dress under €100'});
      await entered.future;
      final b = first.turn({'message': 'A dress under €120'});
      await second.turn({'message': 'A dress under €300'});
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
      runtime.turn({'message': 'A dress under €100'}),
      throwsA(anything),
    );
    await entered.future;
    await runtime.dispose();
    response.complete(toolResponse('search_products', {'query': 'dress'}));
    await pending;
    expect(calls, 1);
    expect(runtime.outfit['budget'], isNull);
  });

  test(
    'verbal second choice and removal continue within four requests',
    () async {
      var edit = '';
      var calls = 0;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          calls++;
          if (edit.isNotEmpty && request.messages.last.role == Role.user) {
            expect(request.messages.first.text, contains('Last presented IDs'));
            return toolResponse(edit, {'productId': 'dress-2'});
          }
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A dress under €300'});
      edit = 'add_to_outfit';
      calls = 0;
      final picked = await runtime.turn({
        'message': 'I’ll take the second one',
      });
      expect(calls, 4);
      expect(runtime.outfit['items'], {'dress': 'dress-2'});
      expect(picked['reply'], contains('Selected Silk dress. €150.00'));
      expect(
        (picked['products'] as List).every((p) => p['category'] == 'shoes'),
        isTrue,
      );
      edit = 'remove_from_outfit';
      calls = 0;
      final removed = await runtime.turn({'message': 'Remove that dress'});
      expect(calls, 4);
      expect(runtime.outfit['items'], isEmpty);
      expect(
        (removed['products'] as List).every((p) => p['category'] == 'dress'),
        isTrue,
      );
    },
  );

  test(
    'verbal selections reject IDs outside the last displayed choices',
    () async {
      var bad = false;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (!bad) return offlineStylistModel(request);
          if (request.messages.last.role == Role.user) {
            return toolResponse('add_to_outfit', {'productId': 'invented'});
          }
          expect(
            request.messages.last.content.last.toolResponse!.output,
            containsPair('error', isA<String>()),
          );
          return textResponse('Selected the invented product.');
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A dress under €300'});
      bad = true;
      await expectLater(
        runtime.turn({'message': 'Pick the second one'}),
        throwsStateError,
      );
      expect(runtime.outfit['items'], isEmpty);
      expect(runtime.outfit['budget'], 300);
    },
  );

  test('missing brief fields block searching and host submission starts recommendations', () async {
    var triedSearch = false;
    final runtime = StylistRuntime(
      products: products,
      model: (request) async {
        if (!triedSearch &&
            request.messages.first.text.contains('Searching is blocked')) {
          triedSearch = true;
          return toolResponse('search_products', {'query': 'dress'});
        }
        if (request.messages.last.role == Role.tool &&
            (request.messages.last.content.last.toolResponse!.output as Map)
                .containsKey('missingFields')) {
          return textResponse('What style and budget should I use?');
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    final greeting = await runtime.turn({
      'message': 'I need something for an interview',
    });
    expect(greeting['missingFields'], ['dressCode', 'budget']);
    expect(greeting['products'], isEmpty);
    expect(greeting['reply'], isNot(contains('complete')));
    final ready = await runtime.turn({
      'action': {
        'name': 'find_options',
        'context': {
          'dressCode': 'smart-casual',
          'season': 'summer',
          'budget': 300,
        },
      },
    });
    expect(ready['missingFields'], isEmpty);
    expect(
      (ready['products'] as List).every((p) => p['category'] == 'top'),
      isTrue,
    );
    expect(ready['brief']['occasion'], contains('interview'));
  });

  test(
    'save_outfit retains explicit preferences and replaces obsolete season',
    () async {
      var saving = false;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (saving && request.messages.last.role == Role.user) {
            return toolResponse('save_outfit', {
              'season': 'summer',
              'palette': 'blue',
              'notes': 'avoid heels',
            });
          }
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'Smart casual winter work under €300'});
      saving = true;
      final updated = await runtime.turn({
        'message': 'Change the season and prefer blue',
      });
      expect(updated['brief']['season'], 'summer');
      expect(updated['brief']['palette'], 'blue');
      expect(updated['brief']['notes'], 'avoid heels');
      expect(updated['brief']['occasion'], 'work');
      expect(updated['brief']['budget'], 300);
      final data = (updated['messages'] as List).firstWhere(
        (m) => m['updateDataModel']?['surfaceId'] == 'dressing-room',
      )['updateDataModel']['value'];
      expect(data['brief'], contains('summer'));
      expect(data['brief'], isNot(contains('winter')));
    },
  );

  test(
    'foundation swaps refund conflicting pieces before budget admission',
    () async {
      final runtime = StylistRuntime(products: products);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A casual top under €180'});
      await runtime.turn(action('select_product', 'top-1'));
      await runtime.turn(action('select_product', 'bottom-1'));
      final dresses = await runtime.turn({'message': 'Show a dress instead'});
      expect(
        (dresses['products'] as List).map((p) => p['id']),
        contains('dress-2'),
      );
      await runtime.turn(action('select_product', 'dress-2'));
      expect(runtime.outfit['items'], {'dress': 'dress-2'});
      final tops = await runtime.turn({'message': 'Show a top instead'});
      expect((tops['products'] as List).map((p) => p['id']), contains('top-1'));
      await runtime.turn(action('select_product', 'top-1'));
      expect(runtime.outfit['items'], {'top': 'top-1'});
    },
  );

  test('budget exhaustion offers a meaningful next decision without unaffordable cards', () async {
    final runtime = StylistRuntime(products: products);
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A dress under €80'});
    final picked = await runtime.turn(action('select_product', 'dress-1'));
    expect(picked['products'], isEmpty);
    expect(picked['reply'], contains('€0.00 left'));
    expect(picked['reply'], contains('raise the budget or replace'));
    expect(picked['reply'], isNot(contains('look is complete')));
    expect(runtime.outfit['items'], {'dress': 'dress-1'});
  });

  test('completed looks allow verbal removal and preference updates', () async {
    var editing = '';
    var calls = 0;
    final runtime = StylistRuntime(
      products: products,
      model: (request) async {
        calls++;
        if (editing.isNotEmpty && request.messages.last.role == Role.user) {
          expect(
            request.tools!.map((tool) => tool.name),
            isNot(contains('search_products')),
          );
          return editing == 'palette'
              ? toolResponse('save_outfit', {'palette': 'blue'})
              : toolResponse('remove_from_outfit', {'productId': 'bag-1'});
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A summer dress under €300'});
    await runtime.turn(action('select_product', 'dress-1'));
    await runtime.turn(action('select_product', 'shoes-1'));
    final complete = await runtime.turn(action('select_product', 'bag-1'));
    expect(complete['reply'], contains('complete'));
    editing = 'palette';
    calls = 0;
    final palette = await runtime.turn({'message': 'Make it blue'});
    expect(palette['brief']['palette'], 'blue');
    expect(palette['products'], isEmpty);
    expect(calls, 2);
    editing = 'remove';
    calls = 0;
    final removed = await runtime.turn({'message': 'Remove the bag'});
    expect(calls, 4);
    expect((runtime.outfit['items'] as Map).containsKey('bag'), isFalse);
    expect(
      (removed['products'] as List).every((p) => p['category'] == 'bag'),
      isTrue,
    );
    expect(removed['reply'], isNot(contains('look is complete')));
  });

  test('dress code refinement follows the separates plan instead of matching dress', () async {
    var changing = false;
    final runtime = StylistRuntime(
      products: products,
      model: (request) async {
        if (changing && request.messages.last.role == Role.user) {
          return toolResponse('save_outfit', {'dressCode': 'casual'});
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    runtime.reset(journey: DemoJourney.berlin);
    await runtime.turn({
      'message': '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}',
    });
    changing = true;
    final updated = await runtime.turn({
      'message': 'Change the dress code to casual',
    });
    expect(updated['brief']['dressCode'], 'casual');
    expect(
      (updated['products'] as List).every((p) => p['category'] == 'top'),
      isTrue,
    );
  });

  test(
    'a late plan edit cannot reuse search results for a different category',
    () async {
      var requests = 0;
      var bad = true;
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          if (!bad) return offlineStylistModel(request);
          requests++;
          if (requests == 1) {
            return toolResponse('search_products', {'query': 'top'});
          }
          expect(
            request.tools!.map((tool) => tool.name),
            isNot(contains('save_outfit')),
          );
          return toolResponse('save_outfit', {'dressCode': 'black-tie'});
        },
      );
      addTearDown(runtime.dispose);
      runtime.reset(journey: DemoJourney.berlin);
      final message =
          '${DemoJourney.berlin.title}. ${DemoJourney.berlin.brief}';
      await expectLater(runtime.turn({'message': message}), throwsStateError);
      expect(requests, 2);
      expect(runtime.outfit['budget'], 900);
      expect(runtime.outfit['items'], isEmpty);
      bad = false;
      final retried = await runtime.turn({'message': message});
      expect(retried['brief']['dressCode'], 'smart-casual');
      expect(
        (retried['products'] as List).every((p) => p['category'] == 'top'),
        isTrue,
      );
    },
  );

  test('budget parsing preserves decimal and grouped euro amounts', () {
    for (final entry in {
      'under €1,200': 1200.0,
      '€1.200,50': 1200.5,
      '100,50 EUR': 100.5,
      'under 100€': 100.0,
      'under 100 €': 100.0,
      '100,50 €': 100.5,
      '€0': 0.0,
    }.entries) {
      expect(parseStylistBudget(entry.key), entry.value);
    }
    expect(parseStylistBudget('under a hundred'), isNull);
  });

  test('suffix-euro budget changes prevent unaffordable selections', () async {
    var calls = 0;
    final runtime = StylistRuntime(
      products: products,
      model: (request) {
        calls++;
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A dress under €200'});
    await runtime.turn({'message': 'Change my budget to 40 €'});
    expect(runtime.outfit['budget'], 40);
    final before = calls;
    await expectLater(
      runtime.turn(action('select_product', 'dress-1')),
      throwsStateError,
    );
    expect(calls, before);
    expect(runtime.outfit['items'], isEmpty);
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
