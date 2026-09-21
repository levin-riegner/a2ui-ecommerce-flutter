import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/agent/stub_agent.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:a2ui_flutter_commerce/src/data/product_repository.dart';

void main() {
  test('fixture and CSV repositories share the same contract', () async {
    const fixture = FixtureProductRepository();
    final csv = CsvProductRepository();

    final fixtureProducts = await fixture.recommendations(
      journey: DemoJourney.paris,
      category: ProductCategory.shoes,
    );
    final csvProducts = await csv.recommendations(
      journey: DemoJourney.paris,
      category: ProductCategory.shoes,
    );

    expect(fixtureProducts, isNotEmpty);
    expect(csvProducts, isNotEmpty);
    expect(csvProducts.first.category, ProductCategory.shoes);
    expect(csvProducts.first.name, 'Satin Pointed Pump');
  });

  test(
    'every showcase journey has a foundation and next-step options',
    () async {
      const repository = FixtureProductRepository();

      for (final journey in DemoJourney.values) {
        final foundation = await repository.recommendations(
          journey: journey,
          category: journey.foundationCategory,
          limit: 1,
        );
        final nextStep = await repository.recommendations(
          journey: journey,
          category: ProductCategory.shoes,
          limit: 1,
        );

        expect(foundation, isNotEmpty, reason: journey.name);
        expect(nextStep, isNotEmpty, reason: journey.name);
      }
    },
  );

  test('commerce catalog exposes an extensible component vocabulary', () {
    final names = buildCommerceCatalog().items.map((item) => item.name).toSet();

    expect(names.length, greaterThanOrEqualTo(20));
    expect(
      names,
      containsAll(<String>[
        'Text',
        'Column',
        'StylistMessage',
        'ProductCard',
        'DressingRoom',
      ]),
    );
  });

  test('CSV-backed agent emits recommendation components', () async {
    final agent = StubAgent(repository: CsvProductRepository());
    await agent.startJourney(DemoJourney.paris);
    await agent.conversation.sendRequest(ChatMessage.user('Find options'));

    final surfaceId = agent.latestInlineSurfaceId;
    expect(surfaceId, 'inline-1');
    final definition = agent.controller.contextFor(surfaceId!).definition.value;
    expect(definition?.components.keys, contains('product-0'));
    final dataModel = agent.controller.contextFor(surfaceId).dataModel;
    expect(
      dataModel.getValue<String>(DataPath('/recommendations/0/name')),
      'Satin Pointed Pump',
    );

    agent.dispose();
  });

  test('stub agent emits a recommendation surface for every journey', () async {
    for (final journey in DemoJourney.values) {
      final agent = StubAgent();
      await agent.startJourney(journey);
      await agent.conversation.sendRequest(ChatMessage.user('Find options'));

      expect(agent.latestInlineSurfaceId, 'inline-1', reason: journey.name);
      expect(
        agent.controller
            .contextFor(agent.latestInlineSurfaceId!)
            .definition
            .value
            ?.components
            .keys,
        contains('product-0'),
        reason: journey.name,
      );
      agent.dispose();
    }
  });

  testWidgets('start screen launches an offline journey', (tester) async {
    await tester.pumpWidget(const ReferenceApp());
    expect(find.text('Build the look\naround the moment.'), findsOneWidget);

    await tester.tap(find.text(DemoJourney.paris.title));
    await tester.pumpAndSettle();

    expect(find.text('Dressing room'), findsOneWidget);
    expect(find.text('Find options'), findsOneWidget);

    await tester.ensureVisible(find.text('Find options'));
    await tester.tap(find.text('Find options'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Satin Pointed Pump').evaluate().isNotEmpty) break;
    }

    expect(find.text('Satin Pointed Pump'), findsOneWidget);

    if (const bool.fromEnvironment('USE_CSV_FIXTURES')) return;

    await tester.tap(find.text('Leather Kitten Heel'));
    await tester.pumpAndSettle();
    expect(find.text('Leather Kitten Heel'), findsNWidgets(2));
  });

  testWidgets('start screen opens the component catalog', (tester) async {
    await tester.pumpWidget(const ReferenceApp());

    await tester.ensureVisible(find.text('Explore component catalog'));
    await tester.tap(find.text('Explore component catalog'));
    await tester.pumpAndSettle();

    expect(find.text('Catalog components'), findsOneWidget);
    expect(find.text('ProductCard'), findsOneWidget);
    expect(find.text('DressingRoom'), findsOneWidget);
    expect(find.text('TextField'), findsOneWidget);
  });

  testWidgets('wide layout anchors the dressing room at the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ReferenceApp());
    await tester.tap(find.text(DemoJourney.paris.title));
    await tester.pumpAndSettle();

    final dressingRoomLabel = find.text('Dressing room');
    expect(dressingRoomLabel, findsOneWidget);
    expect(tester.getTopLeft(dressingRoomLabel).dy, lessThan(100));
  });

  testWidgets('portrait layout wraps the brief controls without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ReferenceApp());
    await tester.tap(find.text(DemoJourney.paris.title));
    await tester.pumpAndSettle();

    final dressingRoomTitle = find.text('Dressing room');
    expect(dressingRoomTitle, findsOneWidget);
    expect(tester.getTopLeft(dressingRoomTitle).dy, lessThan(140));
    expect(find.text('How formal?'), findsOneWidget);
    expect(find.text('Season'), findsOneWidget);
    expect(find.text('Find options'), findsOneWidget);
  });
}
