import 'stylist_wire_helpers.dart';

import 'dart:async';

import 'package:a2ui_flutter_commerce/presentation/stylist/bloc/genkit_agent.dart';
import 'package:a2ui_flutter_commerce/data/stylist/service/runtime/stylist_runtime.dart';
import 'package:a2ui_flutter_commerce/data/catalog/model/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart' as g;
import 'package:genui/genui.dart';

import 'stylist_runtime_test.dart' show products;

void main() {
  test(
    'a new journey discards a follow-up queued before model execution',
    () async {
      final modelTexts = <String>[];
      final runtime = StylistRuntime(
        products: products,
        model: (request) async {
          modelTexts.add(
            request.messages.map((g.Message message) => message.text).join(' '),
          );
          return offlineStylistModel(request);
        },
      );
      final agent = GenkitAgent(runtime);
      addTearDown(agent.dispose);
      await agent.startJourney(DemoJourney.lisbon);
      modelTexts.clear();

      final followUp = agent.conversation.sendRequest(
        ChatMessage.user('Obsolete follow-up request'),
      );
      final replacement = agent.startJourney(DemoJourney.paris);
      await Future.wait([followUp, replacement]);
      expect(agent.activeJourney, DemoJourney.paris);
      expect(
        modelTexts.every(
          (text) => !text.contains('Obsolete follow-up request'),
        ),
        isTrue,
        reason: 'Superseded queued input must never reach the provider.',
      );
      expect(agent.connectionError, isNull);
    },
  );

  test('queued turns retain their own callbacks and reject drafts before commit', () async {
    final firstModelStarted = Completer<void>();
    final releaseFirstModel = Completer<void>();
    var blockFirstRequest = true;
    final runtime = StylistRuntime(
      products: products,
      model: (request) async {
        if (blockFirstRequest) {
          blockFirstRequest = false;
          firstModelStarted.complete();
          await releaseFirstModel.future;
        }
        return offlineStylistModel(request);
      },
    );
    addTearDown(runtime.dispose);
    runtime.reset(journey: DemoJourney.lisbon);
    final callbackOrder = <String>[];
    final firstPicks = <String>[];
    final secondPicks = <String>[];

    final first = runtime.turn(
      {'message': '${DemoJourney.lisbon.title}. ${DemoJourney.lisbon.brief}'},
      onProgress: (picks) {
        callbackOrder.add('first-progress');
        firstPicks.addAll(picks.map((product) => product.id));
        expect(() => picks.clear(), throwsUnsupportedError);
      },
      validateResult: (result) {
        callbackOrder.add('first-validation');
        expect(runtime.outfit['items'], isEmpty);
        expect((result['outfit'] as Map)['items'], isEmpty);
      },
    );
    await firstModelStarted.future;

    // Enqueue before the first callback fires: a shared mutable callback field
    // would send the first turn's products to the second turn's consumer.
    final rejectedSecond = runtime.turn(
      {
        'action': {
          'name': 'select_product',
          'context': {'productId': 'top-1'},
        },
      },
      onProgress: (picks) {
        callbackOrder.add('second-progress');
        secondPicks.addAll(picks.map((product) => product.id));
      },
      validateResult: (result) {
        callbackOrder.add('second-validation');
        expect((result['outfit'] as Map)['items'], {'top': 'top-1'});
        expect(runtime.outfit['items'], isEmpty);
        throw const FormatException('Rejected final A2UI batch');
      },
    );
    final rejection = expectLater(rejectedSecond, throwsFormatException);
    expect(callbackOrder, isEmpty);
    releaseFirstModel.complete();
    final firstResult = await first;
    await rejection;

    expect(callbackOrder, [
      'first-progress',
      'first-validation',
      'second-progress',
      'second-validation',
    ]);
    expect(firstPicks, ['top-1']);
    expect(secondPicks, ['bottom-1']);
    expect(runtime.outfit, firstResult['outfit']);
    expect(runtime.outfit['items'], isEmpty);

    // A rejected turn neither consumes the last presented choice nor advances
    // the committed surface revision. A later caller with no callbacks retries.
    final retry = await runtime.turn({
      'action': {
        'name': 'select_product',
        'context': {'productId': 'top-1'},
      },
    });
    expect(callbackOrder, hasLength(4));
    expect(runtime.outfit['items'], {'top': 'top-1'});
    expect(
      (presentedStylistTurn(retry)['messages'] as List)
          .where((message) => (message as Map).containsKey('createSurface'))
          .map((message) => message['createSurface']['surfaceId']),
      ['inline-2'],
    );
  });
}
