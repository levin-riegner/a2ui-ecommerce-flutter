import 'dart:async';
import 'dart:io';

import 'package:a2ui_flutter_commerce/src/agent/stylist_presenter.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_result.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_schemas.dart';
import 'package:a2ui_flutter_commerce/src/agent/stylist_tool_error.dart';
import 'package:flutter_test/flutter_test.dart';

import 'stylist_runtime_test.dart' show products;
import 'stylist_store_helpers.dart';

void main() {
  test(
    'runtime returns a named immutable result and only presenter emits wire',
    () async {
      final runtime = StylistRuntime(products: products);
      addTearDown(runtime.dispose);
      final result = await runtime.turn({
        'message': 'A casual outfit under €500.',
      });
      expect(result, isA<StylistTurnResult>());
      expect(result.keys, isNot(contains('messages')));
      expect(result.view.picks, isNotEmpty);
      expect(await stylistResultSchema.validate(result.toJson()), isEmpty);
      expect(() => result['reply'] = 'changed', throwsUnsupportedError);
      expect(
        () => (result['brief'] as Map)['budget'] = 1,
        throwsUnsupportedError,
      );
      expect(() => result.view.picks.clear(), throwsUnsupportedError);
      final wire = presentStylistResult(result);
      expect(
        (wire['messages'] as List).any(
          (m) => m['createSurface']?['surfaceId'] == 'inline-1',
        ),
        isTrue,
      );
      expect(wire['reply'], result.reply);
      expect(
        File('lib/src/agent/stylist_runtime.dart').readAsStringSync(),
        isNot(contains("import 'stylist_surfaces.dart'")),
      );
    },
  );

  test(
    'presenter detaches mutable form drafts from immutable domain preferences',
    () async {
      final runtime = StylistRuntime(products: products);
      addTearDown(runtime.dispose);
      await runtime.turn({'message': 'A casual outfit under €500.'});
      final result = await runtime.turn({
        'action': {'name': 'edit_preferences', 'context': <String, Object?>{}},
      });
      final preferences = result.view.preferences!;
      expect((preferences['owned'] as Map)['top'], isFalse);
      final wire = presentStylistResult(result);
      final data =
          (wire['messages'] as List).last['updateDataModel']['value'] as Map;
      (data['ownedPieces'] as Map)['top'] = true;
      (data['preferredColours'] as List).add('Blue');
      (wire['brief'] as Map)['budget'] = 1;
      expect((preferences['owned'] as Map)['top'], isFalse);
      expect(preferences['colours'], isNot(contains('Blue')));
      expect(result.brief.budget, 500);
      expect((result['brief'] as Map)['budget'], 500);
      expect(
        () => (preferences['owned'] as Map)['top'] = true,
        throwsUnsupportedError,
      );
      final secondWire = presentStylistResult(result);
      final secondData =
          (secondWire['messages'] as List).last['updateDataModel']['value']
              as Map;
      expect((secondData['ownedPieces'] as Map)['top'], isFalse);
    },
  );

  test(
    'asynchronous presenter rejection cannot commit state or storage',
    () async {
      final store = MemoryStylistStore();
      final runtime = StylistRuntime(products: products, store: store);
      addTearDown(runtime.dispose);
      final first = await runtime.turn({
        'message': 'A casual outfit under €500.',
      });
      final persisted = store.encoded;
      final before = runtime.outfit;
      await expectLater(
        runtime.turn(
          {
            'action': {
              'name': 'select_product',
              'context': {'productId': first.view.picks.first.id},
            },
          },
          validateResult: (result) async {
            await Future<void>.delayed(Duration.zero);
            expect(presentStylistResult(result)['messages'], isNotEmpty);
            throw const FormatException('Presenter rejected the candidate');
          },
        ),
        throwsFormatException,
      );
      expect(runtime.outfit, before);
      expect(store.encoded, persisted);
      final retry = await runtime.turn({
        'action': {
          'name': 'select_product',
          'context': {'productId': first.view.picks.first.id},
        },
      });
      expect(retry.view.turn, first.view.turn + 1);
    },
  );

  test(
    'cancellation while an async validator waits never commits the draft',
    () async {
      final runtime = StylistRuntime(products: products);
      addTearDown(runtime.dispose);
      final first = await runtime.turn({
        'message': 'A casual outfit under €500.',
      });
      final before = runtime.outfit;
      final validating = Completer<void>();
      final release = Completer<void>();
      final pending = runtime.turn(
        {
          'action': {
            'name': 'select_product',
            'context': {'productId': first.view.picks.first.id},
          },
        },
        validateResult: (_) async {
          validating.complete();
          await release.future;
        },
      );
      final rejected = expectLater(pending, throwsA(anything));
      await validating.future;
      runtime.cancelActiveTurn();
      release.complete();
      await rejected;
      expect(runtime.outfit, before);
    },
  );

  test(
    'tool failures carry a stable code and immutable diagnostic values',
    () async {
      final missing = ['budget'];
      final failure = StylistToolError(
        message: 'Save the missing facts.',
        missingFields: missing,
      );
      missing.add('season');
      final wire = failure.toJson();
      expect(wire['code'], 'invalid_input');
      expect(wire['missingFields'], ['budget']);
      expect(() => wire['error'] = 'changed', throwsUnsupportedError);
      expect(
        await stylistToolOutputSchema('search_products').validate(wire),
        isEmpty,
      );
    },
  );
}
