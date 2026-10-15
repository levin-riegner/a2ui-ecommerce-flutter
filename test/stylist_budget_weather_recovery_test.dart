import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:a2ui_flutter_commerce/src/agent/city_context.dart';
import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genkit/genkit.dart' as g;

import 'city_context_test.dart' show inlineData;
import 'progressive_agent_test.dart' show action;

Product piece(String id, ProductCategory category, double price) => Product(
  id: id,
  category: category,
  name: id,
  brand: 'Alder Studio',
  price: price,
  meta: '',
  tag: 'Work',
  swatch: '#ffffff',
  imageAsset: id == 'Cotton Shirt'
      ? 'assets/images/products/demo-0231.jpg'
      : '',
);
final catalog = [
  piece('Cotton Shirt', ProductCategory.top, 45),
  piece('Trousers', ProductCategory.bottom, 80),
  piece('Shoes', ProductCategory.shoes, 60),
  piece('Bag', ProductCategory.bag, 40),
];
const chooseShirt = {
  'action': {
    'name': 'select_product',
    'context': {'productId': 'Cotton Shirt'},
  },
};

class WeekendForecast implements CityContextSource {
  final calls = <({String city, bool refresh})>[];
  bool fail = false;
  @override
  Future<CityContext> fetch(String city, {bool refresh = false}) async {
    calls.add((city: city, refresh: refresh));
    if (fail) throw StateError('network unavailable');
    return CityContext(
      city: city.split(',').first,
      country: 'United Kingdom',
      latitude: 54.6,
      longitude: -5.9,
      timezone: 'Europe/London',
      fetchedAt: DateTime.utc(2026, 10, 14),
      days: const [
        {
          'date': '2026-10-14',
          'label': 'Wed',
          'highC': 17,
          'lowC': 10,
          'rainProbabilityPercent': 76,
          'value': '17° / 10°',
          'detail': 'Rain 76%',
          'icon': 'rain',
        },
        {
          'date': '2026-10-15',
          'label': 'Thu',
          'highC': 16,
          'lowC': 10,
          'rainProbabilityPercent': 100,
          'value': '16° / 10°',
          'detail': 'Rain 100%',
          'icon': 'rain',
        },
        {
          'date': '2026-10-16',
          'label': 'Fri',
          'highC': 12,
          'lowC': 7,
          'rainProbabilityPercent': 12,
          'value': '12° / 7°',
          'detail': 'Rain 12%',
          'icon': 'day',
        },
        {
          'date': '2026-10-17',
          'label': 'Sat',
          'highC': 14,
          'lowC': 9,
          'rainProbabilityPercent': 80,
          'value': '14° / 9°',
          'detail': 'Rain 80%',
          'icon': 'rain',
        },
        {
          'date': '2026-10-18',
          'label': 'Sun',
          'highC': 15,
          'lowC': 10,
          'rainProbabilityPercent': 30,
          'value': '15° / 10°',
          'detail': 'Rain 30%',
          'icon': 'day',
        },
      ],
    );
  }

  @override
  void dispose() {}
}

List<Map> components(Map<String, dynamic> turn) => (turn['messages'] as List)
    .where(
      (m) => m['updateComponents']?['surfaceId'].startsWith('inline-') == true,
    )
    .expand((m) => m['updateComponents']['components'] as List)
    .cast<Map>()
    .toList();

void main() {
  test('destination lookup supports Belfast and multiword cities without treating clothes as locations', () {
    for (final text in [
      'Belfast for the weekend, business under €50',
      'A work weekend in Belfast under €50',
      'A work weekend in Belfast, business under €50',
      'What is the weather in Belfast?',
      'Show me the forecast for Belfast',
    ]) {
      expect(parseDestinationCity(text), 'Belfast');
    }
    expect(
      parseDestinationCity('Change my destination to Kyoto, Japan'),
      'Kyoto, Japan',
    );
    expect(
      parseDestinationCity('A work day in New York, United States today'),
      'New York, United States',
    );
    expect(
      parseDestinationCity('A work day in Berlin, United States today'),
      'Berlin, United States',
    );
    expect(parseDestinationCity('A dress for the weekend'), isNull);
    expect(parseDestinationCity('Only shirts in black'), isNull);
    expect(parseDestinationCity('Show the forecast for Thursday'), isNull);
    expect(parseDestinationCity('What is the weather for tomorrow?'), isNull);
    expect(parseDestinationCity('Belfast', allowBare: true), 'Belfast');
    expect(isWeatherQuestion('what will the weather be'), isTrue);
    expect(isWeatherQuestion('What should I wear in cold weather?'), isFalse);
  });

  test('budget dead end renders current budget and preserves selected pieces on update', () async {
    final runtime = StylistRuntime(products: catalog);
    addTearDown(runtime.dispose);
    final first = await runtime.turn({
      'message': 'Belfast for the weekend, business under €50',
    });
    expect((first['products'] as List).single['id'], 'Cotton Shirt');
    expect(
      components(first).any((c) => c['component'] == 'BudgetSlider'),
      isFalse,
    );
    final blocked = await runtime.turn(chooseShirt);
    expect(blocked['reply'], contains('€225.00'));
    expect(inlineData(blocked)['budget'], 50);
    expect(inlineData(blocked)['budgetIsSuggested'], isFalse);
    expect(
      components(blocked).where((c) => c['component'] == 'BudgetSlider'),
      hasLength(1),
    );
    expect(
      components(blocked).any((c) => c['label'] == 'Update budget'),
      isTrue,
    );
    final resumed = await runtime.turn({
      'action': {
        'name': 'update_budget',
        'context': {'budget': 300},
      },
    });
    expect(resumed['brief'], containsPair('budget', 300));
    expect(resumed['outfit']['items'], {'top': 'Cotton Shirt'});
    expect((resumed['products'] as List).single['id'], 'Trousers');
    expect(resumed['reply'], contains('€300.00 for the whole outfit'));
    expect(
      components(resumed).any((c) => c['component'] == 'BudgetSlider'),
      isFalse,
    );
  });

  test('budget update below selected total fails without losing the recovery controls', () async {
    final runtime = StylistRuntime(products: catalog);
    addTearDown(runtime.dispose);
    await runtime.turn({'message': 'Business under €50'});
    await runtime.turn(chooseShirt);
    await expectLater(
      runtime.turn({
        'action': {
          'name': 'update_budget',
          'context': {'budget': 40},
        },
      }),
      throwsA(isA<StylistInputError>()),
    );
    expect(runtime.outfit, {
      'budget': 50.0,
      'items': {'top': 'Cotton Shirt'},
    });
  });

  test('weather query fetches retained Belfast and answers dated facts without advancing or losing budget controls', () async {
    final source = WeekendForecast();
    final prompts = <String>[];
    final runtime = StylistRuntime(
      products: catalog,
      cityContextSource: source,
      onModelRequest: (g.ModelRequest r) => prompts.add(r.messages.first.text),
    );
    addTearDown(runtime.dispose);
    await runtime.turn({
      'message': 'Belfast for the weekend, business under €50',
    });
    await runtime.turn(chooseShirt);
    final before = jsonEncode(runtime.outfit);
    final requestsBefore = prompts.length;
    final weather = await runtime.turn({'message': 'what will the weather be'});
    expect(weather['intent'], 'weather');
    expect(prompts.length, requestsBefore);
    expect(source.calls.last, (city: 'Belfast', refresh: true));
    expect(
      weather['reply'],
      contains('2026-10-17: 9–14°C, 80% chance of rain'),
    );
    expect(weather['reply'], isNot(contains('there are no')));
    expect(weather['products'], isEmpty);
    expect(jsonEncode(runtime.outfit), before);
    expect(prompts.last, contains('rainProbabilityPercent'));
    expect(inlineData(weather)['budget'], 50);
    expect(
      components(weather).any((c) => c['label'] == 'Update budget'),
      isTrue,
    );
    final resumed = await runtime.turn({
      'action': {
        'name': 'update_budget',
        'context': {'budget': 300},
      },
    });
    expect((resumed['products'] as List).single['id'], 'Trousers');
    expect(resumed['outfit']['items'], {'top': 'Cotton Shirt'});
  });

  test('weather lookup asks only for city and can recover from an unavailable forecast', () async {
    final source = WeekendForecast();
    final runtime = StylistRuntime(
      products: catalog,
      cityContextSource: source,
    );
    addTearDown(runtime.dispose);
    final missing = await runtime.turn({
      'message': 'What will the weather be?',
    });
    expect(missing['reply'], 'Which city should I check the weather for?');
    expect(
      components(missing).any((c) => c['component'] == 'BudgetSlider'),
      isFalse,
    );
    source.fail = true;
    final failed = await runtime.turn({'message': 'Belfast'});
    expect(failed['reply'], contains('couldn’t load the forecast for Belfast'));
    expect(inlineData(failed)['weather'], isNull);
    source.fail = false;
    final retried = await runtime.turn({'message': 'Check the weather again'});
    expect(retried['reply'], contains('Belfast, United Kingdom'));
    expect(inlineData(retried)['weather'], isNotNull);
    expect(runtime.outfit['budget'], isNull);
  });

  test(
    'weather phrasing and explicit dates override retained weekend context',
    () async {
      final source = WeekendForecast();
      final runtime = StylistRuntime(
        products: catalog,
        cityContextSource: source,
      );
      addTearDown(runtime.dispose);
      await runtime.turn({
        'message': 'Belfast for the weekend, business under €50',
      });
      await runtime.turn(chooseShirt);
      for (final question in [
        'Can you check the weather?',
        'Will it rain?',
        'Will the temperature be under 20 degrees?',
      ]) {
        final result = await runtime.turn({'message': question});
        expect(result['intent'], 'weather');
        expect(result['brief']['budget'], 50);
        expect(result['reply'], contains('2026-10-17'));
        expect(result['reply'], isNot(contains('There are no bottoms')));
      }
      for (final question in [
        'What is the weather tomorrow?',
        'Show the forecast for Thursday',
        'Weather on 2026-10-15?',
      ]) {
        final result = await runtime.turn({'message': question});
        expect(
          result['reply'],
          contains('2026-10-15: 10–16°C, 100% chance of rain'),
        );
        expect(result['reply'], isNot(contains('2026-10-17')));
        expect(result['outfit']['items'], {'top': 'Cotton Shirt'});
        expect(source.calls.last.city, 'Belfast');
      }
      final outside = await runtime.turn({'message': 'Weather on 2026-10-25?'});
      expect(
        outside['reply'],
        contains('not included in the available forecast'),
      );
      expect(outside['reply'], isNot(contains('2026-10-25:')));
    },
  );

  testWidgets(
    'budget slider edits locally, then Update budget resumes the same outfit',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      late StylistRuntime runtime;
      final agent = (await tester.runAsync(() async {
        runtime = StylistRuntime(
          products: catalog,
          cityContextSource: WeekendForecast(),
        );
        return GenkitAgent(runtime);
      }))!;
      final captureKey = GlobalKey();
      if (Platform.environment['ALDER_CAPTURE_RECOVERY'] == '1') {
        await tester.runAsync(() async {
          for (final (family, asset) in [
            ('Jost', 'assets/fonts/jost/Jost-Variable.ttf'),
            ('Inter', 'assets/fonts/inter/Inter-Variable.ttf'),
            ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
          ]) {
            await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
          }
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: ReferenceApp(agent: agent),
        ),
      );
      if (Platform.environment['ALDER_CAPTURE_RECOVERY'] == '1') {
        await tester.runAsync(
          () => precacheImage(
            const AssetImage('assets/images/products/demo-0231.jpg'),
            captureKey.currentContext!,
          ),
        );
      }
      await tester.runAsync(
        () => agent.startBrief('Belfast for the weekend, business under €50'),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => agent.conversation.sendRequest(
          action('select_product', {
            'productId': 'Cotton Shirt',
          }, surfaceId: agent.latestInlineSurfaceId),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsWidgets);
      expect(find.text('Update budget'), findsWidgets);
      expect(runtime.outfit['budget'], 50);
      final slider = find.byType(Slider).last;
      final button = find.text('Update budget').last;
      await tester.ensureVisible(slider);
      if (Platform.environment['ALDER_CAPTURE_RECOVERY'] == '1') {
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('/private/tmp/alder-budget-recovery.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.drag(slider, const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(runtime.outfit['budget'], 50);
      final updated = agent.controller
          .contextFor(agent.latestInlineSurfaceId!)
          .dataModel
          .getValue<num>(DataPath('/budget'))!;
      await tester.ensureVisible(button);
      await tester.tap(button);
      for (var i = 0; i < 20 && agent.isBusy; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(runtime.outfit['budget'], closeTo(updated, 0.005));
      expect(runtime.outfit['items'], {'top': 'Cotton Shirt'});
      expect(agent.connectionError, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
