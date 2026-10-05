import 'dart:convert';

import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

Product _piece(String id, ProductCategory category, double price) => Product(
  id: id,
  category: category,
  name: id,
  brand: 'Demo',
  price: price,
  meta: 'Summer',
  tag: 'Formal',
  swatch: '#123456',
  season: 'summer',
  occasion: 'celebration',
);

final _catalog = [
  _piece('selected-dress', ProductCategory.dress, 80),
  _piece('replacement-dress', ProductCategory.dress, 200),
  _piece('over-budget-dress', ProductCategory.dress, 250),
  _piece('selected-shoes', ProductCategory.shoes, 40),
  _piece('selected-bag', ProductCategory.bag, 30),
];

Map<String, dynamic> _select(String id) => {
  'action': {
    'name': 'select_product',
    'context': {'productId': id},
  },
};
Map<String, dynamic> _adjust(Object? category) => {
  'action': {
    'name': 'adjust_piece',
    'context': {'category': category},
  },
};
Future<void> _complete(StylistRuntime runtime) async {
  await runtime.turn({'message': 'A summer formal dinner dress under €300'});
  for (final id in ['selected-dress', 'selected-shoes', 'selected-bag']) {
    await runtime.turn(_select(id));
  }
}

void main() {
  test(
    'Quick Adjust preference reaches the model and is retained without edits',
    () async {
      final requests = <ModelRequest>[];
      final runtime = StylistRuntime(
        products: _catalog,
        model: (request) async {
          requests.add(request);
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await _complete(runtime);
      final before = jsonEncode(runtime.outfit);
      requests.clear();
      final result = await runtime.turn({
        'action': {
          'name': 'adjust_piece',
          'context': {'category': 'dress', 'adjustment': ' Warmer '},
        },
      });
      expect(jsonEncode(runtime.outfit), before);
      expect((result['products'] as List).map((p) => p['id']), [
        'replacement-dress',
      ]);
      expect(requests, isNotEmpty);
      for (final request in requests) {
        expect(
          request.messages.where((m) => m.role == Role.system).single.text,
          contains('dress replacement preference: Warmer'),
        );
      }
      expect(
        requests.first.messages.last.text,
        contains('dress replacement preference: Warmer'),
      );
      requests.clear();
      await runtime.turn(_adjust('shoes'));
      expect(jsonEncode(runtime.outfit), before);
      expect(
        requests.first.messages.where((m) => m.role == Role.system).single.text,
        contains('dress replacement preference: Warmer'),
      );
    },
  );

  test(
    'invalid adjustment payloads fail before a model request or outfit edit',
    () async {
      var modelRequests = 0;
      final runtime = StylistRuntime(
        products: _catalog,
        model: (request) async {
          modelRequests++;
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await _complete(runtime);
      final before = jsonEncode(runtime.outfit);
      final beforeRequests = modelRequests;
      for (final adjustment in [5, List.filled(121, 'a').join()]) {
        await expectLater(
          runtime.turn({
            'action': {
              'name': 'adjust_piece',
              'context': {'category': 'dress', 'adjustment': adjustment},
            },
          }),
          throwsFormatException,
        );
        expect(modelRequests, beforeRequests);
        expect(jsonEncode(runtime.outfit), before);
      }
    },
  );

  test(
    'Change cannot expose model tools that mutate the selected outfit',
    () async {
      var adjusting = false;
      final runtime = StylistRuntime(
        products: _catalog,
        model: (request) async {
          if (adjusting) {
            expect(
              request.tools?.map((tool) => tool.name),
              isNot(contains('remove_from_outfit')),
            );
            expect(
              request.tools?.map((tool) => tool.name),
              isNot(contains('add_to_outfit')),
            );
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'remove_from_outfit',
                      ref: 'malicious-remove',
                      input: {'productId': 'selected-dress'},
                    ),
                  ),
                ],
              ),
            );
          }
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await _complete(runtime);
      final before = jsonEncode(runtime.outfit);
      adjusting = true;
      await expectLater(
        runtime.turn({
          ..._adjust('dress'),
          'message': 'A different dress please',
        }),
        throwsStateError,
      );
      expect(jsonEncode(runtime.outfit), before);
    },
  );

  test('presentation rejects the old piece and can recover with a genuine alternative', () async {
    var adjusting = false;
    var rejectedOldPiece = false;
    final runtime = StylistRuntime(
      products: _catalog,
      model: (request) async {
        if (adjusting && request.messages.last.role == Role.tool) {
          final result = request.messages.last.content
              .where((part) => part.isToolResponse)
              .last
              .toolResponse!;
          if (result.name == 'search_products' ||
              result.name == 'present_products' &&
                  (result.output as Map).containsKey('error')) {
            if (result.name == 'present_products') {
              expect(
                (result.output as Map)['error'],
                contains('currently selected'),
              );
              rejectedOldPiece = true;
            }
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'present_products',
                      ref: 'adjust-presentation',
                      input: {
                        'productIds': [
                          result.name == 'search_products'
                              ? 'selected-dress'
                              : 'replacement-dress',
                        ],
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    await _complete(runtime);
    final before = jsonEncode(runtime.outfit);
    adjusting = true;
    final result = await runtime.turn(_adjust('dress'));
    expect(rejectedOldPiece, isTrue);
    expect((result['products'] as List).single['id'], 'replacement-dress');
    expect(jsonEncode(runtime.outfit), before);
  });
  test(
    'Change reopens a complete category without deleting any selected piece',
    () async {
      final runtime = StylistRuntime(products: _catalog);
      addTearDown(runtime.dispose);
      await _complete(runtime);
      final before = jsonEncode(runtime.outfit);
      final result = await runtime.turn(_adjust('dress'));
      expect(jsonEncode(runtime.outfit), before);
      expect((result['products'] as List).map((p) => p['id']), [
        'replacement-dress',
      ]);
      expect(result['reply'], isNot(contains('Removed')));
      expect(result['reply'], isNot(contains('Selected replacement-dress')));
      final messages = result['messages'] as List;
      final dressing =
          (messages.firstWhere(
                    (m) =>
                        m['updateDataModel']?['surfaceId'] == 'dressing-room',
                  )['updateDataModel']
                  as Map)['value']
              as Map;
      expect(dressing['spent'], contains('€150.00'));
      expect(dressing['left'], '€150.00 left');
      final slots = (dressing['slots'] as List).cast<Map>();
      expect(
        slots.singleWhere((slot) => slot['category'] == 'dress')['name'],
        'selected-dress',
      );

      // The €200 replacement exceeds €150 cash remaining, but is affordable
      // after the old €80 dress is released. The €250 replacement is excluded.
      final replaced = await runtime.turn(_select('replacement-dress'));
      expect(replaced['outfit']['items'], {
        'dress': 'replacement-dress',
        'shoes': 'selected-shoes',
        'bag': 'selected-bag',
      });
    },
  );

  test(
    'Change takes its explicit category over a different typed category',
    () async {
      final runtime = StylistRuntime(products: _catalog);
      addTearDown(runtime.dispose);
      await _complete(runtime);
      final result = await runtime.turn({
        ..._adjust('Dress'),
        'message': 'Maybe shoes instead',
      });
      expect(
        (result['products'] as List).map((p) => p['category']),
        everyElement('dress'),
      );
      expect((runtime.outfit['items'] as Map)['dress'], 'selected-dress');
    },
  );

  test('invalid and unselected categories fail before any provider request or state change', () async {
    var requests = 0;
    final runtime = StylistRuntime(
      products: _catalog,
      onModelRequest: (_) => requests++,
    );
    addTearDown(runtime.dispose);
    await _complete(runtime);
    final before = jsonEncode(runtime.outfit);
    final count = requests;
    for (final invalid in [null, 5, '', 'unknown', 'dress/shoes']) {
      await expectLater(runtime.turn(_adjust(invalid)), throwsFormatException);
      expect(jsonEncode(runtime.outfit), before);
    }
    await expectLater(runtime.turn(_adjust('top')), throwsStateError);
    expect(requests, count);
    expect(jsonEncode(runtime.outfit), before);
  });

  test('when no other affordable item exists Change keeps the selected look and explains', () async {
    final runtime = StylistRuntime(
      products: _catalog.where((p) => p.id != 'replacement-dress').toList(),
    );
    addTearDown(runtime.dispose);
    await _complete(runtime);
    final before = jsonEncode(runtime.outfit);
    final result = await runtime.turn(_adjust('dress'));
    expect(result['products'], isEmpty);
    expect(
      result['reply'],
      contains(
        'There are no alternatives for that piece within the available budget',
      ),
    );
    expect(result['reply'], contains('Keep it'));
    expect(jsonEncode(runtime.outfit), before);
  });

  test(
    'model failure while changing a piece rolls back and leaves retry possible',
    () async {
      var fail = false;
      final runtime = StylistRuntime(
        products: _catalog,
        model: (request) async {
          if (fail) throw StateError('Injected provider failure');
          return offlineStylistModel(request);
        },
      );
      addTearDown(runtime.dispose);
      await _complete(runtime);
      final before = jsonEncode(runtime.outfit);
      fail = true;
      await expectLater(runtime.turn(_adjust('dress')), throwsStateError);
      expect(jsonEncode(runtime.outfit), before);
      fail = false;
      final result = await runtime.turn(_adjust('dress'));
      expect((result['products'] as List).single['id'], 'replacement-dress');
      expect(jsonEncode(runtime.outfit), before);
    },
  );
}
