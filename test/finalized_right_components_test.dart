import 'dart:convert';
import 'dart:io';

import 'package:a2ui_flutter_commerce/src/catalog/commerce_components.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_right_components.dart';
import 'package:a2ui_flutter_commerce/src/catalog/finalized_right_a2ui.dart';
import 'package:a2ui_flutter_commerce/src/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:genui/genui.dart';
import 'package:genui/src/primitives/embedded_schemas.g.dart'
    show commonTypesSchemaJson;
import 'package:json_schema_builder/json_schema_builder.dart';

Widget _harness(Widget child, {double width = 351, double scale = 1}) =>
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      ),
    );
Widget _catalogWidget(
  CatalogItem item,
  Map<String, Object?> data,
  List<UiEvent> events,
  InMemoryDataModel model,
) => Builder(
  builder: (context) => item.widgetBuilder(
    CatalogItemContext(
      data: data,
      id: 'root',
      type: item.name,
      buildChild: (id, [dataContext]) => const SizedBox.shrink(),
      dispatchEvent: events.add,
      buildContext: context,
      dataContext: DataContext(model, DataPath('/')),
      getComponent: (_) => null,
      getCatalogItem: (_) => null,
      surfaceId: 'right-test',
      reportError: (error, stack) => throw error,
    ),
  ),
);

void main() {
  test('all finalized right components expose every verified variant', () {
    expect(finalizedRightItems.map((i) => i.name).toSet(), hasLength(15));
    expect(
      finalizedRightItems.fold<int>(0, (n, i) => n + i.exampleData.length),
      36,
    );
  });
  test(
    'all actual A2UI catalog examples validate their registered schema',
    () async {
      for (final item in finalizedRightItems) {
        for (final example in item.exampleData) {
          final data = (jsonDecode(example()) as List).single;
          expect(
            await item.dataSchema.validate(
              data,
              schemaRegistry: SchemaRegistry()
                ..addSchema(
                  Uri.parse(
                    'https://a2ui.org/specification/v0_9/common_types.json',
                  ),
                  Schema.fromMap(
                    jsonDecode(commonTypesSchemaJson) as Map<String, Object?>,
                  ),
                ),
            ),
            isEmpty,
            reason: '${item.name}: $data',
          );
        }
      }
    },
  );
  for (final width in [172.0, 351.0, 466.0]) {
    testWidgets(
      'every right variant renders in $width panes at 300 percent text',
      (tester) async {
        for (final item in finalizedRightItems) {
          for (final example in item.exampleData) {
            final data = Map<String, Object?>.from(
              (jsonDecode(example()) as List).single as Map,
            );
            final model = InMemoryDataModel();
            await tester.pumpWidget(
              _harness(
                _catalogWidget(item, data, [], model),
                width: width,
                scale: 3,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${item.name}: $data',
            );
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
          }
        }
      },
    );
  }
  testWidgets('mini map renders all four exact street exports and the pin', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        const FinalizedMapCard(label: 'Paris 8e', mini: true),
        width: 77.25,
      ),
    );
    await tester.pumpAndSettle();
    final names = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((w) => (w.bytesLoader as SvgAssetLoader).assetName)
        .toSet();
    expect(names, {
      'assets/icons/finalized_right/map-53-3097.svg',
      'assets/icons/finalized_right/map-53-3098.svg',
      'assets/icons/finalized_right/map-53-3099.svg',
      'assets/icons/finalized_right/map-53-3100.svg',
      'assets/icons/finalized_right/map-53-3101.svg',
    });
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'large text choosing badge remains outside short shoe thumbnail clipping',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          const FinalizedPieceSlot(
            category: 'Shoes',
            label: 'Shoes',
            meta: '',
            state: 'Next',
          ),
          width: 172,
          scale: 3,
        ),
      );
      await tester.pumpAndSettle();
      final badge = find.text('Choosing now');
      expect(badge, findsOneWidget);
      expect(tester.getTopLeft(badge).dy, greaterThanOrEqualTo(64));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'filled hanger change resolves bound host context and emits stable event',
    (tester) async {
      final events = <UiEvent>[];
      final model = InMemoryDataModel();
      model.update(DataPath('/productId'), 'demo-0092');
      await tester.pumpWidget(
        _harness(
          _catalogWidget(
            finalizedPieceSlotCatalogItem,
            {
              'label': 'A dress',
              'meta': 'Alder · €95',
              'state': 'Filled',
              'swatch': '#d9d4ca',
              'category': 'Dress',
              'name': 'Selected dress',
              'changeAction': {
                'event': {
                  'name': 'adjust_piece',
                  'context': {
                    'productId': {'path': '/productId'},
                  },
                },
              },
            },
            events,
            model,
          ),
          width: 172,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(events, hasLength(1));
      final event = UserActionEvent.fromMap(events.single.toMap());
      expect(event.name, 'adjust_piece');
      expect(event.context, {'productId': 'demo-0092'});
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  for (final width in [280.0, 351.0]) {
    testWidgets(
      'production black room stays readable at $width and 300 percent text',
      (tester) async {
        final item = finalizedDressingRoomCatalogItem;
        final data = Map<String, Object?>.from(
          (jsonDecode(item.exampleData.single()) as List).single as Map,
        );
        final model = InMemoryDataModel();
        await tester.pumpWidget(
          _harness(
            CommerceDressingRoomStyle(
              dark: true,
              child: _catalogWidget(item, data, [], model),
            ),
            width: width,
            scale: 3,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Dressing room'), findsOneWidget);
        expect(find.text('Choosing now'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final title = tester.widget<Text>(find.text('Dressing room'));
        expect(title.style?.color, Colors.white);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      },
    );
  }
  for (final scale in [1.0, 3.12]) {
    testWidgets(
      'compact black rack scrolls to every slot and keeps actions at $scale text',
      (tester) async {
        final item = finalizedDressingRoomCatalogItem;
        final data = Map<String, Object?>.from(
          (jsonDecode(item.exampleData.single()) as List).single as Map,
        );
        final model = InMemoryDataModel();
        final events = <UiEvent>[];
        data['planCaption'] = '1 of 4 pieces selected';
        await tester.pumpWidget(
          _harness(
            CommerceDressingRoomStyle(
              dark: true,
              compact: true,
              child: _catalogWidget(item, data, events, model),
            ),
            width: 314,
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        final room = find.byKey(const ValueKey('finalized-dressing-room'));
        final rack = find.byKey(const ValueKey('dressing-room-rack'));
        final decoration =
            tester.widget<Container>(room).decoration as BoxDecoration;
        expect(decoration.color, Colors.black);
        expect(find.text('1 of 4 pieces selected'), findsNothing);
        expect(find.text('€874 spent'), findsOneWidget);
        if (scale == 1) expect(tester.getSize(room).height, lessThan(350));
        expect(
          tester.getBottomRight(rack).dy,
          lessThan(tester.getTopLeft(find.byType(CommerceBudgetSummary)).dy),
        );
        final dress = find.byKey(const ValueKey('dressing-slot-dress'));
        await tester.ensureVisible(dress);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: dress, matching: find.byType(InkWell)),
        );
        expect(events, hasLength(1));
        final action = events.single as UserActionEvent;
        expect(action.name, 'adjust_piece');
        expect(action.context, {'category': 'dress'});
        await tester.drag(rack, const Offset(-1000, 0));
        await tester.pumpAndSettle();
        expect(
          tester
              .getRect(rack)
              .overlaps(
                tester.getRect(find.byKey(const ValueKey('dressing-slot-bag'))),
              ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      },
    );
  }
  testWidgets(
    'legacy category-less PieceSlot retains original schema presentation',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          const FinalizedPieceSlot(
            label: 'Shoes',
            meta: 'Next',
            state: 'Next',
            swatch: '#d9d4ca',
          ),
        ),
      );
      expect(find.byType(CommercePieceSlot), findsOneWidget);
      expect(find.text('Shoes'), findsOneWidget);
    },
  );
  testWidgets(
    'bound numeric budget updates without rebuilding component definition',
    (tester) async {
      final model = InMemoryDataModel();
      model.update(DataPath('/spent'), 35);
      final item = finalizedRightItems.singleWhere(
        (i) => i.name == 'BudgetMeter',
      );
      await tester.pumpWidget(
        _harness(
          _catalogWidget(
            item,
            {
              'spent': {'path': '/spent'},
              'budget': 100,
              'pieceCount': 1,
              'totalPieces': 4,
            },
            [],
            model,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('€35 spent · 1 of 4'), findsOneWidget);
      model.update(DataPath('/spent'), 120);
      await tester.pump();
      expect(find.text('Over budget'), findsOneWidget);
      expect(find.text('€-20 left'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  testWidgets(
    'bag quantity and remove update local summary and dispatch explicit events',
    (tester) async {
      final item = finalizedRightItems.singleWhere(
        (i) => i.name == 'BagPreview',
      );
      final data = Map<String, Object?>.from(
        (jsonDecode(item.exampleData.single()) as List).single as Map,
      );
      final model = InMemoryDataModel();
      final events = <UiEvent>[];
      await tester.pumpWidget(
        _harness(_catalogWidget(item, data, events, model), width: 351),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your bag — 4 items'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('bag-quantity-design-dress')),
          matching: find.text('+'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your bag — 5 items'), findsOneWidget);
      expect(find.text('€3,168'), findsOneWidget);
      var event = UserActionEvent.fromMap(events.last.toMap());
      expect(event.name, 'set_bag_quantity');
      expect(event.context, {'productId': 'design-dress', 'quantity': 2});
      await tester.tap(find.byTooltip('Remove Indra Long Dress'));
      await tester.pumpAndSettle();
      expect(find.text('Your bag — 3 items'), findsOneWidget);
      event = UserActionEvent.fromMap(events.last.toMap());
      expect(event.name, 'remove_bag_product');
      expect(event.context, {'productId': 'design-dress'});
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  testWidgets(
    'minus at one removes and Undo emits host restore and restores local item',
    (tester) async {
      final item = finalizedRightItems.singleWhere(
        (i) => i.name == 'BagPreview',
      );
      final data = Map<String, Object?>.from(
        (jsonDecode(item.exampleData.single()) as List).single as Map,
      );
      final model = InMemoryDataModel();
      final events = <UiEvent>[];
      await tester.pumpWidget(
        _harness(_catalogWidget(item, data, events, model)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('bag-quantity-design-dress')),
          matching: find.text('−'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your bag — 3 items'), findsOneWidget);
      expect(
        UserActionEvent.fromMap(events.last.toMap()).name,
        'remove_bag_product',
      );
      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(find.text('Your bag — 4 items'), findsOneWidget);
      expect(
        UserActionEvent.fromMap(events.last.toMap()).name,
        'restore_bag_product',
      );
      expect(UserActionEvent.fromMap(events.last.toMap()).context, {
        'productId': 'design-dress',
        'quantity': 1,
      });
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  testWidgets('Added bag button does not pretend to add the look twice', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        FinalizedRightComponent(
          component: 'AddToBagButton',
          data: finalizedRightFixtures.firstWhere(
            (f) => f['component'] == 'AddToBagButton' && f['state'] == 'Added',
          ),
          onAction: (_, extra) => taps++,
        ),
      ),
    );
    await tester.tap(find.text('Added to your bag · 4 items'));
    expect(taps, 0);
  });
  testWidgets('disabled malformed action cannot edit bag state', (
    tester,
  ) async {
    final data = {
      ...finalizedRightFixtures.firstWhere(
        (f) => f['component'] == 'BagPreview',
      ),
      'quantityAction': null,
    };
    await tester.pumpWidget(
      _harness(
        FinalizedRightComponent(
          component: 'BagPreview',
          data: data,
          onAction: (_, extra) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('bag-quantity-design-dress')),
        matching: find.text('+'),
      ),
    );
    await tester.pump();
    expect(find.text('Your bag — 4 items'), findsOneWidget);
  });
  test('literal export assets remain nonempty with no temporary Figma URLs in source', () {
    final files = Directory('assets/icons/finalized_right')
        .listSync()
        .whereType<File>()
        .toList();
    expect(files.length, greaterThanOrEqualTo(28));
    for (final f in files) {
      expect(f.lengthSync(), greaterThan(0));
    }
    expect(
      File('lib/src/catalog/finalized_right_components.dart')
          .readAsStringSync(),
      isNot(contains('figma.com/api')),
    );
  });
}
