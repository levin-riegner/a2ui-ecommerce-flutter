import 'dart:async';

import 'package:a2ui_flutter_commerce/src/agent/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/app.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_components.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:a2ui_flutter_commerce/src/layout/adaptive_pane_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';

import 'city_context_test.dart' show FixtureContext, inlineData;
import 'progressive_agent_test.dart' show action;
import 'stylist_library_test.dart' show event;
import 'stylist_product_options_test.dart' show blue, black, brief;
import 'stylist_runtime_test.dart' show products;
import 'stylist_store_helpers.dart';
import 'stylist_wire_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'optional search notices appear with choices, not size selection',
    () async {
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          final response = await offlineStylistModel(request);
          for (final part in response.message!.content) {
            if (part.isToolRequest &&
                part.toolRequest!.name == 'search_products') {
              return g.ModelResponse(
                finishReason: g.FinishReason.stop,
                message: g.Message(
                  role: g.Role.model,
                  content: [
                    g.ToolRequestPart(
                      toolRequest: g.ToolRequest(
                        name: 'search_products',
                        ref: part.toolRequest!.ref,
                        input: {
                          ...part.toolRequest!.input as Map,
                          'color': 'purple',
                        },
                      ),
                    ),
                  ],
                ),
              );
            }
          }
          return response;
        },
      );
      addTearDown(runtime.dispose);
      final opening = await runtime.turn({
        'message': 'Smart casual work under €900',
      });
      expect(opening['reply'], contains('optional search filters'));
      final first =
          (inlineData(opening)['recommendations'] as List).first as Map;
      final selected = await runtime.turn(
        event('select_product', {'productId': first['id']}),
      );
      expect(inlineData(selected)['selectionOptions'], isNotNull);
      expect(selected['reply'], isNot(contains('optional search filters')));
    },
  );

  test(
    'item and size choices retain weather without fetching or repeating it',
    () async {
      final source = FixtureContext();
      final runtime = StylistRuntime(
        products: products,
        cityContextSource: source,
      );
      addTearDown(runtime.dispose);
      final opening = await runtime.turn({
        'message': 'Smart casual work in Berlin under €900',
      });
      expect(inlineData(opening)['weather'], isNotNull);
      final first =
          (inlineData(opening)['recommendations'] as List).first as Map;
      final selected = await runtime.turn(
        event('select_product', {'productId': first['id']}),
      );
      expect(source.calls, hasLength(1));
      expect(selected['reply'], isNot(contains('optional search filters')));
      expect(inlineData(selected)['weather'], isNull);
      expect(
        presentedStylistTurn(selected)['messages'].toString(),
        isNot(contains('city-context')),
      );
      final options = inlineData(selected)['selectionOptions'] as Map;
      final choice = (options['choices'] as List).first as Map;
      final saved = await runtime.turn(
        event('set_product_options', {
          'productId': first['id'],
          'colourProductId': first['id'],
          'size': (choice['sizes'] as List).first,
          'fit': 'Regular',
        }),
      );
      expect(source.calls, hasLength(1));
      expect(inlineData(saved)['weather'], isNull);
      final weather = await runtime.turn({'message': 'What is the weather?'});
      expect(inlineData(weather)['weather'], isNotNull);
      expect(source.calls, hasLength(2));
    },
  );

  test(
    'each saved selection introduces the actual next category once',
    () async {
      final runtime = StylistRuntime(products: products);
      addTearDown(runtime.dispose);
      await runtime.turn({
        'message': 'A summer dress for lunch, smart casual under €500',
      });
      for (final (id, next) in [('dress-1', 'shoes'), ('shoes-1', 'a bag')]) {
        final selected = await runtime.turn(
          event('select_product', {'productId': id}),
        );
        final product = products.singleWhere((p) => p.id == id);
        final reply = selected['reply'] as String;
        expect(product.name.allMatches(reply), hasLength(1));
        expect(reply, isNot(contains('\n\nChoose your')));
        expect(reply, isNot(contains('Next, choose')));
        final options = inlineData(selected)['selectionOptions'] as Map;
        final choice = (options['choices'] as List).first as Map;
        final saved = await runtime.turn(
          event('set_product_options', {
            'productId': id,
            'size': (choice['sizes'] as List).first,
            'fit': 'Regular',
          }),
        );
        expect(saved['reply'], startsWith('Saved size '));
        expect(
          saved['reply'],
          contains('Next, choose $next to continue the look.'),
        );
        expect(saved['reply'], isNot(contains(product.name)));
        expect(saved['reply'], isNot(contains('\n\n')));
        expect(inlineData(saved)['recommendations'], isNotEmpty);
      }
      final bag = await runtime.turn(
        event('select_product', {'productId': 'bag-1'}),
      );
      expect(bag['reply'], contains('Your look is complete.'));
    },
  );

  test(
    'colour changes use one concise sizing message and completion follows save',
    () async {
      final runtime = StylistRuntime(products: [blue, black]);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': brief});
      final selected = await runtime.turn(
        event('select_product', {'productId': blue.id}),
      );
      expect(selected['reply'], isNot(contains('Your look is complete')));
      final colour = await runtime.turn(
        event('choose_product_colour', {
          'productId': blue.id,
          'colour': 'Black',
        }),
      );
      expect(
        colour['reply'],
        'Selected Black dress. €410.00 left in your budget. Choose your size and preferred fit below.',
      );
      final saved = await runtime.turn(
        event('set_product_options', {
          'productId': black.id,
          'size': 'L',
          'fit': 'Regular',
        }),
      );
      expect(
        saved['reply'],
        'Saved size L and regular fit. Your look is complete. Keep it, or tell me which piece you want to swap.',
      );
    },
  );

  for (final fail in [false, true]) {
    test('dressing room updates before the model finishes; failure=$fail', () async {
      const top = Product(
        id: 'one-size-top',
        category: ProductCategory.top,
        name: 'Cotton shirt',
        brand: 'Sample',
        price: 50,
        meta: '',
        tag: '',
        swatch: '#000000',
        sizeOptions: ['One size'],
      );
      final entered = Completer<void>();
      final finish = Completer<void>();
      var blocked = false;
      final runtime = StylistRuntime(
        products: [
          top,
          const Product(
            id: 'other-top',
            category: ProductCategory.top,
            name: 'Other shirt',
            brand: 'Sample',
            price: 55,
            meta: '',
            tag: '',
            swatch: '#ffffff',
            sizeOptions: ['One size'],
          ),
        ],
        model: (request) async {
          if (blocked) {
            if (!entered.isCompleted) entered.complete();
            await finish.future;
            if (fail) throw StateError('test failure');
          }
          return offlineStylistModel(request);
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startBrief(
        'Smart casual work under €500; I already own trousers, shoes and a bag',
      );
      final choices = agent.controller
          .contextFor(agent.latestInlineSurfaceId!)
          .dataModel;
      final previous = choices.getValue<Object?>(DataPath.root).toString();
      blocked = true;
      final turn = agent.conversation.sendRequest(
        action('select_product', {'productId': top.id}),
      );
      await entered.future;
      expect(choices.getValue<String>(DataPath('/selectedProductId')), top.id);
      final rows = choices
          .getValue<List<Object?>>(DataPath('/recommendations'))!
          .cast<Map>();
      expect(rows.singleWhere((r) => r['id'] == top.id)['selected'], true);
      expect(rows.singleWhere((r) => r['id'] != top.id)['dimmed'], true);
      final room = agent.controller.contextFor('dressing-room').dataModel;
      expect(
        (room.getValue<List<Object?>>(DataPath('/slots'))!.first
            as Map)['name'],
        top.name,
      );
      expect(
        runtime.outfit['items'],
        isEmpty,
        reason: 'The preview is not a committed turn.',
      );
      finish.complete();
      await turn;
      final slots = room
          .getValue<List<Object?>>(DataPath('/slots'))!
          .cast<Map>();
      expect(slots.any((s) => s['name'] == top.name), !fail);
      expect((runtime.outfit['items'] as Map).containsValue(top.id), !fail);
      if (fail) {
        expect(choices.getValue<Object?>(DataPath.root).toString(), previous);
      } else {
        expect(
          choices.getValue<String>(DataPath('/selectedProductId')),
          top.id,
        );
      }
    });
  }

  for (final compact in [false, true]) {
    testWidgets('an explicit selection resumes scrolling, compact=$compact', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(compact ? 390 : 1200, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Widget layout(Object? trigger) => MaterialApp(
        home: Scaffold(
          body: AdaptivePaneLayout(
            followPrimaryEnd: true,
            holdInitialPrimaryBeginning: true,
            primaryFollowTrigger: trigger,
            primary: const SizedBox(height: 2500),
            secondary: const Text('Room'),
            header: const Text('Header'),
            footer: const Text('Composer'),
          ),
        ),
      );
      await tester.pumpWidget(layout(null));
      await tester.pumpAndSettle();
      final viewport = find.byKey(
        ValueKey(compact ? 'compact-pane-scroll' : 'primary-pane-scroll'),
      );
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(of: viewport, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      expect(scroll.pixels, 0);
      await tester.drag(viewport, const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(scroll.extentAfter, greaterThan(48));
      await tester.pumpWidget(layout('selected-item'));
      await tester.pumpAndSettle();
      expect(scroll.extentAfter, closeTo(0, 1));
    });
  }

  for (final fail in [false, true]) {
    testWidgets(
      'Save size collapses immediately and reopens on failure=$fail',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1000);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryStylistStore();
        final runtime = (await tester.runAsync(
          () async => StylistRuntime(products: [blue], store: store),
        ))!;
        final agent = GenkitAgent(runtime);
        await tester.pumpWidget(ReferenceApp(agent: agent));
        await tester.runAsync(() => agent.startBrief(brief));
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => agent.conversation.sendRequest(
            action('select_product', {'productId': blue.id}),
          ),
        );
        await tester.pumpAndSettle();
        final size = find
            .byWidgetPredicate((w) => w is CommerceChoice && w.label == 'M')
            .last;
        await tester.ensureVisible(size);
        await tester.tap(size);
        await tester.pumpAndSettle();
        final fit = find
            .byWidgetPredicate(
              (w) => w is CommerceChoice && w.label == 'Regular',
            )
            .last;
        await tester.ensureVisible(fit);
        await tester.tap(fit);
        await tester.pumpAndSettle();
        final form = find.byKey(
          const ValueKey('collapsible-selection-options'),
        );
        final height = tester.getSize(form).height;
        final gate = Completer<void>();
        store.beforeWrite = () async {
          await gate.future;
          if (fail) throw StateError('test storage failure');
        };
        final save = find.text('Save size & fit').last;
        await tester.ensureVisible(save);
        await tester.runAsync(() async {
          await tester.tap(save);
        });
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(tester.getSize(form).height, lessThan(height));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getSize(form).height, 0);
        await tester.runAsync(() async {
          gate.complete();
        });
        for (var i = 0; i < 100 && agent.isBusy; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(agent.isBusy, isFalse);
        await tester.pumpAndSettle();
        expect(tester.getSize(form).height, fail ? height : 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
