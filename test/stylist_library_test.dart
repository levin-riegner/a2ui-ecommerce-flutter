import 'stylist_wire_helpers.dart';

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/src/data/local_stylist_store.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:a2ui_flutter_commerce/src/data/stylist_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'stylist_component_adoption_test.dart' show actual, choose, components;
import 'stylist_store_helpers.dart';
import 'progressive_agent_test.dart' show action;

final libraryCatalog = [
  for (final id in [
    'demo-0092',
    'demo-0198',
    'demo-0579',
    'demo-0060',
    'demo-0026',
    'demo-0195',
  ])
    actual(id),
];
Map<String, dynamic> event(
  String name, [
  Map<String, Object?> context = const {},
]) => {
  'action': {'name': name, 'context': context},
};
Map data(Map result) =>
    (presentedStylistTurn(result)['messages'] as List)
            .last['updateDataModel']['value']
        as Map;
Future<StylistRuntime> completed({StylistStore? store}) async {
  final runtime = StylistRuntime(products: libraryCatalog, store: store);
  await runtime.turn({
    'message':
        "Women's dress under €500; I already own shoes; I already own a bag",
  });
  await runtime.turn(choose('demo-0092'));
  return runtime;
}

Product repriced(Product p, double price, {String? gender}) => Product(
  id: p.id,
  category: p.category,
  name: p.name,
  brand: p.brand,
  price: price,
  meta: p.meta,
  tag: p.tag,
  swatch: p.swatch,
  description: p.description,
  subcategory: p.subcategory,
  gender: gender ?? p.gender,
  color: p.color,
  material: p.material,
  season: p.season,
  occasion: p.occasion,
  imageAsset: p.imageAsset,
  keywords: p.keywords,
);

void main() {
  test('typed save and bag commands acknowledge real local changes with zero model calls', () async {
    var calls = 0;
    final runtime = StylistRuntime(
      products: libraryCatalog,
      onModelRequest: (_) => calls++,
    );
    addTearDown(runtime.dispose);
    await runtime.turn({
      'message':
          "Women's dress under €500; I already own shoes; I already own a bag",
    });
    await runtime.turn(choose('demo-0092'));
    final before = calls;
    final saved = await runtime.turn({'message': 'Can you save this look?'});
    expect(
      components(saved).map((c) => c['component']),
      contains('SavedLooksRail'),
    );
    await runtime.turn({'message': 'Add this look to my bag'});
    final bag = await runtime.turn({'message': "What's in my bag?"});
    expect(data(bag)['bagItems'].single['id'], 'demo-0092');
    expect(calls, before);
  });
  test('equal-priced cached pieces are not cheaper and an explicit correction releases that cap', () async {
    final runtime = StylistRuntime(
      products: [actual('demo-0092'), repriced(actual('demo-0198'), 230)],
    );
    addTearDown(runtime.dispose);
    await runtime.turn({
      'message':
          "Women's dress under €500; I already own shoes; I already own a bag",
    });
    await runtime.turn(choose('demo-0092'));
    final empty = await runtime.turn(
      event('adjust_piece', {
        'productId': 'demo-0092',
        'category': 'dress',
        'adjustment': 'Cheaper',
      }),
    );
    expect(empty['products'], isEmpty);
    expect(empty['reply'], contains('no lower-priced compatible alternatives'));
    await expectLater(
      runtime.turn(choose('demo-0198')),
      throwsA(isA<StylistInputError>()),
    );
    final correction = await runtime.turn({'message': 'Not cheaper please'});
    expect(correction['reply'], contains('do not have to be cheaper'));
    expect((correction['products'] as List).single['id'], 'demo-0198');
    await runtime.turn(choose('demo-0198'));
    expect(runtime.outfit['items'], {'dress': 'demo-0198'});
  });
  test('save, restore, delete and reset preserve catalog IDs and accepted provenance', () async {
    final store = MemoryStylistStore();
    final runtime = await completed(store: store);
    addTearDown(runtime.dispose);
    final saved = await runtime.turn(event('save_look'));
    expect(
      components(saved).map((c) => c['component']),
      containsAll(['SavedLooksRail', 'Toast']),
    );
    final snapshot = (await store.read())!;
    expect((snapshot['looks'] as List), hasLength(1));
    final brief = (snapshot['current'] as Map)['brief'] as Map;
    expect(brief['sources']['gender'], 'user');
    expect(brief['facts']['budget'], 500);
    expect(
      brief['constraints']['ownedCategories'],
      containsAll(['shoes', 'bag']),
    );
    expect(store.encoded, isNot(contains('apiKey')));
    expect(store.encoded, isNot(contains('history')));
    await runtime.turn(event('save_look'));
    expect((await store.read())!['looks'], hasLength(1));
    await runtime.turn(event('reset_look'));
    expect(runtime.outfit['items'], isEmpty);
    final loaded = await runtime.turn(
      event('restore_look', {'lookId': 'look-1'}),
    );
    expect(loaded['outfit']['items'], {'dress': 'demo-0092'});
    expect(loaded['brief']['gender'], 'female');
    expect(loaded['brief']['budget'], 500);
    expect(data(loaded)['look']['meta'], contains('Owned:'));
    await runtime.turn(event('delete_look', {'lookId': 'look-1'}));
    expect((await store.read())!['looks'], isEmpty);
    await expectLater(
      runtime.turn(event('restore_look', {'lookId': 'look-1'})),
      throwsA(isA<StylistInputError>()),
    );
    expect(runtime.outfit['items'], {'dress': 'demo-0092'});
  });

  test(
    'a second runtime restores preferences, look and bag without model calls',
    () async {
      final store = MemoryStylistStore();
      final first = await completed(store: store);
      await first.turn(
        event('update_preferences', {
          'colours': ['Blue'],
          'love': ['Pale Lantern'],
          'skip': ['Cloud Circuit'],
        }),
      );
      await first.turn(event('save_look'));
      await first.turn(event('add_look_to_bag'));
      await first.turn(
        event('change_bag_quantity', {'productId': 'demo-0092', 'quantity': 2}),
      );
      await first.dispose();
      var calls = 0;
      final second = StylistRuntime(
        products: libraryCatalog,
        store: store,
        model: (_) async {
          calls++;
          throw StateError('No model needed');
        },
      );
      addTearDown(second.dispose);
      expect(await second.loadLocalState(), true);
      final restored = await second.turn(event('resume_session'));
      expect(calls, 0);
      expect(restored['outfit']['items'], {'dress': 'demo-0092'});
      expect(restored['brief']['budget'], 500);
      expect(restored['constraints']['preferredBrands'], ['pale lantern']);
      expect(restored['constraints']['preferredColors'], ['blue']);
      expect(restored['constraints']['excludedBrands'], ['cloud circuit']);
      expect(second.bagCount, 2);
      final bag = await second.turn(event('open_bag'));
      expect(data(bag)['bagItems'].single['quantity'], 2);
      expect(data(bag)['bagItems'].single['unitPrice'], 230);
      expect(calls, 0);
      second.reset();
      final library = await second.turn(event('open_saved_looks'));
      expect(data(library)['savedLooks'], hasLength(1));
      expect(second.bagCount, 2);
    },
  );

  test('SDK-backed local store reads a second instance and stores only its namespace', () async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    final platform = MemoryPreferencePlatform();
    SharedPreferencesAsyncPlatform.instance = platform;
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    final first = await completed(store: LocalStylistStore());
    await first.turn(event('save_look'));
    await first.dispose();
    final second = StylistRuntime(
      products: libraryCatalog,
      store: LocalStylistStore(),
    );
    addTearDown(second.dispose);
    expect(await second.loadLocalState(), true);
    expect(second.outfit['items'], {'dress': 'demo-0092'});
    expect(platform.values.keys, [LocalStylistStore.storageKey]);
    expect(jsonDecode(platform.values.values.single)['version'], 1);
  });

  test('changed prices or missing products reject restore without replacing the working look', () async {
    final store = MemoryStylistStore();
    final first = await completed(store: store);
    await first.turn(event('save_look'));
    await first.dispose();
    for (final catalog in [
      [
        for (final p in libraryCatalog)
          if (p.id != 'demo-0092') p,
      ],
      [
        for (final p in libraryCatalog)
          p.id == 'demo-0092' ? repriced(p, 600) : p,
      ],
      [
        for (final p in libraryCatalog)
          p.id == 'demo-0092' ? repriced(p, p.price, gender: 'male') : p,
      ],
    ]) {
      final runtime = StylistRuntime(products: catalog, store: store);
      expect(await runtime.loadLocalState(), false);
      final before = store.encoded;
      await expectLater(
        runtime.turn(event('restore_look', {'lookId': 'look-1'})),
        throwsA(isA<StylistInputError>()),
      );
      expect(runtime.outfit['items'], isEmpty);
      expect(store.encoded, before);
      await runtime.dispose();
    }
  });

  test('demo bag uses host quantities, validates stale undo and preserves the working outfit', () async {
    final store = MemoryStylistStore();
    final runtime = await completed(store: store);
    addTearDown(runtime.dispose);
    await runtime.turn(event('add_look_to_bag'));
    await runtime.turn(event('add_look_to_bag'));
    expect(runtime.bagCount, 1);
    final updated = await runtime.turn(
      event('change_bag_quantity', {'productId': 'demo-0092', 'quantity': 2}),
    );
    expect(data(updated)['bagItems'].single['quantity'], 2);
    expect(runtime.bagCount, 2);
    expect(runtime.outfit['items'], {'dress': 'demo-0092'});
    for (final quantity in [-1, 0, 100, 1.5, '2']) {
      await expectLater(
        runtime.turn(
          event('change_bag_quantity', {
            'productId': 'demo-0092',
            'quantity': quantity,
          }),
        ),
        throwsA(isA<StylistInputError>()),
      );
      expect(runtime.bagCount, 2);
    }
    await runtime.turn(event('remove_bag_item', {'productId': 'demo-0092'}));
    expect(runtime.bagCount, 0);
    await expectLater(
      runtime.turn(
        event('restore_bag_item', {'productId': 'demo-0092', 'quantity': 1}),
      ),
      throwsA(isA<StylistInputError>()),
    );
    await runtime.turn(
      event('restore_bag_item', {'productId': 'demo-0092', 'quantity': 2}),
    );
    expect(runtime.bagCount, 2);
    await expectLater(
      runtime.turn(
        event('restore_bag_item', {'productId': 'demo-0092', 'quantity': 2}),
      ),
      throwsA(isA<StylistInputError>()),
    );
  });

  test('undoing a look addition restores earlier quantities instead of clearing the bag', () async {
    final runtime = await completed();
    addTearDown(runtime.dispose);
    await runtime.turn(event('add_look_to_bag'));
    await runtime.turn(
      event('change_bag_quantity', {'productId': 'demo-0092', 'quantity': 2}),
    );
    await runtime.turn(choose('demo-0198'));
    await runtime.turn(event('add_look_to_bag'));
    expect(runtime.bagCount, 3);
    final undone = await runtime.turn(event('undo_bag_changes'));
    expect(data(undone)['bagItems'].single['id'], 'demo-0092');
    expect(data(undone)['bagItems'].single['quantity'], 2);
    expect(runtime.outfit['items'], {'dress': 'demo-0198'});
  });

  test('failed or cancelled storage writes keep both committed outfit and stored snapshot', () async {
    final store = MemoryStylistStore();
    final runtime = await completed(store: store);
    addTearDown(runtime.dispose);
    final baseline = store.encoded;
    store.beforeWrite = () async {
      store.beforeWrite = null;
      throw StateError('Disk unavailable');
    };
    await expectLater(
      runtime.turn(event('add_look_to_bag')),
      throwsA(isA<StylistInputError>()),
    );
    expect(runtime.bagCount, 0);
    expect(store.encoded, baseline);
    final entered = Completer<void>(), release = Completer<void>();
    store.beforeWrite = () async {
      store.beforeWrite = null;
      entered.complete();
      await release.future;
    };
    final pending = runtime.turn(event('add_look_to_bag'));
    final rejected = expectLater(pending, throwsA(anything));
    await entered.future;
    runtime.cancelActiveTurn();
    release.complete();
    await rejected;
    expect(runtime.bagCount, 0);
    expect(store.encoded, baseline);
    expect(runtime.outfit['items'], {'dress': 'demo-0092'});
  });

  testWidgets(
    'actual controls save, add, change quantity, remove, undo and restore a look',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final store = MemoryStylistStore();
      final seed = (await tester.runAsync(() => completed(store: store)))!;
      await tester.runAsync(seed.dispose);
      final runtime = (await tester.runAsync(
        () async => StylistRuntime(products: libraryCatalog, store: store),
      ))!;
      final agent = (await tester.runAsync(() async => GenkitAgent(runtime)))!;
      await tester.runAsync(agent.resumeLocalState);
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder, {bool expectInputError = false}) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
        await tester.pump();
        expect(finder.hitTestable(), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        for (var i = 0; i < 100 && agent.isBusy; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(agent.isBusy, false);
        await tester.pumpAndSettle();
        expect(agent.connectionError, isNull);
        expect(agent.inputError, expectInputError ? isNotNull : isNull);
      }

      await tap(find.text('Save look').last);
      expect((await store.read())!['looks'], hasLength(1));
      await tap(find.text('Add look to demo bag · €230.00').last);
      expect(find.byType(FinalizedBagPreview), findsOneWidget);
      expect(find.text('Check out'), findsOneWidget);
      expect(runtime.bagCount, 1);
      final plus = find.descendant(
        of: find.byType(FinalizedBagPreview).last,
        matching: find.text('+'),
      );
      store.beforeWrite = () async => throw StateError('Storage unavailable');
      await tap(plus, expectInputError: true);
      expect(runtime.bagCount, 1);
      expect(
        find.descendant(
          of: find.byType(FinalizedBagPreview),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      store.beforeWrite = null;
      await tap(plus);
      expect(runtime.bagCount, 2);
      expect(find.text('€460'), findsWidgets);
      await tap(find.byTooltip('Remove Black Draped Wrap Dress').last);
      expect(runtime.bagCount, 0);
      await tap(find.text('Undo').last);
      expect(runtime.bagCount, 2);
      await tap(find.byTooltip('Close bag').last);
      await tap(find.text('Start over').last);
      expect(runtime.outfit['items'], isEmpty);
      await tester.runAsync(agent.openSavedLooks);
      await tester.pumpAndSettle();
      final rail = find
          .byWidgetPredicate(
            (w) =>
                w is FinalizedRightComponent && w.component == 'SavedLooksRail',
          )
          .last;
      await tap(find.descendant(of: rail, matching: find.text('Your look')));
      expect(runtime.outfit['items'], {'dress': 'demo-0092'});
      expect(runtime.bagCount, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'filled-slot Change, QuickAdjust and a single replacement swap use host actions',
    (tester) async {
      tester.view.physicalSize = const Size(1240, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final agent = (await tester.runAsync(
        () async => GenkitAgent(
          StylistRuntime(products: [actual('demo-0092'), actual('demo-0198')]),
        ),
      ))!;
      await tester.pumpWidget(ReferenceApp(agent: agent));
      await tester.runAsync(
        () => agent.startBrief(
          "Women's dress under €500; I already own shoes; I already own a bag",
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => agent.conversation.sendRequest(
          action('select_product', {
            'productId': 'demo-0092',
          }, surfaceId: agent.latestInlineSurfaceId),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
        await tester.pump();
        expect(finder.hitTestable(), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        for (var i = 0; i < 100 && agent.isBusy; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(agent.isBusy, false);
        await tester.pumpAndSettle();
        expect(agent.connectionError, isNull);
        expect(agent.inputError, isNull);
      }

      final selectedSlot = find
          .byWidgetPredicate(
            (widget) =>
                widget is FinalizedPieceSlot &&
                widget.name == 'Black Draped Wrap Dress' &&
                widget.onChange != null,
          )
          .first;
      expect(selectedSlot, findsOneWidget);
      await tap(
        find.descendant(of: selectedSlot, matching: find.byType(InkWell)).first,
      );
      expect(find.byType(FinalizedQuickAdjust), findsOneWidget);
      await tap(
        find.descendant(
          of: find.byType(FinalizedQuickAdjust).last,
          matching: find.text('Cheaper'),
        ),
      );
      expect(
        tester
            .widget<FinalizedQuickAdjust>(
              find.byType(FinalizedQuickAdjust).last,
            )
            .selected,
        'Cheaper',
      );
      await tap(find.text('Swap').last);
      expect(
        find.textContaining('Selected Black Sheer-Panel Maxi Dress'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
