import 'dart:convert';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/outfit_plan.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_constraints.dart';
import 'package:a2ui_flutter_commerce/data/stylist/model/stylist_input_error.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/data/stylist/repository/local_stylist_store.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'stylist_store_helpers.dart';
import 'stylist_wire_helpers.dart';

Product piece(String id, ProductCategory category, double price) => Product(
  id: id,
  category: category,
  name: id,
  brand: 'Demo',
  price: price,
  meta: '',
  tag: '',
  swatch: '#000000',
);
final decimalCatalog = [
  piece('Shirt', ProductCategory.top, 1.10),
  piece('Trousers', ProductCategory.bottom, 2.20),
];
const brief =
    'Casual outfit under €3.30; I already own shoes; I already own a bag';
Map<String, dynamic> event(
  String name, [
  Map<String, Object?> context = const {},
]) => {
  'action': {'name': name, 'context': context},
};
Map inlineData(Map result) =>
    (presentedStylistTurn(result)['messages'] as List).lastWhere(
          (message) =>
              message['updateDataModel']?['surfaceId'].startsWith('inline-') ==
              true,
        )['updateDataModel']['value']
        as Map;
Future<Map<String, dynamic>> selectExactLook(StylistRuntime runtime) async {
  final opening = await runtime.turn({'message': brief});
  expect((opening['products'] as List).single['id'], 'Shirt');
  final next = await runtime.turn(
    event('select_product', {'productId': 'Shirt'}),
  );
  expect((next['products'] as List).single['id'], 'Trousers');
  return runtime.turn(event('select_product', {'productId': 'Trousers'}));
}

final class ReadFailurePlatform extends SharedPreferencesAsyncPlatform {
  final values = <String, String>{};
  bool fail = true;
  int reads = 0;
  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    reads++;
    if (fail) throw StateError('Storage temporarily unavailable');
    return values[key];
  }

  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'EUR boundaries preserve pennies, compare caps, and reject nonfinite money',
    () {
      expect(sumEuros([1.10, 2.20]), 3.30);
      expect(subtractEuros(3.30, 1.10), 2.20);
      expect(formatEuros(sumEuros([1.10, 2.20])), '€3.30');
      expect(euroAmountExceeds(3.30, 3.30), false);
      expect(euroAmountExceeds(3.31, 3.30), true);
      expect(euroAmountExceeds(3.31, double.infinity), false);
      expect(() => euroCents(double.nan), throwsFormatException);
      expect(() => euroCents(double.infinity), throwsFormatException);
      expect(decimalCatalog.first.priceLabel, '€1.10');
    },
  );

  test('completion, search, selection, save and restore agree on an exact decimal budget', () async {
    final assessment = assessOutfitSelection(
      candidate: decimalCatalog.first,
      outfit: {},
      catalog: decimalCatalog,
      brief: 'casual',
      dressCode: 'casual',
      constraints: const StylistConstraints(
        ownedCategories: {ProductCategory.shoes, ProductCategory.bag},
      ),
      budget: 3.30,
    );
    expect(assessment.minimumTotal, 3.30);
    expect(assessment.feasible, true);
    final store = MemoryStylistStore();
    final runtime = StylistRuntime(products: decimalCatalog, store: store);
    addTearDown(runtime.dispose);
    final complete = await selectExactLook(runtime);
    expect(inlineData(complete)['look']['meta'], contains('€3.30'));
    await runtime.turn(event('save_look'));
    await runtime.turn(event('add_look_to_bag'));
    final bag = await runtime.turn(event('open_bag'));
    expect(
      (inlineData(bag)['bagItems'] as List).map((item) => item['unitPrice']),
      [1.10, 2.20],
    );
    final restarted = StylistRuntime(products: decimalCatalog, store: store);
    addTearDown(restarted.dispose);
    expect(await restarted.loadLocalState(), true);
    expect(restarted.outfit['items'], {'top': 'Shirt', 'bottom': 'Trousers'});
    final restored = await restarted.turn(
      event('restore_look', {'lookId': 'look-1'}),
    );
    expect(inlineData(restored)['look']['meta'], contains('€3.30'));
    expect(restored['reply'], isNot(contains('above')));
    await expectLater(
      restarted.turn(event('update_budget', {'budget': 3.29})),
      throwsA(isA<StylistInputError>()),
    );
    expect(restarted.outfit['budget'], 3.30);
  });

  for (final invalid in <String, String>{
    'malformed JSON': '{',
    'non-object JSON': '[]',
    'unsupported version': '{"version":2,"library":"keep this original"}',
    'invalid shape': '{"version":1,"looks":[],"bag":[],"nextLookId":1}',
    'oversized value': 'x' * 262145,
  }.entries) {
    test(
      '${invalid.key} preserves raw storage and allows session styling and saving',
      () async {
        final previous = SharedPreferencesAsyncPlatform.instance;
        final platform = MemoryPreferencePlatform();
        SharedPreferencesAsyncPlatform.instance = platform;
        addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
        platform.values[LocalStylistStore.storageKey] = invalid.value;
        final runtime = StylistRuntime(
          products: decimalCatalog,
          store: LocalStylistStore(),
        );
        addTearDown(runtime.dispose);
        expect(await runtime.loadLocalState(), false);
        expect(runtime.localStorageNotice, contains('left unchanged'));
        await selectExactLook(runtime);
        final saved = await runtime.turn(event('save_look'));
        expect(saved['reply'], contains('Look kept for this session.'));
        expect(
          saved['reply'],
          contains('new looks will not be saved on this device'),
        );
        expect(inlineData(saved)['savedLooks'], hasLength(1));
        expect(platform.values[LocalStylistStore.storageKey], invalid.value);
        final reset = await runtime.turn(event('reset_look'));
        expect(reset['reply'], contains('left unchanged'));
        expect(platform.values[LocalStylistStore.storageKey], invalid.value);
      },
    );
  }

  test('unreadable storage permits connection, retries on reconnect, and preserves the original library', () async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    final platform = ReadFailurePlatform()..fail = false;
    SharedPreferencesAsyncPlatform.instance = platform;
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    final seed = StylistRuntime(
      products: decimalCatalog,
      store: LocalStylistStore(),
    );
    await selectExactLook(seed);
    await seed.turn(event('save_look'));
    await seed.dispose();
    final original = platform.values[LocalStylistStore.storageKey];
    expect(jsonDecode(original!)['looks'], hasLength(1));
    platform.fail = true;
    final reads = platform.reads;
    final runtime = StylistRuntime(
      products: decimalCatalog,
      store: LocalStylistStore(),
    );
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    await agent.resumeLocalState();
    expect(agent.hasStarted, true);
    expect(agent.conversationEntries, isNotEmpty);
    expect(runtime.localStorageNotice, isNotNull);
    await selectExactLook(runtime);
    await runtime.turn(event('save_look'));
    expect(platform.reads, reads + 1);
    expect(platform.values[LocalStylistStore.storageKey], original);
    await agent.disconnect();
    platform.fail = false;
    final reconnected = StylistRuntime(
      products: decimalCatalog,
      store: LocalStylistStore(),
    );
    addTearDown(reconnected.dispose);
    expect(await reconnected.loadLocalState(), true);
    final restored = await reconnected.turn(event('open_saved_looks'));
    expect(inlineData(restored)['savedLooks'], hasLength(1));
    expect(reconnected.outfit['items'], {'top': 'Shirt', 'bottom': 'Trousers'});
  });

  testWidgets('bag line quantities and subtotal preserve decimal EUR amounts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FinalizedBagPreview(
              data: {
                'mode': 'demo-host',
                'items': [
                  {
                    'id': 'Shirt',
                    'name': 'Shirt',
                    'category': 'top',
                    'unitPrice': 1.10,
                    'quantity': 3,
                  },
                  {
                    'id': 'Trousers',
                    'name': 'Trousers',
                    'category': 'bottom',
                    'unitPrice': 2.20,
                    'quantity': 1,
                  },
                ],
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('€3.30'), findsOneWidget);
    expect(find.text('€2.20'), findsOneWidget);
    expect(find.text('€5.50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
