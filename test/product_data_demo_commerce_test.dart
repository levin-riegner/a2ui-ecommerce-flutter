import 'dart:io';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/demo_commerce.dart';
import 'package:a2ui_flutter_commerce/src/data/product_attributes.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_shared_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

import 'stylist_component_adoption_test.dart' show actual, choose, components;
import 'stylist_library_test.dart' show event, data;
import 'stylist_store_helpers.dart';

Future<StylistRuntime> look(
  MemoryStylistStore store, {
  void Function()? onModel,
}) async {
  final runtime = StylistRuntime(
    products: [actual('demo-0198'), actual('demo-0092')],
    store: store,
    now: () => DateTime.utc(2026, 10, 15),
    onModelRequest: (_) => onModel?.call(),
  );
  await runtime.turn({
    'message':
        "Women's dress under €500; I already own shoes; I already own a bag",
  });
  await runtime.turn(choose('demo-0198'));
  return runtime;
}

Map quoteAction(Map result) =>
    components(result).singleWhere(
          (c) => c['id'] == 'confirm-demo-checkout',
        )['action']['event']['context']
        as Map;

void main() {
  test('all 977 products have reproducible attribute evidence and coherent fictional variants', () {
    final products = parseCatalogProducts(
      File('assets/data/catalog/products.csv').readAsStringSync(),
    );
    expect(products, hasLength(977));
    final variantIds = <String>{};
    for (final p in products) {
      final text = {
        'name': p.name,
        'description': p.description,
        'subcategory': p.subcategory,
        'keywords': p.keywords,
        'material': p.material,
        'occasion': p.occasion,
      };
      for (final attribute in p.attributes.values.values.where(
        (a) => a.known,
      )) {
        expect(text[attribute.field], contains(attribute.quote), reason: p.id);
        expect(attribute.toMap()['verified'], false);
      }
      expect(p.attributes['weather_performance'].known, false);
      if (p.material == 'unspecified') {
        expect(p.attributes['material'].known, false);
      }
      expect(
        p.sizeOptions,
        isNotEmpty,
        reason: '${p.id} needs configured catalog sizes',
      );
      final variants = const DemoCommerce().variants(p);
      expect(variants.map((v) => v.size), p.sizeOptions, reason: p.id);
      expect(variants.where((v) => v.stock > 0), isNotEmpty);
      for (final v in variants) {
        expect(variantIds.add(v.id), true);
        expect(v.toMap()['source'], 'local_demo_fixture');
      }
    }
  });

  test('configured item sizes override category defaults', () {
    final product = parseCatalogProducts(
      'id,name,brand,price_eur,category,size_options,variant_group\n'
      'configured-1,Occasion dress,Alder,95,dress,Petite|Tall,occasion-style\n',
    ).single;
    expect(product.sizeOptions, ['Petite', 'Tall']);
    expect(product.variantGroup, 'occasion-style');
    expect(const DemoCommerce().variants(product).map((v) => v.size), [
      'Petite',
      'Tall',
    ]);
  });

  test('classification respects negation and ignores styling advice about other garments', () {
    final facts = ProductAttributes.fromCatalog({
      'category': 'layer',
      'name': 'Coat',
      'description':
          'A coat that is not lightweight. Pair with a fitted midi dress.',
    });
    expect(facts['layering_weight'].known, false);
    expect(facts['silhouette'].known, false);
    expect(facts['length'].known, false);
    final smart = ProductAttributes.fromCatalog({
      'category': 'top',
      'name': 'Smart-casual shirt',
    });
    expect(smart['formality'].value, 'smart casual');
    expect(smart['formality'].basis, 'styling_inference');
  });

  test('demo sizes, stock, delivery, checkout and receipt survive restart without model calls', () async {
    final store = MemoryStylistStore();
    var calls = 0;
    final runtime = await look(store, onModel: () => calls++);
    addTearDown(runtime.dispose);
    final before = calls;
    await runtime.turn(event('add_look_to_bag'));
    await expectLater(
      runtime.turn(event('preview_demo_checkout')),
      throwsA(isA<StylistInputError>()),
    );
    final detail = await runtime.turn(
      event('open_product_details', {'productId': 'demo-0198'}),
    );
    expect(data(detail)['productDetails']['sizes'], contains('M'));
    await runtime.turn(
      event('set_fit_size', {
        'productId': 'demo-0198',
        'size': 'M',
        'fit': 'Relaxed',
      }),
    );
    await runtime.turn(
      event('change_bag_quantity', {'productId': 'demo-0198', 'quantity': 2}),
    );
    final preview = await runtime.turn(event('preview_demo_checkout'));
    expect(
      components(preview).map((c) => c['component']),
      contains('DeliveryEstimate'),
    );
    expect(preview['reply'], contains('fictional'));
    final confirmation = Map<String, Object?>.from(quoteAction(preview));
    final paid = await runtime.turn(
      event('confirm_demo_checkout', confirmation),
    );
    final receipt = data(paid)['demoReceipt'];
    expect(receipt['mode'], 'local_demo');
    expect(receipt['status'], 'simulated');
    expect(receipt['totalCents'], 11395);
    expect(receipt['delivery']['earliestDate'], '2026-10-18');
    expect(receipt['delivery']['latestDate'], '2026-10-20');
    expect(runtime.bagCount, 0);
    expect(paid['brief']['budget'], 500);
    expect(paid['brief']['gender'], 'female');
    expect(paid['outfit']['items'], {'dress': 'demo-0198'});
    await expectLater(
      runtime.turn(event('confirm_demo_checkout', confirmation)),
      throwsA(isA<StylistInputError>()),
    );
    expect(calls, before);
    final second = StylistRuntime(
      products: [actual('demo-0198'), actual('demo-0092')],
      store: store,
      model: (_) => throw StateError('No model needed'),
    );
    addTearDown(second.dispose);
    await second.loadLocalState();
    final restored = await second.turn(event('open_demo_receipt'));
    expect(data(restored)['demoReceipt']['id'], receipt['id']);
    final details = await second.turn(
      event('open_product_details', {'productId': 'demo-0198'}),
    );
    expect(data(details)['productDetails']['size'], 'M');
    expect(data(details)['productDetails']['fit'], 'Relaxed');
    expect(data(details)['productDetails']['stockText'], contains('M: 4'));
  });

  test(
    'undo removal preserves the chosen size and checkout eligibility',
    () async {
      final store = MemoryStylistStore();
      final runtime = await look(store);
      addTearDown(runtime.dispose);
      await runtime.turn(event('add_look_to_bag'));
      await runtime.turn(
        event('set_fit_size', {
          'productId': 'demo-0198',
          'size': 'M',
          'fit': 'Regular',
        }),
      );
      final before = await runtime.turn(event('open_bag'));
      final variant = data(before)['bagItems'].single['variantId'];
      expect(variant, isNotNull);
      await runtime.turn(event('remove_bag_item', {'productId': 'demo-0198'}));
      final restored = await runtime.turn(
        event('restore_bag_item', {'productId': 'demo-0198', 'quantity': 1}),
      );
      expect(data(restored)['bagItems'].single['variantId'], variant);
      expect(data(restored)['bagItems'].single['size'], 'M');
      expect(
        quoteAction(await runtime.turn(event('preview_demo_checkout'))),
        isNotEmpty,
      );
    },
  );

  test('stock limits, stale quotes and failed storage do not consume inventory or lose a bag', () async {
    final store = MemoryStylistStore();
    final runtime = await look(store);
    addTearDown(runtime.dispose);
    await runtime.turn(event('add_look_to_bag'));
    await runtime.turn(
      event('set_fit_size', {
        'productId': 'demo-0198',
        'size': 'M',
        'fit': 'Regular',
      }),
    );
    await expectLater(
      runtime.turn(
        event('change_bag_quantity', {'productId': 'demo-0198', 'quantity': 7}),
      ),
      throwsA(isA<StylistInputError>()),
    );
    expect(runtime.bagCount, 1);
    final old = await runtime.turn(event('preview_demo_checkout'));
    await runtime.turn(
      event('change_bag_quantity', {'productId': 'demo-0198', 'quantity': 2}),
    );
    await expectLater(
      runtime.turn(
        event(
          'confirm_demo_checkout',
          Map<String, Object?>.from(quoteAction(old)),
        ),
      ),
      throwsA(isA<StylistInputError>()),
    );
    final preview = await runtime.turn(event('preview_demo_checkout'));
    final baseline = store.encoded;
    store.beforeWrite = () async => throw StateError('Storage unavailable');
    await expectLater(
      runtime.turn(
        event(
          'confirm_demo_checkout',
          Map<String, Object?>.from(quoteAction(preview)),
        ),
      ),
      throwsA(isA<StylistInputError>()),
    );
    expect(runtime.bagCount, 2);
    expect(store.encoded, baseline);
    store.beforeWrite = null;
    final details = await runtime.turn(
      event('open_product_details', {'productId': 'demo-0198'}),
    );
    expect(data(details)['productDetails']['stockText'], contains('M: 6'));
    await expectLater(
      runtime.turn(
        event('set_fit_size', {'productId': 'demo-0198', 'size': '999'}),
      ),
      throwsA(isA<StylistInputError>()),
    );
  });

  test('plain-language usual size is acknowledged, retained and offered as a draft', () async {
    final store = MemoryStylistStore();
    final runtime = await look(store);
    addTearDown(runtime.dispose);
    final response = await runtime.turn({'message': 'I usually wear M'});
    expect(response['reply'], contains('Usual size M noted'));
    final details = await runtime.turn(
      event('open_product_details', {'productId': 'demo-0198'}),
    );
    expect(data(details)['productDetails']['size'], 'M');
    expect(((await store.read())!['current'] as Map)['fit']['usualSize'], 'M');
    expect(details['brief']['budget'], 500);
    expect(details['brief']['gender'], 'female');
  });

  test('shoe sizes do not overwrite clothing size preferences on a new look', () async {
    final store = MemoryStylistStore();
    final runtime = StylistRuntime(
      products: parseCatalogProducts(
        File('assets/data/catalog/products.csv').readAsStringSync(),
      ),
      store: store,
    );
    addTearDown(runtime.dispose);
    await runtime.turn({
      'message': "Women's dress under €500; I already own a bag",
    });
    final next = await runtime.turn(choose('demo-0198'));
    final shoeId = (next['products'] as List).first['id'];
    await runtime.turn(
      event('set_fit_size', {
        'productId': 'demo-0198',
        'size': 'M',
        'fit': 'Regular',
      }),
    );
    await runtime.turn(
      event('set_fit_size', {
        'productId': shoeId,
        'size': '41',
        'fit': 'Regular',
      }),
    );
    await runtime.turn(event('reset_look'));
    await runtime.turn({
      'message':
          "Women's dress under €500; I already own shoes; I already own a bag",
    });
    final detail = await runtime.turn(
      event('open_product_details', {'productId': 'demo-0198'}),
    );
    expect(data(detail)['productDetails']['size'], 'M');
    expect(((await store.read())!['current'] as Map)['fit']['usualSizes'], {
      'clothing': 'M',
      'shoes': '41',
    });
  });

  testWidgets(
    'real controls apply a size, preview delivery and complete only a simulated checkout',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final store = MemoryStylistStore();
      final seed = (await tester.runAsync(() => look(store)))!;
      await tester.runAsync(seed.dispose);
      final runtime = (await tester.runAsync(
        () async => StylistRuntime(
          products: [actual('demo-0198'), actual('demo-0092')],
          store: store,
        ),
      ))!;
      final agent = (await tester.runAsync(() async => GenkitAgent(runtime)))!;
      await tester.runAsync(agent.resumeLocalState);
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
        await tester.pump();
        expect(finder.hitTestable(), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        for (var i = 0; i < 100 && agent.isBusy; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(agent.connectionError, isNull);
        expect(agent.inputError, isNull);
      }

      await tap(find.text('Add look to demo bag · €55.00').last);
      await tap(
        find.byTooltip('Choose size · Black Sheer-Panel Maxi Dress').last,
      );
      expect(find.byType(FinalizedFitSize), findsOneWidget);
      expect(find.text('Save size & fit'), findsOneWidget);
      expect(find.text('Back to your look'), findsNothing);
      final sizeButton = find.byWidgetPredicate(
        (w) => w is FinalizedPrimaryButton && w.label == 'Save size & fit',
      );
      expect(
        tester.widget<FinalizedPrimaryButton>(sizeButton).onPressed,
        isNull,
      );
      for (final text in ['Material:', 'Length:', 'Silhouette:', 'A black']) {
        expect(find.textContaining(text), findsNothing);
      }
      for (final removed in [
        'Illustrative demo',
        'Fictional demo stock',
        'Evidence:',
        'actual fit unverified',
        'Apply demo',
      ]) {
        expect(find.textContaining(removed), findsNothing);
      }
      expect(
        agent.controller
            .contextFor(agent.latestInlineSurfaceId!)
            .dataModel
            .getValue<Object?>(DataPath('/productDetails/guideText')),
        isNull,
      );
      await tap(
        find.descendant(
          of: find.byType(FinalizedFitSize),
          matching: find.text('M'),
        ),
      );
      expect(
        tester.widget<FinalizedPrimaryButton>(sizeButton).onPressed,
        isNull,
      );
      await tap(
        find.descendant(
          of: find.byType(FinalizedFitSize),
          matching: find.text('Relaxed'),
        ),
      );
      expect(
        tester.widget<FinalizedPrimaryButton>(sizeButton).onPressed,
        isNotNull,
      );
      await tap(find.text('Save size & fit').last);
      expect(
        agent.controller
            .contextFor(agent.latestInlineSurfaceId!)
            .definition
            .value!
            .components
            .containsKey('detail-fit'),
        isFalse,
      );
      expect(runtime.bagCount, 1);
      expect(find.text('Demo bag (1)'), findsNothing);
      await tap(find.byType(FinalizedBagIcon).last);
      await tap(find.text('Check out').last);
      expect(find.textContaining('LOCAL DEMO CHECKOUT'), findsOneWidget);
      await tap(find.text('Complete demo checkout — no payment').last);
      expect(runtime.bagCount, 0);
      expect(find.textContaining('SIMULATED RECEIPT'), findsOneWidget);
      expect(runtime.outfit['budget'], 500);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
