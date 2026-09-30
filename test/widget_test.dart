import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
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
    expect(csvProducts.first.name, isNotEmpty);
    expect(csvProducts.first.id, startsWith('demo-'));
    expect(csvProducts.first.imageAsset, startsWith('assets/images/products/'));
  });

  test('public CSV loads 200 products and supports filtered search', () async {
    final repository = CsvProductRepository();
    final all = await repository.search(limit: 250);
    expect(all, hasLength(200));
    final matches = await repository.search(
      category: 'shoes',
      season: 'summer',
      maxPrice: 200,
      limit: 5,
    );
    expect(matches, isNotEmpty);
    expect(matches.length, lessThanOrEqualTo(5));
    for (final product in matches) {
      expect(product.category, ProductCategory.shoes);
      expect(['summer', 'all-season'], contains(product.season.toLowerCase()));
      expect(product.price, lessThanOrEqualTo(200));
    }
  });

  test('category filters use categories rather than keyword matches', () async {
    final repository = CsvProductRepository(
      bundle: _CsvBundle(
        'id,name,brand,category,subcategory,price_eur,keywords\n'
        'shoe-1,Low-Top Sneaker,Demo,shoes,sneakers,90,low-top summer\n'
        'top-1,Linen Shirt,Demo,top,shirt,80,summer shirt\n',
      ),
    );

    expect((await repository.search(category: 'top')).map((p) => p.id), [
      'top-1',
    ]);
    expect(await repository.search(category: 'summer'), isEmpty);
    expect((await repository.search(category: ' TOP ')).map((p) => p.id), [
      'top-1',
    ]);
    expect((await repository.search(query: 'low-top')).map((p) => p.id), [
      'shoe-1',
    ]);
  });

  test(
    'catalog recommendations rank the demo occasion and remain stable',
    () async {
      final repository = CsvProductRepository();
      final expected = <DemoJourney, String>{
        DemoJourney.paris: 'demo-0092',
        DemoJourney.berlin: 'demo-0027',
        DemoJourney.cotswolds: 'demo-0077',
        DemoJourney.lisbon: 'demo-0113',
      };
      for (final journey in DemoJourney.values) {
        final products = await repository.recommendations(
          journey: journey,
          category: journey.foundationCategory,
          limit: 1,
        );
        expect(products.single.id, expected[journey], reason: journey.name);
        expect(products.single.price, lessThanOrEqualTo(journey.budget));
      }
    },
  );

  test('CSV parsing preserves quoted descriptions and loads once', () async {
    final bundle = _CsvBundle(
      'id,name,brand,description,category,subcategory,color,material,season,occasion,price_eur,image_asset,keywords\n'
      'demo-1,"A ""soft"" dress",Demo,"Line one\nLine two, still description",dress,midi,blue,cotton,summer,evening,120,assets/images/products/demo-1.jpg,soft dress\n',
    );
    final repository = CsvProductRepository(bundle: bundle);
    final first = await repository.search(query: 'soft dress');
    final second = await repository.search(query: 'line two');
    expect(first.single.name, 'A "soft" dress');
    expect(second.single.description, 'Line one\nLine two, still description');
    expect(bundle.reads, 1);
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
      isNotEmpty,
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

  testWidgets('injected fixture preserves catalog photo previews', (
    tester,
  ) async {
    final options = (await tester.runAsync(
      () => CsvProductRepository().recommendations(
        journey: DemoJourney.paris,
        category: ProductCategory.shoes,
      ),
    ))!;
    await tester.pumpWidget(
      ReferenceApp(agent: StubAgent(repository: CsvProductRepository())),
    );
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
      if (find.text(options.first.name).evaluate().isNotEmpty) break;
    }

    expect(find.text(options.first.name), findsOneWidget);
    final firstCard = find
        .ancestor(
          of: find.text(options.first.name),
          matching: find.byType(InkWell),
        )
        .first;
    expect(
      find.descendant(of: firstCard, matching: find.text('Shoes')),
      findsNothing,
    );

    await tester.tap(find.text(options[1].name));
    await tester.pumpAndSettle();
    expect(find.text(options[1].name), findsNWidgets(2));
    final productImages = tester.widgetList<Image>(find.byType(Image));
    expect(productImages, isNotEmpty);
    expect(productImages.every((image) => image.fit == BoxFit.contain), isTrue);
    expect(
      productImages.where(
        (image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName == options[1].imageAsset,
      ),
      hasLength(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('start screen opens the component catalog', (tester) async {
    await tester.pumpWidget(const ReferenceApp(serviceUrl: ''));

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

    await tester.pumpWidget(
      ReferenceApp(agent: StubAgent(repository: CsvProductRepository())),
    );
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

    await tester.pumpWidget(
      ReferenceApp(agent: StubAgent(repository: CsvProductRepository())),
    );
    await tester.tap(find.text(DemoJourney.paris.title));
    await tester.pumpAndSettle();

    final dressingRoomTitle = find.text('Dressing room');
    expect(dressingRoomTitle, findsOneWidget);
    expect(tester.getTopLeft(dressingRoomTitle).dy, lessThan(140));
    expect(find.text('How formal?'), findsOneWidget);
    expect(find.text('Season'), findsOneWidget);
    expect(find.text('Find options'), findsOneWidget);
  });
  testWidgets('mobile header can start another journey', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ReferenceApp(agent: StubAgent(repository: CsvProductRepository())),
    );
    await tester.tap(find.text(DemoJourney.paris.title));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New journey'));
    await tester.pumpAndSettle();
    expect(find.text('Build the look\naround the moment.'), findsOneWidget);

    await tester.tap(find.text(DemoJourney.berlin.title));
    await tester.pumpAndSettle();
    expect(find.text('Dressing room'), findsOneWidget);
    expect(find.text('Build the look\naround the moment.'), findsNothing);
  });
}

class _CsvBundle extends CachingAssetBundle {
  _CsvBundle(this.source);

  final String source;
  int reads = 0;

  @override
  Future<ByteData> load(String key) async {
    reads++;
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(source)));
  }
}
