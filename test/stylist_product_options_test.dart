import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/commerce_components.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'progressive_agent_test.dart' show action;
import 'stylist_library_test.dart' show data, event;
import 'stylist_store_helpers.dart';

const blue = Product(
  id: 'blue',
  category: ProductCategory.dress,
  name: 'Blue dress',
  brand: 'Alder',
  price: 80,
  meta: 'Blue',
  tag: 'Summer',
  swatch: '#3344ff',
  color: 'blue',
  gender: 'female',
  sizeOptions: ['S', 'M'],
  variantGroup: 'occasion-dress',
);
const black = Product(
  id: 'black',
  category: ProductCategory.dress,
  name: 'Black dress',
  brand: 'Alder',
  price: 90,
  meta: 'Black',
  tag: 'Summer',
  swatch: '#111111',
  color: 'black',
  gender: 'female',
  sizeOptions: ['M', 'L'],
  variantGroup: 'occasion-dress',
);
const other = Product(
  id: 'other',
  category: ProductCategory.dress,
  name: 'Red dress',
  brand: 'Alder',
  price: 80,
  meta: 'Red',
  tag: 'Summer',
  swatch: '#ff0000',
  color: 'red',
  gender: 'female',
  sizeOptions: ['M'],
  variantGroup: 'another-dress',
);
const one = Product(
  id: 'one',
  category: ProductCategory.dress,
  name: 'Wrap dress',
  brand: 'Alder',
  price: 80,
  meta: 'Blue',
  tag: 'Summer',
  swatch: '#3344ff',
  color: 'blue',
  gender: 'female',
  sizeOptions: ['One size'],
);
const brief =
    "Women's dress for a summer wedding, smart casual under €500; I already own shoes and I already own a bag";

Future<void> settleTurn(WidgetTester tester, GenkitAgent agent) async {
  await tester.pump();
  for (var i = 0; i < 300 && agent.isBusy; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(agent.isBusy, false);
  await tester.pumpAndSettle();
}

void main() {
  test('linked colour and size choices save the actual product and survive restore without model calls', () async {
    final store = MemoryStylistStore();
    var calls = 0;
    final runtime = StylistRuntime(
      products: [blue, black, other],
      store: store,
      onModelRequest: (_) => calls++,
    );
    addTearDown(runtime.dispose);
    await runtime.turn({'message': brief});
    final selected = await runtime.turn(
      event('select_product', {'productId': blue.id}),
    );
    final options = data(selected)['selectionOptions'] as Map;
    expect((options['choices'] as List).map((row) => row['id']), [
      'blue',
      'black',
    ]);
    final count = calls;
    final saved = await runtime.turn(
      event('set_product_options', {
        'productId': 'blue',
        'colourProductId': 'black',
        'size': 'L',
        'fit': 'Regular',
      }),
    );
    expect(calls, count);
    expect(runtime.outfit['items'], {'dress': 'black'});
    expect(data(saved)['selectionOptions'], isNull);
    final details = await runtime.turn(
      event('open_product_details', {'productId': 'black'}),
    );
    expect(data(details)['productDetails']['size'], 'L');
    final restored = StylistRuntime(
      products: [blue, black, other],
      store: store,
    );
    addTearDown(restored.dispose);
    await restored.loadLocalState();
    expect(restored.outfit['items'], {'dress': 'black'});
    final restoredDetails = await restored.turn(
      event('open_product_details', {'productId': 'black'}),
    );
    expect(data(restoredDetails)['productDetails']['size'], 'L');
  });

  test(
    'unrelated colours and invalid size/colour combinations roll back',
    () async {
      final store = MemoryStylistStore();
      final runtime = StylistRuntime(
        products: [blue, black, other],
        store: store,
      );
      addTearDown(runtime.dispose);
      await runtime.turn({'message': brief});
      await runtime.turn(event('select_product', {'productId': 'blue'}));
      final baseline = store.encoded;
      for (final context in [
        {'productId': 'blue', 'colourProductId': 'other', 'size': 'M'},
        {'productId': 'blue', 'colourProductId': 'black', 'size': 'S'},
        {'productId': 'other', 'colourProductId': 'black', 'size': 'L'},
        {'productId': 'blue', 'colourProductId': 'black', 'size': ''},
        {
          'productId': 'blue',
          'colourProductId': 'black',
          'size': 'L',
          'fit': '',
        },
      ]) {
        await expectLater(
          runtime.turn(event('set_product_options', context)),
          throwsA(isA<StylistInputError>()),
        );
        expect(runtime.outfit['items'], {'dress': 'blue'});
        expect(store.encoded, baseline);
      }
    },
  );

  test(
    'single-option products skip the prompt and colours are never inferred',
    () async {
      final runtime = StylistRuntime(products: [one]);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': brief});
      final selected = await runtime.turn(
        event('select_product', {'productId': 'one'}),
      );
      expect(data(selected)['selectionOptions'], isNull);
      final details = await runtime.turn(
        event('open_product_details', {'productId': 'one'}),
      );
      expect(data(details)['productDetails']['size'], 'One size');
      final onlySize = StylistRuntime(products: [blue, other]);
      addTearDown(onlySize.dispose);
      await onlySize.turn({'message': brief});
      final size = await onlySize.turn(
        event('select_product', {'productId': 'blue'}),
      );
      expect(data(size)['selectionOptions']['choices'], hasLength(1));
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'selection uses existing inline selectors and saves at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final runtime = (await tester.runAsync(
          () async => StylistRuntime(products: [blue, black, other]),
        ))!;
        final agent = (await tester.runAsync(
          () async => GenkitAgent(runtime),
        ))!;
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.runAsync(() => agent.startBrief(brief));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('product-options-dialog')),
          findsNothing,
        );
        await tester.runAsync(
          () => agent.conversation.sendRequest(
            action('select_product', {'productId': 'blue'}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(FinalizedColourPicker), findsOneWidget);
        expect(find.byType(FinalizedFitSize), findsOneWidget);
        expect(
          find.text(
            'Selected Blue dress. €420.00 left in your budget. Choose your size and preferred fit below.',
          ),
          findsOneWidget,
        );
        Finder save() => find.text('Save size & fit').last;
        Future<void> choose(String label) async {
          final choice = find
              .byWidgetPredicate((w) => w is CommerceChoice && w.label == label)
              .last;
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
        }

        await choose('M');
        final colour = find
            .byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Black',
            )
            .last;
        await tester.ensureVisible(colour);
        await tester.runAsync(() async => tester.tap(colour));
        await settleTurn(tester, agent);
        expect(runtime.outfit['items'], {'dress': 'black'});
        expect(
          tester
              .widget<FinalizedFitSize>(find.byType(FinalizedFitSize).last)
              .sizes,
          ['M', 'L'],
        );
        await choose('L');
        await choose('Regular');
        await tester.ensureVisible(save());
        await tester.runAsync(() async {
          await tester.tap(save());
        });
        await settleTurn(tester, agent);
        expect(
          find.byKey(const ValueKey('product-options-dialog')),
          findsNothing,
        );
        expect(runtime.outfit['items'], {'dress': 'black'});
        expect(agent.inputError, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('one colour shows only size choices', (tester) async {
    final agent = (await tester.runAsync(
      () async => GenkitAgent(StylistRuntime(products: [blue])),
    ))!;
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.runAsync(() => agent.startBrief(brief));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => agent.conversation.sendRequest(
        action('select_product', {'productId': 'blue'}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FinalizedColourPicker), findsNothing);
    expect(find.byType(FinalizedFitSize), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('product-options-dialog')), findsNothing);
    expect(agent.connectionError, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
