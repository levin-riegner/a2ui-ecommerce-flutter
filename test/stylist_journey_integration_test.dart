import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

ChatMessage _action(String name, String id) => ChatMessage.user(
  '',
  parts: [
    UiInteractionPart.create(
      jsonEncode({
        'action': {
          'name': name,
          'context': {'productId': id},
        },
      }),
    ),
  ],
);

List<Map> _options(GenkitAgent agent) =>
    (agent.controller
                .contextFor(agent.latestInlineSurfaceId!)
                .dataModel
                .getValue<List<Object?>>(DataPath('/recommendations')) ??
            [])
        .cast<Map>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Product> catalog;
  setUpAll(() async {
    catalog = parseCatalogProducts(
      await rootBundle.loadString('assets/data/catalog/products.csv'),
    );
  });
  Product productFor(String id) => catalog.singleWhere((p) => p.id == id);

  final routes = {
    DemoJourney.paris: [
      ProductCategory.dress,
      ProductCategory.shoes,
      ProductCategory.layer,
      ProductCategory.bag,
    ],
    DemoJourney.berlin: [
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.bag,
    ],
    DemoJourney.cotswolds: [
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.layer,
      ProductCategory.bag,
    ],
    DemoJourney.lisbon: [
      ProductCategory.top,
      ProductCategory.bottom,
      ProductCategory.shoes,
      ProductCategory.bag,
    ],
  };
  for (final entry in routes.entries) {
    test('${entry.key.name} advances through every required piece and finishes', () async {
      final runtime = StylistRuntime(products: catalog);
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startJourney(entry.key);
      var spent = 0.0;
      final selected = <String>[];
      for (final category in entry.value) {
        expect(agent.connectionError, isNull);
        final options = _options(agent);
        expect(options, isNotEmpty, reason: 'Missing ${category.name} options');
        expect(
          options.map((card) => productFor(card['id'] as String).category),
          everyElement(category),
        );
        final id = options.first['id'] as String;
        expect(selected, isNot(contains(id)));
        spent += productFor(id).price;
        selected.add(id);
        await agent.conversation.sendRequest(_action('select_product', id));
        expect(agent.connectionError, isNull);
        final dressing = agent.controller.contextFor('dressing-room').dataModel;
        expect(
          dressing.getValue<String>(DataPath('/left')),
          '€${(entry.key.budget - spent).toStringAsFixed(2)} left',
        );
        expect((runtime.outfit['items'] as Map).values, containsAll(selected));
      }
      expect(
        _options(agent),
        isEmpty,
        reason: 'A complete look stops searching',
      );
      final completeReply = agent.controller
          .contextFor(agent.latestInlineSurfaceId!)
          .dataModel
          .getValue<String>(DataPath('/message'));
      expect(completeReply, contains('complete'));
      expect((runtime.outfit['items'] as Map), hasLength(entry.value.length));

      // Reopening a decision resumes the conversation rather than just deleting.
      final reopened = selected[1];
      await agent.conversation.sendRequest(_action('remove_product', reopened));
      expect(agent.connectionError, isNull);
      expect(_options(agent), isNotEmpty);
      expect(
        _options(agent)
            .map((card) => productFor(card['id'] as String).category),
        everyElement(entry.value[1]),
      );
      expect(
        (runtime.outfit['items'] as Map).values,
        isNot(contains(reopened)),
      );
      final dressing = agent.controller.contextFor('dressing-room').dataModel;
      expect(
        dressing.getValue<String>(DataPath('/left')),
        '€${(entry.key.budget - spent + productFor(reopened).price).toStringAsFixed(2)} left',
      );
      await agent.conversation.sendRequest(_action('select_product', reopened));
      expect(agent.connectionError, isNull);
      expect(_options(agent), isEmpty);
      expect(dressing.getValue<bool>(DataPath('/planComplete')), isTrue);
    });
  }

  testWidgets('Berlin knit stays visible while next choices become bottoms', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final agent = (await tester.runAsync(
      () async => GenkitAgent(StylistRuntime(products: catalog)),
    ))!;
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.runAsync(() => agent.startJourney(DemoJourney.berlin));
    await tester.pumpAndSettle();
    final top = productFor(_options(agent).first['id'] as String);
    await tester.runAsync(() async {
      await tester.tap(find.text('Choose this').first);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (agent.isBusy && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(agent.isBusy, isFalse);
    });
    await tester.pumpAndSettle();
    expect(agent.connectionError, isNull);
    expect(find.text(top.name), findsWidgets);
    expect(find.text('Choosing now'), findsOneWidget);
    final slots = agent.controller
        .contextFor('dressing-room')
        .dataModel
        .getValue<List<Object?>>(DataPath('/slots'))!
        .cast<Map>();
    expect(
      slots.singleWhere((slot) => slot['category'] == 'top'),
      containsPair('imageAsset', top.imageAsset),
    );
    expect(
      slots.singleWhere((slot) => slot['category'] == 'top')['state'],
      'Filled',
    );
    expect(
      slots.singleWhere((slot) => slot['state'] == 'Next')['category'],
      'bottom',
    );
    expect(
      _options(agent).map((p) => productFor(p['id'] as String).category),
      everyElement(ProductCategory.bottom),
    );
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any(
            (widget) =>
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == top.imageAsset,
          ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
