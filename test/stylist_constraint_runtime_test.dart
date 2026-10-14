import 'package:a2ui_flutter_commerce/src/agent/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

Product _piece(
  String id,
  ProductCategory category,
  double price, {
  String color = 'red',
  String material = 'cotton',
  String brand = 'Sample',
}) => Product(
  id: id,
  category: category,
  name: 'Cotton ${category.name}',
  brand: brand,
  price: price,
  meta: '',
  tag: '',
  swatch: '#123456',
  color: color,
  material: material,
  occasion: 'travel',
  season: 'summer',
);

final _catalog = [
  _piece(
    'top-blue-wool',
    ProductCategory.top,
    50,
    color: 'blue',
    material: 'wool',
    brand: 'Acme',
  ),
  _piece('top-red-cotton', ProductCategory.top, 80),
  _piece('bottom-red', ProductCategory.bottom, 50),
  _piece('shoes-red', ProductCategory.shoes, 40),
  _piece('bag-red', ProductCategory.bag, 30),
  _piece('dress-red', ProductCategory.dress, 100),
];

ModelResponse _tool(String name, Map<String, dynamic> input) => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [
      ToolRequestPart(
        toolRequest: ToolRequest(name: name, ref: 'test-$name', input: input),
      ),
    ],
  ),
);

ModelResponse _text() => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [TextPart(text: 'Consider these catalog choices.')],
  ),
);

Map<String, dynamic> _select(String id) => {
  'action': {
    'name': 'select_product',
    'context': {'productId': id},
  },
};

List<String> _ids(Map<String, dynamic> result) => (result['products'] as List)
    .map((product) => product['id'] as String)
    .toList();

StylistModel _searchModel(
  Map<String, dynamic> filters, {
  void Function(Map<dynamic, dynamic> output)? inspect,
}) => (request) async {
  final last = request.messages.last;
  if (last.role == Role.user) return _tool('search_products', filters);
  final response = last.content.last.toolResponse!;
  if (response.name == 'search_products') {
    final output = response.output as Map;
    inspect?.call(output);
    final ids = (output['products'] as List)
        .map((product) => product['id'])
        .toList();
    return ids.isEmpty
        ? _text()
        : _tool('present_products', {'productIds': ids.take(5).toList()});
  }
  return _text();
};

void main() {
  test(
    'hard color/material/brand filters survive optional search fallback',
    () async {
      final runtime = StylistRuntime(
        products: _catalog,
        model: _searchModel(
          {
            'query': '',
            'color': 'blue',
            'occasion': 'work',
            'season': 'winter',
          },
          inspect: (output) {
            expect(
              (output['products'] as List).map((product) => product['id']),
              ['top-red-cotton'],
            );
          },
        ),
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message':
            'Casual summer outfit under €500. Only red, no wool, no Acme.',
      });
      expect(_ids(result), ['top-red-cotton']);
      expect(result['constraints']['allowedColors'], ['red']);
      expect(result['constraints']['excludedMaterials'], ['wool']);
      expect(result['constraints']['excludedBrands'], ['acme']);
      expect(result['reply'], contains('optional search filters'));
    },
  );

  test(
    'presentation rechecks stale seen products after a hard restriction',
    () async {
      var attack = false;
      var rejected = false;
      final runtime = StylistRuntime(
        products: _catalog,
        model: (request) async {
          if (!attack) return offlineStylistModel(request);
          final last = request.messages.last;
          if (last.role == Role.user) {
            return _tool('present_products', {
              'productIds': ['top-blue-wool'],
            });
          }
          final response = last.content.last.toolResponse!;
          if (response.name == 'present_products' &&
              (response.output as Map).containsKey('error')) {
            rejected = true;
            return _tool('search_products', {'query': ''});
          }
          if (response.name == 'search_products') {
            return _tool('present_products', {
              'productIds': ['top-red-cotton'],
            });
          }
          return _text();
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'Casual summer outfit under €500'});
      attack = true;
      final result = await runtime.turn({'message': 'Only red, no wool'});
      expect(rejected, isTrue);
      expect(_ids(result), ['top-red-cotton']);
      expect(runtime.outfit['items'], isEmpty);
    },
  );

  test(
    'selection rejects an old seen product that violates revised constraints',
    () async {
      var calls = 0;
      final runtime = StylistRuntime(
        products: _catalog,
        model: (request) async {
          calls++;
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'Casual summer outfit under €500'});
      await runtime.turn({'message': 'Only red, no wool'});
      final before = calls;
      await expectLater(
        runtime.turn(_select('top-blue-wool')),
        throwsA(isA<StylistInputError>()),
      );
      expect(calls, before);
      expect(runtime.outfit['items'], isEmpty);
      expect(runtime.outfit['budget'], 500);
    },
  );

  test(
    'affordable full outfits exclude a dress that strands the remaining pieces',
    () async {
      final catalog = [
        _piece('dress-expensive', ProductCategory.dress, 450),
        _piece('dress-affordable', ProductCategory.dress, 300),
        _piece('shoes', ProductCategory.shoes, 100),
        _piece('bag', ProductCategory.bag, 50),
      ];
      final runtime = StylistRuntime(products: catalog);
      addTearDown(runtime.dispose);
      final initial = await runtime.turn({
        'message': 'Formal summer outfit under €1000',
      });
      expect(_ids(initial), contains('dress-expensive'));
      final revised = await runtime.turn({
        'message': 'Reduce the outfit budget to €500',
      });
      expect(_ids(revised), ['dress-affordable']);
      await expectLater(
        runtime.turn(_select('dress-expensive')),
        throwsA(isA<StylistInputError>()),
      );
      expect(runtime.outfit['items'], isEmpty);
      await runtime.turn(_select('dress-affordable'));
      expect(runtime.outfit['items'], {'dress': 'dress-affordable'});
    },
  );

  test(
    'an impossible complete look remains explorable with an honest cost notice',
    () async {
      final runtime = StylistRuntime(
        products: [
          _piece('dress', ProductCategory.dress, 80),
          _piece('shoes', ProductCategory.shoes, 40),
          _piece('bag', ProductCategory.bag, 30),
        ],
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'A formal summer outfit under €100',
      });
      expect(_ids(result), ['dress']);
      expect(result['reply'], contains('€150.00'));
      expect(result['reply'], contains('at least'));
      final selected = await runtime.turn(_select('dress'));
      expect(runtime.outfit['items'], {'dress': 'dress'});
      expect(_ids(selected), isEmpty);
      expect(selected['reply'], contains('€150.00'));
      expect(selected['reply'], contains('use something you own'));
    },
  );

  test(
    'missing catalog categories get a distinct availability explanation',
    () async {
      final runtime = StylistRuntime(
        products: [_piece('dress', ProductCategory.dress, 80)],
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'Formal summer outfit under €500',
      });
      expect(_ids(result), ['dress']);
      expect(result['reply'], contains('No catalog option'));
      expect(result['reply'], contains('shoes, bag'));
    },
  );

  test(
    'excluded and owned categories advance to the actual remaining purchases',
    () async {
      final runtime = StylistRuntime(products: _catalog);
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'A formal summer wedding under €500, no dresses, no bag, I already own shoes',
      });
      expect(
        (result['products'] as List).every(
          (product) => product['category'] == 'top',
        ),
        isTrue,
      );
      final bottom = await runtime.turn(_select('top-red-cotton'));
      expect(_ids(bottom), ['bottom-red']);
      final complete = await runtime.turn(_select('bottom-red'));
      expect(_ids(complete), isEmpty);
      expect(complete['reply'], contains('Your look is complete'));
      expect(complete['constraints']['ownedCategories'], ['shoes']);
    },
  );

  test(
    'casual wedding follows the explicitly requested casual route',
    () async {
      final runtime = StylistRuntime(products: _catalog);
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'A casual summer wedding under €500',
      });
      expect(result['brief']['dressCode'], 'casual');
      expect(
        (result['products'] as List).every(
          (product) => product['category'] == 'top',
        ),
        isTrue,
      );
    },
  );

  test(
    'soft color preference affects ranking before the search limit',
    () async {
      final runtime = StylistRuntime(
        products: _catalog,
        model: _searchModel({'query': '', 'limit': 1}),
      );
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'Casual summer outfit under €500, I prefer red',
      });
      expect(_ids(result), ['top-red-cotton']);
      expect(result['constraints']['allowedColors'], isNull);
      expect(result['constraints']['preferredColors'], ['red']);
    },
  );

  test(
    'a newly incompatible selected piece remains visible and reopens its slot',
    () async {
      final runtime = StylistRuntime(products: _catalog);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'Casual summer outfit under €500'});
      await runtime.turn(_select('top-blue-wool'));
      await runtime.turn(_select('bottom-red'));
      await runtime.turn(_select('shoes-red'));
      final complete = await runtime.turn(_select('bag-red'));
      expect(complete['reply'], contains('Your look is complete'));
      final revised = await runtime.turn({'message': 'No wool'});
      expect(_ids(revised), ['top-red-cotton']);
      expect((runtime.outfit['items'] as Map)['top'], 'top-blue-wool');
      expect(revised['reply'], isNot(contains('Your look is complete')));
      expect(revised['reply'], contains('conflict'));
      final repaired = await runtime.turn(_select('top-red-cotton'));
      expect((runtime.outfit['items'] as Map)['top'], 'top-red-cotton');
      expect(repaired['reply'], contains('Your look is complete'));
    },
  );

  test(
    'an excluded selected extra requires removal before declaring completion',
    () async {
      final runtime = StylistRuntime(products: _catalog);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'Casual summer outfit under €500'});
      await runtime.turn(_select('top-red-cotton'));
      await runtime.turn(_select('bottom-red'));
      await runtime.turn(_select('shoes-red'));
      await runtime.turn(_select('bag-red'));
      final revised = await runtime.turn({'message': 'No bag'});
      expect(_ids(revised), isEmpty);
      expect((runtime.outfit['items'] as Map)['bag'], 'bag-red');
      expect(revised['reply'], isNot(contains('Your look is complete')));
      expect(
        revised['reply'],
        matches(RegExp('remove|replace', caseSensitive: false)),
      );
      final repaired = await runtime.turn({
        'action': {
          'name': 'remove_product',
          'context': {'productId': 'bag-red'},
        },
      });
      expect(runtime.outfit['items'], isNot(contains('bag')));
      expect(repaired['reply'], contains('Your look is complete'));
    },
  );

  test(
    'clearing one restriction is acknowledged while another remains active',
    () async {
      final runtime = StylistRuntime(products: _catalog);
      addTearDown(runtime.dispose);
      await runtime.turn({
        'message': 'Casual summer outfit under €500, only red, no wool',
      });
      final revised = await runtime.turn({
        'message': 'Forget the wool restriction',
      });
      expect(revised['constraints']['excludedMaterials'], isNull);
      expect(revised['constraints']['allowedColors'], ['red']);
      expect(revised['reply'], contains('avoid materials cleared'));
      expect(_ids(revised), ['top-red-cotton']);
    },
  );

  test('scoped red shoes permit blue tops in the same outfit', () async {
    final runtime = StylistRuntime(products: _catalog);
    addTearDown(runtime.dispose);
    final shoes = await runtime.turn({
      'message': 'Casual summer outfit under €500, only red shoes',
    });
    expect(_ids(shoes), ['shoes-red']);
    expect(shoes['constraints']['allowedColors'], isNull);
    expect(
      shoes['constraints']['categoryConstraints']['shoes']['allowedColors'],
      ['red'],
    );
    final tops = await runtime.turn(_select('shoes-red'));
    expect(_ids(tops), contains('top-blue-wool'));
    expect(tops['reply'], isNot(contains('only these colors: red')));
  });

  test('ambiguous scope survives unrelated text and waits for category clarifications', () async {
    final runtime = StylistRuntime(products: _catalog);
    addTearDown(runtime.dispose);
    final unclear = await runtime.turn({
      'message':
          'Casual summer outfit under €500, only red shoes and blue tops',
    });
    expect(_ids(unclear), isEmpty);
    expect(unclear['constraints']['clarificationRequests'], isNotEmpty);
    expect(unclear['constraints']['allowedColors'], isNull);
    final unrelated = await runtime.turn({'message': 'Hello'});
    expect(_ids(unrelated), isEmpty);
    expect(
      unrelated['constraints']['clarificationRequests'],
      unclear['constraints']['clarificationRequests'],
    );
    final partial = await runtime.turn({'message': 'Only red shoes'});
    expect(_ids(partial), isEmpty);
    expect(partial['constraints']['clarificationRequests'], isNotEmpty);
    final resolved = await runtime.turn({'message': 'Only blue tops'});
    expect(resolved['constraints']['clarificationRequests'], isNull);
    expect(_ids(resolved), ['top-blue-wool']);
  });

  test('excluding heels keeps shoes required and permits sandals', () async {
    final sandals = Product(
      id: 'sandals',
      category: ProductCategory.shoes,
      name: 'Flat leather sandals',
      brand: 'Sample',
      price: 40,
      meta: '',
      tag: '',
      swatch: '#000000',
      subcategory: 'sandals',
      color: 'red',
      material: 'leather',
    );
    final heels = Product(
      id: 'heels',
      category: ProductCategory.shoes,
      name: 'Block heels',
      brand: 'Sample',
      price: 30,
      meta: '',
      tag: '',
      swatch: '#000000',
      subcategory: 'heels',
      color: 'red',
      material: 'leather',
    );
    final runtime = StylistRuntime(
      products: [
        ..._catalog.where((piece) => piece.category != ProductCategory.shoes),
        sandals,
        heels,
      ],
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': 'Casual summer outfit under €500, no heels',
    });
    expect(result['constraints']['excludedCategories'], isNull);
    expect(result['constraints']['excludedProductTerms'], ['heels']);
    await runtime.turn(_select('top-red-cotton'));
    final shoes = await runtime.turn(_select('bottom-red'));
    expect(_ids(shoes), ['sandals']);
    expect(shoes['reply'], isNot(contains('Your look is complete')));
  });
}
