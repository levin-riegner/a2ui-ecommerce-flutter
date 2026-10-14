import 'dart:io';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/src/agent/stylist_surfaces.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_left_components.dart';
import 'package:a2ui_flutter_commerce/src/data/catalog_products.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui/test/validation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'protocol_fixture_helpers.dart';

void main() {
  test('recorded host messages remain valid v0.9 catalog envelopes', () async {
    final catalog = buildCommerceCatalog();
    final files = Directory('test/fixtures/protocol')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'));
    expect(files.length, greaterThanOrEqualTo(5));
    for (final file in files) {
      final name = file.uri.pathSegments.last.replaceAll('.json', '');
      for (final message in readProtocolFixture(name)) {
        expect(message['version'], 'v0.9', reason: file.path);
        expect(() => core.A2uiMessage.fromJson(message), returnsNormally);
        final components =
            (message['updateComponents'] as Map?)?['components'] as List?;
        for (final raw in components ?? []) {
          final row = Map<String, Object?>.from(raw as Map);
          final item = catalog.items.singleWhere(
            (item) => item.name == row['component'],
          );
          final errors = await item.dataSchema.validate(
            row,
            schemaRegistry: createSchemaRegistryWithCommonTypes(),
          );
          expect(errors, isEmpty, reason: '$name/${row['id']}: $errors');
        }
      }
    }
  });

  test('host emits the recorded catalog-backed recommendation contract', () {
    final products = parseCatalogProducts(
      File('assets/data/catalog/products.csv').readAsStringSync(),
    );
    expect(
      renderStylistSurfaces(
        turn: 1,
        reply: 'Start with a comfortable shirt for your spring city visit.',
        picks: [
          for (final id in ['demo-0001', 'demo-0002'])
            products.singleWhere((product) => product.id == id),
        ],
        outfit: {},
        budget: 900,
        occasion: 'Spring city visit',
      ),
      readProtocolFixture('recommendations'),
    );
  });

  test('recommendation prices omit zero decimals and preserve cents', () {
    final messages = renderPendingStylistSurface(
      surfaceId: 'preview',
      picks: [
        for (final price in [45.0, 45.75, 45.5])
          Product(
            id: 'price-$price',
            category: ProductCategory.top,
            name: 'Shirt',
            brand: 'Alder Studio',
            price: price,
            meta: 'Stone · Cotton',
            tag: 'work',
            swatch: '#fff',
          ),
      ],
    );
    final update = messages.last['updateDataModel'] as Map;
    final data = update['value'] as Map;
    expect(
      (data['recommendations'] as List).map((row) => (row as Map)['price']),
      ['€45', '€45.75', '€45.50'],
    );
  });

  testWidgets('recorded bound cards resolve facts and submit product IDs', (
    tester,
  ) async {
    final harness = ProtocolFixtureHarness();
    addTearDown(harness.dispose);
    harness.publish('recommendations');
    await tester.pumpWidget(harness.view(['inline-1']));
    await tester.pumpAndSettle();

    expect(find.text('Solstice Button Shirt'), findsOneWidget);
    expect(find.text('Arc Ribbed Knit'), findsOneWidget);
    expect(find.text('€85'), findsOneWidget);
    expect(find.text('€125'), findsOneWidget);
    final completedCards = tester.widgetList<FinalizedProductCard>(
      find.byType(FinalizedProductCard),
    );
    expect(completedCards, hasLength(2));
    expect(completedCards.map((card) => card.category), everyElement('top'));
    expect(completedCards.map((card) => card.tag), ['travel', 'weekend']);
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any(
            (widget) =>
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    'assets/images/products/demo-0001.jpg',
          ),
      isTrue,
    );
    expect(harness.sent, isEmpty);
    await tester.tap(find.text('Add to dressing room').first);
    await tester.pumpAndSettle();
    expect(harness.sent, hasLength(1));
    expect(harness.submittedAction['name'], 'select_product');
    expect(harness.submittedAction['context'], {'productId': 'demo-0001'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('data-only updates repaint advice and persistent dressing room', (
    tester,
  ) async {
    final harness = ProtocolFixtureHarness();
    addTearDown(harness.dispose);
    harness.publish('recommendations');
    await tester.pumpWidget(harness.view(['inline-1', 'dressing-room']));
    await tester.pumpAndSettle();
    final originalSurface = tester.element(
      find.byKey(const ValueKey('inline-1')),
    );
    final originalDressing = tester.element(
      find.byKey(const ValueKey('dressing-room')),
    );
    expect(find.text('€900 left'), findsOneWidget);
    expect(find.text('Solstice Button Shirt'), findsOneWidget);

    for (final name in ['advice_data_update', 'dressing_room_data_update']) {
      expect(
        readProtocolFixture(name)
            .every((message) => message.containsKey('updateDataModel')),
        isTrue,
      );
      harness.publish(name);
    }
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byKey(const ValueKey('inline-1'))),
      same(originalSurface),
    );
    expect(
      tester.element(find.byKey(const ValueKey('dressing-room'))),
      same(originalDressing),
    );
    expect(
      find.text('Choose the cotton shirt for a light starting point.'),
      findsOneWidget,
    );
    expect(find.text('€815 left'), findsOneWidget);
    expect(find.text('€85 spent —\u00a01 of 4'), findsOneWidget);
    expect(find.text('Solstice Button Shirt'), findsNWidgets(2));
    final nextSlot = find.byKey(const ValueKey('dressing-slot-bottom'));
    expect(
      find.descendant(of: nextSlot, matching: find.text('Choosing now')),
      findsOneWidget,
    );
    expect(harness.sent, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recorded brief edits remain local until explicit submission', (
    tester,
  ) async {
    final harness = ProtocolFixtureHarness();
    addTearDown(harness.dispose);
    harness.publish('brief');
    await tester.pumpWidget(harness.view(['inline-1']));
    await tester.pumpAndSettle();
    expect(find.text('Season'), findsNothing);
    await tester.tap(find.text('Smart-casual'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Slider), const Offset(70, 0));
    await tester.pumpAndSettle();
    final data = harness.controller.contextFor('inline-1').dataModel;
    final submittedBudget = data.getValue<num>(DataPath('/budget'));
    expect(data.getValue<String>(DataPath('/dressCode')), 'smart-casual');
    expect(submittedBudget, isNot(750));
    expect(harness.sent, isEmpty);
    await tester.tap(find.text('Find options'));
    await tester.pumpAndSettle();
    expect(harness.sent, hasLength(1));
    expect(harness.submittedAction['name'], 'find_options');
    expect(harness.submittedAction['context'], {
      'dressCode': 'smart-casual',
      'season': 'spring',
      'budget': submittedBudget,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending and validated preview remain distinct from empty results',
    (tester) async {
      final harness = ProtocolFixtureHarness();
      addTearDown(harness.dispose);
      harness.publish('pending');
      await tester.pumpWidget(harness.view(['pending-turn-1']));
      await tester.pumpAndSettle();
      expect(find.text('Preparing your recommendations…'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Recommendation cards are loading',
        ),
        findsOneWidget,
      );
      expect(find.text('No catalog options match this request.'), findsNothing);
      expect(find.byType(FinalizedProductCard), findsNothing);
      final pendingSurface = tester.element(
        find.byKey(const ValueKey('pending-turn-1')),
      );

      // Host-validated cards replace the skeleton on the same pending surface.
      // Their explicit actionless component prevents a provisional selection.
      expect(
        readProtocolFixture('validated_preview')
            .any((message) => message.containsKey('createSurface')),
        isFalse,
      );
      harness.publish('validated_preview');
      await tester.pumpAndSettle();
      expect(
        tester.element(find.byKey(const ValueKey('pending-turn-1'))),
        same(pendingSurface),
      );
      expect(find.text('Preparing your recommendations…'), findsNothing);
      expect(find.text('Adding styling advice…'), findsOneWidget);
      expect(find.text('Solstice Button Shirt'), findsOneWidget);
      expect(find.text('Arc Ribbed Knit'), findsOneWidget);
      expect(find.text('€85'), findsOneWidget);
      final previewCards = tester.widgetList<FinalizedProductCard>(
        find.byType(FinalizedProductCard),
      );
      expect(previewCards, hasLength(2));
      expect(previewCards.map((card) => card.category), everyElement('top'));
      expect(previewCards.map((card) => card.tag), ['travel', 'weekend']);
      expect(
        tester
            .widgetList<InkWell>(find.byType(InkWell))
            .every(
              (widget) =>
                  widget.onTap == null &&
                  widget.onDoubleTap == null &&
                  widget.onLongPress == null,
            ),
        isTrue,
      );
      expect(find.byType(Slider), findsNothing);
      await tester.tap(find.text('Solstice Button Shirt'));
      await tester.pump();
      expect(harness.sent, isEmpty);

      harness.transport.addMessage(
        core.DeleteSurfaceMessage(surfaceId: 'pending-turn-1'),
      );
      harness.publish('empty');
      await tester.pumpWidget(harness.view(['inline-1']));
      await tester.pumpAndSettle();
      expect(
        find.text('No catalog options match this request.'),
        findsOneWidget,
      );
      expect(find.text('Preparing your recommendations…'), findsNothing);
      expect(find.text('Adding styling advice…'), findsNothing);
      expect(find.byType(FinalizedProductCard), findsNothing);
      expect(
        harness.controller.contextFor('pending-turn-1').definition.value,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
