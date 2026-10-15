import 'package:a2ui_flutter_commerce/src/agent/stylist_brief.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

Product item(
  String id,
  ProductCategory category,
  String gender,
  double price,
) => Product(
  id: id,
  category: category,
  gender: gender,
  name: id,
  brand: 'Demo',
  price: price,
  meta: 'Black',
  tag: 'Demo',
  swatch: '#000000',
  color: 'black',
  season: 'all-season',
  occasion: 'celebration',
);

final catalog = [
  item('female-dress', ProductCategory.dress, 'female', 80),
  item('male-coverall', ProductCategory.dress, 'male', 80),
  item('unisex-coverall', ProductCategory.dress, 'male, female', 80),
  item('male-jacket', ProductCategory.layer, 'male', 10),
  item('female-jacket', ProductCategory.layer, 'female', 60),
  item('unisex-jacket', ProductCategory.layer, 'male, female', 65),
  item('shoes', ProductCategory.shoes, 'male, female', 30),
  item('bag', ProductCategory.bag, 'male, female', 20),
];

Map<String, dynamic> select(String id) => {
  'action': {
    'name': 'select_product',
    'context': {'productId': id},
  },
};
Map<String, dynamic> remove(String id) => {
  'action': {
    'name': 'remove_product',
    'context': {'productId': id},
  },
};
ModelResponse tool(String name, Map<String, dynamic> input) => ModelResponse(
  finishReason: FinishReason.stop,
  message: Message(
    role: Role.model,
    content: [
      ToolRequestPart(
        toolRequest: ToolRequest(name: name, ref: 'gender-$name', input: input),
      ),
    ],
  ),
);

void main() {
  test('initial negative audience request keeps compatible jackets and acknowledges scope', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': "Casual jackets under €500, no men's jackets",
    });
    expect(result['brief'], isNot(contains('gender')));
    expect((result['brief'] as Map)['budget'], 500);
    expect((result['products'] as List).cast<Map>().map((p) => p['id']), [
      'female-jacket',
      'unisex-jacket',
    ]);
    expect(result['reply'], contains('men’s jackets'));
    expect(
      result['reply'],
      isNot(contains('avoid these product types: jackets')),
    );
    expect((result['constraints'] as Map)['excludedGenderProductTerms'], {
      'male': ['jackets'],
    });
  });

  test(
    'negative audience correction preserves an explicit female flow',
    () async {
      final runtime = StylistRuntime(
        products: catalog,
        model: offlineStylistModel,
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': "Women's casual jackets under €500"});
      final corrected = await runtime.turn({'message': "No men's jackets"});
      expect(corrected['brief'], containsPair('gender', 'female'));
      expect((corrected['products'] as List).cast<Map>().map((p) => p['id']), [
        'female-jacket',
        'unisex-jacket',
      ]);
      expect(corrected['reply'], contains('men’s jackets'));
      expect(
        corrected['reply'],
        isNot(contains('avoid these product types: jackets')),
      );
      final continued = await runtime.turn({'message': 'Show jackets'});
      expect(continued['brief'], containsPair('gender', 'female'));
      expect((continued['products'] as List).cast<Map>().map((p) => p['id']), [
        'female-jacket',
        'unisex-jacket',
      ]);
    },
  );

  test('audience exclusions survive contradictory model filters and empty-search fallback', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: (request) async {
        if (request.messages.last.role == Role.user) {
          return tool('search_products', {
            'query': 'nonexistent',
            'gender': 'male',
            'category': 'layer',
          });
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    final initial = await runtime.turn({
      'message': "Casual jackets under €500, no men's jackets",
    });
    final continued = await runtime.turn({'message': 'Show jackets'});
    for (final result in [initial, continued]) {
      expect((result['products'] as List).cast<Map>().map((p) => p['id']), [
        'female-jacket',
        'unisex-jacket',
      ]);
      expect((result['constraints'] as Map)['excludedGenderProductTerms'], {
        'male': ['jackets'],
      });
    }
  });

  test('negated paired audiences preserve the accepted audience', () {
    final brief = const StylistBrief().recordMessage('female clothing please');
    for (final message in [
      "I don't want men's and women's collections mixed",
      'Not male, female',
    ]) {
      expect(parseBriefGender(message), isNull);
      expect(brief.recordMessage(message).gender, 'female');
    }
  });

  test('explicit garment audience is canonical, optional and correctable', () {
    var brief = const StylistBrief().recordMessage(
      "A women's dress under €500",
    );
    expect(brief.gender, 'female');
    expect(brief.summary, contains('Women’s styling'));
    expect(brief.summary, isNot(contains('catalog audience')));
    expect(brief.sources['gender'], BriefFactSource.user);
    expect(brief.missingFields, isNot(contains('gender')));
    brief = brief.recordMessage("Actually menswear, not women's clothing");
    expect(brief.gender, 'male');
    expect(brief.recordMessage('unisex please').gender, 'male, female');
    expect(brief.recordMessage('male, female').gender, 'male, female');
    expect(brief.recordMessage('unisex, actually womenswear').gender, 'female');
    expect(brief.recordMessage('Ladies’ winter jackets').gender, 'female');
    expect(brief.recordMessage("Ladies' jackets").gender, 'female');
    expect(brief.recordMessage('women and men').gender, 'male, female');
    expect(
      brief.recordMessage('unisex, actually women’s jackets').gender,
      'female',
    );
    expect(brief.recordMessage('Gents jackets').gender, 'male');
    expect(brief.recordMessage('Gentlemen’s jackets').gender, 'male');
    expect(brief.recordMessage('clear the audience').gender, isEmpty);
    expect(() => brief.merge({'gender': 'unknown'}), throwsFormatException);
  });

  test(
    'selected female dress restricts layers including broadened fallback',
    () async {
      var forceEmpty = false;
      final runtime = StylistRuntime(
        products: catalog,
        model: (request) async {
          if (forceEmpty && request.messages.last.role == Role.user) {
            return tool('search_products', {
              'query': 'nonexistent',
              'gender': 'male',
            });
          }
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A winter dress under €500'});
      final chosen = await runtime.turn(select('female-dress'));
      expect(chosen['brief'], containsPair('gender', 'female'));
      expect(chosen['reply'], contains('based on your selected piece'));
      forceEmpty = true;
      final layers = await runtime.turn({'message': 'Show jackets'});
      final profiles = (layers['products'] as List).cast<Map>();
      expect(
        profiles.map((p) => p['id']),
        containsAll(['female-jacket', 'unisex-jacket']),
      );
      expect(profiles.map((p) => p['id']), isNot(contains('male-jacket')));
      expect(
        profiles.every(
          (p) => p['gender'] == 'female' || p['gender'] == 'male, female',
        ),
        isTrue,
      );
    },
  );

  test('male single-audience coverall also uses dress slot without female inference', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A winter one-piece under €500'});
    final chosen = await runtime.turn(select('male-coverall'));
    expect(chosen['brief'], containsPair('gender', 'male'));
    final layers = await runtime.turn({'message': 'Show jackets'});
    expect(
      (layers['products'] as List).cast<Map>().map((p) => p['id']),
      contains('male-jacket'),
    );
    expect(
      (layers['products'] as List).cast<Map>().map((p) => p['id']),
      isNot(contains('female-jacket')),
    );
  });

  test('model cannot overwrite explicit audience and unisex selection preserves it', () async {
    var overrideGender = false;
    final runtime = StylistRuntime(
      products: catalog,
      model: (request) async {
        if (overrideGender && request.messages.last.role == Role.user) {
          return tool('save_outfit', {'gender': 'male'});
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': "A women's winter dress under €500"});
    await runtime.turn(select('female-dress'));
    await runtime.turn(select('shoes'));
    final layers = await runtime.turn({'message': 'Show jackets'});
    expect(layers['brief'], containsPair('gender', 'female'));
    await runtime.turn(select('unisex-jacket'));
    overrideGender = true;
    final current = await runtime.turn({'message': 'Keep my outfit'});
    expect(current['brief'], containsPair('gender', 'female'));
  });

  test(
    'explicit audience correction preserves conflicting selected pieces',
    () async {
      final runtime = StylistRuntime(
        products: catalog,
        model: offlineStylistModel,
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': "A women's winter dress under €500"});
      await runtime.turn(select('female-dress'));
      final corrected = await runtime.turn({
        'message': 'Actually male clothing',
      });
      expect(corrected['brief'], containsPair('gender', 'male'));
      expect(
        (corrected['outfit'] as Map)['items'],
        containsPair('dress', 'female-dress'),
      );
      expect(
        corrected['reply'],
        contains('conflicts with your new instructions'),
      );
      expect(
        (corrected['products'] as List).cast<Map>().map((p) => p['id']),
        isNot(contains('female-dress')),
      );
    },
  );

  test(
    'removing last single-audience piece releases only inferred audience',
    () async {
      final runtime = StylistRuntime(
        products: catalog,
        model: offlineStylistModel,
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A winter dress under €500'});
      await runtime.turn(select('female-dress'));
      final removed = await runtime.turn(remove('female-dress'));
      expect(removed['brief'], isNot(contains('gender')));
      await runtime.turn({'message': 'female clothing please'});
      await runtime.turn(select('female-dress'));
      final explicitRemoved = await runtime.turn(remove('female-dress'));
      expect(explicitRemoved['brief'], containsPair('gender', 'female'));
    },
  );

  test(
    'failed turn rolls back inferred and explicitly corrected audience',
    () async {
      var fail = false;
      final runtime = StylistRuntime(
        products: catalog,
        model: (request) async {
          if (fail) throw StateError('offline failure');
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A winter dress under €500'});
      await runtime.turn(select('female-dress'));
      fail = true;
      await expectLater(
        runtime.turn({'message': 'Actually male clothing'}),
        throwsStateError,
      );
      fail = false;
      final retained = await runtime.turn({'message': 'Show jackets'});
      expect(retained['brief'], containsPair('gender', 'female'));
      expect(
        (retained['outfit'] as Map)['items'],
        containsPair('dress', 'female-dress'),
      );
    },
  );

  test('replacing the only inferred audience anchor updates it; incompatible extras block switching', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A winter one-piece under €500'});
    await runtime.turn(select('female-dress'));
    final switched = await runtime.turn(select('male-coverall'));
    expect(switched['brief'], containsPair('gender', 'male'));
    expect(
      (switched['outfit'] as Map)['items'],
      containsPair('dress', 'male-coverall'),
    );
    await runtime.turn(select('female-dress'));
    await runtime.turn({'message': 'Show jackets'});
    await runtime.turn(select('female-jacket'));
    await expectLater(
      runtime.turn(select('male-coverall')),
      throwsA(isA<Exception>()),
    );
    final retained = await runtime.turn({'message': 'Show jackets'});
    expect(retained['brief'], containsPair('gender', 'female'));
    expect(
      (retained['outfit'] as Map)['items'],
      containsPair('dress', 'female-dress'),
    );
    expect(
      (retained['outfit'] as Map)['items'],
      containsPair('layer', 'female-jacket'),
    );
  });

  test('malicious presentation cannot reuse male product seen before female correction', () async {
    var malicious = false;
    var rejected = false;
    final runtime = StylistRuntime(
      products: catalog,
      model: (request) async {
        for (final part in request.messages.last.content) {
          final response = part.toolResponse;
          if (response?.name == 'present_products' &&
              (response!.output as Map)['error'] != null) {
            rejected = true;
            return tool('search_products', {'query': ''});
          }
        }
        if (malicious && request.messages.last.role == Role.user) {
          return tool('present_products', {
            'productIds': ['male-jacket'],
          });
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A winter dress under €500'});
    await runtime.turn({'message': 'Show jackets'});
    malicious = true;
    final corrected = await runtime.turn({
      'message': 'female clothing jackets please',
    });
    expect(corrected['brief'], containsPair('gender', 'female'));
    expect(rejected, isTrue);
    expect(
      (corrected['products'] as List).cast<Map>().map((p) => p['id']),
      isNot(contains('male-jacket')),
    );
  });

  test('unisex replacement releases inferred audience but preserves explicit audience', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'A winter one-piece under €500'});
    await runtime.turn(select('female-dress'));
    await runtime.turn({'message': 'Show one-pieces'});
    final neutral = await runtime.turn(select('unisex-coverall'));
    expect(neutral['brief'], isNot(contains('gender')));
    await runtime.turn({'message': 'female clothing please'});
    await runtime.turn(select('female-dress'));
    final explicit = await runtime.turn(select('unisex-coverall'));
    expect(explicit['brief'], containsPair('gender', 'female'));
  });

  test('explicit unisex request admits only products classified for both audiences', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': 'Unisex casual jackets under €500',
    });
    expect(result['brief'], containsPair('gender', 'male, female'));
    expect((result['products'] as List).cast<Map>().map((p) => p['id']), [
      'unisex-jacket',
    ]);
  });

  test('paired possessive audiences keep an explicit unisex request restricted to both', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message':
          "Unisex jackets for both men's and women's wardrobes under €500",
    });
    expect(result['brief'], containsPair('gender', 'male, female'));
    expect((result['products'] as List).cast<Map>().map((p) => p['id']), [
      'unisex-jacket',
    ]);
    final reversed = await runtime.turn({
      'message': 'Both women’s and men’s jackets',
    });
    expect(reversed['brief'], containsPair('gender', 'male, female'));
    expect((reversed['products'] as List).cast<Map>().map((p) => p['id']), [
      'unisex-jacket',
    ]);
    final corrected = await runtime.turn({
      'message': 'Unisex, actually womenswear jackets please',
    });
    expect(corrected['brief'], containsPair('gender', 'female'));
    expect(
      (corrected['products'] as List).cast<Map>().map((p) => p['id']),
      containsAll(['female-jacket', 'unisex-jacket']),
    );
  });

  test('ladies possessive requests enforce female and unisex layers', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': 'Ladies’ winter jackets under €500',
    });
    expect(result['brief'], containsPair('gender', 'female'));
    expect(
      (result['products'] as List).cast<Map>().map((p) => p['id']),
      containsAll(['female-jacket', 'unisex-jacket']),
    );
    expect(
      (result['products'] as List).cast<Map>().map((p) => p['id']),
      isNot(contains('male-jacket')),
    );
  });

  test('completion budget cannot use cheap incompatible male layer', () async {
    final runtime = StylistRuntime(
      products: catalog,
      model: offlineStylistModel,
    );
    addTearDown(runtime.dispose);
    final options = await runtime.turn({
      'message': "A women's winter dress under €150",
    });
    expect(options['reply'], contains('€190.00'));
    expect(
      (options['products'] as List).cast<Map>().map((p) => p['id']),
      isNot(contains('male-coverall')),
    );
  });
}
