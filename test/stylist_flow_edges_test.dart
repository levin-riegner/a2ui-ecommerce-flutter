import 'dart:async';
import 'dart:convert';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/commerce_components.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_shared_components.dart';

import 'progressive_agent_test.dart' show action;
import 'stylist_product_options_test.dart' show settleTurn;

import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';

import 'stylist_component_adoption_test.dart' show components;
import 'stylist_library_test.dart' show completed, data, event, libraryCatalog;
import 'stylist_product_options_test.dart' show blue, black, brief;
import 'stylist_runtime_test.dart' show products;
import 'stylist_store_helpers.dart';

const shoes = Product(
  id: 'sandals',
  category: ProductCategory.shoes,
  name: 'Blue sandals',
  brand: 'Alder',
  price: 40,
  meta: 'Blue',
  tag: 'Summer',
  swatch: '#3344ff',
  color: 'blue',
  gender: 'female',
  sizeOptions: ['40', '41'],
);

ChatMessage nativeAction(
  GenkitAgent agent,
  String surfaceId,
  String componentId, {
  Map<String, Object?> extra = const {},
}) {
  final component = agent.controller
      .contextFor(surfaceId)
      .definition
      .value!
      .components[componentId]!
      .toJson();
  final authored = (component['action'] ?? component['changeAction']) as Map;
  final event = authored['event'] as Map;
  return ChatMessage.user(
    '',
    parts: [
      UiInteractionPart.create(
        jsonEncode({
          'action': {
            'name': event['name'],
            'context': {...event['context'] as Map, ...extra},
            'surfaceId': surfaceId,
            'sourceComponentId': componentId,
          },
        }),
      ),
    ],
  );
}

class BusyRestartAgent extends GenkitAgent {
  BusyRestartAgent(super.runtime);
  bool holdBusy = false;
  @override
  bool get isBusy => holdBusy || super.isBusy;
  @override
  Future<bool> restartChat() {
    holdBusy = false;
    return super.restartChat();
  }
}

void main() {
  test('restart phrases are explicit and support a new brief without negation mistakes', () {
    for (final phrase in [
      'restart',
      'Please start over',
      'Can we restart the chat?',
      'start a new look',
    ]) {
      expect(restartStylistBrief(phrase), '', reason: phrase);
    }
    expect(
      restartStylistBrief('Restart with a dress under €300'),
      'a dress under €300',
    );
    for (final phrase in [
      "Don't restart",
      'I changed my mind',
      'Can we change the shoes?',
      'I said "start over"',
    ]) {
      expect(restartStylistBrief(phrase), isNull, reason: phrase);
    }
  });

  test(
    'vague change of mind offers inline choices and preserves look and library',
    () async {
      final store = MemoryStylistStore();
      final runtime = await completed(store: store);
      addTearDown(runtime.dispose);
      await runtime.turn(event('save_look'));
      await runtime.turn(event('add_look_to_bag'));
      final before = runtime.outfit;
      final result = await runtime.turn({'message': 'I changed my mind'});
      expect(result['intent'], 'change_direction');
      expect(runtime.outfit, before);
      expect(
        components(result)
            .where((c) => c['component'] == 'ChoiceChip')
            .map((c) => c['label']),
        contains('Start a new look'),
      );
      expect(
        components(result).where((c) => c['component'] == 'ProductCard'),
        isEmpty,
      );
      final restarted = await runtime.turn({'message': 'restart'});
      expect(restarted['outfit']['items'], isEmpty);
      expect(runtime.bagCount, 1);
      expect((await store.read())!['looks'], hasLength(1));
    },
  );

  test('size step names selected dress and defers shoes; shoes never require clothing fit', () async {
    final runtime = StylistRuntime(products: [blue, black, shoes]);
    addTearDown(runtime.dispose);
    await runtime.turn({
      'message': "Women's dress for summer under €500; I already own a bag",
    });
    final dress = await runtime.turn(
      event('select_product', {'productId': blue.id}),
    );
    expect(dress['reply'], contains(blue.name));
    expect(data(dress)['selectionOptions']['fits'], contains('Regular'));
    expect(
      components(dress).where((c) => c['component'] == 'ProductCard'),
      isEmpty,
    );
    await runtime.turn(
      event('set_fit_size', {
        'productId': blue.id,
        'size': 'M',
        'fit': 'Relaxed',
      }),
    );
    final details = await runtime.turn(
      event('open_product_details', {'productId': shoes.id}),
    );
    expect(data(details)['productDetails']['fits'], isEmpty);
    expect(data(details)['productDetails']['question'], contains(shoes.name));
    expect(data(details)['productDetails']['saveLabel'], 'Save size');
    await runtime.turn(
      event('set_fit_size', {'productId': shoes.id, 'size': '41'}),
    );
    final clothing = await runtime.turn(
      event('open_product_details', {'productId': blue.id}),
    );
    expect(data(clothing)['productDetails']['fit'], 'Relaxed');
    expect(data(clothing)['productDetails']['size'], 'M');
  });

  test('asking about shoes does not open the selected dress sizing', () async {
    final runtime = StylistRuntime(products: [blue, shoes]);
    addTearDown(runtime.dispose);
    await runtime.turn({
      'message': "Women's dress for summer under €500; I already own a bag",
    });
    await runtime.turn(event('select_product', {'productId': blue.id}));
    final result = await runtime.turn({'message': 'What sizes are the shoes?'});
    expect(data(result)['productDetails']['id'], shoes.id);
    expect(data(result)['productDetails']['fits'], isEmpty);
  });

  test(
    'restart releases a noncooperative model and ignores its late failure',
    () async {
      final entered = Completer<void>(), release = Completer<g.ModelResponse>();
      final runtime = StylistRuntime(
        products: products,
        providerModel: g.Model(
          name: 'test/noncooperative',
          fn: (request, context) async {
            if (request.tools?.isEmpty == true) {
              entered.complete();
              return release.future;
            }
            return offlineStylistModel(request);
          },
        ),
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      final pending = agent.startBrief('A summer dress under €500');
      await entered.future;
      expect(
        await agent.restartChat().timeout(const Duration(seconds: 3)),
        isTrue,
      );
      await pending;
      expect(agent.isBusy, isFalse);
      expect(agent.hasStarted, isFalse);
      expect(agent.latestInlineSurfaceId, isNull);
      expect(runtime.outfit['items'], isEmpty);
      release.completeError(StateError('Late provider failure'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(agent.connectionError, isNull);
      expect(agent.latestInlineSurfaceId, isNull);
    },
  );

  test(
    'reused surface IDs reject old native actions after a successful restart',
    () async {
      final agent = GenkitAgent(StylistRuntime(products: [blue, black]));
      addTearDown(agent.dispose);
      await agent.startBrief(brief);
      final stale = nativeAction(agent, 'inline-1', 'details-blue');
      await agent.restartChat();
      await agent.startBrief(brief);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      await agent.conversation.sendRequest(stale);
      expect(agent.latestInlineSurfaceId, 'inline-1');
      await agent.conversation.sendRequest(
        nativeAction(agent, 'inline-1', 'details-blue'),
      );
      expect(agent.latestInlineSurfaceId, 'inline-2');
      expect(agent.connectionError, isNull);
    },
  );

  test('failed restart keeps persisted look and previously authored controls usable', () async {
    final store = MemoryStylistStore();
    final seed = await completed(store: store);
    await seed.dispose();
    final runtime = StylistRuntime(products: libraryCatalog, store: store);
    final agent = GenkitAgent(runtime);
    addTearDown(agent.dispose);
    await agent.resumeLocalState();
    final id = agent.latestInlineSurfaceId!;
    final original = nativeAction(agent, id, 'details-demo-0092');
    final before = store.encoded;
    store.beforeWrite = () async {
      store.beforeWrite = null;
      throw StateError('Disk unavailable');
    };
    expect(await agent.restartChat(), isFalse);
    expect(store.encoded, before);
    expect(runtime.outfit['items'], {'dress': 'demo-0092'});
    expect(agent.inputError, isNotNull);
    await agent.conversation.sendRequest(original);
    expect(agent.latestInlineSurfaceId, isNot(id));
    expect(agent.inputError, isNull);
    expect(agent.connectionError, isNull);
  });

  testWidgets('actual shoe controls enable Save size without a clothing fit', (
    tester,
  ) async {
    final runtime = (await tester.runAsync(
      () async => StylistRuntime(products: [blue, shoes]),
    ))!;
    final agent = (await tester.runAsync(() async => GenkitAgent(runtime)))!;
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.runAsync(
      () => agent.startBrief(
        "Women's dress for summer under €500; I already own a bag",
      ),
    );
    await tester.runAsync(
      () => agent.conversation.sendRequest(
        action('select_product', {'productId': blue.id}),
      ),
    );
    await tester.runAsync(
      () => agent.conversation.sendRequest(
        action('set_product_options', {
          'productId': blue.id,
          'colourProductId': blue.id,
          'size': 'M',
          'fit': 'Regular',
        }),
      ),
    );
    await tester.runAsync(
      () => agent.conversation.sendRequest(
        action('select_product', {'productId': shoes.id}),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<FinalizedFitSize>(
      find.byType(FinalizedFitSize).last,
    );
    expect(editor.fits, isEmpty);
    expect(editor.question, isEmpty);
    expect(find.textContaining('Choose your size below.'), findsOneWidget);
    final button = find.byWidgetPredicate(
      (w) => w is FinalizedPrimaryButton && w.label == 'Save size',
    );
    expect(tester.widget<FinalizedPrimaryButton>(button).onPressed, isNull);
    final size = find
        .byWidgetPredicate((w) => w is CommerceChoice && w.label == '41')
        .last;
    await tester.ensureVisible(size);
    await tester.tap(size);
    await tester.pumpAndSettle();
    expect(tester.widget<FinalizedPrimaryButton>(button).onPressed, isNotNull);
    await tester.ensureVisible(button);
    await tester.runAsync(() async {
      await tester.tap(button);
    });
    await settleTurn(tester, agent);
    expect(agent.inputError, isNull);
    expect(agent.connectionError, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('restart control remains enabled while the agent is busy', (
    tester,
  ) async {
    final agent = (await tester.runAsync(
      () async => BusyRestartAgent(StylistRuntime(products: products)),
    ))!;
    await tester.runAsync(() => agent.startBrief('A summer dress under €500'));
    agent.holdBusy = true;
    await tester.pumpWidget(ReferenceApp(agent: agent));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(agent.isBusy, isTrue);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.byTooltip('New journey').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Back to start'));
    await settleTurn(tester, agent);
    expect(find.text('Where are you going?'), findsOneWidget);
    expect(agent.hasStarted, isFalse);
    expect(agent.connectionError, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'restart with replacement brief drops the previous constraints',
    () async {
      final runtime = StylistRuntime(products: libraryCatalog);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': brief});
      final result = await runtime.turn({
        'message': "Restart with a men's business outfit under €250",
      });
      expect(result['outfit']['items'], isEmpty);
      expect(result['brief']['gender'], 'male');
      expect(result['brief']['budget'], 250);
      expect(
        result['constraints']['ownedCategories'],
        isNot(contains('shoes')),
      );
    },
  );
}
