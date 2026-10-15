import 'stylist_wire_helpers.dart';

import 'dart:io';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_shared_components.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_semantics.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_constraints.dart';
import 'package:genui/genui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;

import 'progressive_agent_test.dart' show action;
import 'stylist_budget_weather_recovery_test.dart' show WeekendForecast;

final actualCatalog = parseCatalogProducts(
  File('assets/data/catalog/products.csv').readAsStringSync(),
);
Product actual(String id) => actualCatalog.singleWhere((p) => p.id == id);
Map<String, dynamic> choose(String id) => {
  'action': {
    'name': 'select_product',
    'context': {'productId': id},
  },
};
Map<String, dynamic> adjust(String id, String adjustment) => {
  'action': {
    'name': 'adjust_piece',
    'context': {
      'productId': id,
      'category': actual(id).category.name,
      'adjustment': adjustment,
    },
  },
};
g.ModelResponse tool(String name, Map<String, dynamic> input) =>
    g.ModelResponse(
      finishReason: g.FinishReason.stop,
      message: g.Message(
        role: g.Role.model,
        content: [
          g.ToolRequestPart(
            toolRequest: g.ToolRequest(
              name: name,
              ref: 'adoption-$name',
              input: input,
            ),
          ),
        ],
      ),
    );
StylistRuntime runtimeFor(
  String opening, {
  void Function(g.ModelRequest)? onRequest,
}) => StylistRuntime(
  products: actualCatalog,
  onModelRequest: onRequest,
  model: (request) async {
    if (request.messages.last.role == g.Role.user &&
        request.messages.last.text.contains('initial')) {
      return tool('search_products', {
        'query': opening,
        'season': '',
        'occasion': '',
      });
    }
    return offlineStylistModel(request);
  },
);
List<Map> resultProducts(Map result) =>
    (result['products'] as List).cast<Map>();
List<Map> components(Map result) =>
    (presentedStylistTurn(result)['messages'] as List)
        .where((m) => m['updateComponents'] != null)
        .expand((m) => m['updateComponents']['components'] as List)
        .cast<Map>()
        .toList();
const openingDress =
    "Women's initial wrap dress for a winter celebration under €500";

Future<void> settleStylistTurn(WidgetTester tester, GenkitAgent agent) async {
  await tester.pump();
  for (var i = 0; i < 500 && agent.isBusy; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(agent.isBusy, false);
  await tester.pumpAndSettle();
}

void main() {
  test('formal male styling uses available separates instead of unsuitable utility coveralls', () async {
    final runtime = StylistRuntime(products: actualCatalog);
    addTearDown(runtime.dispose);
    final result = await runtime.turn({
      'message': "Men's formal outfit under €500",
    });
    expect(result['brief']['gender'], 'male');
    expect(result['brief']['dressCode'], 'formal');
    expect(resultProducts(result), isNotEmpty);
    expect(
      resultProducts(result).every((p) => p['category'] == 'top'),
      true,
      reason: '${resultProducts(result)}',
    );
    expect(
      resultProducts(result)
          .every((p) => actual(p['id']).supportsGender('male')),
      true,
    );
  });
  test(
    'normalization resolves contradictory subtype and gray/grey families',
    () {
      expect(catalogGarmentType(actual('demo-0511')), 't-shirt');
      expect(catalogGarmentType(actual('demo-0229')), 'robe');
      expect(catalogGarmentType(actual('demo-0769')), 'coveralls');
      expect(productColorFamilies(actual('demo-0388')), contains('blue'));
      expect(productColorFamilies(actual('demo-0642')), contains('grey'));
      final navy = actualCatalog.firstWhere(
        (p) => p.color.toLowerCase().contains('navy'),
      );
      expect(productColorFamilies(navy), contains('blue'));
      expect(
        const StylistConstraints(excludedColors: {'blue'}).matches(navy),
        false,
      );
      expect(
        differentCatalogColor(actual('demo-0092'), actual('demo-0198')),
        false,
      );
    },
  );

  test('actual jacket request survives empty-query fallback with audience and budget', () async {
    final runtime = runtimeFor('Black Draped Wrap Dress');
    addTearDown(runtime.dispose);
    final opening = await runtime.turn({'message': openingDress});
    expect(
      opening['reply'],
      isNot(contains('preferred colors: preferred colors')),
    );
    await runtime.turn(choose('demo-0092'));
    final result = await runtime.turn({'message': 'Show jackets'});
    expect(result['brief']['gender'], 'female');
    expect(result['brief']['budget'], 500);
    expect(resultProducts(result), isNotEmpty);
    for (final row in resultProducts(result)) {
      final product = actual(row['id']);
      expect({'jacket', 'blazer'}, contains(catalogGarmentType(product)));
      expect(product.supportsGender('female'), true);
      expect(product.price, lessThanOrEqualTo(270));
    }
    final qualified = await runtime.turn({'message': "No men's jackets"});
    expect(resultProducts(qualified), isNotEmpty);
    for (final p in resultProducts(qualified)) {
      expect({
        'jacket',
        'blazer',
      }, contains(catalogGarmentType(actual(p['id']))));
    }
    final broad = await runtime.turn({'message': 'Show layers'});
    expect(
      broad['constraints']['requiredGarmentTypes'],
      isNot(contains('layer')),
    );
    expect(resultProducts(broad), isNotEmpty);
  });

  test('business budget recovery preserves shirt and does not broaden to loungewear', () async {
    final runtime = runtimeFor('Cotton Shirt');
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'Business initial work weekend under €50'});
    await runtime.turn(choose('demo-0231'));
    final result = await runtime.turn({
      'action': {
        'name': 'update_budget',
        'context': {'budget': 300},
      },
    });
    expect(result['outfit']['items']['top'], 'demo-0231');
    expect(result['brief']['dressCode'], 'business');
    expect(resultProducts(result), isNotEmpty);
    for (final row in resultProducts(result)) {
      expect({
        'leggings',
        'shorts',
        'jeans',
      }, isNot(contains(catalogGarmentType(actual(row['id'])))));
      expect(
        '${row['name']} ${row['description']}'.toLowerCase(),
        isNot(contains('lounge')),
      );
    }
  });

  test('Cheaper exposes actual cheaper alternatives and rejects cached original selection', () async {
    final runtime = runtimeFor('Black Draped Wrap Dress');
    addTearDown(runtime.dispose);
    await runtime.turn({'message': openingDress});
    await runtime.turn(choose('demo-0092'));
    final result = await runtime.turn(adjust('demo-0092', 'Cheaper'));
    expect(result['outfit']['items']['dress'], 'demo-0092');
    expect(resultProducts(result), isNotEmpty);
    expect(
      components(result).map((c) => c['component']),
      containsAll(['QuickAdjust', 'ThisOrThat']),
    );
    for (final product in resultProducts(result)) {
      expect(product['price_eur'], lessThan(230));
      expect(product['gender'], contains('female'));
    }
    await expectLater(
      runtime.turn(choose('demo-0092')),
      throwsA(isA<StylistInputError>()),
    );
    final accepted = await runtime.turn(
      choose(resultProducts(result).first['id']),
    );
    expect(
      accepted['outfit']['items']['dress'],
      resultProducts(result).first['id'],
    );
    expect(accepted['brief']['budget'], 500);
  });

  test('text cheaper and another color preserve the selected outfit until accepted', () async {
    final runtime = runtimeFor('Black Draped Wrap Dress');
    addTearDown(runtime.dispose);
    await runtime.turn({'message': openingDress});
    await runtime.turn(choose('demo-0092'));
    final cheaper = await runtime.turn({'message': 'Show a cheaper dress'});
    expect(resultProducts(cheaper), isNotEmpty);
    expect(resultProducts(cheaper).every((p) => p['price_eur'] < 230), true);
    final color = await runtime.turn(adjust('demo-0092', 'Another colour'));
    expect(resultProducts(color), isNotEmpty);
    for (final p in resultProducts(color)) {
      expect(differentCatalogColor(actual('demo-0092'), actual(p['id'])), true);
    }
    expect(color['outfit']['items']['dress'], 'demo-0092');
  });

  test(
    'stale adjustment rolls back and local comparison uses zero model requests',
    () async {
      var requests = 0;
      final runtime = runtimeFor(
        'Black Draped Wrap Dress',
        onRequest: (_) => requests++,
      );
      addTearDown(runtime.dispose);
      final initial = await runtime.turn({'message': openingDress});
      final before = requests;
      final comparison = await runtime.turn({
        'action': {'name': 'compare_products', 'context': <String, Object?>{}},
      });
      expect(requests, before);
      expect(
        resultProducts(comparison).map((p) => p['id']),
        resultProducts(initial).map((p) => p['id']),
      );
      expect(
        components(comparison).map((c) => c['component']),
        contains('ThisOrThat'),
      );
      await runtime.turn(choose('demo-0092'));
      await expectLater(
        runtime.turn(adjust('demo-0198', 'Cheaper')),
        throwsA(isA<StylistInputError>()),
      );
      expect((runtime.outfit['items'] as Map)['dress'], 'demo-0092');
    },
  );

  testWidgets(
    'real GenUI comparison button selects its actual catalog product',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final runtime = (await tester.runAsync(
        () async => runtimeFor('Black Draped Wrap Dress'),
      ))!;
      final agent = (await tester.runAsync(() async => GenkitAgent(runtime)))!;
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.runAsync(() => agent.startBrief(openingDress));
      await tester.pumpAndSettle();
      expect(agent.connectionError, isNull);
      expect(find.text('Compare these two'), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.runAsync(
        () => agent.conversation.sendRequest(action('compare_products', {})),
      );
      await settleStylistTurn(tester, agent);
      expect(agent.connectionError, isNull);
      expect(find.byType(FinalizedThisOrThat), findsOneWidget);
      final choice = find.descendant(
        of: find.byType(FinalizedThisOrThat),
        matching: find.text('Black Draped Wrap Dress · €230.00'),
      );
      await tester.ensureVisible(choice);
      await tester.runAsync(() async {
        await tester.tap(choice);
      });
      await settleStylistTurn(tester, agent);
      expect(agent.connectionError, isNull);
      expect(agent.inputError, isNull);
      expect((runtime.outfit['items'] as Map)['dress'], 'demo-0092');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'preferences use actual brands, soft ranking and atomic validation',
    () async {
      var requests = 0;
      final runtime = runtimeFor(
        'Black Draped Wrap Dress',
        onRequest: (_) => requests++,
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': openingDress});
      await runtime.turn(choose('demo-0092'));
      final before = requests;
      final panel = await runtime.turn({
        'action': {'name': 'edit_preferences', 'context': <String, Object?>{}},
      });
      expect(requests, before);
      expect(
        components(panel).map((c) => c['component']),
        containsAll(['ColourPicker', 'BrandPreferences', 'ChoiceChip']),
      );
      final data =
          (presentedStylistTurn(panel)['messages'] as List)
                  .last['updateDataModel']['value']
              as Map;
      expect(data['catalogBrands'], hasLength(9));
      expect(data['catalogBrands'], contains('Alder Studio'));
      expect(data['catalogBrands'], isNot(contains('Gucci')));
      expect(
        data['paletteOptions'],
        everyElement(containsPair('count', greaterThan(0))),
      );
      final updated = await runtime.turn({
        'action': {
          'name': 'update_preferences',
          'context': {
            'colours': ['Blue'],
            'love': ['Woven Orbit'],
            'skip': ['Soft Current'],
            'owned': {'shoes': true, 'bag': true},
          },
        },
      });
      expect(updated['brief']['gender'], 'female');
      expect(updated['brief']['budget'], 500);
      expect(updated['outfit']['items']['dress'], 'demo-0092');
      expect(updated['constraints']['preferredColors'], ['blue']);
      expect(updated['constraints']['preferredBrands'], ['woven orbit']);
      expect(updated['constraints']['excludedBrands'], ['soft current']);
      expect(
        updated['constraints']['ownedCategories'],
        containsAll(['shoes', 'bag']),
      );
      expect(updated['reply'], contains('already owned: shoes, bag'));
      await expectLater(
        runtime.turn({
          'action': {
            'name': 'update_preferences',
            'context': {
              'colours': ['Chocolate'],
              'love': ['Gucci'],
            },
          },
        }),
        throwsA(isA<StylistInputError>()),
      );
      final retained = await runtime.turn({
        'action': {'name': 'edit_preferences', 'context': <String, Object?>{}},
      });
      expect(retained['constraints']['preferredColors'], ['blue']);
      final preference = const StylistConstraints(
        preferredBrands: {'woven orbit'},
      );
      expect(
        preference.preferenceScore(actual('demo-0195')),
        greaterThan(preference.preferenceScore(actual('demo-0388'))),
      );
      expect(preference.matches(actual('demo-0388')), true);
    },
  );

  testWidgets(
    'preference widgets edit drafts and submit all choices together',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final runtime = (await tester.runAsync(
        () async => runtimeFor('Black Draped Wrap Dress'),
      ))!;
      final agent = (await tester.runAsync(() async => GenkitAgent(runtime)))!;
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.runAsync(() => agent.startBrief(openingDress));
      await tester.pumpAndSettle();
      expect(find.text('Colors, brands & owned pieces'), findsNothing);
      expect(find.textContaining('Details & demo sizes'), findsNothing);
      await tester.runAsync(
        () => agent.conversation.sendRequest(action('edit_preferences', {})),
      );
      await settleStylistTurn(tester, agent);
      expect(agent.connectionError, isNull);
      expect(find.byType(FinalizedColourPicker), findsOneWidget);
      final watch = find
          .descendant(
            of: find.byType(FinalizedBrandPreferences),
            matching: find.text('Woven Orbit'),
          )
          .first;
      await tester.ensureVisible(watch);
      await tester.tap(watch);
      await tester.pumpAndSettle();
      expect(agent.isBusy, false);
      final ownedShoes = find.byWidgetPredicate(
        (w) => w is FinalizedChip && w.label == 'Shoes',
      );
      await tester.ensureVisible(ownedShoes);
      await tester.tap(ownedShoes);
      await tester.pumpAndSettle();
      expect(agent.isBusy, false);
      expect(
        agent.controller
            .contextFor(agent.latestInlineSurfaceId!)
            .dataModel
            .getValue<bool>(DataPath('/ownedPieces/shoes')),
        true,
      );
      expect(
        agent.controller
            .contextFor(agent.latestInlineSurfaceId!)
            .dataModel
            .getValue<List>(DataPath('/lovedBrands')),
        ['Woven Orbit'],
      );
      final button = find.text('Update preferences').last;
      await tester.ensureVisible(button);
      await tester.runAsync(() async {
        await tester.tap(button);
      });
      await settleStylistTurn(tester, agent);
      expect(agent.connectionError, isNull);
      expect(agent.inputError, isNull);
      final panel = await tester.runAsync(
        () => runtime.turn({
          'action': {
            'name': 'edit_preferences',
            'context': <String, Object?>{},
          },
        }),
      );
      expect(panel!['constraints']['preferredBrands'], ['woven orbit']);
      expect(panel['constraints']['ownedCategories'], contains('shoes'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'structured trip dates preserve the outfit and disclose partial forecasts',
    () async {
      final runtime = StylistRuntime(
        products: [
          actual('demo-0231'),
          actual('demo-0088'),
          actual('demo-0388'),
        ],
        cityContextSource: WeekendForecast(),
      );
      addTearDown(runtime.dispose);
      await runtime.turn({
        'message': 'Belfast for the weekend, business under €300',
      });
      await runtime.turn({'message': 'Trip from 2026-10-17 to 2026-10-19'});
      final panel = await runtime.turn({
        'action': {'name': 'edit_preferences', 'context': <String, Object?>{}},
      });
      expect(panel['brief']['tripStart'], '2026-10-17');
      expect(panel['brief']['tripEnd'], '2026-10-19');
      expect(
        components(panel).where((c) => c['component'] == 'DateTimeInput'),
        hasLength(2),
      );
      final forecast = await runtime.turn({
        'message': 'What will the weather be?',
      });
      expect(forecast['reply'], contains('2026-10-17:'));
      expect(forecast['reply'], contains('2026-10-18:'));
      expect(forecast['reply'], isNot(contains('2026-10-16:')));
      expect(forecast['reply'], contains('only part of your trip'));
      await expectLater(
        runtime.turn({
          'action': {
            'name': 'update_preferences',
            'context': {
              'tripStart': '2026-10-20',
              'tripEnd': '2026-10-19',
              'colours': ['Blue'],
            },
          },
        }),
        throwsA(isA<StylistInputError>()),
      );
      final next = await runtime.turn({'message': 'Weather tomorrow?'});
      expect(next['brief']['tripStart'], '2026-10-17');
      expect(next['brief']['budget'], 300);
      expect(next['constraints'], isNot(contains('preferredColors')));
      expect(next['reply'], contains('2026-10-15:'));
    },
  );

  test('completed look includes the optional accessory and owned facts without invented pieces', () async {
    final runtime = runtimeFor('Black Draped Wrap Dress');
    addTearDown(runtime.dispose);
    await runtime.turn({
      'message':
          "$openingDress, I already own shoes; I already own a bag; I already own a layer",
    });
    await runtime.turn(choose('demo-0092'));
    final accessories = await runtime.turn({'message': 'Show earrings'});
    expect(
      resultProducts(accessories).map((p) => p['id']),
      contains('demo-0026'),
    );
    final completed = await runtime.turn(choose('demo-0026'));
    expect(
      components(completed).map((c) => c['component']),
      containsAll(['Look', 'LookSummary']),
    );
    final data =
        (presentedStylistTurn(completed)['messages'] as List)
                .last['updateDataModel']['value']
            as Map;
    expect((data['look']['pieces'] as List).map((p) => p['category']), [
      'dress',
      'accessory',
    ]);
    expect(data['look']['meta'], contains('€255.00'));
    expect(data['look']['meta'], contains('Owned:'));
    expect(completed['outfit']['items'], {
      'dress': 'demo-0092',
      'accessory': 'demo-0026',
    });
  });

  test('weather keeps current choices actionable and an end-only trip date is not invented as a start', () async {
    var calls = 0;
    final runtime = StylistRuntime(
      products: [actual('demo-0231'), actual('demo-0388')],
      cityContextSource: WeekendForecast(),
      onModelRequest: (_) => calls++,
    );
    addTearDown(runtime.dispose);
    final initial = await runtime.turn({
      'message': 'Belfast for work, business under €300',
    });
    expect(resultProducts(initial), isNotEmpty);
    final before = calls;
    final weather = await runtime.turn({
      'message': 'What will the weather be?',
    });
    expect(calls, before);
    expect(weather['products'], isEmpty);
    expect(
      components(weather).map((c) => c['component']),
      contains('ProductCard'),
    );
    await runtime.turn(choose(resultProducts(initial).first['id']));
    final ended = await runtime.turn({'message': 'My trip ends on 2026-10-17'});
    expect(ended['brief']['tripEnd'], '2026-10-17');
    expect(ended['brief'], isNot(contains('tripStart')));
    final forecast = await runtime.turn({'message': 'Weather for my trip?'});
    expect(forecast['reply'], contains('2026-10-17:'));
    expect(forecast['reply'], contains('Only your trip end date is stated'));
  });
}
