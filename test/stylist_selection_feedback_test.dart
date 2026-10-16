import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/app/app.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/commerce_components.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/design_system/views/commerce/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/presentation/stylist/a2ui/catalog/model_catalog.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:a2ui_flutter_commerce/presentation/shared/layout/adaptive_pane_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

const _dresses = [
  Product(
    id: 'green-dress',
    category: ProductCategory.dress,
    name: 'Green summer dress',
    brand: 'Alder Studio',
    price: 90,
    meta: 'Green · Linen',
    tag: 'Summer',
    swatch: '#405d42',
    imageAsset: 'assets/images/products/demo-0242.jpg',
    sizeOptions: ['S', 'M', 'L'],
  ),
  Product(
    id: 'slate-dress',
    category: ProductCategory.dress,
    name: 'Slate Sleeveless Midi Dress',
    brand: 'Alder Studio',
    price: 75,
    meta: 'Slate blue · Linen',
    tag: 'Summer',
    swatch: '#718b98',
    imageAsset: 'assets/images/products/demo-0241.jpg',
    sizeOptions: ['S', 'M', 'L'],
  ),
  Product(
    id: 'black-dress',
    category: ProductCategory.dress,
    name: 'Black summer dress',
    brand: 'Alder Studio',
    price: 120,
    meta: 'Black · Linen',
    tag: 'Summer',
    swatch: '#111111',
    imageAsset: 'assets/images/products/demo-0243.jpg',
    sizeOptions: ['S', 'M', 'L'],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final component in ['ProductCard', 'PicksStrip', 'ThisOrThat']) {
    for (final width in [390.0, 1200.0]) {
      testWidgets(
        'selecting a dress from $component keeps only its real card inline at $width',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final agent = (await tester.runAsync(
            () async => GenkitAgent(
              StylistRuntime(
                products: _dresses,
                uiCatalog: buildModelUiCatalog(buildCommerceCatalog()),
                model: (request) async {
                  final response = await offlineStylistModel(request);
                  for (final part in response.message!.content) {
                    if (part.toolRequest?.name == 'search_products') {
                      final tool = part.toolRequest!;
                      tool.input = {...tool.input as Map, 'limit': 3};
                    }
                    if (part.toolRequest?.name == 'present_products') {
                      final tool = part.toolRequest!;
                      tool.input = {
                        ...tool.input as Map,
                        'component': component,
                        if (component != 'ThisOrThat')
                          'productIds': _dresses.map((p) => p.id).toList(),
                      };
                    }
                  }
                  return response;
                },
              ),
            ),
          ))!;
          final capture =
              Platform.environment['ALDER_CAPTURE_SELECTION'] == '1';
          if (capture) {
            await tester.runAsync(() async {
              for (final (family, asset) in [
                ('Inter', 'assets/fonts/inter/Inter-Variable.ttf'),
                ('Jost', 'assets/fonts/jost/Jost-Variable.ttf'),
              ]) {
                await (FontLoader(
                  family,
                )..addFont(rootBundle.load(asset))).load();
              }
            });
          }
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: ReferenceApp(agent: agent),
            ),
          );
          await tester.runAsync(() => agent.startBrief(brief));
          await tester.pumpAndSettle();
          final cards = find.byType(FinalizedProductCard);
          final Finder chosen;
          if (component == 'ProductCard') {
            expect(cards, findsNWidgets(3));
            chosen = find.byWidgetPredicate(
              (w) => w is FinalizedProductCard && w.name == _dresses[1].name,
            );
          } else {
            final choices = component == 'PicksStrip'
                ? find.byType(FinalizedPicksStrip)
                : find.byType(FinalizedThisOrThat);
            expect(choices, findsOneWidget);
            final rows = component == 'PicksStrip'
                ? tester.widget<FinalizedPicksStrip>(choices).products
                : tester.widget<FinalizedThisOrThat>(choices).options;
            final index = rows.indexWhere(
              (row) => row['productId'] == _dresses[1].id,
            );
            expect(index, greaterThanOrEqualTo(0));
            chosen = find
                .descendant(of: choices, matching: find.byType(InkWell))
                .at(index);
          }
          await tester.ensureVisible(chosen);
          await tester.tap(chosen);
          await tester.pump();
          for (var i = 0; i < 100 && agent.isBusy; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          expect(agent.connectionError, isNull);
          expect(cards, findsOneWidget);
          final card = tester.widget<FinalizedProductCard>(cards);
          expect(card.name, _dresses[1].name);
          expect(card.price, '€75');
          expect(card.brandLine, _dresses[1].brandLine);
          expect(card.imageAsset, _dresses[1].imageAsset);
          expect(card.selected, isTrue);
          expect(find.text('In your dressing room'), findsOneWidget);
          expect(find.text('Add to dressing room'), findsNothing);
          expect(find.text('Save size & fit'), findsOneWidget);
          expect(find.byType(FinalizedPicksStrip), findsNothing);
          expect(find.byType(FinalizedThisOrThat), findsNothing);
          expect(tester.takeException(), isNull);
          if (capture) {
            await tester.ensureVisible(cards);
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              await precacheImage(
                AssetImage(_dresses[1].imageAsset),
                boundaryKey.currentContext!,
              );
            });
            await tester.pumpAndSettle();
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File('/tmp/alder-selected-$component-${width.toInt()}.png')
                  .writeAsBytes(
                    bytes.buffer.asUint8List(
                      bytes.offsetInBytes,
                      bytes.lengthInBytes,
                    ),
                  );
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  test(
    'an accepted replacement collapses AlternativePiece to the chosen card',
    () async {
      var replacing = false;
      final runtime = StylistRuntime(
        products: _dresses.take(2).toList(),
        uiCatalog: buildModelUiCatalog(buildCommerceCatalog()),
        model: (request) async {
          final response = await offlineStylistModel(request);
          if (replacing) {
            for (final part in response.message!.content) {
              if (part.toolRequest?.name == 'present_products') {
                final tool = part.toolRequest!;
                tool.input = {
                  ...tool.input as Map,
                  'component': 'AlternativePiece',
                };
              }
            }
          }
          return response;
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startBrief(brief);
      await agent.conversation.sendRequest(
        action('select_product', {'productId': _dresses.first.id}),
      );
      await agent.conversation.sendRequest(
        action('set_product_options', {
          'productId': _dresses.first.id,
          'size': 'M',
          'fit': 'Regular',
        }),
      );
      replacing = true;
      await agent.conversation.sendRequest(
        action('adjust_piece', {
          'category': 'dress',
          'productId': _dresses.first.id,
          'adjustment': 'Cheaper',
        }),
      );
      expect(agent.connectionError, isNull);
      final surface = agent.controller.contextFor(agent.latestInlineSurfaceId!);
      expect(
        surface.definition.value!.components['recommendations']!.type,
        'AlternativePiece',
      );
      await agent.conversation.sendRequest(
        action('select_product', {'productId': _dresses[1].id}),
      );
      expect(agent.connectionError, isNull);
      final card = surface.definition.value!.components['recommendations']!
          .toJson();
      expect(card['component'], 'ProductCard');
      expect(card['name'], _dresses[1].name);
      expect(card['imageAsset'], _dresses[1].imageAsset);
      expect(card['selected'], true);
      expect(runtime.outfit['items'], {'dress': _dresses[1].id});
    },
  );

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
      final surfaceId = agent.latestInlineSurfaceId!;
      final definition = agent.controller.contextFor(surfaceId).definition;
      final previousComponent = definition.value!.components['recommendations']!
          .toJson();
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
      expect(
        choices.getValue<String>(DataPath('/recommendations/0/name')),
        top.name,
      );
      final selectedCard = definition.value!.components['recommendations']!
          .toJson();
      expect(selectedCard['component'], 'ProductCard');
      expect(selectedCard['name'], top.name);
      expect(selectedCard['selected'], true);
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
        expect(
          definition.value!.components['recommendations']!.toJson(),
          previousComponent,
        );
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
        // BLoC subscribes to its event stream during construction. Keep the
        // agent and runtime in the same real async zone as the awaited turns.
        final agent = (await tester.runAsync(
          () async =>
              GenkitAgent(StylistRuntime(products: [blue], store: store)),
        ))!;
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
