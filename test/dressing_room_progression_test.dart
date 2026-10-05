import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:a2ui_flutter_commerce/src/agent/stub_agent.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_surfaces.dart';
import 'package:a2ui_flutter_commerce/src/catalog/commerce_catalog.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

Product piece(ProductCategory category) => Product(
  id: 'test-${category.name}',
  category: category,
  name: 'Selected ${category.name}',
  brand: 'Demo',
  price: 50,
  meta: 'Cotton',
  tag: 'A good fit',
  swatch: '#123456',
  imageAsset: 'assets/images/products/demo-0001.jpg',
);

Map<String, Object?> dressingData(List<Map<String, Object?>> messages) =>
    Map<String, Object?>.from(
      ((messages.firstWhere(
                (message) =>
                    (message['updateDataModel'] as Map?)?['surfaceId'] ==
                    'dressing-room',
              )['updateDataModel']
              as Map)['value'])
          as Map,
    );

List<Map<String, Object?>> surfaces(
  Map<String, Product> outfit, {
  int turn = 1,
  ProductCategory? nextCategory,
}) => renderStylistSurfaces(
  turn: turn,
  reply: 'Let’s keep building the look.',
  picks: [piece(ProductCategory.bottom)],
  outfit: outfit,
  budget: 900,
  occasion: 'Spring · smart layers',
  nextCategory: nextCategory,
);

class _SurfaceHarness {
  _SurfaceHarness() {
    controller = SurfaceController(catalogs: [buildCommerceCatalog()]);
    transport = A2uiTransportAdapter(
      onSend: (message) async => sent.add(message),
    );
    conversation = Conversation(controller: controller, transport: transport);
  }
  late final SurfaceController controller;
  late final A2uiTransportAdapter transport;
  late final Conversation conversation;
  final List<ChatMessage> sent = [];

  Future<void> publish(List<Map<String, Object?>> messages) async {
    for (final message in messages) {
      transport.addMessage(
        core.A2uiMessage.fromJson(Map<String, dynamic>.from(message)),
      );
    }
  }

  void dispose() {
    conversation.dispose();
    controller.dispose();
  }
}

void main() {
  testWidgets('brief choices stay local until one submit sends all values', (
    tester,
  ) async {
    final harness = _SurfaceHarness();
    addTearDown(harness.dispose);
    final messages = renderStylistSurfaces(
      turn: 1,
      reply: 'What style and budget should we use?',
      picks: [],
      outfit: {},
      budget: null,
      occasion: 'Spring city visit',
      clarification: {
        'missingFields': ['dressCode', 'budget'],
        'dressCode': '',
        'season': 'spring',
        'budget': null,
      },
    );
    await harness.publish(messages);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Surface(
              surfaceContext: harness.controller.contextFor('inline-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Find options'), findsOneWidget);
    expect(find.text('Season'), findsNothing);
    expect(harness.sent, isEmpty);
    await tester.tap(find.text('smart-casual'));
    await tester.pumpAndSettle();
    expect(
      harness.controller
          .contextFor('inline-1')
          .dataModel
          .getValue<String>(DataPath('/dressCode')),
      'smart-casual',
    );
    expect(harness.sent, isEmpty);
    await tester.drag(find.byType(Slider), const Offset(50, 0));
    await tester.pumpAndSettle();
    final budget = harness.controller
        .contextFor('inline-1')
        .dataModel
        .getValue<num>(DataPath('/budget'));
    expect(budget, isNot(750));
    expect(harness.sent, isEmpty);
    await tester.tap(find.text('Find options'));
    await tester.pumpAndSettle();
    expect(harness.sent, hasLength(1));
    final interaction = harness.sent.single.parts.uiInteractionParts.single;
    final payload = jsonDecode(interaction.interaction) as Map;
    expect(payload['action']['name'], 'find_options');
    expect(payload['action']['context'], {
      'dressCode': 'smart-casual',
      'season': 'spring',
      'budget': budget,
    });
    expect(tester.takeException(), isNull);
  });

  test('selected knit has a visual top slot and bottoms are next', () {
    final data = dressingData(surfaces({'top': piece(ProductCategory.top)}));
    final rows = (data['slots'] as List).cast<Map>();
    expect(rows.map((row) => row['category']), [
      'top',
      'bottom',
      'shoes',
      'bag',
    ]);
    expect(rows.first['name'], 'Selected top');
    expect(rows.first['imageAsset'], 'assets/images/products/demo-0001.jpg');
    expect(rows.first['state'], 'Filled');
    expect(
      rows.where((row) => row['state'] == 'Next').single['category'],
      'bottom',
    );
    expect(data['planCaption'], '1 of 4 pieces selected');
    expect(data['left'], '€850.00 left');
  });

  test('selected optional pieces remain visible after completing the plan', () {
    final outfit = {
      for (final category in ProductCategory.values.where(
        (category) => category != ProductCategory.dress,
      ))
        category.name: piece(category),
    };
    final data = dressingData(surfaces(outfit));
    final rows = (data['slots'] as List).cast<Map>();
    expect(rows.map((row) => row['category']), [
      'top',
      'bottom',
      'shoes',
      'bag',
      'layer',
      'accessory',
    ]);
    expect(rows.every((row) => row['state'] == 'Filled'), isTrue);
    expect(data['planCaption'], 'Your look is complete');
    expect(data['planComplete'], isTrue);
  });

  test('removal can reopen a slot different from the planner’s first gap', () {
    final data = dressingData(
      surfaces({}, nextCategory: ProductCategory.shoes),
    );
    final rows = (data['slots'] as List).cast<Map>();
    expect(
      rows.where((row) => row['state'] == 'Next').single['category'],
      'shoes',
    );
  });

  testWidgets(
    'bound dynamic slots update, fill, and complete on a narrow panel',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final harness = _SurfaceHarness();
      addTearDown(harness.dispose);
      await harness.publish(surfaces({'top': piece(ProductCategory.top)}));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: 390,
                child: Surface(
                  surfaceContext: harness.controller.contextFor(
                    'dressing-room',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Selected top'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('dressing-slot-bottom')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dressing-slot-bottom')),
          matching: find.text('Choosing now'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('dressing-slot-shoes')),
          matching: find.text('Choosing now'),
        ),
        findsNothing,
      );
      final full = {
        for (final category in [
          ProductCategory.top,
          ProductCategory.bottom,
          ProductCategory.shoes,
          ProductCategory.bag,
          ProductCategory.layer,
          ProductCategory.accessory,
        ])
          category.name: piece(category),
      };
      await harness.publish(surfaces(full, turn: 2));
      await tester.pumpAndSettle();
      expect(find.text('Your look is complete'), findsOneWidget);
      expect(find.text('Choosing now'), findsNothing);
      for (final category in full.keys) {
        expect(find.byKey(ValueKey('dressing-slot-$category')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected cards show Remove and recommendations show Add to dressing room',
    (tester) async {
      final harness = _SurfaceHarness();
      addTearDown(harness.dispose);
      await harness.publish(surfaces({'top': piece(ProductCategory.top)}));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Surface(
                    surfaceContext: harness.controller.contextFor('inline-1'),
                  ),
                  Surface(
                    surfaceContext: harness.controller.contextFor(
                      'selected-products',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Add to dressing room'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('old named-slot fixtures remain renderable', (tester) async {
    final agent = StubAgent();
    addTearDown(agent.dispose);
    await tester.runAsync(() => agent.startJourney(DemoJourney.paris));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Surface(
              surfaceContext: agent.controller.contextFor('dressing-room'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dressing room'), findsOneWidget);
    expect(find.text('A dress'), findsOneWidget);
    expect(find.text('Shoes'), findsOneWidget);
    expect(find.text('Choosing now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
